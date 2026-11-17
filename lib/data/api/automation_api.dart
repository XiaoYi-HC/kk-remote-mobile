import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/automation.dart';

class AutomationApi {
  AutomationApi(this._api);

  final ApiClient _api;

  Future<List<ScheduledTask>> scheduledTasks() async {
    final data = await _api.get('/client/scheduled-tasks');
    return asList(data).map((item) => ScheduledTask.fromJson(asMap(item))).toList();
  }

  Future<ScheduledTask> createScheduledTask(ScheduledTask task) async {
    final data = await _api.post('/client/scheduled-tasks', data: task.toRequest());
    return ScheduledTask.fromJson(asMap(data));
  }

  Future<void> updateScheduledTask(ScheduledTask task) async {
    await _api.put('/client/scheduled-tasks/${task.id}', data: {
      'name': task.name,
      'triggerAt': (task.triggerAt ?? DateTime.now()).toUtc().toIso8601String(),
      'repeatRule': task.repeatRule,
      'retry': task.retry,
      'enabled': task.enabled,
    });
  }

  Future<void> deleteScheduledTask(int id) async {
    await _api.delete('/client/scheduled-tasks/$id');
  }

  Future<List<OfflineCommand>> offlineCommands() async {
    final data = await _api.get('/client/offline-commands');
    return asList(data).map((item) => OfflineCommand.fromJson(asMap(item))).toList();
  }

  Future<OfflineCommand> createOfflineCommand({
    required int deviceId,
    required String command,
    bool enabled = true,
  }) async {
    final data = await _api.post('/client/offline-commands', data: {
      'deviceId': deviceId,
      'command': command,
      'enabled': enabled,
    });
    return OfflineCommand.fromJson(asMap(data));
  }

  Future<void> deleteOfflineCommand(int id) async {
    await _api.delete('/client/offline-commands/$id');
  }

  Future<List<OfflineCommandResult>> offlineCommandResults(int id) async {
    final data = await _api.get('/client/offline-commands/$id/results');
    return asList(data)
        .map((item) => OfflineCommandResult.fromJson(asMap(item)))
        .toList();
  }

  Future<NetworkDiagnosticsConfig> networkDiagnosticsConfig() async {
    final data = await _api.get('/client/diagnostics/network');
    return NetworkDiagnosticsConfig.fromJson(asMap(data));
  }

  Future<String> reportDiagnostics(Map<String, dynamic> report) async {
    final data = await _api.post('/client/diagnostics/report', data: report);
    return asString(asMap(data)['path']);
  }
}
