import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/platform/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';
import '../../../widgets/mobile_page.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  Future<void> _toggleAppLock(BuildContext context, bool value) async {
    final settings = context.read<SettingsProvider>();
    if (!value) {
      final ok = await showConfirmDialog(
        context,
        title: '关闭应用锁',
        content: '关闭后打开 KK远程 将不再验证指纹/面容或系统密码。',
        confirmText: '关闭',
        danger: true,
      );
      if (!ok) return;
      await settings.setBool(SettingsKeys.appLockEnabled, false);
      return;
    }
    final authenticated = await AppLockService.instance.authenticate(
      reason: '验证身份以开启 KK远程 应用锁',
    );
    if (!context.mounted) return;
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证未通过，无法开启应用锁')),
      );
      return;
    }
    await settings.setBool(SettingsKeys.appLockEnabled, true);
    settings.unlockedThisSession = true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final canUseBiometrics = AppLockService.instance.canUseBiometrics();
    return MobilePage(
      title: '安全与隐私',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('本地安全'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '应用锁',
                subtitle: '打开 App 时验证指纹、面容或系统密码',
                value: settings.appLockEnabled,
                onChanged: (value) => _toggleAppLock(context, value),
              ),
              if (settings.appLockEnabled)
                FutureBuilder<bool>(
                  future: canUseBiometrics,
                  builder: (context, snapshot) {
                    return SettingsSwitchTile(
                      title: '优先使用生物识别',
                      subtitle: snapshot.data == true
                          ? '支持指纹/面容识别'
                          : '当前设备未检测到生物识别，将回退为系统密码',
                      value: settings.biometricEnabled,
                      onChanged: (value) {
                        if (snapshot.data == true) {
                          settings.setBool(SettingsKeys.biometricEnabled, value);
                        }
                      },
                    );
                  },
                ),
              SettingsSwitchTile(
                title: '剪贴板同步',
                subtitle: '手机与电脑之间自动同步复制的文字',
                value: settings.clipboardSync,
                onChanged: (value) => settings.setBool(SettingsKeys.clipboardSync, value),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('账号安全'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '两步验证（2FA）',
                subtitle: auth.isLoggedIn
                    ? (auth.user?.totpEnabled == true ? '已开启' : '未开启')
                    : '登录后可开启',
                leading: const IconBadge(icon: Icons.verified_user_outlined),
                onTap: () {
                  if (auth.isLoggedIn) {
                    context.push('/account/2fa');
                  } else {
                    context.go('/login');
                  }
                },
              ),
              SettingsTile(
                title: '登录设备管理',
                subtitle: '查看已登录设备并强制下线',
                leading: const IconBadge(icon: Icons.devices_other_rounded),
                onTap: () {
                  if (auth.isLoggedIn) {
                    context.push('/account/login-devices');
                  } else {
                    context.go('/login');
                  }
                },
              ),
              SettingsTile(
                title: '站内消息中心',
                subtitle: '客服回复、离线告警与系统公告',
                leading: const IconBadge(icon: Icons.mark_email_unread_outlined),
                onTap: () => context.push('/account/messages'),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('隐私说明'),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Text(
              'KK远程默认端到端加密传输音视频与控制指令。隐私黑屏开启后，被控电脑本地屏幕将变黑，仅主控端可见画面。应用锁与剪贴板同步只保存在本机设置中，不会上传到服务器。',
              style: TextStyle(fontSize: 11, height: 1.7, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
