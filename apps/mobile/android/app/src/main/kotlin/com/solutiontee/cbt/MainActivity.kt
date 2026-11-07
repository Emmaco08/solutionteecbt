package com.solutiontee.cbt

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.MediaDrm
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.function.Consumer

// FlutterFragmentActivity (a ComponentActivity) so Paystack's payment sheet can open inside the app (D-089).
class MainActivity : FlutterFragmentActivity() {
    private var device: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PaystackBridge.register(this)
    }

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

    // One account per phone (D-079). The Widevine id is the same for every app copy and every user on the phone
    // (dual apps, cloners, work profiles); the Android ID differs per copy. A factory reset changes both.
    private fun drmId(): String? {
        var drm: MediaDrm? = null
        return try {
            drm = MediaDrm(UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"))
            drm.getPropertyByteArray(MediaDrm.PROPERTY_DEVICE_UNIQUE_ID).joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        } finally {
            try {
                if (Build.VERSION.SDK_INT >= 28) drm?.close() else @Suppress("DEPRECATION") drm?.release()
            } catch (e: Exception) {
            }
        }
    }

    private val cloners = listOf(
        "com.lbe.parallel.intl", "com.parallel.space.lite", "com.parallel.space.pro", "com.excelliance.dualaid", "com.ludashi.dualspace", "com.applisto.appcloner", "com.oasisfeng.island", "net.typeblog.shelter", "com.dualspace.multispace.android", "com.jumobile.multiapp", "multi.parallel.dualspace.cloner", "com.polestar.multiaccount", "com.parallel.space.clone",
    )

    /** "clone:…" means this copy of the app runs as a dual app, in a cloner, or as another Android user: blocked. */
    private fun phoneFlags(): List<String> {
        val f = mutableListOf<String>()
        if (android.os.Process.myUid() / 100000 != 0) f.add("clone:second-user")
        val dir = filesDir.absolutePath
        if (!(dir.contains("/user/0/$packageName") || dir.startsWith("/data/data/$packageName"))) f.add("clone:data-dir")
        if (packageName != "com.solutiontee.cbt") f.add("clone:package")
        for (p in cloners) {
            try {
                packageManager.getPackageInfo(p, 0)
                f.add("cloner-installed:$p")
            } catch (e: Exception) {
            }
        }
        if (looksLikeEmulator()) f.add("emulator")
        return f
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        PaystackBridge.attach(flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        // Phone id (hashed in Dart) and fair-play signals (lib/features/compete/device.dart).
        device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/device").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "id" -> result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "")
                    "ids" -> result.success(
                        mapOf(
                            "drm" to drmId(),
                            "android" to (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""),
                            "flags" to phoneFlags(),
                        ),
                    )
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
        // Screenshots and screen recording: blocked where the admin switches say (lib/core/secure_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/secure").setMethodCallHandler { call, result ->
            if (call.method == "set") {
                // On or off as Flutter decides from the admin switches (D-080: whole app; tests, challenges, videos).
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
        // In-app update of the direct app (D-080): own version, the "install unknown apps" permission, Android's installer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "solutiontee/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "version" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
                    result.success(mapOf("code" to code, "name" to (info.versionName ?: "")))
                }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                "allowInstall" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // Background download (owner, 2026-11-07): Android's download manager keeps going when the app is
                // minimised or closed, with a notification; Flutter reads the progress while the app is open.
                "bgDownload" -> {
                    try {
                        val a = call.arguments as Map<*, *>
                        val name = a["name"] as String
                        val dir = getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS)
                        java.io.File(dir, name).let { if (it.exists()) it.delete() }
                        val req = android.app.DownloadManager.Request(Uri.parse(a["url"] as String))
                            .setTitle(a["title"] as? String ?: "SolutionTee CBT update")
                            .setDescription("Downloading the new version")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            .setDestinationInExternalFilesDir(this, android.os.Environment.DIRECTORY_DOWNLOADS, name)
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
                        result.success(dm.enqueue(req))
                    } catch (e: Exception) {
                        result.error("download", e.message, null)
                    }
                }
                "bgStatus" -> {
                    try {
                        val id = (call.arguments as Number).toLong()
                        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
                        dm.query(android.app.DownloadManager.Query().setFilterById(id)).use { c ->
                            if (c == null || !c.moveToFirst()) {
                                result.success(mapOf("status" to 0))
                            } else {
                                val status = c.getInt(c.getColumnIndexOrThrow(android.app.DownloadManager.COLUMN_STATUS))
                                val got = c.getLong(c.getColumnIndexOrThrow(android.app.DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                                val total = c.getLong(c.getColumnIndexOrThrow(android.app.DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                                val uri = c.getString(c.getColumnIndexOrThrow(android.app.DownloadManager.COLUMN_LOCAL_URI))
                                result.success(mapOf("status" to status, "got" to got, "total" to total, "path" to (uri?.let { Uri.parse(it).path } ?: "")))
                            }
                        }
                    } catch (e: Exception) {
                        result.success(mapOf("status" to 0))
                    }
                }
                "bgCancel" -> {
                    try {
                        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
                        dm.remove((call.arguments as Number).toLong())
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                "install" -> {
                    try {
                        val file = java.io.File(call.arguments as String)
                        val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.updates", file)
                        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                }
                else -> result.notImplemented()
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
