import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_core/src/services/filament_prebuilt.dart';
import 'package:lumina_core/src/services/release_asset.dart';

/// A prebuilt Jolt Physics archive could not be fetched, verified or
/// unpacked.
class JoltPrebuiltException implements Exception {
  final String message;
  const JoltPrebuiltException(this.message);

  @override
  String toString() => 'JoltPrebuiltException: $message';
}

/// The prebuilt Jolt Physics build attached to each Lumina GitHub release
/// (`.github/scripts/package_jolt.sh` packs it): the headers, static library
/// and `jolt_defines.txt` flutter_jolt's native-assets hook compiles and
/// links against, built by the release from the Jolt tag the tools commit
/// that release pins names (`flutter_jolt/tool/jolt_version.txt`). A release
/// checkout resolves flutter_jolt from git (the pub cache), where Jolt is not
/// built; the root pubspec's `jolt_dir` user-define names the checkout's
/// `jolt`, which the bootstrap links here. Without it the hook builds no
/// Jolt and the engine runs its Dart physics.
///
/// Release assets, per platform: `<baseUrl>/<releaseTag>/jolt-<os>-<arch>.<zip|tar.gz>`
/// plus a `.sha256` sidecar (`<arch>` is `x64`, or `arm64` for Linux arm64;
/// [ReleaseAssets.platformName]). The archive holds one folder,
/// `jolt-<os>-<arch>`, with `include/Jolt/...`, `lib/<Jolt.lib|libJolt.a>`,
/// `jolt_defines.txt`, `VERSION`, the Jolt `LICENSE` and a
/// `lumina-jolt.json` describing it.
///
/// The build belongs to its release (the tools pin), so [ensure] unpacks it
/// to `<cacheRoot>/<releaseTag>`; an unpacked one is reused without the
/// network.
abstract final class JoltPrebuilt {
  /// The provenance file at the top of every archive.
  static const String infoFileName = 'lumina-jolt.json';

  /// The OS name used in asset names for [operatingSystem].
  static String osName([String? operatingSystem]) => ReleaseAssets.osName(
      operatingSystem, (_) => JoltPrebuiltException('No prebuilt Jolt Physics for ${operatingSystem ?? Platform.operatingSystem}.'));

  /// `jolt-<os>-<arch>`: the archive's folder, and its file name
  /// without the extension (the host's architecture on Linux).
  static String baseName([String? operatingSystem]) => 'jolt-${ReleaseAssets.platformName(osName(operatingSystem))}';

  /// The archive's file name: `.zip` on Windows, `.tar.gz` elsewhere.
  static String archiveName([String? operatingSystem]) {
    final os = osName(operatingSystem);
    return '${baseName(os)}.${ReleaseAssets.archiveExtension(os)}';
  }

  /// The static library's file name, as the hook links it.
  static String libraryName([String? operatingSystem]) => osName(operatingSystem) == 'windows' ? 'Jolt.lib' : 'libJolt.a';

  /// What a complete build holds besides the library.
  static const List<String> requiredFiles = ['jolt_defines.txt', 'include/Jolt/Jolt.h'];

  /// The archive's download URL.
  static Uri archiveUri(String releaseTag, {String? operatingSystem, String baseUrl = ReleaseAssets.defaultBaseUrl}) =>
      ReleaseAssets.assetUri(baseUrl, releaseTag, archiveName(operatingSystem));

  /// The cache folder of [releaseTag]: `<cacheRoot>/<releaseTag>` (characters
  /// a folder name cannot hold replaced).
  static Directory dirFor(Directory cacheRoot, String releaseTag) =>
      Directory(p.join(cacheRoot.path, releaseTag.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_')));

  /// The cache folder of [releaseTag] when it holds the unpacked library for
  /// this OS, else null.
  static Directory? installed(Directory cacheRoot, String releaseTag, {String? operatingSystem}) {
    final os = osName(operatingSystem);
    final dir = dirFor(cacheRoot, releaseTag);
    final info = ReleaseAssets.readInfo(dir, infoFileName);
    if (info == null || info['platform'] != ReleaseAssets.platformName(os)) return null;
    return _complete(dir, os) ? dir : null;
  }

  static bool _complete(Directory dir, String os) {
    if (!File(p.join(dir.path, 'lib', libraryName(os))).existsSync()) return false;
    return requiredFiles.every((f) => File(p.join(dir.path, f)).existsSync());
  }

  /// Makes `<cacheRoot>/<releaseTag>` the unpacked Jolt build of the
  /// [releaseTag] release for this OS, downloading it when it is not there
  /// yet, and returns it: the folder `jolt_dir` names.
  /// Checked against the `.sha256` sidecar before anything is unpacked.
  ///
  /// [baseUrl] replaces [ReleaseAssets.defaultBaseUrl]; so does
  /// [ReleaseAssets.baseUrlVariable], else [FilamentPrebuilt.baseUrlVariable] (a
  /// mirror of the release's Filament holds the whole release). [force]
  /// downloads again even when it is installed.
  static Future<Directory> ensure({
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
    String? operatingSystem,
    String? baseUrl,
    bool force = false,
    HttpClient? httpClient,
  }) async {
    final os = osName(operatingSystem);
    if (!force) {
      final found = installed(cacheRoot, releaseTag, operatingSystem: os);
      if (found != null) {
        onProgress?.call(1, 'Jolt Physics for $releaseTag is already installed');
        return found;
      }
    }
    final base = baseUrl ??
        ReleaseAssets.baseUrlFromEnvironment(const [ReleaseAssets.baseUrlVariable, FilamentPrebuilt.baseUrlVariable]) ??
        ReleaseAssets.defaultBaseUrl;
    final lib = libraryName(os);
    final dir = await ReleaseAssets.fetch(
      uri: archiveUri(releaseTag, operatingSystem: os, baseUrl: base),
      folder: baseName(os),
      infoFileName: infoFileName,
      accept: (info) => info['platform'] == ReleaseAssets.platformName(os),
      target: dirFor(cacheRoot, releaseTag),
      label: 'Jolt Physics',
      error: JoltPrebuiltException.new,
      onProgress: onProgress,
      httpClient: httpClient,
    );
    if (!_complete(dir, os)) {
      dir.deleteSync(recursive: true);
      throw JoltPrebuiltException('The Jolt Physics archive of $releaseTag has no lib/$lib, headers or defines.');
    }
    return dir;
  }
}
