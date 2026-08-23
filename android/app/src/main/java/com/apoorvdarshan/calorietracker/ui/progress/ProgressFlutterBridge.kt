package com.apoorvdarshan.calorietracker.ui.progress

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal enum class FlutterProgressAction(val channelValue: String) {
    LOG_WEIGHT("logWeight"),
    LOG_BODY_FAT("logBodyFat"),
    WEIGHT_HISTORY("weightHistory"),
    BODY_FAT_HISTORY("bodyFatHistory"),
    WORKOUT_HISTORY("workoutHistory");

    companion object {
        fun fromChannelValue(value: String?): FlutterProgressAction? =
            entries.firstOrNull { it.channelValue == value }
    }
}

/**
 * Owns the narrow MethodChannel boundary between Flutter presentation and the
 * native Android stores. Flutter can request display snapshots and native UI
 * actions, but it never receives repositories or persistence objects.
 */
internal class ProgressFlutterBridge {
    private data class PendingSnapshot(
        val range: String,
        val result: MethodChannel.Result
    )

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var bindingOwner: Any? = null
    private var snapshotProvider: ((String) -> Map<String, Any?>)? = null
    private var actionHandler: ((FlutterProgressAction) -> Unit)? = null
    private val pendingSnapshots = mutableListOf<PendingSnapshot>()
    private var pendingActionResult: MethodChannel.Result? = null

    fun attach(flutterEngine: FlutterEngine) {
        if (engine === flutterEngine) return
        channel?.setMethodCallHandler(null)
        engine = flutterEngine
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).also { methodChannel ->
            methodChannel.setMethodCallHandler(::handleCall)
        }
    }

    fun detach(flutterEngine: FlutterEngine) {
        if (engine !== flutterEngine) return
        channel?.setMethodCallHandler(null)
        channel = null
        engine = null
        failPending("bridge_detached", "Progress bridge was detached.")
    }

    fun bind(
        owner: Any,
        snapshotProvider: (String) -> Map<String, Any?>,
        actionHandler: (FlutterProgressAction) -> Unit
    ) {
        bindingOwner = owner
        this.snapshotProvider = snapshotProvider
        this.actionHandler = actionHandler

        if (pendingSnapshots.isNotEmpty()) {
            val queued = pendingSnapshots.toList()
            pendingSnapshots.clear()
            queued.forEach { request ->
                sendSnapshot(request.range, request.result)
            }
        }
    }

    fun unbind(owner: Any) {
        if (bindingOwner !== owner) return
        bindingOwner = null
        snapshotProvider = null
        actionHandler = null
        failPending("bridge_detached", "Progress screen was closed.")
    }

    /** Completes Flutter's action Future only after the native sheet closes. */
    fun completeAction() {
        pendingActionResult?.success(null)
        pendingActionResult = null
    }

    /** Requests a reload without recreating the embedded engine or losing scroll state. */
    fun notifySnapshotChanged() {
        channel?.invokeMethod("snapshotChanged", null)
    }

    internal fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        when (call.method) {
            "getSnapshot" -> {
                val range = arguments?.get("range") as? String ?: "week"
                if (snapshotProvider == null) {
                    pendingSnapshots += PendingSnapshot(range, result)
                } else {
                    sendSnapshot(range, result)
                }
            }

            "performAction" -> {
                val action = FlutterProgressAction.fromChannelValue(
                    arguments?.get("action") as? String
                )
                if (action == null) {
                    result.error(
                        "invalid_action",
                        "Unknown Progress action.",
                        arguments?.get("action")
                    )
                    return
                }
                if (pendingActionResult != null) {
                    result.error(
                        "action_in_progress",
                        "Another Progress action is already open.",
                        null
                    )
                    return
                }
                val handler = actionHandler
                if (handler == null) {
                    result.error(
                        "bridge_unavailable",
                        "The native Progress screen is unavailable.",
                        null
                    )
                    return
                }
                pendingActionResult = result
                handler(action)
            }

            else -> result.notImplemented()
        }
    }

    private fun sendSnapshot(range: String, result: MethodChannel.Result) {
        val provider = snapshotProvider
        if (provider == null) {
            pendingSnapshots += PendingSnapshot(range, result)
            return
        }
        runCatching { provider(range) }
            .onSuccess(result::success)
            .onFailure { error ->
                result.error(
                    "snapshot_failed",
                    error.message ?: "Progress snapshot failed.",
                    null
                )
            }
    }

    private fun failPending(code: String, message: String) {
        pendingSnapshots.forEach { it.result.error(code, message, null) }
        pendingSnapshots.clear()
        pendingActionResult?.error(code, message, null)
        pendingActionResult = null
    }

    private companion object {
        const val CHANNEL_NAME = "com.apoorvdarshan.fudai/progress"
    }
}
