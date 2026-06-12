import 'dart:async';

import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';

class WhiteLabelBackendProxy {
  static Future<void>? _starting;
  static bool _temporaryStarted = false;

  static String get localProxy => '$localhost:$whiteLabelBackendProxyPort';

  static Future<bool> ensureStarted() async {
    if (whiteLabelBootstrapProxy.trim().isEmpty) {
      return false;
    }
    if (globalState.isStart) {
      return true;
    }
    if (_temporaryStarted) {
      return true;
    }
    _starting ??= _startTemporary();
    try {
      await _starting;
      return _temporaryStarted;
    } finally {
      _starting = null;
    }
  }

  static Future<void> stopIfTemporary() async {
    if (!_temporaryStarted || globalState.isStart) {
      return;
    }
    try {
      await clashCore.stopListener();
    } catch (e) {
      commonPrint.log('Failed to stop WhiteLabel backend proxy: $e');
    } finally {
      _temporaryStarted = false;
    }
  }

  static Future<void> _startTemporary() async {
    try {
      final isInit = await clashCore.isInit;
      if (!isInit) {
        await clashCore.init();
        await clashCore.setState(globalState.getCoreState());
      }
      final params = SetupParams(
        config: _buildBootstrapConfig(),
        selectedMap: const {},
        testUrl: defaultTestUrl,
      );
      final message = await clashCore.setupConfig(params);
      if (message.isNotEmpty) {
        throw message;
      }
      await clashCore.startListener();
      final reloadMessage = await clashCore.setupConfig(params);
      if (reloadMessage.isNotEmpty) {
        throw reloadMessage;
      }
      _temporaryStarted = true;
    } catch (e) {
      commonPrint.log('Failed to start WhiteLabel backend proxy: $e');
      _temporaryStarted = false;
      rethrow;
    }
  }

  static Map<String, dynamic> _buildBootstrapConfig() {
    if (whiteLabelBootstrapProxy.trim().isEmpty) {
      throw StateError('BOOTSTRAP_PROXY_URI is not configured.');
    }
    final uri = Uri.parse(whiteLabelBootstrapProxy);
    final password = Uri.decodeComponent(uri.userInfo);
    final name = uri.fragment.isEmpty
        ? whiteLabelBootstrapProxyName
        : Uri.decodeComponent(uri.fragment);
    final serverName = uri.queryParameters['sni'] ?? uri.host;

    return {
      'mixed-port': whiteLabelBackendProxyPort,
      'allow-lan': false,
      'mode': Mode.rule.name,
      'log-level': LogLevel.error.name,
      'ipv6': false,
      'tcp-concurrent': true,
      'unified-delay': true,
      'proxies': [
        {
          'name': name,
          'type': 'trojan',
          'server': uri.host,
          'port': uri.port,
          'password': password,
          'sni': serverName,
          'skip-cert-verify': false,
        },
      ],
      'rule': ['MATCH,$name'],
    };
  }
}
