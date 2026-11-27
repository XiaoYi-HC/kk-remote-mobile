/// 账号状态事件的全局通道。
///
/// 信令层（远程会话、被控共享）收到服务端 `account.expired` 时，
/// 通过这里通知 AuthProvider 强制退出并弹出提示，避免各层重复持有鉴权状态。
class AccountSessionNotice {
  AccountSessionNotice._();

  static final AccountSessionNotice instance = AccountSessionNotice._();

  void Function(String message)? onExpired;

  void notifyExpired(String message) {
    onExpired?.call(message);
  }
}
