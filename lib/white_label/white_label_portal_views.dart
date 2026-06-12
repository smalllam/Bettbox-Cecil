import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bett_box/white_label/white_label_api.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_strings.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;
import 'package:webview_flutter/webview_flutter.dart';

String _plainText(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

String _dateText(int timestamp) {
  if (timestamp <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _cleanRichContent(String source) {
  return source
      .replaceAll(
        RegExp(r'<!--\s*access\s+(?:start|end)\s*-->', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(
          r'&lt;!--\s*access\s+(?:start|end)\s*--&gt;',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAllMapped(
        RegExp(r'\[\[([^\]]+)\]\]\(([^)\s]+)(?:\s+"[^"]*")?\)'),
        (match) => '[${match.group(1)}](${match.group(2)})',
      );
}

String whiteLabelRichHtml(String source) {
  return markdown.markdownToHtml(
    _cleanRichContent(source),
    extensionSet: markdown.ExtensionSet.gitHubWeb,
    encodeHtml: false,
  );
}

class _WhiteLabelHtmlFactory extends WidgetFactory {
  @override
  ImageProvider? imageProviderFromNetwork(String url) {
    if (url.isEmpty) return null;
    final resolved = Uri.parse(
      '$whiteLabelPanelBaseUrl/',
    ).resolve(url).toString();
    return NetworkImage(
      resolved,
      headers: {
        'Referer': whiteLabelHomeUrl.isNotEmpty
            ? '$whiteLabelHomeUrl/'
            : '$whiteLabelPanelBaseUrl/',
        'User-Agent': browserUa,
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      },
    );
  }
}

class WhiteLabelRichContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const WhiteLabelRichContent({
    super.key,
    required this.content,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      whiteLabelRichHtml(content),
      baseUrl: Uri.parse('$whiteLabelPanelBaseUrl/'),
      buildAsync: true,
      factoryBuilder: _WhiteLabelHtmlFactory.new,
      textStyle:
          textStyle ?? context.textTheme.bodyLarge?.copyWith(height: 1.7),
      customWidgetBuilder: (element) {
        if (element.localName == 'img') {
          final source = element.attributes['src'];
          if (source != null && source.isNotEmpty) {
            return _WhiteLabelNetworkImage(source: source);
          }
        }
        if (element.localName == 'svg') {
          return _WhiteLabelInlineSvg(element: element);
        }
        return null;
      },
      onTapUrl: (url) async {
        await globalState.openUrl(url);
        return true;
      },
      onLoadingBuilder: (_, _, _) =>
          const Center(child: CircularProgressIndicator()),
      onErrorBuilder: (_, element, _) {
        final source = element.attributes['src'];
        if (element.localName == 'img' && source != null) {
          final resolved = Uri.parse(
            '$whiteLabelPanelBaseUrl/',
          ).resolve(source);
          return TextButton.icon(
            onPressed: () => globalState.openUrl(resolved.toString()),
            icon: const Icon(Icons.image_outlined),
            label: Text(whiteLabelStringsOf(context).viewImage),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _WhiteLabelInlineSvg extends StatelessWidget {
  final dom.Element element;

  const _WhiteLabelInlineSvg({required this.element});

  double? _dimension(String name) {
    final raw = element.attributes[name]?.trim();
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  @override
  Widget build(BuildContext context) {
    final width = _dimension('width');
    final height = _dimension('height');
    final svg = element.outerHtml;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width,
          maxHeight: 480,
        ),
        child: SvgPicture.string(
          svg,
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _WhiteLabelNetworkImage extends StatefulWidget {
  final String source;

  const _WhiteLabelNetworkImage({required this.source});

  @override
  State<_WhiteLabelNetworkImage> createState() =>
      _WhiteLabelNetworkImageState();
}

class _WhiteLabelNetworkImageState extends State<_WhiteLabelNetworkImage> {
  late final Future<Uint8List> _future = _load();

  Uri _resolveSource() {
    final source = widget.source.trim();
    final direct = Uri.tryParse(source);
    if (direct != null && direct.hasScheme) return direct;
    final encoded = Uri.tryParse(Uri.encodeFull(source));
    if (encoded != null && encoded.hasScheme) return encoded;
    return Uri.parse('$whiteLabelPanelBaseUrl/').resolve(source);
  }

  Uint8List? _dataUriBytes(String source) {
    final match = RegExp(
      r'''^data:[^;,]+;base64,(.+)$''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source.trim());
    if (match == null) return null;
    try {
      return base64Decode(match.group(1)!.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Uint8List? _embeddedRaster(Uint8List svgBytes) {
    final svg = utf8.decode(svgBytes, allowMalformed: true);
    final match = RegExp(
      r'''(?:xlink:href|href)\s*=\s*["']data:image/(?:png|jpe?g|webp);base64,([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(svg);
    if (match == null) return null;
    try {
      return base64Decode(match.group(1)!.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _load() async {
    final dataBytes = _dataUriBytes(widget.source);
    if (dataBytes != null) return dataBytes;
    final url = _resolveSource();
    Object? lastError;
    for (final referer in [
      if (whiteLabelHomeUrl.isNotEmpty) '$whiteLabelHomeUrl/',
      '$whiteLabelPanelBaseUrl/',
      null,
    ]) {
      try {
        final response = await Dio().get<List<int>>(
          url.toString(),
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 25),
            headers: {
              'User-Agent': browserUa,
              'Accept':
                  'image/svg+xml,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              'Referer': ?referer,
            },
          ),
        );
        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Empty image response');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final resolved = _resolveSource();
          final isSvg = resolved.path.toLowerCase().endsWith('.svg');
          final embeddedRaster = isSvg ? _embeddedRaster(snapshot.data!) : null;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: embeddedRaster != null
                ? Image.memory(
                    embeddedRaster,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                : isSvg
                ? SvgPicture.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                : Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _fallback(),
                  ),
          );
        }
        if (snapshot.hasError) return _fallback();
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget _fallback() {
    final url = _resolveSource();
    return TextButton.icon(
      onPressed: () => globalState.openUrl(url.toString()),
      icon: const Icon(Icons.image_outlined),
      label: Text(whiteLabelStringsOf(context).viewImage),
    );
  }
}

class WhiteLabelPlanContent extends StatelessWidget {
  final String content;
  final bool compact;

  const WhiteLabelPlanContent({
    super.key,
    required this.content,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fragment = html_parser.parseFragment(content);
    final root = fragment.children.length == 1 ? fragment.children.first : null;
    final sections = (root?.children ?? fragment.children)
        .where((element) => element.localName == 'div')
        .toList();
    if (sections.isEmpty) {
      return WhiteLabelRichContent(
        content: content,
        textStyle: context.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var sectionIndex = 0;
          sectionIndex < sections.length;
          sectionIndex++
        ) ...[
          if (sectionIndex > 0) SizedBox(height: compact ? 8 : 14),
          _buildSection(context, sections[sectionIndex]),
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, dom.Element section) {
    final children = section.children;
    if (children.isEmpty) return const SizedBox.shrink();
    final heading = children.first;
    final rows = children.skip(1).where((element) {
      return element.querySelector('svg') != null ||
          element.text.trim().isNotEmpty;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WhiteLabelRichContent(
          content: heading.innerHtml,
          textStyle: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 2 : 6),
        for (final row in rows) _buildRow(context, row),
      ],
    );
  }

  Widget _buildRow(BuildContext context, dom.Element row) {
    final textElement = row.children.reversed.firstWhere(
      (element) => element.querySelector('svg') == null,
      orElse: () => row,
    );
    final hasDivider = (row.attributes['style'] ?? '').contains(
      'border-bottom',
    );
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 7),
      decoration: BoxDecoration(
        border: hasDivider
            ? Border(
                bottom: BorderSide(color: context.colorScheme.outlineVariant),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 20 : 24,
            height: compact ? 20 : 24,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: compact ? 14 : 17,
              color: Colors.white,
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: WhiteLabelRichContent(
              content: textElement.innerHtml,
              textStyle: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Future<WhiteLabelSession> _session() async {
  final session = await WhiteLabelApi.loadSession();
  if (session == null) throw 'Session expired.';
  return session;
}

class WhiteLabelNoticesView extends StatefulWidget {
  const WhiteLabelNoticesView({super.key});

  @override
  State<WhiteLabelNoticesView> createState() => _WhiteLabelNoticesViewState();
}

class _WhiteLabelNoticesViewState extends State<WhiteLabelNoticesView> {
  late Future<List<WhiteLabelNotice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WhiteLabelNotice>> _load() async {
    return WhiteLabelApi.fetchNotices(await _session());
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.announcements,
      body: FutureBuilder<List<WhiteLabelNotice>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${strings.loadFailed}\n${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final notices = snapshot.data ?? const [];
          if (notices.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                  _EmptyState(
                    icon: Icons.campaign_outlined,
                    label: strings.noAnnouncements,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final notice = notices[index];
                final preview = _plainText(notice.content);
                return ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(
                    notice.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (preview.isNotEmpty) preview,
                      if (_dateText(notice.createdAt).isNotEmpty)
                        _dateText(notice.createdAt),
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WhiteLabelNoticeDetailsView(notice: notice),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class WhiteLabelNoticeDetailsView extends StatefulWidget {
  final WhiteLabelNotice notice;
  final String? pageTitle;

  const WhiteLabelNoticeDetailsView({
    super.key,
    required this.notice,
    this.pageTitle,
  });

  @override
  State<WhiteLabelNoticeDetailsView> createState() =>
      _WhiteLabelNoticeDetailsViewState();
}

class _WhiteLabelNoticeDetailsViewState
    extends State<WhiteLabelNoticeDetailsView> {
  WebViewController? _controller;
  var _loading = true;
  var _allowInitialNavigation = true;
  String? _loadedTheme;
  Timer? _loadingFallback;

  @override
  void initState() {
    super.initState();
    if (system.isWindows) {
      _loading = false;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loadingFallback?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (_allowInitialNavigation && request.isMainFrame) {
              _allowInitialNavigation = false;
              return NavigationDecision.navigate;
            }
            if (!request.isMainFrame ||
                request.url == 'about:blank' ||
                request.url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }
            globalState.openUrl(request.url);
            return NavigationDecision.prevent;
          },
        ),
      );
  }

  @override
  void dispose() {
    _loadingFallback?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (system.isWindows) return;
    final brightness = Theme.of(context).brightness;
    final signature = brightness.name;
    if (_loadedTheme == signature) return;
    _loadedTheme = signature;
    _loading = true;
    _allowInitialNavigation = true;
    _controller!.loadHtmlString(
      _document(brightness),
      baseUrl: whiteLabelPanelBaseUrl,
    );
    _loadingFallback?.cancel();
    _loadingFallback = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _document(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final body = whiteLabelRichHtml(widget.notice.content);
    final date = _dateText(widget.notice.createdAt);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <base href="$whiteLabelPanelBaseUrl/">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
  <style>
    :root {
      color-scheme: ${dark ? 'dark' : 'light'};
      --text: ${dark ? '#e6e6e6' : '#202322'};
      --muted: ${dark ? '#a9b1ae' : '#66706d'};
      --border: ${dark ? '#414846' : '#d8dfdc'};
      --surface: ${dark ? '#1b1c1c' : '#f8faf9'};
      --accent: ${dark ? '#8fd5c7' : '#006c60'};
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      color: var(--text);
      font-family: system-ui, -apple-system, "Noto Sans SC", sans-serif;
      font-size: 16px;
      line-height: 1.7;
      overflow-wrap: anywhere;
    }
    article { padding: 20px 20px 36px; }
    h1.notice-title {
      margin: 0;
      font-size: 25px;
      line-height: 1.35;
      font-weight: 700;
    }
    .notice-date {
      margin-top: 8px;
      color: var(--muted);
      font-size: 13px;
    }
    .notice-content { margin-top: 22px; }
    .notice-content > :first-child { margin-top: 0; }
    p { margin: 0 0 14px; }
    h1, h2, h3, h4, h5, h6 {
      margin: 24px 0 10px;
      line-height: 1.35;
    }
    img, video {
      display: block;
      max-width: 100% !important;
      height: auto !important;
      margin: 14px auto;
      border-radius: 6px;
    }
    table {
      display: block;
      width: 100%;
      overflow-x: auto;
      border-collapse: collapse;
    }
    th, td { padding: 8px; border: 1px solid var(--border); }
    a { color: var(--accent); text-decoration: none; }
    blockquote {
      margin: 16px 0;
      padding: 8px 14px;
      border-left: 3px solid var(--accent);
      color: var(--muted);
      background: var(--surface);
    }
    pre {
      padding: 14px;
      overflow-x: auto;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: var(--surface);
    }
    code {
      padding: 2px 5px;
      border-radius: 4px;
      background: var(--surface);
      font-family: ui-monospace, monospace;
    }
    pre code { padding: 0; }
  </style>
</head>
<body>
  <article>
    <h1 class="notice-title">${_escapeHtml(widget.notice.title)}</h1>
    ${date.isEmpty ? '' : '<div class="notice-date">${_escapeHtml(date)}</div>'}
    <div class="notice-content">$body</div>
  </article>
</body>
</html>
''';
  }

  Widget _windowsContent(BuildContext context) {
    final date = _dateText(widget.notice.createdAt);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        SelectableText(
          widget.notice.title,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (date.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            date,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 22),
        WhiteLabelRichContent(
          content: widget.notice.content,
          textStyle: context.textTheme.bodyLarge?.copyWith(height: 1.7),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.pageTitle ?? whiteLabelStringsOf(context).announcements,
      body: system.isWindows
          ? _windowsContent(context)
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_loading)
                  ColoredBox(
                    color: context.colorScheme.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

class WhiteLabelTicketsView extends StatefulWidget {
  const WhiteLabelTicketsView({super.key});

  @override
  State<WhiteLabelTicketsView> createState() => _WhiteLabelTicketsViewState();
}

class _WhiteLabelTicketsViewState extends State<WhiteLabelTicketsView> {
  late Future<List<WhiteLabelTicket>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WhiteLabelTicket>> _load() async {
    return WhiteLabelApi.fetchTickets(await _session());
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _createTicket() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WhiteLabelCreateTicketView()),
    );
    if (created == true) await _refresh();
  }

  Future<void> _openTicket(WhiteLabelTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhiteLabelTicketDetailsView(ticketId: ticket.id),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.tickets,
      floatingActionButton: FloatingActionButton(
        tooltip: strings.newTicket,
        onPressed: _createTicket,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<WhiteLabelTicket>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${strings.loadFailed}\n${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final tickets = snapshot.data ?? const [];
          if (tickets.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                  _EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    label: strings.noTickets,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final status = ticket.isClosed
                    ? strings.closed
                    : strings.pendingReply;
                return ListTile(
                  leading: Icon(
                    ticket.isClosed
                        ? Icons.task_alt
                        : Icons.confirmation_number_outlined,
                  ),
                  title: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$status${_dateText(ticket.updatedAt).isEmpty ? '' : '  ${_dateText(ticket.updatedAt)}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openTicket(ticket),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class WhiteLabelCreateTicketView extends StatefulWidget {
  const WhiteLabelCreateTicketView({super.key});

  @override
  State<WhiteLabelCreateTicketView> createState() =>
      _WhiteLabelCreateTicketViewState();
}

class _WhiteLabelCreateTicketViewState
    extends State<WhiteLabelCreateTicketView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  int _level = 1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await WhiteLabelApi.createTicket(
        await _session(),
        subject: _subjectController.text.trim(),
        level: _level,
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      globalState.showNotifier(whiteLabelStringsOf(context).ticketCreated);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.newTicket,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.subject,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? strings.requiredField : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _level,
              decoration: InputDecoration(
                labelText: strings.priority,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 0, child: Text(strings.priorityLow)),
                DropdownMenuItem(value: 1, child: Text(strings.priorityMedium)),
                DropdownMenuItem(value: 2, child: Text(strings.priorityHigh)),
              ],
              onChanged: (value) => setState(() => _level = value ?? 1),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: strings.message,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? strings.requiredField : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(strings.submit),
            ),
          ],
        ),
      ),
    );
  }
}

class WhiteLabelTicketDetailsView extends StatefulWidget {
  final int ticketId;

  const WhiteLabelTicketDetailsView({super.key, required this.ticketId});

  @override
  State<WhiteLabelTicketDetailsView> createState() =>
      _WhiteLabelTicketDetailsViewState();
}

class _WhiteLabelTicketDetailsViewState
    extends State<WhiteLabelTicketDetailsView> {
  final _replyController = TextEditingController();
  WhiteLabelTicket? _ticket;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await WhiteLabelApi.fetchTicket(
        await _session(),
        widget.ticketId,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool get _canReply {
    final ticket = _ticket;
    if (ticket == null || ticket.isClosed) return false;
    if (ticket.messages.isEmpty) return true;
    return !ticket.messages.last.isMe;
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (_sending || message.isEmpty || !_canReply) return;
    setState(() => _sending = true);
    try {
      await WhiteLabelApi.replyTicket(
        await _session(),
        id: widget.ticketId,
        message: message,
      );
      _replyController.clear();
      if (!mounted) return;
      globalState.showNotifier(whiteLabelStringsOf(context).replySent);
      await _load();
    } catch (error) {
      if (!mounted) return;
      globalState.showNotifier(error.toString());
      setState(() => _sending = false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: _ticket?.subject ?? strings.tickets,
      actions: [
        IconButton(
          tooltip: strings.retry,
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(
              message: '${strings.loadFailed}\n$_error',
              onRetry: _load,
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: _ticket!.messages.length,
                    itemBuilder: (context, index) {
                      final message = _ticket!.messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
                ),
                _ReplyComposer(
                  controller: _replyController,
                  enabled: _canReply && !_sending,
                  sending: _sending,
                  hint: _ticket!.isClosed
                      ? strings.closed
                      : _canReply
                      ? strings.reply
                      : strings.pendingReply,
                  onSend: _sendReply,
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WhiteLabelTicketMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    final scheme = context.colorScheme;
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: message.isMe
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isMe ? strings.me : strings.supportAgent,
              style: context.textTheme.labelMedium?.copyWith(
                color: message.isMe
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(_plainText(message.message)),
            if (_dateText(message.createdAt).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _dateText(message.createdAt),
                style: context.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final String hint;
  final VoidCallback onSend;

  const _ReplyComposer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.hint,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(color: context.colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: whiteLabelStringsOf(context).send,
                onPressed: enabled ? onSend : null,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(whiteLabelStringsOf(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          label,
          style: context.textTheme.titleMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
