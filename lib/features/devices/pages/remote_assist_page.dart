import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../state/connect_args.dart';

/// "远程协助"Tab：输入被控端识别码发起连接。
class RemoteAssistPage extends StatefulWidget {
  const RemoteAssistPage({super.key});

  @override
  State<RemoteAssistPage> createState() => _RemoteAssistPageState();
}

class _RemoteAssistPageState extends State<RemoteAssistPage> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _navigating = false;

  Future<void> _connect() async {
    if (_navigating) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入被控端识别码');
      return;
    }
    setState(() {
      _error = null;
      _navigating = true;
    });
    await context.push('/connect', extra: ConnectArgs(deviceCode: code));
    if (mounted) setState(() => _navigating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            const Text(
              '远程协助',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
            const SizedBox(height: 6),
            const Text(
              '输入被控电脑上显示的识别码，即可发起远程连接',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A1F2329), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dialpad_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '识别码连接',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _codeController,
                    label: '被控端识别码',
                    hint: '请输入 6~24 位识别码',
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _connect(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AppPrimaryButton(label: '连接', onPressed: _connect),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: '扫码连接',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: () => context.push('/scan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '连接提示',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. 在被控电脑上打开 KK远程 被控端\n'
                    '2. 将页面上显示的识别码填入上方\n'
                    '3. 按提示输入验证码完成连接',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
