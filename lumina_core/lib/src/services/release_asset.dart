import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// The prebuilt archives attached to Lumina GitHub releases (Filament in its
/// own `filament-<VERSION>` release, OpenRigLogic in each Lumina release):
/// downloaded, checked against their `.sha256` sidecar and
/// unpacked into a per-user cache. [FilamentPrebuilt] and
/// [OpenRigLogicPrebuilt] name the assets; this holds what they share.
abstract final class ReleaseAssets {
  /// Where release assets are downloaded from: `<this>/<tag>/<asset>`.
  static const String defaultBaseUrl = 'https://github.com/LuminaGame/lumina/releases/download';

  /// Redirects every release-asset download (a mirror laid out like
  /// [defaultBaseUrl]).
  static const String baseUrlVariable = 'LUMINA_RELEASE_BASE_URL';

  /// The OS name used in asset names for [operatingSystem] (a
  /// `Platform.operatingSystem` value); [onUnsupported] builds the error.
  static String osName(String? operatingSystem, Exception Function(String message) onUnsupported) {
    final os = operatingSystem ?? Platform.operatingSystem;
    return switch (os) {
      'windows' || 'linux' || 'macos' => os,
      _ => throw onUnsupported('No prebuilt build for $os.'),
    };
  }

  /// The archive extension release assets use on [os]: `zip` on Windows,
  /// `tar.gz` elsewhere.
  static String archiveExtension(String os) => os == 'windows' ? 'zip' : 'tar.gz';

  /// The CPU architecture this process runs on, as asset names spell it:
  /// `x64` or `arm64` (from the Dart VM's `Platform.version`).
  static String hostArchitecture() {
    final v = Platform.version.toLowerCase();
    return v.contains('arm64') || v.contains('aarch64') ? 'arm64' : 'x64';
  }

  /// The `<os>-<arch>` suffix of an asset for [os]: Linux builds exist for
  /// x64 and arm64 ([architecture], default the host's); Windows and macOS
  /// assets are x64 only.
  static String platformName(String os, [String? architecture]) {
    final arch = os == 'linux' ? (architecture ?? hostArchitecture()) : 'x64';
    return '$os-$arch';
  }

  /// `<baseUrl>/<releaseTag>/<asset>`.
  static Uri assetUri(String baseUrl, String releaseTag, String asset) =>
      Uri.parse('${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}'
          '/${Uri.encodeComponent(releaseTag)}/$asset');

  /// The first of [variables] set to a non-empty value in [environment]
  /// (default: the process environment), or null.
  static String? baseUrlFromEnvironment(List<String> variables, [Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    for (final name in variables) {
      final v = env[name];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// The JSON object in `<dir>/<infoFileName>`, or null.
  static Map<String, Object?>? readInfo(Directory dir, String infoFileName) {
    final file = File(p.join(dir.path, infoFileName));
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// Downloads [uri] and its `.sha256` sidecar, checks the checksum, unpacks
  /// the archive and moves its single top folder [folder] to [target] once
  /// [accept] approves the `<folder>/<infoFileName>` it holds (an archive
  /// without a provenance file passes a null [infoFileName] and a [verify]
  /// check of the unpacked folder instead). [onVerified] gets the archive's
  /// SHA-256 once it matched the sidecar. Staging
  /// happens next to [target], so a failed or interrupted run leaves no
  /// partial [target] behind. [onProgress] gets 0..0.9 while downloading,
  /// then 0.9 and 1; [label] names the download in its messages; [error]
  /// builds the exception thrown, and [notFound], when given, the one for
  /// an HTTP 404 of the archive or its sidecar.
  static Future<Directory> fetch({
    required Uri uri,
    required String folder,
    String? infoFileName,
    bool Function(Map<String, Object?> info)? accept,
    bool Function(Directory unpacked)? verify,
    void Function(String sha256)? onVerified,
    required Directory target,
    required String label,
    required Exception Function(String message) error,
    Exception Function(String message)? notFound,
    void Function(double progress, String message)? onProgress,
    HttpClient? httpClient,
  }) async {
    assert(infoFileName != null ? accept != null : verify != null, 'an info file needs accept, none needs verify');
    final missing = notFound ?? error;
    final shaUri = uri.replace(path: '${uri.path}.sha256');
    final client = httpClient ?? (HttpClient()..connectionTimeout = const Duration(seconds: 30));
    await target.parent.create(recursive: true);
    final staging = Directory(p.join(target.parent.path, '.staging-${p.basename(target.path)}-$pid'));
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    try {
      onProgress?.call(0, 'Downloading ${p.basename(shaUri.path)}');
      final expected = _parseSha256(await _getText(client, shaUri, error, missing), error);
      final archive = File(p.join(staging.path, p.basename(uri.path)));
      var shownTenths = -1;
      final actual = await _downloadTo(client, uri, archive, error, missing, (received, total) {
        // One event per 0.1 MiB, not per network chunk.
        final tenths = received * 10 ~/ (1 << 20);
        if (tenths == shownTenths && received != total) return;
        shownTenths = tenths;
        final mib = (received / (1 << 20)).toStringAsFixed(1);
        final of = total == null ? '' : ' of ${(total / (1 << 20)).toStringAsFixed(1)}';
        onProgress?.call(total == null || total == 0 ? 0 : 0.9 * received / total, 'Downloading $label: $mib$of MiB');
      });
      if (actual.toString() != expected) {
        throw error('Checksum mismatch for $uri: expected $expected, got $actual.');
      }
      onVerified?.call(expected);
      onProgress?.call(0.9, 'Unpacking $label');
      final unpacked = Directory(p.join(staging.path, 'unpacked'))..createSync();
      await _extract(archive, unpacked, error);
      final inner = Directory(p.join(unpacked.path, folder));
      if (infoFileName != null) {
        final info = readInfo(inner, infoFileName);
        if (info == null || !accept!(info)) {
          throw error('${archive.path} does not hold $folder/$infoFileName for $label.');
        }
      } else if (!inner.existsSync() || !verify!(inner)) {
        throw error('${archive.path} does not hold the $folder folder $label needs.');
      }
      if (target.existsSync()) target.deleteSync(recursive: true);
      inner.renameSync(target.path);
      onProgress?.call(1, '$label ready');
      return target;
    } on IOException catch (e) {
      throw error('Could not fetch $uri: $e');
    } finally {
      if (httpClient == null) client.close(force: true);
      if (staging.existsSync()) {
        try {
          staging.deleteSync(recursive: true);
        } on FileSystemException {
          // A virus scanner holding the archive: the next run clears it.
        }
      }
    }
  }

  /// The first token of a `sha256sum` line.
  static String _parseSha256(String text, Exception Function(String) error) {
    final token = text.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw error('Not a SHA-256 checksum: "${text.trim()}".');
    }
    return token;
  }

  /// GETs [uri], following redirects (GitHub serves release assets from
  /// another host).
  static Future<HttpClientResponse> _get(
      HttpClient client, Uri uri, Exception Function(String) error, Exception Function(String) notFound) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'lumina-release-assets');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      final message = 'GET $uri: HTTP ${response.statusCode}.';
      throw response.statusCode == HttpStatus.notFound ? notFound(message) : error(message);
    }
    return response;
  }

  static Future<String> _getText(
          HttpClient client, Uri uri, Exception Function(String) error, Exception Function(String) notFound) async =>
      utf8.decode(await (await _get(client, uri, error, notFound)).fold<List<int>>(<int>[], (a, b) => a..addAll(b)));

  /// Streams [uri] into [to] and returns the body's SHA-256.
  static Future<Digest> _downloadTo(HttpClient client, Uri uri, File to, Exception Function(String) error,
      Exception Function(String) notFound, void Function(int received, int? total)? progress) async {
    final response = await _get(client, uri, error, notFound);
    final total = response.contentLength >= 0 ? response.contentLength : null;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final sink = to.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        hasher.add(chunk);
        sink.add(chunk);
        received += chunk.length;
        progress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    if (total != null && received != total) {
      throw error('GET $uri: got $received of $total bytes.');
    }
    return digestSink.value!;
  }

  /// Unpacks [archive] into [into] with the system `tar` (bsdtar on
  /// Windows 10+ and macOS reads zip too; GNU tar on Linux reads .tar.gz,
  /// and a zip there goes through `unzip` or `python3 -m zipfile`).
  static Future<void> _extract(File archive, Directory into, Exception Function(String) error) async {
    // On Windows, System32's bsdtar: a Git-for-Windows GNU tar on PATH can
    // read neither zip nor `C:` paths.
    final tar = Platform.isWindows ? p.join(Platform.environment['SystemRoot'] ?? r'C:\Windows', 'System32', 'tar.exe') : 'tar';
    if (Platform.isLinux && archive.path.toLowerCase().endsWith('.zip')) {
      // GNU tar reads no zip: unzip, else Python's zipfile module.
      for (final (exe, args) in [
        ('unzip', ['-q', '-o', archive.path, '-d', into.path]),
        ('python3', ['-m', 'zipfile', '-e', archive.path, into.path]),
      ]) {
        final ProcessResult result;
        try {
          result = await Process.run(exe, args);
        } on ProcessException {
          continue;
        }
        if (result.exitCode != 0) {
          throw error('Could not unpack ${archive.path} ($exe exit ${result.exitCode}): ${result.stderr}'.trim());
        }
        return;
      }
      throw error('Could not unpack ${archive.path}: neither unzip nor python3 is installed.');
    }
    final result = await Process.run(tar, ['-xf', archive.path, '-C', into.path]);
    if (result.exitCode != 0) {
      throw error('Could not unpack ${archive.path} (tar exit ${result.exitCode}): ${result.stderr}'.trim());
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
