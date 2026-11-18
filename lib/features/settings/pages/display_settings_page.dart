import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/mobile_page.dart';
import '../../../widgets/settings_widgets.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MobilePage(
      title: '画质与显示',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('默认画质'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(AppConstants.qualityPresets.length, (index) {
                final value = AppConstants.qualityPresetValues[index];
                return ChoiceChip(
                  label: Text(AppConstants.qualityPresets[index]),
                  selected: settings.qualityPreset == value,
                  onSelected: (_) => settings.setString(SettingsKeys.qualityPreset, value),
                );
              }),
            ),
          ),
          _SliderTile(
            title: '分辨率缩放',
            value: settings.resolutionScale,
            min: 0.4,
            max: 1,
            divisions: 6,
            label: '${(settings.resolutionScale * 100).round()}%',
            onChanged: (value) => settings.setDouble(SettingsKeys.resolutionScale, value),
          ),
          _SliderTile(
            title: '帧率上限',
            value: settings.fpsLimit.toDouble(),
            min: 30,
            max: 120,
            divisions: 3,
            label: '${settings.fpsLimit} FPS',
            onChanged: (value) {
              final options = [30.0, 60.0, 90.0, 120.0];
              final nearest = options.reduce(
                (a, b) => (a - value).abs() < (b - value).abs() ? a : b,
              );
              settings.setInt(SettingsKeys.fpsLimit, nearest.round());
            },
          ),
          _SliderTile(
            title: '码率上限',
            value: settings.bitrateLimit.toDouble(),
            min: 0,
            max: 16000,
            divisions: 32,
            label: settings.bitrateLimit <= 0 ? '自动' : '${settings.bitrateLimit} Kbps',
            onChanged: (value) => settings.setInt(SettingsKeys.bitrateLimit, value.round()),
          ),
          SettingsGroup(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              SettingsTile(
                title: '编码器',
                subtitle: _encoderLabel(settings.encoder),
                trailing: AppSelectValue(
                  valueLabel: _encoderShortLabel(settings.encoder),
                  onTap: () async {
                    final value = await showAppPicker<String>(
                      context,
                      title: '编码器',
                      selected: settings.encoder,
                      options: const [
                        AppSelectOption(value: 'auto', label: '自动', subtitle: '根据设备能力自动选择'),
                        AppSelectOption(value: 'h264', label: 'H.264', subtitle: '兼容性优先'),
                        AppSelectOption(value: 'hevc', label: 'HEVC', subtitle: '更高压缩率，需双方支持'),
                        AppSelectOption(value: 'vp9', label: 'VP9', subtitle: '开源编码'),
                        AppSelectOption(value: 'av1', label: 'AV1', subtitle: '高压缩率，编码开销较高'),
                      ],
                    );
                    if (value != null) {
                      await settings.setString(SettingsKeys.encoder, value);
                    }
                  },
                ),
              ),
              SettingsSwitchTile(
                title: '自适应降低画质',
                subtitle: '弱网时优先保障流畅度',
                value: settings.adaptiveQuality,
                onChanged: (value) => settings.setBool(SettingsKeys.adaptiveQuality, value),
              ),
              SettingsSwitchTile(
                title: '远程时屏幕常亮',
                subtitle: '避免操作过程中手机自动锁屏',
                value: settings.keepScreenOn,
                onChanged: (value) => settings.setBool(SettingsKeys.keepScreenOn, value),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('字体与界面'),
          _SliderTile(
            title: '字体大小',
            value: settings.fontScale,
            min: 0.85,
            max: 1.4,
            divisions: 11,
            label: '${(settings.fontScale * 100).round()}%',
            onChanged: (value) => settings.setDouble(SettingsKeys.fontScale, value),
          ),
          _SliderTile(
            title: '界面缩放',
            value: settings.uiScale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            label: '${(settings.uiScale * 100).round()}%',
            onChanged: (value) => settings.setDouble(SettingsKeys.uiScale, value),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '效果预览',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(settings.effectiveTextScale),
                    ),
                    child: const Text(
                      '远程桌面操作更清晰，设备识别码与连接记录一目了然。',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SettingsSectionTitle('屏幕方向'),
          SettingsGroup(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Builder(
                builder: (context) {
                  // 旧版本工具栏写入过 'locked'，统一按自动处理，避免选择器没有选中项。
                  final orientation = settings.orientationLock == 'locked'
                      ? 'auto'
                      : settings.orientationLock;
                  return SettingsTile(
                title: '远程画面方向',
                subtitle: orientation == 'auto'
                    ? '跟随手机自动旋转'
                    : (orientation == 'portrait' ? '锁定竖屏' : '锁定横屏'),
                trailing: AppSelectValue(
                  valueLabel: orientation == 'auto'
                      ? '自动'
                      : (orientation == 'portrait' ? '竖屏' : '横屏'),
                  onTap: () async {
                    final value = await showAppPicker<String>(
                      context,
                      title: '远程画面方向',
                      selected: orientation,
                      options: const [
                        AppSelectOption(value: 'auto', label: '自动', subtitle: '跟随手机自动旋转'),
                        AppSelectOption(value: 'portrait', label: '竖屏', subtitle: '锁定竖屏方向'),
                        AppSelectOption(value: 'landscape', label: '横屏', subtitle: '锁定横屏方向'),
                      ],
                    );
                    if (value == null) return;
                    await settings.setString(SettingsKeys.orientationLock, value);
                    if (value == 'auto') {
                      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
                    } else if (value == 'portrait') {
                      await SystemChrome.setPreferredOrientations(
                        const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
                      );
                    } else {
                      await SystemChrome.setPreferredOrientations(
                        const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
                      );
                    }
                  },
                ),
                showDivider: false,
              );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _encoderShortLabel(String value) {
    switch (value) {
      case 'h264':
        return 'H.264';
      case 'hevc':
        return 'HEVC';
      case 'vp9':
        return 'VP9';
      case 'av1':
        return 'AV1';
      default:
        return '自动';
    }
  }

  String _encoderLabel(String value) {
    switch (value) {
      case 'h264':
        return '兼容性优先';
      case 'hevc':
        return '更高压缩率，需双方支持';
      case 'vp9':
        return '开源编码';
      case 'av1':
        return '高压缩率，编码开销较高';
      default:
        return '根据设备能力自动选择';
    }
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
