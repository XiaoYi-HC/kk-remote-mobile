import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/settings_widgets.dart';

class AudioSettingsPage extends StatelessWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('音频'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsSectionTitle('远程声音'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '播放远程声音',
                subtitle: '接收并播放被控电脑的系统声音',
                value: settings.audioEnabled,
                onChanged: (value) => settings.setBool(SettingsKeys.audioEnabled, value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('播放音量', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          '${(settings.volume * 100).round()}%',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.volume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: settings.audioEnabled
                          ? (value) => settings.setDouble(SettingsKeys.volume, value)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SettingsSectionTitle('麦克风'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: '麦克风透传',
                subtitle: '将手机麦克风声音发送到被控电脑，用于语音沟通',
                value: settings.micPassthrough,
                onChanged: (value) => settings.setBool(SettingsKeys.micPassthrough, value),
                showDivider: false,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              '提示：远程声音与麦克风透传会额外占用带宽。使用移动网络时建议开启流量节省或在 WiFi 下使用。',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
