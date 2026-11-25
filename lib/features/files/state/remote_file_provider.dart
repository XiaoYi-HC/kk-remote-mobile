import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/utils/download_paths.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/file_entry.dart';
import '../../../data/models/session.dart';
import '../../../state/app_services.dart';
import '../../remote/state/remote_session_provider.dart';

/// 远程文件管理：通过 file DataChannel 浏览、下载、上传，并同步传输记录。
class RemoteFileProvider extends ChangeNotifier {
  RemoteFileProvider({
    required this.session,
    required this.services,
    required this.deviceId,
  });

  final RemoteSessionProvider session;
  final AppServices services;
  final int deviceId;

  final Uuid _uuid = const Uuid();
  StreamSubscription<Map<String, dynamic>>? _fileSub;

  String currentPath = '';
  List<RemoteFileEntry> entries = [];
  bool loading = false;
  String? error;
  String sortField = 'name';
  bool sortAscending = true;
  String filter = '';

  List<TransferRecord> records = [];
  bool recordsLoading = false;
  List<RemoteFileTask> tasks = [];
  List<FileSystemEntity> localDownloads = [];
  String downloadDir = '';

  final Map<String, Completer<List<RemoteFileEntry>>> _listRequests = {};
  final Map<String, RemoteFileTask> _taskByRequest = {};
  final Map<String, IOSink> _sinks = {};
  final Map<String, Stopwatch> _speedWatch = {};
  final Map<String, List<List<int>>> _pendingChunks = {};
  bool _disposed = false;

  bool get fileChannelReady => session.peer?.fileReady ?? false;

  List<RemoteFileEntry> get visibleEntries {
    var list = List<RemoteFileEntry>.from(entries);
    if (filter.trim().isNotEmpty) {
      final kw = filter.trim().toLowerCase();
      list = list.where((item) => item.name.toLowerCase().contains(kw)).toList();
    }
    list.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      int result;
      switch (sortField) {
        case 'size':
          result = a.size.compareTo(b.size);
          break;
        case 'modified':
          result = (a.modified?.millisecondsSinceEpoch ?? 0)
              .compareTo(b.modified?.millisecondsSinceEpoch ?? 0);
          break;
        default:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return sortAscending ? result : -result;
    });
    return list;
  }

  bool get canGoUp => currentPath.isNotEmpty;

  Future<void> init() async {
    _fileSub ??= session.peer?.fileMessages.listen(_handleFileMessage);
    await _prepareDownloadDir();
    await Future.wait([
      listDirectory(''),
      loadTransfers(),
    ]);
  }

  void _bindChannelIfNeeded() {
    _fileSub ??= session.peer?.fileMessages.listen(_handleFileMessage);
  }

  Future<void> _prepareDownloadDir() async {
    try {
      // iOS 容器根目录不可写，统一由 resolveDownloadDirectory 处理平台差异。
      final dir = await resolveDownloadDirectory(
        configured: services.settings.downloadDir,
      );
      downloadDir = dir.path;
      await services.settings.setString('download_dir', downloadDir);
      final files = await dir.list().where((item) => item is File).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      localDownloads = files;
      error = null;
    } catch (e) {
      error = '无法创建下载目录：$e';
    }
    notifyListeners();
  }

  Future<void> listDirectory(String path) async {
    _bindChannelIfNeeded();
    loading = true;
    error = null;
    notifyListeners();
    if (!fileChannelReady) {
      loading = false;
      error = '文件通道尚未建立，请确认远程连接正常';
      notifyListeners();
      return;
    }
    final reqId = _uuid.v4();
    final completer = Completer<List<RemoteFileEntry>>();
    _listRequests[reqId] = completer;
    session.peer?.sendFile({'t': 'fs.list', 'path': path, 'reqId': reqId});
    try {
      final result = await completer.future.timeout(const Duration(seconds: 10));
      currentPath = path;
      entries = result;
      error = null;
    } on TimeoutException {
      error = '读取目录超时，被控端可能未实现文件通道';
    } catch (e) {
      error = '读取目录失败：$e';
    } finally {
      _listRequests.remove(reqId);
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => listDirectory(currentPath);

  Future<void> open(RemoteFileEntry entry) async {
    if (entry.isDirectory) {
      await listDirectory(entry.path);
    }
  }

  Future<void> goUp() async {
    currentPath = _parentPath(currentPath);
    await listDirectory(currentPath);
  }

  void setSort(String field) {
    if (sortField == field) {
      sortAscending = !sortAscending;
    } else {
      sortField = field;
      sortAscending = true;
    }
    notifyListeners();
  }

  void setFilter(String value) {
    filter = value;
    notifyListeners();
  }

  String _parentPath(String path) {
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) return '';
    var parent = trimmed.substring(0, index);
    if (parent.length == 2 && parent.endsWith(':')) parent = '$parent\\';
    return parent;
  }

  Future<void> _handleFileMessage(Map<String, dynamic> message) async {
    final type = asString(message['t']);
    final reqId = asString(message['reqId']);
    switch (type) {
      case 'fs.list.result':
      case 'fs.list':
        final list = asList(message['entries'] ?? message['items'])
            .map((item) => RemoteFileEntry.fromJson(asMap(item)))
            .toList();
        _listRequests[reqId]?.complete(list);
        break;
      case 'fs.error':
      case 'file.error':
        final messageText = asString(message['message'], fallback: '文件操作失败');
        _listRequests[reqId]?.completeError(messageText);
        final task = _taskByRequest[reqId];
        if (task != null) {
          task
            ..status = 'failed'
            ..error = messageText;
          _pendingChunks.remove(reqId);
          _closeSink(reqId);
          notifyListeners();
        }
        break;
      case 'fs.download.start':
      case 'file.download.start':
        await _startDownloadSink(reqId, message);
        break;
      case 'fs.download.chunk':
      case 'file.download.chunk':
        await _writeDownloadChunk(reqId, message);
        break;
      case 'fs.download.done':
      case 'file.download.done':
        await _finishDownload(reqId);
        break;
      case 'fs.upload.progress':
      case 'file.upload.progress':
        final task = _taskByRequest[reqId];
        if (task != null) {
          task.received = asInt(message['bytesDone'] ?? message['received'], fallback: task.received);
          task.speedBps = asInt(message['speedBps'], fallback: task.speedBps);
          notifyListeners();
        }
        break;
      case 'fs.upload.done':
      case 'file.upload.done':
        final task = _taskByRequest[reqId];
        if (task != null) {
          task
            ..status = 'success'
            ..received = task.size;
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  Future<void> download(RemoteFileEntry entry) async {
    if (!fileChannelReady) {
      error = '文件通道尚未建立';
      notifyListeners();
      return;
    }
    final task = RemoteFileTask(
      localId: _uuid.v4(),
      fileName: entry.name,
      remotePath: entry.path,
      size: entry.size,
      direction: 'download',
      status: 'running',
    );
    tasks.insert(0, task);
    notifyListeners();
    try {
      final record = await services.sessionApi.createTransfer(
        deviceId: deviceId,
        direction: 'download',
        fileName: entry.name,
        fileSize: entry.size,
        status: 'running',
      );
      task.recordId = record.id;
    } catch (_) {
      // 游客或离线时仍允许本地传输，记录稍后再补。
    }
    final reqId = _uuid.v4();
    _taskByRequest[reqId] = task;
    _speedWatch[reqId] = Stopwatch()..start();
    session.peer?.sendFile({
      't': 'fs.download',
      'path': entry.path,
      'name': entry.name,
      'reqId': reqId,
    });
    records.insert(
      0,
      TransferRecord(
        id: task.recordId,
        deviceId: deviceId,
        direction: 'download',
        fileName: entry.name,
        fileSize: entry.size,
        status: 'running',
        startedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> _startDownloadSink(String reqId, Map<String, dynamic> message) async {
    final task = _taskByRequest[reqId];
    if (task == null) return;
    if (downloadDir.isEmpty) {
      await _prepareDownloadDir();
    }
    final safeName = _safeFileName(task.fileName);
    final file = File(p.join(downloadDir, safeName));
    task.localPath = file.path;
    final sink = file.openWrite();
    _sinks[reqId] = sink;
    final total = asInt(message['size'], fallback: task.size);
    if (total > 0) task.size = total;
    // 建立 sink 期间到达的分片先缓存，随后按顺序补写，避免静默丢包导致文件损坏。
    final pending = _pendingChunks.remove(reqId);
    if (pending != null) {
      for (final bytes in pending) {
        sink.add(bytes);
        task.received += bytes.length;
      }
    }
    notifyListeners();
  }

  List<int>? _decodeChunk(Map<String, dynamic> message) {
    final data = message['data'] ?? message['chunk'];
    if (data is String) {
      try {
        return base64Decode(data);
      } catch (_) {
        return utf8.encode(data);
      }
    }
    if (data is List) {
      return data.whereType<num>().map((item) => item.toInt()).toList();
    }
    return null;
  }

  Future<void> _writeDownloadChunk(String reqId, Map<String, dynamic> message) async {
    final task = _taskByRequest[reqId];
    if (task == null) return;
    final bytes = _decodeChunk(message);
    if (bytes == null) return;
    final sink = _sinks[reqId];
    if (sink == null) {
      // sink 尚未创建（目录准备中），先入队。
      _pendingChunks.putIfAbsent(reqId, () => []).add(bytes);
      return;
    }
    sink.add(bytes);
    task.received += bytes.length;
    final watch = _speedWatch[reqId];
    if (watch != null) {
      final elapsed = watch.elapsedMilliseconds;
      if (elapsed > 0) {
        task.speedBps = (task.received * 1000 / elapsed).round();
      }
    }
    notifyListeners();
  }

  Future<void> _finishDownload(String reqId) async {
    final task = _taskByRequest[reqId];
    if (task == null) return;
    final pending = _pendingChunks.remove(reqId);
    final sink = _sinks[reqId];
    if (pending != null && sink != null) {
      for (final bytes in pending) {
        sink.add(bytes);
        task.received += bytes.length;
      }
    }
    await _closeSink(reqId);
    task
      ..status = 'success'
      ..received = task.size > 0 ? task.size : task.received;
    _taskByRequest.remove(reqId);
    _speedWatch.remove(reqId);
    await _refreshLocalDownloads();
    notifyListeners();
  }

  Future<void> _closeSink(String reqId) async {
    final sink = _sinks.remove(reqId);
    try {
      await sink?.flush();
      await sink?.close();
    } catch (_) {}
  }

  Future<void> pickAndUpload() async {
    if (!fileChannelReady) {
      error = '文件通道尚未建立';
      notifyListeners();
      return;
    }
    final result = await FilePicker.platform.pickFiles(withReadStream: false);
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    await upload(file.path!, file.name, file.size);
  }

  Future<void> upload(String localPath, String fileName, int size) async {
    final task = RemoteFileTask(
      localId: _uuid.v4(),
      fileName: fileName,
      remotePath: currentPath,
      size: size,
      direction: 'upload',
      status: 'running',
      localPath: localPath,
    );
    tasks.insert(0, task);
    notifyListeners();
    try {
      final record = await services.sessionApi.createTransfer(
        deviceId: deviceId,
        direction: 'upload',
        fileName: fileName,
        fileSize: size,
        status: 'running',
      );
      task.recordId = record.id;
    } catch (_) {}
    final reqId = _uuid.v4();
    _taskByRequest[reqId] = task;
    _speedWatch[reqId] = Stopwatch()..start();
    final started = session.peer?.sendFile({
          't': 'fs.upload.start',
          'path': currentPath,
          'name': fileName,
          'size': size,
          'reqId': reqId,
        }) ??
        false;
    if (!started) {
      task
        ..status = 'failed'
        ..error = '文件通道已断开';
      _taskByRequest.remove(reqId);
      _speedWatch.remove(reqId);
      notifyListeners();
      return;
    }
    try {
      final file = File(localPath);
      final total = await file.length();
      var sent = 0;
      const maxBuffered = 4 * 1024 * 1024;
      await for (final chunk in file.openRead()) {
        if (chunk.isEmpty) continue;
        final peer = session.peer;
        if (peer == null || _disposed) {
          throw Exception('会话已结束，上传中断');
        }
        final ok = peer.sendFile({
          't': 'fs.upload.chunk',
          'reqId': reqId,
          'data': base64Encode(chunk),
        });
        if (!ok) {
          throw Exception('文件通道已断开，上传中断');
        }
        sent += chunk.length;
        task.received = sent;
        final elapsed = _speedWatch[reqId]?.elapsedMilliseconds ?? 0;
        if (elapsed > 0) task.speedBps = (sent * 1000 / elapsed).round();
        if (total > 0) task.size = total;
        notifyListeners();
        // 发送缓冲超过阈值时等待回落，避免把控制指令挤掉或丢包。
        while ((session.peer?.fileBufferedAmount ?? 0) > maxBuffered) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (_disposed) throw Exception('会话已结束，上传中断');
        }
      }
      final ended = session.peer?.sendFile({'t': 'fs.upload.end', 'reqId': reqId}) ?? false;
      if (!ended) throw Exception('文件通道已断开，上传中断');
      task.status = 'success';
    } catch (error) {
      task
        ..status = 'failed'
        ..error = error.toString();
    } finally {
      _speedWatch.remove(reqId);
      notifyListeners();
      await loadTransfers();
    }
  }

  Future<void> loadTransfers() async {
    recordsLoading = true;
    notifyListeners();
    try {
      records = await services.sessionApi.transfers();
    } catch (_) {
      // 游客没有传输记录权限，保持本地任务列表。
    } finally {
      recordsLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry(TransferRecord record) async {
    try {
      await services.sessionApi.retryTransfer(record.id);
      await loadTransfers();
    } catch (e) {
      error = '重传失败：$e';
      notifyListeners();
    }
  }

  Future<void> retryTask(RemoteFileTask task) async {
    if (task.isUpload) {
      if (task.localPath.isEmpty || !File(task.localPath).existsSync()) {
        error = '本地文件不存在，无法重传';
        notifyListeners();
        return;
      }
      await upload(task.localPath, task.fileName, task.size);
      return;
    }
    await download(RemoteFileEntry(
      name: task.fileName,
      path: task.remotePath,
      size: task.size,
    ));
  }

  Future<void> clearRecords() async {
    await services.sessionApi.clearTransfers();
    records = [];
    notifyListeners();
  }

  Future<void> _refreshLocalDownloads() async {
    if (downloadDir.isEmpty) return;
    try {
      final dir = Directory(downloadDir);
      final files = await dir.list().where((item) => item is File).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      localDownloads = files;
    } catch (_) {}
  }

  Future<void> refreshDownloads() => _refreshLocalDownloads();

  Future<void> deleteDownload(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } catch (_) {}
    await _refreshLocalDownloads();
    notifyListeners();
  }

  Future<void> clearDownloads() async {
    for (final entity in List<FileSystemEntity>.from(localDownloads)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
    await _refreshLocalDownloads();
    notifyListeners();
  }

  Future<int> cacheSize() async {
    var total = 0;
    for (final entity in localDownloads) {
      try {
        total += await entity.stat().then((value) => value.size);
      } catch (_) {}
    }
    return total;
  }

  String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.isEmpty ? 'download.bin' : sanitized;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _fileSub?.cancel();
    for (final sink in _sinks.values) {
      sink.close();
    }
    _sinks.clear();
    _pendingChunks.clear();
    super.dispose();
  }
}
