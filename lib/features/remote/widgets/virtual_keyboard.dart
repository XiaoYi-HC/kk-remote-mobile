import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 虚拟键盘：快捷键行 + 字母/数字键盘 + 中文输入入口。
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    required this.onKey,
    required this.onClose,
    required this.onChineseInput,
    required this.onToggleFavorite,
    this.favoriteCodes = const [],
    this.hapticsEnabled = true,
  });

  final void Function(String code, bool down, List<String> modifiers) onKey;
  final VoidCallback onClose;
  final VoidCallback onChineseInput;
  final void Function(String code, String label, bool favorite) onToggleFavorite;
  final List<String> favoriteCodes;
  final bool hapticsEnabled;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  final Set<String> _modifiers = {};

  static const Map<String, String> _hotkeyLabels = {
    'ControlLeft': 'Ctrl',
    'AltLeft': 'Alt',
    'MetaLeft': 'Win',
    'ShiftLeft': 'Shift',
    'Tab': 'Tab',
    'Escape': 'Esc',
    'ArrowUp': '↑',
    'ArrowDown': '↓',
    'ArrowLeft': '←',
    'ArrowRight': '→',
    'Delete': 'Del',
    'Enter': 'Enter',
    'Backspace': '⌫',
    'F1': 'F1',
    'F2': 'F2',
    'F3': 'F3',
    'F4': 'F4',
    'F5': 'F5',
    'F6': 'F6',
    'F7': 'F7',
    'F8': 'F8',
    'F9': 'F9',
    'F10': 'F10',
    'F11': 'F11',
    'F12': 'F12',
  };

  static const List<String> _hotkeys = [
    'ControlLeft',
    'AltLeft',
    'MetaLeft',
    'ShiftLeft',
    'Tab',
    'Escape',
    'Delete',
    'ArrowUp',
    'ArrowDown',
    'ArrowLeft',
    'ArrowRight',
  ];

  List<String> get _activeModifiers => _modifiers.map(_modifierName).toList();

  String _modifierName(String code) {
    switch (code) {
      case 'ControlLeft':
        return 'ctrl';
      case 'AltLeft':
        return 'alt';
      case 'MetaLeft':
        return 'meta';
      case 'ShiftLeft':
        return 'shift';
      default:
        return code.toLowerCase();
    }
  }

  void _tapModifier(String code) {
    setState(() {
      if (_modifiers.contains(code)) {
        _modifiers.remove(code);
      } else {
        _modifiers.add(code);
      }
    });
  }

  void _tapKey(String code) {
    if (widget.hapticsEnabled) HapticFeedback.lightImpact();
    final modifiers = _activeModifiers;
    widget.onKey(code, true, modifiers);
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      widget.onKey(code, false, modifiers);
    });
  }

  void _tapHotkey(String code) {
    if (code.startsWith('Control') ||
        code.startsWith('Alt') ||
        code.startsWith('Meta') ||
        code.startsWith('Shift')) {
      _tapModifier(code);
      return;
    }
    _tapKey(code);
  }

  Future<void> _showFunctionKeys() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('功能键', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(12, (index) {
                  final code = 'F${index + 1}';
                  return SizedBox(
                    width: 58,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(code),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(code),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) _tapKey(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEE1A1D23),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_alt_outlined, size: 17, color: Colors.white70),
                  const SizedBox(width: 6),
                  const Text('虚拟键盘', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  if (_modifiers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(50),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _activeModifiers.join('+').toUpperCase(),
                        style: const TextStyle(fontSize: 9, color: AppColors.primary),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onChineseInput,
                    icon: const Icon(Icons.translate_rounded, size: 15),
                    label: const Text('中文输入', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(44, 32),
                    ),
                  ),
                  IconButton(
                    tooltip: '收起键盘',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 22),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...widget.favoriteCodes.map((code) => _buildHotkey(
                          code,
                          label: _hotkeyLabels[code] ?? code,
                          favorite: true,
                        )),
                    ..._hotkeys
                        .where((code) => !widget.favoriteCodes.contains(code))
                        .map((code) => _buildHotkey(code, label: _hotkeyLabels[code] ?? code)),
                    _buildHotkey('F1', label: 'F1-12', onTap: _showFunctionKeys),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _buildNumberRow(),
              const SizedBox(height: 5),
              _buildLetterRow('QWERTYUIOP'),
              const SizedBox(height: 5),
              _buildLetterRow('ASDFGHJKL', padding: 12),
              const SizedBox(height: 5),
              Row(
                children: [
                  _buildKey(
                    label: 'Shift',
                    width: 46,
                    active: _modifiers.contains('ShiftLeft'),
                    onTap: () => _tapModifier('ShiftLeft'),
                  ),
                  const SizedBox(width: 4),
                  ...'ZXCVBNM'.split('').map(
                        (letter) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _buildKey(
                              label: letter,
                              flex: true,
                              code: 'Key$letter',
                              onTap: () => _tapKey('Key$letter'),
                            ),
                          ),
                        ),
                      ),
                  SizedBox(
                    width: 50,
                    child: _buildKey(
                      label: '⌫',
                      width: 50,
                      code: 'Backspace',
                      onTap: () => _tapKey('Backspace'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _buildKey(label: 'Esc', width: 46, onTap: () => _tapKey('Escape')),
                  const SizedBox(width: 4),
                  _buildKey(label: 'Tab', width: 46, onTap: () => _tapKey('Tab')),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildKey(
                      label: '空格',
                      flex: true,
                      code: 'Space',
                      onTap: () => _tapKey('Space'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildKey(label: 'Enter', width: 58, onTap: () => _tapKey('Enter')),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow() {
    return Row(
      children: [
        ...List.generate(10, (index) {
          final number = (index + 1) % 10;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildKey(
                label: '$number',
                flex: true,
                code: 'Digit$number',
                onTap: () => _tapKey('Digit$number'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLetterRow(String letters, {double padding = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: letters.split('').map((letter) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildKey(
                label: letter,
                flex: true,
                code: 'Key$letter',
                onTap: () => _tapKey('Key$letter'),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHotkey(
    String code, {
    required String label,
    bool favorite = false,
    VoidCallback? onTap,
  }) {
    final active = _modifiers.contains(code);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onLongPress: () {
          if (onTap != null) return;
          widget.onToggleFavorite(code, label, favorite);
        },
        child: InkWell(
          onTap: onTap ?? () => _tapHotkey(code),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.white10,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: favorite ? AppColors.warning.withAlpha(150) : Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favorite) ...[
                  const Icon(Icons.star_rounded, size: 10, color: AppColors.warning),
                  const SizedBox(width: 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey({
    required String label,
    required VoidCallback onTap,
    String? code,
    double? width,
    bool flex = false,
    bool active = false,
  }) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 36,
        width: flex ? null : width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withAlpha(90) : const Color(0xFF2B2F36),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white12, width: 0.6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : Colors.white.withAlpha(225),
          ),
        ),
      ),
    );
    if (!flex) return child;
    return child;
  }
}
