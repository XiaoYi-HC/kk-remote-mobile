import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/json_utils.dart';
import '../state/connect_args.dart';

/// 扫一扫页面。
///
/// 视觉与交互参考主流 App（微信 / 支付宝 / Telegram）：
/// 全屏预览 + 四角扫描框 + 半透明遮罩 + 相册识别 / 手电筒。
/// 识别内核保持 mobile_scanner 不变，仅重构 UI 与性能参数。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _accent = Color(0xFF2EE6A8);
  static const Duration _successDelay = Duration(milliseconds: 520);

  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    // 限制采集分辨率（Android 生效），降低 CPU / 内存占用，提升预览流畅度。
    cameraResolution: const Size(1280, 720),
    torchEnabled: false,
    // 由页面自己控制启动时机，先申请权限再开流。
    autoStart: false,
  );

  final ImagePicker _picker = ImagePicker();

  late final AnimationController _lineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _handled = false;
  bool _success = false;
  bool _picking = false;
  bool _initialized = false;
  bool _starting = true;
  bool _permissionDenied = false;
  TorchState _torchState = TorchState.unavailable;
  MobileScannerException? _cameraError;
  String? _hint;
  Timer? _hintTimer;
  DateTime _lastHintAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _awaitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onScannerStateChanged);
    _bootstrap();
  }

  /// 进入页面立刻申请相机权限。
  ///
  /// 这里直接由 mobile_scanner 调用系统相机授权（AVCaptureDevice），
  /// 不依赖 permission_handler 的 iOS 权限宏配置，避免出现“永远拒绝且在设置里看不到开关”的问题。
  Future<void> _bootstrap() async {
    try {
      await _controller.start();
    } catch (_) {
      // 具体错误会通过 controller 状态回传。
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _permissionDenied =
          _controller.value.error?.errorCode == MobileScannerErrorCode.permissionDenied;
    });
  }

  @override
  void dispose() {
    // 离开页面立刻释放摄像头，避免后台占用与发热。
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _controller.removeListener(_onScannerStateChanged);
    // 先停流再释放，避免平台侧 stop/dispose 交错调用。
    final controller = _controller;
    unawaited(() async {
      await controller.stop();
      await controller.dispose();
    }());
    _lineController.dispose();
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置返回后重建页面，让相机以最新权限状态重新初始化。
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      if (_permissionDenied && mounted) {
        context.pushReplacement('/scan');
      }
      return;
    }
    // 退到后台时主动停流，回到前台再恢复。
    if (_handled || _permissionDenied) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.start());
    }
  }

  void _onScannerStateChanged() {
    if (!mounted) return;
    final value = _controller.value;
    final denied =
        value.error?.errorCode == MobileScannerErrorCode.permissionDenied;
    final changed = _initialized != value.isInitialized ||
        _torchState != value.torchState ||
        _cameraError?.errorCode != value.error?.errorCode ||
        _permissionDenied != denied;
    if (!changed) return;
    setState(() {
      _initialized = value.isInitialized;
      _torchState = value.torchState;
      _cameraError = value.error;
      // 运行中权限被系统收回时也要更新，否则重试按钮永远不会走"去设置"分支。
      _permissionDenied = denied;
    });
  }

  /// 低调提示：不弹窗，底部轻提示，2 秒内不重复。
  void _showHint(String text, {bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastHintAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastHintAt = now;
    _hintTimer?.cancel();
    setState(() => _hint = text);
    _hintTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _success) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final result = _parse(raw);
      if (result != null) {
        _handled = true;
        _succeed(result);
        return;
      }
    }
    _showHint('未识别到有效的 KK远程 设备二维码');
  }

  Future<void> _succeed(_ScanResult result) async {
    if (!mounted) return;
    setState(() => _success = true);
    _flashController.forward(from: 0);
    await Future<void>.delayed(_successDelay);
    if (!mounted) return;
    context.pushReplacement(
      '/connect',
      extra: ConnectArgs(
        deviceCode: result.deviceCode,
        deviceName: result.deviceName,
        showBindOption: true,
      ),
    );
  }

  _ScanResult? _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // 支持 JSON、kkremote:// 深链与普通文本识别码。
    if (text.startsWith('{')) {
      try {
        final map = asMap(jsonDecode(text));
        final code = asString(map['deviceCode'] ?? map['code'] ?? map['device']);
        if (_isDeviceCode(code)) {
          return _ScanResult(code, asString(map['name'] ?? map['deviceName']));
        }
      } catch (_) {}
    }
    final uri = Uri.tryParse(text);
    if (uri != null &&
        (uri.scheme == 'kkremote' || uri.scheme == 'http' || uri.scheme == 'https')) {
      final code = uri.queryParameters['deviceCode'] ??
          uri.queryParameters['code'] ??
          uri.queryParameters['device'];
      if (code != null && _isDeviceCode(code)) {
        return _ScanResult(code, uri.queryParameters['name'] ?? '');
      }
    }
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (_isDeviceCode(compact)) {
      return _ScanResult(compact, '');
    }
    return null;
  }

  /// 设备识别码为 6~12 位数字，避免把网址/普通文本误当识别码。
  bool _isDeviceCode(String value) => RegExp(r'^\d{6,12}$').hasMatch(value.trim());

  /// 相册识图：沿用 mobile_scanner 的图片分析能力。
  Future<void> _pickFromGallery() async {
    if (_picking || _success) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final capture = await _controller.analyzeImage(file.path);
      final barcodes = capture?.barcodes ?? const <Barcode>[];
      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.isEmpty) continue;
        final result = _parse(raw);
        if (result != null) {
          _handled = true;
          await _succeed(result);
          return;
        }
      }
      _showHint('未识别到有效的 KK远程 设备二维码', force: true);
    } catch (_) {
      _showHint('图片识别失败，请换一张更清晰的二维码截图', force: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _toggleTorch() async {
    if (!_initialized) return;
    if (_torchState == TorchState.unavailable) {
      _showHint('当前设备不支持闪光灯', force: true);
      return;
    }
    try {
      await _controller.toggleTorch();
    } catch (_) {
      _showHint('闪光灯不可用', force: true);
    }
  }

  Future<void> _retryCamera() async {
    if (_permissionDenied) {
      // iOS 首次拒绝后系统不会再次弹窗，只能引导用户去设置里开启。
      _awaitingSettings = true;
      await openAppSettings();
      return;
    }
    setState(() {
      _starting = true;
      _cameraError = null;
    });
    try {
      await _controller.start();
    } catch (_) {
      _showHint('摄像头启动失败，请稍后重试', force: true);
    }
    if (mounted) setState(() => _starting = false);
  }

  String get _errorTitle {
    switch (_cameraError?.errorCode) {
      case MobileScannerErrorCode.unsupported:
        return '当前设备不支持扫码';
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerUninitialized:
        return '摄像头未就绪';
      default:
        return '摄像头打开失败';
    }
  }

  String get _errorDescription {
    return '请检查相机是否被其他应用占用，或稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final frameSize = math.min(width * 0.68, 280.0);
          final centerY = height / 2 - 20;
          final scanRect = Rect.fromCenter(
            center: Offset(width / 2, centerY),
            width: frameSize,
            height: frameSize,
          );
          final showError = _permissionDenied || _cameraError != null;
          final ready = _initialized && !showError;
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: scanRect,
                errorBuilder: (context, error, child) =>
                    const SizedBox.shrink(),
                placeholderBuilder: (context, child) =>
                    const SizedBox.shrink(),
              ),
              // 半透明遮罩，只保留扫码区域可见。
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MaskPainter(scanRect: scanRect),
                  ),
                ),
              ),
              // 四角高亮 + 扫描线（局部重绘，避免全屏动画开销）。
              Positioned.fromRect(
                rect: scanRect,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                      [_lineController, _pulseController],
                    ),
                    builder: (context, child) => CustomPaint(
                      painter: _ScanFramePainter(
                        lineProgress: _lineController.value,
                        pulse: _pulseController.value,
                        color: _accent,
                      ),
                    ),
                  ),
                ),
              ),
              if (ready && !_success)
                Positioned(
                  top: scanRect.bottom + 22,
                  left: 24,
                  right: 24,
                  child: const IgnorePointer(
                    child: Column(
                      children: [
                        Text(
                          '将电脑端 KK远程 的二维码放入框内',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '识别成功后将自动填充识别码',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildTopBar(context),
              if (ready) _buildBottomActions(context),
              if (!ready && !showError && _starting) _buildLoading(),
              if (showError) _buildError(),
              if (_hint != null) _buildHint(),
              if (_success) _buildSuccessFlash(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withAlpha(150), Colors.transparent],
          ),
        ),
        child: SizedBox(
          height: 52,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    onPressed: () => context.pop(),
                    tooltip: '返回',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  '扫一扫',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 24,
          bottom: MediaQuery.paddingOf(context).bottom + 26,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(140)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScanActionButton(
              icon: Icons.photo_library_outlined,
              label: '相册',
              onTap: _pickFromGallery,
            ),
            const SizedBox(width: 64),
            _ScanActionButton(
              icon: _torchState == TorchState.on
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_outlined,
              label: '手电筒',
              active: _torchState == TorchState.on,
              onTap: _toggleTorch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(_accent),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  '正在启动摄像头…',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    final denied = _permissionDenied;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    denied
                        ? Icons.no_photography_outlined
                        : Icons.videocam_off_outlined,
                    size: 52,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    denied ? '相机权限未开启' : _errorTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    denied ? '请在系统设置中允许 KK远程 访问相机后重试' : _errorDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _retryCamera,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 10,
                      ),
                    ),
                    child: Text(denied ? '重新授权' : '重试'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      '返回',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Positioned(
      left: 32,
      right: 32,
      bottom: MediaQuery.paddingOf(context).bottom + 118,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(190),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessFlash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _flashController,
          builder: (context, child) {
            final value = _flashController.value;
            final flash = (1 - value).clamp(0.0, 1.0);
            final appear = (value * 2.2).clamp(0.0, 1.0).toDouble();
            final scale = 0.82 + 0.18 * Curves.easeOutBack.transform(value);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withAlpha((150 * flash).round())),
                Center(
                  child: Opacity(
                    opacity: appear,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: _accent.withAlpha(38),
                          shape: BoxShape.circle,
                          border: Border.all(color: _accent, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 46,
                          color: _accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 扫码区域以外的半透明遮罩。
class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.scanRect});

  final Rect scanRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(22)));
    final path = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(path, Paint()..color = Colors.black.withAlpha(145));
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) =>
      oldDelegate.scanRect != scanRect;
}

/// 四角高亮 + 循环扫描线（带拖影）+ 轻微呼吸。
class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({
    required this.lineProgress,
    required this.pulse,
    required this.color,
  });

  final double lineProgress;
  final double pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLength = 26.0;
    const strokeWidth = 3.0;
    final w = size.width;
    final h = size.height;

    canvas.save();
    // 呼吸：整体 1.0 ~ 1.015 轻微缩放。
    final scale = 1 + 0.015 * pulse;
    canvas.translate(w / 2, h / 2);
    canvas.scale(scale);
    canvas.translate(-w / 2, -h / 2);

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final corners = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, 0)
      ..lineTo(cornerLength, 0)
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w, 0)
      ..lineTo(w, cornerLength)
      ..moveTo(w, h - cornerLength)
      ..lineTo(w, h)
      ..lineTo(w - cornerLength, h)
      ..moveTo(cornerLength, h)
      ..lineTo(0, h)
      ..lineTo(0, h - cornerLength);
    canvas.drawPath(corners, cornerPaint);

    // 扫描线：从上往下循环，上方带淡拖影。
    const trailLength = 48.0;
    final y = (h - 4) * lineProgress;
    if (y > 1) {
      final trailRect = Rect.fromLTWH(
        0,
        math.max(0.0, y - trailLength),
        w,
        math.min(y, trailLength),
      );
      if (trailRect.height > 0) {
        final shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x002EE6A8), Color(0x462EE6A8), Color(0xDC2EE6A8)],
        ).createShader(trailRect);
        canvas.drawRect(trailRect, Paint()..shader = shader);
      }
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = color.withAlpha(235)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.lineProgress != lineProgress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color;
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const accent = _ScanPageState._accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? accent.withAlpha(40)
                  : Colors.white.withAlpha(30),
              border: Border.all(
                color: active
                    ? accent.withAlpha(170)
                    : Colors.white.withAlpha(42),
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: active ? accent : Colors.white,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? accent : Colors.white70,
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
