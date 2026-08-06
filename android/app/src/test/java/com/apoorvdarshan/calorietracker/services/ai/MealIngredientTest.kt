package com.apoorvdarshan.calorietracker.services.ai

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealIngredient
import com.apoorvdarshan.calorietracker.models.totals
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MealIngredientTest {
    @Test
    fun scalingAndTotalsRecalculateMealMacros() {
        val ingredients = listOf(
            MealIngredient("Rice", 150.0, 195, 4.0, 42.0, 0.5),
            MealIngredient("Chicken", 100.0, 165, 31.0, 0.0, 3.6)
        ).map { it.scaled(0.5) }
        val totals = ingredients.totals()

        assertEquals(125.0, totals.grams, 0.001)
        assertEquals(181, totals.calories)
        assertEquals(17.5, totals.protein, 0.001)
    }

    @Test
    fun oldFoodEntryJsonWithoutIngredientsStillDecodes() {
        val json = """{"name":"Apple","calories":95,"protein":0.5,"carbs":25.0,"fat":0.3,"source":"manual"}"""
        val entry = Json { ignoreUnknownKeys = true }.decodeFromString<FoodEntry>(json)

        assertTrue(entry.ingredients.isEmpty())
        assertEquals("Apple", entry.name)
        assertEquals(FoodSource.MANUAL, entry.source)
    }
}
