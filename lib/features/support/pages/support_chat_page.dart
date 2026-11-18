import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/support.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../auth/state/auth_provider.dart';
import '../state/support_chat_controller.dart';
import '../state/support_notify_service.dart';
import '../widgets/leave_message_sheet.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> with WidgetsBindingObserver {
  late final SupportChatController _chat;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _sendingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = SupportChatController(services: context.read<AppServices>());
    _chat.addListener(_onChatChanged);
    _chat.init();
  }

  /// 键盘弹出/收起时保持列表滚到底部，输入框跟随键盘。
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SupportNotifyService.instance.leaveConversation();
    _chat.removeListener(_onChatChanged);
    _chat.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (!mounted) return;
    final conversation = _chat.conversation;
    if (conversation != null) {
      SupportNotifyService.instance.enterConversation(conversation.id);
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await _chat.sendText(text);
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (image == null) return;
    setState(() => _sendingImage = true);
    await _chat.sendImage(image.path);
    if (mounted) setState(() => _sendingImage = false);
  }

  Future<void> _showEmoji() async {
    const emojis = [
      '😀', '😄', '😊', '😉', '😍', '🤔', '😅', '😢', '😡', '👍',
      '👏', '🙏', '💪', '🎉', '✅', '❌', '⚠️', '🔧', '💻', '📱',
      '🖥️', '📶', '🔒', '🚀', '❤️', '🌟', '😴', '🤝', '👌', '🆗',
    ];
    await showAppSheet<void>(
      context,
      title: '表情',
      heightFactor: 0.45,
      builder: (sheetContext) => GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(12),
        children: emojis
            .map(
              (emoji) => InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _chat.sendEmoji(emoji);
                },
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _transferHuman() async {
    await _chat.transferHuman();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _chat.queuePosition > 0
              ? '已转人工，当前排队第 ${_chat.queuePosition} 位'
              : '已为您转接人工客服',
        ),
      ),
    );
  }

  Future<void> _openLeaveMessage() async {
    final config = context.read<ConfigProvider>().config;
    final ticket = await showLeaveMessageSheet(
      context,
      services: context.read<AppServices>(),
      phoneRequired: config.ticketPhoneRequired,
    );
    if (ticket != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('留言已提交，可在“我的反馈”查看')),
      );
    }
  }

  Future<void> _rate() async {
    final score = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('评价本次服务'),
        children: List.generate(
          5,
          (index) => SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(index + 1),
            child: Row(
              children: [
                ...List.generate(
                  5,
                  (star) => Icon(
                    star <= index ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${index + 1} 星'),
              ],
            ),
          ),
        ),
      ),
    );
    if (score == null) return;
    await _chat.rate(score, '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('感谢您的评价')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          title: const Text('在线客服'),
        ),
        body: EmptyState(
          icon: Icons.support_agent_rounded,
          title: '登录后联系客服',
          description: '在线客服与留言工单需要登录账号后使用',
          action: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('去登录'),
          ),
        ),
      );
    }
    final conversation = _chat.conversation;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chat.hasAgent && _chat.agentName.isNotEmpty ? _chat.agentName : 'KK远程客服'),
            Text(
              _chat.statusText,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _chat.hasAgent ? null : _transferHuman,
            child: const Text('转人工', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () async {
              final value = await showAppPicker<String>(
                context,
                title: '更多操作',
                options: [
                  const AppSelectOption(
                    value: 'leave',
                    label: '提交留言工单',
                    subtitle: '上传问题说明与附件',
                  ),
                  const AppSelectOption(value: 'reload', label: '刷新消息'),
                  if (conversation != null)
                    const AppSelectOption(value: 'rate', label: '评价服务'),
                ],
              );
              if (value == 'leave') _openLeaveMessage();
              if (value == 'reload') _chat.reload();
              if (value == 'rate') _rate();
            },
            icon: const Icon(Icons.more_horiz_rounded, size: 21),
          ),
        ],
      ),
      body: _chat.loading && _chat.messages.isEmpty
          ? const LoadingView(message: '正在接入客服…')
          : Column(
              children: [
                if (_chat.queuePosition > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.warningSoft,
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 15, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '正在排队等待人工客服，当前第 ${_chat.queuePosition} 位',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: _openLeaveMessage,
                          style: TextButton.styleFrom(minimumSize: const Size(44, 28)),
                          child: const Text('先留言', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                if (_chat.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    color: AppColors.dangerSoft,
                    child: Text(
                      _chat.error!,
                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _chat.messages.length + (_chat.agentTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _chat.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          child: Row(
                            children: [
                              _TypingDots(),
                              SizedBox(width: 6),
                              Text(
                                '客服正在输入…',
                                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        );
                      }
                      return _MessageBubble(message: _chat.messages[index]);
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildInputBar() {
    final enabled = _chat.conversation != null && !_chat.conversation!.isClosed;
    return Container(
      // 键盘避让由 Scaffold(resizeToAvoidBottomInset) 负责，这里不能再叠加 viewInsets，
      // 否则会出现输入框被顶到页面上方、聊天记录被挤掉的问题。
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0F1F2329), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '发送图片',
              onPressed: enabled && !_sendingImage ? _pickImage : null,
              icon: _sendingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined, size: 22),
            ),
            IconButton(
              tooltip: '表情',
              onPressed: enabled ? _showEmoji : null,
              icon: const Icon(Icons.emoji_emotions_outlined, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: enabled ? '输入消息…' : '会话已结束',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: '发送',
              onPressed: enabled ? _send : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    final mine = message.isMine;
    final name = mine
        ? '我'
        : (message.senderName.isEmpty
            ? (message.isBot ? 'KK远程客服' : '客服')
            : message.senderName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: message.isBot ? AppColors.primarySoft : AppColors.successSoft,
              child: Icon(
                message.isBot ? Icons.smart_toy_outlined : Icons.support_agent_rounded,
                size: 16,
                color: message.isBot ? AppColors.primary : AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: message.isImage
                      ? const EdgeInsets.all(3)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(mine ? 12 : 3),
                      bottomRight: Radius.circular(mine ? 3 : 12),
                    ),
                    border: mine ? null : Border.all(color: AppColors.border),
                  ),
                  child: message.isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: message.attachmentUrl.isEmpty
                              ? Container(
                                  width: 170,
                                  height: 130,
                                  color: AppColors.background,
                                  child: const Icon(Icons.image_outlined, color: AppColors.textTertiary),
                                )
                              : Image.network(
                                  message.attachmentUrl,
                                  width: 170,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 170,
                                      height: 130,
                                      color: AppColors.background,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stack) => Container(
                                    width: 170,
                                    height: 130,
                                    color: AppColors.background,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                        )
                      : Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: mine ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.sending)
                      const Text(
                        '发送中…',
                        style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
                      )
                    else if (message.failed)
                      const Text(
                        '发送失败',
                        style: TextStyle(fontSize: 9, color: AppColors.danger),
                      )
                    else
                      Text(
                        Formatters.shortDate(message.createdAt),
                        style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final active = ((_controller.value * 3).floor() % 3) == index;
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
