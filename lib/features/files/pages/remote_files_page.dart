import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/file_entry.dart';
import '../../../data/models/session.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../remote/state/remote_session_provider.dart';
import '../state/remote_file_provider.dart';

class RemoteFilesPage extends StatefulWidget {
  const RemoteFilesPage({super.key});

  @override
  State<RemoteFilesPage> createState() => _RemoteFilesPageState();
}

class _RemoteFilesPageState extends State<RemoteFilesPage> with SingleTickerProviderStateMixin {
  RemoteFileProvider? _files;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    final session = RemoteSessionRegistry.instance.current;
    if (session != null) {
      _files = RemoteFileProvider(
        session: session,
        services: session.services,
        deviceId: session.args.deviceId,
      )..init();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _files?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = RemoteSessionRegistry.instance.current;
    final files = _files;
    if (session == null || files == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('远程文件')),
        body: const EmptyState(
          icon: Icons.cloud_off_rounded,
          title: '远程会话已结束',
          description: '请重新连接后再管理远程文件',
        ),
      );
    }
    return ChangeNotifierProvider<RemoteFileProvider>.value(
      value: files,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('远程文件', style: TextStyle(fontSize: 16)),
              Text(
                session.args.displayName,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            if (_tabController.index == 0)
              IconButton(
                tooltip: '上传文件',
                onPressed: files.pickAndUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 21),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: '远程文件'),
              Tab(text: '传输记录'),
              Tab(text: '本地下载'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _RemoteBrowserView(onUpload: files.pickAndUpload),
            const _TransfersView(),
            const _DownloadsView(),
          ],
        ),
      ),
    );
  }
}

class _RemoteBrowserView extends StatefulWidget {
  const _RemoteBrowserView({required this.onUpload});

  final Future<void> Function() onUpload;

  @override
  State<_RemoteBrowserView> createState() => _RemoteBrowserViewState();
}

class _RemoteBrowserViewState extends State<_RemoteBrowserView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = context.watch<RemoteFileProvider>();
    final entries = files.visibleEntries;
    final running = files.tasks.where((task) => task.isRunning).toList();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          color: AppColors.surface,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '上一级',
                    onPressed: files.canGoUp && !files.loading ? files.goUp : null,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                  ),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        files.currentPath.isEmpty ? '此电脑' : files.currentPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: files.loading ? null : files.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '排序',
                    icon: const Icon(Icons.sort_rounded, size: 19),
                    onSelected: files.setSort,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'name', child: Text('按名称排序')),
                      PopupMenuItem(value: 'size', child: Text('按大小排序')),
                      PopupMenuItem(value: 'modified', child: Text('按修改时间排序')),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: files.setFilter,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '搜索当前目录文件',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '上传手机文件',
                    onPressed: widget.onUpload,
                    icon: const Icon(Icons.add_rounded, size: 21, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (running.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.primarySoft,
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '正在${running.first.isUpload ? '上传' : '下载'} ${running.first.fileName} '
                    '${(running.first.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        if (files.error != null)
          InlineError(
            message: files.error!,
            onRetry: files.refresh,
          ),
        Expanded(
          child: files.loading
              ? const LoadingView(message: '正在读取被控目录…')
              : entries.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: '当前目录为空',
                      description: files.fileChannelReady
                          ? '可上传手机文件，或返回上一级目录'
                          : '文件通道尚未建立，请确认远程连接正常',
                      action: OutlinedButton.icon(
                        onPressed: widget.onUpload,
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: const Text('上传文件'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: files.refresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: entries.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 0.8,
                          indent: 60,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            onTap: entry.isDirectory ? () => files.open(entry) : null,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: entry.isDirectory
                                    ? AppColors.warningSoft
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                entry.isDirectory
                                    ? Icons.folder_rounded
                                    : _fileIcon(entry.name),
                                size: 20,
                                color: entry.isDirectory ? AppColors.warning : AppColors.primary,
                              ),
                            ),
                            title: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              entry.isDirectory
                                  ? '文件夹'
                                  : '${entry.extensionLabel} · ${Formatters.bytes(entry.size)} · ${Formatters.shortDate(entry.modified)}',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                            trailing: entry.isDirectory
                                ? const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textTertiary,
                                  )
                                : IconButton(
                                    tooltip: '下载到手机',
                                    onPressed: () => files.download(entry),
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  IconData _fileIcon(String name) {
    final ext = Formatters.fileExtension(name);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.movie_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'txt':
      case 'md':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _TransfersView extends StatelessWidget {
  const _TransfersView();

  @override
  Widget build(BuildContext context) {
    final files = context.watch<RemoteFileProvider>();
    final localTasks = files.tasks;
    final records = files.records;
    return RefreshIndicator(
      onRefresh: files.loadTransfers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              const Text(
                '传输任务',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${localTasks.length + records.length} 条',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: files.records.isEmpty
                    ? null
                    : () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: '清空传输记录',
                          content: '仅清空服务端记录，不会删除已下载文件。',
                          confirmText: '清空',
                          danger: true,
                        );
                        if (ok) await files.clearRecords();
                      },
                child: const Text('清空', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (localTasks.isEmpty && records.isEmpty)
            const EmptyState(
              icon: Icons.sync_alt_rounded,
              title: '暂无传输任务',
              description: '在远程文件页下载或上传后，任务会显示在这里',
            )
          else ...[
            ...localTasks.map((task) => _TaskTile(task: task, onRetry: () => files.retryTask(task))),
            ...records.map((record) => _RecordTile(record: record, onRetry: () => files.retry(record))),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onRetry});

  final RemoteFileTask task;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = task.isFailed
        ? AppColors.danger
        : task.isDone
            ? AppColors.success
            : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Icon(
                task.isUpload ? Icons.upload_rounded : Icons.download_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                _statusLabel(task.status),
                style: TextStyle(fontSize: 10.5, color: color),
              ),
              if (task.isFailed)
                IconButton(
                  tooltip: '重试',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: task.progress <= 0 ? null : task.progress,
            minHeight: 4,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.bytes(task.received)} / ${Formatters.bytes(task.size)}'
            '${task.speedBps > 0 ? ' · ${Formatters.speed(task.speedBps)}' : ''}'
            '${task.error.isEmpty ? '' : ' · ${task.error}'}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onRetry});

  final TransferRecord record;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = record.isFailed
        ? AppColors.danger
        : record.isSuccess
            ? AppColors.success
            : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_statusLabel(record.status)} · ${Formatters.bytes(record.fileSize)} · ${Formatters.shortDate(record.startedAt)}',
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
          if (record.isFailed)
            IconButton(
              tooltip: '重新传输',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

class _DownloadsView extends StatefulWidget {
  const _DownloadsView();

  @override
  State<_DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<_DownloadsView> {
  Future<int>? _cacheFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final files = context.read<RemoteFileProvider>();
      files.refreshDownloads();
      setState(() => _cacheFuture = files.cacheSize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = context.watch<RemoteFileProvider>();
    return FutureBuilder<int>(
      future: _cacheFuture ??= files.cacheSize(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本地占用 ${Formatters.bytes(total)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          files.downloadDir.isEmpty ? '下载目录未初始化' : files.downloadDir,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: files.localDownloads.isEmpty
                        ? null
                        : () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: '清理下载缓存',
                              content: '将删除下载目录中的全部文件，是否继续？',
                              confirmText: '清理',
                              danger: true,
                            );
                            if (ok) await files.clearDownloads();
                          },
                    child: const Text('清理', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: files.localDownloads.isEmpty
                  ? const EmptyState(
                      icon: Icons.download_done_rounded,
                      title: '暂无本地下载文件',
                      description: '从被控电脑下载的文件会保存在这里',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: files.localDownloads.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 0.8,
                        indent: 54,
                        endIndent: 8,
                      ),
                      itemBuilder: (context, index) {
                        final entity = files.localDownloads[index];
                        int size = 0;
                        DateTime? modified;
                        try {
                          final stat = entity.statSync();
                          size = stat.size;
                          modified = stat.modified;
                        } catch (_) {
                          // 文件可能已被外部删除，渲染时不再阻塞整页。
                        }
                        final name = entity.uri.pathSegments.last;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            modified == null
                                ? Formatters.bytes(size)
                                : '${Formatters.bytes(size)} · ${Formatters.shortDate(modified)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                          trailing: IconButton(
                            tooltip: '删除',
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: '删除文件',
                                content: '确定删除 $name ？',
                                confirmText: '删除',
                                danger: true,
                              );
                              if (ok) await files.deleteDownload(entity);
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 19),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
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
