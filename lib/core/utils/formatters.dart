import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String bytes(num value, {int digits = 1}) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = value.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : digits)} ${units[index]}';
  }

  static String speed(num bytesPerSecond) => '${bytes(bytesPerSecond)}/s';

  static String bitrate(num kbps) {
    if (kbps <= 0) return '--';
    if (kbps >= 1024) return '${(kbps / 1024).toStringAsFixed(1)} Mbps';
    return '${kbps.toStringAsFixed(0)} Kbps';
  }

  static String duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String seconds(int value) {
    final mins = value ~/ 60;
    final secs = value % 60;
    if (mins > 0) return '$mins分$secs秒';
    return '$secs秒';
  }

  static String date(DateTime? value, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    if (value == null) return '--';
    return DateFormat(pattern, 'zh_CN').format(value.toLocal());
  }

  static String shortDate(DateTime? value) =>
      date(value, pattern: 'MM-dd HH:mm');

  static String relative(DateTime? value) {
    if (value == null) return '--';
    final now = DateTime.now();
    final diff = now.difference(value.toLocal());
    if (diff.isNegative) return shortDate(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return date(value, pattern: 'yyyy-MM-dd');
  }

  static String latency(int ms) => ms <= 0 ? '--' : '${ms}ms';

  static String percent(double value, {int digits = 1}) =>
      '${(value * 100).toStringAsFixed(digits)}%';

  static String maskedAccount(String? value) {
    if (value == null || value.isEmpty) return '未绑定';
    if (value.contains('@')) {
      final parts = value.split('@');
      final name = parts.first;
      final domain = parts.length > 1 ? parts.last : '';
      if (name.isEmpty) return value;
      if (name.length <= 2) return '${name[0]}***@$domain';
      return '${name.substring(0, 2)}***@$domain';
    }
    if (value.length >= 7) {
      return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
    }
    return value;
  }

  static String fileExtension(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return '';
    return name.substring(index + 1).toLowerCase();
  }

  static String fileTypeLabel(String name, bool isDirectory) {
    if (isDirectory) return '文件夹';
    final ext = fileExtension(name);
    if (ext.isEmpty) return '文件';
    return '.$ext';
  }
}
