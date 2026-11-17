import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../models/device.dart';

/// 局域网 UDP 广播发现：发送探测包并接收被控端响应。
/// 包格式与桌面端约定：{ magic, type:"kkremote.device", deviceCode, name, ... }
class LanDiscoveryService {
  LanDiscoveryService();

  RawDatagramSocket? _socket;
  Timer? _probeTimer;
  Timer? _timeoutTimer;
  final Map<String, LanDevice> _found = {};
  bool _scanning = false;

  final StreamController<List<LanDevice>> _controller =
      StreamController<List<LanDevice>>.broadcast();

  Stream<List<LanDevice>> get devices => _controller.stream;
  bool get isScanning => _scanning;

  Future<void> start({int port = AppConstants.defaultLanPort}) async {
    if (_scanning) return;
    _scanning = true;
    _found.clear();
    _emit();
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram == null) return;
            final device = LanDevice.tryParse(
              utf8.decode(datagram.data, allowMalformed: true),
              datagram.address.address,
            );
            if (device != null) {
              _found[device.deviceCode] = device;
              _emit();
            }
          }
        },
        onError: (Object error) {
          if (kDebugMode) debugPrint('LAN discovery error: $error');
        },
      );
      _sendProbe(port);
      _probeTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendProbe(port));
      _timeoutTimer = Timer(const Duration(seconds: 8), stop);
    } catch (error) {
      if (kDebugMode) debugPrint('LAN bind failed: $error');
      _scanning = false;
    }
  }

  void _sendProbe(int port) {
    final socket = _socket;
    if (socket == null) return;
    final payload = jsonEncode({
      'magic': AppConstants.lanMagic,
      'type': 'kkremote.discover',
      'client': 'mobile',
      'version': AppConstants.appVersion,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    final data = utf8.encode(payload);
    try {
      socket.send(data, InternetAddress('255.255.255.255'), port);
    } catch (_) {
      // 部分系统禁用全局广播，忽略即可，用户仍可使用识别码连接。
    }
  }

  void _emit() {
    final list = _found.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!_controller.isClosed) _controller.add(list);
  }

  Future<void> stop() async {
    _probeTimer?.cancel();
    _probeTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _socket?.close();
    _socket = null;
    _scanning = false;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
