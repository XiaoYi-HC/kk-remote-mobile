import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/content.dart';
import '../models/user.dart';

class ProfileResult {
  const ProfileResult({this.user, this.unreadMessages = 0});

  final UserProfile? user;
  final int unreadMessages;
}

class AccountApi {
  AccountApi(this._api);

  final ApiClient _api;

  Future<ProfileResult> profile() async {
    final data = asMap(await _api.get('/client/account/profile'));
    return ProfileResult(
      user: data['user'] is Map ? UserProfile.fromJson(asMap(data['user'])) : null,
      unreadMessages: asInt(data['unreadMessages']),
    );
  }

  Future<UserProfile> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    final data = await _api.put('/client/account/profile', data: {
      if (nickname != null) 'nickname': nickname,
      if (signature != null) 'signature': signature,
      if (avatar != null) 'avatar': avatar,
    });
    return UserProfile.fromJson(asMap(data));
  }

  Future<String> uploadAvatar(String filePath) async {
    final data = await _api.uploadFile('/client/account/avatar', filePath);
    return asString(data['avatar']);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.put('/client/account/password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> bindPhone({required String phone, required String code, String? oldCode}) async {
    await _api.post('/client/account/bind/phone', data: {
      'phone': phone,
      'code': code,
      if (oldCode != null && oldCode.isNotEmpty) 'oldCode': oldCode,
    });
  }

  Future<void> bindEmail({required String email, required String code, String? oldCode}) async {
    await _api.post('/client/account/bind/email', data: {
      'email': email,
      'code': code,
      if (oldCode != null && oldCode.isNotEmpty) 'oldCode': oldCode,
    });
  }

  Future<List<UserIdentity>> identities() async {
    final data = await _api.get('/client/account/identities');
    return asList(data).map((item) => UserIdentity.fromJson(asMap(item))).toList();
  }

  Future<Map<String, dynamic>> bindUrl(String provider) async {
    final data = await _api.post('/client/account/identities/$provider/bind-url');
    return asMap(data);
  }

  Future<void> bindIdentity(String provider, {required String code, required String state}) async {
    await _api.post('/client/account/identities/$provider/bind', data: {
      'code': code,
      'state': state,
    });
  }

  Future<void> unbindIdentity(String provider) async {
    await _api.delete('/client/account/identities/$provider');
  }

  Future<Map<String, dynamic>> setup2fa() async {
    final data = await _api.post('/client/account/2fa/setup');
    return asMap(data);
  }

  Future<void> enable2fa(String code) async {
    await _api.post('/client/account/2fa/enable', data: {'code': code});
  }

  Future<void> disable2fa(String code) async {
    await _api.post('/client/account/2fa/disable', data: {'code': code});
  }

  Future<List<LoginDevice>> loginDevices() async {
    final data = await _api.get('/client/account/login-devices');
    return asList(data).map((item) => LoginDevice.fromJson(asMap(item))).toList();
  }

  Future<void> kickLoginDevice(int id) async {
    await _api.delete('/client/account/login-devices/$id');
  }

  Future<Map<String, dynamic>> requestDeletion() async {
    final data = await _api.post('/client/account/deletion');
    return asMap(data);
  }

  Future<void> cancelDeletion() async {
    await _api.post('/client/account/deletion/cancel');
  }

  Future<MessageListResult> messages({
    String? category,
    bool? read,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get('/client/account/messages', query: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (read != null) 'read': read ? 'true' : 'false',
      'page': page,
      'pageSize': pageSize,
    });
    return MessageListResult.fromJson(asMap(data));
  }

  Future<void> readMessage(int id) async {
    await _api.put('/client/account/messages/$id/read');
  }

  Future<void> readAllMessages() async {
    await _api.put('/client/account/messages-read-all');
  }

  Future<void> deleteMessage(int id) async {
    await _api.delete('/client/account/messages/$id');
  }
}
