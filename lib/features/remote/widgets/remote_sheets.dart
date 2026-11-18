import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/remote.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/settings_widgets.dart';

class QualitySheet extends StatefulWidget {
  const QualitySheet({
    super.key,
    required this.onApply,
  });

  final void Function({
    required String preset,
    required int fps,
    required int bitrateKbps,
    required double resolutionScale,
    required String encoder,
  }) onApply;

  @override
  State<QualitySheet> createState() => _QualitySheetState();
}

class _QualitySheetState extends State<QualitySheet> {
  late String _preset;
  late int _fps;
  late int _bitrate;
  late double _scale;
  late String _encoder;
  late bool _adaptive;

  static const _fpsOptions = [30, 60, 90, 120];
  static const _encoderOptions = {
    'auto': '自动选择',
    'h264': 'H.264',
    'hevc': 'HEVC',
    'vp9': 'VP9',
    'av1': 'AV1',
  };

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _preset = settings.qualityPreset;
    _fps = settings.fpsLimit;
    _bitrate = settings.bitrateLimit;
    _scale = settings.resolutionScale;
    _encoder = settings.encoder;
    _adaptive = settings.adaptiveQuality;
  }

  void _selectPreset(String preset) {
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'smooth':
          _fps = 30;
          _bitrate = 800;
          _scale = 0.5;
          break;
        case 'balanced':
          _fps = 60;
          _bitrate = 2000;
          _scale = 0.75;
          break;
        case 'hd':
          _fps = 60;
          _bitrate = 4000;
          _scale = 1;
          break;
        case 'game':
          _fps = 120;
          _bitrate = 8000;
          _scale = 1;
          break;
      }
    });
  }

  Future<void> _apply() async {
    final settings = context.read<SettingsProvider>();
    await settings.setString(SettingsKeys.qualityPreset, _preset);
    await settings.setInt(SettingsKeys.fpsLimit, _fps);
    await settings.setInt(SettingsKeys.bitrateLimit, _bitrate);
    await settings.setDouble(SettingsKeys.resolutionScale, _scale);
    await settings.setString(SettingsKeys.encoder, _encoder);
    await settings.setBool(SettingsKeys.adaptiveQuality, _adaptive);
    widget.onApply(
      preset: _preset,
      fps: _fps,
      bitrateKbps: _bitrate,
      resolutionScale: _scale,
      encoder: _encoder,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '画质预设',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(AppConstants.qualityPresets.length, (index) {
              final preset = AppConstants.qualityPresetValues[index];
              return ChoiceChip(
                label: Text(AppConstants.qualityPresets[index]),
                selected: _preset == preset,
                onSelected: (_) => _selectPreset(preset),
              );
            }),
          ),
          const SizedBox(height: 18),
          _labelRow('分辨率缩放', '${(_scale * 100).round()}%'),
          Slider(
            value: _scale,
            min: 0.4,
            max: 1,
            divisions: 6,
            label: '${(_scale * 100).round()}%',
            onChanged: (value) => setState(() => _scale = value),
          ),
          _labelRow('帧率上限', '$_fps FPS'),
          Wrap(
            spacing: 8,
            children: _fpsOptions
                .map((fps) => ChoiceChip(
                      label: Text('$fps FPS'),
                      selected: _fps == fps,
                      onSelected: (_) => setState(() => _fps = fps),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          _labelRow('码率上限', _bitrate <= 0 ? '自动' : '$_bitrate Kbps'),
          Slider(
            value: _bitrate <= 0 ? 0 : _bitrate.toDouble(),
            min: 0,
            max: 16000,
            divisions: 32,
            label: _bitrate <= 0 ? '自动' : '${_bitrate}Kbps',
            onChanged: (value) => setState(() => _bitrate = value.round()),
          ),
          const SizedBox(height: 8),
          AppSelectField<String>(
            label: '编码器',
            valueLabel: _encoderOptions[_encoder] ?? '自动',
            options: [
              for (final entry in _encoderOptions.entries)
                AppSelectOption(value: entry.key, label: entry.value),
            ],
            onChanged: (value) => setState(() => _encoder = value),
          ),
          const SizedBox(height: 10),
          SettingsSwitchTile(
            title: '弱网自适应',
            subtitle: '网络变差时自动降低码率与帧率',
            value: _adaptive,
            onChanged: (value) => setState(() => _adaptive = value),
            showDivider: false,
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(label: '应用画质', onPressed: _apply),
        ],
      ),
    );
  }

  Widget _labelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        ],
      ),
    );
  }
}

Future<void> showQualitySheet(
  BuildContext context, {
  required void Function({
    required String preset,
    required int fps,
    required int bitrateKbps,
    required double resolutionScale,
    required String encoder,
  }) onApply,
}) {
  return showAppSheet<void>(
    context,
    title: '画质与显示',
    subtitle: '实时生效，弱网下将自动调整',
    heightFactor: 0.82,
    builder: (sheetContext) => QualitySheet(onApply: onApply),
  );
}

class DisplaySwitchSheet extends StatelessWidget {
  const DisplaySwitchSheet({
    super.key,
    required this.displays,
    required this.activeId,
    required this.onSelect,
  });

  final List<DisplayInfo> displays;
  final String activeId;
  final ValueChanged<DisplayInfo> onSelect;

  @override
  Widget build(BuildContext context) {
    if (displays.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '被控端未上报显示器信息，暂无法切换。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: displays
          .map(
            (display) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  onSelect(display);
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: display.id == activeId ? AppColors.primarySoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: display.id == activeId ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.desktop_windows_rounded, color: Colors.white54, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  display.label,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                if (display.primary) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '主屏',
                                      style: TextStyle(fontSize: 9, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              display.resolutionLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (display.id == activeId)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

Future<void> showDisplaySwitchSheet(
  BuildContext context, {
  required List<DisplayInfo> displays,
  required String activeId,
  required ValueChanged<DisplayInfo> onSelect,
}) {
  return showAppSheet<void>(
    context,
    title: '切换显示器',
    subtitle: '切换不会中断当前会话',
    heightFactor: 0.55,
    builder: (sheetContext) => DisplaySwitchSheet(
      displays: displays,
      activeId: activeId,
      onSelect: onSelect,
    ),
  );
}

Future<void> showSystemActionsSheet(
  BuildContext context, {
  required ValueChanged<String> onAction,
}) {
  return showAppSheet<void>(
    context,
    title: '系统操作',
    subtitle: '以下操作将在被控电脑上执行',
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      children: [
        SheetActionTile(
          icon: Icons.lock_outline_rounded,
          title: '锁定屏幕',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onAction('lock');
          },
        ),
        SheetActionTile(
          icon: Icons.restart_alt_rounded,
          title: '重启电脑',
          subtitle: '需要二次确认',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            final ok = await showConfirmDialog(
              context,
              title: '重启电脑',
              content: '确定要远程重启被控电脑吗？未保存的内容可能丢失。',
              confirmText: '确认重启',
              danger: true,
            );
            if (ok) onAction('restart');
          },
        ),
        SheetActionTile(
          icon: Icons.power_settings_new_rounded,
          title: '关机',
          subtitle: '需要二次确认',
          danger: true,
          onTap: () async {
            Navigator.of(sheetContext).pop();
            final ok = await showConfirmDialog(
              context,
              title: '关闭电脑',
              content: '确定要远程关闭被控电脑吗？关闭后将断开连接。',
              confirmText: '确认关机',
              danger: true,
            );
            if (ok) onAction('shutdown');
          },
        ),
        SheetActionTile(
          icon: Icons.logout_rounded,
          title: '注销当前用户',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onAction('logoff');
          },
        ),
        const Divider(),
        SheetActionTile(
          icon: Icons.lock_person_outlined,
          title: '锁定远程输入',
          subtitle: '禁止本次会话继续发送键鼠事件',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onAction('lock_input');
          },
        ),
      ],
    ),
  );
}

Future<void> showCameraSheet(
  BuildContext context, {
  required bool enabled,
  required VoidCallback onToggle,
}) {
  return showAppSheet<void>(
    context,
    title: '远程摄像头',
    subtitle: '按需查看被控电脑摄像头画面',
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  enabled ? Icons.videocam_rounded : Icons.videocam_off_outlined,
                  size: 34,
                  color: enabled ? AppColors.success : AppColors.textTertiary,
                ),
                const SizedBox(height: 8),
                Text(
                  enabled ? '摄像头预览已开启' : '摄像头预览未开启',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '预览画面会作为独立视频轨传输，可能增加带宽占用。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppPrimaryButton(
            label: enabled ? '关闭摄像头预览' : '开启摄像头预览',
            onPressed: () {
              onToggle();
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    ),
  );
}
