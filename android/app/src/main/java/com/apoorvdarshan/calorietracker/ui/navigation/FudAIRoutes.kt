package com.apoorvdarshan.calorietracker.ui.navigation

object FudAIRoutes {
    const val ONBOARDING = "onboarding"
    const val HOME = "home"
    const val PROGRESS = "progress"
    const val COACH = "coach"
    const val SETTINGS = "settings"
    const val OPTIONAL_NUTRIENT_GOALS = "settings/optional-nutrient-goals"
    const val CALCULATION_METHODS = "settings/calculation-methods"
    const val BODY_MEASUREMENTS = "settings/body-measurements"
    const val WORKOUTS = "workouts"

    val bottomTabs = listOf(HOME, PROGRESS, COACH, SETTINGS, WORKOUTS)
}
