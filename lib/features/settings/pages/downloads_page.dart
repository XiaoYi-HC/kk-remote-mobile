import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/session.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<TransferRecord> _records = [];
  List<FileSystemEntity> _files = [];
  bool _loading = true;
  String? _error;
  String _dirPath = '';
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([_loadRecords(), _loadFiles()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRecords() async {
    try {
      _records = await context.read<AppServices>().sessionApi.transfers();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _loadFiles() async {
    try {
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
      _dirPath = path;
      final list = await dir.list().where((item) => item is File).toList();
      list.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      var total = 0;
      for (final item in list) {
        total += item.statSync().size;
      }
      _files = list;
      _cacheBytes = total;
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _chooseDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择下载目录');
    if (path == null) return;
    await context.read<SettingsProvider>().setString(SettingsKeys.downloadDir, path);
    await _loadFiles();
    if (mounted) setState(() {});
  }

  Future<void> _retry(TransferRecord record) async {
    try {
      await context.read<AppServices>().sessionApi.retryTransfer(record.id);
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重新加入传输队列，请在会话内重新选择文件')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(FileSystemEntity entity) async {
    final name = entity.uri.pathSegments.last;
    final ok = await showConfirmDialog(
      context,
      title: '删除文件',
      content: '确定删除 $name ？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    await entity.delete(recursive: true);
    await _loadFiles();
    if (mounted) setState(() {});
  }

  Future<void> _clearCache() async {
    final ok = await showConfirmDialog(
      context,
      title: '清理缓存',
      content: '将删除下载目录中的全部文件，共 ${Formatters.bytes(_cacheBytes)}。',
      confirmText: '清理',
      danger: true,
    );
    if (!ok) return;
    for (final item in List<FileSystemEntity>.from(_files)) {
      try {
        await item.delete(recursive: true);
      } catch (_) {}
    }
    await _loadFiles();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('下载与传输记录'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '传输记录'),
            Tab(text: '本地下载'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecords(),
                _buildLocalFiles(),
              ],
            ),
    );
  }

  Widget _buildRecords() {
    if (_error != null && _records.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: '暂时无法读取传输记录',
        description: _error,
        action: OutlinedButton(onPressed: _loadAll, child: const Text('重试')),
      );
    }
    if (_records.isEmpty) {
      return const EmptyState(
        icon: Icons.sync_alt_rounded,
        title: '暂无传输记录',
        description: '远程文件上传或下载后，任务会同步到此处',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _records.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final record = _records[index];
          final color = record.isFailed
              ? AppColors.danger
              : record.isSuccess
                  ? AppColors.success
                  : AppColors.primary;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  record.isUpload ? Icons.upload_rounded : Icons.download_rounded,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fileName.isEmpty ? '未命名文件' : record.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${record.isUpload ? '上传' : '下载'} · ${Formatters.bytes(record.fileSize)}'
                        ' · ${Formatters.shortDate(record.startedAt)} · ${_statusLabel(record.status)}',
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                      if (record.error.isNotEmpty)
                        Text(
                          record.error,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.danger),
                        ),
                    ],
                  ),
                ),
                if (record.isFailed)
                  IconButton(
                    tooltip: '重传',
                    onPressed: () => _retry(record),
                    icon: const Icon(Icons.refresh_rounded, size: 19, color: AppColors.primary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocalFiles() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_rounded, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '下载目录 · ${Formatters.bytes(_cacheBytes)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearCache,
                    child: const Text('清理缓存', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _dirPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _chooseDirectory,
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 17),
                label: const Text('更改下载目录'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _files.isEmpty
              ? const EmptyState(
                  icon: Icons.download_done_rounded,
                  title: '暂无本地下载文件',
                  description: '远程文件下载完成后会保存到下载目录',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _files.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 0.8,
                    indent: 48,
                  ),
                  itemBuilder: (context, index) {
                    final entity = _files[index];
                    final stat = entity.statSync();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                      title: Text(
                        entity.uri.pathSegments.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${Formatters.bytes(stat.size)} · ${Formatters.date(stat.modified)}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        onPressed: () => _delete(entity),
                        tooltip: '删除',
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '等待中';
      case 'running':
        return '传输中';
      case 'success':
        return '已完成';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }
}
