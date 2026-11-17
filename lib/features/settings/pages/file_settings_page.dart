import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/settings_widgets.dart';

class FileSettingsPage extends StatefulWidget {
  const FileSettingsPage({super.key});

  @override
  State<FileSettingsPage> createState() => _FileSettingsPageState();
}

class _FileSettingsPageState extends State<FileSettingsPage> {
  String _path = '';
  int _size = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    var path = settings.downloadDir;
    if (path.isEmpty) {
      final downloads = await getDownloadsDirectory();
      path = downloads == null
          ? p.join((await getApplicationDocumentsDirectory()).path, 'KK远程下载')
          : p.join(downloads.path, 'KK远程');
    }
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    var size = 0;
    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        count++;
        try {
          size += await entity.length();
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _path = path;
        _size = size;
        _count = count;
      });
    }
  }

  Future<void> _changeDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择下载目录');
    if (path == null) return;
    await context.read<SettingsProvider>().setString(SettingsKeys.downloadDir, path);
    await _load();
  }

  Future<void> _clearCache() async {
    final ok = await showConfirmDialog(
      context,
      title: '清理缓存',
      content: '将删除下载目录中的 $_count 个文件，共 ${Formatters.bytes(_size)}。',
      confirmText: '清理',
      danger: true,
    );
    if (!ok) return;
    final dir = Directory(_path);
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('文件与下载'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('下载目录'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: _path.isEmpty ? '正在读取下载目录' : _path,
                subtitle: _path.isEmpty
                    ? '远程下载、截图与录制的默认保存位置'
                    : '$_count 个文件 · ${Formatters.bytes(_size)}',
                leading: const IconBadge(icon: Icons.folder_rounded),
                trailing: TextButton(
                  onPressed: _changeDirectory,
                  child: const Text('更改', style: TextStyle(fontSize: 12)),
                ),
              ),
              SettingsTile(
                title: '清理下载缓存',
                subtitle: '不会影响正在传输的任务',
                leading: const IconBadge(icon: Icons.cleaning_services_outlined),
                onTap: _clearCache,
                danger: true,
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('传输'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '传输记录',
                subtitle: '查看上传/下载任务与失败重传',
                leading: const IconBadge(icon: Icons.sync_alt_rounded),
                onTap: () => context.push('/settings/downloads'),
              ),
              SettingsTile(
                title: '下载管理',
                subtitle: '查看本地文件、清理缓存、打开下载目录',
                leading: const IconBadge(icon: Icons.download_rounded),
                onTap: () => context.push('/settings/downloads?tab=1'),
                showDivider: false,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              '远程文件通过 WebRTC file 通道传输，不经过服务器中转。截图、录制和小窗画面默认保存在上述下载目录。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
