import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/content.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../auth/state/auth_provider.dart';

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  static const _categories = [
    ('', '全部'),
    ('system', '系统公告'),
    ('support', '客服回复'),
    ('offline', '设备告警'),
  ];

  List<MessageItem> _messages = [];
  int _unread = 0;
  String _category = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = '登录后查看消息中心';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AppServices>().accountApi.messages(
            category: _category.isEmpty ? null : _category,
            pageSize: 50,
          );
      _messages = result.list;
      _unread = result.unread;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MessageItem message) async {
    if (!message.read) {
      try {
        await context.read<AppServices>().accountApi.readMessage(message.id);
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index >= 0) {
          _messages[index] = MessageItem(
            id: message.id,
            category: message.category,
            title: message.title,
            content: message.content,
            read: true,
            refId: message.refId,
            createdAt: message.createdAt,
          );
          _unread = (_unread - 1).clamp(0, _unread).toInt();
          setState(() {});
        }
        context.read<AuthProvider>().refreshProfile(silent: true);
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(message.title.isEmpty ? '消息' : message.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      message.categoryLabel,
                      style: const TextStyle(fontSize: 9, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.date(message.createdAt),
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message.content,
                style: const TextStyle(fontSize: 13, height: 1.7),
              ),
            ],
          ),
        ),
        actions: [
          if (message.category == 'support' && message.refId > 0)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/help/tickets/${message.refId}');
              },
              child: const Text('查看工单'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(72, 38)),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _readAll() async {
    try {
      await context.read<AppServices>().accountApi.readAllMessages();
      await _load();
      context.read<AuthProvider>().refreshProfile(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(MessageItem message) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除消息',
      content: '确定删除该条消息？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await context.read<AppServices>().accountApi.deleteMessage(message.id);
      await _load();
      context.read<AuthProvider>().refreshProfile(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: Row(
          children: [
            const Text('消息中心'),
            if (_unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_unread',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _unread > 0 ? _readAll : null,
            child: const Text('全部已读', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categories
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: _category == item.$1,
                        onSelected: (_) {
                          setState(() => _category = item.$1);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? EmptyState(
                        icon: Icons.mark_email_unread_outlined,
                        title: '消息不可用',
                        description: _error,
                        action: OutlinedButton(onPressed: _load, child: const Text('重试')),
                      )
                    : _messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: '暂无消息',
                            description: '公告、客服回复与设备离线告警会显示在这里',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: _messages.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: message.read ? AppColors.border : const Color(0xFFC9DEFF),
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _open(message),
                                    onLongPress: () => _delete(message),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    leading: Stack(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: _categoryColor(message.category).withAlpha(20),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _categoryIcon(message.category),
                                            size: 19,
                                            color: _categoryColor(message.category),
                                          ),
                                        ),
                                        if (!message.read)
                                          Positioned(
                                            right: 1,
                                            top: 1,
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: AppColors.danger,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            message.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: message.read
                                                  ? FontWeight.w400
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          Formatters.relative(message.createdAt),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        message.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'support':
        return AppColors.primary;
      case 'offline':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'support':
        return Icons.support_agent_rounded;
      case 'offline':
        return Icons.wifi_off_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }
}
