package com.apoorvdarshan.calorietracker

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.services.MealShare
import com.apoorvdarshan.calorietracker.services.ReviewPrompter
import com.apoorvdarshan.calorietracker.ui.home.ImportSharedMealSheet
import com.apoorvdarshan.calorietracker.ui.navigation.FudAINavHost
import com.apoorvdarshan.calorietracker.ui.theme.AppThemeColor
import com.apoorvdarshan.calorietracker.ui.theme.FudAITheme
import com.google.android.play.core.ktx.launchReview
import com.google.android.play.core.ktx.requestReview
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

open class MainActivity : ComponentActivity() {
    // Shared-meal deep link (issue #107). Non-empty -> the confirm sheet is shown over the app.
    private var pendingSharedMeals by mutableStateOf<List<FoodEntry>>(emptyList())

    /** Decode a `fudai://add-meal` link (if that's what launched us) into pending meals. */
    private fun handleShareIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (!MealShare.handles(uri)) return
        MealShare.meals(uri)?.let { pendingSharedMeals = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }
    override fun onStart() {
        super.onStart()
        lifecycleScope.launch {
            // Adaptive Goals auto-runs the full goal calculation about once a week (Energy Burn,
            // when on, supplies the measured-burn anchor it consumes — separate toggle).
            val container = (application as FudAIApp).container
            container.refreshAdaptiveGoalsIfNeeded()
            // Pull any new external weight / body-fat readings (e.g. a Withings scale)
            // from Health Connect into the app on every foreground (issue #91).
            container.syncHealthConnectReads()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must run before super.onCreate so the system swaps the splash theme
        // back to Theme.FudAI before the first frame, preventing a white flash
        // on cold start. The splash uses a transparent foreground mark over
        // the app's light/dark splash background.
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Launch the Play in-app review card once, right after the first
        // successful food log (see ReviewPrompter). Silently no-ops on devices
        // without Play services or when Play declines to show the card.
        lifecycleScope.launch {
            ReviewPrompter.requestReview.collect { wanted ->
                if (!wanted) return@collect
                ReviewPrompter.consumed()
                delay(1_500)
                runCatching {
                    val manager = ReviewManagerFactory.create(this@MainActivity)
                    val info = manager.requestReview()
                    manager.launchReview(this@MainActivity, info)
                }
            }
        }

        // Support --reset-onboarding launch flag (parallel to iOS CLAUDE.md convention).
        if (intent?.getBooleanExtra("reset_onboarding", false) == true) {
            runBlocking { (application as FudAIApp).container.prefs.setOnboardingCompleted(false) }
            intent.removeExtra("reset_onboarding")
        }

        val container = (application as FudAIApp).container
        // Dev-only seeders for verifying the Progress tab UI without polluting Health Connect.
        // adb shell am start -n com.apoorvdarshan.calorietracker/.MainActivity --ez seed_test_data true
        // adb shell am start -n com.apoorvdarshan.calorietracker/.MainActivity --ez restore_real_data true
        // Extras are removed after handling so Activity.recreate() (used by Delete All
        // Data) doesn't re-fire the same flag on the next onCreate.
        if (intent?.getBooleanExtra("seed_test_data", false) == true) {
            runBlocking { container.testDataSeeder.seedYear() }
            intent.removeExtra("seed_test_data")
        }
        // Focused 30-day weight + body-fat seeder for verifying the v3.2 Body
        // Fat chart + segmented Progress toggle without polluting food data.
        // adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez seed_body_metrics true
        if (intent?.getBooleanExtra("seed_body_metrics", false) == true) {
            runBlocking { container.testDataSeeder.seedBodyMetrics() }
            intent.removeExtra("seed_body_metrics")
        }
        // Long-range variant: 2 years of weight + body-fat for the 1Y / All
        // ranges and the history lists.
        // adb shell am start -n com.apoorvdarshan.calorietracker.debug/com.apoorvdarshan.calorietracker.MainActivity --ez seed_body_metrics_2y true
        if (intent?.getBooleanExtra("seed_body_metrics_2y", false) == true) {
            runBlocking { container.testDataSeeder.seedTwoYearsBodyMetrics() }
            intent.removeExtra("seed_body_metrics_2y")
        }
        if (intent?.getBooleanExtra("restore_real_data", false) == true) {
            runBlocking { container.testDataSeeder.restore() }
            intent.removeExtra("restore_real_data")
        }
        // A fudai://add-meal link may have cold-launched us.
        handleShareIntent(intent)

        val startOnboarding = runBlocking { !container.prefs.hasCompletedOnboarding.first() }
        val initialAppearance = runBlocking { container.prefs.appearanceMode.first() }
        val initialThemeColorKey = runBlocking { container.prefs.appThemeColor.first() }

        // Hold the splash on screen until the saved profile has loaded from
        // DataStore so Home doesn't briefly render its 2000/150/220/70 fallback
        // goal numbers before snapping to the user's real targets. Onboarding
        // doesn't show those numbers, so we let the splash dismiss immediately
        // in that case.
        var contentReady = startOnboarding
        splashScreen.setKeepOnScreenCondition { !contentReady }
        if (!startOnboarding) {
            lifecycleScope.launch {
                container.profileRepository.profile.first { it != null }
                contentReady = true
            }
        }

        setContent {
            val appearance by container.prefs.appearanceMode.collectAsState(initial = initialAppearance)
            val themeColorKey by container.prefs.appThemeColor.collectAsState(initial = initialThemeColorKey)
            val themeColor = AppThemeColor.fromKey(themeColorKey)
            val systemDark = isSystemInDarkTheme()
            val darkTheme = when (appearance) {
                "light" -> false
                "dark" -> true
                else -> systemDark
            }
            FudAITheme(darkTheme = darkTheme, themeColor = themeColor) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    FudAINavHost(container = container, startOnboarding = startOnboarding)

                    if (pendingSharedMeals.isNotEmpty()) {
                        ImportSharedMealSheet(
                            meals = pendingSharedMeals,
                            onAdd = { meals ->
                                lifecycleScope.launch {
                                    meals.forEach { container.foodRepository.addEntry(it) }
                                }
                                pendingSharedMeals = emptyList()
                            },
                            onDismiss = { pendingSharedMeals = emptyList() }
                        )
                    }
                }
            }
        }
    }
}
