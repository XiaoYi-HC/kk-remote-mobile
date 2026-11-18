import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 下拉选项。
class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label, this.subtitle});

  final T value;
  final String label;
  final String? subtitle;
}

/// 统一的底部弹层选择器（替代原生 DropdownButton 的浮层菜单）。
Future<T?> showAppPicker<T>(
  BuildContext context, {
  required String title,
  required List<AppSelectOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.72;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 0.8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                children: [
                  for (final option in options)
                    _PickerTile<T>(
                      option: option,
                      selected: option.value == selected,
                      onTap: () => Navigator.of(sheetContext).pop(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PickerTile<T> extends StatelessWidget {
  const _PickerTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// 表单里的选择框，外观与 AppTextField 保持一致。
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.onChanged,
    this.title,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final String valueLabel;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? title;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final T? current = options
        .where(
          (item) =>
              item.label == valueLabel ||
              valueLabel.startsWith(item.label) ||
              item.label.startsWith(valueLabel),
        )
        .map<T?>((item) => item.value)
        .firstWhere((_) => true, orElse: () => null);
    final isEmpty = valueLabel.isEmpty;
    return Semantics(
      button: true,
      label: '$label，当前 $valueLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: enabled
                ? () async {
                    final value = await showAppPicker<T>(
                      context,
                      title: title ?? label,
                      options: options,
                      selected: current,
                    );
                    if (value != null) onChanged(value);
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: enabled ? AppColors.background : AppColors.background.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEmpty ? (hint ?? '请选择') : valueLabel,
                      style: TextStyle(
                        fontSize: 15,
                        color: isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置项右侧的紧凑选择按钮。
class AppSelectValue extends StatelessWidget {
  const AppSelectValue({
    super.key,
    required this.valueLabel,
    required this.onTap,
    this.enabled = true,
  });

  final String valueLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valueLabel,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
