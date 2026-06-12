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
  if (whiteLabelSupportUrl.trim().isEmpty) {
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
      webview.launch(whiteLabelSupportUrl);
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
      )
      ..loadRequest(Uri.parse(whiteLabelSupportUrl));
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
