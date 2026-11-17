import '../../core/constants/app_constants.dart';
import '../../core/utils/json_utils.dart';
import 'common.dart';

class BootstrapConfig {
  const BootstrapConfig({
    this.productName = AppConstants.productName,
    this.platform = '',
    this.apiBaseUrl = '',
    this.signalingUrl = '',
    this.iceServers = const [],
    this.turnTtlSeconds = 600,
    this.loginMethods = const {},
    this.registerMethods = const {},
    this.allowGuest = true,
    this.thirdPartyChannels = const [],
    this.features = const {},
    this.watermark = const {},
    this.quality = const {},
    this.latestVersion,
    this.forceUpdate = false,
    this.announcements = const [],
    this.protocols = const {},
    this.ticketPhoneRequired = false,
    this.supportFallback = '',
    this.lanDiscoveryPort = AppConstants.defaultLanPort,
    this.remoteSleepEnabled = true,
    this.sessionRecordEnabled = true,
  });

  final String productName;
  final String platform;
  final String apiBaseUrl;
  final String signalingUrl;
  final List<IceServerConfig> iceServers;
  final int turnTtlSeconds;
  final Map<String, bool> loginMethods;
  final Map<String, bool> registerMethods;
  final bool allowGuest;
  final List<ThirdPartyChannel> thirdPartyChannels;
  final Map<String, dynamic> features;
  final Map<String, dynamic> watermark;
  final Map<String, dynamic> quality;
  final AppUpdateInfo? latestVersion;
  final bool forceUpdate;
  final List<Announcement> announcements;
  final Map<String, dynamic> protocols;
  final bool ticketPhoneRequired;
  final String supportFallback;
  final int lanDiscoveryPort;
  final bool remoteSleepEnabled;
  final bool sessionRecordEnabled;

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    final protocols = asMap(json['protocols']);
    return BootstrapConfig(
      productName: asString(json['productName'], fallback: AppConstants.productName),
      platform: asString(json['platform']),
      apiBaseUrl: asString(json['apiBaseUrl']),
      signalingUrl: asString(json['signalingUrl']),
      iceServers: asList(json['iceServers'])
          .map((item) => IceServerConfig.fromJson(asMap(item)))
          .where((item) => item.urls.isNotEmpty)
          .toList(),
      turnTtlSeconds: asInt(json['turnTtlSeconds'], fallback: 600),
      loginMethods: asMap(json['loginMethods']).map(
        (key, value) => MapEntry(key, asBool(value, fallback: true)),
      ),
      registerMethods: asMap(json['registerMethods']).map(
        (key, value) => MapEntry(key, asBool(value, fallback: true)),
      ),
      allowGuest: asBool(json['allowGuest'], fallback: true),
      thirdPartyChannels: asList(json['thirdPartyChannels'])
          .map((item) => ThirdPartyChannel.fromJson(asMap(item)))
          .toList()
        ..sort((a, b) => a.sort.compareTo(b.sort)),
      features: asMap(json['features']),
      watermark: asMap(json['watermark']),
      quality: asMap(json['quality']),
      latestVersion: json['latestVersion'] is Map
          ? AppUpdateInfo.fromJson(asMap(json['latestVersion']))
          : null,
      forceUpdate: asBool(json['forceUpdate']),
      announcements: asList(json['announcements'])
          .map((item) => Announcement.fromJson(asMap(item)))
          .toList(),
      protocols: protocols,
      ticketPhoneRequired: asBool(json['ticketPhoneRequired']),
      supportFallback: asString(json['supportFallback']),
      lanDiscoveryPort: asInt(json['lanDiscoveryPort'], fallback: AppConstants.defaultLanPort),
      remoteSleepEnabled: asBool(json['remoteSleepEnabled'], fallback: true),
      sessionRecordEnabled: asBool(json['sessionRecordEnabled'], fallback: true),
    );
  }

  /// 后台未下发配置时视为全部登录方式可用；下发后按开关控制。
  bool loginEnabled(String method) {
    if (loginMethods.isEmpty) return true;
    return loginMethods[method] ?? true;
  }

  bool registerEnabled(String method) {
    if (registerMethods.isEmpty) return true;
    return registerMethods[method] ?? true;
  }

  bool featureEnabled(String key, {bool fallback = false}) =>
      asBool(features[key], fallback: fallback);

  List<ThirdPartyChannel> get appleChannels =>
      thirdPartyChannels.where((item) => item.provider == 'apple').toList();

  List<ThirdPartyChannel> channelForLogin() => thirdPartyChannels;

  static BootstrapConfig empty() => const BootstrapConfig();
}
