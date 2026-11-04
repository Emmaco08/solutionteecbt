package com.solutiontee.cbt

import androidx.activity.ComponentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Play build: no Paystack sheet (Google Play Billing pays). The app falls back to the in-app checkout tab. */
object PaystackBridge {
    fun register(activity: ComponentActivity) {}

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "solutiontee/paystack").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(false)
                "launch" -> result.success(mapOf("status" to "unavailable"))
                else -> result.notImplemented()
            }
        }
    }
}
