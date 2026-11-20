import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/mobile_page.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  void initState() {
    super.initState();
    // 当前版本仅提供简体中文，进入页面时把历史遗留的其他语言设置纠正回来。
    final settings = context.read<SettingsProvider>();
    if (settings.language != 'zh-CN') {
      settings.setString(SettingsKeys.language, 'zh-CN');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MobilePage(
      title: '语言与地区',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsGroup(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              SettingsTile(
                title: '简体中文',
                subtitle: 'Chinese (Simplified)',
                trailing: settings.language == 'zh-CN'
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {},
                showDivider: false,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              '当前版本界面仅支持简体中文，繁体中文、英语、日语、韩语等语言将在后续版本开放。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
