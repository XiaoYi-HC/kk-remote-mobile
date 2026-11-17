import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/platform/app_lock_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/state/auth_provider.dart';
import 'routing/app_router.dart';
import 'state/settings_provider.dart';
import 'widgets/brand_logo.dart';

class KKRemoteApp extends StatefulWidget {
  const KKRemoteApp({super.key, required this.auth, required this.settings});

  final AuthProvider auth;
  final SettingsProvider settings;

  @override
  State<KKRemoteApp> createState() => _KKRemoteAppState();
}

class _KKRemoteAppState extends State<KKRemoteApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  Locale _localeFor(String lang) {
    final parts = lang.split('-');
    if (parts.length > 1) return Locale(parts[0], parts[1]);
    return Locale(parts.first);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp.router(
          title: AppConstants.productName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          locale: _localeFor(settings.language),
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
            Locale('en', 'US'),
            Locale('ja', 'JP'),
            Locale('ko', 'KR'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(settings.effectiveTextScale),
              ),
              child: AppLockGate(
                settings: settings,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}

/// 应用锁：启动或长时间后台返回时要求生物识别/系统密码。
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.settings, required this.child});

  final SettingsProvider settings;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  DateTime? _pausedAt;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.settings.appLockEnabled && !widget.settings.unlockedThisSession;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.appLockEnabled && !widget.settings.unlockedThisSession && !_locked) {
      setState(() => _locked = true);
      _unlock();
    }
    if (!widget.settings.appLockEnabled && _locked) {
      setState(() => _locked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      _pausedAt = null;
      if (paused != null &&
          DateTime.now().difference(paused) > const Duration(minutes: 2) &&
          widget.settings.appLockEnabled) {
        widget.settings.unlockedThisSession = false;
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    if (mounted) setState(() => _message = null);
    final ok = await AppLockService.instance.authenticate();
    _authenticating = false;
    if (!mounted) return;
    if (ok) {
      widget.settings.unlockedThisSession = true;
      setState(() {
        _locked = false;
        _message = null;
      });
    } else {
      setState(() => _message = '验证未通过，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: Material(
                color: AppColors.background,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandLogo(size: 84, showName: false),
                          const SizedBox(height: 16),
                          const Text(
                            'KK远程已锁定',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '验证身份后继续使用远程控制',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 220,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _authenticating ? null : _unlock,
                              icon: _authenticating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint_rounded, size: 22),
                              label: Text(_authenticating ? '验证中…' : '解锁'),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              style: const TextStyle(fontSize: 12, color: AppColors.danger),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            '可在 设置 → 安全与隐私 中关闭应用锁',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
