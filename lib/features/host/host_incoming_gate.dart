import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_services.dart';
import 'host_controller.dart';

/// 全局监听被控连接请求。
///
/// 之前确认弹窗只挂在「屏幕共享」页面里，用户返回首页后虽然信令仍然在线，
/// 但没有任何页面监听 `incoming`，桌面端发起连接时手机上不会弹确认框。
/// 这里在应用根部统一监听，无论当前停在哪个页面都能弹出确认。
class HostIncomingGate extends StatefulWidget {
  const HostIncomingGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<HostIncomingGate> createState() => _HostIncomingGateState();
}

class _HostIncomingGateState extends State<HostIncomingGate> with WidgetsBindingObserver {
  HostShareController? _controller;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = HostShareController.shared(context.read<AppServices>());
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onChanged);
      _controller = controller;
      controller.addListener(_onChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时确认信令仍然可用，避免连接被系统冻结后桌面端连不上。
    if (state == AppLifecycleState.resumed) {
      _controller?.ensureOnline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || _dialogShowing) return;
    final controller = _controller;
    if (controller == null) return;
    if (controller.status != HostShareStatus.incoming) return;
    if (controller.incoming == null) return;
    _dialogShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIncoming());
  }

  Future<void> _showIncoming() async {
    final controller = _controller;
    final call = controller?.incoming;
    final dialogContext = widget.navigatorKey.currentContext;
    if (!mounted || controller == null || call == null || dialogContext == null) {
      _dialogShowing = false;
      return;
    }
    final accept = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('桌面端请求观看'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(call.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${call.platformLabel} · ${call.controllerIp}'),
            const SizedBox(height: 10),
            const Text(
              '接受后本机屏幕与麦克风会共享给对方，画面仅用于观看，不会被远程操作。',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('接受'),
          ),
        ],
      ),
    );
    _dialogShowing = false;
    if (!mounted) return;
    if (accept == true) {
      await controller.accept();
    } else {
      controller.reject();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
