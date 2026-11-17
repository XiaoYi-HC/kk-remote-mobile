import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RemoteToolbar extends StatefulWidget {
  const RemoteToolbar({
    super.key,
    required this.keyboardVisible,
    required this.gamepadVisible,
    required this.viewOnly,
    required this.antiTouch,
    required this.recording,
    required this.pipActive,
    required this.castingActive,
    required this.privacyEnabled,
    required this.orientationLocked,
    required this.onDisconnect,
    required this.onKeyboard,
    required this.onGamepad,
    required this.onFiles,
    required this.onSystemActions,
    required this.onDisplaySwitch,
    required this.onToggleViewOnly,
    required this.onToggleAntiTouch,
    required this.onScreenshot,
    required this.onRecording,
    required this.onPip,
    required this.onCast,
    required this.onQuality,
    required this.onCamera,
    required this.onPrivacy,
    required this.onOrientationLock,
    required this.onClipboard,
  });

  final bool keyboardVisible;
  final bool gamepadVisible;
  final bool viewOnly;
  final bool antiTouch;
  final bool recording;
  final bool pipActive;
  final bool castingActive;
  final bool privacyEnabled;
  final bool orientationLocked;

  final VoidCallback onDisconnect;
  final VoidCallback onKeyboard;
  final VoidCallback onGamepad;
  final VoidCallback onFiles;
  final VoidCallback onSystemActions;
  final VoidCallback onDisplaySwitch;
  final VoidCallback onToggleViewOnly;
  final VoidCallback onToggleAntiTouch;
  final VoidCallback onScreenshot;
  final VoidCallback onRecording;
  final VoidCallback onPip;
  final VoidCallback onCast;
  final VoidCallback onQuality;
  final VoidCallback onCamera;
  final VoidCallback onPrivacy;
  final VoidCallback onOrientationLock;
  final VoidCallback onClipboard;

  @override
  State<RemoteToolbar> createState() => _RemoteToolbarState();
}

class _RemoteToolbarState extends State<RemoteToolbar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final items = <_ToolItem>[
      _ToolItem(
        label: '断开',
        icon: Icons.power_settings_new_rounded,
        color: AppColors.danger,
        onTap: widget.onDisconnect,
      ),
      _ToolItem(
        label: '键盘',
        icon: Icons.keyboard_alt_outlined,
        active: widget.keyboardVisible,
        onTap: widget.onKeyboard,
      ),
      _ToolItem(
        label: '游戏按键',
        icon: Icons.sports_esports_outlined,
        active: widget.gamepadVisible,
        onTap: widget.onGamepad,
      ),
      _ToolItem(
        label: '文件',
        icon: Icons.folder_outlined,
        onTap: widget.onFiles,
      ),
      _ToolItem(
        label: '系统操作',
        icon: Icons.settings_suggest_outlined,
        onTap: widget.onSystemActions,
      ),
      _ToolItem(
        label: '显示器',
        icon: Icons.monitor_rounded,
        onTap: widget.onDisplaySwitch,
      ),
      _ToolItem(
        label: widget.viewOnly ? '观看中' : '观看模式',
        icon: widget.viewOnly ? Icons.visibility_rounded : Icons.visibility_outlined,
        active: widget.viewOnly,
        onTap: widget.onToggleViewOnly,
      ),
      _ToolItem(
        label: '防误触',
        icon: widget.antiTouch ? Icons.lock_rounded : Icons.lock_open_rounded,
        active: widget.antiTouch,
        onTap: widget.onToggleAntiTouch,
      ),
      _ToolItem(
        label: '截图',
        icon: Icons.photo_camera_outlined,
        onTap: widget.onScreenshot,
      ),
      _ToolItem(
        label: widget.recording ? '停止录制' : '录制',
        icon: widget.recording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded,
        active: widget.recording,
        color: widget.recording ? AppColors.danger : null,
        onTap: widget.onRecording,
      ),
      _ToolItem(
        label: '悬浮小窗',
        icon: Icons.picture_in_picture_alt_rounded,
        active: widget.pipActive,
        onTap: widget.onPip,
      ),
      _ToolItem(
        label: '投屏',
        icon: Icons.screen_share_rounded,
        active: widget.castingActive,
        onTap: widget.onCast,
      ),
      _ToolItem(
        label: '画质',
        icon: Icons.tune_rounded,
        onTap: widget.onQuality,
      ),
      _ToolItem(
        label: '摄像头',
        icon: Icons.videocam_outlined,
        onTap: widget.onCamera,
      ),
      _ToolItem(
        label: '隐私黑屏',
        icon: widget.privacyEnabled ? Icons.visibility_off_rounded : Icons.visibility_outlined,
        active: widget.privacyEnabled,
        onTap: widget.onPrivacy,
      ),
      _ToolItem(
        label: '方向锁定',
        icon: widget.orientationLocked ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded,
        active: widget.orientationLocked,
        onTap: widget.onOrientationLock,
      ),
      _ToolItem(
        label: '剪贴板',
        icon: Icons.content_paste_rounded,
        onTap: widget.onClipboard,
      ),
    ];

    return Container(
      color: const Color(0xD91A1D23),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _collapsed ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _collapsed ? '展开工具栏' : '收起工具栏',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                    ),
                    if (widget.recording) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('录制中', style: TextStyle(fontSize: 10, color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ToolButton(item: items[index]),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  _ToolItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? color;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.item});

  final _ToolItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? (item.active ? AppColors.primary : Colors.white70);
    return Semantics(
      button: true,
      label: item.label,
      selected: item.active,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.active ? AppColors.primary.withAlpha(40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 19, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 9, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
