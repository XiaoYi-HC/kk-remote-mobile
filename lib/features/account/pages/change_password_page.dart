import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppServices>().accountApi.changePassword(
            oldPassword: _oldController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改')));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('修改密码'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _oldController,
                  label: '当前密码',
                  hint: '请输入当前密码',
                  allowToggleObscure: true,
                  obscure: true,
                  validator: (value) => Validators.required(value, '当前密码'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _newController,
                  label: '新密码',
                  hint: '至少 8 位，包含字母和数字',
                  allowToggleObscure: true,
                  obscure: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirmController,
                  label: '确认新密码',
                  hint: '请再次输入新密码',
                  allowToggleObscure: true,
                  obscure: true,
                  validator: (value) => Validators.confirmPassword(value, _newController.text),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AppPrimaryButton(label: '确认修改', loading: _saving, onPressed: _submit),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  child: const Text('忘记原密码？通过手机/邮箱找回', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
