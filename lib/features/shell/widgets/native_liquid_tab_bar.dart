import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 传给原生 SwiftUI 的标签项（symbol 为 SF Symbol 名称）。
class NativeLiquidTabItem {
  const NativeLiquidTabItem({required this.symbol, required this.label});

  final String symbol;
  final String label;
}

/// iOS 26 官方 Liquid Glass 标签栏（SwiftUI glassEffect 平台视图）。
///
/// 仅 iOS 生效；其它平台返回空占位，由调用方决定是否使用 Flutter 实现。
class NativeLiquidGlassTabBar extends StatefulWidget {
  const NativeLiquidGlassTabBar({
    super.key,
    required this.index,
    required this.items,
    required this.onChanged,
    this.height = 86,
  });

  final int index;
  final List<NativeLiquidTabItem> items;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  State<NativeLiquidGlassTabBar> createState() => _NativeLiquidGlassTabBarState();
}

class _NativeLiquidGlassTabBarState extends State<NativeLiquidGlassTabBar> {
  MethodChannel? _channel;

  bool get _supported => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant NativeLiquidGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _channel?.invokeMethod<void>('setSelection', widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: UiKitView(
        viewType: 'kk/liquid_tab_bar',
        creationParams: {
          'index': widget.index,
          'items': [
            for (final item in widget.items)
              {'symbol': item.symbol, 'title': item.label},
          ],
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          _channel = MethodChannel('kk/liquid_tab_bar/$id');
          _channel!.setMethodCallHandler((call) async {
            if (!mounted) return;
            if (call.method == 'select') {
              final value = call.arguments;
              if (value is int) widget.onChanged(value);
            }
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    // 清理原生通道回调，避免平台视图销毁后仍回调已卸载的 State。
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }
}
