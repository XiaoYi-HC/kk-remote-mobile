package com.kk.remote

import android.app.PictureInPictureParams
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Rational
import android.view.InputDevice
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.kk.remote/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
                    else -> result.notImplemented()
                }
            }
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
