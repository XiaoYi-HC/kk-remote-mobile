import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/automation.dart';
import '../../../data/models/device.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/mobile_page.dart';
import '../../../widgets/settings_widgets.dart';
import '../../auth/state/auth_provider.dart';

class ScheduledTasksPage extends StatefulWidget {
  const ScheduledTasksPage({super.key});

  @override
  State<ScheduledTasksPage> createState() => _ScheduledTasksPageState();
}

class _ScheduledTasksPageState extends State<ScheduledTasksPage> {
  List<ScheduledTask> _tasks = [];
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
        _error = '登录后可管理定时连接任务';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      _tasks = await services.automationApi.scheduledTasks();
      _devices = (await services.deviceApi.list()).devices;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({ScheduledTask? task}) async {
    final result = await showAppSheet<ScheduledTask>(
      context,
      title: task == null ? '添加定时任务' : '编辑定时任务',
      subtitle: '到点自动发起连接，适合定时值守巡检',
      heightFactor: 0.8,
      builder: (sheetContext) => _TaskForm(
        task: task,
        devices: _devices,
      ),
    );
    if (result == null) return;
    try {
      final api = context.read<AppServices>().automationApi;
      if (result.id == 0) {
        await api.createScheduledTask(result);
      } else {
        await api.updateScheduledTask(result);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('定时任务已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(ScheduledTask task) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除任务',
      content: '确定删除“${task.name}”定时任务？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await context.read<AppServices>().automationApi.deleteScheduledTask(task.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggle(ScheduledTask task, bool enabled) async {
    final updated = ScheduledTask(
      id: task.id,
      deviceId: task.deviceId,
      name: task.name,
      triggerAt: task.triggerAt,
      repeatRule: task.repeatRule,
      retry: task.retry,
      enabled: enabled,
      lastRunAt: task.lastRunAt,
      lastResult: task.lastResult,
    );
    try {
      await context.read<AppServices>().automationApi.updateScheduledTask(updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      title: '定时任务',
      actions: [
          IconButton(
            tooltip: '添加任务',
            onPressed: _error != null && _error!.contains('登录') ? null : () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 22),
          ),
        ],
      child: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(
                  icon: Icons.schedule_rounded,
                  title: '暂无定时任务',
                  description: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('重试')),
                )
              : _tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.schedule_rounded,
                      title: '还没有定时任务',
                      description: '设置触发时间、重复周期与目标设备，到点自动连接',
                      action: FilledButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('添加任务'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _tasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          final device = _deviceName(task.deviceId);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.alarm_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.name.isEmpty ? '未命名任务' : task.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$device · ${Formatters.date(task.triggerAt)} · ${AppConstants.repeatRuleNames[task.repeatRule] ?? task.repeatRule}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: task.enabled,
                                      onChanged: (value) => _toggle(task, value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (task.retry)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successSoft,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '失败重试',
                                          style: TextStyle(fontSize: 9, color: AppColors.success),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        task.lastRunAt == null
                                            ? '尚未执行'
                                            : '上次执行 ${Formatters.shortDate(task.lastRunAt)}：${task.lastResult.isEmpty ? '成功' : task.lastResult}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _openEditor(task: task),
                                      style: TextButton.styleFrom(minimumSize: const Size(44, 30)),
                                      child: const Text('编辑', style: TextStyle(fontSize: 11)),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(task),
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

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.task, required this.devices});

  final ScheduledTask? task;
  final List<Device> devices;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController _nameController;
  late DateTime _triggerAt;
  late int _deviceId;
  late String _repeatRule;
  late bool _retry;
  late bool _enabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '定时连接');
    _triggerAt = widget.task?.triggerAt ?? DateTime.now().add(const Duration(hours: 1));
    _deviceId = widget.task?.deviceId ??
        (widget.devices.isNotEmpty ? widget.devices.first.id : 0);
    _repeatRule = widget.task?.repeatRule ?? 'none';
    _retry = widget.task?.retry ?? true;
    _enabled = widget.task?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final firstDate = DateTime.now().subtract(const Duration(days: 1));
    final lastDate = DateTime.now().add(const Duration(days: 365));
    // 编辑旧任务时 _triggerAt 可能早于 firstDate，直接传会触发 DatePicker 断言崩溃。
    var initialDate = _triggerAt;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_triggerAt),
    );
    if (time == null) return;
    setState(() {
      _triggerAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_deviceId <= 0) {
      setState(() => _error = '请选择目标设备');
      return;
    }
    if (_repeatRule == 'none' && !_triggerAt.isAfter(DateTime.now())) {
      setState(() => _error = '触发时间需晚于当前时间');
      return;
    }
    Navigator.of(context).pop(
      ScheduledTask(
        id: widget.task?.id ?? 0,
        deviceId: _deviceId,
        name: _nameController.text.trim().isEmpty ? '定时连接' : _nameController.text.trim(),
        triggerAt: _triggerAt,
        repeatRule: _repeatRule,
        retry: _retry,
        enabled: _enabled,
        lastRunAt: widget.task?.lastRunAt,
        lastResult: widget.task?.lastResult ?? '',
      ),
    );
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
          AppTextField(
            controller: _nameController,
            label: '任务名称',
            hint: '例如：每日巡检',
            maxLength: 30,
          ),
          const SizedBox(height: 12),
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
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '触发时间',
                suffixIcon: Icon(Icons.event_rounded, size: 20),
              ),
              child: Text(Formatters.date(_triggerAt)),
            ),
          ),
          const SizedBox(height: 12),
          AppSelectField<String>(
            label: '重复周期',
            valueLabel: AppConstants.repeatRuleNames[_repeatRule] ?? _repeatRule,
            options: [
              for (final rule in AppConstants.repeatRules)
                AppSelectOption(
                  value: rule,
                  label: AppConstants.repeatRuleNames[rule] ?? rule,
                ),
            ],
            onChanged: (value) => setState(() => _repeatRule = value),
          ),
          const SizedBox(height: 6),
          SettingsGroup(
            padding: EdgeInsets.zero,
            children: [
              SettingsSwitchTile(
                title: '失败自动重试',
                subtitle: '连接失败后按重连间隔重试',
                value: _retry,
                onChanged: (value) => setState(() => _retry = value),
              ),
              SettingsSwitchTile(
                title: '启用任务',
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
          AppPrimaryButton(label: '保存任务', onPressed: _submit),
        ],
      ),
    );
  }
}
