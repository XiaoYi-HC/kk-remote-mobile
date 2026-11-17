import '../../core/utils/json_utils.dart';

class UserProfile {
  const UserProfile({
    this.id = 0,
    this.username = '',
    this.nickname = '',
    this.avatar = '',
    this.signature = '',
    this.phone = '',
    this.email = '',
    this.status = 'normal',
    this.totpEnabled = false,
    this.createdAt,
    this.quotaConcurrent = 0,
    this.quotaMonthlyTrafficMb = 0,
    this.deletionRequestedAt,
    this.deletionEffectiveAt,
    this.unreadMessages = 0,
  });

  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String signature;
  final String phone;
  final String email;
  final String status;
  final bool totpEnabled;
  final DateTime? createdAt;
  final int quotaConcurrent;
  final int quotaMonthlyTrafficMb;
  final DateTime? deletionRequestedAt;
  final DateTime? deletionEffectiveAt;
  final int unreadMessages;

  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    if (username.isNotEmpty) return username;
    return 'KK用户';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: asInt(json['id']),
      username: asString(json['username']),
      nickname: asString(json['nickname']),
      avatar: asString(json['avatar']),
      signature: asString(json['signature']),
      phone: asString(json['phone']),
      email: asString(json['email']),
      status: asString(json['status'], fallback: 'normal'),
      totpEnabled: asBool(json['totpEnabled']),
      createdAt: asDate(json['createdAt']),
      quotaConcurrent: asInt(json['quotaConcurrent']),
      quotaMonthlyTrafficMb: asInt(json['quotaMonthlyTrafficMb']),
      deletionRequestedAt: asDate(json['deletionRequestedAt']),
      deletionEffectiveAt: asDate(json['deletionEffectiveAt']),
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? signature,
    String? avatar,
    String? phone,
    String? email,
    bool? totpEnabled,
    int? unreadMessages,
  }) {
    return UserProfile(
      id: id,
      username: username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      signature: signature ?? this.signature,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status,
      totpEnabled: totpEnabled ?? this.totpEnabled,
      createdAt: createdAt,
      quotaConcurrent: quotaConcurrent,
      quotaMonthlyTrafficMb: quotaMonthlyTrafficMb,
      deletionRequestedAt: deletionRequestedAt,
      deletionEffectiveAt: deletionEffectiveAt,
      unreadMessages: unreadMessages ?? this.unreadMessages,
    );
  }
}

class LoginDevice {
  const LoginDevice({
    required this.id,
    this.deviceName = '',
    this.deviceType = '',
    this.os = '',
    this.ip = '',
    this.region = '',
    this.lastSeenAt,
    this.current = false,
  });

  final int id;
  final String deviceName;
  final String deviceType;
  final String os;
  final String ip;
  final String region;
  final DateTime? lastSeenAt;
  final bool current;

  factory LoginDevice.fromJson(Map<String, dynamic> json) {
    return LoginDevice(
      id: asInt(json['id']),
      deviceName: asString(json['deviceName'], fallback: '未知设备'),
      deviceType: asString(json['deviceType']),
      os: asString(json['os']),
      ip: asString(json['ip']),
      region: asString(json['region']),
      lastSeenAt: asDate(json['lastSeenAt']),
      current: asBool(json['current']),
    );
  }
}

class UserIdentity {
  const UserIdentity({
    this.provider = '',
    this.nickname = '',
    this.avatar = '',
    this.boundAt,
    this.maskedOpenId = '',
  });

  final String provider;
  final String nickname;
  final String avatar;
  final DateTime? boundAt;
  final String maskedOpenId;

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      provider: asString(json['provider']),
      nickname: asString(json['nickname']),
      avatar: asString(json['avatar']),
      boundAt: asDate(json['boundAt']),
      maskedOpenId: asString(
        json['maskedOpenId'],
        fallback: asString(json['openId'], fallback: asString(json['openIdMasked'])),
      ),
    );
  }
}

class LoginResult {
  const LoginResult({
    this.user,
    this.accessToken = '',
    this.refreshToken = '',
    this.need2fa = false,
    this.ticket = '',
    this.guest = false,
  });

  final UserProfile? user;
  final String accessToken;
  final String refreshToken;
  final bool need2fa;
  final String ticket;
  final bool guest;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      user: json['user'] is Map ? UserProfile.fromJson(asMap(json['user'])) : null,
      accessToken: asString(json['accessToken']),
      refreshToken: asString(json['refreshToken']),
      need2fa: asBool(json['need2fa']),
      ticket: asString(json['ticket']),
      guest: asBool(json['guest']),
    );
  }
}
