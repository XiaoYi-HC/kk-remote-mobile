import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 隐私黑屏确认弹窗：开启/关闭均需用户明确确认。
class PrivacyDialog extends StatelessWidget {
  const PrivacyDialog({
    super.key,
    required this.currentlyEnabled,
    required this.onConfirm,
    required this.onCancel,
  });

  final bool currentlyEnabled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final closing = currentlyEnabled;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                    color: (closing ? AppColors.warning : AppColors.textPrimary).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    closing ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: closing ? AppColors.warning : AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  closing ? '关闭隐私黑屏' : '开启隐私黑屏',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      closing
                          ? '关闭后对方电脑本地屏幕将恢复正常显示，远程画面不受影响。是否确认关闭？'
                          : '开启后对方电脑屏幕将变黑，仅你的手机可见画面。对方本地无法看到操作内容，是否继续？',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: closing ? AppColors.warning : AppColors.primary,
                    ),
                    icon: Icon(
                      closing ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18,
                    ),
                    label: Text(closing ? '确认关闭' : '确认开启'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 返回 true 表示用户确认切换隐私黑屏。
Future<bool> showPrivacyDialog(
  BuildContext context, {
  required bool currentlyEnabled,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => PrivacyDialog(
      currentlyEnabled: currentlyEnabled,
      onConfirm: () => Navigator.of(sheetContext).pop(true),
      onCancel: () => Navigator.of(sheetContext).pop(false),
    ),
  );
  return result ?? false;
}
