import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'release_asset.dart';

/// A prebuilt Filament archive could not be fetched, verified or unpacked.
class FilamentPrebuiltException implements Exception {
  final String message;
  const FilamentPrebuiltException(this.message);

  @override
  String toString() => 'FilamentPrebuiltException: $message';
}

/// The prebuilt Filament builds attached to each Lumina GitHub release
/// (`tool/filament/build_prebuilt.{sh,ps1}` makes them): upstream Filament
/// plus `third_party/filament/patches`, pruned to the headers, sources and
/// static libraries the native-assets hooks read.
///
/// Release assets, per [version] (`tool/filament/VERSION`, e.g.
/// `1.77.0-lumina.1`) and OS:
/// `<baseUrl>/<releaseTag>/filament-<version>-<os>-x64.<zip|tar.gz>` plus a
/// `.sha256` sidecar (`sha256sum` format). The archive holds one folder,
/// `filament-<version>-<os>-x64`, with a `lumina-filament.json` describing it.
///
/// [ensure] downloads, verifies and unpacks it to `<cacheRoot>/<version>`,
/// a folder that works as the hooks' `filament_dir`; an unpacked one is
/// reused without the network. The download itself is [ReleaseAssets.fetch].
abstract final class FilamentPrebuilt {
  /// Where release assets are downloaded from: `<this>/<tag>/<asset>`.
  static const String defaultBaseUrl = ReleaseAssets.defaultBaseUrl;

  /// The provenance file at the top of every archive.
  static const String infoFileName = 'lumina-filament.json';

  /// Redirects the Filament download only; [ReleaseAssets.baseUrlVariable]
  /// redirects every release asset.
  static const String baseUrlVariable = 'LUMINA_FILAMENT_BASE_URL';

  /// The OS name used in asset names for [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  static String osName([String? operatingSystem]) =>
      ReleaseAssets.osName(operatingSystem, (_) => FilamentPrebuiltException('No prebuilt Filament for ${operatingSystem ?? Platform.operatingSystem}.'));

  /// `filament-<version>-<os>-x64`: the archive's folder, and its file name
  /// without the extension.
  static String baseName(String version, [String? operatingSystem]) => 'filament-$version-${osName(operatingSystem)}-x64';

  /// The archive's file name: `.zip` on Windows, `.tar.gz` elsewhere.
  static String archiveName(String version, [String? operatingSystem]) {
    final os = osName(operatingSystem);
    return '${baseName(version, os)}.${ReleaseAssets.archiveExtension(os)}';
  }

  /// The archive's download URL.
  static Uri archiveUri(String version, String releaseTag, {String? operatingSystem, String baseUrl = defaultBaseUrl}) =>
      ReleaseAssets.assetUri(baseUrl, releaseTag, archiveName(version, operatingSystem));

  /// `<cacheRoot>/<version>` when it holds a complete unpacked [version]
  /// (its `lumina-filament.json` names it), else null.
  static Directory? installed(Directory cacheRoot, String version) {
    final dir = Directory(p.join(cacheRoot.path, version));
    final info = readInfo(dir);
    return info != null && info['version'] == version ? dir : null;
  }

  /// The `lumina-filament.json` of an unpacked prebuilt, or null.
  static Map<String, Object?>? readInfo(Directory dir) => ReleaseAssets.readInfo(dir, infoFileName);

  /// Makes `<cacheRoot>/<version>` the unpacked prebuilt Filament [version]
  /// for this OS, downloading it from the [releaseTag] release when it is
  /// not there yet, and returns it. The archive is checked against its
  /// `.sha256` sidecar before anything is unpacked; a failed or interrupted
  /// run leaves no partial folder behind. [onProgress] gets a 0..1 fraction
  /// (download, then unpack) and a message.
  ///
  /// [baseUrl] replaces [defaultBaseUrl] (so do [baseUrlVariable] and
  /// [ReleaseAssets.baseUrlVariable], for mirrors); [force] downloads again
  /// even when it is installed.
  static Future<Directory> ensure({
    required String version,
    required String releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
    String? operatingSystem,
    String? baseUrl,
    bool force = false,
    HttpClient? httpClient,
  }) async {
    if (!force) {
      final found = installed(cacheRoot, version);
      if (found != null) {
        onProgress?.call(1, 'Filament $version is already installed');
        return found;
      }
    }
    final os = osName(operatingSystem);
    final base = baseUrl ?? ReleaseAssets.baseUrlFromEnvironment(const [baseUrlVariable, ReleaseAssets.baseUrlVariable]) ?? defaultBaseUrl;
    return ReleaseAssets.fetch(
      uri: archiveUri(version, releaseTag, operatingSystem: os, baseUrl: base),
      folder: baseName(version, os),
      infoFileName: infoFileName,
      accept: (info) => info['version'] == version,
      target: Directory(p.join(cacheRoot.path, version)),
      label: 'Filament $version',
      error: FilamentPrebuiltException.new,
      onProgress: onProgress,
      httpClient: httpClient,
    );
  }
}
