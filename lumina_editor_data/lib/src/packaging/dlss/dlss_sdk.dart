/// The NVIDIA DLSS SDK (NGX) a game builds against: flutter_filament's
/// `build/dlss-sdk/`, filled by `tool/dlss/fetch_sdk.dart` and pinned by
/// `tool/dlss/VERSION` + `tool/dlss/manifest.txt`.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// One line of `tool/dlss/manifest.txt`: a file's SHA-256, size and path
/// (relative to `build/dlss-sdk/`).
class DlssManifestEntry {
  final String sha256;
  final int size;
  final String path;

  const DlssManifestEntry(this.sha256, this.size, this.path);

  /// The file name without its folders (`nvngx_dlss.dll`).
  String get fileName => path.split('/').last;

  /// The lines of a manifest; `#` comments and blank lines are skipped.
  static List<DlssManifestEntry> parse(String text) {
    final entries = <DlssManifestEntry>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length != 3) throw FormatException('bad DLSS manifest line: $raw');
      entries.add(DlssManifestEntry(parts[0].toLowerCase(), int.parse(parts[1]), parts[2]));
    }
    return entries;
  }
}

/// The DLSS SDK of one flutter_filament package and how much of it is on disk.
class DlssSdk {
  /// The flutter_filament package root.
  final String packageRoot;

  /// The pinned release tag (`v310.9.1`).
  final String version;

  final List<DlssManifestEntry> manifest;

  /// Manifest paths that are absent from [sdkDir] or have the wrong size.
  final List<String> missing;

  const DlssSdk({required this.packageRoot, required this.version, required this.manifest, this.missing = const []});

  /// The command that fetches the SDK, run in [packageRoot].
  static const String fetchCommand = 'dart run tool/dlss/fetch_sdk.dart';

  /// Where the runtime libraries of a target live in the SDK.
  static const Map<String, String> runtimeFolders = {
    'windows': 'lib/Windows_x86_64/rel/',
    'linux': 'lib/Linux_x86_64/rel/',
  };

  /// The SDK's licence, relative to [sdkDir].
  static const String licensePath = 'LICENSE.txt';

  /// Only Windows and Linux games can load the NGX runtime.
  static bool supportsTarget(String target) => runtimeFolders.containsKey(target);

  String get sdkDir => p.join(packageRoot, 'build', 'dlss-sdk');

  String get licenseFile => p.join(sdkDir, licensePath);

  bool get isFetched => missing.isEmpty;

  /// The version without the tag's `v` (`310.9.1`).
  String get versionNumber => version.startsWith('v') ? version.substring(1) : version;

  /// Why the SDK cannot be bundled yet, with how to fetch it.
  String get missingReason => 'The NVIDIA DLSS SDK $version is not fetched into $sdkDir (${missing.length} file(s) missing). '
      'Run `$fetchCommand` in $packageRoot, or use Fetch DLSS SDK in Project Settings > Packaging.';

  /// The manifest's runtime libraries for [target] (empty for targets that
  /// cannot load them).
  List<DlssManifestEntry> runtimeEntriesFor(String target) {
    final folder = runtimeFolders[target];
    if (folder == null) return const [];
    return [
      for (final e in manifest)
        if (e.path.startsWith(folder) && !e.path.substring(folder.length).contains('/')) e,
    ];
  }

  DlssManifestEntry? get licenseEntry {
    for (final e in manifest) {
      if (e.path == licensePath) return e;
    }
    return null;
  }

  /// Reads the SDK of the flutter_filament package at [packageRoot]; null when
  /// it has no `tool/dlss/manifest.txt`. Runs on a background isolate.
  static Future<DlssSdk?> read(String packageRoot) => Isolate.run(() => readSync(packageRoot));

  /// The flutter_filament a game at [projectDir] builds against: the one its
  /// `.dart_tool/package_config.json` resolves (a local engine override or a
  /// git checkout in the pub cache), else the first of [fallbackPackageRoots]
  /// (default: the editor's source checkout) that has the DLSS tooling.
  /// Runs on a background isolate.
  static Future<DlssSdk?> locate(String projectDir, {List<String>? fallbackPackageRoots}) =>
      Isolate.run(() => locateSync(projectDir, fallbackPackageRoots: fallbackPackageRoots));

  /// [locate] on the calling isolate (tests, CLI tools, worker isolates).
  static DlssSdk? locateSync(String projectDir, {List<String>? fallbackPackageRoots}) {
    final resolved = projectDir.isEmpty ? null : LuminaWorkspace.resolvedPackageDir(projectDir, 'flutter_filament');
    if (resolved != null) {
      // The game's native code is compiled from this package: its SDK is the
      // one that decides whether the game has DLSS at all.
      final sdk = readSync(resolved);
      if (sdk != null) return sdk;
    }
    final fallbacks = fallbackPackageRoots ?? _editorPackageRoots();
    for (final root in fallbacks) {
      final sdk = readSync(root);
      if (sdk != null) return sdk;
    }
    return null;
  }

  static List<String> _editorPackageRoots() {
    final root = LuminaWorkspace.findSourceRoot();
    return root == null ? const [] : [LuminaWorkspace.packageIn(root, 'flutter_filament')];
  }

  /// [read] on the calling isolate.
  static DlssSdk? readSync(String packageRoot) {
    final manifestFile = File(p.join(packageRoot, 'tool', 'dlss', 'manifest.txt'));
    final versionFile = File(p.join(packageRoot, 'tool', 'dlss', 'VERSION'));
    if (!manifestFile.existsSync() || !versionFile.existsSync()) return null;
    final manifest = DlssManifestEntry.parse(manifestFile.readAsStringSync());
    final sdkDir = p.join(packageRoot, 'build', 'dlss-sdk');
    final missing = <String>[
      for (final e in manifest)
        if (!_sizeMatches(File(p.join(sdkDir, e.path)), e.size)) e.path,
    ];
    return DlssSdk(packageRoot: packageRoot, version: versionFile.readAsStringSync().trim(), manifest: manifest, missing: missing);
  }

  static bool _sizeMatches(File f, int size) => f.existsSync() && f.lengthSync() == size;

  /// The same SDK read again from disk (after a fetch).
  Future<DlssSdk> refresh() async => await read(packageRoot) ?? this;

  /// Checks size and SHA-256 of [entries] in [sdkDir] on a background
  /// isolate; returns one problem per file that does not match (empty: all
  /// match).
  Future<List<String>> verify(List<DlssManifestEntry> entries) {
    final dir = sdkDir;
    return Isolate.run(() => verifySync(dir, entries));
  }

  /// [verify] on the calling isolate.
  static List<String> verifySync(String sdkDir, List<DlssManifestEntry> entries) {
    final problems = <String>[];
    for (final e in entries) {
      final problem = verifyFileSync(File(p.join(sdkDir, e.path)), e);
      if (problem != null) problems.add(problem);
    }
    return problems;
  }

  /// Why [file] is not [entry] (missing, size or SHA-256), or null.
  static String? verifyFileSync(File file, DlssManifestEntry entry) {
    if (!file.existsSync()) return '${entry.path}: missing';
    final size = file.lengthSync();
    if (size != entry.size) return '${entry.path}: $size bytes, the manifest says ${entry.size}';
    final digest = sha256Sync(file);
    if (digest != entry.sha256) return '${entry.path}: SHA-256 $digest, the manifest says ${entry.sha256}';
    return null;
  }

  /// The hex SHA-256 of [file], read in chunks.
  static String sha256Sync(File file) {
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    final raf = file.openSync();
    try {
      final buffer = List<int>.filled(1 << 20, 0);
      while (true) {
        final n = raf.readIntoSync(buffer);
        if (n <= 0) break;
        input.add(n == buffer.length ? buffer : buffer.sublist(0, n));
      }
    } finally {
      raf.closeSync();
    }
    input.close();
    return output.value.toString();
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
