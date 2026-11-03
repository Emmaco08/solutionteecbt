package com.solutiontee.cbt

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.function.Consumer

class MainActivity : FlutterActivity() {
    private var device: MethodChannel? = null

    // Screenshot (Android 14+) and screen-recording (Android 15+) detection (D-075). FLAG_SECURE already blocks the
    // picture where it matters; this tells Flutter so it can warn the student and flag a challenge entry.
    private val screenshotCallback: Any? by lazy {
        if (Build.VERSION.SDK_INT >= 34) Activity.ScreenCaptureCallback { device?.invokeMethod("screenshot", null) } else null
    }
    private val recordingCallback: Any? by lazy {
        if (Build.VERSION.SDK_INT >= 35) {
            Consumer<Int> { state -> device?.invokeMethod("recording", state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) }
        } else {
            null
        }
    }

    // Owner (D-076): screenshots and screen recording are blocked in the whole app, on every Android version.
    // Set before anything is drawn, so even the first frame and the recent-apps preview are protected.
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    @Suppress("UNCHECKED_CAST")
    override fun onStart() {
        super.onStart()
        try {
            if (Build.VERSION.SDK_INT >= 34) registerScreenCaptureCallback(mainExecutor, screenshotCallback as Activity.ScreenCaptureCallback)
            if (Build.VERSION.SDK_INT >= 35) {
                val state = windowManager.addScreenRecordingCallback(mainExecutor, recordingCallback as Consumer<Int>)
                if (state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) device?.invokeMethod("recording", true)
            }
        } catch (e: Exception) {
            // Detection is a bonus; never crash because of it.
        }
    }

    @Suppress("UNCHECKED_CAST")
    override fun onStop() {
        try {
            if (Build.VERSION.SDK_INT >= 34) unregisterScreenCaptureCallback(screenshotCallback as Activity.ScreenCaptureCallback)
            if (Build.VERSION.SDK_INT >= 35) windowManager.removeScreenRecordingCallback(recordingCallback as Consumer<Int>)
        } catch (e: Exception) {
        }
        super.onStop()
    }

    // Fair play in challenges (D-070): tell Flutter when another window (notification shade, floating app, call screen)
    // takes the focus, or when split screen starts.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        device?.invokeMethod("focus", hasFocus)
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        device?.invokeMethod("multiWindow", isInMultiWindowMode)
    }

    private fun looksLikeEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") || Build.FINGERPRINT.contains("emulator") || Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for") || Build.HARDWARE.contains("goldfish") || Build.HARDWARE.contains("ranchu") ||
            Build.PRODUCT.contains("sdk") || Build.MANUFACTURER.contains("Genymotion")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Phone id (hashed in Dart) and fair-play signals (lib/features/compete/device.dart).
        device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/device").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "id" -> result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "")
                    "flags" -> {
                        val flags = mutableListOf<String>()
                        if (looksLikeEmulator()) flags.add("Emulator")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) flags.add("Split screen at start")
                        result.success(flags)
                    }
                    "multiWindow" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode)
                    else -> result.notImplemented()
                }
            }
        }
        // Screenshots and screen recording are blocked in the whole app (lib/core/secure_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/secure").setMethodCallHandler { call, result ->
            if (call.method == "set") {
                // The whole app stays protected (D-076): screens may ask for it, but never turn it off.
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        // Notifications on/off for this app, and the phone's notification settings page (lib/core/push.dart, D-064).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/notify").setMethodCallHandler { call, result ->
            when (call.method) {
                "enabled" -> {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    result.success(nm.areNotificationsEnabled())
                }
                "sdk" -> result.success(Build.VERSION.SDK_INT)
                "openSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                    }
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
