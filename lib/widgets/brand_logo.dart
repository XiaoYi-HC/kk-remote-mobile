import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.showName = true,
    this.subtitle,
    this.onTap,
  });

  final double size;
  final bool showName;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            'assets/images/logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(size * 0.22),
              ),
              child: Icon(Icons.desktop_windows_rounded, color: AppColors.primary, size: size * 0.55),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 10),
          Text(
            AppConstants.productName,
            style: TextStyle(
              fontSize: size > 60 ? 22 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    );
    return Semantics(
      label: '${AppConstants.productName} 图标',
      image: true,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content),
    );
  }
}
