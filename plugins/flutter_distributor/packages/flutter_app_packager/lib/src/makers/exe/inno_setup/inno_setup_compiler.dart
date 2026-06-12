import 'dart:io';

import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_script.dart';
import 'package:path/path.dart' as p;
import 'package:shell_executor/shell_executor.dart';

class InnoSetupCompiler {
  Future<bool> compile(InnoSetupScript script) async {
    final candidates = <Directory>[
      Directory('C:\\Program Files (x86)\\Inno Setup 6'),
      Directory('C:\\Program Files\\Inno Setup 6'),
    ];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      candidates.add(
        Directory(p.join(localAppData, 'Programs', 'Inno Setup 6')),
      );
    }
    final innoSetupDirectory = candidates.firstWhere(
      (directory) => File(p.join(directory.path, 'ISCC.exe')).existsSync(),
      orElse: () => candidates.first,
    );

    if (!innoSetupDirectory.existsSync()) {
      throw Exception('`Inno Setup 6` was not installed.');
    }

    File file = await script.createFile();

    ProcessResult processResult = await $(
      p.join(innoSetupDirectory.path, 'ISCC.exe'),
      [file.path],
    );

    if (processResult.exitCode != 0) {
      return false;
    }

    file.deleteSync(recursive: true);
    return true;
  }
}
