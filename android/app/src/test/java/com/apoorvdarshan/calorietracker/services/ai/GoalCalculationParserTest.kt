package com.apoorvdarshan.calorietracker.services.ai

import com.apoorvdarshan.calorietracker.models.UserProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalCalculationParserTest {
    @Test
    fun requiresEveryCalorieAndMacroField() {
        val incomplete = """{"calories":2000,"protein":150,"carbs":200}"""

        val failure = runCatching { FoodJsonParser.parseGoalCalculation(incomplete) }.exceptionOrNull()

        assertTrue(failure is AiError.InvalidResponse)
    }

    @Test
    fun rejectsExtremeOrZeroMacroPlansInsteadOfClampingThem() {
        val extreme = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":801,"protein":999,"carbs":999,"fat":999,"reason":"test"}"""
            )
        }.exceptionOrNull()
        val zero = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":2000,"protein":0,"carbs":500,"fat":0}"""
            )
        }.exceptionOrNull()
        val normalizedToZeroFat = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":800,"protein":200,"carbs":0,"fat":10}"""
            )
        }.exceptionOrNull()

        assertTrue(extreme is AiError.InvalidResponse)
        assertTrue(zero is AiError.InvalidResponse)
        assertTrue(normalizedToZeroFat is AiError.InvalidResponse)

        val profileMismatch = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":2000,"protein":300,"carbs":110,"fat":40}""",
                UserProfile()
            )
        }.exceptionOrNull()
        assertTrue(profileMismatch is AiError.InvalidResponse)
        val calorieMismatch = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":6000,"protein":112,"carbs":1289,"fat":44}""",
                UserProfile()
            )
        }.exceptionOrNull()
        assertTrue(calorieMismatch is AiError.InvalidResponse)
    }

    @Test
    fun normalizesSmallRoundingDriftButRejectsIncoherentCarbArithmetic() {
        val result = FoodJsonParser.parseGoalCalculation(
            """{"calories":2000,"protein":150,"carbs":215,"fat":61}"""
        )

        assertEquals(215, result.carbs)
        assertEquals(2000, 4 * result.protein + 4 * result.carbs + 9 * result.fat)

        val incoherent = runCatching {
            FoodJsonParser.parseGoalCalculation(
                """{"calories":2000,"protein":150,"carbs":7,"fat":60}"""
            )
        }.exceptionOrNull()
        assertTrue(incoherent is AiError.InvalidResponse)
    }
}
