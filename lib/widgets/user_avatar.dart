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
  });

  final double size;
  final String avatar;
  final String name;
  final Color background;
  final Color foreground;

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

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl(context);
    if (url.isEmpty) return _initial();
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _initial(),
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
