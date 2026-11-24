import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/device.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/brand_logo.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/user_avatar.dart';
import '../../auth/state/auth_provider.dart';
import '../state/connect_args.dart';
import '../state/devices_provider.dart';
import '../widgets/device_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  DevicesProvider? _devices;
  bool _castMode = false;
  bool _handlingAccept = false;

  @override
  void initState() {
    super.initState();
    final devices = context.read<DevicesProvider>();
    _devices = devices;
    devices.addListener(_handleIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      devices.load();
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) auth.refreshProfile(silent: true);
      _handleIncoming();
      final settings = context.read<SettingsProvider>();
      if (!settings.accessibilityGuideSeen) {
        context.push('/settings/accessibility');
      }
    });
  }

  @override
  void dispose() {
    // dispose 阶段不能再通过 context 查 Provider，使用 initState 保存的实例。
    _devices?.removeListener(_handleIncoming);
    _searchController.dispose();
    super.dispose();
  }

  void _handleIncoming() {
    final devices = context.read<DevicesProvider>();
    if (devices.incomingAcceptRequested && !_handlingAccept && devices.incomingCall != null) {
      _handlingAccept = true;
      final call = devices.incomingCall!;
      devices.consumeIncomingAccept();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlingAccept = false;
        _openConnect(
          ConnectArgs(
            deviceCode: call.deviceCode,
            deviceName: call.displayName,
            deviceId: call.id,
            castMode: _castMode,
          ),
        );
      });
    }
  }

  Future<void> _refresh() async {
    await context.read<DevicesProvider>().refresh();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) await auth.refreshProfile(silent: true);
  }

  void _openConnect(ConnectArgs args) {
    context.push('/connect', extra: args);
  }

  void _openDevice(Device device) {
    _openConnect(
      ConnectArgs(
        deviceCode: device.deviceCode,
        deviceName: device.displayName,
        deviceId: device.id,
        isLan: device.lan,
        castMode: _castMode,
      ),
    );
  }

  Future<void> _openDeviceMenu(Device device) async {
    final provider = context.read<DevicesProvider>();
    await showAppSheet<void>(
      context,
      title: device.displayName,
      subtitle: '识别码 ${device.deviceCode}',
      heightFactor: 0.62,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
        children: [
          SheetActionTile(
            icon: Icons.cast_connected_rounded,
            title: '连接设备',
            subtitle: device.online ? '设备在线' : '设备离线，连接可能失败',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _openDevice(device);
            },
          ),
          SheetActionTile(
            icon: Icons.info_outline_rounded,
            title: '设备详情',
            subtitle: '查看最近会话、访问规则与离线指令',
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/device/${device.id}', extra: device);
            },
          ),
          SheetActionTile(
            icon: Icons.edit_note_rounded,
            title: '修改备注',
            subtitle: device.remark.isEmpty ? '未设置备注' : device.remark,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final remark = await showTextInputDialog(
                context,
                title: '修改备注',
                hint: '例如：办公室电脑',
                initialValue: device.remark,
              );
              if (remark == null) return;
              try {
                await provider.updateRemark(device, remark);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
          SheetActionTile(
            icon: Icons.folder_outlined,
            title: '移动到分组',
            subtitle: device.groupName.isEmpty ? '未分组' : device.groupName,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _chooseGroup(device);
            },
          ),
          SheetActionTile(
            icon: device.favorite ? Icons.star_rounded : Icons.star_border_rounded,
            title: device.favorite ? '取消收藏' : '收藏设备',
            onTap: () async {
              Navigator.of(sheetContext).pop();
              try {
                await provider.toggleFavorite(device);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
          SheetActionTile(
            icon: Icons.terminal_rounded,
            title: '离线指令',
            subtitle: '设备上线后自动执行',
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/settings/offline-commands?deviceId=${device.id}');
            },
          ),
          SheetActionTile(
            icon: Icons.link_off_rounded,
            title: '解绑设备',
            danger: true,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final confirmed = await showConfirmDialog(
                context,
                title: '解绑设备',
                content: '解绑后将不再同步该设备的会话与设置，是否继续？',
                confirmText: '解绑',
                danger: true,
              );
              if (!confirmed) return;
              try {
                await provider.unbind(device);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseGroup(Device device) async {
    final provider = context.read<DevicesProvider>();
    await showAppSheet<void>(
      context,
      title: '选择分组',
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          SheetActionTile(
            icon: Icons.folder_off_outlined,
            title: '未分组',
            onTap: () {
              Navigator.of(sheetContext).pop();
              provider.updateGroup(device, null);
            },
          ),
          ...provider.groups.map((group) => SheetActionTile(
                icon: Icons.folder_outlined,
                title: group.name,
                trailing: group.id == device.groupId
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  provider.updateGroup(device, group);
                },
              )),
          SheetActionTile(
            icon: Icons.create_new_folder_outlined,
            title: '新建分组',
            onTap: () async {
              final name = await showTextInputDialog(
                context,
                title: '新建分组',
                hint: '分组名称',
                maxLength: 20,
              );
              if (name == null || name.isEmpty) return;
              final group = await provider.createGroup(name);
              await provider.updateGroup(device, group);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openLanScan() async {
    final provider = context.read<DevicesProvider>();
    provider.startLanScan();
    await showAppSheet<void>(
      context,
      title: '局域网扫描',
      subtitle: '同一 WiFi 下发现设备可直接内网连接',
      heightFactor: 0.6,
      builder: (sheetContext) => Consumer<DevicesProvider>(
        builder: (context, devices, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    if (devices.lanScanning) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '正在扫描…',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ] else
                      Text(
                        '发现 ${devices.lanDevices.length} 台设备',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: devices.lanScanning ? null : devices.startLanScan,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('重新扫描', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: devices.lanDevices.isEmpty
                    ? EmptyState(
                        icon: Icons.wifi_find_rounded,
                        title: devices.lanScanning ? '正在同一 WiFi 下寻找设备' : '未发现局域网设备',
                        description: '请确认被控电脑与手机连接到同一 WiFi，且已开启 KK远程',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        children: devices.lanDevices
                            .map((lan) => LanDeviceCard(
                                  device: lan,
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    _openConnect(ConnectArgs(
                                      deviceCode: lan.deviceCode,
                                      deviceName: lan.displayName,
                                      isLan: true,
                                      lanIp: lan.ip,
                                      castMode: _castMode,
                                    ));
                                  },
                                ))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = context.watch<DevicesProvider>();
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final unread = auth.user?.unreadMessages ?? 0;
    final visible = devices.visibleDevices;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, auth, unread)),
              SliverToBoxAdapter(child: _buildHostShareCard(context)),
              if (devices.incomingCall != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: IncomingCallCard(
                      device: devices.incomingCall!,
                      source: devices.incomingSource == 'push' ? '系统推送' : '连接请求',
                      onAccept: () {
                        devices.acceptIncoming();
                      },
                      onReject: devices.dismissIncoming,
                    ),
                  ),
                ),
              if (devices.error != null)
                SliverToBoxAdapter(
                  child: InlineError(message: devices.error!, onRetry: devices.refresh),
                ),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildFilters(devices)),
              if (devices.loading && devices.devices.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingView(message: '正在同步设备…'),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: devices.devices.isNotEmpty
                      ? EmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: '没有符合条件的设备',
                          description: devices.favoriteOnly
                              ? '当前只看收藏，试试关闭收藏筛选或清空搜索关键词'
                              : '当前筛选/搜索条件下没有设备，清空筛选后重试',
                          action: OutlinedButton(
                            onPressed: () {
                              devices.setKeyword('');
                              devices.setGroup(null);
                              if (devices.favoriteOnly) devices.toggleFavoriteFilter();
                              _searchController.clear();
                            },
                            child: const Text('清空筛选'),
                          ),
                        )
                      : EmptyState(
                    icon: isLoggedIn ? Icons.devices_other_rounded : Icons.login_rounded,
                    title: isLoggedIn ? '还没有绑定设备' : '登录后查看已绑定设备',
                    description: isLoggedIn
                        ? '在「远程协助」输入被控电脑的识别码连接，成功后会自动保存到设备列表'
                        : '登录后即可同步设备列表与连接记录',
                    action: FilledButton.icon(
                      onPressed: () => _openConnect(ConnectArgs(castMode: _castMode)),
                      icon: const Icon(Icons.add_link_rounded, size: 18),
                      label: const Text('输入识别码连接'),
                      style: FilledButton.styleFrom(minimumSize: const Size(180, 44)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                  sliver: _buildDeviceSliver(visible, devices),
                ),
              if (devices.lanDevices.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '局域网设备',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...devices.lanDevices.map(
                          (lan) => LanDeviceCard(
                            device: lan,
                            onTap: () => _openConnect(ConnectArgs(
                              deviceCode: lan.deviceCode,
                              deviceName: lan.displayName,
                              isLan: true,
                              lanIp: lan.ip,
                              castMode: _castMode,
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
      child: Row(
        children: [
          const BrandLogo(size: 34, showName: false),
          const SizedBox(width: 9),
          const Text(
            'KK远程',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          const Spacer(),
          IconButton(
            tooltip: '扫一扫',
            onPressed: () => context.push('/scan'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
          ),
          IconButton(
            tooltip: '消息中心',
            onPressed: () async {
              await context.push('/account/messages');
              if (context.mounted) {
                context.read<AuthProvider>().refreshProfile(silent: true);
              }
            },
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_rounded, size: 23),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (auth.isLoggedIn) {
                context.push('/account');
              } else {
                context.go('/login');
              }
            },
            child: UserAvatar(
              size: 34,
              avatar: auth.user?.avatar ?? '',
              name: auth.displayName,
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: context.read<DevicesProvider>().setKeyword,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '搜索设备名称、识别码或分组',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '扫码连接',
                  onPressed: () => context.push('/scan'),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 21, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // 手机端两列排布，避免四张卡片挤在一行。
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: QuickActionCard(
                      icon: Icons.wifi_find_rounded,
                      title: '局域网扫描',
                      subtitle: '同 WiFi 直连',
                      onTap: _openLanScan,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: QuickActionCard(
                      icon: Icons.screen_share_rounded,
                      title: '投屏模式',
                      subtitle: _castMode ? '已开启' : '手机投到电脑',
                      active: _castMode,
                      onTap: () {
                        setState(() => _castMode = !_castMode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_castMode ? '投屏模式已开启，请选择电脑' : '已退出投屏模式')),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(DevicesProvider devices) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '我的设备',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text(
                '${devices.visibleDevices.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: devices.toggleFavoriteFilter,
                icon: Icon(
                  devices.favoriteOnly ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 17,
                  color: devices.favoriteOnly ? AppColors.warning : AppColors.textSecondary,
                ),
                label: const Text('收藏', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: devices.loading ? null : devices.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 19, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('全部'),
                    selected: devices.groupId == null,
                    onSelected: (_) => devices.setGroup(null),
                  ),
                ),
                ...devices.groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(group.name),
                      selected: devices.groupId == group.id,
                      onSelected: (_) => devices.setGroup(group.id),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('新建分组'),
                  onPressed: () async {
                    final name = await showTextInputDialog(
                      context,
                      title: '新建分组',
                      hint: '分组名称',
                      maxLength: 20,
                    );
                    if (name != null && name.isNotEmpty) {
                      try {
                        await devices.createGroup(name);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostShareCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/host-share'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.screen_share_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本机屏幕共享',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '让电脑观看这台手机的画面，支持语音对讲',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSliver(List<Device> devices, DevicesProvider provider) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.crossAxisExtent > 760;
        if (wide) {
          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 460,
              mainAxisExtent: 92,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDeviceCard(devices[index], provider),
              childCount: devices.length,
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDeviceCard(devices[index], provider),
            ),
            childCount: devices.length,
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard(Device device, DevicesProvider provider) {
    return DeviceCard(
      device: device,
      onTap: () => _openDevice(device),
      onMenu: () => _openDeviceMenu(device),
      onToggleFavorite: () async {
        try {
          await provider.toggleFavorite(device);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      },
    );
  }
}
