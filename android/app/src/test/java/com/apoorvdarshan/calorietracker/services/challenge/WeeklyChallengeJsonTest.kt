package com.apoorvdarshan.calorietracker.services.challenge

import com.apoorvdarshan.calorietracker.data.isCompletedDeleteResponse
import com.apoorvdarshan.calorietracker.data.isExpiredSessionResponse
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeAggregate
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeCreateProfileRequest
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeLeaderboard
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeProfileRequest
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeProfileValidator
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeReportValidator
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeSocialPlatform
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class WeeklyChallengeJsonTest {
    @Test
    fun reportDetailsMatchServerControlAndLengthPolicy() {
        assertEquals(
            "First line Second line",
            WeeklyChallengeReportValidator.requestDetails("  First line\nSecond\u200B line  ")
        )
        assertEquals("🙂", WeeklyChallengeReportValidator.requestDetails("🙂"))
        assertTrue(WeeklyChallengeReportValidator.validDetails("🙂".repeat(300)))
        assertFalse(WeeklyChallengeReportValidator.validDetails("a".repeat(301)))
        assertNull(WeeklyChallengeReportValidator.requestDetails("\n\u200B"))
    }

    @Test
    fun deletionIsIdempotentAfterServerAlreadyRemovedTheProfile() {
        assertTrue(WeeklyChallengeApiException("invalid_token", 401).isCompletedDeleteResponse())
        assertTrue(WeeklyChallengeApiException("not_found", 404).isCompletedDeleteResponse())
        assertFalse(WeeklyChallengeApiException("server_error", 500).isCompletedDeleteResponse())
    }

    @Test
    fun onlyUnauthorizedResponseExpiresTheLocalSession() {
        assertTrue(WeeklyChallengeApiException("invalid_token", 401).isExpiredSessionResponse())
        assertFalse(WeeklyChallengeApiException("forbidden", 403).isExpiredSessionResponse())
        assertFalse(WeeklyChallengeApiException("not_found", 404).isExpiredSessionResponse())
    }

    @Test
    fun profileCreationRequiresRulesAndAdultEligibility() {
        assertNull(
            WeeklyChallengeProfileValidator.createRequest(
                "Ava Runner", null, "", acceptedRules = false, eligibilityAccepted = true
            )
        )
        assertNull(
            WeeklyChallengeProfileValidator.createRequest(
                "Ava Runner", null, "", acceptedRules = true, eligibilityAccepted = false
            )
        )
        assertNotNull(
            WeeklyChallengeProfileValidator.createRequest(
                "Ava Runner", null, "", acceptedRules = true, eligibilityAccepted = true
            )
        )
    }

    @Test
    fun displayNameRejectsReservedImpersonationAndLinksLikeTheServer() {
        for (
            invalidName in listOf(
                "Admin",
                "Friendly Admin",
                "Fud AI",
                "Fud-AI",
                "fud.ai",
                "example.com",
                "runner@example.com",
                "Friendly Support",
                "White-Power"
            )
        ) {
            assertFalse(
                invalidName,
                WeeklyChallengeProfileValidator.validDisplayName(invalidName)
            )
        }
        assertTrue(WeeklyChallengeProfileValidator.validDisplayName("Élodie Singh"))
        assertTrue(WeeklyChallengeProfileValidator.validDisplayName("अनन्या १२"))
    }

    @Test
    fun createProfileEncodingIncludesBothRequiredAcceptances() {
        val encoded = WeeklyChallengeJson.codec.parseToJsonElement(
            WeeklyChallengeJson.encodeCreateProfile(
                WeeklyChallengeCreateProfileRequest(
                    displayName = "Ava Runner",
                    socialPlatform = WeeklyChallengeSocialPlatform.X,
                    socialHandle = "ava_runner",
                    acceptedRules = true,
                    eligibilityAccepted = true
                )
            )
        ).jsonObject

        assertEquals(
            setOf(
                "displayName",
                "socialPlatform",
                "socialHandle",
                "acceptedRules",
                "eligibilityAccepted"
            ),
            encoded.keys
        )
        assertEquals("x", encoded.getValue("socialPlatform").jsonPrimitive.content)
        assertTrue(encoded.getValue("acceptedRules").jsonPrimitive.boolean)
        assertTrue(encoded.getValue("eligibilityAccepted").jsonPrimitive.boolean)
    }

    @Test
    fun patchEncodingClearsBothSocialFieldsAndNeverSendsCreateConsent() {
        val encoded = WeeklyChallengeJson.codec.parseToJsonElement(
            WeeklyChallengeJson.encodeProfile(
                WeeklyChallengeProfileRequest(displayName = "Ava Runner")
            )
        ).jsonObject

        assertEquals(setOf("displayName", "socialPlatform", "socialHandle"), encoded.keys)
        assertSame(JsonNull, encoded.getValue("socialPlatform"))
        assertSame(JsonNull, encoded.getValue("socialHandle"))
        assertFalse("acceptedRules" in encoded)
        assertFalse("eligibilityAccepted" in encoded)
    }

    @Test
    fun weeklyScoreEncodingContainsOnlyTheAggregateContract() {
        val encoded = WeeklyChallengeJson.codec.parseToJsonElement(
            WeeklyChallengeJson.encodeScore(
                WeeklyChallengeAggregate(
                    weekStart = "2026-08-24",
                    overallPoints = 10,
                    activityDays = 3,
                    nutritionDays = 2,
                    consistencyDays = 4,
                    hydrationDays = 1,
                    activityKcal = 2_450
                )
            )
        ).jsonObject

        assertEquals(
            setOf(
                "weekStart",
                "overallPoints",
                "activityDays",
                "nutritionDays",
                "consistencyDays",
                "hydrationDays",
                "activityKcal"
            ),
            encoded.keys
        )
        assertEquals(10, encoded.getValue("overallPoints").jsonPrimitive.content.toInt())
        assertFalse(encoded.keys.any { it.contains("weight", ignoreCase = true) })
        assertFalse(encoded.keys.any { it.contains("food", ignoreCase = true) })
        assertFalse(encoded.keys.any { it.contains("workout", ignoreCase = true) })
    }

    @Test
    fun leaderboardDecodesSeparateViewerOutsideRankings() {
        val rowFields = """
            "displayName":"Ava","socialPlatform":null,"socialHandle":null,
            "score":4,"overallPoints":4,"activityDays":1,"nutritionDays":1,
            "consistencyDays":1,"hydrationDays":1,"activityKcal":400,
            "updatedAt":"2026-08-31T10:00:00Z","isViewer":true
        """.trimIndent()
        val decoded = WeeklyChallengeJson.decode(
            WeeklyChallengeLeaderboard.serializer(),
            """
            {
              "weekStart":"2026-08-31",
              "category":"overall",
              "updatedAt":"2026-08-31T10:00:00Z",
              "rankings":[],
              "viewer":{"rank":120,"participantId":"viewer-1",$rowFields}
            }
            """.trimIndent()
        )

        assertTrue(decoded.rankings.isEmpty())
        assertEquals("viewer-1", decoded.viewer?.participantId)
        assertEquals(120, decoded.viewer?.rank)
    }
}
