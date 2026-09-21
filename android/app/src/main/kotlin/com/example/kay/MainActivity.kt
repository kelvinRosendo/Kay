package com.example.kay

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "KAY_ASSISTANT"
        private const val MIC_PERMISSION_REQUEST_CODE = 7301
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7402
    }

    private var eventsChannel: MethodChannel? = null
    private var roleResultCallback: ((Boolean) -> Unit)? = null

    @Suppress("DEPRECATION")
    private val roleRequestCode = 7501

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kay/voice").setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences("kay_voice", MODE_PRIVATE)
            when (call.method) {
                "get" -> result.success(preferences.getString("name", null))
                "set" -> {
                    val name = call.argument<String>("name")
                    preferences.edit().putString("name", name).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        Log.i(TAG, "KAY_ASSISTANT_MAINACTIVITY_CONFIGURED")

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7401)
        }

        // ── Background channel: start / stop service ───────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/background",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, KayForegroundService::class.java).apply {
                        action = KayForegroundService.ACTION_START
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(null)
                }
                "stop" -> {
                    val intent = Intent(this, KayForegroundService::class.java).apply {
                        action = KayForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "pause_wake" -> result.success(null)
                "resume_wake" -> result.success(null)
                "is_running" -> result.success(KayForegroundService.running)
                "vosk_ready" -> result.success(KayForegroundService.voskReady)
                "voice_service_active" -> result.success(
                    KayVoiceInteractionService.isAvailable() &&
                        KayVoiceInteractionService.sessionActive,
                )
                "set_waits" -> {
                    val waitMs = (call.argument<Number>("wait_ms")?.toLong() ?: 10_000)
                    val silenceMs = (call.argument<Number>("silence_ms")?.toLong() ?: 5_000)
                    KayForegroundService.instance?.setWaitConfig(waitMs, silenceMs)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Permissions channel ────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "microphone" -> result.success(
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                        PackageManager.PERMISSION_GRANTED
                    ) "granted" else "denied",
                )
                "notifications" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        result.success(
                            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED
                            ) "granted" else "denied",
                        )
                    } else {
                        result.success("granted")
                    }
                }
                "requestMicrophone" -> {
                    requestPermissions(
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        MIC_PERMISSION_REQUEST_CODE,
                    )
                    result.success(null)
                }
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            NOTIFICATION_PERMISSION_REQUEST_CODE,
                        )
                    }
                    result.success(null)
                }
                "openAppSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.fromParts("package", packageName, null),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APP_NOTIFICATION_SETTINGS,
                    ).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Events channel: service → Flutter ──────────────────────
        eventsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/service_events",
        )
        KayForegroundService.onWakeDetected = {
            eventsChannel?.invokeMethod("wake_detected", null)
        }
        KayForegroundService.onStateUpdate = { state ->
            eventsChannel?.invokeMethod("state_changed", state)
        }

        // ── Assistant role channel ─────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/assistant_role",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val available = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
                    Log.i(TAG, "KAY_ASSISTANT_ROLE_AVAILABLE: $available")
                    result.success(available)
                }
                "isHeld" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val rm = getSystemService(RoleManager::class.java)
                        val roleAvailable = rm.isRoleAvailable(RoleManager.ROLE_ASSISTANT)
                        val held = rm.isRoleHeld(RoleManager.ROLE_ASSISTANT)
                        Log.i(TAG, "KAY_ASSISTANT_ROLE_HELD: $held (available=$roleAvailable)")
                        result.success(held)
                    } else {
                        Log.i(TAG, "KAY_ASSISTANT_ROLE_HELD: false (API < Q)")
                        result.success(false)
                    }
                }
                "requestRole" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val rm = getSystemService(RoleManager::class.java)
                        if (!rm.isRoleAvailable(RoleManager.ROLE_ASSISTANT)) {
                            Log.w(TAG, "KAY_ASSISTANT_ROLE_NOT_AVAILABLE_ON_DEVICE")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        Log.i(TAG, "KAY_ASSISTANT_ROLE_REQUESTING")
                        val intent = rm.createRequestRoleIntent(RoleManager.ROLE_ASSISTANT)
                        roleResultCallback = { granted ->
                            Log.i(TAG, "KAY_ASSISTANT_ROLE_RESULT: $granted")
                            result.success(granted)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, roleRequestCode)
                    } else {
                        Log.w(TAG, "KAY_ASSISTANT_ROLE_API_TOO_LOW")
                        result.success(false)
                    }
                }
                "openAssistantSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (_: Exception) {
                        val intent = Intent(Settings.ACTION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Legacy wake_word channel: kept for forward compat ──────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/wake_word",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start", "stop", "dispose" -> result.success(null)
                else -> result.notImplemented()
            }
        }

        // ── Legacy local_commands channel (unchanged) ─────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kay/local_commands",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val command = call.arguments as? String
            val packageName = when (command) {
                "youtube" -> "com.google.android.youtube"
                "spotify" -> "com.spotify.music"
                "chrome" -> "com.android.chrome"
                "settings" -> null
                else -> {
                    result.error("invalid_command", "Comando não suportado", null)
                    return@setMethodCallHandler
                }
            }
            try {
                val intent = if (command == "settings") {
                    Intent(Settings.ACTION_SETTINGS)
                } else {
                    packageManager.getLaunchIntentForPackage(packageName!!)
                }
                if (intent == null) {
                    result.success("unavailable")
                } else {
                    startActivity(intent)
                    result.success("opened")
                }
            } catch (_: android.content.ActivityNotFoundException) {
                result.success("unavailable")
            } catch (_: SecurityException) {
                result.success("failed")
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == roleRequestCode) {
            val granted = resultCode == RESULT_OK
            Log.i(TAG, "KAY_ASSISTANT_ROLE_ACTIVITY_RESULT: granted=$granted resultCode=$resultCode")
            roleResultCallback?.invoke(granted)
            roleResultCallback = null
        }
    }

    override fun onResume() {
        super.onResume()
        KayForegroundService.isFlutterInForeground = true
        sendForegroundState(true)
    }

    override fun onPause() {
        super.onPause()
        KayForegroundService.isFlutterInForeground = false
        sendForegroundState(false)
    }

    override fun onDestroy() {
        KayForegroundService.onWakeDetected = null
        KayForegroundService.onStateUpdate = null
        eventsChannel = null
        super.onDestroy()
    }

    private fun sendForegroundState(foreground: Boolean) {
        val intent = Intent(this, KayForegroundService::class.java).apply {
            action = KayForegroundService.ACTION_SET_FOREGROUND
            putExtra("foreground", foreground)
        }
        startService(intent)
    }
}
