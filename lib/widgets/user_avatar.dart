import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../state/app_services.dart';

/// 用户头像：有头像时显示图片，否则显示昵称首字。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.avatar = '',
    this.name = '',
    this.background = AppColors.primarySoft,
    this.foreground = AppColors.primary,
    this.fallbackAsset,
  });

  final double size;
  final String avatar;
  final String name;
  final Color background;
  final Color foreground;

  /// 无头像或加载失败时使用的本地兜底图（不传则显示昵称首字）。
  final String? fallbackAsset;

  String _resolveUrl(BuildContext context) {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) return avatar;
    return context.read<AppServices>().api.resolveUri(avatar).toString();
  }

  Widget _initial() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? 'K' : name.characters.first,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  Widget _fallback() {
    final asset = fallbackAsset;
    if (asset == null || asset.isEmpty) return _initial();
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _initial(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl(context);
    if (url.isEmpty) return _fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          );
        },
      ),
    );
  }
}
