package com.apoorvdarshan.calorietracker.ui.home

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodSubmissionGateTest {
    @Test
    fun repeatedSubmissionIsRejectedUntilTheFirstFinishes() {
        val gate = FoodSubmissionGate()

        assertTrue(gate.tryBegin())
        assertFalse(gate.tryBegin())

        gate.finish()

        assertTrue(gate.tryBegin())
    }
}
