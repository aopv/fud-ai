package com.apoorvdarshan.calorietracker.services

import com.apoorvdarshan.calorietracker.BuildConfig
import kotlinx.coroutines.runBlocking
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException
import java.util.concurrent.atomic.AtomicReference

class OpenFoodFactsServiceTest {
    @Test
    fun http404MapsToProductNotFoundBeforeParsingTheBody() {
        val error = lookupFailure(
            code = 404,
            body = """{"status":0,"status_verbose":"product not found"}"""
        )

        assertEquals(OpenFoodFactsService.LookupFailure.PRODUCT_NOT_FOUND, error.failure)
        assertEquals(404, error.httpStatus)
    }

    @Test
    fun successfulStatusZeroPayloadMapsToProductNotFound() {
        val error = lookupFailure(
            code = 200,
            body = """{"status":"0","product":null}"""
        )

        assertEquals(OpenFoodFactsService.LookupFailure.PRODUCT_NOT_FOUND, error.failure)
        assertNull(error.httpStatus)
    }

    @Test
    fun rateLimitAndServerFailuresRemainDistinct() {
        val rateLimit = lookupFailure(code = 429, body = "slow down")
        val serverFailure = lookupFailure(code = 503, body = "unavailable")

        assertEquals(OpenFoodFactsService.LookupFailure.RATE_LIMITED, rateLimit.failure)
        assertEquals(429, rateLimit.httpStatus)
        assertEquals(OpenFoodFactsService.LookupFailure.SERVICE_UNAVAILABLE, serverFailure.failure)
        assertEquals(503, serverFailure.httpStatus)
    }

    @Test
    fun invalidOrIncompletePayloadsHaveSpecificFailures() {
        val malformed = lookupFailure(code = 200, body = "not json")
        val missingNutrition = lookupFailure(
            code = 200,
            body = """{"status":1,"product":{"product_name":"Test"}}"""
        )
        val emptyNutrition = lookupFailure(
            code = 200,
            body = """{"status":1,"product":{"product_name":"Test","nutriments":{}}}"""
        )

        assertEquals(OpenFoodFactsService.LookupFailure.UNEXPECTED_RESPONSE, malformed.failure)
        assertEquals(OpenFoodFactsService.LookupFailure.MISSING_NUTRITION, missingNutrition.failure)
        assertEquals(OpenFoodFactsService.LookupFailure.MISSING_NUTRITION, emptyNutrition.failure)
    }

    @Test
    fun networkFailureRemainsDistinct() {
        val client = OkHttpClient.Builder()
            .addInterceptor { throw IOException("offline") }
            .build()

        val error = try {
            runBlocking {
                OpenFoodFactsService.lookup(
                    barcode = "3017620422003",
                    client = client,
                    baseUrl = TEST_BASE_URL
                )
            }
            fail("Expected lookup to fail")
            throw AssertionError("unreachable")
        } catch (error: OpenFoodFactsService.LookupException) {
            error
        }

        assertEquals(OpenFoodFactsService.LookupFailure.NETWORK, error.failure)
        assertTrue(error.cause is IOException)
    }

    @Test
    fun successfulLookupPreservesNumericCodeAndParsesFlexibleNutrients() = runBlocking {
        val captured = AtomicReference<Request>()
        val client = responseClient(
            code = 200,
            body = """
                {
                  "status":"1",
                  "product":{
                    "product_name":"Test Bar",
                    "brands":"Acme",
                    "serving_quantity":"50",
                    "nutriments":{
                      "energy-kcal_100g":"200",
                      "proteins_100g":"10,0",
                      "carbohydrates_100g":30,
                      "fat_serving":"4.5",
                      "sodium_100g":0.5
                    }
                  }
                }
            """.trimIndent(),
            capturedRequest = captured
        )

        val result = OpenFoodFactsService.lookup(
            barcode = " 0012345678905 ",
            client = client,
            baseUrl = TEST_BASE_URL
        )

        assertEquals("Acme Test Bar", result.name)
        assertEquals(100, result.calories)
        assertEquals(5.0, result.protein, 0.0001)
        assertEquals(15.0, result.carbs, 0.0001)
        assertEquals(4.5, result.fat, 0.0001)
        assertEquals(50.0, result.servingSizeGrams, 0.0001)
        assertEquals(250.0, result.sodium!!, 0.0001)

        val request = captured.get()
        assertNotNull(request)
        assertEquals("/api/v2/product/0012345678905.json", request.url.encodedPath)
        assertEquals(
            "product_name,generic_name,brands,quantity,serving_size,serving_quantity,nutriments",
            request.url.queryParameter("fields")
        )
        assertEquals(
            "FudAI/${BuildConfig.VERSION_NAME} (https://fud-ai.app)",
            request.header("User-Agent")
        )
    }

    @Test
    fun barcodeValidationAcceptsOnlyBoundedAsciiDigits() {
        assertEquals("0012345678905", OpenFoodFactsService.normalizedBarcode(" 0012345678905 "))
        assertNull(OpenFoodFactsService.normalizedBarcode(""))
        assertNull(OpenFoodFactsService.normalizedBarcode("123 456"))
        assertNull(OpenFoodFactsService.normalizedBarcode("123/456"))
        assertNull(OpenFoodFactsService.normalizedBarcode("١٢٣٤٥٦٧٨"))
        assertNull(OpenFoodFactsService.normalizedBarcode("1".repeat(25)))
    }

    private fun lookupFailure(code: Int, body: String): OpenFoodFactsService.LookupException {
        val client = responseClient(code = code, body = body)
        return try {
            runBlocking {
                OpenFoodFactsService.lookup(
                    barcode = "3017620422003",
                    client = client,
                    baseUrl = TEST_BASE_URL
                )
            }
            fail("Expected lookup to fail")
            throw AssertionError("unreachable")
        } catch (error: OpenFoodFactsService.LookupException) {
            error
        }
    }

    private fun responseClient(
        code: Int,
        body: String,
        capturedRequest: AtomicReference<Request>? = null
    ): OkHttpClient = OkHttpClient.Builder()
        .addInterceptor { chain ->
            capturedRequest?.set(chain.request())
            Response.Builder()
                .request(chain.request())
                .protocol(Protocol.HTTP_1_1)
                .code(code)
                .message("test response")
                .body(body.toResponseBody(JSON_MEDIA_TYPE))
                .build()
        }
        .build()

    private companion object {
        val TEST_BASE_URL = "https://example.test/".toHttpUrl()
        val JSON_MEDIA_TYPE = "application/json".toMediaType()
    }
}
