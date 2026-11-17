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
import '../../../widgets/brand_logo.dart';
import '../../../widgets/countdown_button.dart';
import '../../../widgets/loading_view.dart';
import '../state/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialAccount = ''});

  final String initialAccount;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _phoneFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreed = false;
  final bool _obscurePassword = true;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _accountController.text = widget.initialAccount;
    if (widget.initialAccount.isNotEmpty && widget.initialAccount.contains('@')) {
      _tabController.index = 1;
    }
    _agreed = context.read<SettingsProvider>().protocolAgreed;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _sendCode() async {
    final phone = _phoneController.text.trim();
    final error = Validators.phone(phone);
    if (error != null) {
      setState(() => _inlineError = error);
      return false;
    }
    try {
      await context.read<AppServices>().authApi.sendSms(phone: phone, scene: 'login');
      if (!mounted) return true;
      _showMessage('验证码已发送，请注意查收');
      setState(() => _inlineError = null);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _inlineError = e.toString());
      return false;
    }
  }

  Future<void> _loginByCode() async {
    if (!_validateAgreement()) return;
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    try {
      final result = await auth.loginPhone(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
      );
      if (!mounted || result == null) return;
      if (result.need2fa) {
        await _show2faDialog(auth);
        return;
      }
      await _afterLogin(auth);
    } catch (e) {
      if (mounted) setState(() => _inlineError = e.toString());
    }
  }

  Future<void> _loginByPassword() async {
    if (!_validateAgreement()) return;
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    try {
      final result = await auth.loginPassword(
        account: _accountController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted || result == null) return;
      if (result.need2fa) {
        await _show2faDialog(auth);
        return;
      }
      await _afterLogin(auth);
    } catch (e) {
      if (mounted) setState(() => _inlineError = e.toString());
    }
  }

  Future<void> _afterLogin(AuthProvider auth) async {
    await context.read<SettingsProvider>().setBool(SettingsKeys.protocolAgreed, true);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _show2faDialog(AuthProvider auth) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('两步验证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请输入身份验证器中的 6 位动态码，或使用恢复码。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: const InputDecoration(hintText: '6 位动态码', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('验证'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await auth.verify2fa(code);
      await _afterLogin(auth);
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool _validateAgreement() {
    if (_agreed) return true;
    HapticFeedback.mediumImpact();
    setState(() => _inlineError = '请先阅读并同意《用户协议》《隐私政策》');
    return false;
  }

  Future<void> _guestLogin() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.loginAsGuest();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _inlineError = e.toString());
    }
  }

  Future<void> _startOAuth(ThirdPartyChannel channel) async {
    final services = context.read<AppServices>();
    final auth = context.read<AuthProvider>();
    try {
      final data = await services.authApi.oauthUrl(channel.provider);
      final url = Uri.tryParse(data['url']?.toString() ?? '');
      final state = data['state']?.toString() ?? '';
      if (url == null) throw Exception('授权地址无效');
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('无法打开授权页面');
      if (!mounted) return;
      final code = await showTextInputDialog(
        context,
        title: '${channel.name}授权',
        hint: '完成授权后粘贴回调 code（可选）',
        confirmText: '完成登录',
        maxLength: 512,
      );
      if (code == null || code.isEmpty) return;
      await auth.oauthLogin(provider: channel.provider, code: code, state: state);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _inlineError = e.toString());
    }
  }

  void _showProtocol(String type) {
    final config = context.read<ConfigProvider>().config;
    final data = config.protocols[type];
    final map = data is Map ? data : const {};
    final content = (map['content'] ?? '').toString();
    showInfoDialog(
      context,
      title: type == 'privacy' ? '隐私政策' : '用户协议',
      content: content.isEmpty
          ? '协议内容由后台配置下发。登录即代表你已阅读并同意${AppConstants.productName}用户协议与隐私政策。'
          : content,
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _BrandPanel()),
                          const SizedBox(width: 40),
                          SizedBox(width: 420, child: _buildFormCard(config, auth)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          const BrandLogo(size: 76, subtitle: '安全、流畅的跨端远程控制'),
                          const SizedBox(height: 28),
                          _buildFormCard(config, auth),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(ConfigProvider config, AuthProvider auth) {
    final showCodeTab = config.loginEnabled('phone');
    final showPasswordTab = config.loginEnabled('password');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1F2329), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCodeTab && showPasswordTab)
            TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.border,
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 15),
              tabs: const [
                Tab(text: '手机号验证码登录'),
                Tab(text: '密码登录'),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                showCodeTab ? '手机号验证码登录' : '密码登录',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 14),
          if (showCodeTab && showPasswordTab)
            SizedBox(
              height: 244,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildCodeForm(), _buildPasswordForm()],
              ),
            )
          else
            SizedBox(
              height: 190,
              child: showCodeTab
                  ? _buildCodeForm()
                  : (showPasswordTab
                      ? _buildPasswordForm()
                      : _buildDisabledHint('登录方式已全部关闭')),
            ),
          const SizedBox(height: 4),
          if (_inlineError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          AppPrimaryButton(
            label: '登录',
            loading: auth.loading,
            onPressed: () {
              final useCode = showCodeTab && (!showPasswordTab || _tabController.index == 0);
              if (useCode) {
                _loginByCode();
              } else {
                _loginByPassword();
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AgreementRow(
                  agreed: _agreed,
                  onChanged: (value) => setState(() => _agreed = value),
                  onUserProtocol: () => _showProtocol('user'),
                  onPrivacy: () => _showProtocol('privacy'),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('忘记密码', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/register'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 38),
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('立即注册', style: TextStyle(fontSize: 13)),
              ),
              if (config.allowGuest)
                Container(
                  width: 1,
                  height: 12,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
              if (config.allowGuest)
                TextButton(
                  onPressed: auth.loading ? null : _guestLogin,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 38),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('游客体验', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          if (config.loginChannels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('其他登录方式', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 10,
              children: config.loginChannels
                  .map((channel) => _ThirdPartyButton(
                        channel: channel,
                        onTap: auth.loading ? null : () => _startOAuth(channel),
                      ))
                  .toList(),
            ),
          ],
          if (config.isLoading && !config.loadedOnce)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LoadingView(message: '正在读取登录配置…'),
            ),
        ],
      ),
    );
  }

  Widget _buildCodeForm() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
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
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) {
              if (_inlineError != null) setState(() => _inlineError = null);
            },
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
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: Validators.code,
                  onSubmitted: (_) => _loginByCode(),
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
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          AppTextField(
            controller: _accountController,
            label: '账号',
            hint: '手机号 / 邮箱 / 用户名',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) => Validators.required(value, '账号'),
            autofillHints: const [AutofillHints.username],
            onChanged: (_) {
              if (_inlineError != null) setState(() => _inlineError = null);
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: '密码',
            hint: '请输入密码',
            obscure: _obscurePassword,
            allowToggleObscure: true,
            textInputAction: TextInputAction.done,
            validator: (value) => Validators.required(value, '密码'),
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _loginByPassword(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledHint(String text) {
    return Center(
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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

class _ThirdPartyButton extends StatelessWidget {
  const _ThirdPartyButton({required this.channel, this.onTap});

  final ThirdPartyChannel channel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glyph = AppConstants.providerGlyphs[channel.provider] ?? channel.name.characters.first;
    final isApple = channel.provider == 'apple';
    return Semantics(
      button: true,
      label: '使用${channel.name}登录',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
              ),
              child: isApple
                  ? const Icon(Icons.apple, size: 26, color: AppColors.textPrimary)
                  : Text(
                      glyph,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              channel.name,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(size: 88, showName: false),
          const SizedBox(height: 22),
          Text(
            AppConstants.productName,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          const Text(
            '安全、流畅的跨端远程控制',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),
          ...const [
            _BrandPoint(icon: Icons.bolt_rounded, text: 'P2P 直连，低延迟画面传输'),
            _BrandPoint(icon: Icons.lock_outline_rounded, text: '端到端加密，隐私黑屏保护'),
            _BrandPoint(icon: Icons.devices_rounded, text: '手机随时连接 Windows 电脑'),
          ],
        ],
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
