import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/device.dart';
import '../data/models/support.dart';
import '../features/account/pages/account_center_page.dart';
import '../features/account/pages/account_deletion_page.dart';
import '../features/account/pages/bind_account_page.dart';
import '../features/account/pages/change_password_page.dart';
import '../features/account/pages/identity_bind_page.dart';
import '../features/account/pages/login_devices_page.dart';
import '../features/account/pages/message_center_page.dart';
import '../features/account/pages/profile_edit_page.dart';
import '../features/account/pages/two_factor_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/devices/pages/connect_page.dart';
import '../features/devices/pages/device_detail_page.dart';
import '../features/devices/pages/home_page.dart';
import '../features/devices/pages/scan_page.dart';
import '../features/devices/state/connect_args.dart';
import '../features/files/pages/remote_files_page.dart';
import '../features/remote/pages/remote_page.dart';
import '../features/remote/state/remote_args.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/accessibility_page.dart';
import '../features/settings/pages/audio_settings_page.dart';
import '../features/settings/pages/connection_settings_page.dart';
import '../features/settings/pages/developer_settings_page.dart';
import '../features/settings/pages/display_settings_page.dart';
import '../features/settings/pages/downloads_page.dart';
import '../features/settings/pages/file_settings_page.dart';
import '../features/settings/pages/gamepad_settings_page.dart';
import '../features/settings/pages/language_page.dart';
import '../features/settings/pages/network_diagnostics_page.dart';
import '../features/settings/pages/notification_settings_page.dart';
import '../features/settings/pages/offline_commands_page.dart';
import '../features/settings/pages/scheduled_tasks_page.dart';
import '../features/settings/pages/security_settings_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/settings/pages/touch_settings_page.dart';
import '../features/support/pages/help_page.dart';
import '../features/support/pages/support_chat_page.dart';
import '../features/support/pages/ticket_detail_page.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      final publicRoutes = path == '/login' || path == '/register' || path == '/forgot-password';
      final loggedIn = auth.isAuthenticated;
      if (!loggedIn && !publicRoutes) return '/login';
      if (loggedIn && publicRoutes) return '/home';
      if (path.startsWith('/account') && !auth.canAccessAccount) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          initialAccount: state.uri.queryParameters['account'] ?? '',
        ),
      ),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/connect',
        builder: (context, state) {
          final args = state.extra;
          return ConnectPage(args: args is ConnectArgs ? args : const ConnectArgs());
        },
      ),
      GoRoute(path: '/scan', builder: (context, state) => const ScanPage()),
      GoRoute(
        path: '/remote',
        builder: (context, state) {
          final args = state.extra;
          return RemotePage(
            args: args is RemoteArgs ? args : const RemoteArgs(deviceCode: ''),
          );
        },
      ),
      GoRoute(path: '/remote/files', builder: (context, state) => const RemoteFilesPage()),
      GoRoute(
        path: '/device/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final extra = state.extra;
          return DeviceDetailPage(
            deviceId: id,
            device: extra is Device ? extra : null,
          );
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
      GoRoute(
        path: '/settings/display',
        builder: (context, state) => const DisplaySettingsPage(),
      ),
      GoRoute(
        path: '/settings/audio',
        builder: (context, state) => const AudioSettingsPage(),
      ),
      GoRoute(
        path: '/settings/touch',
        builder: (context, state) => const TouchSettingsPage(),
      ),
      GoRoute(
        path: '/settings/connection',
        builder: (context, state) => const ConnectionSettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/files',
        builder: (context, state) => const FileSettingsPage(),
      ),
      GoRoute(
        path: '/settings/downloads',
        builder: (context, state) => DownloadsPage(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => const SecuritySettingsPage(),
      ),
      GoRoute(path: '/settings/about', builder: (context, state) => const AboutPage()),
      GoRoute(
        path: '/settings/language',
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        builder: (context, state) => const AccessibilityPage(),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (context, state) => const NetworkDiagnosticsPage(),
      ),
      GoRoute(
        path: '/settings/scheduled-tasks',
        builder: (context, state) => const ScheduledTasksPage(),
      ),
      GoRoute(
        path: '/settings/offline-commands',
        builder: (context, state) => OfflineCommandsPage(
          deviceId: int.tryParse(state.uri.queryParameters['deviceId'] ?? '0') ?? 0,
        ),
      ),
      GoRoute(
        path: '/settings/gamepad',
        builder: (context, state) => const GamepadSettingsPage(),
      ),
      GoRoute(
        path: '/settings/developer',
        builder: (context, state) => const DeveloperSettingsPage(),
      ),
      GoRoute(path: '/help', builder: (context, state) => const HelpPage()),
      GoRoute(path: '/help/support', builder: (context, state) => const SupportChatPage()),
      GoRoute(
        path: '/help/tickets/:id',
        builder: (context, state) {
          final extra = state.extra;
          return TicketDetailPage(
            ticketId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ticket: extra is Ticket ? extra : null,
          );
        },
      ),
      GoRoute(path: '/account', builder: (context, state) => const AccountCenterPage()),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: '/account/password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/account/bind',
        builder: (context, state) => BindAccountPage(
          type: state.uri.queryParameters['type'] ?? 'phone',
        ),
      ),
      GoRoute(
        path: '/account/login-devices',
        builder: (context, state) => const LoginDevicesPage(),
      ),
      GoRoute(path: '/account/2fa', builder: (context, state) => const TwoFactorPage()),
      GoRoute(
        path: '/account/deletion',
        builder: (context, state) => const AccountDeletionPage(),
      ),
      GoRoute(
        path: '/account/messages',
        builder: (context, state) => const MessageCenterPage(),
      ),
      GoRoute(
        path: '/account/identities',
        builder: (context, state) => const IdentityBindPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error?.toString() ?? '未找到该页面'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
}
