/// 产品与全局常量。
class AppConstants {
  AppConstants._();

  static const String productName = 'KK远程';
  static const String applicationId = 'com.kk.remote';
  static const String appVersion = '1.2.0';
  static const String officialSite = 'https://kkyc.521.cl';
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/api/v1',
  );
  static const String defaultSignalingUrl = String.fromEnvironment(
    'SIGNALING_URL',
    defaultValue: 'ws://127.0.0.1:8081/ws/signaling',
  );
  static const String platformChannel = 'com.kk.remote/platform';
  static const int defaultLanPort = 38401;
  static const int smsCountdown = 60;
  static const int connectConfirmTimeout = 30;

  /// 桌面端局域网广播固定魔数，用于过滤非 KK远程 设备。
  static const String lanMagic = 'KKREMOTE_LAN_V1';

  static const List<String> registerProblemTypes = [
    '功能异常',
    '流畅度问题',
    '桌面端操作问题',
    '远程问题',
    '未成年有害信息举报',
    '意见与建议',
    '用户登录或注册问题',
    '其他问题',
  ];

  /// 第三方渠道展示名称与图标字符（图标资源由后台下发，缺失时使用字母占位）。
  static const Map<String, String> providerNames = {
    'wechat': '微信',
    'alipay': '支付宝',
    'qq': 'QQ',
    'apple': 'Apple',
  };

  static const Map<String, String> providerGlyphs = {
    'wechat': '微',
    'alipay': '支',
    'qq': 'Q',
    'apple': '',
  };

  static const List<String> qualityPresets = [
    '流畅',
    '平衡',
    '高清',
    '游戏高刷',
  ];

  static const List<String> qualityPresetValues = [
    'smooth',
    'balanced',
    'hd',
    'game',
  ];

  static const List<String> repeatRules = ['none', 'daily', 'weekly', 'workday'];
  static const Map<String, String> repeatRuleNames = {
    'none': '仅一次',
    'daily': '每天',
    'weekly': '每周',
    'workday': '工作日',
  };
}

/// 本地设置键。
class SettingsKeys {
  SettingsKeys._();

  static const apiOverride = 'api_base_url_override';
  static const signalingOverride = 'signaling_url_override';
  static const serverApiBaseUrl = 'server_api_base_url';
  static const serverSignalingUrl = 'server_signaling_url';

  static const qualityPreset = 'quality_preset';
  static const resolutionScale = 'resolution_scale';
  static const fpsLimit = 'fps_limit';
  static const bitrateLimit = 'bitrate_limit';
  static const encoder = 'encoder';
  static const adaptiveQuality = 'adaptive_quality';
  static const keepScreenOn = 'keep_screen_on';
  static const fontScale = 'font_scale';
  static const uiScale = 'ui_scale';
  static const orientationLock = 'orientation_lock';

  static const audioEnabled = 'audio_enabled';
  static const volume = 'volume';
  static const micPassthrough = 'mic_passthrough';

  static const touchMode = 'touch_mode';
  static const touchSensitivity = 'touch_sensitivity';
  static const scrollSensitivity = 'scroll_sensitivity';
  static const gestureSensitivity = 'gesture_sensitivity';
  static const trackballMode = 'trackball_mode';
  static const threeFingerEnabled = 'three_finger_enabled';
  static const hapticsEnabled = 'haptics_enabled';
  static const hideCursor = 'hide_cursor';
  static const hotkeyFavorites = 'hotkey_favorites';

  static const autoReconnect = 'auto_reconnect';
  static const reconnectInterval = 'reconnect_interval';
  static const networkHint = 'network_hint';
  static const trafficReminderMb = 'traffic_reminder_mb';
  static const p2pPreferred = 'p2p_preferred';
  static const allowRelay = 'allow_relay';
  static const onlyWifi = 'only_wifi';
  static const saveDataMode = 'save_data_mode';
  static const lowBandwidthAdaptive = 'low_bandwidth_adaptive';
  static const minBitrate = 'min_bitrate';
  static const restoreThreshold = 'restore_threshold';

  static const backgroundKeepAlive = 'background_keep_alive';
  static const notificationEnabled = 'notification_enabled';
  static const incomingCallPush = 'incoming_call_push';

  static const clipboardSync = 'clipboard_sync';
  static const appLockEnabled = 'app_lock_enabled';
  static const biometricEnabled = 'biometric_enabled';
  static const cloudSync = 'cloud_sync';

  static const language = 'language';
  static const accessibilityGuideSeen = 'accessibility_guide_seen';
  static const protocolAgreed = 'protocol_agreed';
  static const downloadDir = 'download_dir';
  static const lastDeviceGroup = 'last_device_group';
  static const lanDiscoveryPort = 'lan_discovery_port';
}
