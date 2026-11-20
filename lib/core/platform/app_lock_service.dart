import 'package:local_auth/local_auth.dart';

/// 生物识别/系统密码解锁。
class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      return supported && (canCheck || biometrics.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// 设备是否具备可用的锁屏密码或生物识别能力。
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = '验证身份以解锁 KK远程'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
