package com.solutiontee.cbt

import androidx.activity.ComponentActivity
import com.paystack.android.core.Paystack
import com.paystack.android.ui.paymentsheet.PaymentSheet
import com.paystack.android.ui.paymentsheet.PaymentSheetResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Paystack's own payment sheet inside the app (direct build only, D-089). Card details are typed into Paystack's
 * sheet, never into our screens (PCI DSS). The server makes the transaction and checks the result; this only shows
 * the sheet for an access code and says how it closed. Channel "solutiontee/paystack":
 *   available → bool
 *   launch {publicKey, accessCode, dark} → {status: success|cancelled|failed|unavailable|busy, reference?, message?}
 */
object PaystackBridge {
    private var sheet: PaymentSheet? = null
    private var pending: MethodChannel.Result? = null

    /** Called in onCreate (the sheet must be registered before the screen starts). */
    fun register(activity: ComponentActivity) {
        // A new screen (for example after Android recreated it): the old sheet's answer will never come.
        pending?.success(mapOf("status" to "unknown"))
        pending = null
        sheet = try {
            PaymentSheet(activity) { r -> finish(r) }
        } catch (e: Exception) {
            null
        }
    }

    private fun finish(r: PaymentSheetResult) {
        val out: Map<String, Any?> = when (r) {
            is PaymentSheetResult.Completed -> mapOf("status" to "success", "reference" to r.paymentCompletionDetails.reference)
            is PaymentSheetResult.Cancelled -> mapOf("status" to "cancelled")
            is PaymentSheetResult.Failed -> mapOf("status" to "failed", "message" to (r.error.message ?: ""), "reference" to r.reference)
            else -> mapOf("status" to "failed")
        }
        pending?.success(out)
        pending = null
    }

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "solutiontee/paystack").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(sheet != null)
                "launch" -> {
                    val key = call.argument<String>("publicKey")
                    val code = call.argument<String>("accessCode")
                    val s = sheet
                    if (s == null || key.isNullOrEmpty() || code.isNullOrEmpty()) {
                        result.success(mapOf("status" to "unavailable"))
                    } else if (pending != null) {
                        result.success(mapOf("status" to "busy"))
                    } else {
                        try {
                            val paystack = Paystack.builder().setPublicKey(key).setLoggingEnabled(false).build()
                            pending = result
                            // paystack-ui 0.1.8 (1.0.0 needs compile SDK 37): the sheet follows the phone's theme.
                            s.launch(paystack, code)
                        } catch (e: Exception) {
                            pending = null
                            result.success(mapOf("status" to "unavailable", "message" to (e.message ?: "")))
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
