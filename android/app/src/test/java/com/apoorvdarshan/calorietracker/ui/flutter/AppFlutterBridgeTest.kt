package com.apoorvdarshan.calorietracker.ui.flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AppFlutterBridgeTest {
    @Test
    fun unitActionResultsAreEncodedAsNull() {
        val bridge = AppFlutterBridge()
        val owner = Any()
        bridge.bind(
            owner = owner,
            shellProvider = { emptyMap() },
            pageProvider = { emptyMap() },
            actionHandler = { _, _ -> Unit },
            tabHandler = {}
        )

        val result = RecordingResult()
        bridge.handleCall(
            MethodCall("performAction", mapOf("action" to "home.endFast")),
            result
        )

        assertTrue(result.completed)
        assertNull(result.value)
        bridge.unbind(owner)
    }

    @Test
    fun codecSafeActionValuesArePreserved() {
        val bridge = AppFlutterBridge()
        val owner = Any()
        val expected = mapOf("status" to "ok")
        bridge.bind(
            owner = owner,
            shellProvider = { emptyMap() },
            pageProvider = { emptyMap() },
            actionHandler = { _, _ -> expected },
            tabHandler = {}
        )

        val result = RecordingResult()
        bridge.handleCall(
            MethodCall("performAction", mapOf("action" to "test.action")),
            result
        )

        assertEquals(expected, result.value)
        bridge.unbind(owner)
    }

    private class RecordingResult : MethodChannel.Result {
        var completed = false
        var value: Any? = null

        override fun success(result: Any?) {
            completed = true
            value = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            completed = true
            throw AssertionError("Unexpected bridge error: $errorCode $errorMessage")
        }

        override fun notImplemented() {
            completed = true
            throw AssertionError("Unexpected notImplemented")
        }
    }
}
