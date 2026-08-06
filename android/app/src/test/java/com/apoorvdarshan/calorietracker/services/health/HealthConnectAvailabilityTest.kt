package com.apoorvdarshan.calorietracker.services.health

import org.junit.Assert.assertEquals
import org.junit.Test

class HealthConnectAvailabilityTest {
    @Test
    fun secondaryProfileExplainsWhyApprovedPermissionsAreNotUsable() {
        assertEquals(
            HealthConnectAvailability.PROFILE_UNSUPPORTED,
            resolveHealthConnectAvailability(
                isProfile = true,
                sdkAvailable = false,
                providerUpdateRequired = false
            )
        )
    }

    @Test
    fun availableSdkWinsForMainProfile() {
        assertEquals(
            HealthConnectAvailability.AVAILABLE,
            resolveHealthConnectAvailability(
                isProfile = false,
                sdkAvailable = true,
                providerUpdateRequired = false
            )
        )
    }

    @Test
    fun providerUpdateAndMissingSystemServiceRemainDistinct() {
        assertEquals(
            HealthConnectAvailability.PROVIDER_UPDATE_REQUIRED,
            resolveHealthConnectAvailability(
                isProfile = false,
                sdkAvailable = false,
                providerUpdateRequired = true
            )
        )
        assertEquals(
            HealthConnectAvailability.UNAVAILABLE,
            resolveHealthConnectAvailability(
                isProfile = false,
                sdkAvailable = false,
                providerUpdateRequired = false
            )
        )
    }
}
