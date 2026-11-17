import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';

class TwoFactorPage extends StatefulWidget {
  const TwoFactorPage({super.key});

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final TextEditingController _codeController = TextEditingController();
  Map<String, dynamic> _setup = const {};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _setup2fa() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _setup = await context.read<AppServices>().accountApi.setup2fa();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enable() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = '请输入验证器中的 6 位动态码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppServices>().accountApi.enable2fa(code);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      setState(() {
        _setup = const {};
        _codeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两步验证已开启')));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disable() async {
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('关闭两步验证'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(hintText: '6 位动态码或恢复码', counterText: ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<AppServices>().accountApi.disable2fa(code);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两步验证已关闭')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final enabled = auth.user?.totpEnabled == true;
    final secret = asString(_setup['secret']);
    final otpauth = asString(_setup['otpauthUrl']);
    final recovery = asList(_setup['recoveryCodes']).map((item) => item.toString()).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('两步验证'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: enabled ? AppColors.successSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? const Color(0x3327AE60) : const Color(0x40F59E0B),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  enabled ? Icons.verified_user_rounded : Icons.gpp_maybe_outlined,
                  color: enabled ? AppColors.success : AppColors.warning,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled ? '两步验证已开启' : '两步验证未开启',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? '登录时需要输入身份验证器生成的动态码。'
                            : '开启后即使密码泄露，也需要动态码才能登录。',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!enabled && _setup.isEmpty) ...[
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: '开始设置',
              loading: _loading,
              onPressed: _setup2fa,
            ),
            const SettingsSectionTitle('支持的身份验证器'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '可使用 Google Authenticator、Microsoft Authenticator、1Password 等 TOTP 应用。',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
              ),
            ),
          ],
          if (!enabled && _setup.isNotEmpty) ...[
            const SettingsSectionTitle('1. 扫码添加'),
            if (otpauth.isNotEmpty)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: otpauth,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '无法扫码时手动输入密钥',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          secret,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: secret.isEmpty ? null : () => _copy(secret),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (recovery.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '恢复码（仅显示一次，请妥善保存）',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _copy(recovery.join('\n')),
                          style: TextButton.styleFrom(minimumSize: const Size(48, 28)),
                          child: const Text('复制', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: recovery
                          .map(
                            (code) => Text(
                              code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SettingsSectionTitle('2. 输入动态码启用'),
            AppTextField(
              controller: _codeController,
              label: '6 位动态码',
              hint: '身份验证器生成的验证码',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(label: '启用两步验证', loading: _loading, onPressed: _enable),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _setup = const {};
                _codeController.clear();
              }),
              child: const Text('取消设置', style: TextStyle(fontSize: 12)),
            ),
          ],
          if (enabled) ...[
            const SizedBox(height: 18),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            AppSecondaryButton(
              label: '关闭两步验证',
              danger: true,
              loading: _loading,
              onPressed: _disable,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '关闭后账号仅依赖密码保护，建议同时在“登录设备管理”中检查异常登录。',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
