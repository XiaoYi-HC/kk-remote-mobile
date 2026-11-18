import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/device.dart';
import '../../../data/models/session.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/settings_widgets.dart';
import '../state/connect_args.dart';
import '../state/devices_provider.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({super.key, required this.deviceId, this.device});

  final int deviceId;
  final Device? device;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  DeviceDetail? _detail;
  bool _loading = true;
  String? _error;

  Device? get _device => _detail?.device ?? widget.device;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<AppServices>().deviceApi.detail(widget.deviceId);
      _detail = detail;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _wakeOnLan() async {
    try {
      final result = await context.read<AppServices>().deviceApi.wakeOnLan(widget.deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['sent'] == true ? '已发送唤醒魔术包' : '唤醒请求已提交')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  bool _unbinding = false;

  Future<void> _unbind() async {
    if (_unbinding) return;
    final device = _device;
    if (device == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '解绑设备',
      content: '解绑后将移除备注、分组与收藏，是否继续？',
      confirmText: '解绑',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _unbinding = true);
    try {
      await context.read<DevicesProvider>().unbind(device);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _unbinding = false);
    }
  }

  Future<void> _addAccessRule() async {
    final ruleType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('新增访问规则'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('allow'),
            child: const Text('允许指定账号/设备接入'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('deny'),
            child: const Text('拒绝指定账号/设备接入'),
          ),
        ],
      ),
    );
    if (ruleType == null || !mounted) return;
    await showAppSheet<void>(
      context,
      title: ruleType == 'allow' ? '允许接入' : '拒绝接入',
      builder: (sheetContext) => _AccessRuleForm(
        ruleType: ruleType,
        onSubmit: (userId, deviceCode, remark) async {
          await context.read<AppServices>().deviceApi.createAccessRule(
                widget.deviceId,
                ruleType: ruleType,
                controllerUserId: userId,
                controllerDeviceCode: deviceCode,
                remark: remark,
              );
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          await _load();
        },
      ),
    );
  }

  Future<void> _deleteAccessRule(DeviceAccessRule rule) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除规则',
      content: '确定删除该访问规则？',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await context.read<AppServices>().deviceApi.deleteAccessRule(widget.deviceId, rule.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: Text(device?.displayName ?? '设备详情'),
        actions: [
          if (device != null)
            IconButton(
              tooltip: '解绑',
              onPressed: _unbind,
              icon: const Icon(Icons.link_off_rounded, size: 21),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _detail == null
            ? const LoadingView()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  if (device != null) _buildDeviceCard(device),
                  if (device != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: '远程连接',
                            icon: Icons.cast_connected_rounded,
                            onPressed: () => context.push(
                              '/connect',
                              extra: ConnectArgs(
                                deviceCode: device.deviceCode,
                                deviceName: device.displayName,
                                deviceId: device.id,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppSecondaryButton(
                            label: '离线指令',
                            icon: Icons.terminal_rounded,
                            onPressed: () => context.push(
                              '/settings/offline-commands?deviceId=${device.id}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SettingsSectionTitle('设备设置'),
                  _buildSettings(),
                  const SettingsSectionTitle('访问规则'),
                  _buildAccessRules(),
                  const SettingsSectionTitle('最近会话'),
                  _buildSessions(),
                  const SizedBox(height: 16),
                  if (device?.wolEnabled ?? false)
                    SettingsGroup(
                      children: [
                        SettingsTile(
                          title: '网络唤醒',
                          subtitle: '通过同网段在线设备发送魔术包',
                          leading: const IconBadge(icon: Icons.power_settings_new_rounded),
                          onTap: _wakeOnLan,
                          showDivider: false,
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.desktop_windows_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.displayName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: device.online ? AppColors.successSoft : AppColors.background,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        device.online ? '在线' : '离线',
                        style: TextStyle(
                          fontSize: 10,
                          color: device.online ? AppColors.success : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '识别码 ${device.deviceCode}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  '${device.platformLabel} ${device.osVersion} · NAT ${device.natType.isEmpty ? '未知' : device.natType}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    final settings = _detail?.settings ?? const {};
    final items = <MapEntry<String, dynamic>>[];
    if (settings.isEmpty) {
      items.add(const MapEntry('状态', '暂无设备端设置数据'));
    } else {
      items.addAll(settings.entries.take(8));
    }
    return SettingsGroup(
      children: items
          .map(
            (entry) => SettingsTile(
              title: _settingLabel(entry.key),
              subtitle: entry.value is Map || entry.value is List
                  ? '已配置'
                  : entry.value.toString(),
              showDivider: entry != items.last,
            ),
          )
          .toList(),
    );
  }

  String _settingLabel(String key) {
    const labels = {
      'resolution': '分辨率',
      'fps': '帧率',
      'encoder': '编码器',
      'audio': '音频采集',
      'quality': '画质预设',
      'clipboardSync': '剪贴板同步',
      'privacyDefault': '默认隐私黑屏',
      'captureDisplay': '采集显示器',
    };
    return labels[key] ?? key;
  }

  Widget _buildAccessRules() {
    final rules = _detail?.accessRules ?? const <DeviceAccessRule>[];
    return SettingsGroup(
      children: [
        if (rules.isEmpty)
          const SettingsTile(
            title: '暂无访问规则',
            subtitle: '默认允许持有验证码的主控连接',
            showDivider: false,
          ),
        ...rules.map(
          (rule) => SettingsTile(
            title: rule.ruleType == 'allow' ? '允许接入' : '拒绝接入',
            subtitle:
                '${rule.controllerDeviceCode.isNotEmpty ? '设备 ${rule.controllerDeviceCode}' : '账号 ${rule.controllerUserId}'}'
                '${rule.remark.isEmpty ? '' : ' · ${rule.remark}'}',
            leading: IconBadge(
              icon: rule.ruleType == 'allow' ? Icons.check_circle_outline : Icons.block_outlined,
            ),
            trailing: IconButton(
              onPressed: () => _deleteAccessRule(rule),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
            ),
            showDivider: rule != rules.last,
          ),
        ),
        SettingsTile(
          title: '新增访问规则',
          leading: const IconBadge(icon: Icons.add_rounded),
          onTap: _addAccessRule,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildSessions() {
    final sessions = _detail?.recentSessions ?? const <SessionRecord>[];
    if (sessions.isEmpty) {
      return const SettingsGroup(
        children: [
          SettingsTile(title: '暂无连接记录', showDivider: false),
        ],
      );
    }
    return SettingsGroup(
      children: sessions
          .map(
            (session) => SettingsTile(
              title: Formatters.date(session.startedAt),
              subtitle:
                  '${session.transport.isEmpty ? '未知传输' : session.transport.toUpperCase()} · ${Formatters.seconds(session.durationSec)} · RTT ${session.avgRttMs}ms',
              leading: const IconBadge(icon: Icons.history_rounded),
              showDivider: session != sessions.last,
            ),
          )
          .toList(),
    );
  }
}

class _AccessRuleForm extends StatefulWidget {
  const _AccessRuleForm({
    required this.ruleType,
    required this.onSubmit,
  });

  final String ruleType;
  final Future<void> Function(int userId, String deviceCode, String remark) onSubmit;

  @override
  State<_AccessRuleForm> createState() => _AccessRuleFormState();
}

class _AccessRuleFormState extends State<_AccessRuleForm> {
  final _userIdController = TextEditingController();
  final _deviceCodeController = TextEditingController();
  final _remarkController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _userIdController.dispose();
    _deviceCodeController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          AppTextField(
            controller: _userIdController,
            label: '主控账号 ID',
            hint: '与设备识别码二选一',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _deviceCodeController,
            label: '主控设备识别码',
            hint: '与账号 ID 二选一',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _remarkController,
            label: '备注',
            hint: '备注用途',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: '保存规则',
            loading: _saving,
            onPressed: () async {
              final userId = int.tryParse(_userIdController.text.trim()) ?? 0;
              final deviceCode = _deviceCodeController.text.trim();
              if (userId <= 0 && deviceCode.isEmpty) {
                setState(() => _error = '请填写账号 ID 或设备识别码');
                return;
              }
              setState(() {
                _saving = true;
                _error = null;
              });
              try {
                await widget.onSubmit(userId, deviceCode, _remarkController.text.trim());
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
          ],
        ),
      ),
    );
  }
}
