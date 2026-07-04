package com.apoorvdarshan.calorietracker

import android.app.Application
import com.apoorvdarshan.calorietracker.data.BodyFatRepository
import com.apoorvdarshan.calorietracker.data.BodyMeasurementRepository
import com.apoorvdarshan.calorietracker.data.ChatRepository
import com.apoorvdarshan.calorietracker.data.FoodRepository
import com.apoorvdarshan.calorietracker.data.KeyStore
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.data.ProfileRepository
import com.apoorvdarshan.calorietracker.data.WeightRepository
import com.apoorvdarshan.calorietracker.services.FoodImageStore
import com.apoorvdarshan.calorietracker.services.NotificationService
import com.apoorvdarshan.calorietracker.services.TestDataSeeder
import com.apoorvdarshan.calorietracker.services.WidgetSnapshotWriter
import com.apoorvdarshan.calorietracker.services.AdaptiveGoalResult
import com.apoorvdarshan.calorietracker.services.WeightAnalysisService
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.services.ai.ChatService
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysisService
import com.apoorvdarshan.calorietracker.services.health.HealthConnectManager
import com.apoorvdarshan.calorietracker.services.speech.SpeechService
import com.google.android.gms.ads.MobileAds
import kotlin.math.roundToInt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

/**
 * Application-scoped singleton wiring. Manual DI (no Hilt) — repositories and
 * services are instantiated once and handed to ViewModels via [container].
 */
class FudAIApp : Application() {

    lateinit var container: AppContainer
        private set

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        container.notifications.createChannels()
        container.widgetSnapshotWriter.observe().launchIn(appScope)
        // Google Mobile Ads SDK — initialized off the main thread (documented as
        // supported) so cold start isn't delayed; banners render via AdBannerStrip.
        appScope.launch { MobileAds.initialize(this@FudAIApp) }
        // Re-arm the daily weight-log alarm on every cold start. AlarmManager
        // drops scheduled alarms on device reboot and (sometimes) on app
        // updates — without this, a user who enabled Notifications once would
        // silently stop receiving the reminder after the next reboot.
        appScope.launch {
            if (container.prefs.notificationsEnabled.first() &&
                container.notifications.canPostNotifications()
            ) {
                if (container.prefs.streakReminderEnabled.first()) {
                    container.notifications.scheduleStreakReminder(
                        container.prefs.streakReminderHour.first(),
                        container.prefs.streakReminderMinute.first()
                    )
                } else {
                    container.notifications.cancelStreakReminder()
                }
                if (container.prefs.dailySummaryEnabled.first()) {
                    container.notifications.scheduleDailySummary(
                        container.prefs.dailySummaryHour.first(),
                        container.prefs.dailySummaryMinute.first()
                    )
                } else {
                    container.notifications.cancelDailySummary()
                }
                if (container.prefs.weightReminderEnabled.first()) {
                    container.notifications.scheduleWeightReminder()
                } else {
                    container.notifications.cancelWeightReminder()
                }
                // Body-fat reminder only fires for users who've actually opted
                // into body-fat tracking and left that notification type on.
                val profile = container.profileRepository.current()
                if (container.prefs.bodyFatReminderEnabled.first() && profile?.bodyFatPercentage != null) {
                    container.notifications.scheduleBodyFatReminder()
                } else {
                    container.notifications.cancelBodyFatReminder()
                }
            }
        }
    }
}

/** Stable labels for the read types a Health Connect changes token was seeded for,
 *  persisted alongside the token so we can detect a newly-granted read capability. */
private const val HEALTH_READ_TYPE_WEIGHT = "weight"
private const val HEALTH_READ_TYPE_BODY_FAT = "bodyfat"

class AppContainer(app: FudAIApp) {
    val appContext = app.applicationContext
    val prefs = PreferencesStore(app)
    val keyStore = KeyStore(app)
    val imageStore = FoodImageStore(app)
    val notifications = NotificationService(app)
    val health = HealthConnectManager(app)

    val profileRepository = ProfileRepository(prefs)
    val foodRepository = FoodRepository(prefs, health)
    val weightRepository = WeightRepository(prefs, profileRepository, health)
    val bodyFatRepository = BodyFatRepository(prefs, profileRepository, health)
    val bodyMeasurementRepository = BodyMeasurementRepository(prefs)
    val chatRepository = ChatRepository(prefs)

    val foodAnalysis = FoodAnalysisService(prefs, keyStore)
    val chatService = ChatService(prefs, keyStore)
    val speechService = SpeechService(prefs, keyStore)

    val widgetSnapshotWriter = WidgetSnapshotWriter(app, prefs, foodRepository, profileRepository)
    val testDataSeeder = TestDataSeeder(this)

    /**
     * App-scoped flag set by [HomeViewModel] while a food analysis request is
     * in flight. The bottom nav reads this so the bar can hide during the
     * AnalyzingOverlay (matches iOS, where the analyzing sheet covers the
     * tab bar).
     */
    val analyzingFood: MutableStateFlow<Boolean> = MutableStateFlow(false)

    private var adaptiveGoalsRefreshInFlight = false

    @Volatile
    private var healthReadSyncInFlight = false

    /**
     * Pull external weight + body-fat readings FROM Health Connect into the app (e.g. a
     * Withings scale that writes weigh-ins to Health Connect). Runs on app foreground and
     * right after the user connects/grants. Read-direction only — gated per metric on READ
     * permission, so a user who granted read but not write still gets their data imported
     * (issue #91). Incremental via a persisted changes token, with a one-time historical
     * backfill when there's no token yet; imports are deduped, so re-runs are harmless.
     */
    suspend fun syncHealthConnectReads() {
        if (healthReadSyncInFlight) return
        if (!prefs.healthConnectEnabled.first()) return
        if (!health.isAvailable()) return
        val caps = health.capabilities()
        if (!caps.weightRead && !caps.bodyFatRead) return

        healthReadSyncInFlight = true
        try {
            val desiredTypes = buildSet {
                if (caps.weightRead) add(HEALTH_READ_TYPE_WEIGHT)
                if (caps.bodyFatRead) add(HEALTH_READ_TYPE_BODY_FAT)
            }
            // If a read type was granted AFTER the token was seeded, the existing token never
            // observes it. Drop the token so we re-enter the backfill branch and import that
            // metric's history + re-seed a token covering everything now granted.
            if (!prefs.healthChangesTokenTypes.first().containsAll(desiredTypes)) {
                prefs.clearHealthChangesToken()
            }

            val token = prefs.healthChangesToken.first()
            if (token == null) {
                // First sync: backfill recent history (two years) so existing scale data shows up.
                val now = Instant.now()
                val from = now.minus(Duration.ofDays(730))
                if (caps.weightRead) {
                    weightRepository.importExternalWeights(health.readWeights(from, now))
                }
                if (caps.bodyFatRead) {
                    bodyFatRepository.importExternalBodyFats(health.readBodyFats(from, now))
                }
                // Seed a token covering only the types we can actually read.
                val recordTypes = buildSet {
                    if (caps.weightRead) add(androidx.health.connect.client.records.WeightRecord::class)
                    if (caps.bodyFatRead) add(androidx.health.connect.client.records.BodyFatRecord::class)
                }
                health.getChangesToken(recordTypes)?.let {
                    prefs.setHealthChangesToken(it)
                    prefs.setHealthChangesTokenTypes(desiredTypes)
                }
            } else {
                var next: String? = null
                if (caps.weightRead) {
                    val result = health.consumeWeightChanges(token)
                    if (result == null) { prefs.clearHealthChangesToken(); return }
                    weightRepository.importExternalWeights(result.first)
                    next = result.second
                }
                if (caps.bodyFatRead) {
                    val result = health.consumeBodyFatChanges(token)
                    if (result == null) { prefs.clearHealthChangesToken(); return }
                    bodyFatRepository.importExternalBodyFats(result.first)
                    next = result.second ?: next
                }
                next?.let { prefs.setHealthChangesToken(it) }
            }
        } finally {
            healthReadSyncInFlight = false
        }
    }

    /**
     * Energy Burn toggle resolved to a number: the user's measured maintenance from Health Connect
     * (14-day active + basal average), or null when Energy Burn is off, Health is unavailable, or
     * there isn't enough data. Single source consulted by both manual Recalculate and Adaptive.
     */
    suspend fun measuredEnergyTdeeIfEnabled(profile: UserProfile): Int? {
        if (!prefs.healthEnergyGoalsEnabled.first()) return null
        if (!prefs.healthConnectEnabled.first()) return null
        if (!health.isAvailable() || !health.hasEnergyRead()) return null
        val summary = runCatching { health.readRecentEnergySummary(days = 14) }.getOrNull() ?: return null
        return summary.totalAverageCalories ?: (profile.bmr.roundToInt() + summary.activeAverageCalories)
    }

    /**
     * Adaptive Goals: automatically re-runs the FULL AI goal calculation (the same one the
     * Recalculate button uses) about once a week, from the latest logged food + weight trend
     * (hit-and-trial) and — when Energy Burn is on — the measured Health maintenance anchor.
     * Silent and non-destructive on AI failure (keeps existing goals; marks checked so it does not
     * retry on every app open). Protein is pinned to the activity multiplier, like manual recalc.
     */
    suspend fun refreshAdaptiveGoalsIfNeeded(force: Boolean = false): AdaptiveGoalResult? {
        if (adaptiveGoalsRefreshInFlight) return null
        adaptiveGoalsRefreshInFlight = true
        try {
            if (!prefs.adaptiveGoalsEnabled.first()) return null

            val today = LocalDate.now()
            if (!force && !shouldCheckAdaptiveGoals(prefs.adaptiveGoalsLastCheckDay.first(), today)) {
                return null
            }

            val profile = profileRepository.current() ?: return null
            val heightMetric = prefs.heightUnit.first() == "cm"
            val weightMetric = prefs.weightUnit.first() == "kg"
            val measuredTdee = measuredEnergyTdeeIfEnabled(profile)
            val forecast = WeightAnalysisService.compute(
                weights = weightRepository.entries.first(),
                foods = foodRepository.entries.first(),
                profile = profile
            )
            val result = runCatching {
                foodAnalysis.calculateGoals(profile, forecast, heightMetric, weightMetric, measuredTdee, bodyMeasurementRepository.latestSnapshot())
            }.getOrNull()
            // Mark checked on success OR AI failure so a misconfigured provider isn't hit on every
            // foreground; the weekly cadence simply resumes next week.
            prefs.setAdaptiveGoalsLastCheckDay(today.toString())
            if (result == null) return null

            prefs.saveAdaptiveGoalPreviousTargetsIfNeeded(profile)
            val next = profile.recalculatedFromFormulas().copy(
                customCalories = result.calories,
                customProtein = result.protein,
                customCarbs = result.carbs,
                customFat = result.fat
            )
            profileRepository.save(next)
            return AdaptiveGoalResult(
                profile = next,
                changed = true,
                updatedCalories = result.calories,
                message = "Updated to ${result.calories} kcal from your latest data." + (result.reason?.let { " $it" } ?: "")
            )
        } finally {
            adaptiveGoalsRefreshInFlight = false
        }
    }

    private fun shouldCheckAdaptiveGoals(lastCheckDay: String?, today: LocalDate): Boolean {
        val lastCheck = lastCheckDay?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            ?: return true
        return !lastCheck.plusDays(7).isAfter(today)
    }
}
