package com.wonjongseo.jp_phonebook

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PersistableBundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // バックグランド状態で着信時に連絡先の情報が表示されない不具合対応
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        Log.d("WON", pm.toString())

        if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
            @SuppressLint("BatteryLife") val battIntent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            Log.d("W", battIntent.toString())
            startActivity(battIntent)
        }
    }

//    @SuppressLint("BatteryLife")
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        // バックグランド状態で着信時に連絡先の情報が表示されない不具合対応
//        val pm = getSystemService(PowerManager::class.java)
//        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
//                .setData(Uri.parse("package:$packageName"))
//            startActivity(intent)
//        }
//
//    }
//    override fun onResume() {
//        super.onResume()
//        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
//            val perms = arrayOf(
//                android.Manifest.permission.READ_PHONE_STATE,
//                android.Manifest.permission.READ_PHONE_NUMBERS,
//                android.Manifest.permission.READ_CALL_LOG
//            )
//            val notGranted = perms.filter {
//                checkSelfPermission(it) != android.content.pm.PackageManager.PERMISSION_GRANTED
//            }
//            if (notGranted.isNotEmpty()) {
//                requestPermissions(notGranted.toTypedArray(), 1234)
//            }
//        }
//    }

}