import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 虚拟键盘：快捷键行 + 字母/数字/符号键盘 + 输入法逐字上屏。
///
/// 修饰键是真实的按下/抬起事件，锁定后可与鼠标点击组合使用。
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
    required this.onText,
    required this.onLongText,
    required this.onClose,
    required this.onToggleFavorite,
    required this.onCombo,
    required this.onSystemAction,
    this.onImeFocusChanged,
    this.favoriteCodes = const [],
    this.hapticsEnabled = true,
  });

  final void Function(String code, bool repeatable) onKeyDown;
  final void Function(String code) onKeyUp;
  final void Function(String text) onText;
  final VoidCallback onLongText;
  final VoidCallback onClose;
  final void Function(String code, String label, bool favorite) onToggleFavorite;
  final void Function(List<String> keys) onCombo;
  final void Function(String action) onSystemAction;
  final void Function(bool focused)? onImeFocusChanged;
  final List<String> favoriteCodes;
  final bool hapticsEnabled;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  static const Map<String, String> _hotkeyLabels = {
    'ControlLeft': 'Ctrl',
    'AltLeft': 'Alt',
    'MetaLeft': 'Win',
    'ShiftLeft': 'Shift',
    'Tab': 'Tab',
    'Escape': 'Esc',
    'Delete': 'Del',
    'Insert': 'Ins',
    'Home': 'Home',
    'End': 'End',
    'PageUp': 'PgUp',
    'PageDown': 'PgDn',
    'ArrowUp': '↑',
    'ArrowDown': '↓',
    'ArrowLeft': '←',
    'ArrowRight': '→',
    'Enter': 'Enter',
    'Backspace': '⌫',
    'Space': '空格',
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

  static const List<List<String>> _symbolRows = [
    ['!', '@', '#', r'$', '%', '^', '&', '*', '(', ')'],
    ['-', '_', '=', '+', '[', ']', '{', '}', r'\', '|'],
    [';', ':', "'", '"', ',', '.', '/', '?', '<', '>'],
    ['~', '`', '€', '£', '¥', '°', '©', '®', '™', '§'],
    ['，', '。', '？', '！', '：', '；', '、', '“', '”', '（'],
  ];

  static const List<List<String>> _fnRows = [
    ['F1', 'F2', 'F3', 'F4', 'F5', 'F6'],
    ['F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
  ];

  final Set<String> _modifiers = <String>{};
  final TextEditingController _imeController = TextEditingController();
  final FocusNode _imeFocus = FocusNode();

  bool _symbolPage = false;
  bool _fnPage = false;
  bool _imeVisible = false;
  bool _shiftOneShot = false;
  String _sentText = '';
  DateTime? _lastShiftTap;

  @override
  void initState() {
    super.initState();
    _imeFocus.addListener(_onImeFocusChanged);
  }

  @override
  void dispose() {
    _imeFocus.removeListener(_onImeFocusChanged);
    _imeController.dispose();
    _imeFocus.dispose();
    super.dispose();
  }

  void _onImeFocusChanged() {
    widget.onImeFocusChanged?.call(_imeFocus.hasFocus);
  }

  bool get _shiftActive => _modifiers.contains('ShiftLeft');

  List<String> get _activeModifiers =>
      _modifiers.map((code) => _hotkeyLabels[code] ?? code).toList();

  void _haptic() {
    if (widget.hapticsEnabled) HapticFeedback.lightImpact();
  }

  void _tapKey(String code, {bool repeatable = false}) {
    _haptic();
    widget.onKeyDown(code, repeatable);
    Future<void>.delayed(const Duration(milliseconds: 28), () {
      widget.onKeyUp(code);
      _releaseShiftIfOneShot();
    });
  }

  void _releaseShiftIfOneShot() {
    if (!_shiftOneShot) return;
    _shiftOneShot = false;
    if (_modifiers.remove('ShiftLeft')) {
      widget.onKeyUp('ShiftLeft');
      if (mounted) setState(() {});
    }
  }

  void _tapText(String text) {
    _haptic();
    widget.onText(text);
    _releaseShiftIfOneShot();
  }

  void _longPressStart(String code) {
    widget.onKeyDown(code, true);
  }

  void _longPressEnd(String code) {
    widget.onKeyUp(code);
    _releaseShiftIfOneShot();
  }

  void _tapModifier(String code) {
    _haptic();
    if (code == 'ShiftLeft') {
      final now = DateTime.now();
      if (_shiftActive) {
        final doubleTap = _lastShiftTap != null &&
            now.difference(_lastShiftTap!) < const Duration(milliseconds: 320);
        _lastShiftTap = now;
        if (doubleTap && _shiftOneShot) {
          // 双击 Shift 进入锁定模式。
          _shiftOneShot = false;
          setState(() {});
          return;
        }
        widget.onKeyUp(code);
        _modifiers.remove(code);
        _shiftOneShot = false;
        setState(() {});
        return;
      }
      _lastShiftTap = now;
      widget.onKeyDown(code, false);
      _modifiers.add(code);
      _shiftOneShot = true;
      setState(() {});
      return;
    }
    if (_modifiers.contains(code)) {
      widget.onKeyUp(code);
      _modifiers.remove(code);
    } else {
      widget.onKeyDown(code, false);
      _modifiers.add(code);
    }
    setState(() {});
  }

  void _toggleIme() {
    setState(() {
      _imeVisible = !_imeVisible;
      if (!_imeVisible) {
        _imeFocus.unfocus();
        _imeController.clear();
        _sentText = '';
      }
    });
    if (_imeVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _imeFocus.requestFocus();
      });
    }
  }

  void _onImeChanged() {
    final value = _imeController.value;
    // 拼音组词过程中不发送，等输入法提交。
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    final text = value.text;
    var common = 0;
    while (common < text.length &&
        common < _sentText.length &&
        text[common] == _sentText[common]) {
      common++;
    }
    final removed = _sentText.length - common;
    for (var i = 0; i < removed; i++) {
      widget.onKeyDown('Backspace', false);
      widget.onKeyUp('Backspace');
    }
    final added = text.substring(common);
    if (added.isNotEmpty) widget.onText(added);
    _sentText = text;
    if (_sentText.length >= 200) {
      _imeController.clear();
      _sentText = '';
    }
  }

  void _onImeSubmitted(String _) {
    widget.onKeyDown('Enter', false);
    widget.onKeyUp('Enter');
    _imeController.clear();
    _sentText = '';
  }

  void _close() {
    for (final code in _modifiers.toList()) {
      widget.onKeyUp(code);
    }
    _modifiers.clear();
    _imeFocus.unfocus();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF5161A20), Color(0xF50C0F14)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Colors.white12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(110),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              if (_imeVisible) ...[
                const SizedBox(height: 8),
                _buildImeField(),
              ],
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  children: [
                    ...widget.favoriteCodes.map((code) => _buildHotkey(
                          code,
                          label: _hotkeyLabels[code] ?? code,
                          favorite: true,
                        )),
                    ..._hotkeys
                        .where((code) => !widget.favoriteCodes.contains(code))
                        .map((code) => _buildHotkey(code, label: _hotkeyLabels[code] ?? code)),
                    _buildHotkey(
                      'Fn',
                      label: 'F1-12',
                      active: _fnPage,
                      onTap: () => setState(() {
                        _fnPage = !_fnPage;
                        _symbolPage = false;
                      }),
                    ),
                    _buildHotkey(
                      'Symbols',
                      label: '符号',
                      active: _symbolPage,
                      onTap: () => setState(() {
                        _symbolPage = !_symbolPage;
                        _fnPage = false;
                      }),
                    ),
                    _buildHotkey(
                      'Combo',
                      label: '组合键',
                      onTap: _showCombos,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (_fnPage)
                ..._buildFnPage()
              else if (_symbolPage)
                ..._buildSymbolPage()
              else ...[
                _buildNumberRow(),
                const SizedBox(height: 6),
                _buildLetterRow('QWERTYUIOP'),
                const SizedBox(height: 6),
                _buildLetterRow('ASDFGHJKL', padding: 12),
                const SizedBox(height: 6),
                _buildLetterRow('ZXCVBNM', leading: _buildShiftKey(), trailing: _buildBackspaceKey()),
              ],
              const SizedBox(height: 8),
              _buildBottomRow(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCombos() async {
    final combos = <(String, List<String>)>[
      ('Ctrl + C', ['ControlLeft', 'KeyC']),
      ('Ctrl + V', ['ControlLeft', 'KeyV']),
      ('Ctrl + X', ['ControlLeft', 'KeyX']),
      ('Ctrl + Z', ['ControlLeft', 'KeyZ']),
      ('Ctrl + A', ['ControlLeft', 'KeyA']),
      ('Ctrl + F', ['ControlLeft', 'KeyF']),
      ('Ctrl + S', ['ControlLeft', 'KeyS']),
      ('Alt + Tab', ['AltLeft', 'Tab']),
      ('Alt + F4', ['AltLeft', 'F4']),
      ('Ctrl + Shift + Esc', ['ControlLeft', 'ShiftLeft', 'Escape']),
      ('Win + D', ['MetaLeft', 'KeyD']),
      ('Win + E', ['MetaLeft', 'KeyE']),
    ];
    final selected = await showModalBottomSheet<(String, List<String>)>(
      context: context,
      backgroundColor: const Color(0xFF171B22),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(
                '组合键',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            ...combos.map(
              (item) => ListTile(
                dense: true,
                title: Text(item.$1, style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () => Navigator.of(sheetContext).pop(item),
              ),
            ),
            ListTile(
              dense: true,
              title: const Text(
                'Ctrl + Alt + Del',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: const Text(
                '发送安全注意序列（需被控端授权）',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () => Navigator.of(sheetContext).pop(('Ctrl + Alt + Del', <String>[])),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected.$2.isEmpty) {
      widget.onSystemAction('ctrl_alt_del');
    } else {
      widget.onCombo(selected.$2);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(46),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4C95FF), AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.keyboard_alt_rounded, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '虚拟键盘',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeModifiers.isEmpty ? '快捷键 · 字母 · 中文输入' : _activeModifiers.join(' + '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _activeModifiers.isEmpty ? Colors.white38 : AppColors.primary,
                      fontWeight: _activeModifiers.isEmpty ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _buildHeaderAction(
              icon: Icons.notes_rounded,
              label: '长文本',
              onTap: () {
                _imeFocus.unfocus();
                widget.onLongText();
              },
            ),
            const SizedBox(width: 2),
            _buildHeaderAction(
              icon: Icons.translate_rounded,
              label: '中文',
              active: _imeVisible,
              onTap: _toggleIme,
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: _close,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(14)),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withAlpha(36) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? AppColors.primary.withAlpha(120) : Colors.white.withAlpha(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? AppColors.primary : Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: active ? AppColors.primary : Colors.white70,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImeField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 15, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _imeController,
              focusNode: _imeFocus,
              onChanged: (_) => _onImeChanged(),
              onSubmitted: _onImeSubmitted,
              textInputAction: TextInputAction.send,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '输入中文，逐字发送到电脑',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: '发送回车',
            onPressed: () => _onImeSubmitted(''),
            icon: const Icon(Icons.keyboard_return_rounded, size: 18),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFnPage() {
    return _fnRows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: row
                  .map(
                    (code) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _buildKey(label: code, onTap: () => _tapKey(code)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildSymbolPage() {
    return _symbolRows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: row
                  .map(
                    (char) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: _buildKey(
                          label: char,
                          height: 36,
                          onTap: () => _tapText(char),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        )
        .toList();
  }

  Widget _buildNumberRow() {
    return Row(
      children: List.generate(10, (index) {
        final number = (index + 1) % 10;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildKey(
              label: '$number',
              code: 'Digit$number',
              repeatable: true,
              onTap: () => _tapKey('Digit$number', repeatable: true),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLetterRow(String letters, {double padding = 0, Widget? leading, Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 56, child: leading),
            const SizedBox(width: 5),
          ],
          ...letters.split('').map((letter) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _buildKey(
                  label: _shiftActive ? letter : letter.toLowerCase(),
                  code: 'Key$letter',
                  repeatable: true,
                  onTap: () => _tapKey('Key$letter', repeatable: true),
                ),
              ),
            );
          }),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            SizedBox(width: 54, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftKey() {
    return _buildKey(
      label: 'Shift',
      active: _shiftActive,
      onTap: () => _tapModifier('ShiftLeft'),
    );
  }

  Widget _buildBackspaceKey() {
    return _buildKey(
      label: '⌫',
      code: 'Backspace',
      repeatable: true,
      onTap: () => _tapKey('Backspace', repeatable: true),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: _buildKey(label: 'Esc', onTap: () => _tapKey('Escape')),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 48,
          child: _buildKey(label: 'Tab', onTap: () => _tapKey('Tab')),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _buildKey(
            label: '空格',
            code: 'Space',
            repeatable: true,
            onTap: () => _tapKey('Space', repeatable: true),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 62,
          child: _buildKey(label: 'Enter', onTap: () => _tapKey('Enter')),
        ),
      ],
    );
  }

  Widget _buildHotkey(
    String code, {
    required String label,
    bool favorite = false,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final isActive = active || _modifiers.contains(code);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          if (onTap != null) return;
          widget.onToggleFavorite(code, label, favorite);
        },
        child: InkWell(
          onTap: onTap ?? () => _tapModifierOrKey(code),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 38),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isActive
                    ? const [Color(0xFF4C95FF), AppColors.primaryDark]
                    : const [Color(0xFF323843), Color(0xFF262B33)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? Colors.white.withAlpha(70)
                    : favorite
                        ? AppColors.warning.withAlpha(140)
                        : Colors.white.withAlpha(16),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(90),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favorite) ...[
                  const Icon(Icons.star_rounded, size: 10, color: AppColors.warning),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _tapModifierOrKey(String code) {
    if (code.startsWith('Control') ||
        code.startsWith('Alt') ||
        code.startsWith('Meta') ||
        code.startsWith('Shift')) {
      _tapModifier(code);
      return;
    }
    _tapKey(code);
  }

  Widget _buildKey({
    required String label,
    required VoidCallback onTap,
    String? code,
    bool active = false,
    bool repeatable = false,
    double height = 44,
  }) {
    final keyCode = code;
    final child = _AnimatedKey(
      label: label,
      onTap: onTap,
      height: height,
      active: active,
    );
    if (keyCode == null || !repeatable) return child;
    return GestureDetector(
      onLongPressStart: (_) => _longPressStart(keyCode),
      onLongPressEnd: (_) => _longPressEnd(keyCode),
      onLongPressCancel: () => _longPressEnd(keyCode),
      child: child,
    );
  }
}

/// 带按压反馈的单个按键：轻微缩放 + 渐变高亮。
class _AnimatedKey extends StatefulWidget {
  const _AnimatedKey({
    required this.label,
    required this.onTap,
    required this.height,
    required this.active,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final bool active;

  @override
  State<_AnimatedKey> createState() => _AnimatedKeyState();
}

class _AnimatedKeyState extends State<_AnimatedKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1,
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Color(0xFF4C95FF), AppColors.primaryDark]
                  : _pressed
                      ? const [Color(0xFF3B424E), Color(0xFF2F353F)]
                      : const [Color(0xFF343A45), Color(0xFF252A32)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? Colors.white.withAlpha(80) : Colors.white.withAlpha(16),
              width: 0.8,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : _pressed
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? Colors.white : Colors.white.withAlpha(230),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
