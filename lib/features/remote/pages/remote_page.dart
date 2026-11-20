import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/models/remote.dart';
import '../../../widgets/app_select.dart';
import '../../../data/models/virtual_layout.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/settings_widgets.dart';
import '../state/remote_args.dart';
import '../state/remote_input_controller.dart';
import '../state/remote_session_provider.dart';
import '../widgets/connect_loading.dart';
import '../widgets/gamepad_panel.dart';
import '../widgets/privacy_dialog.dart';
import '../widgets/remote_gesture_layer.dart';
import '../widgets/remote_indicator.dart';
import '../widgets/remote_sheets.dart';
import '../widgets/remote_toolbar.dart';
import '../widgets/transport_badge.dart';
import '../widgets/virtual_keyboard.dart';

class RemotePage extends StatefulWidget {
  const RemotePage({super.key, required this.args});

  final RemoteArgs args;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> with WidgetsBindingObserver {
  static const _layoutKey = 'gamepad_layout_current';

  late final RemoteSessionProvider _session;
  late final RemoteInputController _input;
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loadingVisible = true;
  bool _keyboardVisible = false;
  bool _gamepadVisible = false;
  bool _gamepadEditing = false;
  bool _orientationLocked = false;
  bool _leaving = false;
  bool _showingTransport = false;
  bool _noVideoCheckScheduled = false;
  bool _wasBackground = false;
  bool _imeFocused = false;
  bool _pipSupported = false;
  bool _recordingSupported = false;
  bool _castSupported = false;
  VirtualKeyLayout _layout = VirtualKeyLayout.defaultShooter();
  Offset _virtualCursor = const Offset(0.5, 0.5);

  Timer? _recordingTimer;
  Timer? _resumeWatchdog;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String _networkLabel = '当前网络';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final services = context.read<AppServices>();
    final settings = context.read<SettingsProvider>();
    final config = context.read<ConfigProvider>();
    _session = RemoteSessionProvider(
      services: services,
      settings: settings,
      args: widget.args,
      iceServers: config.config.iceServers,
    );
    RemoteSessionRegistry.instance.current = _session;
    _session.addListener(_onSessionChanged);
    _input = RemoteInputController(_session);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _orientationLocked = settings.orientationLock != 'auto';
    _loadLayout();
    // 原生能力门控：未接入的能力不展示入口，避免用户点进死路。
    Future.wait([
      services.native.isSupported('pip'),
      services.native.isSupported('recording'),
      services.native.isSupported('cast'),
    ]).then((values) {
      if (!mounted) return;
      setState(() {
        _pipSupported = values[0];
        _recordingSupported = values[1];
        _castSupported = values[2];
      });
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => _networkLabel = _networkLabelFor(results));
      if (results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          results.contains(ConnectivityResult.none) == false) {
        _showMessage('已切换到移动网络，可在设置中开启仅 WiFi 连接');
      }
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _networkLabel = _networkLabelFor(results));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _session.start();
      if (!mounted) return;
      await _applyOrientation(settings.orientationLock);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _input.releaseAll();
    _recordingTimer?.cancel();
    _resumeWatchdog?.cancel();
    _connectivitySub?.cancel();
    _session.removeListener(_onSessionChanged);
    if (RemoteSessionRegistry.instance.current == _session) {
      RemoteSessionRegistry.instance.current = null;
    }
    final session = _session;
    if (_leaving) {
      session.dispose();
    } else {
      // 非常规退出（路由被移除等）也要先停止录制，避免原生录屏在后台持续运行。
      if (session.recording) {
        unawaited(session.stopRecording());
      }
      session.endSession().whenComplete(session.dispose);
    }
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_session.connected) {
      if (_loadingVisible) {
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _loadingVisible = false);
        });
      }
      if (!_noVideoCheckScheduled) {
        _noVideoCheckScheduled = true;
        Future<void>.delayed(const Duration(seconds: 6), () {
          if (!mounted || !_session.connected) return;
          final width = _session.renderer?.value.width ?? 0;
          if (width == 0) {
            _showMessage('已连接但未收到画面，长按顶部延迟可查看画面诊断');
          }
        });
      }
    } else if (!_session.connected) {
      _noVideoCheckScheduled = false;
      if (_session.stage == RemoteStage.failed && !_loadingVisible) {
        setState(() => _loadingVisible = true);
      }
    }
    setState(() {});
  }

  Future<void> _showVideoDiagnostics() async {
    final info = _session.videoDiagnostics;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('画面诊断'),
        content: SelectableText(
          info.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLayout() async {
    final settings = context.read<SettingsProvider>();
    final map = settings.getMapOverride(_layoutKey);
    if (map.isNotEmpty) {
      try {
        final layout = VirtualKeyLayout.fromJson(map);
        if (layout.buttons.isNotEmpty) {
          setState(() => _layout = layout);
        }
      } catch (_) {}
    }
  }

  Future<void> _saveLayout() async {
    await context.read<SettingsProvider>().setMapValue(_layoutKey, _layout.toJson());
    _showMessage('按键布局已保存');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 实体键盘/蓝牙键盘事件桥接；输入法获得焦点时不拦截，交给系统组词。
  bool _onHardwareKey(KeyEvent event) {
    if (!mounted || !_keyboardVisible || _imeFocused) return false;
    // 有弹窗/底部面板打开时，键盘事件交给弹窗处理。
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final code = domCodeFor(event.logicalKey);
    if (code == null) return false;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _input.keyDown(code);
    } else if (event is KeyUpEvent) {
      _input.keyUp(code);
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackground = true;
      // 切后台前抬起所有按键，避免被控端 Ctrl/W 等按键卡住。
      _session.releaseAllKeys();
      _resumeWatchdog?.cancel();
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackground) {
      _wasBackground = false;
      final settings = context.read<SettingsProvider>();
      if (!_session.connected && settings.autoReconnect && !_leaving) {
        setState(() => _loadingVisible = true);
        _session.manualReconnect();
        _showMessage('已回到前台，正在恢复远程会话');
      }
      // 不再主动读取系统剪贴板：iOS 16+ 会因此反复弹出“允许粘贴”授权。
      _scheduleResumeHealthCheck();
    }
  }

  /// 回前台后检查媒体是否恢复；仍无画面/无统计时自动重连。
  void _scheduleResumeHealthCheck() {
    _resumeWatchdog?.cancel();
    _resumeWatchdog = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_session.connected) return;
      final noFrame = (_session.renderer?.value.width ?? 0) == 0;
      if (noFrame || _session.mediaStale) {
        _showMessage('画面未恢复，正在重新建立会话');
        setState(() => _loadingVisible = true);
        _session.manualReconnect();
      }
    });
  }

  Future<void> _requestLeave() async {
    if (_leaving) return;
    if (_session.connected) {
      final ok = await showConfirmDialog(
        context,
        title: '断开远程连接',
        content: '断开后将结束当前远程会话，是否继续？',
        confirmText: '断开连接',
        danger: true,
      );
      if (!ok) return;
    }
    await _leave();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _input.releaseAll();
    if (_session.recording) {
      await _session.stopRecording();
    }
    await _session.endSession();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _takeScreenshot() async {
    try {
      final settings = context.read<SettingsProvider>();
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('画面尚未就绪');
      final image = await boundary.toImage(pixelRatio: 1.6);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) throw Exception('截图编码失败');
        final dir = await _downloadDirectory(settings);
        final file = File(p.join(
          dir.path,
          'KK远程截图_${DateTime.now().millisecondsSinceEpoch}.png',
        ));
        await file.writeAsBytes(byteData.buffer.asUint8List());
        // 优先写入系统相册；失败时保留沙盒文件路径，至少不丢失截图。
        final savedToGallery =
            await context.read<AppServices>().native.saveImageToGallery(file.path);
        if (!mounted) return;
        _showMessage(savedToGallery ? '截图已保存到相册' : '截图已保存：${file.path}');
      } finally {
        image.dispose();
      }
    } catch (e) {
      _showMessage('截图失败：$e');
    }
  }

  Future<Directory> _downloadDirectory(SettingsProvider settings) async {
    final configured = settings.downloadDir;
    if (configured.isNotEmpty) {
      final dir = Directory(configured);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final downloads = await getDownloadsDirectory();
    final dir = downloads == null
        ? Directory(p.join((await getApplicationDocumentsDirectory()).path, 'KK远程'))
        : Directory(p.join(downloads.path, 'KK远程'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _toggleRecording() async {
    if (_session.recording) {
      final path = await _session.stopRecording();
      _recordingTimer?.cancel();
      setState(() => _recordingDuration = Duration.zero);
      _showMessage(path == null ? '录制已停止' : '录制已保存：$path');
      return;
    }
    final ok = await _session.startRecording();
    if (!ok) {
      _showMessage('当前平台暂未接入屏幕录制，请在原生侧实现 recorder 通道');
      return;
    }
    _recordingTimer?.cancel();
    setState(() => _recordingDuration = Duration.zero);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
    _showMessage('开始录制远程会话');
  }

  Future<void> _openPip() async {
    final ok = await _session.enterPip();
    if (!ok) {
      await showInfoDialog(
        context,
        title: '悬浮小窗不可用',
        content: '当前设备不支持画中画，或尚未授予悬浮窗权限。请在系统设置中允许 KK远程 显示在其他应用上层。',
      );
    } else {
      _showMessage('已进入悬浮小窗');
    }
  }

  Future<void> _toggleCast() async {
    if (_session.castingActive) {
      await _session.stopCasting();
      _showMessage('已停止反向投屏');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: '反向投屏',
      content: '将手机屏幕画面推送到已连接的电脑，电脑端可查看手机屏幕。投屏会额外占用带宽。',
      confirmText: '开始投屏',
    );
    if (!ok) return;
    final started = await _session.startCasting();
    setState(() {});
    if (!started) {
      await showInfoDialog(
        context,
        title: '投屏能力未接入',
        content: '当前版本已预留媒体投影通道，原生侧实现 startCast 后即可使用。',
      );
    } else {
      _showMessage('反向投屏已开启');
    }
  }

  Future<void> _togglePrivacy() async {
    // 弹窗期间可能收到服务端 privacy.sync，先固定本次目标值。
    final target = !_session.privacyBlackScreen;
    final enabled = await showPrivacyDialog(
      context,
      currentlyEnabled: _session.privacyBlackScreen,
    );
    if (!enabled || !mounted) return;
    await _session.togglePrivacy(target);
    _showMessage(target ? '隐私黑屏已开启' : '隐私黑屏已关闭');
  }

  Future<void> _toggleOrientation() async {
    final next = !_orientationLocked;
    // 与设置页共用 portrait/landscape/auto 语义：锁定当前物理方向，而不是含糊的 locked。
    final mode = next
        ? (MediaQuery.of(context).orientation == Orientation.portrait
            ? 'portrait'
            : 'landscape')
        : 'auto';
    setState(() => _orientationLocked = next);
    await _applyOrientation(mode);
    await context.read<SettingsProvider>().setString(SettingsKeys.orientationLock, mode);
    _showMessage(next ? '已锁定当前屏幕方向' : '已恢复自动旋转');
  }

  Future<void> _applyOrientation(String mode) async {
    switch (mode) {
      case 'portrait':
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        break;
      case 'landscape':
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
      case 'locked':
        // 兼容旧版本保存的 locked：按当前物理方向锁定。
        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
        await SystemChrome.setPreferredOrientations(
          isPortrait
              ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
              : const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        );
        break;
      default:
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<void> _openSystemActions() async {
    await showSystemActionsSheet(
      context,
      onAction: (action) {
        if (action == 'lock_input') {
          _session.toggleAntiTouch();
          return;
        }
        _session.requestSystemAction(action);
        _showMessage('系统操作已发送：$action');
      },
    );
  }

  Future<void> _openClipboard() async {
    final settings = context.read<SettingsProvider>();
    await showAppSheet<void>(
      context,
      title: '剪贴板同步',
      subtitle: '手机与被控电脑互相粘贴文字',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSwitchTile(
                  title: '开启剪贴板同步',
                  subtitle: '开启后可手动粘贴手机剪贴板到电脑',
                  value: settings.clipboardSync,
                  onChanged: (value) async {
                    await settings.setBool(SettingsKeys.clipboardSync, value);
                    setSheetState(() {});
                  },
                  showDivider: false,
                ),
                const SizedBox(height: 10),
                AppSecondaryButton(
                  label: '粘贴手机剪贴板到电脑',
                  icon: Icons.content_paste_go_rounded,
                  onPressed: () async {
                    await _session.pasteFromPhone();
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    _showMessage('已发送剪贴板文字');
                  },
                ),
                const SizedBox(height: 10),
                AppSecondaryButton(
                  label: '输入文字发送到电脑',
                  icon: Icons.keyboard_rounded,
                  onPressed: () async {
                    final text = await showTextInputDialog(
                      context,
                      title: '发送文字',
                      hint: '支持中文输入',
                      maxLength: 500,
                      maxLines: 3,
                    );
                    if (text != null && text.isNotEmpty) {
                      _session.sendText(text);
                      _showMessage('文字已发送');
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openChineseInput() async {
    final text = await showTextInputDialog(
      context,
      title: '中文输入',
      hint: '输入完成后发送到被控电脑',
      maxLength: 500,
      maxLines: 3,
    );
    if (text != null && text.isNotEmpty) {
      _session.sendText(text);
    }
  }

  Future<void> _openFiles() async {
    await context.push('/remote/files');
  }

  Future<void> _openDisplaySwitch() async {
    _session.requestDisplayList();
    await showDisplaySwitchSheet(
      context,
      displays: _session.displays,
      activeId: _session.activeDisplayId,
      onSelect: _session.switchDisplay,
    );
  }

  Future<void> _openQuality() async {
    await showQualitySheet(
      context,
      onApply: ({
        required String preset,
        required int fps,
        required int bitrateKbps,
        required double resolutionScale,
        required String encoder,
      }) {
        _session.updateQuality(
          preset: preset,
          fps: fps,
          bitrateKbps: bitrateKbps,
          resolutionScale: resolutionScale,
          encoder: encoder,
        );
        _showMessage('画质设置已应用');
      },
    );
  }

  Future<void> _openCamera() async {
    await showCameraSheet(
      context,
      enabled: _session.cameraState['enabled'] == true,
      onToggle: _session.toggleCameraPreview,
    );
  }

  Future<void> _showTransportDetails() async {
    if (_showingTransport) return;
    _showingTransport = true;
    await showTransportDetails(
      context,
      transport: _session.transport,
      connected: _session.connected,
    );
    _showingTransport = false;
  }

  Future<void> _toggleViewOnly() async {
    _session.setViewOnly(!_session.viewOnly);
    _showMessage(_session.viewOnly ? '已切换为观看模式，键鼠输入已暂停' : '已切换为控制模式');
  }

  Future<void> _toggleAntiTouch() async {
    if (_session.antiTouch) {
      _session.unlockAntiTouch();
      _showMessage('防误触已解锁');
      return;
    }
    _session.toggleAntiTouch();
    _showMessage('防误触已锁定，触摸不再转发');
  }

  Future<void> _toggleKeyboard() async {
    // 切换面板时先抬起按键，避免被控端残留 Ctrl/Shift。
    _input.releaseAll();
    setState(() {
      _keyboardVisible = !_keyboardVisible;
      if (_keyboardVisible) _gamepadVisible = false;
    });
  }

  Future<void> _toggleGamepad() async {
    _input.releaseAll();
    setState(() {
      _gamepadVisible = !_gamepadVisible;
      if (_gamepadVisible) _keyboardVisible = false;
    });
  }

  Future<void> _toggleFavorite(String code, String label, bool favorite) async {
    final settings = context.read<SettingsProvider>();
    final list = List<String>.from(settings.hotkeyFavorites);
    if (favorite) {
      list.remove(code);
      _showMessage('已取消收藏 $label');
    } else {
      if (!list.contains(code)) list.add(code);
      _showMessage('已收藏 $label，显示在快捷键行');
    }
    await settings.setList(SettingsKeys.hotkeyFavorites, list);
    setState(() {});
  }

  Future<VirtualButton?> _promptButton({VirtualButton? existing}) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final codeController = TextEditingController(text: existing?.keyCode ?? '');
    String type = existing?.type ?? 'key';
    final result = await showDialog<VirtualButton>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加虚拟按键' : '编辑虚拟按键'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: '按键文字'),
                maxLength: 8,
              ),
              const SizedBox(height: 8),
              AppSelectField<String>(
                label: '按键类型',
                valueLabel: const {
                  'key': '键盘按键',
                  'mouseLeft': '鼠标左键',
                  'mouseRight': '鼠标右键',
                  'joystick': '虚拟摇杆',
                }[type] ?? '键盘按键',
                options: const [
                  AppSelectOption(value: 'key', label: '键盘按键'),
                  AppSelectOption(value: 'mouseLeft', label: '鼠标左键'),
                  AppSelectOption(value: 'mouseRight', label: '鼠标右键'),
                  AppSelectOption(value: 'joystick', label: '虚拟摇杆'),
                ],
                onChanged: (value) => setDialogState(() => type = value),
              ),
              if (type == 'key') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '按键代码',
                    hintText: '例如 KeyW、Space、ControlLeft',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                if (label.isEmpty) return;
                Navigator.of(dialogContext).pop(
                  VirtualButton(
                    id: existing?.id ??
                        'btn_${DateTime.now().microsecondsSinceEpoch}',
                    label: label,
                    x: existing?.x ?? 0.45,
                    y: existing?.y ?? 0.75,
                    width: existing?.width ?? (type == 'joystick' ? 0.22 : 0.09),
                    height: existing?.height ?? (type == 'joystick' ? 0.18 : 0.07),
                    type: type,
                    keyCode: codeController.text.trim(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    codeController.dispose();
    return result;
  }

  Future<void> _addGamepadButton() async {
    final button = await _promptButton();
    if (button == null) return;
    setState(() {
      _layout = _layout.copyWith(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: '自定义布局',
        builtin: false,
        buttons: [..._layout.buttons, button],
      );
    });
    await _saveLayout();
  }

  Future<void> _editGamepadButton(VirtualButton button) async {
    final updated = await _promptButton(existing: button);
    if (updated == null) return;
    setState(() {
      _layout = _layout.copyWith(
        builtin: false,
        buttons: _layout.buttons
            .map((item) => item.id == button.id ? updated : item)
            .toList(),
      );
    });
    await _saveLayout();
  }

  Future<void> _deleteGamepadButton(VirtualButton button) async {
    setState(() {
      _layout = _layout.copyWith(
        builtin: false,
        buttons: _layout.buttons.where((item) => item.id != button.id).toList(),
      );
    });
    await _saveLayout();
  }

  Future<void> _importLayout() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final content = await File(path).readAsString();
      final layout = VirtualKeyLayout.fromJson(asMap(jsonDecode(content)));
      if (layout.buttons.isEmpty) throw Exception('布局文件没有按键');
      setState(() {
        _layout = layout.copyWith(
          id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
          builtin: false,
        );
      });
      await _saveLayout();
      _showMessage('已导入布局：${layout.name}');
    } catch (e) {
      _showMessage('导入失败：$e');
    }
  }

  Future<void> _exportLayout() async {
    try {
      final settings = context.read<SettingsProvider>();
      final dir = await _downloadDirectory(settings);
      final file = File(p.join(dir.path, 'KK远程按键布局_${DateTime.now().millisecondsSinceEpoch}.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(_layout.toJson()));
      _showMessage('布局已导出：${file.path}');
    } catch (e) {
      _showMessage('导出失败：$e');
    }
  }

  Future<void> _showLayoutQr() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('分享按键布局'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: jsonEncode(_layout.toJson()),
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_layout.name} · ${_layout.buttons.length} 个按键',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              '使用 KK远程 扫码即可导入',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreDefaultLayout() async {
    final ok = await showConfirmDialog(
      context,
      title: '恢复默认布局',
      content: '当前自定义按键将被默认射击布局替换，是否继续？',
      confirmText: '恢复默认',
    );
    if (!ok) return;
    setState(() {
      _layout = VirtualKeyLayout.defaultShooter();
      _gamepadEditing = false;
    });
    await _saveLayout();
  }

  void _onJoystick(Offset delta, double sensitivity) {
    final next = Offset(
      (_virtualCursor.dx + delta.dx * sensitivity).clamp(0.0, 1.0).toDouble(),
      (_virtualCursor.dy + delta.dy * sensitivity).clamp(0.0, 1.0).toDouble(),
    );
    _virtualCursor = next;
    _session.mouseMove(next.dx, next.dy);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RemoteSessionProvider>.value(
      value: _session,
      child: Consumer2<RemoteSessionProvider, SettingsProvider>(
        builder: (context, session, settings, _) {
          final connected = session.connected;
          final videoSize = session.renderer?.value;
          final videoWidth = videoSize?.width ?? 0;
          final videoHeight = videoSize?.height ?? 0;
          final videoAspectRatio =
              (videoWidth > 0 && videoHeight > 0) ? videoWidth / videoHeight : null;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              // 返回键分级：先收输入法，再收键盘/手柄，最后才询问断开。
              if (_imeFocused) {
                FocusManager.instance.primaryFocus?.unfocus();
                return;
              }
              if (_keyboardVisible) {
                _input.releaseAll();
                setState(() => _keyboardVisible = false);
                return;
              }
              if (_gamepadVisible) {
                _input.releaseAll();
                setState(() => _gamepadVisible = false);
                return;
              }
              if (!_leaving) _requestLeave();
            },
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: AppColors.videoBackground,
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: Container(
                        color: AppColors.videoBackground,
                        child: RemoteGestureLayer(
                          inputEnabled: session.canForwardInput,
                          trackballMode: session.trackballMode,
                          touchSensitivity:
                              settings.touchSensitivity * settings.gestureSensitivity,
                          scrollSensitivity: settings.scrollSensitivity,
                          hapticsEnabled: settings.hapticsEnabled,
                          videoAspectRatio: videoAspectRatio,
                          onMove: (x, y) {
                            // 与虚拟手柄共用同一个光标坐标，避免"看到的"和"点到的"位置不一致。
                            _virtualCursor = Offset(x, y);
                            session.mouseMove(x, y);
                          },
                          onLeftClick: session.leftClick,
                          onRightClick: session.rightClick,
                          onWheel: session.wheel,
                          onThreeFingerTap: settings.threeFingerEnabled
                              ? () => setState(() => _gamepadVisible = !_gamepadVisible)
                              : null,
                          child: session.renderer == null
                              ? _buildVideoPlaceholder(session)
                              : RTCVideoView(
                                  session.renderer!,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                  mirror: false,
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (session.privacyBlackScreen)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withAlpha(140),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white70,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '隐私黑屏已开启',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '被控电脑本地屏幕已隐藏',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _togglePrivacy,
                                child: const Text('关闭隐私黑屏'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_gamepadVisible)
                    Positioned.fill(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 52, bottom: 108),
                          child: GamepadPanel(
                            layout: _layout,
                            editing: _gamepadEditing,
                            onEditingChanged: (value) => setState(() => _gamepadEditing = value),
                            onLayoutChanged: (layout) => setState(() => _layout = layout),
                            onKey: (code, down) =>
                                down ? _input.keyDown(code) : _input.keyUp(code),
                            onMouse: (button, down) {
                              if (down) {
                                session.mouseDown(_virtualCursor.dx, _virtualCursor.dy, button: button);
                              } else {
                                session.mouseUp(_virtualCursor.dx, _virtualCursor.dy, button: button);
                              }
                            },
                            onJoystick: _onJoystick,
                            onAddButton: _addGamepadButton,
                            onEditButton: _editGamepadButton,
                            onDeleteButton: _deleteGamepadButton,
                            onSave: _saveLayout,
                            onImport: _importLayout,
                            onExport: _exportLayout,
                            onShowQr: _showLayoutQr,
                            onRestoreDefault: _restoreDefaultLayout,
                            onClose: () {
                              _input.releaseAll();
                              setState(() => _gamepadVisible = false);
                            },
                            hapticsEnabled: settings.hapticsEnabled,
                          ),
                        ),
                      ),
                    ),
                  if (session.antiTouch)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          session.unlockAntiTouch();
                          _showMessage('防误触已解锁');
                        },
                        child: Container(
                          color: Colors.black.withAlpha(60),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded, color: Colors.white70, size: 26),
                                SizedBox(height: 8),
                                Text(
                                  '防误触已锁定\n触摸不会转发到电脑，点击解锁',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                TransportBadge(
                                  transport: session.transport,
                                  connected: connected,
                                  onTap: _showTransportDetails,
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onLongPress: _showVideoDiagnostics,
                                  child: RemoteIndicator(
                                    latencyMs: session.transport.rttMs,
                                    lossRate: session.transport.lossRate,
                                    trafficBytes: session.trafficBytes,
                                    networkType: _networkLabel,
                                    onTap: _showTransportDetails,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _circleButton(
                                  icon: Icons.monitor_rounded,
                                  tooltip: '切换显示器',
                                  onTap: _openDisplaySwitch,
                                  badge: session.displays.length > 1
                                      ? '${session.displays.length}'
                                      : null,
                                ),
                              ],
                            ),
                            if (session.viewOnly)
                              _statusBanner(
                                icon: Icons.visibility_rounded,
                                text: '观看模式 · 键鼠输入已暂停',
                                color: AppColors.primary,
                              ),
                            if (session.privacyBlackScreen)
                              _statusBanner(
                                icon: Icons.visibility_off_rounded,
                                text: '隐私黑屏已开启，对方本地屏幕已隐藏',
                                color: AppColors.warning,
                                action: TextButton(
                                  onPressed: _togglePrivacy,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 28),
                                    foregroundColor: AppColors.warning,
                                  ),
                                  child: const Text('关闭', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            if (session.transport.isRelay)
                              _statusBanner(
                                icon: Icons.cloud_queue_rounded,
                                text: '当前通过中继传输，延迟可能略高',
                                color: AppColors.relay,
                              ),
                            if (session.recording)
                              _statusBanner(
                                icon: Icons.fiber_manual_record_rounded,
                                text:
                                    '录制中 ${Formatters.duration(_recordingDuration)}',
                                color: AppColors.danger,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    // resizeToAvoidBottomInset=false，这里显式避让输入法。
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_keyboardVisible)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: _keyboardMaxHeight(context),
                              ),
                              child: SingleChildScrollView(
                                child: VirtualKeyboard(
                                  favoriteCodes: settings.hotkeyFavorites,
                                  hapticsEnabled: settings.hapticsEnabled,
                                  onKeyDown: (code, repeatable) =>
                                      _input.keyDown(code, repeatable: repeatable),
                                  onKeyUp: _input.keyUp,
                                  onText: (text) => session.sendText(text),
                                  onLongText: _openChineseInput,
                                  onCombo: _session.keyCombo,
                                  onSystemAction: _session.requestSystemAction,
                                  onImeFocusChanged: (focused) => _imeFocused = focused,
                                  onClose: () {
                                    _input.releaseAll();
                                    setState(() => _keyboardVisible = false);
                                  },
                                  onToggleFavorite: _toggleFavorite,
                                ),
                              ),
                            ),
                          RemoteToolbar(
                            keyboardVisible: _keyboardVisible,
                            gamepadVisible: _gamepadVisible,
                            viewOnly: session.viewOnly,
                            antiTouch: session.antiTouch,
                            recording: session.recording,
                            pipActive: session.pipActive,
                            castingActive: session.castingActive,
                            privacyEnabled: session.privacyBlackScreen,
                            orientationLocked: _orientationLocked,
                            onDisconnect: _requestLeave,
                            onKeyboard: _toggleKeyboard,
                            onGamepad: _toggleGamepad,
                            onFiles: _openFiles,
                            onSystemActions: _openSystemActions,
                            onDisplaySwitch: _openDisplaySwitch,
                            onToggleViewOnly: _toggleViewOnly,
                            onToggleAntiTouch: _toggleAntiTouch,
                            onScreenshot: _takeScreenshot,
                            onRecording: _toggleRecording,
                            showRecording: _recordingSupported,
                            onPip: _openPip,
                            showPip: _pipSupported,
                            onCast: _toggleCast,
                            showCast: _castSupported,
                            onQuality: _openQuality,
                            onCamera: _openCamera,
                            onPrivacy: _togglePrivacy,
                            onOrientationLock: _toggleOrientation,
                            onClipboard: _openClipboard,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ConnectLoading(
                      stage: session.stage,
                      failure: session.failure,
                      visible: _loadingVisible,
                      notice: session.connectionNotice,
                      onCancel: _leave,
                      onRetry: () {
                        setState(() => _loadingVisible = true);
                        session.manualReconnect();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlaceholder(RemoteSessionProvider session) {
    return Container(
      color: AppColors.videoBackground,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Text(
            session.connected ? '正在接收远程画面…' : '等待建立媒体连接',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  double _keyboardMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = (media.size.height - media.viewInsets.bottom - 110)
        .clamp(160.0, media.size.height)
        .toDouble();
    final factor = media.orientation == Orientation.landscape ? 0.7 : 0.6;
    return available * factor;
  }

  String _networkLabelFor(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.ethernet)) return '有线网络';
    if (results.contains(ConnectivityResult.mobile)) return '移动网络';
    if (results.contains(ConnectivityResult.none)) return '无网络';
    return '当前网络';
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 15, color: Colors.white70),
              if (badge != null)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(fontSize: 7, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String text,
    required Color color,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 10.5, color: color)),
          if (action != null) ...[
            const SizedBox(width: 4),
            action,
          ],
        ],
      ),
    );
  }
}
