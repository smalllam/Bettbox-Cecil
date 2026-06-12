import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/state.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class WhiteLabelUpdateInfo {
  final String version;
  final String releaseNotes;
  final String packageUrl;
  final String? packageUrlFallback;
  final String? sha256;
  final int size;
  final String? setupUrl;
  final String? setupUrlFallback;
  final String? setupSha256;
  final int setupSize;
  final Uri manifestUri;

  const WhiteLabelUpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.packageUrl,
    required this.manifestUri,
    this.packageUrlFallback,
    this.sha256,
    this.size = 0,
    this.setupUrl,
    this.setupUrlFallback,
    this.setupSha256,
    this.setupSize = 0,
  });

  bool get hasVersion => version.trim().isNotEmpty;

  bool get isNewer {
    if (!hasVersion) return false;
    return utils.compareVersions(version, globalState.packageInfo.version) > 0;
  }

  WhiteLabelUpdateAsset get preferredAsset {
    if (system.isWindows && (setupUrl?.isNotEmpty ?? false)) {
      return WhiteLabelUpdateAsset(
        url: setupUrl!,
        fallbackUrl: setupUrlFallback,
        sha256: setupSha256,
        size: setupSize,
        extension: '.exe',
      );
    }
    return WhiteLabelUpdateAsset(
      url: packageUrl,
      fallbackUrl: packageUrlFallback,
      sha256: sha256,
      size: size,
      extension: system.isAndroid ? '.apk' : p.extension(packageUrl),
    );
  }

  static WhiteLabelUpdateInfo fromJson(
    Map<String, dynamic> json,
    Uri manifestUri,
  ) {
    return WhiteLabelUpdateInfo(
      version: json['version']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      packageUrl: json['packageUrl']?.toString() ?? '',
      packageUrlFallback: json['packageUrlFallback']?.toString(),
      sha256: json['sha256']?.toString(),
      size: _toInt(json['size']),
      setupUrl: json['setupUrl']?.toString(),
      setupUrlFallback: json['setupUrlFallback']?.toString(),
      setupSha256: json['setupSha256']?.toString(),
      setupSize: _toInt(json['setupSize']),
      manifestUri: manifestUri,
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class WhiteLabelUpdateAsset {
  final String url;
  final String? fallbackUrl;
  final String? sha256;
  final int size;
  final String extension;

  const WhiteLabelUpdateAsset({
    required this.url,
    this.fallbackUrl,
    this.sha256,
    this.size = 0,
    this.extension = '',
  });
}

class WhiteLabelUpdateService {
  static const _autoCheckKey = 'white_label_last_auto_update_check';
  static const _autoCheckInterval = Duration(hours: 12);
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': browserUa, 'Accept': 'application/json'},
    ),
  );

  static Future<void> autoCheck() async {
    if (!system.isAndroid && !system.isWindows) return;
    if (!_hasUpdateEndpoint) return;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final lastCheck = prefs?.getInt(_autoCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCheck < _autoCheckInterval.inMilliseconds) return;
    await prefs?.setInt(_autoCheckKey, now);
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 3),
        () => checkAndPrompt(silent: true),
      ),
    );
  }

  static Future<void> checkAndPrompt({bool silent = false}) async {
    if (!system.isAndroid && !system.isWindows) {
      if (!silent) {
        await _message('版本更新', '当前平台不支持在线更新。');
      }
      return;
    }
    if (!_hasUpdateEndpoint) {
      if (!silent) {
        await _message('版本更新', '更新接口未配置。');
      }
      return;
    }

    try {
      final updateInfo = await fetchUpdateInfo();
      if (!updateInfo.isNewer) {
        if (!silent) {
          await _message('版本更新', '当前已是最新版本。');
        }
        return;
      }
      final accepted = await _showUpdatePrompt(updateInfo);
      if (accepted == true) {
        await downloadAndOpen(updateInfo);
      }
    } catch (e) {
      commonPrint.log('Update check failed: $e');
      if (!silent) {
        await _message('版本更新失败', e.toString());
      }
    }
  }

  static Future<WhiteLabelUpdateInfo> fetchUpdateInfo() async {
    final endpoint = system.isWindows
        ? whiteLabelWindowsUpdateUrl
        : whiteLabelAndroidUpdateUrl;
    if (endpoint.trim().isEmpty) {
      throw '更新接口未配置。';
    }
    final manifestUri = Uri.parse(endpoint);
    final response = await _dio.getUri<String>(
      manifestUri,
      options: Options(responseType: ResponseType.plain),
    );
    final data = response.data;
    if (data == null || data.trim().isEmpty) {
      throw '更新接口返回为空。';
    }
    final decoded = json.decode(data);
    if (decoded is! Map) {
      throw '更新接口格式无效。';
    }
    return WhiteLabelUpdateInfo.fromJson(
      Map<String, dynamic>.from(decoded),
      manifestUri,
    );
  }

  static bool get _hasUpdateEndpoint =>
      (system.isWindows
              ? whiteLabelWindowsUpdateUrl
              : whiteLabelAndroidUpdateUrl)
          .trim()
          .isNotEmpty;

  static Future<void> downloadAndOpen(WhiteLabelUpdateInfo updateInfo) async {
    final asset = updateInfo.preferredAsset;
    if (asset.url.trim().isEmpty) {
      throw '更新接口未提供下载地址。';
    }

    globalState.showNotifier('正在下载更新...');
    final file = await _downloadAsset(updateInfo, asset);
    await _verifySha256(file, asset.sha256);
    await _openDownloadedFile(file);
  }

  static Future<File> _downloadAsset(
    WhiteLabelUpdateInfo updateInfo,
    WhiteLabelUpdateAsset asset,
  ) async {
    final updateDir = Directory(p.join(await appPath.homeDirPath, 'updates'));
    await updateDir.create(recursive: true);
    final fileName = _fileName(updateInfo, asset);
    final targetFile = File(p.join(updateDir.path, fileName));
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final urls = _candidateUrls(updateInfo.manifestUri, asset);
    Object? lastError;
    for (final url in urls) {
      try {
        await _dio.downloadUri(
          url,
          targetFile.path,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            if (total > 0 && received == total) {
              globalState.showNotifier(
                'Download complete. Preparing update...',
              );
            }
          },
        );
        if (await targetFile.length() == 0) {
          throw '下载文件为空。';
        }
        return targetFile;
      } catch (e) {
        lastError = e;
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      }
    }
    throw lastError ?? '下载失败。';
  }

  static Future<void> _verifySha256(File file, String? expected) async {
    final normalized = expected?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return;
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (actual != normalized) {
      try {
        await file.delete();
      } catch (_) {}
      throw '更新包校验失败，请稍后重试。';
    }
  }

  static Future<void> _openDownloadedFile(File file) async {
    if (system.isAndroid) {
      final opened = await app.openFile(file.path);
      if (!opened) {
        throw '无法打开安装包，请手动安装下载文件。';
      }
      return;
    }

    if (system.isWindows) {
      final extension = p.extension(file.path).toLowerCase();
      if (extension == '.exe') {
        await Process.start(
          file.path,
          const [],
          mode: ProcessStartMode.detached,
        );
        globalState.showNotifier('安装程序已启动，请按提示完成更新。');
      } else {
        await Process.start('explorer.exe', ['/select,', file.path]);
        globalState.showNotifier('更新包已下载，请手动安装。');
      }
      return;
    }

    await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
  }

  static Future<bool?> _showUpdatePrompt(WhiteLabelUpdateInfo updateInfo) {
    final asset = updateInfo.preferredAsset;
    final size = _formatSize(asset.size);
    final notes = updateInfo.releaseNotes.trim().isEmpty
        ? '修复问题并优化使用体验'
        : updateInfo.releaseNotes.trim();
    return globalState.showMessage(
      title: '发现新版本',
      confirmText: '立即更新',
      message: TextSpan(
        text:
            '当前版本：${globalState.packageInfo.version}\n'
            '最新版本：${updateInfo.version}\n'
            '${size.isEmpty ? '' : '文件大小：$size\n'}'
            '\n$notes',
      ),
    );
  }

  static Future<void> _message(String title, String message) {
    return globalState.showMessage(
      title: title,
      cancelable: false,
      message: TextSpan(text: message),
    );
  }

  static List<Uri> _candidateUrls(
    Uri manifestUri,
    WhiteLabelUpdateAsset asset,
  ) {
    final urls = <Uri>[];
    void add(String? value) {
      if (value == null || value.trim().isEmpty) return;
      final uri = Uri.parse(value.trim());
      urls.add(uri.hasScheme ? uri : manifestUri.resolve(value.trim()));
    }

    add(asset.url);
    add(asset.fallbackUrl);
    return urls;
  }

  static String _fileName(
    WhiteLabelUpdateInfo updateInfo,
    WhiteLabelUpdateAsset asset,
  ) {
    final urlName = p.basename(Uri.parse(asset.url).path);
    if (urlName.isNotEmpty && urlName.contains('.')) return urlName;
    final extension = asset.extension.isEmpty ? '.bin' : asset.extension;
    return '${whiteLabelDisplayName.replaceAll(RegExp(r"\\s+"), "-")}-${updateInfo.version}$extension';
  }

  static String _formatSize(int size) {
    if (size <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
