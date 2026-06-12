import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  void register(String scheme) {
    String protocolRegKey = 'Software\\Classes\\$scheme';
    RegistryValue protocolRegValue = RegistryValue.string('URL Protocol', '');
    String protocolCmdRegKey = 'shell\\open\\command';
    RegistryValue protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }

  void unregister(String scheme) {
    try {
      Registry.currentUser.deleteKey(
        'Software\\Classes\\$scheme',
        recursive: true,
      );
    } catch (_) {}
  }

  void unregisterAll(Iterable<String> schemes) {
    for (final scheme in schemes) {
      unregister(scheme);
    }
  }
}

final protocol = Protocol();
