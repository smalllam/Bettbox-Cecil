import 'dart:convert';
import 'dart:io';

import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_strings.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

final whiteLabelSupportBubbleVisible = ValueNotifier<bool>(false);
Webview? _whiteLabelSupportWebview;

Future<void> openWhiteLabelSupport(
  BuildContext context, {
  bool showBubbleOnBack = true,
}) async {
  if (!_hasSupportTarget) {
    globalState.showNotifier('Support URL is not configured.');
    return;
  }
  if (system.isWindows) {
    final existing = _whiteLabelSupportWebview;
    if (existing != null) {
      await existing.bringToForeground();
      return;
    }
    try {
      final available = await WebviewWindow.isWebviewAvailable();
      if (!available) {
        throw StateError('Microsoft Edge WebView2 Runtime is unavailable.');
      }
      final dataDirectory = await appPath.dataDir.future;
      final webviewDirectory = Directory(
        '${dataDirectory.path}${Platform.pathSeparator}support_webview',
      );
      await webviewDirectory.create(recursive: true);
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 460,
          windowHeight: 760,
          title: '$whiteLabelDisplayName Support',
          userDataFolderWindows: webviewDirectory.path,
          useWindowPositionAndSize: true,
        ),
      );
      _whiteLabelSupportWebview = webview;
      await webview.setApplicationNameForUserAgent(
        ' $whiteLabelDisplayName/1.0.0',
      );
      webview.launch(await _desktopSupportTarget());
      webview.onClose.whenComplete(() {
        if (identical(_whiteLabelSupportWebview, webview)) {
          _whiteLabelSupportWebview = null;
        }
      });
    } catch (error) {
      globalState.showNotifier('Support window failed to open: $error');
    }
    return;
  }
  whiteLabelSupportBubbleVisible.value = false;
  final showBubble = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const WhiteLabelSupportView()),
  );
  whiteLabelSupportBubbleVisible.value = showBubbleOnBack && showBubble == true;
}

bool get _hasSupportTarget =>
    whiteLabelSupportUrl.trim().isNotEmpty || _crispWebsiteId != null;

String? get _crispWebsiteId {
  final value = whiteLabelSupportUri.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme.toLowerCase() != 'crisp') return null;
  final id = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
  return id.trim().isEmpty ? null : id.trim();
}

String _crispHtml(String websiteId) {
  final id = jsonEncode(websiteId);
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    html, body {
      height: 100%;
      margin: 0;
      background: #f7fbfa;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
  </style>
</head>
<body>
  <script>
    window.\$crisp = [];
    window.CRISP_WEBSITE_ID = $id;
    (function () {
      var d = document;
      var s = d.createElement("script");
      s.src = "https://client.crisp.chat/l.js";
      s.async = 1;
      d.getElementsByTagName("head")[0].appendChild(s);
    })();
    window.\$crisp.push(["do", "chat:open"]);
  </script>
</body>
</html>
''';
}

Future<String> _desktopSupportTarget() async {
  final webUrl = whiteLabelSupportUrl.trim();
  if (webUrl.isNotEmpty) return webUrl;

  final websiteId = _crispWebsiteId;
  if (websiteId == null) {
    throw StateError('Support URL is not configured.');
  }

  final dataDirectory = await appPath.dataDir.future;
  final supportDirectory = Directory(
    '${dataDirectory.path}${Platform.pathSeparator}support_webview',
  );
  await supportDirectory.create(recursive: true);
  final htmlFile = File(
    '${supportDirectory.path}${Platform.pathSeparator}crisp.html',
  );
  await htmlFile.writeAsString(_crispHtml(websiteId));
  return htmlFile.uri.toString();
}

class WhiteLabelSupportView extends StatefulWidget {
  const WhiteLabelSupportView({super.key});

  @override
  State<WhiteLabelSupportView> createState() => _WhiteLabelSupportViewState();
}

class _WhiteLabelSupportViewState extends State<WhiteLabelSupportView> {
  WebViewController? _controller;
  var _loading = true;

  void _close({required bool showBubble}) {
    Navigator.of(context).pop(showBubble);
  }

  @override
  void initState() {
    super.initState();
    if (system.isWindows) {
      _loading = false;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
        ),
      );
    final webUrl = whiteLabelSupportUrl.trim();
    if (webUrl.isNotEmpty) {
      _controller!.loadRequest(Uri.parse(webUrl));
    } else {
      final websiteId = _crispWebsiteId;
      if (websiteId == null) {
        _loading = false;
      } else {
        _controller!.loadHtmlString(_crispHtml(websiteId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close(showBubble: true);
      },
      child: CommonScaffold(
        title: whiteLabelStringsOf(context).support,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _close(showBubble: true),
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: () => _close(showBubble: false),
          ),
        ],
        body: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_loading)
              ColoredBox(
                color: context.colorScheme.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
