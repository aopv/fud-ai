package com.apoorvdarshan.calorietracker.services

import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Signals MainActivity to launch the Play in-app review flow once, right after
 * the first successful food log — the organic high-intent moment (iOS parity;
 * the onboarding rating screen was removed). FoodRepository flips the flag the
 * first time an entry is saved; the once-only guard is persisted in
 * PreferencesStore (reviewPromptedAfterFirstLog).
 */
object ReviewPrompter {
    val requestReview = MutableStateFlow(false)

    fun consumed() {
        requestReview.value = false
    }
}
