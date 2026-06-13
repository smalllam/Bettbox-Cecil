import 'package:bett_box/models/common.dart';
import 'package:bett_box/white_label/white_label_config.dart';

bool isWhiteLabelSensitiveTrackerInfo(TrackerInfo info) {
  final proxyNames = _sensitiveProxyNames();
  if (proxyNames.isNotEmpty &&
      info.chains.any((chain) => proxyNames.contains(_normalizeName(chain)))) {
    return true;
  }

  final hosts = _sensitiveHosts();
  if (hosts.isEmpty) return false;

  final candidates = <String>{
    ..._hostCandidates(info.metadata.host),
    ..._hostCandidates(info.metadata.destinationIP),
    ..._hostCandidates(info.metadata.remoteDestination),
  };

  return candidates.any(
    (candidate) => hosts.any((host) => _hostMatches(candidate, host)),
  );
}

Set<String> _sensitiveHosts() {
  return {
    ..._hostCandidates(whiteLabelApiBaseUrl),
    ..._hostCandidates(whiteLabelPanelBaseUrl),
    ..._hostCandidates(whiteLabelBootstrapProxy),
    ..._hostCandidates(whiteLabelConfigTxtHost),
    ..._hostCandidates(whiteLabelAndroidUpdateUrl),
    ..._hostCandidates(whiteLabelWindowsUpdateUrl),
    ..._hostCandidates(whiteLabelSupportUri),
    ..._hostCandidates(whiteLabelSupportUrl),
  };
}

Set<String> _sensitiveProxyNames() {
  final bootProxy = whiteLabelBootstrapProxy.trim();
  if (bootProxy.isEmpty) return {};
  return {
    _normalizeName(whiteLabelBootstrapProxyName),
    _normalizeName(Uri.tryParse(bootProxy)?.fragment ?? ''),
  }..removeWhere((value) => value.isEmpty);
}

Set<String> _hostCandidates(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return {};

  final hosts = <String>{};
  final uri = Uri.tryParse(trimmed);
  final uriHost = _normalizeHost(uri?.host ?? '');
  if (uriHost.isNotEmpty) hosts.add(uriHost);

  if (!trimmed.contains('://')) {
    final inferred = Uri.tryParse('scheme://$trimmed');
    final inferredHost = _normalizeHost(inferred?.host ?? '');
    if (inferredHost.isNotEmpty) hosts.add(inferredHost);
  }

  final withoutScheme = trimmed.replaceFirst(
    RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://'),
    '',
  );
  final withoutUser = withoutScheme.contains('@')
      ? withoutScheme.substring(withoutScheme.lastIndexOf('@') + 1)
      : withoutScheme;
  final withoutPath = withoutUser.split(RegExp(r'[/#?]')).first;
  final fallbackHost = withoutPath.startsWith('[')
      ? withoutPath.split(']').first.replaceFirst('[', '')
      : withoutPath.split(':').first;
  final normalizedFallback = _normalizeHost(fallbackHost);
  if (normalizedFallback.isNotEmpty) hosts.add(normalizedFallback);

  return hosts;
}

bool _hostMatches(String candidate, String host) {
  final normalizedCandidate = _normalizeHost(candidate);
  final normalizedHost = _normalizeHost(host);
  if (normalizedCandidate.isEmpty || normalizedHost.isEmpty) return false;
  return normalizedCandidate == normalizedHost ||
      normalizedCandidate.endsWith('.$normalizedHost');
}

String _normalizeName(String value) => value.trim().toLowerCase();

String _normalizeHost(String value) {
  var host = value.trim().toLowerCase();
  if (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  return host;
}
