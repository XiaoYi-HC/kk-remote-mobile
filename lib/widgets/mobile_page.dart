import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// 统一的移动端页面骨架：返回按钮、居中标题、最大宽度约束与安全区。
class MobilePage extends StatelessWidget {
  const MobilePage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.maxWidth = 640,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor = AppColors.background,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final double maxWidth;
  final bool resizeToAvoidBottomInset;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        leading: leading ??
            IconButton(
              tooltip: '返回',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            ),
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
