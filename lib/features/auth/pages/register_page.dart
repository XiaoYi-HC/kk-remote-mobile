import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/common.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/countdown_button.dart';
import '../state/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _inviteController = TextEditingController();

  /// 用户手动选择的注册方式；为 null 时跟随后台开关。
  bool? _userEmailChoice;
  bool _agreed = false;
  bool _submitting = false;
  String? _error;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  /// 后台关掉手机号注册后，无论配置何时到达都切到邮箱注册。
  bool _resolveEmailMode(ConfigProvider config) {
    final phone = config.registerEnabled('phone');
    final email = config.registerEnabled('email');
    if (phone && email) return _userEmailChoice ?? false;
    return email;
  }

  void _updateStrength() {
    final score = Validators.passwordStrength(_passwordController.text);
    if (score != _strength) setState(() => _strength = score);
  }

  Future<bool> _sendCode() async {
    final emailMode = _resolveEmailMode(context.read<ConfigProvider>());
    if (emailMode) {
      final error = Validators.email(_emailController.text);
      if (error != null) {
        setState(() => _error = error);
        return false;
      }
      try {
        await context.read<AppServices>().authApi.sendEmail(
              email: _emailController.text.trim(),
              scene: 'register',
            );
        if (mounted) _showMessage('验证码已发送至邮箱');
        return true;
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
        return false;
      }
    }
    final error = Validators.phone(_phoneController.text);
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    try {
      await context.read<AppServices>().authApi.sendSms(
            phone: _phoneController.text.trim(),
            scene: 'register',
          );
      if (mounted) _showMessage('验证码已发送，请注意查收');
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      setState(() => _error = '请先阅读并同意《用户协议》《隐私政策》');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final emailMode = _resolveEmailMode(context.read<ConfigProvider>());
    try {
      await auth.register(
        method: emailMode ? 'email' : 'phone',
        phone: emailMode ? '' : _phoneController.text.trim(),
        email: emailMode ? _emailController.text.trim() : '',
        code: _codeController.text.trim(),
        password: _passwordController.text,
        inviteCode: _inviteController.text.trim(),
      );
      await context.read<SettingsProvider>().setBool(SettingsKeys.protocolAgreed, true);
      // 注册成功后回到登录页并自动回填账号，符合移动端注册流程。
      await auth.logout();
      if (!mounted) return;
      _showMessage('注册成功，请登录');
      context.go('/login?account=${Uri.encodeComponent(
        emailMode ? _emailController.text.trim() : _phoneController.text.trim(),
      )}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _registerWithApple(ThirdPartyChannel channel) async {
    final services = context.read<AppServices>();
    final auth = context.read<AuthProvider>();
    try {
      final data = await services.authApi.oauthUrl(channel.provider);
      final url = Uri.tryParse(data['url']?.toString() ?? '');
      final state = data['state']?.toString() ?? '';
      if (url == null) throw Exception('授权地址无效');
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      final code = await showTextInputDialog(
        context,
        title: 'Apple 注册',
        hint: '完成授权后粘贴回调 code',
        confirmText: '完成注册',
        maxLength: 512,
      );
      if (code == null || code.isEmpty) return;
      await auth.oauthLogin(provider: channel.provider, code: code, state: state);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showProtocol(String type) {
    final config = context.read<ConfigProvider>().config;
    final raw = config.protocols[type];
    final content = raw is Map ? (raw['content']?.toString() ?? '') : '';
    showInfoDialog(
      context,
      title: type == 'privacy' ? '隐私政策' : '用户协议',
      content: content.isEmpty ? '协议内容以${AppConstants.productName}最新版本为准。' : content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final auth = context.watch<AuthProvider>();
    final phoneEnabled = config.registerEnabled('phone');
    final emailEnabled = config.registerEnabled('email');
    final emailMode = _resolveEmailMode(config);
    final canSwitch = phoneEnabled && emailEnabled;
    final noMethod = !phoneEnabled && !emailEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('注册账号'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A1F2329), blurRadius: 24, offset: Offset(0, 10)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '创建账号',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '注册后可在多台设备间同步',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      if (canSwitch) _ModeSwitch(
                        emailMode: emailMode,
                        onChanged: (value) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _userEmailChoice = value;
                            _codeController.clear();
                            _error = null;
                          });
                        },
                      ) else if (!noMethod)
                        Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            emailMode ? '邮箱注册' : '手机号注册',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (noMethod)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            '管理员已关闭注册，请联系客服开通账号',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5),
                          ),
                        )
                      else ...[
                        if (!emailMode)
                          AppTextField(
                            controller: _phoneController,
                            label: '手机号',
                            hint: '请输入手机号',
                            prefixText: '+86  ',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: Validators.phone,
                          )
                        else
                          AppTextField(
                            controller: _emailController,
                            label: '邮箱',
                            hint: '请输入邮箱地址',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.email,
                          ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _codeController,
                                label: '验证码',
                                hint: '6 位验证码',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: Validators.code,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 25),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: CountdownButton(onSend: _sendCode),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _passwordController,
                          label: '设置密码',
                          hint: '至少 8 位，包含字母和数字',
                          allowToggleObscure: true,
                          obscure: true,
                          onChanged: (_) => _updateStrength(),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 8),
                        _PasswordStrengthBar(score: _strength),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _confirmController,
                          label: '确认密码',
                          hint: '请再次输入密码',
                          allowToggleObscure: true,
                          obscure: true,
                          validator: (value) => Validators.confirmPassword(
                            value,
                            _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _inviteController,
                          label: '邀请码（选填）',
                          hint: '填写邀请码可获得额外权益',
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 18),
                        _AgreementRow(
                          agreed: _agreed,
                          onChanged: (value) => setState(() => _agreed = value),
                          onUserProtocol: () => _showProtocol('user'),
                          onPrivacy: () => _showProtocol('privacy'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AppPrimaryButton(
                        label: '注册',
                        loading: _submitting || auth.loading,
                        onPressed: noMethod ? null : _submit,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                          child: const Text('已有账号？去登录', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      if (config.appleRegisterEnabled) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '其他注册方式',
                                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: auth.loading
                                ? null
                                : () => _registerWithApple(config.registerChannels.first),
                            icon: const Icon(Icons.apple, size: 22),
                            label: const Text('使用 Apple 注册'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(220, 46),
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
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
}

/// 注册方式切换（手机号 / 邮箱）。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.emailMode, required this.onChanged});

  final bool emailMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _item('手机号注册', !emailMode, () => onChanged(false))),
          const SizedBox(width: 4),
          Expanded(child: _item('邮箱注册', emailMode, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _item(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x0F1F2329), blurRadius: 6, offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.agreed,
    required this.onChanged,
    required this.onUserProtocol,
    required this.onPrivacy,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;
  final VoidCallback onUserProtocol;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Checkbox(
            value: agreed,
            onChanged: (value) => onChanged(value ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
        ),
        const SizedBox(width: 2),
        const Text('已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        GestureDetector(
          onTap: onUserProtocol,
          child: const Text('《用户协议》', style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ),
        const Text('和', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        GestureDetector(
          onTap: onPrivacy,
          child: const Text('《隐私政策》', style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ),
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score <= 1
        ? AppColors.danger
        : score == 2
            ? AppColors.warning
            : AppColors.success;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 4,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          Validators.passwordStrengthLabel(score),
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}
