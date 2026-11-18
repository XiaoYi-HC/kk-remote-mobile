import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_text_field.dart';
import '../../auth/state/auth_provider.dart';
import '../../remote/state/remote_args.dart';
import '../state/connect_args.dart';
import '../state/devices_provider.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, this.args = const ConnectArgs()});

  final ConnectArgs args;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  final _credentialController = TextEditingController();
  bool _usePassword = false;
  bool _saveDevice = true;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.args.deviceCode);
    _saveDevice = widget.args.showBindOption;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  Future<bool> _isMobileNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);
  }

  Future<bool> _confirmMobileNetwork() async {
    final settings = context.read<SettingsProvider>();
    if (!await _isMobileNetwork()) return true;
    if (settings.onlyWifi) {
      if (!mounted) return false;
      final goSettings = await showConfirmDialog(
        context,
        title: '当前为移动网络',
        content: '已开启“仅 WiFi 连接”，将不会发起远程连接。可关闭该限制后继续。',
        confirmText: '关闭限制并连接',
        cancelText: '取消',
      );
      if (goSettings) {
        await settings.setBool(SettingsKeys.onlyWifi, false);
        return true;
      }
      return false;
    }
    if (!settings.networkHint) return true;
    if (!mounted) return false;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移动流量提醒'),
        content: Text(
          '当前使用移动网络，远程画面将持续消耗流量。'
          '${settings.saveDataMode ? '已开启流量节省，将自动降低码率。' : '可在设置中开启仅 WiFi 连接或流量节省。'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('wifi'),
            child: const Text('仅 WiFi 连接'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('continue'),
            child: const Text('继续连接'),
          ),
        ],
      ),
    );
    if (action == 'wifi') {
      await settings.setBool(SettingsKeys.onlyWifi, true);
      return false;
    }
    return action == 'continue';
  }

  Future<void> _connect() async {
    if (_connecting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final devices = context.read<DevicesProvider>();
    if (!await _confirmMobileNetwork()) return;
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    final deviceCode = _codeController.text.trim();
    final credential = _credentialController.text.trim();
    var deviceName = widget.args.deviceName;
    var deviceId = widget.args.deviceId;
    try {
      if (auth.isLoggedIn && _saveDevice) {
        try {
          final device = await devices.bindDevice(
            deviceCode: deviceCode,
            verifyCode: _usePassword ? null : credential,
            password: _usePassword ? credential : null,
          );
          deviceId = device.id;
          deviceName = device.displayName;
        } catch (bindError) {
          // 绑定失败不阻断临时连接，但验证码错误仍直接提示。
          final message = bindError.toString();
          if (message.contains('验证码') || message.contains('密码错误')) rethrow;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('设备绑定失败：$message，将继续临时连接')),
            );
          }
        }
      }
      if (!mounted) return;
      final args = RemoteArgs(
        deviceCode: deviceCode,
        deviceName: deviceName,
        deviceId: deviceId,
        verifyCode: _usePassword ? '' : credential,
        password: _usePassword ? credential : '',
        isLan: widget.args.isLan,
        lanIp: widget.args.lanIp,
        castMode: widget.args.castMode,
        guest: auth.isGuest,
      );
      context.pushReplacement('/remote', extra: args);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('连接设备'),
        actions: [
          IconButton(
            tooltip: '帮助',
            onPressed: () => context.push('/help'),
            icon: const Icon(Icons.help_outline_rounded, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.args.deviceName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD6E6FF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.computer_rounded, color: AppColors.primary, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.args.deviceName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.args.isLan
                                        ? '局域网直连 · ${widget.args.lanIp}'
                                        : '识别码 ${widget.args.deviceCode}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.args.isLan)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.successSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '内网',
                                  style: TextStyle(fontSize: 10, color: AppColors.success),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _codeController,
                            label: '设备识别码',
                            hint: '请输入被控电脑上的识别码',
                            prefixIcon: Icons.pin_outlined,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(16),
                            ],
                            validator: Validators.deviceCode,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text(
                                '连接凭证',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              _CredentialToggle(
                                usePassword: _usePassword,
                                onChanged: (value) {
                                  setState(() {
                                    _usePassword = value;
                                    _credentialController.clear();
                                    _error = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: _credentialController,
                            hint: _usePassword ? '请输入无人值守密码' : '请输入 6 位验证码',
                            prefixIcon: _usePassword ? Icons.lock_outline_rounded : Icons.shield_outlined,
                            keyboardType: _usePassword ? TextInputType.text : TextInputType.number,
                            obscure: _usePassword,
                            allowToggleObscure: _usePassword,
                            textInputAction: TextInputAction.done,
                            inputFormatters: _usePassword
                                ? null
                                : [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                            validator: (value) => _usePassword
                                ? Validators.required(value, '无人值守密码')
                                : Validators.code(value),
                            onSubmitted: (_) => _connect(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  '验证码由被控端显示，5 分钟内有效',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/help'),
                                style: TextButton.styleFrom(minimumSize: const Size(44, 28)),
                                child: const Text('找不到验证码？', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          if (auth.isLoggedIn && widget.args.showBindOption) ...[
                            const Divider(),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _saveDevice,
                              onChanged: (value) => setState(() => _saveDevice = value),
                              title: const Text(
                                '连接后保存到我的设备',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text(
                                '保存后可查看设备在线状态与连接历史',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: settings.onlyWifi,
                            onChanged: (value) async {
                              await context
                                  .read<SettingsProvider>()
                                  .setBool(SettingsKeys.onlyWifi, value);
                            },
                            title: const Text('仅 WiFi 连接', style: TextStyle(fontSize: 14)),
                            subtitle: const Text(
                              '移动网络下不主动发起远程连接，避免流量消耗',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Icon(
                                Icons.data_usage_rounded,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '本次会话流量提醒阈值 ${settings.trafficReminderMb}MB',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: settings.networkHint,
                                onChanged: (value) async {
                                  await context
                                      .read<SettingsProvider>()
                                      .setBool(SettingsKeys.networkHint, value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    AppPrimaryButton(
                      label: widget.args.castMode ? '开始投屏连接' : '连接',
                      icon: widget.args.castMode ? Icons.screen_share_rounded : Icons.link_rounded,
                      loading: _connecting,
                      onPressed: _connect,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '连接即代表同意《用户协议》与《隐私政策》，${AppConstants.productName}仅传输加密的音视频与控制指令。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CredentialToggle extends StatelessWidget {
  const _CredentialToggle({required this.usePassword, required this.onChanged});

  final bool usePassword;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('验证码')),
        ButtonSegment(value: true, label: Text('密码')),
      ],
      selected: {usePassword},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        minimumSize: const WidgetStatePropertyAll(Size(56, 32)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11)),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
    );
  }
}
