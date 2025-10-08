package com.wonjongseo.jp_phonebook.telephony

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import com.wonjongseo.jp_phonebook.service.CallIncomingService

class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"
        private val handler = Handler(Looper.getMainLooper())

        private var lastState: String = TelephonyManager.EXTRA_STATE_IDLE
        private var latestIncoming: String = "Unknown"
        private var pendingShow: Runnable? = null
        private var hasShownThisSession = false
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val extra = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        if (!extra.isNullOrBlank()) latestIncoming = extra

        Log.d(TAG, "state=$state, last=$lastState, incoming=$latestIncoming")

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (lastState != TelephonyManager.EXTRA_STATE_RINGING) {
                    hasShownThisSession = false
                }
                if (!hasShownThisSession) {
                    pendingShow?.let { handler.removeCallbacks(it) }
                    pendingShow = Runnable {
                        startOverlayService(context, latestIncoming)
                        hasShownThisSession = true
                    }
                    handler.postDelayed(pendingShow!!, 500) // 번호 늦게 붙는 단말 대응
                }
                lastState = state
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                lastState = state
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                pendingShow?.let { handler.removeCallbacks(it) }
                pendingShow = null
                // 통화 종료 시 오버레이 닫기
                context.stopService(Intent(context, CallIncomingService::class.java))

                // 세션 리셋
                lastState = state
                latestIncoming = "Unknown"
                hasShownThisSession = false
            }
        }
    }

    private fun startOverlayService(ctx: Context, number: String) {
        val svc = Intent(ctx, CallIncomingService::class.java)
            .putExtra("phoneNumber", number.ifBlank { "Unknown" })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(svc)
        } else {
            ctx.startService(svc)
        }
    }
}