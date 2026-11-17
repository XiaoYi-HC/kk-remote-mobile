import '../../core/utils/json_utils.dart';

class VirtualButton {
  const VirtualButton({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.width = 0.1,
    this.height = 0.07,
    this.type = 'key',
    this.keyCode = '',
    this.action = '',
    this.modifiers = const [],
    this.opacity = 0.55,
  });

  final String id;
  final String label;

  /// 相对画面宽高的比例坐标（0~1），保证不同分辨率下布局一致。
  final double x;
  final double y;
  final double width;
  final double height;

  /// key / mouseLeft / mouseRight / joystick / text / toggle
  final String type;
  final String keyCode;
  final String action;
  final List<String> modifiers;
  final double opacity;

  bool get isJoystick => type == 'joystick';
  bool get isMouse => type == 'mouseLeft' || type == 'mouseRight';

  VirtualButton copyWith({
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    String? type,
    String? keyCode,
    String? action,
    List<String>? modifiers,
  }) {
    return VirtualButton(
      id: id,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      type: type ?? this.type,
      keyCode: keyCode ?? this.keyCode,
      action: action ?? this.action,
      modifiers: modifiers ?? this.modifiers,
      opacity: opacity,
    );
  }

  factory VirtualButton.fromJson(Map<String, dynamic> json) {
    return VirtualButton(
      id: asString(json['id'], fallback: DateTime.now().microsecondsSinceEpoch.toString()),
      label: asString(json['label']),
      x: asDouble(json['x']).clamp(0, 1).toDouble(),
      y: asDouble(json['y']).clamp(0, 1).toDouble(),
      width: asDouble(json['width'], fallback: 0.1).clamp(0.04, 0.4).toDouble(),
      height: asDouble(json['height'], fallback: 0.07).clamp(0.04, 0.4).toDouble(),
      type: asString(json['type'], fallback: 'key'),
      keyCode: asString(json['keyCode']),
      action: asString(json['action']),
      modifiers: asList(json['modifiers']).map((item) => item.toString()).toList(),
      opacity: asDouble(json['opacity'], fallback: 0.55).clamp(0.2, 1).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'type': type,
        'keyCode': keyCode,
        'action': action,
        'modifiers': modifiers,
        'opacity': opacity,
      };
}

class VirtualKeyLayout {
  const VirtualKeyLayout({
    required this.id,
    required this.name,
    required this.buttons,
    this.joystickSensitivity = 1.0,
    this.builtin = false,
  });

  final String id;
  final String name;
  final List<VirtualButton> buttons;
  final double joystickSensitivity;
  final bool builtin;

  VirtualKeyLayout copyWith({
    String? id,
    String? name,
    List<VirtualButton>? buttons,
    double? joystickSensitivity,
    bool? builtin,
  }) {
    return VirtualKeyLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      buttons: buttons ?? this.buttons,
      joystickSensitivity: joystickSensitivity ?? this.joystickSensitivity,
      builtin: builtin ?? this.builtin,
    );
  }

  factory VirtualKeyLayout.fromJson(Map<String, dynamic> json) {
    return VirtualKeyLayout(
      id: asString(json['id'], fallback: 'layout'),
      name: asString(json['name'], fallback: '自定义布局'),
      buttons: asList(json['buttons']).map((item) => VirtualButton.fromJson(asMap(item))).toList(),
      joystickSensitivity: asDouble(json['joystickSensitivity'], fallback: 1.0),
      builtin: asBool(json['builtin']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'name': name,
        'buttons': buttons.map((item) => item.toJson()).toList(),
        'joystickSensitivity': joystickSensitivity,
        'builtin': builtin,
      };

  static VirtualKeyLayout defaultShooter() {
    return const VirtualKeyLayout(
      id: 'default_shooter',
      name: '默认射击布局',
      builtin: true,
      buttons: [
        VirtualButton(
          id: 'stick',
          label: '视角',
          type: 'joystick',
          x: 0.10,
          y: 0.64,
          width: 0.24,
          height: 0.20,
        ),
        VirtualButton(
          id: 'w',
          label: 'W',
          keyCode: 'KeyW',
          x: 0.12,
          y: 0.40,
          width: 0.07,
          height: 0.06,
        ),
        VirtualButton(
          id: 'a',
          label: 'A',
          keyCode: 'KeyA',
          x: 0.045,
          y: 0.47,
          width: 0.07,
          height: 0.06,
        ),
        VirtualButton(
          id: 's',
          label: 'S',
          keyCode: 'KeyS',
          x: 0.12,
          y: 0.47,
          width: 0.07,
          height: 0.06,
        ),
        VirtualButton(
          id: 'd',
          label: 'D',
          keyCode: 'KeyD',
          x: 0.195,
          y: 0.47,
          width: 0.07,
          height: 0.06,
        ),
        VirtualButton(
          id: 'shift',
          label: 'Shift',
          keyCode: 'ShiftLeft',
          x: 0.045,
          y: 0.55,
          width: 0.10,
          height: 0.06,
        ),
        VirtualButton(
          id: 'space',
          label: '空格',
          keyCode: 'Space',
          x: 0.155,
          y: 0.55,
          width: 0.11,
          height: 0.06,
        ),
        VirtualButton(
          id: 'left',
          label: '左键',
          type: 'mouseLeft',
          x: 0.78,
          y: 0.77,
          width: 0.12,
          height: 0.10,
        ),
        VirtualButton(
          id: 'right',
          label: '右键',
          type: 'mouseRight',
          x: 0.90,
          y: 0.67,
          width: 0.09,
          height: 0.09,
        ),
        VirtualButton(
          id: 'reload',
          label: 'R',
          keyCode: 'KeyR',
          x: 0.90,
          y: 0.77,
          width: 0.06,
          height: 0.06,
        ),
        VirtualButton(
          id: 'e',
          label: 'E',
          keyCode: 'KeyE',
          x: 0.78,
          y: 0.67,
          width: 0.06,
          height: 0.06,
        ),
      ],
    );
  }

  static VirtualKeyLayout defaultRacing() {
    return const VirtualKeyLayout(
      id: 'default_racing',
      name: '默认竞速布局',
      builtin: true,
      buttons: [
        VirtualButton(
          id: 'steer',
          label: '方向',
          type: 'joystick',
          x: 0.08,
          y: 0.66,
          width: 0.25,
          height: 0.22,
        ),
        VirtualButton(
          id: 'throttle',
          label: '油门',
          keyCode: 'KeyW',
          x: 0.80,
          y: 0.76,
          width: 0.10,
          height: 0.12,
        ),
        VirtualButton(
          id: 'brake',
          label: '刹车',
          keyCode: 'KeyS',
          x: 0.89,
          y: 0.76,
          width: 0.10,
          height: 0.10,
        ),
        VirtualButton(
          id: 'handbrake',
          label: '手刹',
          keyCode: 'Space',
          x: 0.80,
          y: 0.63,
          width: 0.12,
          height: 0.07,
        ),
        VirtualButton(
          id: 'reset',
          label: 'R',
          keyCode: 'KeyR',
          x: 0.90,
          y: 0.63,
          width: 0.06,
          height: 0.06,
        ),
      ],
    );
  }

  static List<VirtualKeyLayout> defaults() => [defaultShooter(), defaultRacing()];
}
