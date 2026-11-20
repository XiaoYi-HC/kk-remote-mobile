import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/mobile_page.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  Future<void> _requestSystemPermission(BuildContext context) async {
    final services = context.read<AppServices>();
    final granted = await services.notifications.requestPermission();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? '通知权限已开启' : '通知权限未开启，请前往系统设置中允许')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MobilePage(
      title: '通知与后台',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('通知'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '系统通知',
                subtitle: '客服回复、设备离线与公告提醒',
                value: settings.notificationEnabled,
                onChanged: (value) async {
                  if (value) {
                    final services = context.read<AppServices>();
                    final granted = await services.notifications.requestPermission();
                    if (!context.mounted) return;
                    if (!granted) {
                      // 系统权限被拒绝时回滚开关，避免显示“已开启”但收不到通知。
                      await settings.setBool(SettingsKeys.notificationEnabled, false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('系统通知权限未开启'),
                          action: SnackBarAction(
                            label: '去设置',
                            onPressed: openAppSettings,
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  await settings.setBool(SettingsKeys.notificationEnabled, value);
                },
              ),
              SettingsSwitchTile(
                title: '连接请求推送',
                subtitle: '被控发起呼叫时像来电一样提醒，可一键接听或拒绝',
                value: settings.incomingCallPush,
                onChanged: (value) async {
                  await settings.setBool(SettingsKeys.incomingCallPush, value);
                  if (value) await _requestSystemPermission(context);
                },
              ),
              FutureBuilder<PermissionStatus>(
                future: Permission.notification.status,
                builder: (context, snapshot) {
                  final granted = snapshot.data?.isGranted ?? true;
                  if (granted) return const SizedBox.shrink();
                  return SettingsTile(
                    title: '系统通知权限未开启',
                    subtitle: '点击前往系统设置允许 KK远程 发送通知',
                    leading: const IconBadge(icon: Icons.notifications_off_outlined),
                    onTap: openAppSettings,
                  );
                },
              ),
              SettingsTile(
                title: '站内消息中心',
                subtitle: '公告、客服回复、设备离线告警',
                leading: const IconBadge(icon: Icons.mark_email_unread_outlined),
                onTap: () => context.push('/account/messages'),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('后台保活'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '后台保活',
                subtitle: '切到后台或来电后尽量保持会话，返回时快速恢复画面',
                value: settings.backgroundKeepAlive,
                onChanged: (value) => settings.setBool(SettingsKeys.backgroundKeepAlive, value),
              ),
              if (Platform.isAndroid)
                SettingsTile(
                  title: '电池优化白名单',
                  subtitle: '将 KK远程 加入系统电池优化白名单，减少后台被清理',
                  leading: const IconBadge(icon: Icons.battery_saver_outlined),
                  onTap: () async {
                    final status = await Permission.ignoreBatteryOptimizations.request();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(status.isGranted ? '已加入电池优化白名单' : '未获得电池优化豁免权限')),
                    );
                  },
                ),
              if (Platform.isAndroid)
                SettingsTile(
                  title: '悬浮窗权限',
                  subtitle: '用于画中画小窗在后台继续查看远程画面',
                  leading: const IconBadge(icon: Icons.picture_in_picture_alt_rounded),
                  onTap: () async {
                    final status = await Permission.systemAlertWindow.request();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(status.isGranted ? '悬浮窗权限已开启' : '请前往系统设置允许悬浮窗')),
                    );
                  },
                  showDivider: false,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x40F59E0B)),
              ),
              child: const Text(
                'iOS 后台无法持续采集画面，切到后台后会暂停远程画面，返回前台时自动重连。Android 建议开启前台服务与通知权限以保持会话稳定。',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
