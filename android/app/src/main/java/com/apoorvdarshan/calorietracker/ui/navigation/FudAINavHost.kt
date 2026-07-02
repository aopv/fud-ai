package com.apoorvdarshan.calorietracker.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.flow.first
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.services.update.AndroidUpdateChecker
import com.apoorvdarshan.calorietracker.services.update.AndroidUpdateState
import com.apoorvdarshan.calorietracker.ui.coach.CoachScreen
import com.apoorvdarshan.calorietracker.ui.home.HomeScreen
import com.apoorvdarshan.calorietracker.ui.onboarding.OnboardingScreen
import com.apoorvdarshan.calorietracker.ui.progress.BodyMeasurementsScreen
import com.apoorvdarshan.calorietracker.ui.progress.ProgressScreen
import com.apoorvdarshan.calorietracker.ui.settings.CalculationMethodsScreen
import com.apoorvdarshan.calorietracker.ui.settings.OptionalNutrientGoalsScreen
import com.apoorvdarshan.calorietracker.ui.settings.SettingsScreen
import com.apoorvdarshan.calorietracker.ui.workouts.WorkoutsScreen

/**
 * Increments each time the app is opened: 1 on cold launch, then +1 on every
 * return from the background (ON_START after a real ON_STOP). Read by the Home
 * gauge + macro bars to replay their fill-from-zero reveal. It lives above the
 * NavHost, so tab switches (which recompose Home) never change it.
 */
val LocalLaunchFillEpoch = compositionLocalOf { 1 }

@Composable
fun FudAINavHost(
    container: AppContainer,
    startOnboarding: Boolean
) {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    // Hide the bar while a food analysis is in flight so the AnalyzingOverlay
    // is the only thing on screen — matches iOS, where the analyzing sheet
    // covers the tab bar.
    val analyzing by container.analyzingFood.collectAsState()
    val showTabs = currentRoute in FudAIRoutes.bottomTabs && !analyzing
    val context = LocalContext.current
    val currentVersion = remember(context) { AndroidUpdateChecker.currentVersion(context) }
    var updateAvailable by remember { mutableStateOf(false) }

    LaunchedEffect(currentVersion) {
        val state = AndroidUpdateChecker.check(context, currentVersion)
        updateAvailable = state is AndroidUpdateState.Available
        // A newer version is out — fire a one-shot notification (de-duped per version, gated by the
        // "App Updates" toggle) so the user finds out even without opening the About section.
        if (state is AndroidUpdateState.Available &&
            container.prefs.appUpdateNotificationsEnabled.first() &&
            container.notifications.canPostNotifications() &&
            container.prefs.lastNotifiedUpdateVersion.first() != state.latest
        ) {
            container.notifications.showUpdateAvailable()
            container.prefs.setLastNotifiedUpdateVersion(state.latest)
        }
    }

    // App-open epoch for the Home fill-from-zero reveal. Bumped only on ON_START
    // that follows an ON_STOP (a genuine background -> foreground return), so
    // transient pauses (notification shade, permission dialog) don't retrigger it.
    val lifecycleOwner = LocalLifecycleOwner.current
    var launchFillEpoch by remember { mutableIntStateOf(1) }
    var hasStopped by remember { mutableStateOf(false) }
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> hasStopped = true
                Lifecycle.Event.ON_START -> if (hasStopped) { launchFillEpoch++; hasStopped = false }
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    CompositionLocalProvider(LocalLaunchFillEpoch provides launchFillEpoch) {
    Scaffold(
        bottomBar = {
            if (showTabs) {
                FudAIBottomNavBar(
                    currentRoute = currentRoute,
                    showAboutBadge = updateAvailable,
                    onTap = { target ->
                        if (target == currentRoute) return@FudAIBottomNavBar
                        // Tapping HOME (the start destination) needs popBackStack
                        // — `navigate(HOME) { popUpTo(HOME); launchSingleTop = true }`
                        // is a no-op because NavController sees HOME at the top of
                        // the stack and skips re-emitting currentBackStackEntry, so
                        // the bar stays selected on the previous tab.
                        if (target == FudAIRoutes.HOME) {
                            nav.popBackStack(FudAIRoutes.HOME, inclusive = false)
                        } else {
                            nav.navigate(target) {
                                popUpTo(FudAIRoutes.HOME) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    }
                )
            }
        }
    ) { _ ->
        Box(Modifier.fillMaxSize()) {
            NavHost(
                navController = nav,
                startDestination = if (startOnboarding) FudAIRoutes.ONBOARDING else FudAIRoutes.HOME
            ) {
                composable(FudAIRoutes.ONBOARDING) {
                    OnboardingScreen(container = container, onComplete = {
                        nav.navigate(FudAIRoutes.HOME) {
                            popUpTo(FudAIRoutes.ONBOARDING) { inclusive = true }
                            launchSingleTop = true
                        }
                    })
                }
                composable(FudAIRoutes.HOME) { HomeScreen(container = container) }
                composable(FudAIRoutes.PROGRESS) { ProgressScreen(container = container) }
                composable(FudAIRoutes.COACH) { CoachScreen(container = container) }
                composable(FudAIRoutes.SETTINGS) { SettingsScreen(container = container, nav = nav) }
                composable(FudAIRoutes.OPTIONAL_NUTRIENT_GOALS) {
                    OptionalNutrientGoalsScreen(container = container, onBack = { nav.popBackStack() })
                }
                composable(FudAIRoutes.CALCULATION_METHODS) {
                    CalculationMethodsScreen(onBack = { nav.popBackStack() })
                }
                composable(FudAIRoutes.BODY_MEASUREMENTS) {
                    BodyMeasurementsScreen(container = container, onBack = { nav.popBackStack() })
                }
                composable(FudAIRoutes.WORKOUTS) { WorkoutsScreen() }
            }
        }
    }
    }
}

internal fun NavHostController.current(): String? = currentBackStackEntry?.destination?.route
