import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/brand_logo.dart';
import '../../auth/state/auth_provider.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _signatureController;
  final ImagePicker _picker = ImagePicker();
  String _avatar = '';
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _signatureController = TextEditingController(text: user?.signature ?? '');
    _avatar = user?.avatar ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  String get _avatarUrl {
    if (_avatar.isEmpty) return '';
    if (_avatar.startsWith('http://') || _avatar.startsWith('https://')) return _avatar;
    return context.read<AppServices>().api.resolveUri(_avatar).toString();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (image == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final avatar = await context.read<AppServices>().accountApi.uploadAvatar(image.path);
      setState(() => _avatar = avatar);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<AppServices>().accountApi.updateProfile(
            nickname: _nicknameController.text.trim(),
            signature: _signatureController.text.trim(),
            avatar: _avatar,
          );
      if (!mounted) return;
      await context.read<AuthProvider>().updateUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资料已保存')));
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
        title: const Text('个人资料'),
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
                Center(
                  child: GestureDetector(
                    onTap: _uploading ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primarySoft,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _avatarUrl.isEmpty
                              ? const BrandLogo(size: 52, showName: false)
                              : ClipOval(
                                  child: Image.network(
                                    _avatarUrl,
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        const BrandLogo(size: 52, showName: false),
                                  ),
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                            child: _uploading
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '点击更换头像（jpg/png/webp，≤5MB）',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nicknameController,
                  label: '昵称',
                  hint: '请输入昵称',
                  maxLength: 20,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '昵称不能为空';
                    if (value.trim().runes.length > 20) return '昵称最多 20 个字符';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _signatureController,
                  label: '个性签名',
                  hint: '一句话介绍自己',
                  maxLines: 3,
                  maxLength: 60,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
                const SizedBox(height: 22),
                AppPrimaryButton(label: '保存资料', loading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
