import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_core/src/services/lumina_data_dir.dart';
import 'package:lumina_core/src/services/release_asset.dart';

/// flutter_filament's WebAssembly module could not be found, fetched,
/// verified or unpacked.
class FlutterFilamentWebPrebuiltException implements Exception {
  final String message;
  const FlutterFilamentWebPrebuiltException(this.message);

  @override
  String toString() => 'FlutterFilamentWebPrebuiltException: $message';
}

/// A downloaded flutter_filament web module: [directory] holds
/// `flutter_filament.js` and `flutter_filament.wasm`.
class FlutterFilamentWebInstall {
  const FlutterFilamentWebInstall({required this.directory, required this.tag, required this.requestedTag, this.sha256});

  final Directory directory;

  /// The release the archive came from, e.g. `v0.0.1-dev.16`.
  final String tag;

  /// The editor version that asked for it (its release tag; empty for a
  /// development build). A different editor version downloads again.
  final String requestedTag;

  /// The archive's verified SHA-256.
  final String? sha256;
}

/// The flutter_filament web module every Lumina release attaches
/// (`.github/workflows/release.yml`): `flutter-filament-web-<tag>.zip` plus a
/// `.sha256` sidecar, holding one folder `flutter-filament-web-<tag>` with
/// `flutter_filament.js`, `flutter_filament.wasm` and a `README.md`.
///
/// [ensure] downloads the archive of the editor's own release (else of the
/// newest release that carries one, found through the GitHub releases API),
/// checks it against its sidecar, unpacks it to `<root>/module` and writes
/// [markerFileName] there naming the release it came from and the editor
/// version that asked for it. The default root is
/// [LuminaDataDir.webModuleRoot].
abstract final class FlutterFilamentWebPrebuilt {
  /// The two files a web game serves next to its `index.html`.
  static const List<String> fileNames = ['flutter_filament.js', 'flutter_filament.wasm'];

  /// What [ensure] writes into the unpacked module.
  static const String markerFileName = 'lumina-web-module.json';

  /// The releases listing [ensure] falls back to.
  static const String defaultApiUrl = 'https://api.github.com/repos/LuminaGame/lumina/releases';

  /// Redirects the releases listing (a mirror answering like [defaultApiUrl]).
  static const String apiUrlVariable = 'LUMINA_RELEASE_API_URL';

  /// `flutter-filament-web-<tag>`: the archive's folder.
  static String baseName(String tag) => 'flutter-filament-web-$tag';

  /// The archive's file name.
  static String archiveName(String tag) => '${baseName(tag)}.zip';

  /// `<root>/module`, where the unpacked module lives.
  static Directory moduleDir(Directory root) => Directory(p.join(root.path, 'module'));

  /// The default root: `<data>/flutter_filament_web`.
  static Directory defaultRoot() => LuminaDataDir.webModuleRoot();

  /// The module unpacked under [root] (default [defaultRoot]), or null when
  /// it is not there or incomplete.
  static FlutterFilamentWebInstall? installed([Directory? root]) {
    final dir = moduleDir(root ?? defaultRoot());
    final info = ReleaseAssets.readInfo(dir, markerFileName);
    if (info == null) return null;
    final tag = info['tag'];
    if (tag is! String || !fileNames.every((f) => File(p.join(dir.path, f)).existsSync())) return null;
    return FlutterFilamentWebInstall(
      directory: dir,
      tag: tag,
      requestedTag: info['requestedTag'] is String ? info['requestedTag'] as String : '',
      sha256: info['sha256'] is String ? info['sha256'] as String : null,
    );
  }

  /// Makes `<root>/module` the web module for the editor version
  /// [requestedTag] (its release tag; empty in a development build) and
  /// returns it. An install made for the same [requestedTag] is reused
  /// without the network; one made for another editor version is replaced.
  ///
  /// The archive comes from the [requestedTag] release; when that has none
  /// (HTTP 404) or [requestedTag] is empty, from the newest non-draft
  /// release in the [apiUrl] listing that carries the archive and its
  /// sidecar. A failed or interrupted run leaves the previous install (or
  /// nothing) in place. [onProgress] gets a 0..1 fraction and a message.
  /// [baseUrl] / [apiUrl] replace the GitHub defaults (so do
  /// [ReleaseAssets.baseUrlVariable] and [apiUrlVariable] in
  /// [environment]); [force] downloads even when installed.
  static Future<FlutterFilamentWebInstall> ensure({
    required String requestedTag,
    Directory? root,
    void Function(double progress, String message)? onProgress,
    String? baseUrl,
    String? apiUrl,
    bool force = false,
    HttpClient? httpClient,
    Map<String, String>? environment,
  }) async {
    final into = root ?? defaultRoot();
    if (!force) {
      final found = installed(into);
      if (found != null && found.requestedTag == requestedTag) {
        onProgress?.call(1, 'flutter_filament web module ${found.tag} is already installed');
        return found;
      }
    }
    final base = baseUrl ?? ReleaseAssets.baseUrlFromEnvironment(const [ReleaseAssets.baseUrlVariable], environment) ?? ReleaseAssets.defaultBaseUrl;
    final api = apiUrl ?? ReleaseAssets.baseUrlFromEnvironment(const [apiUrlVariable], environment) ?? defaultApiUrl;
    final client = httpClient ?? (HttpClient()..connectionTimeout = const Duration(seconds: 30));
    try {
      if (requestedTag.isNotEmpty) {
        try {
          return await _fetch(requestedTag, requestedTag, into, base, client, onProgress);
        } on _NotFound {
          onProgress?.call(0, 'The $requestedTag release has no web module; looking for the newest release that has one');
        }
      } else {
        onProgress?.call(0, 'Looking for the newest release with a web module');
      }
      final tag = await newestTagWithModule(api, httpClient: client, skip: {requestedTag});
      if (tag == null) {
        throw FlutterFilamentWebPrebuiltException('No release at $api carries ${archiveName('<tag>')}.');
      }
      return await _fetch(tag, requestedTag, into, base, client, onProgress);
    } on _NotFound catch (e) {
      throw FlutterFilamentWebPrebuiltException(e.message);
    } finally {
      if (httpClient == null) client.close(force: true);
    }
  }

  /// The newest non-draft release in the [apiUrl] listing (GitHub's
  /// `GET /repos/{owner}/{repo}/releases` shape) whose assets hold the web
  /// module archive and its `.sha256`, or null. Tags in [skip] are ignored.
  static Future<String?> newestTagWithModule(String apiUrl, {HttpClient? httpClient, Set<String> skip = const {}}) async {
    final client = httpClient ?? (HttpClient()..connectionTimeout = const Duration(seconds: 30));
    final uri = Uri.parse(apiUrl).replace(queryParameters: {'per_page': '50'});
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'lumina-release-assets')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode != HttpStatus.ok) {
        throw FlutterFilamentWebPrebuiltException('GET $uri: HTTP ${response.statusCode}.');
      }
      final releases = jsonDecode(body);
      if (releases is! List) throw FlutterFilamentWebPrebuiltException('GET $uri: not a release list.');
      final candidates = <(String, String)>[];
      for (final r in releases.whereType<Map>()) {
        final tag = r['tag_name'];
        if (tag is! String || r['draft'] == true || skip.contains(tag)) continue;
        final names = {for (final a in (r['assets'] as List? ?? const []).whereType<Map>()) a['name']};
        if (names.contains(archiveName(tag)) && names.contains('${archiveName(tag)}.sha256')) {
          candidates.add((tag, '${r['published_at'] ?? r['created_at'] ?? ''}'));
        }
      }
      if (candidates.isEmpty) return null;
      // Newest first; a stable sort keeps the listing's order on ties.
      final sorted = [...candidates]..sort((a, b) => b.$2.compareTo(a.$2));
      return sorted.first.$1;
    } on IOException catch (e) {
      throw FlutterFilamentWebPrebuiltException('Could not list releases at $uri: $e');
    } on FormatException catch (e) {
      throw FlutterFilamentWebPrebuiltException('GET $uri: $e');
    } finally {
      if (httpClient == null) client.close(force: true);
    }
  }

  static Future<FlutterFilamentWebInstall> _fetch(String tag, String requestedTag, Directory root, String base, HttpClient client,
      void Function(double, String)? onProgress) async {
    String? digest;
    final dir = await ReleaseAssets.fetch(
      uri: ReleaseAssets.assetUri(base, tag, archiveName(tag)),
      folder: baseName(tag),
      verify: (unpacked) => fileNames.every((f) => File(p.join(unpacked.path, f)).existsSync()),
      onVerified: (sha) => digest = sha,
      target: moduleDir(root),
      label: 'flutter_filament web module $tag',
      error: FlutterFilamentWebPrebuiltException.new,
      notFound: _NotFound.new,
      onProgress: onProgress,
      httpClient: client,
    );
    await File(p.join(dir.path, markerFileName)).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'tag': tag,
      'requestedTag': requestedTag,
      'sha256': digest,
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
    }));
    return FlutterFilamentWebInstall(directory: dir, tag: tag, requestedTag: requestedTag, sha256: digest);
  }
}

/// An HTTP 404 of the archive or its sidecar: another release may have it.
class _NotFound extends FlutterFilamentWebPrebuiltException {
  const _NotFound(super.message);
}
