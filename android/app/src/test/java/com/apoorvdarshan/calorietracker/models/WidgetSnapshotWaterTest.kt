package com.apoorvdarshan.calorietracker.models

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetSnapshotWaterTest {
    private val nutrients = listOf("protein", "carbs", "fat", "fiber").map { id ->
        WidgetNutrient(id = id, label = id.replaceFirstChar(Char::uppercase), unit = "g", value = 1.0, goal = 2.0)
    }

    @Test
    fun waterReplacesOnlyFourthNutrientWhileTrackingIsEnabled() {
        val enabled = snapshot(waterEnabled = true)

        assertEquals(listOf("protein", "carbs", "fat", "water"), enabled.displayedHomeNutrients.map { it.id })
        assertEquals(750.0, enabled.displayedHomeNutrients.last().value, 0.0)
        assertEquals(2_000.0, enabled.displayedHomeNutrients.last().goal, 0.0)
    }

    @Test
    fun savedFourthNutrientReturnsWhenTrackingIsDisabled() {
        val disabled = snapshot(waterEnabled = false)

        assertEquals(listOf("protein", "carbs", "fat", "fiber"), disabled.displayedHomeNutrients.map { it.id })
    }

    private fun snapshot(waterEnabled: Boolean) = WidgetSnapshot(
        date = Instant.EPOCH,
        dayStart = Instant.EPOCH,
        calories = 0,
        calorieGoal = 2_000,
        protein = 0.0,
        proteinGoal = 150,
        carbs = 0.0,
        carbsGoal = 220,
        fat = 0.0,
        fatGoal = 70,
        homeNutrients = nutrients,
        waterTrackingEnabled = waterEnabled,
        waterCurrentMl = 750,
        waterGoalMl = 2_000,
        waterUnitRaw = WaterUnit.MILLILITERS.storageValue
    )
}
