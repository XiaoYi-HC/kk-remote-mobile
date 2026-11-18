import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';
import '../../../widgets/mobile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    return MobilePage(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            onTap: () {
              if (auth.isLoggedIn) {
                context.push('/account');
              } else {
                context.go('/login');
              }
            },
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    auth.displayName.characters.first,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        auth.isLoggedIn
                            ? '${Formatters.maskedAccount(auth.user?.phone)} · 已登录'
                            : '登录后同步设备、消息与设置',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
          const SettingsSectionTitle('显示与操控'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '画质与显示',
                subtitle: '${_qualityLabel(settings.qualityPreset)} · ${settings.fpsLimit}FPS',
                leading: const IconBadge(icon: Icons.tune_rounded),
                onTap: () => context.push('/settings/display'),
              ),
              SettingsTile(
                title: '音频',
                subtitle: settings.audioEnabled ? '远程声音已开启' : '远程声音已关闭',
                leading: const IconBadge(icon: Icons.volume_up_outlined),
                onTap: () => context.push('/settings/audio'),
              ),
              SettingsTile(
                title: '触控与按键',
                subtitle: '灵敏度、触控板模式、快捷键收藏、游戏按键',
                leading: const IconBadge(icon: Icons.touch_app_outlined),
                onTap: () => context.push('/settings/touch'),
              ),
              SettingsTile(
                title: '游戏手柄与虚拟按键',
                subtitle: '布局导入导出、陀螺仪与扳机键',
                leading: const IconBadge(icon: Icons.sports_esports_outlined),
                onTap: () => context.push('/settings/gamepad'),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('连接与提醒'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '连接与网络',
                subtitle: settings.onlyWifi ? '仅 WiFi 连接已开启' : '允许移动网络连接',
                leading: const IconBadge(icon: Icons.lan_outlined),
                onTap: () => context.push('/settings/connection'),
              ),
              SettingsTile(
                title: '网络诊断',
                subtitle: 'NAT 类型、信令延迟、TURN 可用性',
                leading: const IconBadge(icon: Icons.monitor_heart_outlined),
                onTap: () => context.push('/settings/diagnostics'),
              ),
              SettingsTile(
                title: '通知与后台',
                subtitle: settings.notificationEnabled ? '已开启通知与后台保活' : '通知已关闭',
                leading: const IconBadge(icon: Icons.notifications_active_outlined),
                onTap: () => context.push('/settings/notifications'),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('自动化与文件'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '定时任务',
                subtitle: '按设定时间自动发起连接',
                leading: const IconBadge(icon: Icons.schedule_rounded),
                onTap: () => context.push('/settings/scheduled-tasks'),
              ),
              SettingsTile(
                title: '离线指令',
                subtitle: '设备上线后自动执行预设指令',
                leading: const IconBadge(icon: Icons.terminal_rounded),
                onTap: () => context.push('/settings/offline-commands'),
              ),
              SettingsTile(
                title: '文件与下载',
                subtitle: '下载目录、传输记录与缓存清理',
                leading: const IconBadge(icon: Icons.folder_outlined),
                onTap: () => context.push('/settings/files'),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('账号与安全'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '安全与隐私',
                subtitle: settings.appLockEnabled ? '应用锁已开启' : '应用锁未开启',
                leading: const IconBadge(icon: Icons.security_rounded),
                onTap: () => context.push('/settings/security'),
              ),
              SettingsTile(
                title: auth.isLoggedIn ? '账号中心' : '登录或注册',
                subtitle: auth.isLoggedIn ? '资料、密码、换绑、2FA、登录设备' : '登录后可管理账号安全',
                leading: const IconBadge(icon: Icons.person_outline_rounded),
                onTap: () {
                  if (auth.isLoggedIn) {
                    context.push('/account');
                  } else {
                    context.go('/login');
                  }
                },
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('帮助与关于'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '帮助与反馈',
                subtitle: '常见问题、在线客服、留言工单',
                leading: const IconBadge(icon: Icons.support_agent_rounded),
                onTap: () => context.push('/help'),
              ),
              SettingsTile(
                title: '语言与地区',
                subtitle: _languageLabel(settings.language),
                leading: const IconBadge(icon: Icons.language_rounded),
                onTap: () => context.push('/settings/language'),
              ),
              SettingsTile(
                title: '无障碍引导',
                subtitle: '读屏适配说明与字体缩放',
                leading: const IconBadge(icon: Icons.accessibility_new_rounded),
                onTap: () => context.push('/settings/accessibility'),
              ),
              SettingsTile(
                title: '关于 ${AppConstants.productName}',
                subtitle: '版本 ${AppConstants.appVersion}',
                leading: const IconBadge(icon: Icons.info_outline_rounded),
                onTap: () => context.push('/settings/about'),
              ),
              SettingsTile(
                title: '开发者选项',
                subtitle: settings.apiBaseUrlOverride.isEmpty
                    ? '使用后台下发的服务地址'
                    : '已覆盖开发环境地址',
                leading: const IconBadge(icon: Icons.developer_mode_rounded),
                onTap: () => context.push('/settings/developer'),
                showDivider: false,
              ),
            ],
          ),
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: '退出登录',
                  content: '退出后需要重新登录才能同步设备与消息，是否继续？',
                  confirmText: '退出登录',
                  danger: true,
                );
                if (!ok) return;
                await auth.logout();
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: Color(0x33E5484D)),
              ),
              child: const Text('退出登录'),
            ),
          ],
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'KK远程 · 安全、流畅的跨端远程控制',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  String _qualityLabel(String preset) {
    final index = AppConstants.qualityPresetValues.indexOf(preset);
    if (index < 0) return '高清';
    return AppConstants.qualityPresets[index];
  }

  String _languageLabel(String lang) {
    const labels = {
      'zh-CN': '简体中文',
      'zh-TW': '繁體中文',
      'en-US': 'English',
      'ja-JP': '日本語',
      'ko-KR': '한국어',
    };
    return labels[lang] ?? lang;
  }
}
