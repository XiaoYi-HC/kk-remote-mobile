import 'dart:async';

import 'package:flutter/services.dart';

import 'remote_session_provider.dart';

/// 统一管理远程按键状态：按下集合、长按连发、修饰键。
///
/// 虚拟键盘、游戏手柄与实体键盘全部走这里，退出会话时统一抬起，避免被控端按键卡住。
class RemoteInputController {
  RemoteInputController(this._session);

  final RemoteSessionProvider _session;

  final Set<String> _held = <String>{};
  final Map<String, Timer> _repeatTimers = <String, Timer>{};

  static const _repeatDelay = Duration(milliseconds: 420);
  static const _repeatInterval = Duration(milliseconds: 45);

  bool get hasHeldKeys => _held.isNotEmpty;

  void tap(String code) {
    keyDown(code);
    Future<void>.delayed(const Duration(milliseconds: 28), () => keyUp(code));
  }

  void keyDown(String code, {bool repeatable = false}) {
    _held.add(code);
    // 物理键盘的自动重复会连续产生 KeyRepeatEvent，这里每次都转发 keydown。
    _session.key(code, true);
    if (repeatable) _startRepeat(code);
  }

  void keyUp(String code) {
    _repeatTimers.remove(code)?.cancel();
    if (_held.remove(code)) {
      _session.key(code, false);
    }
  }

  void _startRepeat(String code) {
    _repeatTimers.remove(code)?.cancel();
    _repeatTimers[code] = Timer(_repeatDelay, () {
      _repeatTimers[code] = Timer.periodic(_repeatInterval, (_) {
        // Windows 的按键自动重复依赖重复 keydown，这里显式补发。
        _session.key(code, true);
      });
    });
  }

  void toggleModifier(String code) {
    if (_held.contains(code)) {
      keyUp(code);
    } else {
      keyDown(code);
    }
  }

  /// 退出会话、切后台、关闭键盘时调用。
  void releaseAll() {
    for (final timer in _repeatTimers.values) {
      timer.cancel();
    }
    _repeatTimers.clear();
    for (final code in _held.toList()) {
      _session.key(code, false);
    }
    _held.clear();
    _session.releaseAllKeys();
  }
}

/// 实体键盘逻辑键到 W3C DOM code 的映射，供被控端解析。
String? domCodeFor(LogicalKeyboardKey key) {
  final fixed = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.controlLeft: 'ControlLeft',
    LogicalKeyboardKey.controlRight: 'ControlRight',
    LogicalKeyboardKey.shiftLeft: 'ShiftLeft',
    LogicalKeyboardKey.shiftRight: 'ShiftRight',
    LogicalKeyboardKey.altLeft: 'AltLeft',
    LogicalKeyboardKey.altRight: 'AltRight',
    LogicalKeyboardKey.metaLeft: 'MetaLeft',
    LogicalKeyboardKey.metaRight: 'MetaRight',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'NumpadEnter',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.insert: 'Insert',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.capsLock: 'CapsLock',
    LogicalKeyboardKey.numLock: 'NumLock',
    LogicalKeyboardKey.minus: 'Minus',
    LogicalKeyboardKey.equal: 'Equal',
    LogicalKeyboardKey.bracketLeft: 'BracketLeft',
    LogicalKeyboardKey.bracketRight: 'BracketRight',
    LogicalKeyboardKey.backslash: 'Backslash',
    LogicalKeyboardKey.semicolon: 'Semicolon',
    LogicalKeyboardKey.quote: 'Quote',
    LogicalKeyboardKey.comma: 'Comma',
    LogicalKeyboardKey.period: 'Period',
    LogicalKeyboardKey.slash: 'Slash',
    LogicalKeyboardKey.backquote: 'Backquote',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };
  final mapped = fixed[key];
  if (mapped != null) return mapped;
  final id = key.keyId;
  if (id >= 0x61 && id <= 0x7A) {
    return 'Key${String.fromCharCode(id).toUpperCase()}';
  }
  if (id >= 0x30 && id <= 0x39) {
    return 'Digit${String.fromCharCode(id)}';
  }
  return null;
}
