package com.apoorvdarshan.calorietracker.services.ai

import com.apoorvdarshan.calorietracker.data.KeyStore
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.BodyMeasurement
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.OptionalNutrientGoals
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.services.WeightForecast
import com.apoorvdarshan.calorietracker.services.health.HealthEnergySummary
import kotlinx.coroutines.flow.first
import kotlin.math.roundToInt
import okhttp3.OkHttpClient
import java.util.Locale

/**
 * Single-shot food / text / nutrition-label analysis. Port of iOS GeminiService.
 * Routes the call to the right per-format client based on the user's selected provider.
 */
class FoodAnalysisService(
    private val prefs: PreferencesStore,
    private val keyStore: KeyStore,
    private val okHttp: OkHttpClient = defaultClient
) {

    suspend fun estimateOptionalNutrientGoals(profile: UserProfile?): OptionalNutrientGoals {
        val profileContext = profile?.let {
            """
                Profile:
                - age: ${it.age}
                - gender: ${it.gender.name.lowercase()}
                - height_cm: ${String.format(java.util.Locale.US, "%.1f", it.heightCm)}
                - weight_kg: ${String.format(java.util.Locale.US, "%.1f", it.weightKg)}
                - activity_level: ${it.activityLevel.name.lowercase()}
                - weight_goal: ${it.goal.name.lowercase()}
                - daily_calories: ${it.effectiveCalories}
                - daily_protein_g: ${it.effectiveProtein}
                - daily_carbs_g: ${it.effectiveCarbs}
                - daily_fat_g: ${it.effectiveFat}
            """.trimIndent()
        } ?: "No user profile is available. Use conservative general adult defaults."
        val prompt = """
            Estimate practical daily goals for nutrients outside the app's calorie/protein/carbs/fat calculator.

            $profileContext

            Return ONLY JSON in this exact shape:
            {"sugar":50,"added_sugar":25,"fiber":30,"saturated_fat":20,"cholesterol":300,"sodium":2300,"potassium":3500,"trans_fat":0,"calcium":1000,"iron":18,"magnesium":400,"zinc":11,"vitamin_a":900,"vitamin_c":90,"vitamin_d":20,"vitamin_b12":3,"vitamin_e":15,"vitamin_k":120,"folate":400,"omega_3":2}

            Rules:
            - Do not return calories, protein, carbs, or fat.
            - Keep this independent from macro calculation; only estimate the listed optional nutrient goals.
            - sugar, added_sugar, fiber, saturated_fat, trans_fat, and omega_3 are grams per day.
            - cholesterol, sodium, potassium, calcium, iron, magnesium, zinc, vitamin_c, and vitamin_e are milligrams per day.
            - vitamin_a, vitamin_d, vitamin_b12, vitamin_k, and folate are micrograms per day.
            - Use realistic non-medical nutrition targets for an average adult adjusted by profile and calorie target.
            - Keep added_sugar and saturated_fat near or below 10% of calories when possible.
            - Fiber should generally scale around 14g per 1000 kcal, with a practical adult range.
            - Sodium should usually stay near general adult guidance unless the profile strongly suggests otherwise.
            - Potassium, calcium, iron, magnesium, zinc, vitamins, folate, and omega-3 should use practical daily targets, not food-log intake.
            - Use integers only.
        """.trimIndent()
        return FoodJsonParser.parseOptionalNutrientGoals(callAi(prompt, imageBytes = null))
    }

    suspend fun suggestHealthEnergyGoals(
        profile: UserProfile,
        energy: HealthEnergySummary,
        heightMetric: Boolean,
        weightMetric: Boolean
    ): HealthEnergyGoalSuggestion {
        val weight = if (weightMetric) {
            String.format(java.util.Locale.US, "%.1f kg", profile.weightKg)
        } else {
            String.format(java.util.Locale.US, "%.1f lb", profile.weightKg * 2.20462)
        }
        val height = if (heightMetric) {
            String.format(java.util.Locale.US, "%.0f cm", profile.heightCm)
        } else {
            String.format(java.util.Locale.US, "%.1f in", profile.heightCm / 2.54)
        }
        val bodyFat = profile.bodyFatPercentage
            ?.let { "${(it * 100).toInt()}%" }
            ?: "not set"
        val goalWeight = profile.goalWeightKg?.let { kg ->
            if (weightMetric) String.format(java.util.Locale.US, "%.1f kg", kg)
            else String.format(java.util.Locale.US, "%.1f lb", kg * 2.20462)
        } ?: "not set"
        val healthTotalLine = energy.totalAverageCalories
            ?.let { "$it kcal/day from active + basal energy" }
            ?: "total energy unavailable; estimate total burn from app BMR + Health Connect active energy"

        val prompt = """
            You are setting a daily calorie target for a food tracking app.
            Return ONLY valid JSON with these exact keys:
            {"calories":2000,"reason":"Short reason under 100 characters"}

            Use Health Connect energy as the primary activity signal, but keep the app's existing formula as a sanity check.
            If Health Connect total energy is unavailable, estimate total daily burn from app BMR plus Health Connect active energy.
            Apply the user's weight goal and weekly change preference to choose the calorie target.
            Keep calories practical for a consumer food tracker: 800-6000 kcal.
            Do not set protein, carbs, or fat; the app keeps macros unlocked on auto-balance unless the user manually locks them.
            Use integers only for calories. Do not include any other keys.

            User profile:
            - Gender: ${profile.gender.name.lowercase()}
            - Age: ${profile.age}
            - Height: $height
            - Weight: $weight
            - Activity level setting: ${profile.activityLevel.name.lowercase()}
            - Weight goal: ${profile.goal.name.lowercase()}
            - Weekly change preference: ${profile.weeklyChangeKg?.let { String.format(java.util.Locale.US, "%.2f kg/week", it) } ?: "maintain"}
            - Goal weight: $goalWeight
            - Body fat: $bodyFat

            Existing app formula:
            - BMR: ${profile.bmr.toInt()} kcal/day
            - TDEE: ${profile.tdee.toInt()} kcal/day
            - Formula calorie target: ${profile.dailyCalories} kcal/day

            Health Connect energy from ${energy.daysUsed} of the last ${energy.requestedDays} completed days:
            - Active energy average: ${energy.activeAverageCalories} kcal/day
            - Basal energy average: ${energy.basalAverageCalories?.let { "$it kcal/day" } ?: "not available"}
            - Health total: $healthTotalLine
        """.trimIndent()
        return FoodJsonParser.parseHealthEnergyGoalSuggestion(callAi(prompt, imageBytes = null))
    }

    /**
     * AI-driven daily target calculation (port of iOS GeminiService.calculateGoals). Sends the
     * app's formulas, the profile, and — when available — recent logged intake + observed weight
     * trend so the model can estimate true maintenance empirically (hit-and-trial) rather than
     * trusting the formula alone. Caller falls back to the formula when this throws.
     */
    suspend fun calculateGoals(
        profile: UserProfile,
        forecast: WeightForecast?,
        heightMetric: Boolean,
        weightMetric: Boolean,
        measuredTdee: Int? = null,
        measurement: BodyMeasurement? = null
    ): GoalCalculation {
        val weight = if (weightMetric) String.format(Locale.US, "%.1f kg", profile.weightKg)
            else String.format(Locale.US, "%.1f lb", profile.weightKg * 2.20462)
        val height = if (heightMetric) String.format(Locale.US, "%.0f cm", profile.heightCm)
            else String.format(Locale.US, "%.1f in", profile.heightCm / 2.54)
        val bodyFat = profile.bodyFatPercentage?.let { "${(it * 100).toInt()}%" } ?: "not set"
        val goalWeight = profile.goalWeightKg?.let { kg ->
            if (weightMetric) String.format(Locale.US, "%.1f kg", kg) else String.format(Locale.US, "%.1f lb", kg * 2.20462)
        } ?: "not set"
        val weekly = profile.weeklyChangeKg?.let { String.format(Locale.US, "%.2f kg/week", it) } ?: "not set (maintain)"
        val bmrMethod = if (profile.usesBodyFatForBMR) "Katch-McArdle (body fat known and enabled)" else "Mifflin-St Jeor"

        val observedSection = buildString {
            if (forecast != null && forecast.hasEnoughData) {
                appendLine()
                appendLine("OBSERVED DATA — from the user's OWN logs (prefer this over the formula when reliable):")
                appendLine("- Logged intake: avg ${forecast.avgDailyCalories} kcal/day across ${forecast.daysOfFoodData} logged days")
                val obs = forecast.observedWeeklyChangeKg
                if (obs != null) {
                    val obsStr = if (weightMetric) String.format(Locale.US, "%+.2f kg/week", obs)
                        else String.format(Locale.US, "%+.2f lb/week", obs * 2.20462)
                    val empiricalTdee = forecast.avgDailyCalories - (obs * 7700.0 / 7.0).roundToInt()
                    appendLine("- Observed weight trend: $obsStr from ${forecast.weightEntriesUsed} weigh-ins")
                    appendLine("- Implied actual maintenance (logged intake minus the weekly change): ~$empiricalTdee kcal/day")
                } else {
                    appendLine("- Observed weight trend: not enough weigh-ins yet to measure")
                }
                appendLine("- Formula TDEE for comparison: ${forecast.tdee} kcal/day")
                if (forecast.trendsDisagree) {
                    appendLine("- WARNING: logged intake and the real weight trend DISAGREE — the user is likely under-logging. Trust the weight trend over raw logged calories.")
                }
                append("HIT-AND-TRIAL: when this observed data is reliable, estimate true maintenance from intake and the real weight trend, then apply the goal + weekly-change target to THAT maintenance instead of the formula TDEE. If data is thin or trends disagree, lean on the formula/weight trend accordingly. Keep calories within 800-6000.")
            }
        }

        // Energy Burn toggle: when on (and Health Connect has enough data) this measured
        // maintenance replaces the formula TDEE as the calorie anchor.
        val measuredSection = if (measuredTdee != null) {
            "\nMEASURED ENERGY BURN — the user's REAL maintenance from Health Connect (14-day average of active + basal calories). Use THIS as the maintenance/TDEE anchor INSTEAD of the formula TDEE: $measuredTdee kcal/day. Apply the weight goal and weekly-change adjustment to this measured maintenance. Still sanity-check it against the observed weight trend."
        } else ""

        // Optional tape-measure circumferences + derived metrics. Extra signal only — never overrides
        // the formulas. A shrinking waist alongside flat/declining weight implies recomposition.
        val measurementsSummary = measurement?.promptSummary(profile.gender, profile.heightCm)
        val measurementsSection = if (measurementsSummary != null) {
            "\nBODY MEASUREMENTS — the user's latest tape-measure circumferences and the metrics derived from them. Use as extra signal: a shrinking waist with steady or falling weight suggests recomposition, so keep protein high and don't over-cut. Treat the US-Navy body-fat figure as a rough estimate, not exact.\n$measurementsSummary"
        } else ""

        val prompt = """
            You are the goal calculator for a calorie & macro tracking app. Using the FORMULAS, the USER PROFILE, and any OBSERVED DATA below, compute the user's daily targets.
            Return ONLY valid JSON with these exact keys (integers, plus a short reason):
            {"calories":2000,"protein":150,"carbs":200,"fat":60,"reason":"Short reason under 100 characters"}

            Use the app's formulas as the basis. When OBSERVED DATA is present and reliable, prefer the empirical maintenance estimate it implies over the formula TDEE.
            FORMULAS
            - BMR (Mifflin-St Jeor): base = 10*weightKg + 6.25*heightCm - 5*age - 161; if male add 166; female/other use base.
            - BMR (Katch-McArdle, used when body fat is known and enabled): 370 + 21.6 * (1 - bodyFatFraction) * weightKg.
            - TDEE = BMR * activity multiplier. Multipliers: sedentary 1.2, light 1.375, moderate 1.465, active 1.55, very active 1.725, extra active 1.9.
            - Calorie target = TDEE + adjustment. adjustment = 0 for maintain; lose: -(weeklyChangeKg*7000/7); gain: +(weeklyChangeKg*7000/7).
            - Protein: aim NEAR the formula protein value shown below — that value is the activity multiplier (sedentary 0.8, light 1.2, moderate 1.6, active 1.8, very active 2.0, extra active 2.2 g/kg; +0.2 if losing) applied to the user's ${if (profile.bodyFatPercentage != null) "lean body mass" else "full bodyweight"}. You may choose a value within about ±15% of it based on the weight goal and the observed history (lean toward the higher end during a calorie deficit to preserve muscle). Do NOT scale protein down just to fit a lower calorie target.
            - Fat: 0.6 g/kg of full bodyweight.
            - Carbs: the calories remaining after protein (4 kcal/g) and fat (9 kcal/g), divided by 4. Keep 4*protein + 4*carbs + 9*fat approximately equal to calories.
            BMR method in effect for this user: $bmrMethod.
            Keep calories within 800-6000. Use integers only. Output no keys other than calories, protein, carbs, fat, reason.

            USER PROFILE
            - Gender: ${profile.gender.name.lowercase()}
            - Age: ${profile.age}
            - Height: $height
            - Weight: $weight
            - Body fat: $bodyFat
            - Activity level: ${profile.activityLevel.name.lowercase()}
            - Weight goal: ${profile.goal.name.lowercase()}
            - Weekly change preference: $weekly
            - Goal weight: $goalWeight

            APP FORMULA REFERENCE (already computed deterministically — use as the anchor)
            - BMR: ${profile.bmr.toInt()} kcal/day
            - TDEE: ${profile.tdee.toInt()} kcal/day
            - Formula calorie target: ${profile.dailyCalories} kcal/day
            - Formula macros: ${profile.proteinGoal} g protein, ${profile.carbsGoal} g carbs, ${profile.fatGoal} g fat
            $measuredSection
            $measurementsSection
            $observedSection
        """.trimIndent()
        return FoodJsonParser.parseGoalCalculation(callAi(prompt, imageBytes = null))
    }

    suspend fun suggestMealWhatIf(
        entry: FoodEntry,
        dayEntries: List<FoodEntry>,
        profile: UserProfile,
        weightMetric: Boolean
    ): String {
        val beforeCalories = dayEntries.sumOf { it.calories }
        val beforeProtein = dayEntries.sumOf { it.protein }
        val beforeCarbs = dayEntries.sumOf { it.carbs }
        val beforeFat = dayEntries.sumOf { it.fat }
        val afterCalories = beforeCalories + entry.calories
        val afterProtein = beforeProtein + entry.protein
        val afterCarbs = beforeCarbs + entry.carbs
        val afterFat = beforeFat + entry.fat
        val weight = if (weightMetric) {
            String.format(Locale.US, "%.1f kg", profile.weightKg)
        } else {
            String.format(Locale.US, "%.1f lb", profile.weightKg * 2.20462)
        }
        val bodyFat = profile.bodyFatPercentage
            ?.let { "${(it * 100).toInt()}%" }
            ?: "not set"
        fun grams(value: Double) = String.format(Locale.US, "%.1fg", value)

        val prompt = """
            The user tapped "What if?" before logging a meal in a nutrition tracker.
            Return 2-4 short sentences, no markdown, under 90 words.
            Explain how this meal changes today's calorie/protein/carbs/fat totals compared with the user's goals, then give one practical action: log it as-is, reduce portion, replace part of it, or adjust the next meal.
            Stay practical and non-medical.

            User profile:
            - Gender: ${profile.gender.name.lowercase()}
            - Age: ${profile.age}
            - Weight: $weight
            - Activity level: ${profile.activityLevel.name.lowercase()}
            - Weight goal: ${profile.goal.name.lowercase()}
            - Body fat: $bodyFat

            Daily goals:
            - Calories: ${profile.effectiveCalories} kcal
            - Protein: ${profile.effectiveProtein}g
            - Carbs: ${profile.effectiveCarbs}g
            - Fat: ${profile.effectiveFat}g

            Today's totals before this meal:
            - Calories: $beforeCalories kcal
            - Protein: ${grams(beforeProtein)}
            - Carbs: ${grams(beforeCarbs)}
            - Fat: ${grams(beforeFat)}

            Meal being reviewed:
            - Name: ${entry.name}
            - Calories: ${entry.calories} kcal
            - Protein: ${grams(entry.protein)}
            - Carbs: ${grams(entry.carbs)}
            - Fat: ${grams(entry.fat)}

            Today's totals if logged:
            - Calories: $afterCalories kcal
            - Protein: ${grams(afterProtein)}
            - Carbs: ${grams(afterCarbs)}
            - Fat: ${grams(afterFat)}
        """.trimIndent()
        return callAi(prompt, imageBytes = null).trim()
    }

    suspend fun analyzeText(description: String): FoodAnalysis {
        val prompt = """
            Estimate the nutritional content for: $description
            Parse any quantities, brands, and multiple items from the text. If a brand is mentioned, use that brand's known nutritional data. If multiple items are described, sum up the total nutrition.
            Respond ONLY with JSON:
            {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"emoji":"<single specific food emoji>","sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"trans_fat":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
            Calories are integers. Protein/carbs/fat are decimal gram values when needed. serving_size_grams is the estimated total weight in grams. Nutrients are numbers: sugar/fiber/sat fat/mono fat/poly fat/trans fat/omega-3 in grams; cholesterol/sodium/potassium/calcium/iron/magnesium/zinc/vitamin C/vitamin E in milligrams; vitamin A/vitamin D/vitamin B12/vitamin K/folate in micrograms.
            The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
            unit_options is required when the text names an obvious non-gram serving unit, and optional otherwise. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. Do not copy any sample number; use the quantity stated or clearly implied by the meal. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
            For "emoji" pick the single most specific food emoji that depicts this dish — e.g. 🥚 for eggs, 🍕 for pizza, 🍎 for an apple, 🥗 for a salad, 🍔 for a burger, 🍜 for ramen, 🍰 for cake, 🥑 for avocado, ☕ for coffee, 🍣 for sushi. Only fall back to 🍽️ when the food truly cannot be represented by any specific emoji. Use null for any nutrient you cannot estimate.
        """.trimIndent()
        val analysis = FoodJsonParser.parseFood(callAi(prompt, null))
        return addingFallbackServingUnits(analysis, imageBytes = null, description = description)
    }

    suspend fun analyzeAuto(imageBytes: ByteArray): FoodAnalysis {
        val prompt = """
            Analyze this image. It could be either a photo of food OR a nutrition facts label.

            If it's a food photo: identify the food and estimate nutritional content for the serving shown.
            If it's a nutrition label: read the values and calculate for one serving size as listed on the label.

            Respond ONLY with JSON:
            {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"trans_fat":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
            Calories are integers. Protein/carbs/fat are decimal gram values when needed. serving_size_grams is the estimated weight in grams of the serving. Nutrients are numbers: sugar/fiber/sat fat/mono fat/poly fat/trans fat/omega-3 in grams; cholesterol/sodium/potassium/calcium/iron/magnesium/zinc/vitamin C/vitamin E in milligrams; vitamin A/vitamin D/vitamin B12/vitamin K/folate in micrograms.
            The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
            unit_options is required for obvious non-gram units visible in the image or label. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. For a whole or mostly-whole divisible food like cake, pie, or pizza, count the visible pieces/slices and derive grams_per_unit from serving_size_grams / quantity. If N slices are visible, return quantity N. Use quantity 1 only when a single piece/slice is actually the analyzed portion. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
            Use null for any nutrient you cannot estimate.
        """.trimIndent()
        val analysis = FoodJsonParser.parseFood(callAi(prompt, imageBytes))
        return addingFallbackServingUnits(analysis, imageBytes = imageBytes, description = null)
    }

    suspend fun analyzeFood(imageBytes: ByteArray, description: String? = null): FoodAnalysis {
        var prompt = """
            Analyze this food image. Identify the food and estimate its nutritional content.
            Respond ONLY with JSON:
            {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"trans_fat":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
            Calories are integers. Protein/carbs/fat are decimal gram values when needed. serving_size_grams is the estimated weight in grams of the serving shown. Nutrients are numbers: sugar/fiber/sat fat/mono fat/poly fat/trans fat/omega-3 in grams; cholesterol/sodium/potassium/calcium/iron/magnesium/zinc/vitamin C/vitamin E in milligrams; vitamin A/vitamin D/vitamin B12/vitamin K/folate in micrograms.
            The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
            unit_options is required for obvious non-gram units visible in the food. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. For a whole or mostly-whole divisible food like cake, pie, or pizza, count the visible pieces/slices and derive grams_per_unit from serving_size_grams / quantity. If N slices are visible, return quantity N. Use quantity 1 only when a single piece/slice is actually the analyzed portion. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
            Give your best estimate for the visible food amount shown in the image. For whole/mostly-whole cakes, pizzas, pies, loaves, or similar foods, estimate the total visible item/remaining item weight rather than defaulting to one slice. Use null for any nutrient you cannot estimate.
        """.trimIndent()
        if (!description.isNullOrBlank()) {
            prompt += "\n\nAdditional context from the user about this meal: $description\nUse this context to improve accuracy of identification, portion size, and nutrition estimates."
        }
        val analysis = FoodJsonParser.parseFood(callAi(prompt, imageBytes))
        return addingFallbackServingUnits(analysis, imageBytes = imageBytes, description = description)
    }

    suspend fun analyzeFood(imageBytesList: List<ByteArray>, description: String? = null): FoodAnalysis {
        var prompt = """
            Analyze these food images together as one meal logging request. They may show different angles of the same food, separate ingredients, kitchen-scale readings, packaging, or nutrition labels.
            Use every image once. Do not double-count the same food shown from multiple angles. When separate ingredients are shown, combine their nutrition into one meal total. Read visible scale weights and nutrition labels when available; prefer those measurements over visual portion estimates.
            Respond ONLY with JSON:
            {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"trans_fat":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
            Calories are integers. Protein/carbs/fat are decimal gram values when needed. serving_size_grams is the estimated weight in grams of the serving shown. Nutrients are numbers: sugar/fiber/sat fat/mono fat/poly fat/trans fat/omega-3 in grams; cholesterol/sodium/potassium/calcium/iron/magnesium/zinc/vitamin C/vitamin E in milligrams; vitamin A/vitamin D/vitamin B12/vitamin K/folate in micrograms.
            The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
            unit_options is required for obvious non-gram units visible in the food. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
            Do not double-count the meal across images. Treat the photos as multiple views of the same item unless there are clearly separate foods.
            Use null for any nutrient you cannot estimate.
        """.trimIndent()
        if (!description.isNullOrBlank()) {
            prompt += "\n\nAdditional context from the user about this complete meal: $description\nApply this note to the full image set."
        }
        val images = imageBytesList.filter { it.isNotEmpty() }
        if (images.isEmpty()) throw AiError.InvalidResponse
        val analysis = FoodJsonParser.parseFood(callAi(prompt, images))
        return addingFallbackServingUnits(analysis, imageBytes = images.first(), description = description)
    }

    suspend fun analyzeNutritionLabel(imageBytes: ByteArray, servingGrams: Double): FoodAnalysis {
        val prompt = """
            Read this nutrition facts label and extract per-100g values. If the label only shows per-serving, normalize using the serving size listed on the label.
            Respond ONLY with JSON:
            {"name":"...","calories_per_100g":0.0,"protein_per_100g":0.0,"carbs_per_100g":0.0,"fat_per_100g":0.0,"serving_size_grams":0.0,"sugar_per_100g":0.0,"added_sugar_per_100g":0.0,"fiber_per_100g":0.0,"saturated_fat_per_100g":0.0,"monounsaturated_fat_per_100g":0.0,"polyunsaturated_fat_per_100g":0.0,"cholesterol_per_100g":0.0,"sodium_per_100g":0.0,"potassium_per_100g":0.0,"trans_fat_per_100g":0.0,"calcium_per_100g":0.0,"iron_per_100g":0.0,"magnesium_per_100g":0.0,"zinc_per_100g":0.0,"vitamin_a_per_100g":0.0,"vitamin_c_per_100g":0.0,"vitamin_d_per_100g":0.0,"vitamin_b12_per_100g":0.0,"vitamin_e_per_100g":0.0,"vitamin_k_per_100g":0.0,"folate_per_100g":0.0,"omega_3_per_100g":0.0,"unit_options":[]}
            The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is visible.
            All values should be numbers. If serving size or any nutrient is not available, use null. unit_options is required when a non-gram label serving unit is visible, such as slice, piece, tbsp, cup, ml, fl oz, can, or packet. Do not copy any sample number; use the quantity shown on the label. Use [] only when no non-gram unit is visible. Do not include g/grams in unit_options.
        """.trimIndent()
        val analysis = FoodJsonParser.parseLabel(callAi(prompt, imageBytes))
        return addingFallbackServingUnits(analysis, imageBytes).scaled(servingGrams)
    }

    // -- Internal dispatch ------------------------------------------------

    private suspend fun callAi(prompt: String, imageBytes: ByteArray?): String {
        return callAi(prompt, imageBytes?.let { listOf(it) }.orEmpty())
    }

    private suspend fun callAi(prompt: String, imageBytesList: List<ByteArray>): String {
        val context = prefs.userContext.first()
        val finalPrompt = if (context.isNotBlank()) "User context (apply to every analysis): $context\n\n$prompt" else prompt

        val primary = prefs.selectedAIProvider.first()
        val primaryModel = primary.supportedModelOrDefault(prefs.selectedAIModel.first())
        val primaryBaseUrl = prefs.customBaseUrl(primary).first()?.takeIf { it.isNotEmpty() } ?: primary.baseUrl
        val primaryKey = keyStore.apiKey(primary)
        if (primary.requiresApiKey && primaryKey.isNullOrEmpty()) throw AiError.NoApiKey
        val maxTokens = prefs.maxResponseTokens.first()
        val requestTimeoutSeconds = prefs.aiRequestTimeoutSeconds.first()
        val uploadImages = imageBytesList.map(FoodImagePreprocessor::prepareForUpload)

        return try {
            dispatch(primary, primaryModel, primaryBaseUrl, primaryKey, finalPrompt, uploadImages, maxTokens, requestTimeoutSeconds)
        } catch (primaryError: Throwable) {
            val fallback = currentFallbackConfig(primary, primaryModel) ?: throw primaryError
            dispatch(fallback.provider, fallback.model, fallback.baseUrl, fallback.apiKey, finalPrompt, uploadImages, maxTokens, requestTimeoutSeconds)
        }
    }

    private suspend fun addingFallbackServingUnits(
        analysis: FoodAnalysis,
        imageBytes: ByteArray?,
        description: String?
    ): FoodAnalysis {
        if (analysis.servingUnitOptions.isNotEmpty()) return analysis
        val options = runCatching {
            inferServingUnitOptions(
                name = analysis.name,
                servingSizeGrams = analysis.servingSizeGrams,
                imageBytes = imageBytes,
                description = description
            )
        }.getOrDefault(emptyList())
        if (options.isEmpty()) return analysis
        val selected = options.first()
        return analysis.copy(
            servingUnitOptions = options,
            selectedServingUnit = selected.unit,
            selectedServingQuantity = selected.quantityFor(analysis.servingSizeGrams)
        )
    }

    private suspend fun addingFallbackServingUnits(
        analysis: NutritionLabelAnalysis,
        imageBytes: ByteArray
    ): NutritionLabelAnalysis {
        if (analysis.servingUnitOptions.isNotEmpty()) return analysis
        val servingSizeGrams = analysis.servingSizeGrams ?: return analysis
        val options = runCatching {
            inferServingUnitOptions(
                name = analysis.name,
                servingSizeGrams = servingSizeGrams,
                imageBytes = imageBytes,
                description = null
            )
        }.getOrDefault(emptyList())
        if (options.isEmpty()) return analysis
        return analysis.copy(servingUnitOptions = options)
    }

    private suspend fun inferServingUnitOptions(
        name: String,
        servingSizeGrams: Double,
        imageBytes: ByteArray?,
        description: String?
    ): List<com.apoorvdarshan.calorietracker.models.ServingUnitOption> {
        val context = description?.trim()?.takeIf { it.isNotEmpty() }
        val contextLine = context?.let { "\nUser context: $it" }.orEmpty()
        val prompt = """
            The previous food analysis returned grams only. Infer non-gram serving unit options for the same food and amount.

            Food: $name
            Total grams for the analyzed amount: ${String.format(java.util.Locale.US, "%.1f", servingSizeGrams)}$contextLine

            Return ONLY JSON:
            {"unit_options":[{"unit":"slice","quantity":8.0,"grams_per_unit":45.0}]}

            Rules:
            - Replace the sample numbers with the actual best estimate. Do not copy 8 or 45 unless they fit the food.
            - If the image shows countable portions, count visible pieces/slices. For pizza, cake, pie, bread, cookies, fruit pieces, nuggets, or sweets, use slice or piece.
            - For liquids or pourable foods like milk, juice, soup, smoothies, dal, sauces, or yogurt, use ml when the volume is clearer than a count.
            - For spooned foods like peanut butter, honey, oil, chutney, or ghee, use tbsp or tsp.
            - For packaged foods/drinks, use can, packet, bar, scoop, or bowl only when that unit is visible or strongly implied.
            - grams_per_unit is grams for one unit. For countable units, use total grams / visible quantity. For ml, use grams per ml.
            - Return [] only if no non-gram unit is apparent.

            Good outputs:
            {"unit_options":[{"unit":"slice","quantity":8.0,"grams_per_unit":45.0}]}
            {"unit_options":[{"unit":"ml","quantity":250.0,"grams_per_unit":1.03},{"unit":"cup","quantity":1.0,"grams_per_unit":250.0}]}
            {"unit_options":[{"unit":"tbsp","quantity":2.0,"grams_per_unit":16.0}]}
            {"unit_options":[{"unit":"can","quantity":1.0,"grams_per_unit":330.0}]}
            {"unit_options":[{"unit":"piece","quantity":5.0,"grams_per_unit":18.0}]}
        """.trimIndent()
        return FoodJsonParser.parseServingUnitOptions(callAi(prompt, imageBytes), servingSizeGrams)
    }

    private suspend fun dispatch(
        provider: AIProvider,
        model: String,
        baseUrl: String,
        apiKey: String?,
        prompt: String,
        imageBytesList: List<ByteArray>,
        maxTokens: Int,
        requestTimeoutSeconds: Int
    ): String {
        if (baseUrl.isEmpty()) throw AiError.InvalidUrl(baseUrl)
        if (provider.requiresApiKey && apiKey.isNullOrEmpty()) throw AiError.NoApiKey
        val requestClient = clientForProvider(okHttp, provider, requestTimeoutSeconds)
        return when (provider.apiFormat) {
            AIProvider.ApiFormat.GEMINI ->
                GeminiClient.analyze(requestClient, baseUrl, model, apiKey!!, prompt, imageBytesList)
            AIProvider.ApiFormat.ANTHROPIC ->
                AnthropicClient.analyze(requestClient, baseUrl, model, apiKey!!, prompt, imageBytesList, maxTokens)
            AIProvider.ApiFormat.OPENAI_COMPATIBLE ->
                OpenAICompatibleClient.analyze(requestClient, baseUrl, model, apiKey, prompt, imageBytesList, provider, maxTokens)
        }
    }

    private suspend fun currentFallbackConfig(
        primary: AIProvider,
        primaryModel: String
    ): FallbackConfig? {
        if (!prefs.fallbackEnabled.first()) return null
        val provider = prefs.selectedFallbackProvider.first()
        val model = provider.supportedModelOrDefault(prefs.selectedFallbackModel.first())
        // Fallback identical to primary would be a pointless retry of the same call.
        if (provider == primary && model == primaryModel) return null
        val key = keyStore.apiKey(provider)
        if (provider.requiresApiKey && key.isNullOrEmpty()) return null
        val baseUrl = prefs.customBaseUrl(provider).first()?.takeIf { it.isNotEmpty() } ?: provider.baseUrl
        if (baseUrl.isEmpty()) return null
        return FallbackConfig(provider, model, baseUrl, key)
    }

    private data class FallbackConfig(
        val provider: AIProvider,
        val model: String,
        val baseUrl: String,
        val apiKey: String?
    )

    companion object {
        internal fun clientForProvider(
            client: OkHttpClient,
            provider: AIProvider,
            requestTimeoutSeconds: Int
        ): OkHttpClient {
            if (!provider.usesConfigurableRequestTimeout) return client
            val seconds = AIProvider.normalizedRequestTimeoutSeconds(requestTimeoutSeconds).toLong()
            return client.newBuilder()
                .readTimeout(seconds, java.util.concurrent.TimeUnit.SECONDS)
                .writeTimeout(seconds, java.util.concurrent.TimeUnit.SECONDS)
                .build()
        }

        internal val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(20, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
                .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .build()
        }
    }
}
