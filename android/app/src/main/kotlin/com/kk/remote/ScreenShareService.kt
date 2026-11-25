package com.kk.remote

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * 屏幕共享前台服务：Android 14+ 要求 MediaProjection 采集前必须存在
 * mediaProjection 类型的前台服务，否则系统会拒绝创建虚拟屏幕。
 */
class ScreenShareService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("KK远程正在共享屏幕")
            .setContentText("桌面端正在观看本机画面")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            // 未授予录音权限时不能声明 microphone 类型，否则 startForeground 会抛 SecurityException。
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
            ) {
                types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            try {
                startForeground(NOTIFICATION_ID, notification, types)
            } catch (error: Exception) {
                // 部分 ROM / 缺少投影授权时会拒绝 mediaProjection 类型的前台服务。
                // 异常如果落到主线程会直接杀掉 App，这里必须兜住并优雅退出。
                Log.e(TAG, "startForeground with mediaProjection failed", error)
                stopSelf()
                return START_NOT_STICKY
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        @Suppress("DEPRECATION")
        stopForeground(true)
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "屏幕共享", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    companion object {
        private const val TAG = "ScreenShareService"
        private const val CHANNEL_ID = "kk_screen_share"
        private const val NOTIFICATION_ID = 4301
    }
}
