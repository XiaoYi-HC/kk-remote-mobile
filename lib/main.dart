import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/platform/notification_service.dart';
import 'core/storage/local_store.dart';
import 'data/models/device.dart';
import 'features/auth/state/auth_provider.dart';
import 'features/devices/state/devices_provider.dart';
import 'state/app_services.dart';
import 'state/config_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  final store = await LocalStore.create();
  final settings = SettingsProvider(store);
  final services = AppServices(settings: settings, store: store);
  final auth = AuthProvider(
    api: services.api,
    authApi: services.authApi,
    accountApi: services.accountApi,
    store: store,
  );
  final config = ConfigProvider(
    authApi: services.authApi,
    settings: settings,
    api: services.api,
  );
  final devices = DevicesProvider(
    api: services.deviceApi,
    settings: settings,
    lanDiscovery: services.lanDiscovery,
    services: services,
  );

  try {
    await NotificationService.instance.init();
  } catch (_) {
    // 通知初始化失败不应阻塞 App 启动。
  }
  NotificationService.instance.onNotificationTap = (payload) {
    if (payload['type'] == 'incoming_call') {
      devices.showIncomingCall(
        Device(
          name: payload['deviceName']?.toString() ?? '',
          deviceCode: payload['deviceCode']?.toString() ?? '',
          online: true,
        ),
        source: 'push',
      );
    }
  };

  // 启动时尽快读取后台配置，但最多等待 3 秒，避免网络异常卡住启动。
  await Future.any([
    config.load(),
    Future<void>.delayed(const Duration(seconds: 3)),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ConfigProvider>.value(value: config),
        ChangeNotifierProvider<DevicesProvider>.value(value: devices),
      ],
      child: KKRemoteApp(auth: auth, settings: settings),
    ),
  );
}
