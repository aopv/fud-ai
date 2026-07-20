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
}
