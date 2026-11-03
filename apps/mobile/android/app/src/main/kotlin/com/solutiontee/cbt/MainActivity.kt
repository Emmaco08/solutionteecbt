package com.solutiontee.cbt

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Blocks screenshots and screen recording while a test is open (lib/core/secure_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/secure").setMethodCallHandler { call, result ->
            if (call.method == "set") {
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
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
