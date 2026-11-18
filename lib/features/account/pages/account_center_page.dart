import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/user.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/user_avatar.dart';
import '../../auth/state/auth_provider.dart';

class AccountCenterPage extends StatefulWidget {
  const AccountCenterPage({super.key});

  @override
  State<AccountCenterPage> createState() => _AccountCenterPageState();
}

class _AccountCenterPageState extends State<AccountCenterPage> {
  List<UserIdentity> _identities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    await auth.refreshProfile();
    try {
      _identities = await context.read<AppServices>().accountApi.identities();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: '退出登录',
      content: '退出后需要重新登录才能同步设备与消息。',
      confirmText: '退出登录',
      danger: true,
    );
    if (!ok) return;
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          title: const Text('账号中心'),
        ),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('去登录'),
          ),
        ),
      );
    }
    final user = auth.user;
    final boundProviders = _identities.map((item) => item.provider).toSet();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('账号中心'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && user == null
                ? const LoadingView()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          size: 58,
                          avatar: auth.user?.avatar ?? '',
                          name: auth.displayName,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.username ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.signature.isNotEmpty == true
                                    ? user!.signature
                                    : '这个人很懒，还没有填写签名',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await context.push('/account/profile');
                            _load();
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('编辑', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroup(
                    padding: EdgeInsets.zero,
                    children: [
                      SettingsTile(
                        title: '手机号',
                        subtitle: Formatters.maskedAccount(user?.phone),
                        trailing: const Text('换绑', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        onTap: () => context.push('/account/bind?type=phone'),
                      ),
                      SettingsTile(
                        title: '邮箱',
                        subtitle: Formatters.maskedAccount(user?.email),
                        trailing: const Text('换绑', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        onTap: () => context.push('/account/bind?type=email'),
                        showDivider: false,
                      ),
                    ],
                  ),
                  const SettingsSectionTitle('账号安全'),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        title: '修改密码',
                        subtitle: '定期修改密码可提升账号安全',
                        leading: const IconBadge(icon: Icons.lock_outline_rounded),
                        onTap: () => context.push('/account/password'),
                      ),
                      SettingsTile(
                        title: '两步验证（2FA）',
                        subtitle: user?.totpEnabled == true ? '已开启' : '未开启',
                        leading: const IconBadge(icon: Icons.verified_user_outlined),
                        onTap: () async {
                          await context.push('/account/2fa');
                          _load();
                        },
                      ),
                      SettingsTile(
                        title: '登录设备管理',
                        subtitle: '查看在线设备并强制下线',
                        leading: const IconBadge(icon: Icons.devices_other_rounded),
                        onTap: () => context.push('/account/login-devices'),
                      ),
                      SettingsTile(
                        title: '第三方账号绑定',
                        subtitle: boundProviders.isEmpty
                            ? '未绑定任何第三方账号'
                            : '已绑定 ${boundProviders.length} 个渠道',
                        leading: const IconBadge(icon: Icons.link_rounded),
                        onTap: () async {
                          await context.push('/account/identities');
                          _load();
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                  const SettingsSectionTitle('消息与安全'),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        title: '消息中心',
                        subtitle: '公告、客服回复与设备告警',
                        leading: const IconBadge(icon: Icons.mark_email_unread_outlined),
                        trailing: (auth.user?.unreadMessages ?? 0) > 0
                            ? Badge(label: Text('${auth.user!.unreadMessages}'))
                            : null,
                        onTap: () async {
                          await context.push('/account/messages');
                          _load();
                        },
                      ),
                      SettingsTile(
                        title: '注销账号',
                        subtitle: user?.deletionRequestedAt != null
                            ? '注销申请处理中，可在注销页撤销'
                            : '申请注销后将进入冷静期',
                        leading: const IconBadge(icon: Icons.person_remove_outlined),
                        onTap: () async {
                          await context.push('/account/deletion');
                          _load();
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: SizedBox(
                height: 44,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('退出登录'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
