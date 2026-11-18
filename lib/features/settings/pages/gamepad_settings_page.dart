import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/virtual_layout.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/mobile_page.dart';

class GamepadSettingsPage extends StatefulWidget {
  const GamepadSettingsPage({super.key});

  @override
  State<GamepadSettingsPage> createState() => _GamepadSettingsPageState();
}

class _GamepadSettingsPageState extends State<GamepadSettingsPage> {
  static const _layoutKey = 'gamepad_layout_current';
  static const _gyroKey = 'gamepad_gyro_enabled';
  static const _gyroSensitivityKey = 'gamepad_gyro_sensitivity';
  static const _l2Key = 'gamepad_l2_action';
  static const _r2Key = 'gamepad_r2_action';

  VirtualKeyLayout _layout = VirtualKeyLayout.defaultShooter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      final map = settings.getMapOverride(_layoutKey);
      if (map.isNotEmpty) {
        try {
          final layout = VirtualKeyLayout.fromJson(map);
          if (layout.buttons.isNotEmpty) setState(() => _layout = layout);
        } catch (_) {}
      }
    });
  }

  Future<void> _save(VirtualKeyLayout layout) async {
    setState(() => _layout = layout);
    await context.read<SettingsProvider>().setMapValue(_layoutKey, layout.toJson());
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final layout = VirtualKeyLayout.fromJson(asMap(jsonDecode(await File(path).readAsString())));
      if (layout.buttons.isEmpty) throw Exception('布局文件没有按键');
      await _save(layout.copyWith(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        builtin: false,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入 ${layout.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _export() async {
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File(p.join(
        dir.path,
        'KK远程按键布局_${DateTime.now().millisecondsSinceEpoch}.json',
      ));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(_layout.toJson()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出：${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _showQr() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('分享按键布局'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: jsonEncode(_layout.toJson()),
                version: QrVersions.auto,
                size: 230,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_layout.name} · ${_layout.buttons.length} 个按键',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExternalDevices() async {
    final services = context.read<AppServices>();
    final devices = await services.native.listGamepads();
    if (!mounted) return;
    await showInfoDialog(
      context,
      title: '外接手柄与键鼠',
      content: devices.isEmpty
          ? '未检测到已连接的手柄或蓝牙键鼠。可通过系统蓝牙设置连接后重试。'
          : devices
              .map((item) => '• ${item['name'] ?? '输入设备'}（${item['type'] ?? 'gamepad'}）')
              .join('\n'),
    );
  }

  Future<void> _editTrigger(String key, String title, String current) async {
    final value = await showTextInputDialog(
      context,
      title: title,
      hint: '例如：KeyQ 或 mouseLeft',
      initialValue: current,
      maxLength: 40,
    );
    if (value == null) return;
    await context.read<SettingsProvider>().setString(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final gyro = settings.getBool(_gyroKey);
    final gyroSensitivity = settings.getDouble(_gyroSensitivityKey, fallback: 1.0);
    final l2 = settings.getString(_l2Key);
    final r2 = settings.getString(_r2Key);
    return MobilePage(
      title: '游戏手柄与虚拟按键',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('当前虚拟按键布局'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 17, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _layout.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_layout.buttons.length} 个按键',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.videoBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: _layout.buttons.map((button) {
                              return Positioned(
                                left: button.x * constraints.maxWidth,
                                top: button.y * constraints.maxHeight,
                                width: button.width * constraints.maxWidth,
                                height: button.height * constraints.maxHeight,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(120),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text(
                                        button.label,
                                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _save(VirtualKeyLayout.defaultShooter()),
                        icon: const Icon(Icons.videogame_asset_outlined, size: 16),
                        label: const Text('默认射击', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _save(VirtualKeyLayout.defaultRacing()),
                        icon: const Icon(Icons.directions_car_outlined, size: 16),
                        label: const Text('默认竞速', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.file_open_outlined, size: 16),
                        label: const Text('导入', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('导出', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showQr,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                        label: const Text('二维码', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '在远程会话工具栏打开“游戏按键”即可拖拽摆放、添加或修改按键；调整后会自动保存。',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SettingsSectionTitle('外接设备'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '检测手柄与蓝牙键鼠',
                subtitle: '外接设备输入优先于触屏',
                leading: const IconBadge(icon: Icons.usb_rounded),
                onTap: _showExternalDevices,
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('陀螺仪与扳机键'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '陀螺仪映射视角',
                subtitle: '使用手机陀螺仪控制远程视角',
                value: gyro,
                onChanged: (value) =>
                    context.read<SettingsProvider>().setBool(_gyroKey, value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('陀螺仪灵敏度', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          gyroSensitivity.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Slider(
                      value: gyroSensitivity,
                      min: 0.3,
                      max: 2.5,
                      divisions: 22,
                      onChanged: gyro
                          ? (value) => context
                              .read<SettingsProvider>()
                              .setDouble(_gyroSensitivityKey, value)
                          : null,
                    ),
                  ],
                ),
              ),
              SettingsTile(
                title: 'L2 扳机映射',
                subtitle: l2.isEmpty ? '未配置（默认鼠标右键）' : l2,
                leading: const IconBadge(icon: Icons.gamepad_outlined),
                onTap: () => _editTrigger(_l2Key, 'L2 扳机映射', l2),
              ),
              SettingsTile(
                title: 'R2 扳机映射',
                subtitle: r2.isEmpty ? '未配置（默认鼠标左键）' : r2,
                leading: const IconBadge(icon: Icons.gamepad_outlined),
                onTap: () => _editTrigger(_r2Key, 'R2 扳机映射', r2),
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
