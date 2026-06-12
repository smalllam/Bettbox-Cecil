import 'dart:async';
import 'dart:convert';

import 'package:bett_box/white_label/white_label_api.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_portal_views.dart';
import 'package:bett_box/white_label/white_label_strings.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<WhiteLabelSession> _activeSession() async {
  final session = await WhiteLabelApi.loadSession();
  if (session == null) throw 'Session expired.';
  return session;
}

String _date(int timestamp) {
  if (timestamp <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _money(int cents) => 'CNY ${(cents / 100).toStringAsFixed(2)}';

String _traffic(int gb) => gb <= 0 ? '-' : '$gb GB';

String _periodLabel(BuildContext context, String key) {
  const enLabels = {
    'month_price': 'Monthly',
    'monthly_price': 'Monthly',
    'quarter_price': 'Quarterly',
    'quarterly_price': 'Quarterly',
    'half_year_price': 'Half-year',
    'year_price': 'Yearly',
    'two_year_price': 'Two years',
    'three_year_price': 'Three years',
    'onetime_price': 'One-time',
    'reset_price': 'Reset traffic',
  };
  return enLabels[key] ?? key;
}

String _orderStatus(BuildContext context, int status) {
  return switch (status) {
    0 => 'Pending',
    1 => 'Completed',
    2 => 'Cancelled',
    3 => 'Closed',
    _ => 'Processing',
  };
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

class _PaymentPayload {
  final String? url;
  final String? html;
  final String? qrValue;

  const _PaymentPayload({this.url, this.html, this.qrValue});
}

_PaymentPayload _paymentPayload(Object? raw) {
  if (raw is String) {
    final value = raw.trim();
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        return _paymentPayload(jsonDecode(value));
      } catch (_) {}
    }
    if (value.startsWith('<')) return _PaymentPayload(html: value);
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return _PaymentPayload(url: value);
    }
    return _PaymentPayload(qrValue: value);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in [
      'url',
      'payment_url',
      'pay_url',
      'checkout_url',
      'redirect_url',
      'link',
    ]) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return _PaymentPayload(url: value);
      }
    }
    for (final key in ['html', 'form']) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.startsWith('<')) return _PaymentPayload(html: value);
    }
    final action =
        (map['action'] ?? map['gateway'] ?? map['endpoint'])?.toString() ?? '';
    final fields = map['fields'] ?? map['params'] ?? map['data'];
    if (action.startsWith('http') && fields is Map) {
      final inputs = fields.entries
          .map(
            (entry) =>
                '<input type="hidden" name="${_escapeHtml(entry.key.toString())}" '
                'value="${_escapeHtml(entry.value.toString())}">',
          )
          .join();
      return _PaymentPayload(
        html:
            '<!doctype html><meta name="viewport" content="width=device-width">'
            '<form id="pay" method="post" action="${_escapeHtml(action)}">'
            '$inputs</form><script>document.getElementById("pay").submit()</script>',
      );
    }
    for (final key in ['qr_code', 'qrcode', 'qr', 'code']) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return _PaymentPayload(qrValue: value);
    }
  }
  return const _PaymentPayload();
}

class WhiteLabelTutorialsView extends StatefulWidget {
  const WhiteLabelTutorialsView({super.key});

  @override
  State<WhiteLabelTutorialsView> createState() =>
      _WhiteLabelTutorialsViewState();
}

class _WhiteLabelTutorialsViewState extends State<WhiteLabelTutorialsView> {
  Future<List<WhiteLabelKnowledge>>? _future;

  String get _language {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ||
              locale.countryCode == 'TW' ||
              locale.countryCode == 'HK'
          ? 'zh-TW'
          : 'zh-CN';
    }
    return locale.languageCode == 'ru' ? 'ru-RU' : 'en-US';
  }

  Future<List<WhiteLabelKnowledge>> _load() async {
    return WhiteLabelApi.fetchKnowledge(await _activeSession(), _language);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.tutorials,
      body: FutureBuilder<List<WhiteLabelKnowledge>>(
        future: _future!,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _Empty(
              icon: Icons.menu_book_outlined,
              text: strings.noTutorials,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      item.category,
                      _date(item.updatedAt),
                    ].where((value) => value.isNotEmpty).join(' - '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _WhiteLabelTutorialDetailsView(item: item),
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

class _WhiteLabelTutorialDetailsView extends StatefulWidget {
  final WhiteLabelKnowledge item;

  const _WhiteLabelTutorialDetailsView({required this.item});

  @override
  State<_WhiteLabelTutorialDetailsView> createState() =>
      _WhiteLabelTutorialDetailsViewState();
}

class _WhiteLabelTutorialDetailsViewState
    extends State<_WhiteLabelTutorialDetailsView> {
  late Future<WhiteLabelKnowledge> _future = _load();

  Future<WhiteLabelKnowledge> _load() async {
    return WhiteLabelApi.fetchKnowledgeDetail(
      await _activeSession(),
      widget.item.id,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WhiteLabelKnowledge>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return CommonScaffold(
            title: widget.item.title,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return CommonScaffold(
            title: widget.item.title,
            body: _LoadError(error: snapshot.error, retry: _refresh),
          );
        }
        final item = snapshot.data!;
        return WhiteLabelNoticeDetailsView(
          pageTitle: whiteLabelStringsOf(context).tutorials,
          notice: WhiteLabelNotice(
            id: item.id,
            title: item.title,
            content: item.body,
            createdAt: item.updatedAt,
            updatedAt: item.updatedAt,
          ),
        );
      },
    );
  }
}

class WhiteLabelPurchaseView extends StatelessWidget {
  const WhiteLabelPurchaseView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return DefaultTabController(
      length: 2,
      child: CommonScaffold(
        title: strings.purchase,
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: strings.plans),
                Tab(text: strings.orders),
              ],
            ),
            const Expanded(
              child: TabBarView(children: [_PlansTab(), _OrdersTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlanCategory { all, recurring, traffic }

enum _PlanCycle { monthly, yearly }

class _PlansTab extends StatefulWidget {
  const _PlansTab();

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  late Future<List<WhiteLabelPlan>> _future = _load();
  _PlanCategory _category = _PlanCategory.all;
  _PlanCycle _cycle = _PlanCycle.monthly;

  Future<List<WhiteLabelPlan>> _load() async {
    return WhiteLabelApi.fetchPlans(await _activeSession());
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  MapEntry<String, int>? _priceEntry(WhiteLabelPlan plan, String key) {
    final value = plan.prices[key];
    if (value == null || value < 0) return null;
    return MapEntry(key, value);
  }

  MapEntry<String, int>? _selectedCyclePrice(WhiteLabelPlan plan) {
    final key = _cycle == _PlanCycle.monthly ? 'month_price' : 'year_price';
    return _priceEntry(plan, key);
  }

  Future<void> _choosePeriod(
    WhiteLabelPlan plan, {
    MapEntry<String, int>? selectedPeriod,
  }) async {
    final available = plan.prices.entries
        .where((entry) => entry.value >= 0)
        .toList();
    final selected =
        selectedPeriod ??
        await showModalBottomSheet<MapEntry<String, int>>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(plan.name, style: context.textTheme.titleLarge),
                  subtitle: Text(whiteLabelStringsOf(context).selectPeriod),
                ),
                for (final entry in available)
                  ListTile(
                    title: Text(_periodLabel(context, entry.key)),
                    trailing: Text(_money(entry.value)),
                    onTap: () => Navigator.pop(context, entry),
                  ),
              ],
            ),
          ),
        );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(whiteLabelStringsOf(context).confirmOrder),
        content: Text(
          '${plan.name}\n${_periodLabel(context, selected.key)} - ${_money(selected.value)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(whiteLabelStringsOf(context).submit),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final tradeNo = await WhiteLabelApi.createOrder(
        await _activeSession(),
        planId: plan.id,
        period: selected.key,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WhiteLabelOrderDetailsView(tradeNo: tradeNo),
        ),
      );
    } catch (error) {
      globalState.showNotifier(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WhiteLabelPlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error, retry: _refresh);
        }
        final plans = snapshot.data ?? const [];
        if (plans.isEmpty) {
          return _Empty(
            icon: Icons.shopping_bag_outlined,
            text: whiteLabelStringsOf(context).noPlans,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final filteredPlans = plans.where((plan) {
              return switch (_category) {
                _PlanCategory.all => true,
                _PlanCategory.recurring => _selectedCyclePrice(plan) != null,
                _PlanCategory.traffic =>
                  (plan.prices['onetime_price'] ?? -1) >= 0,
              };
            }).toList();
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _PlanFilters(
                      category: _category,
                      cycle: _cycle,
                      onCategoryChanged: (value) {
                        setState(() => _category = value);
                      },
                      onCycleChanged: (value) {
                        setState(() => _cycle = value);
                      },
                    ),
                  ),
                  if (filteredPlans.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        icon: Icons.shopping_bag_outlined,
                        text: whiteLabelStringsOf(context).noPlans,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: columns == 1 ? 610 : 570,
                        ),
                        itemCount: filteredPlans.length,
                        itemBuilder: (context, index) {
                          final plan = filteredPlans[index];
                          final selectedPrice = switch (_category) {
                            _PlanCategory.all => null,
                            _PlanCategory.recurring => _selectedCyclePrice(
                              plan,
                            ),
                            _PlanCategory.traffic => _priceEntry(
                              plan,
                              'onetime_price',
                            ),
                          };
                          return _WhiteLabelPlanCard(
                            plan: plan,
                            index: plans.indexOf(plan),
                            selectedPrice: selectedPrice,
                            onBuy: () => _choosePeriod(
                              plan,
                              selectedPeriod: selectedPrice,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlanFilters extends StatelessWidget {
  final _PlanCategory category;
  final _PlanCycle cycle;
  final ValueChanged<_PlanCategory> onCategoryChanged;
  final ValueChanged<_PlanCycle> onCycleChanged;

  const _PlanFilters({
    required this.category,
    required this.cycle,
    required this.onCategoryChanged,
    required this.onCycleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _PlanCategoryTab(
                label: 'All plans',
                selected: category == _PlanCategory.all,
                onTap: () => onCategoryChanged(_PlanCategory.all),
              ),
              _PlanCategoryTab(
                label: 'Recurring',
                selected: category == _PlanCategory.recurring,
                onTap: () => onCategoryChanged(_PlanCategory.recurring),
              ),
              _PlanCategoryTab(
                label: 'Traffic',
                selected: category == _PlanCategory.traffic,
                onTap: () => onCategoryChanged(_PlanCategory.traffic),
              ),
            ],
          ),
        ),
        if (category == _PlanCategory.recurring)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Yearly'),
                  Switch(
                    value: cycle == _PlanCycle.monthly,
                    onChanged: (monthly) => onCycleChanged(
                      monthly ? _PlanCycle.monthly : _PlanCycle.yearly,
                    ),
                  ),
                  const Text('Monthly'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanCategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colorScheme.primary
        : context.colorScheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? context.colorScheme.surfaceContainerLow
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? context.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhiteLabelPlanCard extends StatelessWidget {
  final WhiteLabelPlan plan;
  final int index;
  final MapEntry<String, int>? selectedPrice;
  final VoidCallback onBuy;

  const _WhiteLabelPlanCard({
    required this.plan,
    required this.index,
    required this.selectedPrice,
    required this.onBuy,
  });

  MapEntry<String, int>? get _lowestPrice {
    final entries = plan.prices.entries
        .where((entry) => entry.value >= 0)
        .toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.first;
  }

  String _periodSuffix(String key) {
    return switch (key) {
      'month_price' || 'monthly_price' => '/mo',
      'quarter_price' || 'quarterly_price' => '/quarter',
      'half_year_price' => '/half-year',
      'year_price' => '/yr',
      'two_year_price' => '/2yr',
      'three_year_price' => '/3yr',
      'onetime_price' => '/once',
      _ => '',
    };
  }

  ({String label, Color color}) get _badge {
    final lowerName = plan.name.toLowerCase();
    if (lowerName.contains('team')) {
      return (label: 'Value', color: const Color(0xFF00A45A));
    }
    if (lowerName.contains('month')) {
      return (label: 'Popular', color: const Color(0xFF00A7AD));
    }
    return (
      label: index == 0 ? 'Featured' : 'Recommended',
      color: const Color(0xFFFF4B3E),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = selectedPrice ?? _lowestPrice;
    final badge = _badge;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: context.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F3F3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: badge.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: Text(
                        badge.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    plan.name,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (price != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(price.value),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            _periodSuffix(price.key),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onBuy,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2CA8B5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('Subscribe'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (plan.content.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: WhiteLabelPlanContent(
                    content: plan.content,
                    compact: true,
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    '${whiteLabelStringsOf(context).traffic}: '
                    '${_traffic(plan.transferEnable)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late Future<List<WhiteLabelOrder>> _future = _load();

  Future<List<WhiteLabelOrder>> _load() async {
    return WhiteLabelApi.fetchOrders(await _activeSession());
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WhiteLabelOrder>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error, retry: _refresh);
        }
        final orders = snapshot.data ?? const [];
        if (orders.isEmpty) {
          return _Empty(
            icon: Icons.receipt_long_outlined,
            text: whiteLabelStringsOf(context).noOrders,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(order.plan?.name ?? order.tradeNo),
                subtitle: Text(
                  '${_orderStatus(context, order.status)} - ${_money(order.totalAmount)}\n${_date(order.createdAt)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WhiteLabelOrderDetailsView(tradeNo: order.tradeNo),
                    ),
                  );
                  _refresh();
                },
              );
            },
          ),
        );
      },
    );
  }
}

class WhiteLabelOrderDetailsView extends StatefulWidget {
  final String tradeNo;

  const WhiteLabelOrderDetailsView({super.key, required this.tradeNo});

  @override
  State<WhiteLabelOrderDetailsView> createState() =>
      _WhiteLabelOrderDetailsViewState();
}

class _WhiteLabelOrderDetailsViewState
    extends State<WhiteLabelOrderDetailsView> {
  late Future<WhiteLabelOrder> _future = _load();
  var _paying = false;
  var _cancelling = false;

  Future<WhiteLabelOrder> _load() async {
    return WhiteLabelApi.fetchOrder(await _activeSession(), widget.tradeNo);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final session = await _activeSession();
      final methods = await WhiteLabelApi.fetchPaymentMethods(session);
      if (!mounted) return;
      if (methods.isEmpty) {
        await _showPaymentError(whiteLabelStringsOf(context).noPaymentMethods);
        return;
      }
      final method = await showModalBottomSheet<WhiteLabelPaymentMethod>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(whiteLabelStringsOf(context).paymentMethod)),
              for (final item in methods)
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(item.name),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      );
      if (method == null) return;
      final result = await WhiteLabelApi.checkoutOrder(
        session,
        tradeNo: widget.tradeNo,
        method: method.id,
      );
      if (result.type == -1) {
        await _refresh();
      } else {
        final payload = _paymentPayload(result.data);
        if (payload.url == null &&
            payload.html == null &&
            payload.qrValue == null) {
          if (!mounted) return;
          await _showPaymentError(
            '${whiteLabelStringsOf(context).paymentDataInvalid}\n${result.data ?? ''}',
          );
          return;
        }
        if (!mounted) return;
        if (system.isWindows && payload.url != null) {
          await globalState.openUrl(payload.url!);
          if (mounted) await _refresh();
          return;
        }
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _WhiteLabelPaymentView(
              tradeNo: widget.tradeNo,
              payload: payload,
            ),
          ),
        );
        if (mounted) await _refresh();
      }
    } catch (error) {
      await _showPaymentError(error.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_cancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order'),
        content: const Text('Cancel this pending order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await WhiteLabelApi.cancelOrder(await _activeSession(), widget.tradeNo);
      if (!mounted) return;
      globalState.showNotifier('Order cancelled');
      await _refresh();
    } catch (error) {
      if (mounted) await _showPaymentError(error.toString());
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showPaymentError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(whiteLabelStringsOf(context).paymentFailed),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.orderDetails,
      body: FutureBuilder<WhiteLabelOrder>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          final order = snapshot.data!;
          final rows = <(String, String)>[
            (strings.orderNumber, order.tradeNo),
            (strings.plan, order.plan?.name ?? '-'),
            (strings.period, _periodLabel(context, order.period)),
            (strings.status, _orderStatus(context, order.status)),
            (strings.amount, _money(order.totalAmount)),
            (strings.createdAt, _date(order.createdAt)),
          ];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          row.$1,
                          style: TextStyle(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: SelectableText(row.$2)),
                    ],
                  ),
                ),
              if (order.status == 0) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _paying || _cancelling ? null : _pay,
                  icon: _paying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: Text(strings.continuePayment),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _paying || _cancelling ? null : _cancelOrder,
                  icon: _cancelling
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close),
                  label: Text(
                    Localizations.localeOf(context).languageCode == 'zh'
                        ? 'Cancel order'
                        : 'Cancel order',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WhiteLabelPaymentView extends StatefulWidget {
  final String tradeNo;
  final _PaymentPayload payload;

  const _WhiteLabelPaymentView({required this.tradeNo, required this.payload});

  @override
  State<_WhiteLabelPaymentView> createState() => _WhiteLabelPaymentViewState();
}

class _WhiteLabelPaymentViewState extends State<_WhiteLabelPaymentView> {
  WebViewController? _controller;
  Timer? _paymentPollTimer;
  var _loading = true;
  var _checking = false;
  var _paymentReturnSeen = false;
  var _paymentPollAttempts = 0;
  String? _pageError;
  String? _currentUrl;

  String _debugUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'invalid';
    final keys = uri.queryParametersAll.keys.join(',');
    return '${uri.scheme}://${uri.host}${uri.path}${keys.isEmpty ? '' : '?keys=$keys'}';
  }

  bool _isExternalPaymentUrl(String url) {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    return scheme == 'weixin' ||
        scheme == 'alipays' ||
        scheme == 'alipay' ||
        scheme == 'intent' ||
        scheme == 'unionpay' ||
        scheme == 'uppay' ||
        _isPaymentProviderHost(uri?.host ?? '');
  }

  bool _isPaymentProviderHost(String host) {
    final value = host.toLowerCase();
    return value == 'ulink.alipay.com' ||
        value.endsWith('.alipay.com') ||
        value == 'wx.tenpay.com' ||
        value.endsWith('.weixin.qq.com');
  }

  Future<void> _openPaymentApp(String url) async {
    debugPrint('WhiteLabelPayment: opening external ${_debugUrl(url)}');
    var opened = false;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!opened && mounted) {
      globalState.showNotifier(
        Localizations.localeOf(context).languageCode == 'zh'
            ? 'Could not open the payment app. Please make sure it is installed.'
            : 'Could not open the payment app. Please make sure it is installed.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (system.isWindows) {
      _loading = false;
      return;
    }
    if (widget.payload.url != null || widget.payload.html != null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              debugPrint('WhiteLabelPayment: page started ${_debugUrl(url)}');
              if (mounted) {
                setState(() {
                  _loading = true;
                  _pageError = null;
                  _currentUrl = url;
                });
              }
            },
            onPageFinished: (_) {
              debugPrint(
                'WhiteLabelPayment: page finished ${_currentUrl == null ? 'unknown' : _debugUrl(_currentUrl!)}',
              );
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              debugPrint(
                'WhiteLabelPayment: web error main=${error.isForMainFrame} '
                'code=${error.errorCode} ${error.description} '
                '${_debugUrl(error.url ?? _currentUrl ?? widget.payload.url ?? '')}',
              );
              if (error.isForMainFrame != true || !mounted) return;
              setState(() {
                _loading = false;
                _pageError =
                    '${error.description}\n'
                    '${error.url ?? _currentUrl ?? widget.payload.url ?? ''}';
              });
            },
            onNavigationRequest: (request) {
              debugPrint(
                'WhiteLabelPayment: navigation ${_debugUrl(request.url)} main=${request.isMainFrame}',
              );
              if (_isPanelReturn(request.url)) {
                _startPaymentPolling();
                return NavigationDecision.prevent;
              }
              if (_isGatewayReturn(request.url)) _startPaymentPolling();
              if (_isExternalPaymentUrl(request.url)) {
                unawaited(_openPaymentApp(request.url));
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );
      _controller = controller;
      if (widget.payload.url != null) {
        controller.loadRequest(Uri.parse(widget.payload.url!));
      } else {
        controller.loadHtmlString(
          widget.payload.html!,
          baseUrl: whiteLabelPanelBaseUrl,
        );
      }
    }
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    super.dispose();
  }

  bool _isPanelReturn(String url) {
    final uri = Uri.tryParse(url);
    final panelHost = Uri.tryParse(whiteLabelPanelBaseUrl)?.host ?? '';
    if (uri == null || panelHost.isEmpty || uri.host != panelHost) {
      return false;
    }
    return url.contains('/order/') ||
        url.contains('/#/order/') ||
        (_paymentReturnSeen && (uri.path.isEmpty || uri.path == '/'));
  }

  bool _isGatewayReturn(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    final queryKeys = uri.queryParametersAll.keys
        .map((key) => key.toLowerCase())
        .toSet();
    return path.contains('/pay/return') || queryKeys.contains('trade_status');
  }

  void _startPaymentPolling() {
    _paymentReturnSeen = true;
    if (_paymentPollTimer?.isActive == true) return;
    _paymentPollAttempts = 0;
    unawaited(_checkPayment(closeWhenPaid: true, silentWhenPending: true));
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_paymentPollAttempts >= 20) {
        timer.cancel();
        return;
      }
      _paymentPollAttempts++;
      unawaited(_checkPayment(closeWhenPaid: true, silentWhenPending: true));
    });
  }

  Future<void> _checkPayment({
    bool closeWhenPaid = false,
    bool silentWhenPending = false,
  }) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final status = await WhiteLabelApi.checkOrder(
        await _activeSession(),
        widget.tradeNo,
      );
      debugPrint('WhiteLabelPayment: check status=$status');
      if (!mounted) return;
      if (status == 3) {
        _paymentPollTimer?.cancel();
        Navigator.of(context).pop(true);
      } else if (!closeWhenPaid && !silentWhenPending) {
        globalState.showNotifier(whiteLabelStringsOf(context).paymentPending);
      }
    } catch (error) {
      if (mounted) globalState.showNotifier(error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    return CommonScaffold(
      title: strings.payment,
      actions: [
        IconButton(
          tooltip: strings.checkPayment,
          onPressed: _checking ? null : _checkPayment,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        if (widget.payload.url != null)
          IconButton(
            tooltip: strings.openExternal,
            onPressed: () => globalState.openUrl(widget.payload.url!),
            icon: const Icon(Icons.open_in_browser),
          ),
      ],
      body: widget.payload.qrValue != null
          ? _PaymentCode(value: widget.payload.qrValue!)
          : system.isWindows
          ? Center(
              child: FilledButton.icon(
                onPressed: widget.payload.url == null
                    ? null
                    : () => globalState.openUrl(widget.payload.url!),
                icon: const Icon(Icons.open_in_browser),
                label: Text(strings.openExternal),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_pageError != null)
                  ColoredBox(
                    color: context.colorScheme.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 52,
                              color: context.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.paymentPageFailed,
                              style: context.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              _pageError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _pageError = null;
                                });
                                _controller!.reload();
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(strings.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

class _PaymentCode extends StatelessWidget {
  final String value;

  const _PaymentCode({required this.value});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 96),
            const SizedBox(height: 20),
            Text(
              whiteLabelStringsOf(context).scanOrOpenPayment,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SelectableText(value, textAlign: TextAlign.center),
            if (value.startsWith('http')) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => globalState.openUrl(value),
                icon: const Icon(Icons.open_in_browser),
                label: Text(whiteLabelStringsOf(context).openExternal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() retry;

  const _LoadError({required this.error, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: Text(whiteLabelStringsOf(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}
