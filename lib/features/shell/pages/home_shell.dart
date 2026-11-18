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

  static const _items = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    _TabItem(icon: Icons.desktop_windows_outlined, activeIcon: Icons.desktop_windows_rounded, label: '远程协助'),
    _TabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '我的'),
  ];

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
            child: IndexedStack(
              index: _index,
              children: const [
                HomePage(),
                RemoteAssistPage(),
                SettingsPage(embedded: true),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _LiquidGlassTabBar(
                  items: _items,
                  index: _index,
                  onChanged: (value) => setState(() => _index = value),
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

/// 液态玻璃质感的悬浮标签栏。
class _LiquidGlassTabBar extends StatelessWidget {
  const _LiquidGlassTabBar({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<_TabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(216),
                Colors.white.withAlpha(150),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withAlpha(190), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A1F2329),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(120),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
            ],
          ),
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
            color: selected ? Colors.white.withAlpha(230) : Colors.transparent,
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
