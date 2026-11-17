import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// 平台能力桥：画中画、投屏、屏幕录制、手柄与震动。
/// 未实现的平台返回 unavailable，但调用路径保持一致，便于后续原生补齐。
class NativeBridge {
  NativeBridge._();

  static final NativeBridge instance = NativeBridge._();
  static const MethodChannel _channel = MethodChannel(AppConstants.platformChannel);

  Future<bool> isSupported(String feature) async {
    try {
      final result = await _channel.invokeMethod<bool>('isSupported', {'feature': feature});
      return result ?? false;
    } on PlatformException catch (error) {
      debugPrint('NativeBridge.isSupported($feature) failed: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> enterPictureInPicture() async {
    try {
      return await _channel.invokeMethod<bool>('enterPictureInPicture') ?? false;
    } on PlatformException catch (error) {
      debugPrint('PiP unavailable: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> exitPictureInPicture() async {
    try {
      return await _channel.invokeMethod<bool>('exitPictureInPicture') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> startCast({
    int width = 720,
    int height = 1280,
    int fps = 30,
    int bitrateKbps = 2000,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('startCast', {
        'width': width,
        'height': height,
        'fps': fps,
        'bitrateKbps': bitrateKbps,
      }) ?? false;
    } on PlatformException catch (error) {
      debugPrint('Cast unavailable: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> stopCast() async {
    try {
      return await _channel.invokeMethod<bool>('stopCast') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> startScreenRecording() async {
    try {
      return await _channel.invokeMethod<bool>('startScreenRecording') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Screen recording unavailable: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> stopScreenRecording() async {
    try {
      return await _channel.invokeMethod<String>('stopScreenRecording');
    } on MissingPluginException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listGamepads() async {
    try {
      final result = await _channel.invokeListMethod<dynamic>('listGamepads');
      return (result ?? const [])
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> vibrate({int durationMs = 30}) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {'durationMs': durationMs});
    } on MissingPluginException {
      HapticFeedback.mediumImpact();
    }
  }

  Future<bool> setKeepScreenOn(bool enabled) async {
    try {
      return await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': enabled}) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> startRemoteForegroundService() async {
    try {
      return await _channel.invokeMethod<bool>('startForegroundService') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> stopRemoteForegroundService() async {
    try {
      return await _channel.invokeMethod<bool>('stopForegroundService') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
