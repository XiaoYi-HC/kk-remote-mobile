import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/automation.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/mobile_page.dart';

class NetworkDiagnosticsPage extends StatefulWidget {
  const NetworkDiagnosticsPage({super.key});

  @override
  State<NetworkDiagnosticsPage> createState() => _NetworkDiagnosticsPageState();
}

class _NetworkDiagnosticsPageState extends State<NetworkDiagnosticsPage> {
  bool _running = false;
  String _stage = '';
  String? _error;
  String _network = '检测中…';
  Map<String, dynamic> _report = const {};
  List<String> _candidates = const [];

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _network = _labelFor(results));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  String _labelFor(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.ethernet)) return '有线网络';
    if (results.contains(ConnectivityResult.mobile)) return '移动网络';
    if (results.contains(ConnectivityResult.none)) return '无网络';
    return '未知网络';
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
      _report = const {};
      _candidates = const [];
      _stage = '获取诊断参数…';
    });
    final services = context.read<AppServices>();
    try {
      final config = await services.automationApi.networkDiagnosticsConfig();
      if (!mounted) return;
      setState(() => _stage = '测试信令延迟…');
      final signalingLatency = await _measureSignaling(config);
      if (!mounted) return;
      setState(() => _stage = '探测 NAT 与 ICE 候选…');
      final ice = await _probeIce(config);
      final network = _labelFor(await Connectivity().checkConnectivity());
      final natType = _inferNatType(ice.types);
      final report = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'network': network,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'osVersion': Platform.operatingSystemVersion,
        'appVersion': AppConstants.appVersion,
        'apiBaseUrl': services.api.baseUrl,
        'signalingUrl': config.signalingUrl.isEmpty
            ? services.settings.resolvedSignalingUrl
            : config.signalingUrl,
        'signalingLatencyMs': signalingLatency,
        'natType': natType,
        'candidateTypes': ice.types,
        'candidates': ice.candidates,
        'turnNodes': config.iceServers.where((item) {
          final urls = item['urls'];
          return urls is List && urls.any((url) => url.toString().startsWith('turn'));
        }).length,
        'iceServers': config.iceServers.length,
        'turnTtlSeconds': config.turnTtlSeconds,
        'packetLoss': null,
      };
      if (!mounted) return;
      setState(() {
        _network = network;
        _report = report;
        _candidates = ice.candidates;
        _stage = '检测完成';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<int?> _measureSignaling(NetworkDiagnosticsConfig config) async {
    final services = context.read<AppServices>();
    final rawUrl = config.signalingUrl.isEmpty
        ? services.settings.resolvedSignalingUrl
        : config.signalingUrl;
    try {
      final base = Uri.parse(rawUrl);
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'role': 'controller',
        'token': services.api.token ?? '',
        'platform': Platform.isIOS ? 'ios' : 'android',
        'version': AppConstants.appVersion,
      });
      final stopwatch = Stopwatch()..start();
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 6));
      stopwatch.stop();
      await channel.sink.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Future<_IceProbeResult> _probeIce(NetworkDiagnosticsConfig config) async {
    final candidates = <String>[];
    RTCPeerConnection? pc;
    try {
      pc = await createPeerConnection({
        'iceServers': config.iceServers,
        'sdpSemantics': 'unified-plan',
      });
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          candidates.add(candidate.candidate!);
        }
      };
      await pc.createDataChannel('diagnostics', RTCDataChannelInit());
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline) && candidates.length < 12) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final types = <String>{};
      for (final candidate in candidates) {
        final match = RegExp(r' typ (\w+)').firstMatch(candidate);
        if (match != null) types.add(match.group(1)!);
      }
      return _IceProbeResult(
        candidates: candidates,
        types: types.toList(),
      );
    } catch (_) {
      return const _IceProbeResult(candidates: [], types: []);
    } finally {
      try {
        await pc?.close();
      } catch (_) {}
    }
  }

  String _inferNatType(List<String> types) {
    if (types.isEmpty) return '探测失败';
    if (types.contains('relay') && !types.contains('srflx')) return '严格 NAT（需要中继）';
    if (types.contains('srflx')) return '锥型 NAT（支持 P2P）';
    if (types.contains('host')) return '仅本地候选（局域网）';
    return types.join(' / ');
  }

  Future<void> _copyReport() async {
    final text = const JsonEncoder.withIndent('  ').convert(_report);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('诊断报告已复制')));
  }

  Future<void> _uploadReport() async {
    try {
      final path = await context.read<AppServices>().automationApi.reportDiagnostics(_report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path.isEmpty ? '诊断报告已提交' : '诊断报告已上传：$path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latency = _report['signalingLatencyMs'];
    final natType = _report['natType']?.toString() ?? '--';
    return MobilePage(
      title: '网络诊断',
      actions: [
          IconButton(
            tooltip: '复制报告',
            onPressed: _report.isEmpty ? null : _copyReport,
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (_error == null ? AppColors.success : AppColors.danger).withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _error == null ? Icons.monitor_heart_rounded : Icons.error_outline_rounded,
                    color: _error == null ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _running ? _stage : (_error == null ? '诊断完成' : '诊断失败'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _error ?? '网络：$_network · NAT：$natType',
                        style: TextStyle(
                          fontSize: 11,
                          color: _error == null ? AppColors.textSecondary : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_running)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (_running)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新检测'),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _MetricCard(label: '网络类型', value: _network, icon: Icons.wifi_rounded),
              _MetricCard(
                label: '信令延迟',
                value: latency == null ? '--' : '$latency ms',
                icon: Icons.speed_rounded,
              ),
              _MetricCard(label: 'NAT 类型', value: natType, icon: Icons.router_outlined),
              _MetricCard(
                label: '丢包率',
                value: _report['packetLoss'] == null ? '未测得' : Formatters.percent(0),
                icon: Icons.network_ping_rounded,
              ),
              _MetricCard(
                label: 'ICE 候选',
                value: _candidates.length.toString(),
                icon: Icons.swap_calls_rounded,
              ),
              _MetricCard(
                label: 'TURN 节点',
                value: (_report['turnNodes'] ?? '--').toString(),
                icon: Icons.cloud_queue_rounded,
              ),
            ],
          ),
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'ICE 候选',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _candidates
                    .map(
                      (candidate) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          candidate.length > 120 ? '${candidate.substring(0, 120)}…' : candidate,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.4,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: '重新检测',
            loading: _running,
            icon: Icons.refresh_rounded,
            onPressed: _run,
          ),
          const SizedBox(height: 10),
          AppSecondaryButton(
            label: '上传诊断报告给客服',
            icon: Icons.cloud_upload_outlined,
            onPressed: _report.isEmpty ? null : _uploadReport,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              '诊断报告包含网络类型、NAT 类型、ICE 候选与设备版本，不包含账号密码或远程画面内容。',
              style: TextStyle(fontSize: 10, height: 1.6, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _IceProbeResult {
  const _IceProbeResult({required this.candidates, required this.types});

  final List<String> candidates;
  final List<String> types;
}
