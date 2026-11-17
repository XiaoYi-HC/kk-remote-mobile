import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_services.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const _languages = [
    ('zh-CN', '简体中文', 'Chinese (Simplified)'),
    ('zh-TW', '繁體中文', 'Chinese (Traditional)'),
    ('en-US', 'English', 'English'),
    ('ja-JP', '日本語', 'Japanese'),
    ('ko-KR', '한국어', 'Korean'),
  ];

  bool _loading = false;

  Future<void> _select(String lang) async {
    final settings = context.read<SettingsProvider>();
    if (settings.language == lang) return;
    setState(() => _loading = true);
    try {
      final messages = await context.read<AppServices>().authApi.i18n(lang);
      await settings.setMapValue('i18n_pack_$lang', messages);
      await settings.setString(SettingsKeys.language, lang);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换为${_label(lang)}，界面语言即时刷新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语言包加载失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(String lang) {
    for (final item in _languages) {
      if (item.$1 == lang) return item.$2;
    }
    return lang;
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
        title: const Text('语言与地区'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          SettingsGroup(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: _languages
                .map(
                  (item) => SettingsTile(
                    title: item.$2,
                    subtitle: item.$3,
                    trailing: settings.language == item.$1
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () => _select(item.$1),
                    showDivider: item != _languages.last,
                  ),
                )
                .toList(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              '界面语言资源由后台统一下发，与桌面端和 Web 后台共用同一套语言包。部分系统提示会跟随手机系统语言。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
