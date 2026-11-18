import 'dart:async';

import '../../../core/platform/notification_service.dart';
import '../../../data/models/support.dart';
import '../../../data/ws/support_socket.dart';
import '../../../state/app_services.dart';

/// 全局客服通道：登录后常驻，客服回复或工单回复时发送本地通知。
///
/// 通知带 accountId，切换账号 / 退出登录时会清理，避免不同账号的通知串在一起。
class SupportNotifyService {
  SupportNotifyService._();

  static final SupportNotifyService instance = SupportNotifyService._();

  SupportSocket? _socket;
  StreamSubscription<SupportSocketEvent>? _sub;
  Timer? _reconnectTimer;
  int _accountId = 0;
  int _viewingConversationId = 0;
  String _token = '';
  String _wsUrl = '';
  bool _running = false;
  bool _starting = false;
  bool _notificationsEnabled = true;

  /// 进入某个会话时暂停该会话的通知，避免正在聊天还弹提醒。
  void enterConversation(int conversationId) => _viewingConversationId = conversationId;

  void leaveConversation() => _viewingConversationId = 0;

  Future<void> start({
    required AppServices services,
    required int accountId,
    required String token,
  }) async {
    if (accountId == 0 || token.isEmpty) return;
    if (_running && _accountId == accountId && _token == token) return;
    // build() 中会重复触发 start，必须做互斥，避免并发创建多个 socket。
    if (_starting) return;
    _starting = true;
    try {
      // 切换账号时清掉上一账号遗留的通知。
      if (_accountId != 0 && _accountId != accountId) {
        await NotificationService.instance.cancelAll();
      }
      await stop();
      _accountId = accountId;
      _token = token;
      _wsUrl = services.supportSocketUrl;
      // 用户关闭通知开关后不再弹客服/工单提醒。
      _notificationsEnabled = services.settings.notificationEnabled;
      _running = true;
      await _connect();
    } finally {
      _starting = false;
    }
  }

  Future<void> _connect() async {
    if (!_running) return;
    final socket = SupportSocket();
    _socket = socket;
    _sub = socket.events.listen(_onEvent);
    try {
      await socket.connect(wsBaseUrl: _wsUrl, token: _token);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 8), () {
      if (_running) {
        _sub?.cancel();
        _socket?.dispose();
        _connect();
      }
    });
  }

  void _onEvent(SupportSocketEvent event) {
    if (!_running) return;
    switch (event.type) {
      case 'support.message':
        final message = SupportMessage.fromJson(event.data);
        if (!message.isAgent) return;
        if (message.conversationId == _viewingConversationId) return;
        _notify(
          title: message.senderName.isEmpty ? '客服回复' : message.senderName,
          body: message.isImage ? '[图片]' : message.content,
          payload: {'type': 'support', 'conversationId': message.conversationId},
        );
        break;
      case 'ticket.reply':
        _notify(
          title: '工单有新回复',
          body: '客服已回复您的工单，点击查看',
          payload: {'type': 'ticket', 'ticketId': event.data['ticketId']},
        );
        break;
      case 'support.disconnected':
        _scheduleReconnect();
        break;
      default:
        break;
    }
  }

  void _notify({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) {
    if (!_notificationsEnabled) return;
    NotificationService.instance.showMessage(
      title: title,
      body: body,
      payload: {...payload, 'accountId': _accountId},
    );
  }

  Future<void> stop({bool clearNotifications = false}) async {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _socket?.dispose();
    _socket = null;
    _viewingConversationId = 0;
    if (clearNotifications) {
      await NotificationService.instance.cancelAll();
    }
  }
}
