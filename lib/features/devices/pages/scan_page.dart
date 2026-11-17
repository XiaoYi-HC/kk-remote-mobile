import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../state/connect_args.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final result = _parse(raw);
      if (result == null) continue;
      _handled = true;
      _controller.stop();
      context.pushReplacement(
        '/connect',
        extra: ConnectArgs(
          deviceCode: result.deviceCode,
          deviceName: result.deviceName,
          showBindOption: true,
        ),
      );
      return;
    }
  }

  _ScanResult? _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // 支持 JSON、kkremote:// 深链与普通文本识别码。
    if (text.startsWith('{')) {
      try {
        final map = asMap(jsonDecode(text));
        final code = asString(map['deviceCode'] ?? map['code'] ?? map['device']);
        if (code.isNotEmpty) {
          return _ScanResult(code, asString(map['name'] ?? map['deviceName']));
        }
      } catch (_) {}
    }
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'kkremote' || uri.hasQuery)) {
      final code = uri.queryParameters['deviceCode'] ??
          uri.queryParameters['code'] ??
          uri.queryParameters['device'];
      if (code != null && code.isNotEmpty) {
        return _ScanResult(code, uri.queryParameters['name'] ?? '');
      }
    }
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length >= 6 && compact.length <= 24) {
      return _ScanResult(compact, '');
    }
    setState(() => _error = '未识别到有效的 KK远程 设备二维码');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('扫码连接', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: '手电筒',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '将电脑端 KK远程 的二维码放入框内',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '识别成功后将自动填充识别码',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 36,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(190),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanResult {
  const _ScanResult(this.deviceCode, this.deviceName);

  final String deviceCode;
  final String deviceName;
}
