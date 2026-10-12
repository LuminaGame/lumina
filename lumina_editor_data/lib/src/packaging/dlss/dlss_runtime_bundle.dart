/// Copies NVIDIA's DLSS runtime into a packaged Windows or Linux game.
library;

import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/packaging/dlss/dlss_sdk.dart';
import 'package:path/path.dart' as p;

/// One file [DlssRuntimeBundle.bundleInto] put into a package.
class DlssBundledFile {
  /// The name in the package (`nvngx_dlss.dll`, `NVIDIA_DLSS_LICENSE.txt`).
  final String name;
  final int bytes;

  /// Empty for the generated notice.
  final String sha256;

  const DlssBundledFile(this.name, this.bytes, this.sha256);
}

/// What [DlssRuntimeBundle.bundleInto] did for one target.
class DlssBundleReport {
  final String target;
  final String packageDir;
  final List<DlssBundledFile> files;

  /// Set when nothing was bundled on purpose (a target that cannot load the
  /// runtime).
  final String? skippedReason;

  const DlssBundleReport({required this.target, required this.packageDir, this.files = const [], this.skippedReason});

  bool get bundled => files.isNotEmpty;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.bytes);
}

/// The bundle was refused: the SDK is missing or a file does not match the
/// manifest. Nothing was copied.
class DlssBundleRefused implements Exception {
  final String message;
  final List<String> problems;

  const DlssBundleRefused(this.message, [this.problems = const []]);

  @override
  String toString() => problems.isEmpty ? message : '$message: ${problems.join('; ')}';
}

/// Puts the NGX runtime libraries of the fetched DLSS SDK next to a packaged
/// game's executable (the runtime lookup searches the executable's folder),
/// with NVIDIA's licence and a notice. Windows and Linux only.
class DlssRuntimeBundle {
  DlssRuntimeBundle._();

  /// NVIDIA's licence text in the package.
  static const String licenseFileName = 'NVIDIA_DLSS_LICENSE.txt';

  /// What the package holds from NVIDIA and under which terms.
  static const String noticeFileName = 'NVIDIA_DLSS_NOTICE.txt';

  /// The names a package of [target] gets (empty for other targets).
  static List<String> packagedNamesFor(DlssSdk sdk, String target) => DlssSdk.supportsTarget(target)
      ? [for (final e in sdk.runtimeEntriesFor(target)) e.fileName, licenseFileName, noticeFileName]
      : const [];

  /// Verifies the runtime libraries of [target] and the licence against the
  /// manifest (size + SHA-256, on a background isolate), then copies them
  /// flat into [packageDir] (the folder holding the executable). Targets
  /// other than Windows and Linux get nothing. Throws [DlssBundleRefused],
  /// without copying anything, when the SDK is incomplete or a file does not
  /// match.
  static Future<DlssBundleReport> bundleInto(DlssSdk sdk, {required String target, required String packageDir}) async {
    if (!DlssSdk.supportsTarget(target)) {
      return DlssBundleReport(
        target: target,
        packageDir: packageDir,
        skippedReason: 'the NVIDIA DLSS runtime is only bundled into Windows and Linux packages',
      );
    }
    final runtime = sdk.runtimeEntriesFor(target);
    final license = sdk.licenseEntry;
    if (runtime.isEmpty || license == null) {
      throw DlssBundleRefused('The DLSS manifest of ${sdk.packageRoot} lists no ${sdk.versionNumber} runtime for $target or no licence');
    }
    final entries = [...runtime, license];
    final absent = [for (final e in entries) if (sdk.missing.contains(e.path)) e.path];
    if (absent.isNotEmpty) throw DlssBundleRefused(sdk.missingReason, absent);
    final problems = await sdk.verify(entries);
    if (problems.isNotEmpty) {
      throw DlssBundleRefused('The DLSS SDK in ${sdk.sdkDir} does not match tool/dlss/manifest.txt; nothing was bundled', problems);
    }
    final out = Directory(packageDir);
    if (!await out.exists()) await out.create(recursive: true);
    final files = <DlssBundledFile>[];
    for (final e in runtime) {
      await File(p.join(sdk.sdkDir, e.path)).copy(p.join(packageDir, e.fileName));
      files.add(DlssBundledFile(e.fileName, e.size, e.sha256));
    }
    await File(p.join(sdk.sdkDir, license.path)).copy(p.join(packageDir, licenseFileName));
    files.add(DlssBundledFile(licenseFileName, license.size, license.sha256));
    final notice = noticeText(sdk, runtime);
    await File(p.join(packageDir, noticeFileName)).writeAsString(notice);
    files.add(DlssBundledFile(noticeFileName, notice.length, ''));
    return DlssBundleReport(target: target, packageDir: packageDir, files: files);
  }

  /// The notice written next to the runtime.
  static String noticeText(DlssSdk sdk, List<DlssManifestEntry> runtime) {
    final b = StringBuffer()
      ..writeln('NVIDIA DLSS runtime')
      ..writeln()
      ..writeln('This package contains the following files from the NVIDIA DLSS SDK ${sdk.version}')
      ..writeln('(https://github.com/NVIDIA/DLSS):')
      ..writeln();
    for (final e in runtime) {
      b.writeln('  ${e.fileName}  ${e.size} bytes  sha256 ${e.sha256}');
    }
    b
      ..writeln()
      ..writeln('They are software of NVIDIA Corporation, redistributed in object code form under the')
      ..writeln('NVIDIA RTX SDKs licence (see $licenseFileName), not under the licence of this game or of')
      ..writeln('the Lumina engine. They are used only on NVIDIA RTX GPUs; on any other GPU the game runs')
      ..writeln('without them.')
      ..writeln()
      ..writeln('NVIDIA, RTX and DLSS are trademarks and/or registered trademarks of NVIDIA Corporation.');
    return b.toString();
  }

  /// The log lines of a report: one per file, then the total.
  static List<String> describe(DlssBundleReport report) {
    if (!report.bundled) {
      return ['NVIDIA DLSS runtime not bundled for ${packagingPlatformLabel(report.target)}: ${report.skippedReason ?? 'nothing to bundle'}'];
    }
    return [
      for (final f in report.files)
        'NVIDIA DLSS: bundled ${f.name} (${_formatBytes(f.bytes)}${f.sha256.isEmpty ? '' : ', sha256 ${f.sha256}'})',
      'NVIDIA DLSS runtime bundled into ${report.packageDir}: ${report.files.length} file(s), ${_formatBytes(report.totalBytes)}',
    ];
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
