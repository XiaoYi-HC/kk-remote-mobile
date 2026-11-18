import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

class CountdownButton extends StatefulWidget {
  const CountdownButton({
    super.key,
    required this.onSend,
    this.seconds = AppConstants.smsCountdown,
    this.label = '获取验证码',
    this.enabled = true,
  });

  /// 返回 true 时开始倒计时。
  final Future<bool> Function() onSend;
  final int seconds;
  final String label;
  final bool enabled;

  @override
  State<CountdownButton> createState() => _CountdownButtonState();
}

class _CountdownButtonState extends State<CountdownButton> {
  Timer? _timer;
  int _remaining = 0;
  bool _sending = false;

  bool get _canSend => widget.enabled && !_sending && _remaining == 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    setState(() => _remaining = widget.seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remaining--;
        if (_remaining <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handle() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      final ok = await widget.onSend();
      if (!mounted) return;
      if (ok) _start();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _remaining > 0 ? '${_remaining}s 后重发' : widget.label;
    return Semantics(
      button: true,
      label: text,
      enabled: _canSend,
      child: TextButton(
        onPressed: _canSend ? _handle : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(104, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textTertiary,
        ),
        child: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
