import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/support.dart';
import '../../../state/app_services.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';

class TicketDetailPage extends StatefulWidget {
  const TicketDetailPage({super.key, required this.ticketId, this.ticket});

  final int ticketId;
  final Ticket? ticket;

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  TicketDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final detail = await services.supportApi.ticketDetail(widget.ticketId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isImageAttachment(TicketAttachment attachment) {
    if (attachment.mime.toLowerCase().startsWith('image/')) return true;
    final name = attachment.fileName.toLowerCase();
    return const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.heic']
        .any(name.endsWith);
  }

  String _attachmentUrl(TicketAttachment attachment) {
    final path = attachment.filePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return context.read<AppServices>().api.resolveUri(path).toString();
  }

  Future<void> _copyAttachmentLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('附件链接已复制')),
    );
  }

  Future<void> _openAttachment(TicketAttachment attachment) async {
    if (attachment.filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('附件地址缺失，无法查看')),
      );
      return;
    }
    final url = _attachmentUrl(attachment);
    if (_isImageAttachment(attachment)) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (dialogContext) => _AttachmentImageViewer(
          fileName: attachment.fileName,
          url: url,
          onCopy: () {
            Navigator.of(dialogContext).pop();
            _copyAttachmentLink(url);
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(attachment.fileName.isEmpty ? '附件' : attachment.fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(url),
            const SizedBox(height: 10),
            Text(
              '大小 ${Formatters.bytes(attachment.size)}'
              '${attachment.mime.isEmpty ? '' : ' · ${attachment.mime}'}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _copyAttachmentLink(url);
            },
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _detail?.ticket ?? widget.ticket;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('反馈详情'),
      ),
      body: _loading && _detail == null
          ? const LoadingView()
          : _error != null && _detail == null && widget.ticket == null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: '无法读取工单',
                  description: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('重试')),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      if (ticket != null) _buildTicket(ticket),
                      const SizedBox(height: 16),
                      const Text(
                        '处理记录',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if ((_detail?.replies ?? const []).isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            '客服尚未回复，请耐心等待。回复后会同步到站内消息中心。',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                          ),
                        )
                      else
                        ...(_detail!.replies).map(
                          (reply) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
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
                                    const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.primarySoft,
                                      child: Icon(
                                        Icons.support_agent_rounded,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      reply.adminName.isEmpty ? '客服' : reply.adminName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Formatters.date(reply.createdAt),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reply.content,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.6,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTicket(Ticket ticket) {
    final statusColor = switch (ticket.status) {
      'processing' => AppColors.warning,
      'replied' => AppColors.success,
      'closed' => AppColors.textTertiary,
      _ => AppColors.primary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.problemType.isEmpty ? '反馈工单' : ticket.problemType,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.statusLabel,
                      style: TextStyle(fontSize: 9, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.content,
                style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                '提交时间 ${Formatters.date(ticket.createdAt)}'
                '${ticket.phone.isEmpty ? '' : ' · ${ticket.phone}'}',
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        if ((_detail?.attachments ?? const []).isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('附件', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...(_detail!.attachments).map(
            (attachment) => InkWell(
              onTap: () => _openAttachment(attachment),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Text(
                      Formatters.bytes(attachment.size),
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttachmentImageViewer extends StatelessWidget {
  const _AttachmentImageViewer({
    required this.fileName,
    required this.url,
    required this.onCopy,
    required this.onClose,
  });

  final String fileName;
  final String url;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width,
        height: size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName.isEmpty ? '附件预览' : fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '图片加载失败，可复制链接后用浏览器查看',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.link_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      '复制链接',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
