import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';

class AccessibilityPage extends StatefulWidget {
  const AccessibilityPage({super.key});

  @override
  State<AccessibilityPage> createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SettingsProvider>().setBool(SettingsKeys.accessibilityGuideSeen, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('无障碍引导'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E6FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.accessibility_new_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'KK远程 无障碍说明',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'KK远程 已为按钮、输入框、设备卡片、远程工具栏与弹窗补充可读标签，适配系统屏幕阅读器（TalkBack / VoiceOver）。视障用户可通过读屏完成登录、连接设备与查看状态。',
                  style: TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SettingsSectionTitle('读屏操作建议'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideItem(
                  index: '1',
                  title: '开启系统读屏',
                  content: '在手机系统设置中开启 TalkBack 或 VoiceOver，KK远程 会自动适配焦点顺序。',
                ),
                _GuideItem(
                  index: '2',
                  title: '连接设备',
                  content: '首页的“识别码”按钮可读出功能说明，双击进入后输入识别码与验证码。',
                ),
                _GuideItem(
                  index: '3',
                  title: '远程画面',
                  content: '远程画面区域会朗读手势说明；工具栏按钮均可单独聚焦，双击执行。',
                ),
                _GuideItem(
                  index: '4',
                  title: '观看模式',
                  content: '若仅需旁听或演示，可在工具栏切换观看模式，避免误触被控电脑。',
                ),
              ],
            ),
          ),
          const SettingsSectionTitle('显示与反馈'),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('字体大小', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          '${(settings.fontScale * 100).round()}%',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.fontScale,
                      min: 0.85,
                      max: 1.4,
                      divisions: 11,
                      label: '${(settings.fontScale * 100).round()}%',
                      onChanged: (value) => settings.setDouble(SettingsKeys.fontScale, value),
                    ),
                  ],
                ),
              ),
              SettingsSwitchTile(
                title: '按键震动反馈',
                subtitle: '为触控操作提供触感提示',
                value: settings.hapticsEnabled,
                onChanged: (value) => settings.setBool(SettingsKeys.hapticsEnabled, value),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '如需进一步帮助，可在“帮助与反馈”中联系在线客服。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.index, required this.title, required this.content});

  final String index;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Text(
              index,
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
