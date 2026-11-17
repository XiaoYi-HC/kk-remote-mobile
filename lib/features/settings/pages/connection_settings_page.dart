import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';
import '../../remote/state/remote_session_provider.dart';

class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({super.key});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  String _network = '检测中…';

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_updateNetwork);
    _sub = Connectivity().onConnectivityChanged.listen(_updateNetwork);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _updateNetwork(List<ConnectivityResult> results) {
    if (!mounted) return;
    String label;
    if (results.contains(ConnectivityResult.wifi)) {
      label = 'WiFi';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      label = '有线网络';
    } else if (results.contains(ConnectivityResult.mobile)) {
      label = '移动网络';
    } else if (results.contains(ConnectivityResult.none)) {
      label = '无网络';
    } else {
      label = '未知网络';
    }
    setState(() => _network = label);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final active = RemoteSessionRegistry.instance.current;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('连接与网络'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsGroup(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              SettingsTile(
                title: '当前网络',
                subtitle: _network,
                leading: const IconBadge(icon: Icons.network_check_rounded),
              ),
              SettingsTile(
                title: '本次会话流量',
                subtitle: active == null
                    ? '当前没有进行中的会话'
                    : '${Formatters.bytes(active.trafficBytes)} · 已连接 ${Formatters.duration(active.elapsed)}',
                leading: const IconBadge(icon: Icons.data_usage_rounded),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('重连'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '断线自动重连',
                subtitle: '切后台、来电或网络切换后自动恢复会话',
                value: settings.autoReconnect,
                onChanged: (value) => settings.setBool(SettingsKeys.autoReconnect, value),
              ),
              SettingsTile(
                title: '重连间隔',
                subtitle: '与信令断开后等待多久重试',
                trailing: DropdownButton<int>(
                  value: settings.reconnectInterval.clamp(1, 15).toInt(),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 秒')),
                    DropdownMenuItem(value: 3, child: Text('3 秒')),
                    DropdownMenuItem(value: 5, child: Text('5 秒')),
                    DropdownMenuItem(value: 10, child: Text('10 秒')),
                  ],
                  onChanged: (value) {
                    if (value != null) settings.setInt(SettingsKeys.reconnectInterval, value);
                  },
                ),
                showDivider: false,
              ),
            ],
          ),
          const SettingsSectionTitle('流量与网络偏好'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '仅 WiFi 连接',
                subtitle: '移动网络下不主动发起远程连接',
                value: settings.onlyWifi,
                onChanged: (value) => settings.setBool(SettingsKeys.onlyWifi, value),
              ),
              SettingsSwitchTile(
                title: '流量节省模式',
                subtitle: '移动网络下自动降低码率与帧率',
                value: settings.saveDataMode,
                onChanged: (value) => settings.setBool(SettingsKeys.saveDataMode, value),
              ),
              SettingsSwitchTile(
                title: '网络类型提示',
                subtitle: '连接前提示当前处于移动网络',
                value: settings.networkHint,
                onChanged: (value) => settings.setBool(SettingsKeys.networkHint, value),
              ),
              SettingsTile(
                title: '流量消耗提醒',
                subtitle: '单次会话达到阈值后提醒',
                trailing: DropdownButton<int>(
                  value: settings.trafficReminderMb,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 100, child: Text('100 MB')),
                    DropdownMenuItem(value: 300, child: Text('300 MB')),
                    DropdownMenuItem(value: 500, child: Text('500 MB')),
                    DropdownMenuItem(value: 1024, child: Text('1 GB')),
                  ],
                  onChanged: (value) {
                    if (value != null) settings.setInt(SettingsKeys.trafficReminderMb, value);
                  },
                ),
              ),
              SettingsSwitchTile(
                title: 'P2P 优先',
                subtitle: '优先建立点对点直连，降低延迟',
                value: settings.p2pPreferred,
                onChanged: (value) => settings.setBool(SettingsKeys.p2pPreferred, value),
              ),
              SettingsSwitchTile(
                title: '允许中继',
                subtitle: 'P2P 失败时通过 TURN 中继，可能产生服务器流量',
                value: settings.allowRelay,
                onChanged: (value) => settings.setBool(SettingsKeys.allowRelay, value),
              ),
            ],
          ),
          const SettingsSectionTitle('弱网策略'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '弱网自适应',
                subtitle: '网络变差自动下调，恢复后自动回升',
                value: settings.lowBandwidthAdaptive,
                onChanged: (value) => settings.setBool(SettingsKeys.lowBandwidthAdaptive, value),
              ),
              _NumberSlider(
                title: '最低码率下限',
                value: settings.minBitrate.toDouble(),
                min: 100,
                max: 1500,
                divisions: 14,
                label: '${settings.minBitrate} Kbps',
                onChanged: (value) => settings.setInt(SettingsKeys.minBitrate, value.round()),
              ),
              _NumberSlider(
                title: '恢复阈值',
                value: settings.restoreThreshold.toDouble(),
                min: 300,
                max: 4000,
                divisions: 37,
                label: '${settings.restoreThreshold} Kbps',
                onChanged: (value) =>
                    settings.setInt(SettingsKeys.restoreThreshold, value.round()),
              ),
            ],
          ),
          const SettingsSectionTitle('诊断'),
          SettingsGroup(
            children: [
              SettingsTile(
                title: '网络诊断',
                subtitle: '检测 NAT 类型、信令延迟与 TURN 节点',
                leading: const IconBadge(icon: Icons.monitor_heart_outlined),
                onTap: () => context.push('/settings/diagnostics'),
                showDivider: false,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              '在移动网络下进行远程控制会消耗较多流量。建议优先使用 WiFi，并根据网络质量调整画质。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }
}
