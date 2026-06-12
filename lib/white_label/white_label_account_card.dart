import 'dart:async';

import 'package:bett_box/white_label/white_label_api.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_portal_views.dart';
import 'package:bett_box/white_label/white_label_service_views.dart';
import 'package:bett_box/white_label/white_label_strings.dart';
import 'package:bett_box/white_label/white_label_support_view.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WhiteLabelAccountSection extends ConsumerStatefulWidget {
  const WhiteLabelAccountSection({super.key});

  @override
  ConsumerState<WhiteLabelAccountSection> createState() =>
      _WhiteLabelAccountSectionState();
}

class _WhiteLabelAccountSectionState
    extends ConsumerState<WhiteLabelAccountSection> {
  String _email = '';
  bool _loggingOut = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEmail());
  }

  Future<void> _loadEmail() async {
    final session = await WhiteLabelApi.loadSession();
    if (!mounted) return;
    setState(() {
      _email = session?.email ?? '';
    });
  }

  Future<void> _openSupport() async {
    await openWhiteLabelSupport(context);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() {
      _loggingOut = true;
    });
    try {
      if (globalState.isStart) {
        await globalState.handleStop();
      }
      await globalState.appController.deleteProfile(whiteLabelProfileId);
      ref.read(currentProfileIdProvider.notifier).value = null;
      globalState.appController.toPage(PageLabel.dashboard);
      await globalState.appController.savePreferences();
      await WhiteLabelApi.clearSession();
    } catch (e) {
      if (!mounted) return;
      globalState.showNotifier(
        '${whiteLabelStringsOf(context).logoutFailed}: $e',
      );
      setState(() {
        _loggingOut = false;
      });
    }
  }

  String _trafficText(SubscriptionInfo? info) {
    final strings = whiteLabelStringsOf(context);
    if (info == null) {
      return strings.noPlanData;
    }
    final used = info.upload + info.download;
    if (used == 0 && info.total == 0) {
      return strings.unlimited;
    }
    if (info.total == 0) {
      return '${TrafficValue(value: used).show} / ${strings.unlimited}';
    }
    return '${TrafficValue(value: used).show} / ${TrafficValue(value: info.total).show}';
  }

  String _expireText(SubscriptionInfo? info) {
    final expire = info?.expire ?? 0;
    if (expire == 0) return whiteLabelStringsOf(context).never;
    return DateTime.fromMillisecondsSinceEpoch(expire * 1000).show;
  }

  @override
  Widget build(BuildContext context) {
    final strings = whiteLabelStringsOf(context);
    final profile = ref.watch(profilesProvider).getProfile(whiteLabelProfileId);
    final info = profile?.subscriptionInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(title: whiteLabelDisplayName),
        ListItem(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(_email.isEmpty ? strings.signedIn : _email),
          subtitle: Text(
            '${strings.userData} - ${_trafficText(info)} - ${strings.expires} ${_expireText(info)}',
          ),
        ),
        const Divider(height: 0),
        ListItem(
          leading: const Icon(Icons.apps_outlined),
          title: Text(strings.servicesAndAccount),
          subtitle: Text(
            _expanded ? strings.tapToCollapse : strings.tapToExpand,
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.expand_more),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        ClipRect(
          child: AnimatedAlign(
            alignment: Alignment.topCenter,
            heightFactor: _expanded ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            child: Column(
              children: [
                const Divider(height: 0),
                ListItem(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(strings.announcements),
                  subtitle: Text(strings.announcementsDesc),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhiteLabelNoticesView(),
                    ),
                  ),
                ),
                const Divider(height: 0),
                ListItem(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(strings.tutorials),
                  subtitle: Text(strings.tutorialsDesc),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhiteLabelTutorialsView(),
                    ),
                  ),
                ),
                const Divider(height: 0),
                ListItem(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(strings.purchase),
                  subtitle: Text(strings.purchaseDesc),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhiteLabelPurchaseView(),
                    ),
                  ),
                ),
                const Divider(height: 0),
                ListItem(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(strings.tickets),
                  subtitle: Text(strings.ticketsDesc),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhiteLabelTicketsView(),
                    ),
                  ),
                ),
                const Divider(height: 0),
                if (whiteLabelHomeUrl.isNotEmpty) ...[
                  ListItem(
                    leading: const Icon(Icons.language_outlined),
                    title: Text(strings.website),
                    subtitle: Text(whiteLabelHomeUrl),
                    onTap: () => globalState.openUrl(whiteLabelHomeUrl),
                  ),
                  const Divider(height: 0),
                ],
                if (hasWhiteLabelSupportTarget) ...[
                  ListItem(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: Text(strings.support),
                    subtitle: Text(strings.onlineSupport),
                    onTap: _openSupport,
                  ),
                  const Divider(height: 0),
                ],
                ListItem(
                  leading: _loggingOut
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  title: Text(strings.signOut),
                  subtitle: Text(strings.signOutDesc),
                  onTap: _loggingOut ? null : _logout,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
