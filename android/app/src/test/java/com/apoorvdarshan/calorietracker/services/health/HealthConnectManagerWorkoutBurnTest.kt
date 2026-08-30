package com.apoorvdarshan.calorietracker.services.health

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HealthConnectManagerWorkoutBurnTest {
    @Test
    fun workoutBurnClientRecordIdRoundTripsStableDateAndSession() {
        val id = UUID.fromString("2cb568d8-193b-4df0-a13e-1666126704e8")

        val clientRecordId = HealthConnectManager.workoutBurnClientRecordId("2026-07-20", id)
        val parsed = HealthConnectManager.parseWorkoutBurnClientRecordId(clientRecordId)

        assertEquals("fudai_workout_burn|2026-07-20|$id", clientRecordId)
        assertEquals(WorkoutBurnIdentity(id, "2026-07-20"), parsed)
    }

    @Test
    fun workoutBurnClientRecordIdRejectsMalformedOrNonCanonicalValues() {
        val id = UUID.fromString("2cb568d8-193b-4df0-a13e-1666126704e8")

        assertNull(HealthConnectManager.workoutBurnClientRecordId("2026-7-20", id))
        assertNull(HealthConnectManager.workoutBurnClientRecordId("2026-02-30", id))
        assertNull(HealthConnectManager.parseWorkoutBurnClientRecordId("fudai_$id"))
        assertNull(HealthConnectManager.parseWorkoutBurnClientRecordId("fudai_workout_burn|2026-07-20|not-a-uuid"))
        assertNull(HealthConnectManager.parseWorkoutBurnClientRecordId("fudai_workout_burn|2026-07-20|$id|extra"))
    }

    @Test
    fun externalActiveCaloriesSubtractsOwnOriginAndNeverGoesNegative() {
        assertEquals(420.0, externalActiveCalories(allActive = 500.0, ownActive = 80.0), 0.0)
        assertEquals(0.0, externalActiveCalories(allActive = 80.0, ownActive = 100.0), 0.0)
    }

    @Test
    fun externalTotalRemovesOwnEstimatedWorkoutBurnWithoutAddingItBack() {
        // 1,700 basal + 500 all-active = 2,200 raw total. Eighty active calories came from
        // Fud AI's own estimate, so the evidence total must be 1,700 + 420 = 2,120.
        assertEquals(
            2_120.0,
            externalTotalCalories(rawTotal = 2_200.0, allActive = 500.0, ownActive = 80.0)!!,
            0.0
        )
        assertNull(externalTotalCalories(rawTotal = null, allActive = 500.0, ownActive = 80.0))
    }
}
