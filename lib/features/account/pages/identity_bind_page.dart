import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/common.dart';
import '../../../data/models/user.dart';
import '../../../state/app_services.dart';
import '../../../state/config_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';

class IdentityBindPage extends StatefulWidget {
  const IdentityBindPage({super.key});

  @override
  State<IdentityBindPage> createState() => _IdentityBindPageState();
}

class _IdentityBindPageState extends State<IdentityBindPage> {
  List<UserIdentity> _identities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _identities = await context.read<AppServices>().accountApi.identities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  UserIdentity? _identityFor(String provider) {
    for (final item in _identities) {
      if (item.provider == provider) return item;
    }
    return null;
  }

  Future<void> _bind(ThirdPartyChannel channel) async {
    try {
      final services = context.read<AppServices>();
      final data = await services.accountApi.bindUrl(channel.provider);
      final url = Uri.tryParse(data['url']?.toString() ?? '');
      final state = data['state']?.toString() ?? '';
      if (url == null) throw Exception('授权地址无效');
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      final code = await showTextInputDialog(
        context,
        title: '绑定${channel.name}',
        hint: '完成授权后粘贴回调 code',
        confirmText: '完成绑定',
        maxLength: 512,
      );
      if (code == null || code.isEmpty) return;
      await services.accountApi.bindIdentity(channel.provider, code: code, state: state);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已绑定${channel.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _unbind(ThirdPartyChannel channel) async {
    final ok = await showConfirmDialog(
      context,
      title: '解绑${channel.name}',
      content: '解绑后将无法使用${channel.name}快捷登录，是否继续？',
      confirmText: '解绑',
      danger: true,
    );
    if (!ok) return;
    try {
      await context.read<AppServices>().accountApi.unbindIdentity(channel.provider);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final channels = config.config.thirdPartyChannels;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('第三方账号绑定'),
      ),
      body: _loading
          ? const LoadingView()
          : channels.isEmpty
              ? const EmptyState(
                  icon: Icons.link_off_rounded,
                  title: '暂无可绑定的第三方渠道',
                  description: '后台未启用或未配置完整的第三方渠道不会显示',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      ...channels.map((channel) {
                        final identity = _identityFor(channel.provider);
                        final bound = identity != null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: channel.provider == 'apple'
                                    ? const Icon(Icons.apple, size: 22)
                                    : Text(
                                        AppConstants.providerGlyphs[channel.provider] ??
                                            channel.name.characters.first,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel.name.isEmpty
                                          ? (AppConstants.providerNames[channel.provider] ?? channel.provider)
                                          : channel.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      bound
                                          ? '已绑定 ${Formatters.maskedAccount(identity.maskedOpenId)}'
                                          : '未绑定',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: bound ? AppColors.success : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (bound)
                                TextButton(
                                  onPressed: () => _unbind(channel),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(52, 34),
                                    foregroundColor: AppColors.danger,
                                  ),
                                  child: const Text('解绑', style: TextStyle(fontSize: 11)),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () => _bind(channel),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(72, 34),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  child: const Text('去绑定', style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          '可绑定的渠道以后台启用的第三方渠道为准。解绑前请确保已设置密码或绑定手机/邮箱，避免无法登录。',
                          style: TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
