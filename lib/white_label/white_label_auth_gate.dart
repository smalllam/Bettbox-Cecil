import 'dart:async';
import 'dart:ui' as ui;

import 'package:bett_box/white_label/white_label_api.dart';
import 'package:bett_box/white_label/white_label_backend_proxy.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_support_view.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WhiteLabelAuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const WhiteLabelAuthGate({super.key, required this.child});

  @override
  ConsumerState<WhiteLabelAuthGate> createState() => _WhiteLabelAuthGateState();
}

class _WhiteLabelAuthGateState extends ConsumerState<WhiteLabelAuthGate> {
  bool _checking = true;
  bool _authenticated = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WhiteLabelApi.authRevision.addListener(_handleAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSession());
    });
  }

  @override
  void dispose() {
    WhiteLabelApi.authRevision.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _authenticated = false;
      _message = null;
    });
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final session = await WhiteLabelApi.loadSession();
    if (session == null) {
      _finishChecking(authenticated: false);
      return;
    }

    try {
      await _syncSubscription(session);
      _finishChecking(authenticated: true);
    } catch (e) {
      await _clearLocalAccess();
      _finishChecking(authenticated: false, message: e.toString());
    }
  }

  void _finishChecking({required bool authenticated, String? message}) {
    if (!mounted) return;
    setState(() {
      _checking = false;
      _authenticated = authenticated;
      _message = message;
    });
  }

  Profile? _currentWhiteLabelProfile() {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.id == whiteLabelProfileId) return profile;
    }
    return null;
  }

  Future<void> _clearLocalAccess() async {
    if (globalState.isStart) {
      await globalState.handleStop();
    }
    await globalState.appController.deleteProfile(whiteLabelProfileId);
    ref.read(currentProfileIdProvider.notifier).value = null;
    await globalState.appController.savePreferences();
    await WhiteLabelApi.clearSession(notify: false);
  }

  Future<void> _syncSubscription(WhiteLabelSession session) async {
    try {
      final subscription = await WhiteLabelApi.fetchSubscription(session);
      if (session.email.isEmpty && subscription.email.isNotEmpty) {
        await WhiteLabelApi.saveSession(
          WhiteLabelSession(
            token: session.token,
            authData: session.authData,
            email: subscription.email,
          ),
        );
      }
      final current = _currentWhiteLabelProfile();
      final profile =
          (current ??
                  Profile(
                    id: whiteLabelProfileId,
                    label: whiteLabelDisplayName,
                    autoUpdateDuration: defaultUpdateDuration,
                  ))
              .copyWith(
                label: whiteLabelDisplayName,
                url: subscription.subscribeUrl,
                autoUpdate: true,
                autoUpdateDuration: defaultUpdateDuration,
                subscriptionInfo: SubscriptionInfo(
                  upload: subscription.upload,
                  download: subscription.download,
                  total: subscription.transferEnable,
                  expire: subscription.expiredAt,
                ),
              );

      final downloaded = await WhiteLabelApi.downloadConfig(profile.url);
      final updatedProfile = await profile
          .copyWith(
            label:
                profile.label ??
                utils.getFileNameForDisposition(
                  downloaded.contentDisposition,
                ) ??
                profile.id,
            subscriptionInfo: downloaded.subscriptionUserInfo == null
                ? profile.subscriptionInfo
                : SubscriptionInfo.formHString(downloaded.subscriptionUserInfo),
          )
          .saveFile(downloaded.bytes);
      ref.read(profilesProvider.notifier).setProfile(updatedProfile);
      ref.read(currentProfileIdProvider.notifier).value = whiteLabelProfileId;
      globalState.appController.toPage(PageLabel.dashboard);
      await globalState.appController.savePreferences();
      await globalState.appController.applyProfile(silence: true);
    } finally {
      await WhiteLabelBackendProxy.stopIfTemporary();
    }
  }

  void _handleLoginSuccess(WhiteLabelSession session) async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      await _syncSubscription(session);
      _finishChecking(authenticated: true);
    } catch (e) {
      await _clearLocalAccess();
      _finishChecking(authenticated: false, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return _WhiteLabelLoadingView(message: _message);
    }
    if (!_authenticated) {
      return WhiteLabelLoginView(
        initialMessage: _message,
        onSuccess: _handleLoginSuccess,
      );
    }
    return widget.child;
  }
}

class _WhiteLabelLoadingView extends StatefulWidget {
  final String? message;

  const _WhiteLabelLoadingView({this.message});

  @override
  State<_WhiteLabelLoadingView> createState() => _WhiteLabelLoadingViewState();
}

class _WhiteLabelLoadingViewState extends State<_WhiteLabelLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final phase = _controller.value;
                    final focus = Curves.easeOutCubic.transform(
                      (phase / 0.42).clamp(0.0, 1.0),
                    );
                    final fadeOut = phase < 0.78
                        ? 1.0
                        : 1 -
                              Curves.easeInCubic.transform(
                                ((phase - 0.78) / 0.22).clamp(0.0, 1.0),
                              );
                    final lineProgress = phase < 0.55
                        ? Curves.easeOutCubic.transform(
                            (phase / 0.55).clamp(0.0, 1.0),
                          )
                        : 1 -
                              Curves.easeInCubic.transform(
                                ((phase - 0.55) / 0.45).clamp(0.0, 1.0),
                              );

                    return Opacity(
                      opacity: fadeOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 12 * (1 - focus),
                              sigmaY: 12 * (1 - focus),
                            ),
                            child: Transform.scale(
                              scale: 1.12 - (0.12 * focus),
                              child: Image.asset(
                                whiteLabelLogoAsset,
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 68 * lineProgress,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WhiteLabelLoginView extends StatefulWidget {
  final String? initialMessage;
  final ValueChanged<WhiteLabelSession> onSuccess;

  const WhiteLabelLoginView({
    super.key,
    this.initialMessage,
    required this.onSuccess,
  });

  @override
  State<WhiteLabelLoginView> createState() => _WhiteLabelLoginViewState();
}

class _WhiteLabelLoginViewState extends State<WhiteLabelLoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    unawaited(_loadEmail());
  }

  Future<void> _loadEmail() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final email = prefs?.getString(whiteLabelAuthEmailKey);
    if (!mounted || email == null) return;
    _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final session = await WhiteLabelApi.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      widget.onSuccess(session);
    } catch (e) {
      await WhiteLabelBackendProxy.stopIfTemporary();
      if (!mounted) return;
      setState(() {
        _message = _formatLoginError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openHome() async {
    if (whiteLabelHomeUrl.trim().isEmpty) return;
    await globalState.openUrl(whiteLabelHomeUrl);
  }

  Future<void> _openSupport() async {
    await openWhiteLabelSupport(context, showBubbleOnBack: false);
  }

  String _formatLoginError(Object error) {
    final message = error.toString();
    if (message.contains('connection timeout') ||
        message.contains('receive timeout') ||
        message.contains('send timeout')) {
      return '连接超时，请检查网络后重试。';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    String localized(String simplified, String traditional, String english) {
      final locale = Localizations.localeOf(context);
      if (locale.languageCode != 'zh') return english;
      final isTraditional =
          locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO';
      return isTraditional ? traditional : simplified;
    }

    final form = Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                whiteLabelLogoAsset,
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: localized('邮箱', '電子郵箱', 'Email'),
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              validator: (value) {
                final valueText = value?.trim() ?? '';
                if (valueText.isEmpty || !valueText.contains('@')) {
                  return localized('请输入邮箱。', '請輸入電子郵箱。', 'Enter your email.');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: localized('密码', '密碼', 'Password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? localized('显示密码', '顯示密碼', 'Show password')
                      : localized('隐藏密码', '隱藏密碼', 'Hide password'),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return localized('请输入密码。', '請輸入密碼。', 'Enter your password.');
                }
                return null;
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(localized('登录', '登入', 'Sign in')),
            ),
            if (whiteLabelHomeUrl.isNotEmpty)
              TextButton.icon(
                onPressed: _loading ? null : _openHome,
                icon: const Icon(Icons.open_in_new),
                label: Text(localized('打开官网', '開啟官網', 'Open website')),
              ),
            if (hasWhiteLabelSupportTarget)
              TextButton.icon(
                onPressed: _loading ? null : _openSupport,
                icon: const Icon(Icons.support_agent),
                label: Text(localized('客服', '客服', 'Support')),
              ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Material(
        color: context.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerLowest,
                    border: Border.all(
                      color: context.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: form,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
