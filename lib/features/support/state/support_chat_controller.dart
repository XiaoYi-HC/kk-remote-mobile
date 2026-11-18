import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/json_utils.dart';
import '../../../data/models/support.dart';
import '../../../data/ws/support_socket.dart';
import '../../../state/app_services.dart';

class SupportChatController extends ChangeNotifier {
  SupportChatController({required this.services});

  final AppServices services;
  final SupportSocket _socket = SupportSocket();
  StreamSubscription<SupportSocketEvent>? _socketSub;

  SupportConversation? conversation;
  List<SupportMessage> messages = [];
  bool loading = false;
  bool sending = false;
  String? error;
  int queuePosition = 0;
  bool socketReady = false;
  bool agentTyping = false;
  String fallback = '未匹配到答案，请转人工或提交留言工单。';
  int rating = 0;

  bool get isLoggedIn => services.api.token != null && services.api.token!.isNotEmpty;
  bool get hasAgent => conversation?.isHumanOnline ?? false;
  String get agentName => conversation?.agentName ?? '';
  String get statusText {
    if (conversation == null) return '正在连接客服';
    if (conversation!.isClosed) return '会话已结束';
    if (hasAgent) return '$agentName 在线';
    if (conversation!.isQueued && queuePosition > 0) return '排队中 · 第 $queuePosition 位';
    return '机器人在线';
  }

  // ---- 历史会话懒加载 ----
  bool historyLoading = false;
  bool historyExhausted = false;
  bool _historyListLoaded = false;
  final List<SupportConversation> _historyConversations = [];
  int _historyCursor = 0;

  int _currentConversationId = 0;

  /// 当前是否有更多历史会话可加载。
  bool get hasMoreHistory => !historyExhausted;

  /// 每次进入聊天页都开启全新会话：不读取旧会话，也不展示历史消息。
  Future<void> init() async {
    loading = true;
    historyLoading = false;
    historyExhausted = false;
    _historyListLoaded = false;
    _historyConversations.clear();
    _historyCursor = 0;
    error = null;
    notifyListeners();
    try {
      fallback = await services.supportApi.fallbackText();
      final created = await services.supportApi.createConversation(forceNew: true);
      conversation = created;
      _currentConversationId = created.id;
      messages = [];
      await _connectSocket(created.id);
      unawaited(_refreshAfterDelay());
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 向上回看时按会话逐个加载更早的历史记录（只读查阅，不参与发送）。
  Future<void> loadHistoryPage() async {
    if (historyLoading || historyExhausted) return;
    final conv = conversation;
    if (conv == null) return;
    historyLoading = true;
    error = null;
    notifyListeners();
    try {
      if (!_historyListLoaded) {
        final list = await services.supportApi.conversations();
        _historyConversations
          ..clear()
          ..addAll(list.where((item) => item.id != conv.id));
        _historyListLoaded = true;
      }
      if (_historyCursor >= _historyConversations.length) {
        historyExhausted = true;
        return;
      }
      final target = _historyConversations[_historyCursor];
      final result = await services.supportApi.messages(target.id);
      _historyCursor++;
      // 历史仅保留对话内容，过滤系统提示，便于查阅。
      final older = result.messages
          .map(_normalize)
          .where((item) => !item.isSystem)
          .toList();
      if (older.isNotEmpty) {
        messages = [...older, ...messages];
      }
      if (_historyCursor >= _historyConversations.length) {
        historyExhausted = true;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectSocket(int conversationId) async {
    if (!isLoggedIn) return;
    try {
      _socketSub ??= _socket.events.listen(_handleSocketEvent);
      await _socket.connect(
        wsBaseUrl: services.supportSocketUrl,
        token: services.api.token!,
      );
      socketReady = true;
      _socket.markRead(conversationId);
    } catch (e) {
      socketReady = false;
      if (kDebugMode) debugPrint('support socket connect failed: $e');
    }
    notifyListeners();
  }

  /// 判断事件是否属于当前会话。事件未携带会话 ID 时按当前会话处理。
  bool _belongsToCurrentConversation(SupportSocketEvent event) {
    if (_currentConversationId == 0) return true;
    final data = event.data;
    var id = asInt(data['conversationId']);
    if (id == 0 && data['message'] is Map) {
      id = asInt(asMap(data['message'])['conversationId']);
    }
    return id == 0 || id == _currentConversationId;
  }

  void _handleSocketEvent(SupportSocketEvent event) {
    // 只处理当前新会话的事件，避免旧会话消息串流到本次聊天。
    if (!_belongsToCurrentConversation(event)) return;
    switch (event.type) {
      case 'support.ready':
        socketReady = true;
        break;
      case 'support.message':
        final message = SupportMessage.fromJson(event.data);
        _appendMessage(message);
        break;
      case 'support.claimed':
        final name = asString(event.data['agentName'], fallback: '人工客服');
        conversation = conversation?.copyWith(
          agentId: asInt(event.data['agentId']),
          agentName: name,
          status: 'active',
        );
        queuePosition = 0;
        break;
      case 'support.transferred':
        conversation = conversation?.copyWith(status: 'queued');
        queuePosition = asInt(event.data['queuePosition']);
        break;
      case 'support.closed':
        conversation = conversation?.copyWith(status: 'closed');
        break;
      case 'support.typing':
        agentTyping = true;
        notifyListeners();
        Future<void>.delayed(const Duration(seconds: 3), () {
          agentTyping = false;
          notifyListeners();
        });
        return;
      case 'support.error':
        error = asString(event.data['message'], fallback: '客服消息发送失败');
        break;
      case 'ticket.reply':
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// 服务端返回的附件地址是相对路径，这里统一补成完整地址。
  SupportMessage _normalize(SupportMessage message) {
    final url = message.attachmentUrl;
    if (url.isEmpty || url.startsWith('http://') || url.startsWith('https://')) {
      return message;
    }
    return message.copyWith(
      attachmentUrl: services.api.resolveUri(url).toString(),
    );
  }

  void _appendMessage(SupportMessage raw) {
    final message = _normalize(raw);
    if (message.id > 0 && messages.any((item) => item.id == message.id)) {
      return;
    }
    // WebSocket 回传自己发送的消息时，用服务端消息替换本地乐观占位，避免重复。
    if (message.isMine) {
      final index = messages.indexWhere(
        (item) =>
            item.id == 0 &&
            item.isMine &&
            item.content == message.content &&
            !item.failed,
      );
      if (index >= 0) {
        messages[index] = message.attachmentUrl.isEmpty
            ? message.copyWith(attachmentUrl: messages[index].attachmentUrl)
            : message;
        agentTyping = false;
        notifyListeners();
        return;
      }
    }
    messages = [...messages, message];
    agentTyping = false;
    notifyListeners();
  }

  Future<void> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty || conversation == null) return;
    final conv = conversation!;
    final optimistic = SupportMessage(
      localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conv.id,
      senderType: 'user',
      contentType: 'text',
      content: content,
      sending: true,
      createdAt: DateTime.now(),
    );
    messages = [...messages, optimistic];
    sending = true;
    error = null;
    notifyListeners();
    try {
      if (socketReady) {
        _socket.sendMessage(
          conversationId: conv.id,
          contentType: 'text',
          content: content,
        );
        _replaceOptimistic(optimistic, optimistic.copyWith(sending: false));
      } else {
        final message = await services.supportApi.sendMessage(
          conversationId: conv.id,
          contentType: 'text',
          content: content,
        );
        _replaceOptimistic(optimistic, message);
        unawaited(_refreshAfterDelay());
      }
    } catch (e) {
      _replaceOptimistic(optimistic, optimistic.copyWith(sending: false, failed: true));
      error = e.toString();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendImage(String filePath) async {
    final conv = conversation;
    if (conv == null) return;
    sending = true;
    error = null;
    notifyListeners();
    try {
      final upload = await services.supportApi.uploadAttachment(filePath);
      final url = services.api.resolveUri(upload.url).toString();
      final optimistic = SupportMessage(
        localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conv.id,
        senderType: 'user',
        contentType: 'image',
        content: '[图片]',
        attachmentId: upload.id,
        attachmentUrl: url,
        sending: true,
        createdAt: DateTime.now(),
      );
      messages = [...messages, optimistic];
      notifyListeners();
      final message = await services.supportApi.sendMessage(
        conversationId: conv.id,
        contentType: 'image',
        content: '[图片]',
        attachmentId: upload.id,
      );
      _replaceOptimistic(
        optimistic,
        () {
          final saved = _normalize(message);
          // 服务端若未回传附件地址，保留本地上传后的地址，保证图片立即可见。
          return saved.attachmentUrl.isEmpty
              ? saved.copyWith(attachmentUrl: optimistic.attachmentUrl)
              : saved;
        }(),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> sendEmoji(String emoji) => sendText(emoji);

  void _replaceOptimistic(SupportMessage old, SupportMessage next) {
    final index = messages.indexWhere((item) => item.localId == old.localId);
    if (index >= 0) {
      messages[index] = next;
    } else {
      messages = [...messages, next];
    }
  }

  Future<void> transferHuman() async {
    final conv = conversation;
    if (conv == null) return;
    try {
      final result = await services.supportApi.transferHuman(conv.id);
      if (result.conversation != null) conversation = result.conversation;
      queuePosition = result.queuePosition;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> rate(int score, String comment) async {
    final conv = conversation;
    if (conv == null) return;
    try {
      await services.supportApi.rate(conversationId: conv.id, score: score, comment: comment);
      rating = score;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final conv = conversation;
    if (conv == null) return;
    try {
      final result = await services.supportApi.messages(conv.id);
      messages = result.messages.map(_normalize).toList();
      if (result.conversation != null) conversation = result.conversation;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAfterDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await reload();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket.dispose();
    super.dispose();
  }
}

void unawaited(Future<void> future) {
  future.catchError((Object _) {});
}
