import 'dart:async';

import 'package:app_links/app_links.dart';

import 'print.dart';

class InstallConfigLink {
  final String? url;
  final String? authData;
  final String? token;

  const InstallConfigLink({this.url, this.authData, this.token});

  bool get isEmpty =>
      (url == null || url!.trim().isEmpty) &&
      (authData == null || authData!.trim().isEmpty) &&
      (token == null || token!.trim().isEmpty);
}

typedef InstallConfigCallBack = void Function(InstallConfigLink link);

String _safeLinkLog(Uri uri) {
  final keys = uri.queryParametersAll.keys.toList()..sort();
  final keyText = keys.isEmpty ? '' : '?keys=${keys.join(',')}';
  return '${uri.scheme}://${uri.host}${uri.path}$keyText';
}

class LinkManager {
  static LinkManager? _instance;
  late AppLinks _appLinks;
  StreamSubscription? subscription;
  String? _lastLinkText;
  DateTime? _lastLinkAt;

  LinkManager._internal() {
    _appLinks = AppLinks();
  }

  Future<void> initAppLinksListen(
    InstallConfigCallBack installConfigCallBack,
  ) async {
    commonPrint.log('initAppLinksListen');
    destroy();
    subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, installConfigCallBack),
      onError: (Object e) {
        commonPrint.log('onAppLink error: $e');
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, installConfigCallBack);
      }
    } catch (e) {
      commonPrint.log('getInitialAppLink error: $e');
    }
  }

  void _handleUri(Uri uri, InstallConfigCallBack installConfigCallBack) {
    commonPrint.log('onAppLink: ${_safeLinkLog(uri)}');
    if (!_isInstallConfigLink(uri) || _isDuplicate(uri)) {
      return;
    }

    final parameters = uri.queryParameters;
    final link = InstallConfigLink(
      url: _firstNonEmpty(parameters, const ['url']),
      authData: _firstNonEmpty(parameters, const [
        'authData',
        'auth_data',
        'auth-data',
      ]),
      token: _firstNonEmpty(parameters, const [
        'token',
        'accessToken',
        'access_token',
      ]),
    );
    installConfigCallBack(link);
  }

  bool _isInstallConfigLink(Uri uri) {
    final path = uri.path.replaceFirst(RegExp(r'^/+'), '');
    return uri.host == 'install-config' || path == 'install-config';
  }

  String? _firstNonEmpty(Map<String, String> parameters, List<String> keys) {
    for (final key in keys) {
      final value = parameters[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _isDuplicate(Uri uri) {
    final text = uri.toString();
    final now = DateTime.now();
    final isDuplicate =
        _lastLinkText == text &&
        _lastLinkAt != null &&
        now.difference(_lastLinkAt!) < const Duration(seconds: 2);
    _lastLinkText = text;
    _lastLinkAt = now;
    return isDuplicate;
  }

  void destroy() {
    subscription?.cancel();
    subscription = null;
  }

  factory LinkManager() {
    _instance ??= LinkManager._internal();
    return _instance!;
  }
}

final linkManager = LinkManager();
