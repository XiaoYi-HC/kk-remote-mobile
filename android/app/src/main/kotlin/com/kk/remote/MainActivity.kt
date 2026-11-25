package com.kk.remote

import android.app.NotificationManager
import android.app.PictureInPictureParams
import android.content.ContentValues
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.MediaStore
import android.util.Rational
import android.util.Log
import android.view.InputDevice
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.kk.remote/platform"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        channel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> {
                        val feature = call.argument<String>("feature") ?: ""
                        val supported = when (feature) {
                            "pip" -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                            "gamepad" -> true
                            "foreground" -> true
                            else -> false
                        }
                        result.success(supported)
                    }
                    "enterPictureInPicture" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(9, 16))
                                    .build()
                                result.success(enterPictureInPictureMode(params))
                            } catch (error: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "exitPictureInPicture" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
                            finishAndRemoveTask()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    // 媒体投影与屏幕录制需要原生 MediaProjection 授权流程，当前仅保留完整调用路径。
                    "startCast", "startScreenRecording" -> result.success(false)
                    "stopCast", "stopScreenRecording" -> result.success(null)
                    "listGamepads" -> result.success(listGamepads())
                    "vibrate" -> {
                        val duration = (call.argument<Int>("durationMs") ?: 30).toLong()
                        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
                        if (vibrator == null || !vibrator.hasVibrator()) {
                            result.success(false)
                        } else {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(
                                    VibrationEffect.createOneShot(
                                        duration,
                                        VibrationEffect.DEFAULT_AMPLITUDE
                                    )
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(duration)
                            }
                            result.success(true)
                        }
                    }
                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(true)
                    }
                    "startForegroundService" -> {
                        val intent = Intent(this, RemoteForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopService(Intent(this, RemoteForegroundService::class.java))
                        result.success(true)
                    }
                    "startScreenShareService" -> {
                        try {
                            val intent = Intent(this, ScreenShareService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (error: Exception) {
                            Log.e("MainActivity", "startScreenShareService failed", error)
                            result.error(
                                "foreground_service_failed",
                                error.message ?: "无法启动屏幕共享服务",
                                null
                            )
                        }
                    }
                    "stopScreenShareService" -> {
                        stopService(Intent(this, ScreenShareService::class.java))
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                            manager.canUseFullScreenIntent()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "saveImageToGallery" -> saveImageToGallery(call.argument<String>("path"), result)
                    "getInitialLink" -> result.success(intent?.dataString)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { link ->
            methodChannel?.invokeMethod("onDeepLink", link)
        }
    }

    private fun saveImageToGallery(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(false)
            return
        }
        Thread {
            var success = false
            try {
                val bitmap = BitmapFactory.decodeFile(path)
                if (bitmap != null) {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, File(path).name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/KKRemote")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    if (uri != null) {
                        contentResolver.openOutputStream(uri)?.use { output ->
                            success = bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                        }
                        values.clear()
                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                        success = true
                    }
                    bitmap.recycle()
                }
            } catch (_: Exception) {
                success = false
            }
            runOnUiThread { result.success(success) }
        }.start()
    }

    private fun listGamepads(): List<Map<String, Any>> {
        val devices = mutableListOf<Map<String, Any>>()
        for (id in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(id) ?: continue
            val sources = device.sources
            val isGamepad = (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
                (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
            if (isGamepad) {
                devices.add(
                    mapOf(
                        "id" to device.id,
                        "name" to device.name,
                        "descriptor" to device.descriptor,
                        "type" to "gamepad"
                    )
                )
            }
        }
        return devices
    }
}
