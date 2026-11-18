import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/remote.dart';
import '../../../widgets/brand_logo.dart';

/// 连接加载动画：Logo 呼吸 + 环形进度 + 五阶段文案。
/// 仅使用 AnimationController，不依赖第三方动画库。
class ConnectLoading extends StatefulWidget {
  const ConnectLoading({
    super.key,
    required this.stage,
    required this.onCancel,
    required this.onRetry,
    this.failure,
    this.visible = true,
    this.notice,
  });

  final RemoteStage stage;
  final RemoteFailure? failure;
  final bool visible;
  final String? notice;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  State<ConnectLoading> createState() => _ConnectLoadingState();
}

class _ConnectLoadingState extends State<ConnectLoading> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final AnimationController _rotate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const _steps = [
    '正在匹配设备',
    '等待对方确认',
    '正在建立加密通道',
    '正在探测直连',
    '正在传输画面',
  ];

  bool get _failed => widget.stage == RemoteStage.failed;
  bool get _success => widget.stage.isConnected;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ConnectLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    // 连接成功后加载页只是被透明化，动画必须停掉，避免后台持续占用帧调度。
    final running = widget.visible && !_success;
    if (running) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
      if (!_rotate.isAnimating) _rotate.repeat();
    } else {
      _breath.stop();
      _rotate.stop();
    }
  }

  int get _currentStep {
    switch (widget.stage) {
      case RemoteStage.idle:
      case RemoteStage.matching:
        return 0;
      case RemoteStage.waitingConfirm:
        return 1;
      case RemoteStage.iceChecking:
        return 2;
      case RemoteStage.p2pConnected:
      case RemoteStage.relayConnected:
        return 4;
      case RemoteStage.failed:
        return -1;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _rotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: ColoredBox(
          color: AppColors.background,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                          CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
                        ),
                        child: BrandLogo(size: 84, showName: false),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'KK远程',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 148,
                        height: 148,
                        child: AnimatedBuilder(
                          animation: _rotate,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _RingPainter(
                                progress: _failed ? 0 : (_currentStep + 1) / 5,
                                rotation: _rotate.value * 2 * math.pi,
                                failed: _failed,
                              ),
                              child: Center(
                                child: _failed
                                    ? const Icon(
                                        Icons.close_rounded,
                                        size: 42,
                                        color: AppColors.danger,
                                      )
                                    : _success
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 44,
                                            color: AppColors.success,
                                          )
                                        : Text(
                                            '${((_currentStep + 1) * 20).clamp(20, 100)}%',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_failed) ...[
                        Text(
                          widget.failure?.message ?? '连接失败',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '失败原因：${_failureReasonLabel(widget.failure?.reason)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  foregroundColor: AppColors.textSecondary,
                                ),
                                child: const Text('取消连接'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: widget.onRetry,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: const Text('重新连接'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_success) ...[
                        const Text(
                          '连接成功，正在进入画面',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '画面即将呈现，请稍候',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ] else ...[
                        Column(
                          children: List.generate(_steps.length, (index) {
                            final active = index == _currentStep;
                            final done = index < _currentStep;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: done
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: AppColors.success,
                                          )
                                        : active
                                            ? const CircularProgressIndicator(strokeWidth: 2)
                                            : Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: AppColors.border,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _steps[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: active
                                          ? AppColors.textPrimary
                                          : (done ? AppColors.success : AppColors.textTertiary),
                                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.notice ?? 'P2P 优先，失败自动切换中继',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 22),
                        OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(160, 44),
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('取消连接'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _failureReasonLabel(String? reason) {
    switch (reason) {
      case 'timeout':
        return '等待确认超时';
      case 'rejected':
        return '对方拒绝';
      case 'network_unreachable':
        return '网络不可达';
      case 'device_offline':
        return '设备离线';
      case 'auth_failed':
        return '凭证错误';
      case 'version_incompatible':
        return '版本不兼容';
      case 'peer_closed':
      case 'closed':
        return '对方已结束会话';
      case 'internal_error':
        return '连接失败';
      default:
        return '内部错误';
    }
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.rotation, required this.failed});

  final double progress;
  final double rotation;
  final bool failed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;
    canvas.drawCircle(center, radius, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = failed ? AppColors.danger : AppColors.primary;
    final sweep = 2 * math.pi * progress.clamp(0.02, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      rotation - math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.rotation != rotation ||
      oldDelegate.failed != failed;
}
