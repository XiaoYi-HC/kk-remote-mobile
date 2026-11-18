import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/mobile_page.dart';

class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  late final TextEditingController _apiController;
  late final TextEditingController _signalingController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiController = TextEditingController(text: settings.apiBaseUrlOverride);
    _signalingController = TextEditingController(text: settings.signalingUrlOverride);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _signalingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = _apiController.text.trim();
    final signaling = _signalingController.text.trim();
    if (api.isNotEmpty) {
      final uri = Uri.tryParse(api);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
        setState(() => _error = 'API BaseURL 必须是 http(s)://host/path 格式');
        return;
      }
    }
    if (signaling.isNotEmpty) {
      final uri = Uri.tryParse(signaling);
      if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss') || uri.host.isEmpty) {
        setState(() => _error = '信令地址必须是 ws(s)://host/ws/signaling 格式');
        return;
      }
    }
    final settings = context.read<SettingsProvider>();
    await settings.setString(SettingsKeys.apiOverride, api);
    await settings.setString(SettingsKeys.signalingOverride, signaling);
    await context.read<AppServices>().reinitializeApi();
    await context.read<ConfigProvider>().refresh();
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开发环境地址已更新，后续请求将使用新地址')),
    );
  }

  Future<void> _reset() async {
    final settings = context.read<SettingsProvider>();
    await settings.remove(SettingsKeys.apiOverride);
    await settings.remove(SettingsKeys.signalingOverride);
    _apiController.clear();
    _signalingController.clear();
    await context.read<AppServices>().reinitializeApi();
    await context.read<ConfigProvider>().refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复为后台下发的服务地址')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = context.watch<ConfigProvider>();
    return MobilePage(
      title: '开发者选项',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x40F59E0B)),
            ),
            child: const Text(
              '此处地址仅用于开发调试。留空时使用 /client/config/bootstrap 下发的 apiBaseUrl 与 signalingUrl。',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _apiController,
            label: 'API BaseURL 覆盖',
            hint: 'https://api.example.com/api/v1',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 6),
          Text(
            '后台下发：${settings.serverApiBaseUrl.isEmpty ? '未获取' : settings.serverApiBaseUrl}',
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _signalingController,
            label: '信令 WebSocket 覆盖',
            hint: 'wss://signal.example.com/ws/signaling',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 6),
          Text(
            '后台下发：${settings.serverSignalingUrl.isEmpty ? '未获取' : settings.serverSignalingUrl}',
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          AppPrimaryButton(label: '保存并应用', icon: Icons.check_rounded, onPressed: _save),
          const SizedBox(height: 10),
          AppSecondaryButton(label: '恢复默认地址', onPressed: _reset),
          const SettingsSectionTitle('当前生效配置'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: 'API',
                subtitle: settings.resolvedApiBaseUrl,
                leading: const IconBadge(icon: Icons.api_rounded),
              ),
              SettingsTile(
                title: '信令',
                subtitle: settings.resolvedSignalingUrl,
                leading: const IconBadge(icon: Icons.cable_rounded),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '配置加载状态：${config.isLoading ? '加载中' : (config.loadedOnce ? '已加载' : '未加载')}'
            '${config.error == null ? '' : ' · ${config.error}'}',
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            '版本 ${AppConstants.appVersion} · 平台 ${AppConstants.applicationId}',
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
