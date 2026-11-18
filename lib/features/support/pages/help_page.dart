import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/content.dart';
import '../../../data/models/support.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';
import '../widgets/leave_message_sheet.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _searchController = TextEditingController();
  List<FaqCategory> _categories = [];
  List<FaqItem> _faqs = [];
  List<Ticket> _tickets = [];
  int? _categoryId;
  bool _loading = true;
  String? _error;
  String _keyword = '';
  int _faqSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFaqs();
      _loadTickets();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFaqs() async {
    final seq = ++_faqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final result = await services.contentApi.faqs(
            categoryId: _categoryId,
            keyword: _keyword,
          );
      if (!mounted || seq != _faqSeq) return;
      setState(() {
        _categories = result.categories;
        _faqs = result.list;
      });
      if (_keyword.isNotEmpty && result.list.isNotEmpty) {
        services.contentApi.logFaqSearch(result.list.first.id, _keyword);
      }
    } catch (e) {
      if (seq == _faqSeq && mounted) setState(() => _error = e.toString());
    } finally {
      if (seq == _faqSeq && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTickets() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final tickets = await context.read<AppServices>().supportApi.tickets(pageSize: 100);
      if (mounted) setState(() => _tickets = tickets);
    } catch (_) {}
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword.trim();
    await _loadFaqs();
  }

  Future<void> _openSupport() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      final login = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要登录'),
          content: const Text('在线客服与留言工单需要登录账号后使用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (login == true && mounted) context.go('/login');
      return;
    }
    if (!mounted) return;
    context.push('/help/support');
  }

  Future<void> _openLeaveMessage() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await _openSupport();
      return;
    }
    final config = context.read<ConfigProvider>().config;
    final ticket = await showLeaveMessageSheet(
      context,
      services: context.read<AppServices>(),
      phoneRequired: config.ticketPhoneRequired,
    );
    if (ticket != null) {
      await _loadTickets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('留言已提交，可在“我的反馈”查看回复')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('帮助与反馈'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadFaqs(), _loadTickets()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, size: 19, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '搜索常见问题，例如“画面卡顿”',
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () => _search(_searchController.text),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('全部'),
                      selected: _categoryId == null,
                      onSelected: (_) {
                        setState(() => _categoryId = null);
                        _loadFaqs();
                      },
                    ),
                  ),
                  ..._categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        onSelected: (_) {
                          setState(() => _categoryId = category.id);
                          _loadFaqs();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(message: '正在加载常见问题…'),
              )
            else if (_error != null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: '暂时无法加载 FAQ',
                description: _error,
                action: OutlinedButton(onPressed: _loadFaqs, child: const Text('重试')),
              )
            else if (_faqs.isEmpty)
              const EmptyState(
                icon: Icons.help_outline_rounded,
                title: '没有找到相关问题',
                description: '换一个关键词，或联系在线客服获取帮助',
              )
            else
              ..._faqs.map(
                (faq) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    title: Row(
                      children: [
                        if (faq.hot) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              '热门',
                              style: TextStyle(fontSize: 8, color: AppColors.warning),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            faq.question,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.answer,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.7,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: '联系在线客服',
                    icon: Icons.support_agent_rounded,
                    onPressed: _openSupport,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppPrimaryButton(
                    label: '人工留言',
                    icon: Icons.edit_note_rounded,
                    onPressed: _openLeaveMessage,
                  ),
                ),
              ],
            ),
            const SettingsSectionTitle('我的反馈'),
            if (!auth.isLoggedIn)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '登录后可查看历史留言与客服回复。',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              )
            else if (_tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '暂无历史反馈。',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              )
            else
              ..._tickets.map(
                (ticket) => _TicketTile(
                  ticket: ticket,
                  onTap: () => context.push('/help/tickets/${ticket.id}', extra: ticket),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (ticket.status) {
      case 'processing':
        return AppColors.warning;
      case 'replied':
        return AppColors.success;
      case 'closed':
        return AppColors.textTertiary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ticket.problemType.isEmpty ? '反馈工单' : ticket.problemType,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(22),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ticket.statusLabel,
                style: TextStyle(fontSize: 9, color: _statusColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${ticket.content}${ticket.replyCount > 0 ? ' · ${ticket.replyCount} 条回复' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.shortDate(ticket.createdAt),
              style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
