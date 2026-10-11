import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_core/src/services/release_asset.dart';

/// A prebuilt Filament archive could not be fetched, verified or unpacked.
class FilamentPrebuiltException implements Exception {
  final String message;
  const FilamentPrebuiltException(this.message);

  @override
  String toString() => 'FilamentPrebuiltException: $message';
}

/// The prebuilt Filament builds (`tool/filament/build_prebuilt.{sh,ps1}`
/// makes them): upstream Filament plus `third_party/filament/patches`, pruned
/// to the headers, sources and static libraries the native-assets hooks read.
///
/// Each [version] (`tool/filament/VERSION`, e.g. `1.77.0-lumina.2`) is
/// published once, in its own GitHub release [releaseTagFor] =
/// `filament-<version>` (a pre-release that never becomes "Latest"). Assets,
/// per platform: `<baseUrl>/<tag>/filament-<version>-<os>-<arch>.<zip|tar.gz>`
/// plus a `.sha256` sidecar (`sha256sum` format); `<arch>` is `x64`, or
/// `arm64` for the Linux arm64 build ([ReleaseAssets.platformName]). The
/// archive holds one folder, `filament-<version>-<os>-<arch>`, with a
/// `lumina-filament.json` describing it.
/// Lumina releases up to v0.0.1-dev.6 attached the same assets to their own
/// release instead; [ensure] falls back to such a tag.
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

  /// The GitHub release that holds the prebuilt [version]:
  /// `filament-<version>`.
  static String releaseTagFor(String version) => 'filament-$version';

  /// The OS name used in asset names for [operatingSystem] (a
  /// `Platform.operatingSystem` value).
  static String osName([String? operatingSystem]) =>
      ReleaseAssets.osName(operatingSystem, (_) => FilamentPrebuiltException('No prebuilt Filament for ${operatingSystem ?? Platform.operatingSystem}.'));

  /// `filament-<version>-<os>-<arch>`: the archive's folder, and its file
  /// name without the extension. [architecture] (`x64` or `arm64`) defaults
  /// to the host's and only matters on Linux.
  static String baseName(String version, [String? operatingSystem, String? architecture]) =>
      'filament-$version-${ReleaseAssets.platformName(osName(operatingSystem), architecture)}';

  /// The archive's file name: `.zip` on Windows, `.tar.gz` elsewhere.
  static String archiveName(String version, [String? operatingSystem, String? architecture]) {
    final os = osName(operatingSystem);
    return '${baseName(version, os, architecture)}.${ReleaseAssets.archiveExtension(os)}';
  }

  /// The archive's download URL.
  static Uri archiveUri(String version, String releaseTag,
          {String? operatingSystem, String? architecture, String baseUrl = defaultBaseUrl}) =>
      ReleaseAssets.assetUri(baseUrl, releaseTag, archiveName(version, operatingSystem, architecture));

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
  /// for this OS, downloading it when it is not there yet, and returns it.
  /// The download comes from the [releaseTagFor] release; when that has no
  /// such asset (HTTP 404) and [releaseTag] is given, from the [releaseTag]
  /// release (a Lumina release that attached Filament itself). The archive
  /// is checked against its `.sha256` sidecar before anything is unpacked; a
  /// failed or interrupted run leaves no partial folder behind. [onProgress]
  /// gets a 0..1 fraction (download, then unpack) and a message.
  ///
  /// [baseUrl] replaces [defaultBaseUrl] (so do [baseUrlVariable] and
  /// [ReleaseAssets.baseUrlVariable] in [environment], default the process
  /// environment, for mirrors); [force] downloads again even when it is
  /// installed.
  static Future<Directory> ensure({
    required String version,
    String? releaseTag,
    required Directory cacheRoot,
    void Function(double progress, String message)? onProgress,
    String? operatingSystem,
    String? baseUrl,
    bool force = false,
    HttpClient? httpClient,
    Map<String, String>? environment,
  }) async {
    if (!force) {
      final found = installed(cacheRoot, version);
      if (found != null) {
        onProgress?.call(1, 'Filament $version is already installed');
        return found;
      }
    }
    final os = osName(operatingSystem);
    final base = baseUrl ??
        ReleaseAssets.baseUrlFromEnvironment(const [baseUrlVariable, ReleaseAssets.baseUrlVariable], environment) ??
        defaultBaseUrl;
    final tags = [releaseTagFor(version), if (releaseTag != null && releaseTag.isNotEmpty && releaseTag != releaseTagFor(version)) releaseTag];
    final notFound = <String>[];
    for (final tag in tags) {
      if (notFound.isNotEmpty) {
        onProgress?.call(0, 'Filament $version is not in the ${tags.first} release; trying the $tag release');
      }
      try {
        return await ReleaseAssets.fetch(
          uri: archiveUri(version, tag, operatingSystem: os, baseUrl: base),
          folder: baseName(version, os),
          infoFileName: infoFileName,
          accept: (info) => info['version'] == version,
          target: Directory(p.join(cacheRoot.path, version)),
          label: 'Filament $version',
          error: FilamentPrebuiltException.new,
          notFound: _NotFound.new,
          onProgress: onProgress,
          httpClient: httpClient,
        );
      } on _NotFound catch (e) {
        notFound.add(e.message);
      }
    }
    throw FilamentPrebuiltException(
        notFound.length == 1 ? notFound.single : 'No release has Filament $version: ${notFound.join(' ')}');
  }
}

/// The Android half of a prebuilt Filament: the static libraries per ABI
/// (`arm64-v8a`, `x86_64`) and the headers of Android's install tree, built
/// from the same upstream tag and patches as the desktop archives
/// (`build_prebuilt.ps1 -Android`).
///
/// The asset `filament-<version>-android.tar.gz` (+ `.sha256`) sits in the
/// same `filament-<version>` release. Its one folder,
/// `filament-<version>-android`, is the `out/android-release` folder of a
/// Filament checkout, with its own `lumina-filament.json`; [ensure] unpacks it
/// there inside an unpacked desktop prebuilt, so one `filament_dir` serves the
/// desktop and the Android builds of a game.
abstract final class FilamentPrebuiltAndroid {
  /// `filament-<version>-android`: the archive's folder.
  static String baseName(String version) => 'filament-$version-android';

  /// `filament-<version>-android.tar.gz`.
  static String archiveName(String version) => '${baseName(version)}.tar.gz';

  /// Where the Android tree lives inside a prebuilt (or a checkout).
  static final String relativePath = p.join('out', 'android-release');

  /// `<prebuilt>/out/android-release` when it holds the Android build of
  /// [version], else null.
  static Directory? installed(Directory prebuilt, String version) {
    final dir = Directory(p.join(prebuilt.path, relativePath));
    final info = FilamentPrebuilt.readInfo(dir);
    return info != null && info['version'] == version ? dir : null;
  }

  /// Makes `<prebuilt>/out/android-release` the Android build of [version]
  /// (downloaded from the `filament-<version>` release and checked against its
  /// sidecar, like [FilamentPrebuilt.ensure]) and returns it. [prebuilt] is an
  /// unpacked desktop prebuilt of the same version.
  static Future<Directory> ensure({
    required String version,
    required Directory prebuilt,
    void Function(double progress, String message)? onProgress,
    String? baseUrl,
    bool force = false,
    HttpClient? httpClient,
    Map<String, String>? environment,
  }) async {
    if (!force) {
      final found = installed(prebuilt, version);
      if (found != null) {
        onProgress?.call(1, 'Filament $version for Android is already installed');
        return found;
      }
    }
    final base = baseUrl ??
        ReleaseAssets.baseUrlFromEnvironment(
            const [FilamentPrebuilt.baseUrlVariable, ReleaseAssets.baseUrlVariable], environment) ??
        FilamentPrebuilt.defaultBaseUrl;
    return ReleaseAssets.fetch(
      uri: ReleaseAssets.assetUri(base, FilamentPrebuilt.releaseTagFor(version), archiveName(version)),
      folder: baseName(version),
      infoFileName: FilamentPrebuilt.infoFileName,
      accept: (info) => info['version'] == version && info['platform'] == 'android',
      target: Directory(p.join(prebuilt.path, relativePath)),
      label: 'Filament $version for Android',
      error: FilamentPrebuiltException.new,
      onProgress: onProgress,
      httpClient: httpClient,
    );
  }
}

/// An HTTP 404 of an asset: the next release tag may have it.
class _NotFound extends FilamentPrebuiltException {
  const _NotFound(super.message);
}
