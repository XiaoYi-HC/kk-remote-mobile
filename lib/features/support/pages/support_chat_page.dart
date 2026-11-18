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
import '../../../widgets/user_avatar.dart';
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
  Timer? _clockTimer;

  /// 历史加载中：此时不自动滚动到底部，避免打断查阅。
  bool _loadingHistory = false;

  /// 客服在线时段：12:00-23:00。
  bool get _serviceOnline {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 12 * 60 && minutes < 23 * 60;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = SupportChatController(services: context.read<AppServices>());
    _chat.addListener(_onChatChanged);
    _chat.init();
    // 在线时段会随时间变化，定时重建以刷新顶部状态。
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// 键盘弹出/收起时保持列表滚到底部，输入框跟随键盘。
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      // 用户正在回看历史时不要强行拉回底部。
      if (position.maxScrollExtent - position.pixels > 160) return;
      _scrollController.jumpTo(position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
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
    // 加载历史记录时不自动滚到底部，保持用户当前查阅位置。
    if (_loadingHistory || _chat.historyLoading) return;
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

  /// 向下滑动到列表顶部时，逐页加载更早的历史会话记录（只读查阅）。
  Future<void> _loadHistory() async {
    if (_loadingHistory || _chat.historyLoading || !_chat.hasMoreHistory) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    _loadingHistory = true;
    await _chat.loadHistoryPage();
    _loadingHistory = false;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      // 短列表（无法滚动）时保持顶部，便于查看刚加载的历史。
      final target = distanceFromBottom <= 0
          ? 0.0
          : (max - distanceFromBottom).clamp(0.0, max);
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final ok = await _chat.sendText(text);
    if (!mounted) return;
    if (ok) {
      // 发送成功才清空输入框，失败时保留内容方便重发。
      _inputController.clear();
    } else {
      _inputController.text = text;
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
      if (image == null || !mounted) return;
      setState(() => _sendingImage = true);
      await _chat.sendImage(image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
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
    final ok = await _chat.transferHuman();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? '转人工失败：${_chat.error ?? '请稍后重试'}'
              : (_chat.queuePosition > 0
                  ? '已转人工，当前排队第 ${_chat.queuePosition} 位'
                  : '已为您转接人工客服'),
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
    final ok = await _chat.rate(score, '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '感谢您的评价' : '评价失败：${_chat.error ?? '请稍后重试'}',
        ),
      ),
    );
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
            const SizedBox(height: 2),
            Row(
              children: [
                const Text(
                  '在线时间 12:00-23:00',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _serviceOnline ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _serviceOnline ? '在线' : '离线',
                  style: TextStyle(
                    fontSize: 10,
                    color: _serviceOnline ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
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
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // 只有用户主动拖动并到达列表顶部时才加载历史，避免进入页面自动触发。
                      if (notification is ScrollUpdateNotification &&
                          notification.dragDetails != null &&
                          notification.metrics.pixels <= 8) {
                        _loadHistory();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: _chat.messages.length + 1 + (_chat.agentTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildHistoryHeader();
                        final messageIndex = index - 1;
                        if (messageIndex >= _chat.messages.length) {
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
                        return _MessageBubble(message: _chat.messages[messageIndex]);
                      },
                    ),
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  /// 列表顶部：历史记录加载状态与到底提示。
  Widget _buildHistoryHeader() {
    if (_chat.historyLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            SizedBox(width: 8),
            Text(
              '正在加载历史记录…',
              style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }
    if (!_chat.hasMoreHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          '没有更多历史记录了',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '下拉查看更多历史记录',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
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

  /// 客服固定头像（本地资源，避免远程依赖）。
  static const _agentAvatarAsset = 'assets/images/support_agent_avatar.png';

  /// 用户未设置头像时的默认头像（本地资源）。
  static const _userDefaultAvatarAsset = 'assets/images/user_default_avatar.png';

  static const double _avatarSize = 40;

  final SupportMessage message;

  Widget _agentAvatar() {
    return ClipOval(
      child: Image.asset(
        _agentAvatarAsset,
        width: _avatarSize,
        height: _avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: _avatarSize,
          height: _avatarSize,
          alignment: Alignment.center,
          color: AppColors.primarySoft,
          child: const Icon(Icons.support_agent_rounded, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }

  /// 图片消息：独立展示，不使用气泡背景、尖角与边框。
  Widget _imageContent() {
    const width = 190.0;
    const height = 150.0;
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.background,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textTertiary,
        size: 26,
      ),
    );
    final url = message.attachmentUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: width,
                  height: height,
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => placeholder,
            ),
    );
  }

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
    // 用户头像读取当前登录资料，未设置时使用本地默认图。
    final avatar = context.select<AuthProvider, String>((auth) => auth.user?.avatar ?? '');
    final accountName = context.select<AuthProvider, String>(
      (auth) => auth.user?.displayName ?? '我',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            _agentAvatar(),
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
                if (message.isImage)
                  _imageContent()
                else
                  _WechatBubble(
                    mine: mine,
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
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
            UserAvatar(
              size: _avatarSize,
              avatar: avatar,
              name: accountName,
              fallbackAsset: _userDefaultAvatarAsset,
            ),
          ],
        ],
      ),
    );
  }
}

/// 微信风格气泡：圆角矩形 + 指向头像一侧的尖角。
class _WechatBubble extends StatelessWidget {
  const _WechatBubble({required this.mine, required this.child});

  static const double _tail = 7;
  static const double _radius = 10;

  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: CustomPaint(
        painter: _WechatBubblePainter(
          mine: mine,
          color: mine ? AppColors.primary : AppColors.surface,
          borderColor: mine ? null : AppColors.border,
          radius: _radius,
          tail: _tail,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mine ? 12 : 12 + _tail,
            9,
            mine ? 12 + _tail : 12,
            9,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WechatBubblePainter extends CustomPainter {
  _WechatBubblePainter({
    required this.mine,
    required this.color,
    required this.borderColor,
    required this.radius,
    required this.tail,
  });

  final bool mine;
  final Color color;
  final Color? borderColor;
  final double radius;
  final double tail;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyLeft = mine ? 0.0 : tail;
    final bodyRight = mine ? size.width - tail : size.width;
    final body = Rect.fromLTRB(bodyLeft, 0, bodyRight, size.height);
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));

    const tailTop = 11.0;
    const tailHeight = 9.0;
    final tailPath = Path();
    if (mine) {
      tailPath
        ..moveTo(bodyRight - 0.5, tailTop)
        ..lineTo(size.width, tailTop + tailHeight / 2)
        ..lineTo(bodyRight - 0.5, tailTop + tailHeight);
    } else {
      tailPath
        ..moveTo(bodyLeft + 0.5, tailTop)
        ..lineTo(0, tailTop + tailHeight / 2)
        ..lineTo(bodyLeft + 0.5, tailTop + tailHeight);
    }
    final shape = Path.combine(PathOperation.union, bodyPath, tailPath);
    canvas.drawPath(shape, Paint()..color = color);

    final border = borderColor;
    if (border != null) {
      canvas.drawPath(
        shape,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_WechatBubblePainter oldDelegate) =>
      oldDelegate.mine != mine ||
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.radius != radius ||
      oldDelegate.tail != tail;
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
