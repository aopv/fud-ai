package com.apoorvdarshan.calorietracker.ui.home

import com.apoorvdarshan.calorietracker.models.CurrentMealSchedule
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.WaterEntry
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeDiaryMealGroupTest {
    @Test
    fun waterAppearsInsideTimedMealWithoutChangingFoodTotals() {
        val waterTime = Instant.parse("2026-08-30T13:01:00Z")
        val foodTime = waterTime.minusSeconds(60)
        val meal = CurrentMealSchedule.value.mealTypeAt(
            waterTime.atZone(ZoneId.systemDefault()).toLocalTime()
        )
        val food = FoodEntry(
            id = UUID.randomUUID(),
            name = "Diary test meal",
            calories = 420,
            protein = 30.0,
            carbs = 45.0,
            fat = 12.0,
            timestamp = foodTime,
            source = FoodSource.MANUAL,
            mealType = meal
        )
        val water = WaterEntry(date = waterTime, milliliters = 250)

        val group = homeDiaryMealGroups(
            foodEntries = listOf(food),
            waterEntries = listOf(water),
            sortOrder = FoodLogSortOrder.STANDARD
        ).first { it.meal == meal }

        assertEquals(2, group.items.size)
        assertTrue(group.items.first() is HomeDiaryItem.Water)
        assertEquals(listOf(food.id), group.foodEntries.map { it.id })
        assertEquals(420, group.totalCalories)
        assertEquals(30.0, group.totalProtein, 0.0)
        assertEquals(45.0, group.totalCarbs, 0.0)
        assertEquals(12.0, group.totalFat, 0.0)
    }
}
