import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/remote.dart';
import '../../../widgets/app_sheet.dart';

/// 画面左上角 P2P/中继状态标签，颜色随传输方式平滑过渡。
class TransportBadge extends StatelessWidget {
  const TransportBadge({
    super.key,
    required this.transport,
    required this.connected,
    required this.onTap,
  });

  final TransportInfo transport;
  final bool connected;
  final VoidCallback onTap;

  Color get _color {
    if (!connected) return AppColors.connecting;
    if (transport.isP2p) return AppColors.p2p;
    if (transport.isRelay) return AppColors.relay;
    return AppColors.connecting;
  }

  String get _label {
    if (!connected) return '连接中';
    if (transport.isP2p) return 'P2P';
    if (transport.isRelay) return '中继';
    return '连接中';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '传输方式 $_label，延迟 ${transport.rttMs} 毫秒，点击查看连接详情',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _color.withAlpha(170), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  color: _color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                child: Text(_label),
              ),
              const SizedBox(width: 6),
              Text(
                Formatters.latency(transport.rttMs),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransportDetailSheet extends StatelessWidget {
  const TransportDetailSheet({super.key, required this.transport, required this.connected});

  final TransportInfo transport;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('传输方式', connected ? (transport.isRelay ? 'TURN 中继' : (transport.isP2p ? 'P2P 直连' : '协商中')) : '正在协商'),
      ('候选类型', transport.candidateType.isEmpty ? '--' : transport.candidateType),
      ('RTT 延迟', Formatters.latency(transport.rttMs)),
      ('丢包率', Formatters.percent(transport.lossRate)),
      ('码率', Formatters.bitrate(transport.bitrateKbps.toDouble())),
      ('帧率', transport.fps <= 0 ? '--' : '${transport.fps} FPS'),
      ('上行 / 下行', '${Formatters.bitrate(transport.upBw.toDouble())} / ${Formatters.bitrate(transport.downBw.toDouble())}'),
      ('远端地址', transport.remoteAddress.isEmpty ? '--' : transport.remoteAddress),
      ('连接状态', transport.connectionState.isEmpty ? '--' : transport.connectionState),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (transport.isRelay ? AppColors.relay : AppColors.p2p).withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  transport.isRelay ? Icons.cloud_queue_rounded : Icons.bolt_rounded,
                  color: transport.isRelay ? AppColors.relay : AppColors.p2p,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? (transport.isRelay ? '通过中继节点传输' : 'P2P 直连传输')
                          : '正在建立连接',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transport.isRelay
                          ? '中继会增加少量延迟，但可穿透严格 NAT 与防火墙'
                          : '端到端加密，媒体流不经过服务器转发',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(rows.length, (index) {
                final row = rows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        row.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

Future<void> showTransportDetails(
  BuildContext context, {
  required TransportInfo transport,
  required bool connected,
}) {
  return showAppSheet<void>(
    context,
    title: '连接详情',
    subtitle: '实时指标每秒刷新',
    builder: (sheetContext) => TransportDetailSheet(
      transport: transport,
      connected: connected,
    ),
  );
}
