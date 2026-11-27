import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../state/auth_provider.dart';

/// 全局账号状态提示。
///
/// 账号被管理员设置有效期并到期后，服务端会强制吊销令牌，
/// 客户端收到 401 会清除登录态；这里在任意页面弹出「账号已到期」提示，
/// 避免用户只看到突然跳回登录页却不知道原因。
class AccountExpiryGate extends StatefulWidget {
  const AccountExpiryGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AccountExpiryGate> createState() => _AccountExpiryGateState();
}

class _AccountExpiryGateState extends State<AccountExpiryGate> {
  AuthProvider? _auth;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_onChanged);
      _auth = auth;
      auth.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || _showing) return;
    final notice = _auth?.sessionNotice;
    if (notice == null || notice.isEmpty) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(notice));
  }

  Future<void> _show(String notice) async {
    final dialogContext = widget.navigatorKey.currentContext;
    if (!mounted || dialogContext == null) {
      _showing = false;
      return;
    }
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('账号已到期'),
          ],
        ),
        content: Text(notice, style: const TextStyle(height: 1.6)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    _showing = false;
    _auth?.clearSessionNotice();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
