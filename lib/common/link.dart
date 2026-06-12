import 'dart:async';

import 'package:app_links/app_links.dart';

import 'print.dart';

class InstallConfigLink {
  final String? url;
  final String? authData;

  const InstallConfigLink({this.url, this.authData});

  bool get isEmpty =>
      (url == null || url!.trim().isEmpty) &&
      (authData == null || authData!.trim().isEmpty);
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

  LinkManager._internal() {
    _appLinks = AppLinks();
  }

  Future<void> initAppLinksListen(
    InstallConfigCallBack installConfigCallBack,
  ) async {
    commonPrint.log('initAppLinksListen');
    destroy();
    subscription = _appLinks.uriLinkStream.listen((uri) {
      commonPrint.log('onAppLink: ${_safeLinkLog(uri)}');
      if (uri.host == 'install-config') {
        final parameters = uri.queryParameters;
        final link = InstallConfigLink(
          url: parameters['url'],
          authData: parameters['authData'],
        );
        if (!link.isEmpty) {
          installConfigCallBack(link);
        }
      }
    });
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
