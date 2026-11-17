import '../../core/utils/json_utils.dart';

class RemoteFileEntry {
  const RemoteFileEntry({
    required this.name,
    required this.path,
    this.isDirectory = false,
    this.size = 0,
    this.modified,
    this.extension = '',
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String extension;

  String get extensionLabel {
    if (isDirectory) return '文件夹';
    if (extension.isNotEmpty) return '.$extension';
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) return name.substring(dot).toLowerCase();
    return '文件';
  }

  factory RemoteFileEntry.fromJson(Map<String, dynamic> json) {
    final isDir = asBool(json['isDir'], fallback: asBool(json['isDirectory']));
    return RemoteFileEntry(
      name: asString(json['name']),
      path: asString(json['path']),
      isDirectory: isDir,
      size: asInt(json['size']),
      modified: asDate(json['modified'] ?? json['modifiedAt'] ?? json['mtime']),
      extension: asString(json['ext'], fallback: asString(json['extension'])),
    );
  }
}

class RemoteFileTask {
  RemoteFileTask({
    required this.localId,
    required this.fileName,
    required this.remotePath,
    required this.direction,
    required this.size,
    this.recordId = 0,
    this.status = 'pending',
    this.error = '',
    this.received = 0,
    this.speedBps = 0,
    this.localPath = '',
  });

  final String localId;
  final String fileName;
  final String remotePath;
  int size;
  final String direction;
  int recordId;
  String status;
  String error;
  int received;
  int speedBps;
  String localPath;

  bool get isUpload => direction == 'upload';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';
  bool get isDone => status == 'success';
  double get progress => size <= 0 ? 0 : (received / size).clamp(0, 1).toDouble();
}
