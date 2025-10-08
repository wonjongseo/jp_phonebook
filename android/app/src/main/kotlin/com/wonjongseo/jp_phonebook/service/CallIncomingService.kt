package com.wonjongseo.jp_phonebook.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.*
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.wonjongseo.jp_phonebook.LookupEngineProvider
import com.wonjongseo.jp_phonebook.R
import io.flutter.plugin.common.MethodChannel

class CallIncomingService : Service() {

    companion object {
        private const val CH_ID = "incoming_call_overlay"
        private const val CH_NAME = "Incoming overlay"
        private const val NOTI_ID = 1001
    }

    private var wm: WindowManager? = null
    private var view: View? = null
    private var tvNumber: TextView? = null

    private var tvLabel: TextView? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        createChannelIfNeeded()
        val notif = NotificationCompat.Builder(this, CH_ID)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle("Incoming call overlay")
            .setContentText("Showing overlay on top")
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTI_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTI_ID, notif)
        }

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        view = LayoutInflater.from(this).inflate(R.layout.call_incoming_overlay, null)
        tvNumber = view?.findViewById(R.id.tv_number)
        tvLabel  = view?.findViewById(R.id.tv_label)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            WindowManager.LayoutParams.TYPE_PHONE

        val flags = (WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)

// ⬇️ 핵심: 폭/높이를 WRAP_CONTENT로 하고 gravity = CENTER
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type, flags, PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            // y 오프셋 사용 금지 (가운데 유지)
        }

        wm?.addView(view, params)
        view?.setOnClickListener { stopSelf() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val number = intent?.getStringExtra("phoneNumber") ?: "Unknown"
        tvNumber?.text = number
        tvLabel?.text  = "검색 중..."

        callLookup(number)

        return START_NOT_STICKY
    }

    // CallIncomingService.kt
    private fun callLookup(number: String, attempt: Int = 0) {
        val ch = LookupEngineProvider.channel(this)

        ch.invokeMethod("lookupLabel", mapOf("number" to number), object: MethodChannel.Result {
            override fun success(result: Any?) {
                val label = (result as? String)?.takeIf { it.isNotBlank() } ?: "등록 없음"
                mainHandler.post { tvLabel?.text = label }
            }

            override fun error(code: String, msg: String?, details: Any?) {
                mainHandler.post { tvLabel?.text = "조회 오류" }
            }

            override fun notImplemented() {
                // Dart 핸들러가 아직 안 붙은 타이밍일 수 있음 → 짧게 재시도
                if (attempt < 10) {
                    mainHandler.postDelayed({ callLookup(number, attempt + 1) }, 100)
                } else {
                    mainHandler.post { tvLabel?.text = "미구현" }
                }
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        view?.let {
            try { wm?.removeView(it) } catch (_: Exception) {}
        }
        view = null
        tvNumber = null
        tvLabel = null
        wm = null
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(CH_ID, CH_NAME, NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
    }
}