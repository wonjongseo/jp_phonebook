package com.wonjongseo.jp_phonebook.telephony


import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import com.wonjongseo.jp_phonebook.MainApplication
import io.flutter.plugin.common.MethodChannel

class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"

        private var lastState: String = TelephonyManager.EXTRA_STATE_IDLE
        private var ringStartedAt: Long = 0L
        private var overlayShownAt: Long = 0L

        private var latestIncoming: String = "Unknown"

        private var hasShownThisSession: Boolean = false

        private val handler = Handler(Looper.getMainLooper())
        private var pendingShow: Runnable? = null
    }

    private fun channel(context: Context) = MethodChannel(
        MainApplication.engine(context).dartExecutor.binaryMessenger,
        "incoming_overlay_channel"
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val extra = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        if (!extra.isNullOrBlank()) latestIncoming = extra

        Log.d(TAG, "onReceive: ${intent.action}, state=$state")
        Log.d(TAG, "hasExtra=${intent.hasExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)} incoming=$extra")
        Log.d(TAG, "state=$state, last=$lastState, number=$latestIncoming")

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                val now = System.currentTimeMillis()
                if (lastState != TelephonyManager.EXTRA_STATE_RINGING) {
                    ringStartedAt = now
                    latestIncoming = if (!extra.isNullOrBlank()) extra!! else "Unknown"
                    hasShownThisSession = false
                }


                if (!hasShownThisSession) {
                    pendingShow?.let { handler.removeCallbacks(it) }
                    pendingShow = Runnable {
                        channel(context).invokeMethod("showOverlay",
                            latestIncoming.ifBlank { "Unknown" })
                        overlayShownAt = System.currentTimeMillis()
                        hasShownThisSession = true
                    }
                    handler.postDelayed(pendingShow!!, 500)
                } else {
                    channel(context).invokeMethod("showOverlay",
                        latestIncoming.ifBlank { "Unknown" })
                }

                lastState = state
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                lastState = state
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {

                pendingShow?.let { handler.removeCallbacks(it) }
                pendingShow = null

                val now = System.currentTimeMillis()
                val shownFor = now - overlayShownAt
                val elapsedSinceRing = if (ringStartedAt == 0L) 0L else now - ringStartedAt

                val shouldClose =
                    hasShownThisSession &&
                            shownFor >= 1200L &&
                            (lastState == TelephonyManager.EXTRA_STATE_RINGING ||
                                    lastState == TelephonyManager.EXTRA_STATE_OFFHOOK)

                Log.d(TAG, "IDLE: elapsedSinceRing=$elapsedSinceRing shownFor=$shownFor shouldClose=$shouldClose")
                if (shouldClose) {
                    channel(context).invokeMethod("closeOverlay", null)
                } else {
                    Log.d(TAG, "IDLE ignored (spurious/too-early)")
                }

                lastState = state
                ringStartedAt = 0L
                overlayShownAt = 0L
                hasShownThisSession = false
                latestIncoming = "Unknown"
            }
        }
    }
}
