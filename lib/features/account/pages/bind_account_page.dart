import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/countdown_button.dart';
import '../../auth/state/auth_provider.dart';

class BindAccountPage extends StatefulWidget {
  const BindAccountPage({super.key, this.type = 'phone'});

  final String type;

  @override
  State<BindAccountPage> createState() => _BindAccountPageState();
}

class _BindAccountPageState extends State<BindAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _codeController = TextEditingController();
  final _oldCodeController = TextEditingController();
  late String _type;
  bool _saving = false;
  String? _error;

  bool get _isEmail => _type == 'email';

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'email' ? 'email' : 'phone';
  }

  @override
  void dispose() {
    _targetController.dispose();
    _codeController.dispose();
    _oldCodeController.dispose();
    super.dispose();
  }

  Future<bool> _sendCode() async {
    final target = _targetController.text.trim();
    final error = _isEmail ? Validators.email(target) : Validators.phone(target);
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    try {
      if (_isEmail) {
        await context.read<AppServices>().authApi.sendEmail(email: target, scene: 'bind');
      } else {
        await context.read<AppServices>().authApi.sendSms(phone: target, scene: 'bind');
      }
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证码已发送至${_isEmail ? '邮箱' : '手机'}')),
      );
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return false;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<AppServices>().accountApi;
      if (_isEmail) {
        await api.bindEmail(
          email: _targetController.text.trim(),
          code: _codeController.text.trim(),
          oldCode: _oldCodeController.text.trim(),
        );
      } else {
        await api.bindPhone(
          phone: _targetController.text.trim(),
          code: _codeController.text.trim(),
          oldCode: _oldCodeController.text.trim(),
        );
      }
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isEmail ? '邮箱' : '手机号'}已更新')),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final current = _isEmail ? user?.email : user?.phone;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: Text(_isEmail ? '换绑邮箱' : '换绑手机号'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'phone', label: Text('手机号')),
                    ButtonSegment(value: 'email', label: Text('邮箱')),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    setState(() {
                      _type = value.first;
                      _targetController.clear();
                      _codeController.clear();
                      _oldCodeController.clear();
                      _error = null;
                    });
                  },
                  style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '当前绑定：${current == null || current.isEmpty ? '未绑定' : Formatters.maskedAccount(current)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _targetController,
                  label: _isEmail ? '新邮箱' : '新手机号',
                  hint: _isEmail ? '请输入新邮箱' : '请输入新手机号',
                  prefixText: _isEmail ? null : '+86  ',
                  keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
                  inputFormatters: _isEmail
                      ? null
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                  validator: _isEmail ? Validators.email : Validators.phone,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _codeController,
                        label: '新${_isEmail ? '邮箱' : '手机'}验证码',
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
                  controller: _oldCodeController,
                  label: '原${_isEmail ? '邮箱' : '手机'}验证码（选填）',
                  hint: '已绑定原账号时建议填写',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
                const SizedBox(height: 22),
                AppPrimaryButton(
                  label: '确认换绑',
                  loading: _saving,
                  onPressed: _submit,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '换绑后原手机号/邮箱将无法用于登录，请确保新账号可正常接收验证码。',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
