import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_services.dart';
import '../../auth/state/auth_provider.dart';
import '../../devices/pages/home_page.dart';
import '../../devices/pages/remote_assist_page.dart';
import '../../settings/pages/settings_page.dart';
import '../../support/state/support_notify_service.dart';
import '../widgets/native_liquid_tab_bar.dart';

/// 登录后的主框架：底部悬浮 Liquid Glass 标签栏 + 三个页面。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _collapsed = false;

  /// 滚动时高光轻微偏移，模拟玻璃对运动/环境光的响应。
  double _specularShift = 0;

  static const _items = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    _TabItem(icon: Icons.desktop_windows_outlined, activeIcon: Icons.desktop_windows_rounded, label: '远程协助'),
    _TabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '我的'),
  ];

  @override
  void initState() {
    super.initState();
    // 客服/工单回复通知需要系统通知权限。
    NotificationService.instance.requestPermission();
  }

  @override
  void dispose() {
    // 退出登录或销毁主框架时断开客服通道，并清除本账号残留的通知。
    SupportNotifyService.instance.stop(clearNotifications: true);
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 4 && !_collapsed && notification.metrics.pixels > 48) {
        setState(() => _collapsed = true);
      } else if (delta < -4 && _collapsed) {
        setState(() => _collapsed = false);
      }
      // 高光随滚动方向移动，幅度很小。
      final next = (_specularShift + delta / 40).clamp(-0.18, 0.18);
      if ((next - _specularShift).abs() > 0.008) {
        setState(() => _specularShift = next);
      }
    } else if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 16 && _collapsed) {
        setState(() => _collapsed = false);
      }
    }
    return false;
  }

  void _selectTab(int value) {
    setState(() {
      _collapsed = false;
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 登录状态下常驻客服通道，接收客服/工单回复通知（按账号隔离）。
    final auth = context.watch<AuthProvider>();
    final services = context.read<AppServices>();
    final token = services.api.token;
    final user = auth.user;
    if (token != null && token.isNotEmpty && user != null && user.id > 0) {
      SupportNotifyService.instance.start(
        services: services,
        accountId: user.id,
        token: token,
      );
    }
    final media = MediaQuery.of(context);
    final barInset = 86 + media.padding.bottom;
    // iOS 使用原生 SwiftUI Liquid Glass 标签栏，其它平台使用 Flutter 实现。
    final nativeBar = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: barInset,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: IndexedStack(
                index: _index,
                children: const [
                  HomePage(),
                  RemoteAssistPage(),
                  SettingsPage(embedded: true),
                ],
              ),
            ),
          ),
          Positioned(
            left: nativeBar ? 0 : 20,
            right: nativeBar ? 0 : 20,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, nativeBar ? 2 : 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    alignment: Alignment.bottomRight,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _collapsed
                      ? Align(
                          key: const ValueKey('bubble'),
                          alignment: Alignment.centerRight,
                          child: _GlassBubbleButton(
                            item: _items[_index],
                            onTap: () => setState(() => _collapsed = false),
                          ),
                        )
                      : nativeBar
                          ? NativeLiquidGlassTabBar(
                              key: const ValueKey('native-bar'),
                              index: _index,
                              items: const [
                                NativeLiquidTabItem(symbol: 'house.fill', label: '首页'),
                                NativeLiquidTabItem(
                                  symbol: 'desktopcomputer',
                                  label: '远程协助',
                                ),
                                NativeLiquidTabItem(symbol: 'person.fill', label: '我的'),
                              ],
                              onChanged: _selectTab,
                            )
                          : _LiquidGlassTabBar(
                              key: const ValueKey('bar'),
                              items: _items,
                              index: _index,
                              specularShift: _specularShift,
                              onChanged: _selectTab,
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Liquid Glass 材质：折射（轻微放大 + 模糊）+ 高光边 + 内阴影。
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.borderRadius,
    required this.child,
    this.height,
    this.specularShift = 0,
    this.prominent = false,
  });

  final double borderRadius;
  final Widget child;
  final double? height;
  final double specularShift;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = height ?? (constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0);
        // 背景先做 1.03 倍轻微放大（折射/透镜感），再进行高斯模糊。
        final lens = ImageFilter.matrix(
          (Matrix4.identity()
                ..translate(-width * 0.015, -h * 0.015)
                ..scale(1.03))
              .storage,
        );
        final filter = ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          inner: lens,
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: filter,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: prominent
                      ? [Colors.white.withAlpha(242), Colors.white.withAlpha(206)]
                      : [Colors.white.withAlpha(190), Colors.white.withAlpha(120)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x221F2329),
                    blurRadius: prominent ? 18 : 30,
                    offset: Offset(0, prominent ? 4 : 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 玻璃内部的柔和折射光斑，随滚动轻微平移。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.75 + specularShift, -1.05),
                            radius: 1.25,
                            colors: [
                              Colors.white.withAlpha(150),
                              Colors.white.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 边缘高光 + 内阴影，模拟 iOS 26 玻璃的立体折射。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GlassRimPainter(
                          radius: borderRadius,
                          prominent: prominent,
                        ),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.radius, required this.prominent});

  final double radius;
  final bool prominent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 渐变描边：左上强高光 → 右下淡边。
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.32, 0.72, 1],
        colors: [
          Colors.white.withAlpha(prominent ? 255 : 235),
          Colors.white.withAlpha(prominent ? 190 : 120),
          Colors.white.withAlpha(60),
          Colors.white.withAlpha(prominent ? 220 : 160),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.7), stroke);

    // 内侧暗边，增加厚度感。
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x12000000);
    canvas.drawRRect(rrect.deflate(2.2), inner);
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.prominent != prominent;
}

/// 展开态的悬浮标签栏。
class _LiquidGlassTabBar extends StatelessWidget {
  const _LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.specularShift,
    required this.onChanged,
  });

  final List<_TabItem> items;
  final int index;
  final double specularShift;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 31,
      height: 62,
      specularShift: specularShift,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabButton(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 收起态的小圆泡按钮。
class _GlassBubbleButton extends StatelessWidget {
  const _GlassBubbleButton({required this.item, required this.onTap});

  final _TabItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '展开 ${item.label} 标签栏',
      child: GestureDetector(
        onTap: onTap,
        child: _GlassSurface(
          borderRadius: 27,
          height: 54,
          prominent: true,
          child: SizedBox(
            width: 54,
            child: Center(
              child: Icon(item.activeIcon, size: 22, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(250),
                      Colors.white.withAlpha(215),
                    ],
                  )
                : null,
            border: selected
                ? Border.all(color: Colors.white.withAlpha(230), width: 0.9)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0x1A1F2329),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
