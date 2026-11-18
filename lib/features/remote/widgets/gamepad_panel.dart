import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/virtual_layout.dart';

/// 自定义游戏虚拟按键面板：透明悬浮、可拖拽编辑、支持保存/导入/导出/二维码分享。
class GamepadPanel extends StatelessWidget {
  const GamepadPanel({
    super.key,
    required this.layout,
    required this.editing,
    required this.onEditingChanged,
    required this.onLayoutChanged,
    required this.onKey,
    required this.onMouse,
    required this.onJoystick,
    required this.onAddButton,
    required this.onEditButton,
    required this.onDeleteButton,
    required this.onSave,
    required this.onImport,
    required this.onExport,
    required this.onShowQr,
    required this.onRestoreDefault,
    required this.onClose,
    this.hapticsEnabled = true,
  });

  final VirtualKeyLayout layout;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<VirtualKeyLayout> onLayoutChanged;
  final void Function(String code, bool down) onKey;
  final void Function(String button, bool down) onMouse;
  final void Function(Offset delta, double sensitivity) onJoystick;
  final VoidCallback onAddButton;
  final ValueChanged<VirtualButton> onEditButton;
  final ValueChanged<VirtualButton> onDeleteButton;
  final VoidCallback onSave;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onShowQr;
  final VoidCallback onRestoreDefault;
  final VoidCallback onClose;
  final bool hapticsEnabled;

  void _updatePosition(VirtualButton button, Offset delta, Size size) {
    final nextX =
        (button.x + delta.dx / size.width).clamp(0.0, 1 - button.width).toDouble();
    final nextY =
        (button.y + delta.dy / size.height).clamp(0.0, 1 - button.height).toDouble();
    final updated = layout.copyWith(
      buttons: layout.buttons
          .map((item) => item.id == button.id ? item.copyWith(x: nextX, y: nextY) : item)
          .toList(),
    );
    onLayoutChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: layout.buttons.map((button) {
                    final rect = Rect.fromLTWH(
                      button.x * size.width,
                      button.y * size.height,
                      button.width * size.width,
                      button.height * size.height,
                    );
                    return Positioned(
                      left: rect.left,
                      top: rect.top,
                      width: rect.width,
                      height: rect.height,
                      child: _buildButton(button, size),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          top: 4,
          child: _buildToolbar(context),
        ),
        if (editing)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '编辑模式：拖动按键调整位置，点击按键修改键值',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE61A1D23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              layout.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          IconButton(
            tooltip: editing ? '完成编辑' : '编辑布局',
            onPressed: () => onEditingChanged(!editing),
            icon: Icon(
              editing ? Icons.check_rounded : Icons.edit_outlined,
              size: 17,
              color: editing ? AppColors.primary : Colors.white70,
            ),
          ),
          if (editing) ...[
            IconButton(
              tooltip: '添加按键',
              onPressed: onAddButton,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 17, color: Colors.white70),
            ),
            IconButton(
              tooltip: '保存布局',
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 17, color: Colors.white70),
            ),
          ],
          PopupMenuButton<String>(
            tooltip: '布局管理',
            color: AppColors.surface,
            icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.white70),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  onImport();
                  break;
                case 'export':
                  onExport();
                  break;
                case 'qr':
                  onShowQr();
                  break;
                case 'default':
                  onRestoreDefault();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'qr', child: Text('二维码分享布局')),
              PopupMenuItem(value: 'export', child: Text('导出为文件')),
              PopupMenuItem(value: 'import', child: Text('从文件导入')),
              PopupMenuItem(value: 'default', child: Text('恢复默认布局')),
            ],
          ),
          IconButton(
            tooltip: '关闭按键面板',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(VirtualButton button, Size size) {
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((button.opacity * 255).round()),
        borderRadius: BorderRadius.circular(button.isJoystick ? 999 : 10),
        border: Border.all(
          color: editing ? AppColors.primary : Colors.white.withAlpha(70),
          width: editing ? 1.4 : 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: button.isJoystick
          ? const Icon(Icons.control_camera_rounded, color: Colors.white54, size: 22)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  button.label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(225),
                    fontSize: button.isMouse ? 11 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );

    if (editing) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) => _updatePosition(button, details.delta, size),
              onTap: () => onEditButton(button),
              child: content,
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: () => onDeleteButton(button),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    if (button.isJoystick) {
      return _JoystickButton(
        button: button,
        sensitivity: layout.joystickSensitivity,
        onMove: onJoystick,
      );
    }
    if (button.isMouse) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (hapticsEnabled) HapticFeedback.selectionClick();
          onMouse(button.type == 'mouseLeft' ? 'left' : 'right', true);
        },
        onPointerUp: (_) => onMouse(button.type == 'mouseLeft' ? 'left' : 'right', false),
        onPointerCancel: (_) => onMouse(button.type == 'mouseLeft' ? 'left' : 'right', false),
        child: content,
      );
    }
    if (button.type == 'text') {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (button.action.isNotEmpty) {
            for (final char in button.action.split('')) {
              onKey('Key${char.toUpperCase()}', true);
              onKey('Key${char.toUpperCase()}', false);
            }
          }
        },
        child: content,
      );
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (hapticsEnabled) HapticFeedback.lightImpact();
        onKey(button.keyCode.isEmpty ? 'Key${button.label.toUpperCase()}' : button.keyCode, true);
      },
      onPointerUp: (_) => onKey(
        button.keyCode.isEmpty ? 'Key${button.label.toUpperCase()}' : button.keyCode,
        false,
      ),
      onPointerCancel: (_) => onKey(
        button.keyCode.isEmpty ? 'Key${button.label.toUpperCase()}' : button.keyCode,
        false,
      ),
      child: content,
    );
  }
}

class _JoystickButton extends StatefulWidget {
  const _JoystickButton({
    required this.button,
    required this.sensitivity,
    required this.onMove,
  });

  final VirtualButton button;
  final double sensitivity;
  final void Function(Offset delta, double sensitivity) onMove;

  @override
  State<_JoystickButton> createState() => _JoystickButtonState();
}

class _JoystickButtonState extends State<_JoystickButton> {
  Offset _knob = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final maxOffset = size.shortestSide * 0.28;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final next = _knob + details.delta;
            final clamped = Offset(
              next.dx.clamp(-maxOffset, maxOffset).toDouble(),
              next.dy.clamp(-maxOffset, maxOffset).toDouble(),
            );
            setState(() => _knob = clamped);
            widget.onMove(
              Offset(
                details.delta.dx / size.width,
                details.delta.dy / size.height,
              ),
              widget.sensitivity,
            );
          },
          onPanEnd: (_) => setState(() => _knob = Offset.zero),
          onPanCancel: () => setState(() => _knob = Offset.zero),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((widget.button.opacity * 255).round()),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.control_camera_rounded, color: Colors.white24, size: 26),
                Transform.translate(
                  offset: _knob,
                  child: Container(
                    width: size.shortestSide * 0.42,
                    height: size.shortestSide * 0.42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(180),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.open_with_rounded, size: 14, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
