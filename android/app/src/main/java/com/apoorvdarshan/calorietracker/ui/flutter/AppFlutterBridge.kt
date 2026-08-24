package com.apoorvdarshan.calorietracker.ui.flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single presentation boundary for the shared five-tab Flutter shell.
 *
 * Native repositories remain authoritative. Flutter receives immutable,
 * StandardMessageCodec-safe snapshots and returns semantic user actions.
 */
internal class AppFlutterBridge {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var bindingOwner: Any? = null
    private var shellProvider: (() -> Map<String, Any?>)? = null
    private var pageProvider: ((String) -> Map<String, Any?>)? = null
    private var actionHandler: ((String, Map<*, *>) -> Any?)? = null
    private var tabHandler: ((String) -> Unit)? = null

    fun attach(flutterEngine: FlutterEngine) {
        if (engine === flutterEngine) return
        channel?.setMethodCallHandler(null)
        engine = flutterEngine
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).also { it.setMethodCallHandler(::handleCall) }
    }

    fun detach(flutterEngine: FlutterEngine) {
        if (engine !== flutterEngine) return
        channel?.setMethodCallHandler(null)
        channel = null
        engine = null
    }

    fun bind(
        owner: Any,
        shellProvider: () -> Map<String, Any?>,
        pageProvider: (String) -> Map<String, Any?>,
        actionHandler: (String, Map<*, *>) -> Any?,
        tabHandler: (String) -> Unit
    ) {
        bindingOwner = owner
        this.shellProvider = shellProvider
        this.pageProvider = pageProvider
        this.actionHandler = actionHandler
        this.tabHandler = tabHandler
    }

    fun unbind(owner: Any) {
        if (bindingOwner !== owner) return
        bindingOwner = null
        shellProvider = null
        pageProvider = null
        actionHandler = null
        tabHandler = null
    }

    fun notifySnapshotChanged(tab: String? = null) {
        channel?.invokeMethod(
            "snapshotChanged",
            tab?.let { mapOf("tab" to it) }
        )
    }

    internal fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        when (call.method) {
            "getShellSnapshot" -> providerResult(result) { shellProvider?.invoke() }
            "getPageSnapshot" -> {
                val tab = arguments["tab"] as? String
                if (tab == null) {
                    result.error("invalid_tab", "A tab is required.", null)
                } else {
                    providerResult(result) { pageProvider?.invoke(tab) }
                }
            }
            "performAction" -> {
                val action = arguments["action"] as? String
                if (action == null) {
                    result.error("invalid_action", "An action is required.", null)
                    return
                }
                val handler = actionHandler
                if (handler == null) {
                    result.error("bridge_unavailable", "The app shell is unavailable.", null)
                    return
                }
                runCatching { handler(action, arguments) }
                    .onSuccess { value ->
                        // Kotlin side-effect handlers return Unit, which is not
                        // representable by Flutter's StandardMessageCodec.
                        result.success(if (value === Unit) null else value)
                    }
                    .onFailure { error ->
                        result.error("action_failed", error.message ?: "Action failed.", null)
                    }
            }
            "selectTab" -> {
                val tab = arguments["tab"] as? String
                if (tab == null) {
                    result.error("invalid_tab", "A tab is required.", null)
                    return
                }
                tabHandler?.invoke(tab)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun providerResult(
        result: MethodChannel.Result,
        provider: () -> Map<String, Any?>?
    ) {
        runCatching { provider() }
            .onSuccess { value ->
                if (value == null) {
                    result.error("bridge_unavailable", "The app shell is unavailable.", null)
                } else {
                    result.success(value)
                }
            }
            .onFailure { error ->
                result.error("snapshot_failed", error.message ?: "Snapshot failed.", null)
            }
    }

    private companion object {
        const val CHANNEL_NAME = "com.apoorvdarshan.fudai/app"
    }
}
