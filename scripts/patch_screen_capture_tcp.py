#!/usr/bin/env python3
"""把 flutter_webrtc 的 iOS 屏幕共享从 App Group Unix Socket 改为 127.0.0.1 TCP。

未签名 IPA 重签后通常拿不到 App Group 权限，containerURL 会返回 nil，
插件会把 nil 路径传给 unlink/strncpy 直接崩溃。改为本机 TCP 后不再依赖 App Group。

必须在 flutter pub get 之后、pod install 之前执行（直接修改 pub-cache 里的插件源码）。
兼容 flutter_webrtc 0.11.x（ios/Classes/Broadcast）与 1.6.x（ios/flutter_webrtc/Sources/...）两种目录结构。
任何一步打补丁失败都会以非 0 退出，避免构建出一个点了就闪退的包。
"""
import glob
import os
import re
import sys

PORT = 39876


def lock_version():
    lock = os.path.join(os.getcwd(), 'pubspec.lock')
    if not os.path.isfile(lock):
        return None
    with open(lock, 'r') as handle:
        content = handle.read()
    match = re.search(r'flutter_webrtc:\s*\n(?:.*\n)*?\s*version:\s*"([^"]+)"', content)
    return match.group(1) if match else None


def plugin_dir():
    roots = []
    if os.environ.get('PUB_CACHE'):
        roots.append(os.environ['PUB_CACHE'])
    roots.append(os.path.expanduser('~/.pub-cache'))
    version = lock_version()
    for root in roots:
        hosted = os.path.join(root, 'hosted', 'pub.dev')
        if not os.path.isdir(hosted):
            continue
        if version:
            candidate = os.path.join(hosted, 'flutter_webrtc-' + version)
            if os.path.isfile(os.path.join(candidate, 'pubspec.yaml')):
                return candidate
        for path in sorted(glob.glob(os.path.join(hosted, 'flutter_webrtc-*')), reverse=True):
            if os.path.isfile(os.path.join(path, 'pubspec.yaml')):
                return path
    return None


def find_file(root, name):
    for base, _, files in os.walk(os.path.join(root, 'ios')):
        if name in files:
            return os.path.join(base, name)
    return None


def replace_once(path, old, new, label):
    with open(path, 'r') as handle:
        content = handle.read()
    if new.strip() in content:
        print('already patched:', label)
        return True
    if old not in content:
        print('ERROR: anchor not found in', label)
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w') as handle:
        handle.write(content)
    print('patched:', label)
    return True


def insert_before(path, marker, text, label):
    return replace_once(path, marker, text + marker, label)


def main():
    root = plugin_dir()
    if not root:
        print('ERROR: flutter_webrtc not found in pub cache')
        return 1
    print('flutter_webrtc:', root)
    header = find_file(root, 'FlutterSocketConnection.h')
    impl = find_file(root, 'FlutterSocketConnection.m')
    capturer = find_file(root, 'FlutterBroadcastScreenCapturer.m')
    if not (header and impl and capturer):
        print('ERROR: broadcast screen capturer sources not found:',
              header, impl, capturer)
        return 1

    ok = True
    ok &= insert_before(
        header,
        '- (void)openWithStreamDelegate:',
        '- (instancetype)initWithTCPPort:(uint16_t)port;\n',
        'FlutterSocketConnection.h',
    )

    ok &= insert_before(
        impl,
        '#import "FlutterSocketConnection.h"',
        '#include <netinet/in.h>\n\n',
        'FlutterSocketConnection.m (netinet)',
    )

    # 防御：即使有人仍然走 initWithFilePath:，nil 路径也不能崩。
    nil_guard = '''- (instancetype)initWithFilePath:(nonnull NSString*)filePath {
  if (filePath.length == 0) {
    NSLog(@"failure: empty socket file path");
    return nil;
  }
'''
    ok &= replace_once(
        impl,
        '- (instancetype)initWithFilePath:(nonnull NSString*)filePath {\n',
        nil_guard,
        'FlutterSocketConnection.m (nil guard)',
    )

    tcp_init = '''- (instancetype)initWithTCPPort:(uint16_t)port {
  self = [super init];
  if (!self) {
    return nil;
  }
  [self setupNetworkThread];
  self.serverSocket = socket(AF_INET, SOCK_STREAM, 0);
  if (self.serverSocket < 0) {
    NSLog(@"failure creating tcp socket");
    return nil;
  }
  int reuse = 1;
  setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (bind(self.serverSocket, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    NSLog(@"failure binding tcp socket");
    close(self.serverSocket);
    return nil;
  }
  return self;
}

'''
    ok &= insert_before(
        impl,
        '- (void)openWithStreamDelegate:',
        tcp_init,
        'FlutterSocketConnection.m (tcp init)',
    )

    old_start = '''- (void)startCapture {
  if (!self.appGroupIdentifier) {
    return;
  }

  NSString* socketFilePath = [self filePathForApplicationGroupIdentifier:self.appGroupIdentifier];
  FlutterSocketConnectionFrameReader* frameReader =
      [[FlutterSocketConnectionFrameReader alloc] initWithDelegate:self.delegate];
  FlutterSocketConnection* connection =
      [[FlutterSocketConnection alloc] initWithFilePath:socketFilePath];
  self.capturer = frameReader;
  [self.capturer startCaptureWithConnection:connection];
}'''
    new_start = '''- (void)startCapture {
  FlutterSocketConnectionFrameReader* frameReader =
      [[FlutterSocketConnectionFrameReader alloc] initWithDelegate:self.delegate];
  FlutterSocketConnection* connection =
      [[FlutterSocketConnection alloc] initWithTCPPort:%d];
  self.capturer = frameReader;
  [self.capturer startCaptureWithConnection:connection];
}''' % PORT
    ok &= replace_once(capturer, old_start, new_start, 'FlutterBroadcastScreenCapturer.m')

    if not ok:
        print('ERROR: screen capture TCP patch failed')
        return 1
    print('screen capture tcp patch ok (port %d)' % PORT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
