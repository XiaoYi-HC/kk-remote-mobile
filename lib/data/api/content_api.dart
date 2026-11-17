import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/common.dart';
import '../models/content.dart';

class ContentApi {
  ContentApi(this._api);

  final ApiClient _api;

  Future<FaqResult> faqs({int? categoryId, String? keyword}) async {
    final data = await _api.get('/client/faqs', query: {
      if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    });
    return FaqResult.fromJson(asMap(data));
  }

  Future<void> logFaqSearch(int id, String keyword) async {
    await _api.post('/client/faqs/$id/search-log', data: {'keyword': keyword});
  }

  Future<List<Announcement>> announcements({required String platform}) async {
    final data = await _api.get('/client/announcements', query: {'platform': platform});
    return asList(data).map((item) => Announcement.fromJson(asMap(item))).toList();
  }

  Future<void> clickAnnouncement(int id) async {
    await _api.post('/client/announcements/$id/click');
  }

  Future<Map<String, dynamic>> protocolsLatest() async {
    final data = await _api.get('/client/protocols/latest');
    return asMap(data);
  }

  Future<void> agreeProtocol(int id) async {
    await _api.post('/client/protocols/$id/agree');
  }
}
