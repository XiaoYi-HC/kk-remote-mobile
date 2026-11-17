import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/session.dart';

class SessionApi {
  SessionApi(this._api);

  final ApiClient _api;

  Future<List<SessionRecord>> list({
    String? transport,
    String? stage,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = asMap(await _api.get('/client/sessions', query: {
      if (transport != null) 'transport': transport,
      if (stage != null) 'stage': stage,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'page': page,
      'pageSize': pageSize,
    }));
    return asList(data['list']).map((item) => SessionRecord.fromJson(asMap(item))).toList();
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final data = await _api.get('/client/sessions/$id');
    return asMap(data);
  }

  Future<List<SessionMetric>> metrics(int id) async {
    final data = await _api.get('/client/sessions/$id/metrics');
    return asList(data).map((item) => SessionMetric.fromJson(asMap(item))).toList();
  }

  Future<void> reportMetric(int id, SessionMetric metric) async {
    await _api.post('/client/sessions/$id/report', data: metric.toReportJson());
  }

  Future<void> close(int id, {String reason = 'user_closed'}) async {
    await _api.post('/client/sessions/$id/close', data: {'reason': reason});
  }

  Future<List<TransferRecord>> transfers({String? status, int page = 1, int pageSize = 30}) async {
    final data = asMap(await _api.get('/client/transfers', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'pageSize': pageSize,
    }));
    return asList(data['list'])
        .map((item) => TransferRecord.fromJson(asMap(item)))
        .toList();
  }

  Future<TransferRecord> createTransfer({
    required int deviceId,
    required String direction,
    required String fileName,
    required int fileSize,
    int sessionId = 0,
    String status = 'pending',
  }) async {
    final data = await _api.post('/client/transfers', data: {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'direction': direction,
      'fileName': fileName,
      'fileSize': fileSize,
      'status': status,
    });
    return TransferRecord.fromJson(asMap(data));
  }

  Future<void> retryTransfer(int id) async {
    await _api.post('/client/transfers/$id/retry');
  }

  Future<void> clearTransfers() async {
    await _api.delete('/client/transfers');
  }

  Future<Map<String, dynamic>> createShare({required int deviceId, int ttlMinutes = 60}) async {
    final data = await _api.post('/client/shares', data: {
      'deviceId': deviceId,
      'ttlMinutes': ttlMinutes,
    });
    return asMap(data);
  }
}
