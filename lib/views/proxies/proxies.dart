import 'package:bett_box/white_label/white_label_api.dart';
import 'package:bett_box/white_label/white_label_backend_proxy.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/white_label/white_label_strings.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/list.dart';
import 'package:bett_box/views/proxies/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'advanced_settings.dart';
import 'setting.dart';
import 'tab.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  bool _hasProviders = false;
  bool _isTab = false;
  bool _refreshingSubscription = false;

  List<Widget> _buildActions() {
    return [
      IconButton(
        tooltip: whiteLabelStringsOf(context).refreshSubscription,
        onPressed: _refreshingSubscription ? null : _refreshSubscription,
        icon: _refreshingSubscription
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      if (_isTab)
        IconButton(
          onPressed: () {
            _proxiesTabKey.currentState?.scrollToGroupSelected();
          },
          icon: Icon(Icons.adjust, weight: 1),
        ),
      CommonPopupBox(
        targetBuilder: (open) {
          return IconButton(
            onPressed: () {
              open(offset: Offset(0, 20));
            },
            icon: Icon(Icons.more_vert),
          );
        },
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: Icons.tune,
              label: appLocalizations.settings,
              onPressed: () {
                showSheet(
                  context: context,
                  props: SheetProps(isScrollControlled: true),
                  builder: (_, type) {
                    return AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                    );
                  },
                );
              },
            ),
            if (_hasProviders)
              PopupMenuItemData(
                icon: Icons.poll_outlined,
                label: appLocalizations.providers,
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_, type) {
                      return ProvidersView(type: type);
                    },
                  );
                },
              ),
            PopupMenuItemData(
              icon: Icons.settings_suggest,
              label: appLocalizations.advancedSettings,
              onPressed: () {
                showExtend(
                  context,
                  builder: (_, type) {
                    return AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesAdvancedSettings(),
                      title: appLocalizations.advancedSettings,
                    );
                  },
                );
              },
            ),
            if (!_isTab)
              PopupMenuItemData(
                icon: Icons.style_outlined,
                label: appLocalizations.iconConfiguration,
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_, type) {
                      return AdaptiveSheetScaffold(
                        type: type,
                        body: const _IconConfigView(),
                        title: appLocalizations.iconConfiguration,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    ];
  }

  Future<void> _refreshSubscription() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.id != whiteLabelProfileId) return;
    setState(() => _refreshingSubscription = true);
    try {
      final session = await WhiteLabelApi.loadSession();
      if (session == null) throw 'Session expired.';
      final subscription = await WhiteLabelApi.fetchSubscription(session);
      final downloaded = await WhiteLabelApi.downloadConfig(
        subscription.subscribeUrl,
      );
      final updated = await profile
          .copyWith(
            url: subscription.subscribeUrl,
            subscriptionInfo: SubscriptionInfo(
              upload: subscription.upload,
              download: subscription.download,
              total: subscription.transferEnable,
              expire: subscription.expiredAt,
            ),
          )
          .copyWith(
            subscriptionInfo: downloaded.subscriptionUserInfo == null
                ? SubscriptionInfo(
                    upload: subscription.upload,
                    download: subscription.download,
                    total: subscription.transferEnable,
                    expire: subscription.expiredAt,
                  )
                : SubscriptionInfo.formHString(downloaded.subscriptionUserInfo),
          )
          .saveFile(downloaded.bytes);
      ref.read(profilesProvider.notifier).setProfile(updated);
      await globalState.appController.savePreferences();
      await globalState.appController.applyProfile(silence: true);
      if (mounted) {
        globalState.showNotifier(
          whiteLabelStringsOf(context).subscriptionUpdated,
        );
      }
    } catch (error) {
      globalState.showNotifier(error.toString());
    } finally {
      await WhiteLabelBackendProxy.stopIfTemporary();
      if (mounted) setState(() => _refreshingSubscription = false);
    }
  }

  Widget? _buildFAB() {
    return _isTab
        ? DelayTestButton(
            onClick: () async {
              await _proxiesTabKey.currentState?.delayTestCurrentGroup();
            },
          )
        : null;
  }

  void _onSearch(String value) {
    ref.read(queryProvider.notifier).value = value;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(providersProvider.select((state) => state.isNotEmpty), (
      prev,
      next,
    ) {
      if (prev != next) {
        setState(() {
          _hasProviders = next;
        });
      }
    }, fireImmediately: true);
    ref.listenManual(
      proxiesStyleSettingProvider.select(
        (state) => state.type == ProxiesType.tab,
      ),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _isTab = next;
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final hasGroups = ref.watch(
      groupsProvider.select((state) => state.isNotEmpty),
    );
    ref.watch(appSettingProvider.select((state) => state.locale));
    return CommonScaffold(
      floatingActionButton: _buildFAB(),
      actions: _buildActions(),
      title: appLocalizations.proxies,
      searchState: AppBarSearchState(onSearch: _onSearch),
      body: switch (hasGroups) {
        false => NullStatus(label: appLocalizations.noProxy),
        true => switch (proxiesType) {
          ProxiesType.tab => ProxiesTabView(key: _proxiesTabKey),
          ProxiesType.list => const ProxiesListView(),
        },
      },
    );
  }
}

class _IconConfigView extends ConsumerWidget {
  const _IconConfigView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconMap = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.iconMap),
    );
    return MapInputPage(
      title: appLocalizations.iconConfiguration,
      map: iconMap,
      keyLabel: appLocalizations.regExp,
      valueLabel: appLocalizations.icon,
      titleBuilder: (item) => Text(item.key),
      leadingBuilder: (item) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(src: item.value, size: 42),
      ),
      subtitleBuilder: (item) =>
          Text(item.value, maxLines: 2, overflow: TextOverflow.ellipsis),
      onChange: (value) {
        ref
            .read(proxiesStyleSettingProvider.notifier)
            .updateState((state) => state.copyWith(iconMap: value));
      },
    );
  }
}
