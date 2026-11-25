import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用内下载目录统一入口。
///
/// iOS 的应用容器根目录不可写：`<container>/Downloads` 会抛出
/// PathAccessException (EPERM)，因此 iOS 固定在沙盒 Documents 下建目录；
/// Android/桌面优先使用系统下载目录，失败再回退到 Documents。
Future<Directory> resolveDownloadDirectory({String configured = ''}) async {
  final candidate = configured.trim();
  if (candidate.isNotEmpty && await _ensureWritable(candidate)) {
    return Directory(candidate);
  }
  final base = await _defaultBaseDirectory();
  final dir = Directory(p.join(base.path, 'KK远程下载'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<bool> _ensureWritable(String path) async {
  try {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return true;
  } catch (_) {
    return false;
  }
}

Future<Directory> _defaultBaseDirectory() async {
  if (!Platform.isIOS) {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        if (!await downloads.exists()) {
          await downloads.create(recursive: true);
        }
        return downloads;
      }
    } catch (_) {
      // 插件不支持或系统限制时回退到 Documents。
    }
  }
  return getApplicationDocumentsDirectory();
}
