package com.apoorvdarshan.calorietracker.ui.progress

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressFlutterBridgeTest {
    @Test
    fun snapshotWaitsForNativeBindingAndThenUsesRequestedRange() {
        val bridge = ProgressFlutterBridge()
        val result = RecordingResult()

        bridge.handleCall(
            MethodCall("getSnapshot", mapOf("range" to "month")),
            result
        )
        assertFalse(result.completed)

        val owner = Any()
        bridge.bind(
            owner = owner,
            snapshotProvider = { range -> mapOf("range" to range) },
            actionHandler = {}
        )

        assertTrue(result.completed)
        assertEquals(mapOf("range" to "month"), result.value)
        bridge.unbind(owner)
    }

    @Test
    fun actionCompletesOnlyAfterNativeUiClosesAndRejectsOverlap() {
        val bridge = ProgressFlutterBridge()
        val owner = Any()
        var handledAction: FlutterProgressAction? = null
        bridge.bind(
            owner = owner,
            snapshotProvider = { emptyMap() },
            actionHandler = { handledAction = it }
        )

        val first = RecordingResult()
        bridge.handleCall(
            MethodCall("performAction", mapOf("action" to "logWeight")),
            first
        )
        assertEquals(FlutterProgressAction.LOG_WEIGHT, handledAction)
        assertFalse(first.completed)

        val overlapping = RecordingResult()
        bridge.handleCall(
            MethodCall("performAction", mapOf("action" to "weightHistory")),
            overlapping
        )
        assertEquals("action_in_progress", overlapping.errorCode)

        bridge.completeAction()
        assertTrue(first.completed)
        assertNull(first.value)
        bridge.unbind(owner)
    }

    @Test
    fun closingScreenFailsAnOutstandingAction() {
        val bridge = ProgressFlutterBridge()
        val owner = Any()
        bridge.bind(
            owner = owner,
            snapshotProvider = { emptyMap() },
            actionHandler = {}
        )
        val result = RecordingResult()
        bridge.handleCall(
            MethodCall("performAction", mapOf("action" to "bodyFatHistory")),
            result
        )

        bridge.unbind(owner)

        assertEquals("bridge_detached", result.errorCode)
    }

    private class RecordingResult : MethodChannel.Result {
        var completed = false
        var value: Any? = null
        var errorCode: String? = null

        override fun success(result: Any?) {
            completed = true
            value = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            completed = true
            this.errorCode = errorCode
        }

        override fun notImplemented() {
            completed = true
            errorCode = "not_implemented"
        }
    }
}
