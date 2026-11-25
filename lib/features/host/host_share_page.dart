import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_services.dart';
import 'host_controller.dart';
import 'host_models.dart';

/// 移动端被控：让桌面端观看本机屏幕并进行双向语音对讲。
class HostSharePage extends StatefulWidget {
  const HostSharePage({super.key});

  @override
  State<HostSharePage> createState() => _HostSharePageState();
}

class _HostSharePageState extends State<HostSharePage> {
  late final HostShareController _controller;

  @override
  void initState() {
    super.initState();
    // 使用全局单例：离开本页不会停止共享，只有用户主动点击“停止共享”才断开。
    _controller = HostShareController.shared(context.read<AppServices>());
    _controller.addListener(_onChanged);
    _controller.ensureReady();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged());
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  // 连接确认弹窗由应用根部的 HostIncomingGate 统一处理，本页只负责刷新状态。
  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _copy(String value, String label) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label 已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final reg = _controller.registration;
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕共享')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 14),
          if (reg != null) _buildCodeCard(reg),
          if (reg != null) const SizedBox(height: 14),
          _buildShareCard(),
          const SizedBox(height: 14),
          _buildTipCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final (icon, title, subtitle, color) = _statusView();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(28), color.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(36),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_controller.status == HostShareStatus.error)
            TextButton(onPressed: _controller.retry, child: const Text('重试')),
        ],
      ),
    );
  }

  (IconData, String, String, Color) _statusView() {
    switch (_controller.status) {
      case HostShareStatus.registering:
        return (Icons.sync_rounded, '正在准备共享通道', '正在注册本机设备，请稍候', AppColors.connecting);
      case HostShareStatus.ready:
        return (
          Icons.verified_rounded,
          _controller.sharing ? '共享已就绪' : '等待开始共享',
          _controller.sharing ? '桌面端输入识别码和验证码即可连接' : '点击下方按钮开始共享屏幕',
          _controller.sharing ? AppColors.success : AppColors.primary,
        );
      case HostShareStatus.incoming:
        return (Icons.phone_in_talk_rounded, '有桌面端请求连接', '请确认是否允许对方观看', AppColors.warning);
      case HostShareStatus.connecting:
        return (Icons.wifi_tethering_rounded, '正在建立画面通道', '正在与桌面端协商连接', AppColors.primary);
      case HostShareStatus.sharing:
        return (Icons.screen_share_rounded, '正在共享屏幕', '桌面端正在观看本机画面', AppColors.success);
      case HostShareStatus.error:
        return (
          Icons.error_outline_rounded,
          '共享不可用',
          _controller.error ?? '请检查网络后重试',
          AppColors.danger,
        );
    }
  }

  Widget _buildCodeCard(HostRegistration reg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('设备识别码', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Icon(Icons.phone_android_rounded, size: 15, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(_controller.platformLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  reg.deviceCode,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制识别码',
                onPressed: () => _copy(reg.deviceCode, '识别码'),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('验证码', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              const Text(
                '长期有效，不会自动变更',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  reg.verificationCode.isEmpty ? '------' : reg.verificationCode,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制验证码',
                onPressed: () => _copy(reg.verificationCode, '验证码'),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '桌面端连接时选择「输入识别码」，填写以上两项即可。',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCard() {
    final sharing = _controller.sharing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.mic_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('麦克风对讲', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    Text(
                      '开启后桌面端可以听到本机声音',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _controller.micEnabled,
                onChanged: _controller.setMicEnabled,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _controller.status == HostShareStatus.registering
                  ? null
                  : (sharing ? _controller.stopShare : _controller.startShare),
              icon: Icon(sharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded),
              label: Text(sharing ? '停止共享' : '开始共享屏幕'),
              style: FilledButton.styleFrom(
                backgroundColor: sharing ? AppColors.danger : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 10),
            const Text(
              'iOS 需在控制中心点击「屏幕录制」，选择 KK远程 广播后返回本页。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用说明',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
          ),
          SizedBox(height: 6),
          Text(
            '1. 在本页点击「开始共享屏幕」并授权。\n'
            '2. 桌面端在连接页面输入识别码和验证码。\n'
            '3. 本页弹窗确认后，桌面端即可观看画面。\n'
            '4. 桌面端点击「对讲」后双方可以通话。',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.7),
          ),
        ],
      ),
    );
  }
}
