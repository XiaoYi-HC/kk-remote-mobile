import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// 远程画面悬浮指示器：网络类型、延迟与本次会话流量。
class RemoteIndicator extends StatelessWidget {
  const RemoteIndicator({
    super.key,
    required this.latencyMs,
    required this.lossRate,
    required this.trafficBytes,
    required this.networkType,
    this.onTap,
  });

  final int latencyMs;
  final double lossRate;
  final int trafficBytes;
  final String networkType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final color = _qualityColor;
    return Semantics(
      button: onTap != null,
      label: '延迟 $latencyMs 毫秒，$networkType，本次流量 ${Formatters.bytes(trafficBytes)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                networkType == '移动网络' ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(3, (index) {
                  return Container(
                    width: 2,
                    height: 4.0 + index * 3,
                    margin: const EdgeInsets.only(right: 1.5),
                    decoration: BoxDecoration(
                      color: index < bars ? color : Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 5),
              Text(
                Formatters.latency(latencyMs),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 5),
              Text(
                Formatters.bytes(trafficBytes),
                style: const TextStyle(color: Colors.white60, fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _bars {
    if (latencyMs <= 0) return 1;
    if (lossRate > 0.08 || latencyMs > 250) return 1;
    if (lossRate > 0.03 || latencyMs > 120) return 2;
    return 3;
  }

  Color get _qualityColor {
    if (latencyMs <= 0) return AppColors.connecting;
    if (lossRate > 0.08 || latencyMs > 250) return AppColors.danger;
    if (lossRate > 0.03 || latencyMs > 120) return AppColors.warning;
    return AppColors.success;
  }
}
