import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 远程画面手势层：
/// 单指拖动=移动鼠标，单击=左键，长按=右键，双指缩放=画面缩放，双指滑动=滚轮。
/// 支持轨迹球模式与三指手势。
class RemoteGestureLayer extends StatefulWidget {
  const RemoteGestureLayer({
    super.key,
    required this.child,
    required this.inputEnabled,
    required this.trackballMode,
    required this.touchSensitivity,
    required this.scrollSensitivity,
    required this.hapticsEnabled,
    required this.onMove,
    required this.onLeftClick,
    required this.onRightClick,
    required this.onWheel,
    this.onThreeFingerTap,
    this.videoAspectRatio,
  });

  final Widget child;
  final bool inputEnabled;
  final bool trackballMode;
  final double touchSensitivity;
  final double scrollSensitivity;
  final bool hapticsEnabled;
  final void Function(double x, double y) onMove;
  final void Function(double x, double y) onLeftClick;
  final void Function(double x, double y) onRightClick;
  final void Function(int delta) onWheel;
  final VoidCallback? onThreeFingerTap;

  /// 远端画面宽高比；为空或非法时按铺满处理。
  final double? videoAspectRatio;

  @override
  State<RemoteGestureLayer> createState() => _RemoteGestureLayerState();
}

class _RemoteGestureLayerState extends State<RemoteGestureLayer> {
  final Map<int, Offset> _pointers = {};
  Timer? _longPressTimer;
  bool _longPressFired = false;
  bool _moved = false;
  bool _multiTouched = false;
  bool _multiMoved = false;
  DateTime _downAt = DateTime.now();
  Offset _downPosition = Offset.zero;
  Offset _lastSinglePosition = Offset.zero;

  double _scale = 1;
  Offset _offset = Offset.zero;
  double _pinchStartDistance = 0;
  double _pinchStartScale = 1;
  Offset _lastFocal = Offset.zero;
  double _wheelAccumulator = 0;

  Offset _trackball = const Offset(0.5, 0.5);
  int _maxPointers = 0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// 视频在 BoxFit.contain 下实际占用的区域（扣除上下或左右黑边）。
  Rect _videoRect(Size size) {
    final ratio = widget.videoAspectRatio;
    if (ratio == null || ratio <= 0 || !ratio.isFinite) {
      return Offset.zero & size;
    }
    final boxRatio = size.width / size.height;
    if (ratio > boxRatio) {
      final height = size.width / ratio;
      return Rect.fromLTWH(0, (size.height - height) / 2, size.width, height);
    }
    final width = size.height * ratio;
    return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
  }

  Offset _normalized(Offset local, Size size) {
    final logical = (local - _offset) / _scale;
    final rect = _videoRect(size);
    return Offset(
      ((logical.dx - rect.left) / rect.width).clamp(0.0, 1.0).toDouble(),
      ((logical.dy - rect.top) / rect.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  Offset _screenFor(Offset normalized, Size size) {
    final rect = _videoRect(size);
    final logical = Offset(
      rect.left + normalized.dx * rect.width,
      rect.top + normalized.dy * rect.height,
    );
    return logical * _scale + _offset;
  }

  void _resetLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _handleDown(PointerDownEvent event, Size size) {
    _pointers[event.pointer] = event.localPosition;
    _maxPointers = math.max(_maxPointers, _pointers.length);
    if (_pointers.length == 1) {
      _downAt = DateTime.now();
      _downPosition = event.localPosition;
      _lastSinglePosition = event.localPosition;
      _moved = false;
      _longPressFired = false;
      _multiTouched = false;
      _multiMoved = false;
      _resetLongPress();
      if (widget.inputEnabled) {
        _longPressTimer = Timer(const Duration(milliseconds: 520), () {
          if (!mounted || _pointers.length != 1 || _moved || _multiTouched) return;
          _longPressFired = true;
          if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
          final target = widget.trackballMode
              ? _trackball
              : _normalized(_lastSinglePosition, size);
          widget.onRightClick(target.dx, target.dy);
        });
      }
    } else {
      _resetLongPress();
      _multiTouched = true;
      _moved = true;
      if (_pointers.length == 2) {
        final points = _pointers.values.toList();
        _pinchStartDistance = (points[0] - points[1]).distance;
        _pinchStartScale = _scale;
        _lastFocal = (points[0] + points[1]) / 2;
        _wheelAccumulator = 0;
      }
    }
  }

  void _handleMove(PointerMoveEvent event, Size size) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      final delta = event.localPosition - _lastSinglePosition;
      if ((event.localPosition - _downPosition).distance > 8) {
        _moved = true;
        _resetLongPress();
      }
      _lastSinglePosition = event.localPosition;
      if (!widget.inputEnabled) return;
      if (widget.trackballMode) {
        final rect = _videoRect(size);
        final next = Offset(
          (_trackball.dx + delta.dx / rect.width * widget.touchSensitivity)
              .clamp(0.0, 1.0)
              .toDouble(),
          (_trackball.dy + delta.dy / rect.height * widget.touchSensitivity)
              .clamp(0.0, 1.0)
              .toDouble(),
        );
        _trackball = next;
        widget.onMove(next.dx, next.dy);
        setState(() {});
      } else {
        final target = _normalized(event.localPosition, size);
        widget.onMove(target.dx, target.dy);
      }
      return;
    }
    if (_pointers.length >= 2) {
      _multiMoved = true;
    }
    if (_pointers.length == 2) {
      _moved = true;
      final points = _pointers.values.toList();
      final distance = (points[0] - points[1]).distance;
      final focal = (points[0] + points[1]) / 2;
      if (_pinchStartDistance > 0) {
        final nextScale =
            (_pinchStartScale * distance / _pinchStartDistance).clamp(1.0, 4.0).toDouble();
        if ((nextScale - _scale).abs() > 0.001) {
          final logicalFocal = (focal - _offset) / _scale;
          setState(() {
            _scale = nextScale;
            _offset = focal - logicalFocal * _scale;
            _clampOffset(size);
          });
        }
      }
      final dy = focal.dy - _lastFocal.dy;
      _lastFocal = focal;
      _wheelAccumulator += dy;
      final threshold = 18.0 / widget.scrollSensitivity.clamp(0.2, 3.0);
      while (_wheelAccumulator.abs() >= threshold) {
        final direction = _wheelAccumulator > 0 ? 1 : -1;
        _wheelAccumulator -= direction * threshold;
        widget.onWheel(direction * 120);
      }
    }
  }

  void _clampOffset(Size size) {
    if (_scale <= 1.001) {
      _offset = Offset.zero;
      return;
    }
    final maxX = (size.width * _scale - size.width) / 2;
    final maxY = (size.height * _scale - size.height) / 2;
    _offset = Offset(
      _offset.dx.clamp(-maxX, maxX).toDouble(),
      _offset.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  void _handleUp(PointerUpEvent event, Size size) {
    final wasSingle = _pointers.length == 1;
    _pointers.remove(event.pointer);
    _resetLongPress();
    if (wasSingle && _pointers.isEmpty) {
      final elapsed = DateTime.now().difference(_downAt);
      if (widget.inputEnabled &&
          !_moved &&
          !_longPressFired &&
          !_multiTouched &&
          elapsed < Duration(milliseconds: 350)) {
        final target =
            widget.trackballMode ? _trackball : _normalized(_downPosition, size);
        if (widget.hapticsEnabled) HapticFeedback.selectionClick();
        widget.onLeftClick(target.dx, target.dy);
      }
      if (_maxPointers >= 3 && !_multiMoved && widget.onThreeFingerTap != null) {
        widget.onThreeFingerTap!();
      }
    }
    if (_pointers.isEmpty) {
      _maxPointers = 0;
      _multiTouched = false;
      _multiMoved = false;
      _moved = false;
    } else if (_pointers.length == 1) {
      _lastSinglePosition = _pointers.values.first;
      _pinchStartDistance = 0;
    }
  }

  void _handleCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _resetLongPress();
    if (_pointers.isEmpty) {
      _maxPointers = 0;
      _multiTouched = false;
      _moved = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          label: '远程画面操作区域，单指移动鼠标，单击左键，长按右键，双指缩放画面，双指滑动滚轮',
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..translate(_offset.dx, _offset.dy)
                      ..scale(_scale),
                    child: widget.child,
                  ),
                ),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _handleDown(event, size),
                    onPointerMove: (event) => _handleMove(event, size),
                    onPointerUp: (event) => _handleUp(event, size),
                    onPointerCancel: _handleCancel,
                  ),
                ),
                if (widget.trackballMode && widget.inputEnabled)
                  Positioned(
                    left: _screenFor(_trackball, size).dx - 12,
                    top: _screenFor(_trackball, size).dy - 12,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1.6),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 5,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_scale > 1.02)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _scale = 1;
                            _offset = Offset.zero;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(130),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            '${_scale.toStringAsFixed(1)}x · 点击重置',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ),
                      ),
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
