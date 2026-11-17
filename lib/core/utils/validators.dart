class Validators {
  Validators._();

  static final RegExp phonePattern = RegExp(r'^1[3-9]\d{9}$');
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp codePattern = RegExp(r'^\d{6}$');

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入手机号';
    if (!phonePattern.hasMatch(text)) return '手机号格式不正确';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入邮箱';
    if (!emailPattern.hasMatch(text)) return '邮箱格式不正确';
    return null;
  }

  static String? code(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入验证码';
    if (!codePattern.hasMatch(text)) return '请输入 6 位数字验证码';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请输入密码';
    if (text.length < 8) return '密码至少 8 位';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    final hasDigit = RegExp(r'\d').hasMatch(text);
    if (!hasLetter || !hasDigit) return '密码需包含字母和数字';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return '请再次输入密码';
    if (value != password) return '两次输入的密码不一致';
    return null;
  }

  static String? deviceCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入设备识别码';
    if (text.length < 6) return '识别码格式不正确';
    return null;
  }

  static String? verifyCodeOrPassword(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入验证码或无人值守密码';
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '请输入$label';
    return null;
  }

  static int passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score.clamp(0, 4).toInt();
  }

  static String passwordStrengthLabel(int score) {
    switch (score) {
      case 0:
        return '请输入密码';
      case 1:
        return '弱';
      case 2:
        return '一般';
      case 3:
        return '强';
      default:
        return '很强';
    }
  }
}
