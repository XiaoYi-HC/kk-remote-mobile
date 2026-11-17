import '../core/network/api_client.dart';
import '../core/platform/native_bridge.dart';
import '../core/platform/notification_service.dart';
import '../core/storage/local_store.dart';
import '../data/api/account_api.dart';
import '../data/api/auth_api.dart';
import '../data/api/automation_api.dart';
import '../data/api/content_api.dart';
import '../data/api/device_api.dart';
import '../data/api/session_api.dart';
import '../data/api/support_api.dart';
import '../data/lan/lan_discovery_service.dart';
import 'settings_provider.dart';

/// 全局服务容器，避免页面重复构造 API 与平台服务。
class AppServices {
  AppServices({required this.settings, required this.store})
      : api = ApiClient(baseUrl: settings.resolvedApiBaseUrl) {
    authApi = AuthApi(api);
    accountApi = AccountApi(api);
    deviceApi = DeviceApi(api);
    contentApi = ContentApi(api);
    supportApi = SupportApi(api);
    sessionApi = SessionApi(api);
    automationApi = AutomationApi(api);
    lanDiscovery = LanDiscoveryService();
  }

  final SettingsProvider settings;
  final LocalStore store;
  final ApiClient api;

  late final AuthApi authApi;
  late final AccountApi accountApi;
  late final DeviceApi deviceApi;
  late final ContentApi contentApi;
  late final SupportApi supportApi;
  late final SessionApi sessionApi;
  late final AutomationApi automationApi;
  late final LanDiscoveryService lanDiscovery;

  NativeBridge get native => NativeBridge.instance;
  NotificationService get notifications => NotificationService.instance;

  /// 客服 WebSocket 与 REST API 同源：http(s)://host:8080/api/v1 -> ws(s)://host:8080/ws/support。
  String get supportSocketUrl {
    final api = Uri.parse(settings.resolvedApiBaseUrl);
    final scheme = api.scheme == 'https' ? 'wss' : 'ws';
    return api.replace(scheme: scheme, path: '/ws/support', query: '').toString();
  }

  String get signalingUrl => settings.resolvedSignalingUrl;

  Future<void> reinitializeApi() async {
    api.updateBaseUrl(settings.resolvedApiBaseUrl);
  }
}
