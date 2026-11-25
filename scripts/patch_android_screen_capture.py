#!/usr/bin/env python3
"""修补 flutter_webrtc 的 Android 屏幕采集，避免共享屏幕时闪退。

问题：
1. 插件会把第一次授权拿到的 MediaProjection Intent 缓存在字段里，重复调用
   getDisplayMedia 会复用同一个 token，Android 14+ 直接抛 SecurityException。
2. 授权返回后的采集启动逻辑在主线程执行，任何异常都会直接杀掉进程。
   这里包一层 try/catch，把异常转成 Dart 侧可显示的错误信息，而不是闪退。

必须在 flutter pub get 之后、flutter build apk 之前执行。
"""
import glob
import os
import re
import sys


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


def main():
    root = plugin_dir()
    if not root:
        print('ERROR: flutter_webrtc not found in pub cache')
        return 1
    print('flutter_webrtc:', root)
    target = os.path.join(
        root, 'android', 'src', 'main', 'java', 'com', 'cloudwebrtc', 'webrtc', 'GetUserMediaImpl.java')
    if not os.path.isfile(target):
        print('ERROR: GetUserMediaImpl.java not found:', target)
        return 1

    with open(target, 'r') as handle:
        content = handle.read()

    ok = True

    # 1) 授权回调里的采集启动包 try/catch，异常转成错误而不是杀进程
    old_call = '                            getDisplayMedia(result, mediaStream, mediaProjectionData);'
    new_call = '''                            try {
                                getDisplayMedia(result, mediaStream, mediaProjectionData);
                            } catch (Throwable error) {
                                Log.e(TAG, "kk-patch getDisplayMedia failed", error);
                                GetUserMediaImpl.this.mediaProjectionData = null;
                                resultError("screenRequestPermissions", "屏幕采集启动失败：" + error, result);
                            }'''
    if 'kk-patch getDisplayMedia failed' in content:
        print('already patched: try/catch')
    elif old_call in content:
        content = content.replace(old_call, new_call, 1)
        print('patched: try/catch')
    else:
        print('ERROR: onReceiveResult anchor not found')
        ok = False

    # 2) 采集成功后清空缓存的授权 Intent，下次共享重新授权
    old_start = '''        videoCapturer.startCapture(info.width, info.height, info.fps);
        Log.d(TAG, "OrientationAwareScreenCapturer.startCapture: " + info.width + "x" + info.height + "@" + info.fps);'''
    new_start = '''        videoCapturer.startCapture(info.width, info.height, info.fps);
        // kk-patch: 投影 token 只能使用一次，采集成功后清空缓存，
        // 否则第二次共享会复用同一个 Intent 触发 SecurityException。
        this.mediaProjectionData = null;
        Log.d(TAG, "OrientationAwareScreenCapturer.startCapture: " + info.width + "x" + info.height + "@" + info.fps);'''
    if 'kk-patch: 投影 token 只能使用一次' in content:
        print('already patched: clear token')
    elif old_start in content:
        content = content.replace(old_start, new_start, 1)
        print('patched: clear token')
    else:
        print('ERROR: startCapture anchor not found')
        ok = False

    if ok:
        with open(target, 'w') as handle:
            handle.write(content)
        print('android screen capture patch ok')
        return 0
    return 1


if __name__ == '__main__':
    sys.exit(main())
