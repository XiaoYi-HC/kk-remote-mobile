import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/user.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';

class LoginDevicesPage extends StatefulWidget {
  const LoginDevicesPage({super.key});

  @override
  State<LoginDevicesPage> createState() => _LoginDevicesPageState();
}

class _LoginDevicesPageState extends State<LoginDevicesPage> {
  List<LoginDevice> _devices = [];
  bool _loading = true;
  String? _error;

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
      _devices = await context.read<AppServices>().accountApi.loginDevices();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kick(LoginDevice device) async {
    final ok = await showConfirmDialog(
      context,
      title: '强制下线',
      content: '将强制 ${device.deviceName} 退出登录，该设备需要重新登录才能继续使用。',
      confirmText: '强制下线',
      danger: true,
    );
    if (!ok) return;
    try {
      await context.read<AppServices>().accountApi.kickLoginDevice(device.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('登录设备管理'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(
                  icon: Icons.devices_other_rounded,
                  title: '暂时无法读取登录设备',
                  description: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('重试')),
                )
              : _devices.isEmpty
                  ? const EmptyState(
                      icon: Icons.devices_other_rounded,
                      title: '暂无其他登录设备',
                      description: '当前账号只在当前设备登录',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _devices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: device.current ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: device.current
                                        ? AppColors.primarySoft
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _icon(device.deviceType),
                                    size: 21,
                                    color: device.current
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              device.deviceName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (device.current) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Text(
                                                '当前设备',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${device.os} · ${device.ip}${device.region.isEmpty ? '' : ' · ${device.region}'}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '最近活跃 ${Formatters.relative(device.lastSeenAt)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!device.current)
                                  TextButton(
                                    onPressed: () => _kick(device),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(52, 34),
                                      foregroundColor: AppColors.danger,
                                    ),
                                    child: const Text('下线', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
      case 'mobile':
        return Icons.smartphone_rounded;
      case 'desktop':
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'tablet':
        return Icons.tablet_mac_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }
}
