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

  Future<void> _openAttachment(TicketAttachment attachment) async {
    final path = attachment.filePath;
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('附件地址缺失，无法查看')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(attachment.fileName),
        content: SelectableText(path),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('附件地址已复制')),
                );
              }
            },
            child: const Text('复制地址'),
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
