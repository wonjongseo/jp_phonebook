package com.wonjongseo.jp_phonebook

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import com.wonjongseo.jp_phonebook.service.CallIncomingService

class MainActivity : FlutterActivity() {

    private val CHANNEL = "native_overlay_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestOverlayPermission" -> {
                        val ok = requestOverlayPermission()
                        result.success(ok)
                    }
                    "requestBatteryException" -> {
                        val ok = requestBatteryException()
                        result.success(ok)
                    }
                    "requestRuntimePermissions" -> {
                        requestRuntimePermissions()
                        result.success(true)
                    }
                    "startDummyOverlay" -> {
                        val number = call.argument<String>("number") ?: "01012345678"
                        startOverlay(number)
                        result.success(true)
                    }
                    "stopOverlay" -> {
                        stopService(Intent(this, CallIncomingService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startOverlay(number: String) {
        val intent = Intent(this, CallIncomingService::class.java)
            .putExtra("phoneNumber", number)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun requestRuntimePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val perms = arrayOf(
                android.Manifest.permission.READ_PHONE_STATE,
                android.Manifest.permission.READ_PHONE_NUMBERS,
                android.Manifest.permission.READ_CALL_LOG,
            )
            val need = perms.filter {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            }
            if (need.isNotEmpty()) {
                requestPermissions(need.toTypedArray(), 1234)
            }
        }
        // Android 13+ 알림 권한도 앱 화면에서 요청 권장 (필요시)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1235)
            }
        }
    }

    private fun requestOverlayPermission(): Boolean {
        return if (Settings.canDrawOverlays(this)) true
        else {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"))
            startActivity(intent)
            false
        }
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryException(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return if (pm.isIgnoringBatteryOptimizations(packageName)) true
        else {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:$packageName"))
            startActivity(intent)
            false
        }
    }
}