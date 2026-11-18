import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/automation.dart';
import '../../../data/models/device.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/mobile_page.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';

class OfflineCommandsPage extends StatefulWidget {
  const OfflineCommandsPage({super.key, this.deviceId = 0});

  final int deviceId;

  @override
  State<OfflineCommandsPage> createState() => _OfflineCommandsPageState();
}

class _OfflineCommandsPageState extends State<OfflineCommandsPage> {
  List<OfflineCommand> _commands = [];
  List<Device> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      setState(() {
        _loading = false;
        _error = '登录后可管理离线指令';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      _commands = await services.automationApi.offlineCommands();
      _devices = (await services.deviceApi.list()).devices;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCommand() async {
    final result = await showAppSheet<Map<String, dynamic>>(
      context,
      title: '添加离线指令',
      subtitle: '设备上线接入后自动执行',
      heightFactor: 0.75,
      builder: (sheetContext) => _CommandForm(
        devices: _devices,
        initialDeviceId: widget.deviceId,
      ),
    );
    if (result == null) return;
    try {
      await context.read<AppServices>().automationApi.createOfflineCommand(
            deviceId: result['deviceId'] as int,
            command: result['command'] as String,
            enabled: result['enabled'] as bool,
          );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('离线指令已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(OfflineCommand command) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除指令',
      content: '确定删除该离线指令？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await context.read<AppServices>().automationApi.deleteOfflineCommand(command.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showResults(OfflineCommand command) async {
    await showAppSheet<void>(
      context,
      title: '执行记录',
      subtitle: command.command,
      heightFactor: 0.65,
      builder: (sheetContext) => FutureBuilder<List<OfflineCommandResult>>(
        future: context.read<AppServices>().automationApi.offlineCommandResults(command.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: '读取执行记录…');
          }
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: '暂无执行记录',
              description: '设备上线并执行指令后会在这里显示结果',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final result = list[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.success ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 16,
                          color: result.success ? AppColors.success : AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          result.success ? '执行成功' : '执行失败',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: result.success ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.date(result.executedAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    if (result.output.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.output,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                    if (result.error.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.error,
                        style: const TextStyle(fontSize: 11, color: AppColors.danger, height: 1.5),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      title: '离线指令',
      actions: [
          IconButton(
            tooltip: '添加指令',
            onPressed: _error != null && _error!.contains('登录') ? null : _addCommand,
            icon: const Icon(Icons.add_rounded, size: 22),
          ),
        ],
      child: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(
                  icon: Icons.terminal_rounded,
                  title: '离线指令不可用',
                  description: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('重试')),
                )
              : _commands.isEmpty
                  ? EmptyState(
                      icon: Icons.terminal_rounded,
                      title: '还没有离线指令',
                      description: '为设备添加预设指令，设备下次上线接入后自动执行',
                      action: FilledButton.icon(
                        onPressed: _addCommand,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('添加指令'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _commands.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final command = _commands[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.terminal_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _deviceName(command.deviceId),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: command.enabled
                                            ? AppColors.successSoft
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        command.enabled ? '已启用' : '已停用',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: command.enabled
                                              ? AppColors.success
                                              : AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  command.command,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    fontFamily: 'monospace',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        command.lastRunAt == null
                                            ? '尚未执行'
                                            : '上次执行 ${Formatters.shortDate(command.lastRunAt)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showResults(command),
                                      style: TextButton.styleFrom(minimumSize: const Size(44, 30)),
                                      child: const Text('执行记录', style: TextStyle(fontSize: 11)),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(command),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(44, 30),
                                        foregroundColor: AppColors.danger,
                                      ),
                                      child: const Text('删除', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _deviceName(int id) {
    for (final device in _devices) {
      if (device.id == id) return device.displayName;
    }
    return '设备 #$id';
  }
}

class _CommandForm extends StatefulWidget {
  const _CommandForm({required this.devices, required this.initialDeviceId});

  final List<Device> devices;
  final int initialDeviceId;

  @override
  State<_CommandForm> createState() => _CommandFormState();
}

class _CommandFormState extends State<_CommandForm> {
  final TextEditingController _commandController = TextEditingController();
  late int _deviceId;
  bool _enabled = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deviceId = widget.initialDeviceId > 0
        ? widget.initialDeviceId
        : (widget.devices.isNotEmpty ? widget.devices.first.id : 0);
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelectField<int>(
            label: '目标设备',
            hint: '请选择目标设备',
            valueLabel: () {
              for (final device in widget.devices) {
                if (device.id == _deviceId) {
                  return '${device.displayName}（${device.deviceCode}）';
                }
              }
              return '';
            }(),
            options: [
              for (final device in widget.devices)
                AppSelectOption(
                  value: device.id,
                  label: device.displayName,
                  subtitle: device.deviceCode,
                ),
            ],
            onChanged: (value) => setState(() => _deviceId = value),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _commandController,
            label: '指令内容',
            hint: '例如：shutdown /l  或  start notepad.exe',
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: 4),
          SettingsGroup(
            padding: EdgeInsets.zero,
            children: [
              SettingsSwitchTile(
                title: '启用指令',
                subtitle: '设备上线接入成功后自动执行',
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                showDivider: false,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: '保存指令',
            onPressed: () {
              final command = _commandController.text.trim();
              if (_deviceId <= 0) {
                setState(() => _error = '请选择目标设备');
                return;
              }
              if (command.isEmpty) {
                setState(() => _error = '请输入指令内容');
                return;
              }
              Navigator.of(context).pop({
                'deviceId': _deviceId,
                'command': command,
                'enabled': _enabled,
              });
            },
          ),
        ],
      ),
    );
  }
}
