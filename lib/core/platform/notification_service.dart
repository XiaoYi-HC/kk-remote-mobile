import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 本地通知：连接请求（来电式）、站内消息与离线告警。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  void Function(Map<String, dynamic> payload)? onIncomingCallAction;
  void Function(Map<String, dynamic> payload)? onNotificationTap;

  static const String _channelId = 'kk_remote_incoming';
  static const String _channelName = '连接与消息提醒';

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = _decodePayload(response.payload);
        if (response.actionId == 'accept') {
          onIncomingCallAction?.call({...payload, 'accepted': true});
        } else if (response.actionId == 'reject') {
          onIncomingCallAction?.call({...payload, 'accepted': false});
        } else {
          onNotificationTap?.call(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: (response) {
        // 后台动作由原生侧拉起 App 后通过启动参数处理，这里保留回调入口。
        debugPrint('background notification action: ${response.actionId}');
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: '连接请求、客服回复与设备离线提醒',
        importance: Importance.high,
        playSound: true,
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) return true;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return iosGranted ?? status.isGranted;
  }

  Future<void> showIncomingCall({
    required String deviceName,
    required String deviceCode,
    String? source,
  }) async {
    await init();
    final payload = jsonEncode({
      'type': 'incoming_call',
      'deviceCode': deviceCode,
      'deviceName': deviceName,
      'source': source ?? 'remote',
    });
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '连接请求、客服回复与设备离线提醒',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction('accept', '接听', showsUserInterface: true),
        AndroidNotificationAction('reject', '拒绝', cancelNotification: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '${deviceName.isEmpty ? '设备' : deviceName} 请求远程连接',
      '识别码 $deviceCode · 点击接听或拒绝',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> showMessage({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload == null ? null : jsonEncode(payload),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Map<String, dynamic> _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      return value is Map ? value.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }
}
