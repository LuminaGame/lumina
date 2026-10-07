import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina/data/services/filament_prebuilt.dart';
import 'package:lumina/data/services/release_asset.dart';

/// A prebuilt OpenRigLogic archive could not be fetched, verified or
/// unpacked.
class OpenRigLogicPrebuiltException implements Exception {
  final String message;
  const OpenRigLogicPrebuiltException(this.message);

  @override
  String toString() => 'OpenRigLogicPrebuiltException: $message';
}

/// The prebuilt OpenRigLogic static library attached to each Lumina GitHub
/// release (`.github/scripts/package_openriglogic.sh` packs it): the
/// library flutter_riglogic's native-assets hook links, built by the release
/// from the tools commit that release pins. A release checkout resolves
/// flutter_riglogic from git (the pub cache), where the library is not
/// built; the root pubspec's `riglogic_lib_dir` user-define names the
/// checkout's `openriglogic/lib`, which the bootstrap links here.
///
/// Release assets, per platform: `<baseUrl>/<releaseTag>/openriglogic-<os>-<arch>.<zip|tar.gz>`
/// plus a `.sha256` sidecar (`<arch>` is `x64`, or `arm64` for Linux arm64;
/// [ReleaseAssets.platformName]). The archive holds one folder,
/// `openriglogic-<os>-<arch>`, with `lib/<riglogic.lib|libriglogic.a>`, the
/// OpenRigLogic `LICENSE` and a `lumina-openriglogic.json` describing it.
///
/// The library belongs to its release (the tools pin), so [ensure] unpacks it
/// to `<cacheRoot>/<releaseTag>`; an unpacked one is reused without the
/// network.
abstract final class OpenRigLogicPrebuilt {
  /// The provenance file at the top of every archive.
  static const String infoFileName = 'lumina-openriglogic.json';

  /// The OS name used in asset names for [operatingSystem].
  static String osName([String? operatingSystem]) => ReleaseAssets.osName(
      operatingSystem, (_) => OpenRigLogicPrebuiltException('No prebuilt OpenRigLogic for ${operatingSystem ?? Platform.operatingSystem}.'));

  /// `openriglogic-<os>-<arch>`: the archive's folder, and its file name
  /// without the extension (the host's architecture on Linux).
  static String baseName([String? operatingSystem]) => 'openriglogic-${ReleaseAssets.platformName(osName(operatingSystem))}';

  /// The archive's file name: `.zip` on Windows, `.tar.gz` elsewhere.
  static String archiveName([String? operatingSystem]) {
    final os = osName(operatingSystem);
    return '${baseName(os)}.${ReleaseAssets.archiveExtension(os)}';
  }

  /// The static library's file name, as the hook links it.
  static String libraryName([String? operatingSystem]) => osName(operatingSystem) == 'windows' ? 'riglogic.lib' : 'libriglogic.a';

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
    return File(p.join(dir.path, 'lib', libraryName(os))).existsSync() ? dir : null;
  }

  /// Makes `<cacheRoot>/<releaseTag>` the unpacked OpenRigLogic of the
  /// [releaseTag] release for this OS, downloading it when it is not there
  /// yet, and returns it; its `lib` folder is what `riglogic_lib_dir` names.
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
        onProgress?.call(1, 'OpenRigLogic for $releaseTag is already installed');
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
      label: 'OpenRigLogic',
      error: OpenRigLogicPrebuiltException.new,
      onProgress: onProgress,
      httpClient: httpClient,
    );
    if (!File(p.join(dir.path, 'lib', lib)).existsSync()) {
      dir.deleteSync(recursive: true);
      throw OpenRigLogicPrebuiltException('The OpenRigLogic archive of $releaseTag has no lib/$lib.');
    }
    return dir;
  }
}
