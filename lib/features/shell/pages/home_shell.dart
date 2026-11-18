import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../devices/pages/home_page.dart';
import '../../devices/pages/remote_assist_page.dart';
import '../../settings/pages/settings_page.dart';

/// 登录后的主框架：底部悬浮 Liquid Glass 标签栏 + 三个页面。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _collapsed = false;

  static const _items = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    _TabItem(icon: Icons.desktop_windows_outlined, activeIcon: Icons.desktop_windows_rounded, label: '远程协助'),
    _TabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '我的'),
  ];

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      // 向下滚动收起成小圆泡，向上滚动展开。
      if (delta > 4 && !_collapsed && notification.metrics.pixels > 48) {
        setState(() => _collapsed = true);
      } else if (delta < -4 && _collapsed) {
        setState(() => _collapsed = false);
      }
    } else if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 16 && _collapsed) {
        setState(() => _collapsed = false);
      }
    }
    return false;
  }

  void _selectTab(int value) {
    if (_collapsed) setState(() => _collapsed = false);
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final barInset = 86 + media.padding.bottom;
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
            left: 20,
            right: 20,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
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
                      : _LiquidGlassTabBar(
                          key: const ValueKey('bar'),
                          items: _items,
                          index: _index,
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

/// 液态玻璃底座：高斯模糊 + 白色渐变 + 高光描边。
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.borderRadius,
    required this.child,
    this.height,
  });

  final double borderRadius;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withAlpha(200), width: 0.9),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.45, 1],
              colors: [
                Colors.white.withAlpha(228),
                Colors.white.withAlpha(176),
                Colors.white.withAlpha(140),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x241F2329),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 顶部高光，模拟玻璃折射的亮边。
              Positioned(
                left: 8,
                right: 8,
                top: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha(0),
                          Colors.white.withAlpha(230),
                          Colors.white.withAlpha(0),
                        ],
                      ),
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
  }
}

/// 展开态的悬浮标签栏。
class _LiquidGlassTabBar extends StatelessWidget {
  const _LiquidGlassTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<_TabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 30,
      height: 62,
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withAlpha(235) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0x141F2329),
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
