package com.apoorvdarshan.calorietracker.services

import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightEntry
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import kotlin.random.Random

/**
 * Dev-only helper that swaps the user's real data for a year of synthetic food + weight
 * entries so the Progress tab can be eyeballed end-to-end. Triggered by launch flags from
 * MainActivity:
 *   adb shell am start -n com.apoorvdarshan.calorietracker/.MainActivity --ez seed_test_data true
 *   adb shell am start -n com.apoorvdarshan.calorietracker/.MainActivity --ez restore_real_data true
 *
 * `seed` snapshots the live state into a single backup blob, disables Health Connect so the
 * synthetic entries can't sync upstream, then writes 365 days of food + weights + body fat.
 * `restore` puts everything back exactly as it was.
 */
class TestDataSeeder(private val container: AppContainer) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun seedYear() {
        snapshotRealDataIfNeeded()

        container.prefs.setHealthConnectEnabled(false)

        val baseProfile = container.profileRepository.profile.first()
            ?: UserProfile(weightKg = 75.0, goalWeightKg = 70.0)
        container.profileRepository.save(
            baseProfile.copy(
                weightKg = 73.5,
                goalWeightKg = 70.0,
                bodyFatPercentage = 0.175,
                goalBodyFatPercentage = 0.15
            )
        )
        container.prefs.setOnboardingCompleted(true)

        container.foodRepository.replaceAll(generateFood())
        container.weightRepository.replaceAll(generateWeights())
        container.bodyFatRepository.replaceAll(
            generateBodyFatSeries(totalDays = 365, startFraction = 0.225, endFraction = 0.175, seed = 0xFA7365)
        )
    }

    /**
     * Focused seeder for the v3.2 Progress chart verification — fills 30 days
     * of weight + 30 days of body-fat readings (overlapping so both 1W and 1M
     * Progress views render with data + a goal-line overlay) without touching
     * food entries or other state. Use this when verifying the Body Fat chart
     * + segmented toggle on debug:
     *
     *   adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez seed_body_metrics true
     *   adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez restore_real_data true
     *
     * Snapshots into the same SeedBackup blob seedYear uses, so restore_real_data
     * recovers the original state regardless of which seeder was last invoked.
     */
    suspend fun seedBodyMetrics() {
        snapshotRealDataIfNeeded()

        // Disable HC so the synthetic entries can't echo to the production
        // install's HC sync relationship. (Ports the same guard from seedYear.)
        container.prefs.setHealthConnectEnabled(false)

        // Seed the profile with body fat + a goal so the Body Fat segment on
        // Progress is visible (showsBodyFatSection guard checks any of: entries
        // exist, profile.bodyFatPercentage, profile.goalBodyFatPercentage).
        val baseProfile = container.profileRepository.profile.first()
            ?: UserProfile(weightKg = 75.0, goalWeightKg = 70.0)
        container.profileRepository.save(
            baseProfile.copy(
                weightKg = 73.0,
                goalWeightKg = 68.0,
                bodyFatPercentage = 0.18,
                goalBodyFatPercentage = 0.12
            )
        )
        container.prefs.setOnboardingCompleted(true)

        container.weightRepository.replaceAll(
            generateWeightSeries(totalDays = 30, startKg = 75.5, endKg = 73.0, seed = 0xBEEF)
        )
        container.bodyFatRepository.replaceAll(
            generateBodyFatSeries(totalDays = 30, startFraction = 0.180, endFraction = 0.165, seed = 0xFA7)
        )
    }

    /**
     * Long-range variant of seedBodyMetrics — 2 years (730 days) of weight +
     * body-fat readings so the 6M / 1Y / All Progress ranges and the history
     * lists can be eyeballed with realistic volume (~580 weights, ~440 fats).
     *
     *   adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez seed_body_metrics_2y true
     *   adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez restore_real_data true
     */
    suspend fun seedTwoYearsBodyMetrics() {
        snapshotRealDataIfNeeded()

        container.prefs.setHealthConnectEnabled(false)

        val baseProfile = container.profileRepository.profile.first()
            ?: UserProfile(weightKg = 75.0, goalWeightKg = 70.0)
        container.profileRepository.save(
            baseProfile.copy(
                weightKg = 73.0,
                goalWeightKg = 70.0,
                bodyFatPercentage = 0.165,
                goalBodyFatPercentage = 0.15
            )
        )
        container.prefs.setOnboardingCompleted(true)

        container.weightRepository.replaceAll(
            generateWeightSeries(totalDays = 730, startKg = 82.0, endKg = 73.0, seed = 0x2BEEF)
        )
        container.bodyFatRepository.replaceAll(
            generateBodyFatSeries(totalDays = 730, startFraction = 0.240, endFraction = 0.165, seed = 0x2FA7)
        )
    }

    /** Snapshot the user's real data into the backup blob — first seed run only.
     *  Re-seeds (e.g. switching from the 30-day to the 2-year dataset) must not
     *  overwrite the original backup, or restore would put seed data back. */
    private suspend fun snapshotRealDataIfNeeded() {
        if (container.prefs.testSeedBackupJson.first() != null) return
        val backup = SeedBackup(
            entriesJson = json.encodeToString(
                ListSerializer(FoodEntry.serializer()),
                container.foodRepository.entries.first()
            ),
            weightsJson = json.encodeToString(
                ListSerializer(WeightEntry.serializer()),
                container.weightRepository.entries.first()
            ),
            bodyFatsJson = json.encodeToString(
                ListSerializer(BodyFatEntry.serializer()),
                container.bodyFatRepository.entries.first()
            ),
            profileJson = container.profileRepository.profile.first()?.let {
                json.encodeToString(UserProfile.serializer(), it)
            },
            healthConnectEnabled = container.prefs.healthConnectEnabled.first(),
            onboarded = container.prefs.hasCompletedOnboarding.first()
        )
        container.prefs.setTestSeedBackupJson(json.encodeToString(SeedBackup.serializer(), backup))
    }

    suspend fun restore() {
        val raw = container.prefs.testSeedBackupJson.first() ?: return
        val backup = runCatching {
            json.decodeFromString(SeedBackup.serializer(), raw)
        }.getOrNull() ?: return

        container.foodRepository.replaceAll(
            json.decodeFromString(ListSerializer(FoodEntry.serializer()), backup.entriesJson)
        )
        container.weightRepository.replaceAll(
            json.decodeFromString(ListSerializer(WeightEntry.serializer()), backup.weightsJson)
        )
        // bodyFatsJson is null for backups written before the field existed —
        // those predate any real body-fat history, so clearing is still right.
        container.bodyFatRepository.replaceAll(
            backup.bodyFatsJson?.let {
                json.decodeFromString(ListSerializer(BodyFatEntry.serializer()), it)
            } ?: emptyList()
        )
        backup.profileJson?.let {
            container.profileRepository.save(json.decodeFromString(UserProfile.serializer(), it))
        }
        container.prefs.setHealthConnectEnabled(backup.healthConnectEnabled)
        container.prefs.setOnboardingCompleted(backup.onboarded)
        container.prefs.clearTestSeedBackup()
    }

    private fun generateFood(): List<FoodEntry> {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val rng = Random(seed = 0xF0D)

        val breakfast = listOf(
            Quad("Greek yogurt with berries", 280, 22, 32, 6, "🥣"),
            Quad("Oatmeal with banana", 340, 12, 60, 8, "🥣"),
            Quad("Avocado toast", 380, 14, 38, 18, "🥑"),
            Quad("Protein smoothie", 310, 30, 28, 7, "🥤"),
            Quad("Eggs and toast", 420, 22, 30, 22, "🍳")
        )
        val lunch = listOf(
            Quad("Chicken caesar salad", 540, 38, 22, 32, "🥗"),
            Quad("Turkey sandwich", 480, 32, 48, 16, "🥪"),
            Quad("Sushi rolls", 620, 28, 84, 14, "🍣"),
            Quad("Burrito bowl", 720, 36, 78, 24, "🌯"),
            Quad("Pasta primavera", 560, 18, 82, 18, "🍝")
        )
        val dinner = listOf(
            Quad("Grilled salmon and rice", 640, 42, 58, 22, "🐟"),
            Quad("Steak and broccoli", 720, 50, 18, 46, "🥩"),
            Quad("Chicken stir-fry", 580, 40, 52, 20, "🍛"),
            Quad("Veggie curry", 510, 18, 72, 18, "🍛"),
            Quad("Margherita pizza", 780, 28, 92, 28, "🍕")
        )
        val snacks = listOf(
            Quad("Apple", 95, 0, 25, 0, "🍎"),
            Quad("Almonds", 170, 6, 6, 14, "🥜"),
            Quad("Protein bar", 210, 20, 22, 6, "🍫"),
            Quad("Banana", 105, 1, 27, 0, "🍌"),
            Quad("Greek yogurt", 130, 18, 8, 4, "🥛")
        )

        val out = mutableListOf<FoodEntry>()
        for (daysAgo in 365 downTo 0) {
            val day = today.minusDays(daysAgo.toLong())
            val skipDay = rng.nextInt(20) == 0
            if (skipDay) continue

            fun add(template: Quad, hour: Int, meal: MealType) {
                val jitter = rng.nextDouble(0.85, 1.15)
                val ts = day.atTime(LocalTime.of(hour, rng.nextInt(0, 50)))
                    .atZone(zone).toInstant()
                out.add(
                    FoodEntry(
                        name = template.name,
                        calories = (template.cal * jitter).toInt(),
                        protein = template.p * jitter,
                        carbs = template.c * jitter,
                        fat = template.f * jitter,
                        timestamp = ts,
                        emoji = template.emoji,
                        source = FoodSource.TEXT_INPUT,
                        mealType = meal
                    )
                )
            }

            add(breakfast.random(rng), hour = 8, meal = MealType.BREAKFAST)
            add(lunch.random(rng), hour = 13, meal = MealType.LUNCH)
            add(dinner.random(rng), hour = 19, meal = MealType.DINNER)
            if (rng.nextBoolean()) add(snacks.random(rng), hour = 16, meal = MealType.SNACK)
        }
        return out
    }

    /** Weight readings over [totalDays], linear [startKg]→[endKg] trend with
     *  day-to-day noise, ~20% skipped days for realism. */
    private fun generateWeightSeries(totalDays: Int, startKg: Double, endKg: Double, seed: Long): List<WeightEntry> {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val rng = Random(seed)
        val out = mutableListOf<WeightEntry>()
        for (daysAgo in (totalDays - 1) downTo 0) {
            // Always log today + yesterday so the 1W view always shows 2+ points.
            if (daysAgo > 1 && rng.nextInt(10) < 2) continue
            val day = today.minusDays(daysAgo.toLong())
            val progress = (totalDays - 1 - daysAgo).toDouble() / (totalDays - 1)
            val baseline = startKg - (startKg - endKg) * progress
            val noise = rng.nextDouble(-0.5, 0.5)
            val ts = day.atTime(8, rng.nextInt(0, 30)).atZone(zone).toInstant()
            out.add(WeightEntry(date = ts, weightKg = baseline + noise))
        }
        return out
    }

    /** Body-fat readings over [totalDays], linear [startFraction]→[endFraction]
     *  trend, ~40% skipped days since people measure body fat less often. */
    private fun generateBodyFatSeries(totalDays: Int, startFraction: Double, endFraction: Double, seed: Long): List<BodyFatEntry> {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val rng = Random(seed)
        val out = mutableListOf<BodyFatEntry>()
        for (daysAgo in (totalDays - 1) downTo 0) {
            // Always log today + yesterday so the 1W chart isn't empty.
            if (daysAgo > 1 && rng.nextInt(10) < 4) continue
            val day = today.minusDays(daysAgo.toLong())
            val progress = (totalDays - 1 - daysAgo).toDouble() / (totalDays - 1)
            val baseline = startFraction - (startFraction - endFraction) * progress
            // ±0.3% jitter to simulate caliper / smart-scale measurement noise.
            val noise = rng.nextDouble(-0.003, 0.003)
            val ts = day.atTime(8, rng.nextInt(0, 30)).atZone(zone).toInstant()
            out.add(BodyFatEntry(date = ts, bodyFatFraction = baseline + noise))
        }
        return out
    }

    private fun generateWeights(): List<WeightEntry> {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val rng = Random(seed = 0xC0FFEE)
        val startKg = 78.0
        val endKg = 73.5
        val totalDays = 365

        val out = mutableListOf<WeightEntry>()
        for (daysAgo in (totalDays - 1) downTo 0) {
            // Skip ~30% of days for realism — most users don't weigh in every day.
            // Always log today + yesterday so the 1W view always has fresh points.
            if (daysAgo > 1 && rng.nextInt(10) < 3) continue
            val day = today.minusDays(daysAgo.toLong())
            val progress = (totalDays - 1 - daysAgo).toDouble() / (totalDays - 1)
            val baseline = startKg - (startKg - endKg) * progress
            // Larger day-to-day noise (water weight, time of day, etc.)
            val noise = rng.nextDouble(-0.6, 0.6)
            val ts = day.atTime(8, rng.nextInt(0, 30)).atZone(zone).toInstant()
            out.add(WeightEntry(date = ts, weightKg = baseline + noise))
        }
        return out
    }
}

@Serializable
private data class SeedBackup(
    val entriesJson: String,
    val weightsJson: String,
    val profileJson: String?,
    val healthConnectEnabled: Boolean,
    val onboarded: Boolean,
    // Added after BodyFatRepository shipped — null in older backups.
    val bodyFatsJson: String? = null
)

private data class Quad(
    val name: String,
    val cal: Int,
    val p: Int,
    val c: Int,
    val f: Int,
    val emoji: String
)
