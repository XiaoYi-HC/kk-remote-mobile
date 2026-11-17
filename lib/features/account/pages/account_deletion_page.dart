import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _loading = false;
  String? _error;

  Future<void> _request() async {
    final ok = await showConfirmDialog(
      context,
      title: '申请注销账号',
      content: '注销后设备绑定、消息与设置将在冷静期结束后删除，且无法恢复。是否继续？',
      confirmText: '提交注销申请',
      danger: true,
    );
    if (!ok) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AppServices>().accountApi.requestDeletion();
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      final days = result['coolingDays']?.toString() ?? '7';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注销申请已提交，冷静期 $days 天内可撤销')),
      );
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: '撤销注销申请',
      content: '撤销后账号将恢复正常状态，是否继续？',
      confirmText: '撤销申请',
    );
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await context.read<AppServices>().accountApi.cancelDeletion();
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤销注销申请')));
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final requested = user?.deletionRequestedAt != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('注销账号'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: requested ? AppColors.warningSoft : AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: requested ? const Color(0x40F59E0B) : const Color(0x33E5484D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  requested ? Icons.hourglass_top_rounded : Icons.warning_amber_rounded,
                  color: requested ? AppColors.warning : AppColors.danger,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requested ? '注销申请处理中' : '注销账号不可恢复',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requested
                            ? '申请时间 ${Formatters.date(user?.deletionRequestedAt)}，预计 ${Formatters.date(user?.deletionEffectiveAt)} 生效。生效前可随时撤销。'
                            : '提交申请后将进入冷静期，期间可撤销。冷静期结束后账号数据将永久删除。',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SettingsSectionTitle('将被删除的内容'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeletionItem(text: '账号资料、头像与安全设置'),
                _DeletionItem(text: '设备绑定、分组、备注与收藏'),
                _DeletionItem(text: '连接历史、传输记录与站内消息'),
                _DeletionItem(text: '客服工单与在线会话记录'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
          if (requested)
            AppSecondaryButton(
              label: '撤销注销申请',
              loading: _loading,
              onPressed: _cancel,
            )
          else
            AppPrimaryButton(
              label: '申请注销账号',
              loading: _loading,
              onPressed: _request,
            ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              '注销后原手机号/邮箱可重新注册新账号，但原账号数据无法找回。如有未完成的工单，建议先处理完毕。',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletionItem extends StatelessWidget {
  const _DeletionItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline_rounded, size: 14, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
