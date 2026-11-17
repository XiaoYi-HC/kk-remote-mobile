import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';

class TouchSettingsPage extends StatelessWidget {
  const TouchSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final favorites = settings.hotkeyFavorites;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('触控与按键'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('操作模式'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'touch',
                  icon: Icon(Icons.touch_app_outlined, size: 18),
                  label: Text('触摸模式'),
                ),
                ButtonSegment(
                  value: 'trackpad',
                  icon: Icon(Icons.mouse_outlined, size: 18),
                  label: Text('触控板模式'),
                ),
              ],
              selected: {settings.touchMode},
              onSelectionChanged: (value) {
                settings.setString(SettingsKeys.touchMode, value.first);
                settings.setBool(SettingsKeys.trackballMode, value.first == 'trackpad');
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            ),
          ),
          if (settings.touchMode == 'trackpad')
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(
                '触控板模式：单指拖动相对移动指针，点按等于鼠标左键，长按等于右键。',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
              ),
            ),
          const SettingsSectionTitle('灵敏度'),
          _Slider(
            title: '触摸灵敏度',
            value: settings.touchSensitivity,
            min: 0.4,
            max: 2.5,
            divisions: 21,
            label: '${settings.touchSensitivity.toStringAsFixed(1)}x',
            onChanged: (value) => settings.setDouble(SettingsKeys.touchSensitivity, value),
          ),
          _Slider(
            title: '滚轮灵敏度',
            value: settings.scrollSensitivity,
            min: 0.5,
            max: 3,
            divisions: 25,
            label: '${settings.scrollSensitivity.toStringAsFixed(1)}x',
            onChanged: (value) => settings.setDouble(SettingsKeys.scrollSensitivity, value),
          ),
          _Slider(
            title: '双指缩放手势',
            value: settings.gestureSensitivity,
            min: 0.5,
            max: 2,
            divisions: 15,
            label: '${settings.gestureSensitivity.toStringAsFixed(1)}x',
            onChanged: (value) => settings.setDouble(SettingsKeys.gestureSensitivity, value),
          ),
          const SettingsSectionTitle('手势与反馈'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '轨迹球模式',
                subtitle: '屏幕上显示虚拟指针，点按确认位置',
                value: settings.trackballMode,
                onChanged: (value) => settings.setBool(SettingsKeys.trackballMode, value),
              ),
              SettingsSwitchTile(
                title: '三指手势',
                subtitle: '三指轻点快速展开/收起游戏按键面板',
                value: settings.threeFingerEnabled,
                onChanged: (value) => settings.setBool(SettingsKeys.threeFingerEnabled, value),
              ),
              SettingsSwitchTile(
                title: '按键震动反馈',
                subtitle: '点击、长按与按键操作时提供触感',
                value: settings.hapticsEnabled,
                onChanged: (value) => settings.setBool(SettingsKeys.hapticsEnabled, value),
              ),
              SettingsSwitchTile(
                title: '隐藏被控鼠标指针',
                subtitle: '观看模式下保持画面整洁',
                value: settings.hideCursor,
                onChanged: (value) => settings.setBool(SettingsKeys.hideCursor, value),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('设备同步'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '分组、备注与收藏云同步',
                subtitle: '关闭后仅保存在本机，不再同步到其他端',
                value: settings.cloudSync,
                onChanged: (value) => settings.setBool(SettingsKeys.cloudSync, value),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('常用快捷键收藏'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: favorites.isEmpty
                  ? const Text(
                      '在远程画面中长按虚拟键盘的快捷键即可收藏，收藏项会置顶显示。',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: favorites
                          .map(
                            (code) => InputChip(
                              label: Text(code),
                              onDeleted: () {
                                final next = List<String>.from(favorites)..remove(code);
                                settings.setList(SettingsKeys.hotkeyFavorites, next);
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          const SettingsSectionTitle('游戏按键与外设'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '虚拟按键布局管理',
                subtitle: '可拖拽布局、导入导出与二维码分享',
                leading: const IconBadge(icon: Icons.grid_view_rounded),
                onTap: () => context.push('/settings/gamepad'),
              ),
              SettingsTile(
                title: '陀螺仪与扳机键',
                subtitle: '手柄 L2/R2 映射，陀螺仪控制视角',
                leading: const IconBadge(icon: Icons.sports_esports_outlined),
                onTap: () => context.push('/settings/gamepad'),
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }
}
