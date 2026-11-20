import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/brand_logo.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/mobile_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = AppConstants.appVersion;
  String _currentVersion = AppConstants.appVersion;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _currentVersion = info.version;
        _version = '${info.version} (${info.buildNumber})';
      });
    });
  }

  int _compareVersion(String a, String b) {
    List<int> parse(String value) {
      return value
          .split('+')
          .first
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final left = parse(a);
    final right = parse(b);
    for (var i = 0; i < 3; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final data = asMap(await context.read<AppServices>().api.get(
            '/client/versions/latest',
            query: {'platform': platform, 'version': _currentVersion},
          ));
      if (!mounted) return;
      if (data.isEmpty) {
        await showInfoDialog(context, title: '检查更新', content: '当前已是最新版本。');
        return;
      }
      final version = asString(data['version']);
      final changelog = asString(data['changelog']);
      final downloadUrl = asString(data['downloadUrl']);
      final force = asBool(data['forceUpdate']);
      if (version.isEmpty || _compareVersion(version, _currentVersion) <= 0) {
        await showInfoDialog(context, title: '检查更新', content: '当前已是最新版本。');
        return;
      }
      if (!mounted) return;
      final update = await showConfirmDialog(
        context,
        title: force ? '发现强制更新' : '发现新版本 $version',
        content: changelog.isEmpty ? '建议更新到最新版本以获得更好的体验。' : changelog,
        confirmText: '立即更新',
        cancelText: '稍后',
      );
      if (update && downloadUrl.isNotEmpty) {
        await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检查更新失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showProtocol(String type) async {
    await context.push('/settings/protocol/$type');
  }

  Future<void> _copyOfficialSite() async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.officialSite));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('官网地址已复制')),
    );
  }

  Future<void> _openOfficialSite() async {
    final ok = await launchUrl(
      Uri.parse(AppConstants.officialSite),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器，请复制官网地址后手动访问')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      title: '关于',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 12),
          const Center(child: BrandLogo(size: 84, subtitle: '安全、流畅的跨端远程控制')),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '版本 $_version',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '检查更新',
                subtitle: _checking ? '正在检查…' : '获取最新版本与更新说明',
                leading: const IconBadge(icon: Icons.system_update_alt_rounded),
                trailing: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _checking ? null : _checkUpdate,
              ),
              SettingsTile(
                title: '官方网站',
                subtitle: AppConstants.officialSite,
                leading: const IconBadge(icon: Icons.public_rounded),
                trailing: IconButton(
                  tooltip: '复制官网地址',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: _copyOfficialSite,
                ),
                onTap: _openOfficialSite,
              ),
              SettingsTile(
                title: '用户协议',
                leading: const IconBadge(icon: Icons.description_outlined),
                onTap: () => _showProtocol('user'),
              ),
              SettingsTile(
                title: '隐私政策',
                leading: const IconBadge(icon: Icons.privacy_tip_outlined),
                onTap: () => _showProtocol('privacy'),
              ),
              SettingsTile(
                title: '儿童隐私政策',
                leading: const IconBadge(icon: Icons.child_care_outlined),
                onTap: () => _showProtocol('children'),
              ),
              SettingsTile(
                title: '第三方服务共享清单',
                leading: const IconBadge(icon: Icons.handshake_outlined),
                onTap: () => _showProtocol('third_party'),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© 2026 KK远程 · 保留所有权利',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ),

        ],
      ),
    );
  }
}
