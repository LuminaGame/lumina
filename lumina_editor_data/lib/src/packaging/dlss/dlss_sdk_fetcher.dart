/// Downloads the NVIDIA DLSS SDK files of `tool/dlss/manifest.txt`, the way
/// `tool/dlss/fetch_sdk.dart` does, with byte progress for the editor.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lumina_editor_data/src/packaging/dlss/dlss_sdk.dart';
import 'package:path/path.dart' as p;

/// Where a [DlssSdkFetcher] run is.
class DlssSdkFetchProgress {
  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;

  /// The manifest path being downloaded or verified.
  final String? currentFile;

  const DlssSdkFetchProgress({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentFile,
  });

  double get fraction => bytesTotal == 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);
}

/// The outcome of a [DlssSdkFetcher.fetch].
class DlssSdkFetchResult {
  final int downloaded;
  final int alreadyPresent;

  const DlssSdkFetchResult(this.downloaded, this.alreadyPresent);
}

/// Fetches every file of an SDK's manifest from the pinned tag into its
/// `build/dlss-sdk/`. A file already there with the right size and SHA-256 is
/// kept; a download is written to `<file>.part`, verified, then renamed, so a
/// mismatch or an error leaves no partial file.
class DlssSdkFetcher {
  /// `<baseUrl>/<tag>/<path>`: github.com/NVIDIA/DLSS's raw files.
  final String baseUrl;

  DlssSdkFetcher({this.baseUrl = defaultBaseUrl});

  static const String defaultBaseUrl = 'https://raw.githubusercontent.com/NVIDIA/DLSS';

  Uri urlFor(DlssSdk sdk, DlssManifestEntry e) => Uri.parse('$baseUrl/${sdk.version}/${e.path}');

  Future<DlssSdkFetchResult> fetch(
    DlssSdk sdk, {
    void Function(DlssSdkFetchProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = sdk.manifest.fold<int>(0, (sum, e) => sum + e.size);
    var done = 0;
    var files = 0;
    var downloaded = 0;
    var present = 0;
    void report(String? current) => onProgress?.call(DlssSdkFetchProgress(
          filesDone: files,
          filesTotal: sdk.manifest.length,
          bytesDone: done,
          bytesTotal: total,
          currentFile: current,
        ));
    final client = HttpClient();
    try {
      for (final e in sdk.manifest) {
        if (isCancelled?.call() ?? false) throw StateError('DLSS SDK fetch cancelled');
        final target = File(p.join(sdk.sdkDir, e.path));
        report(e.path);
        if (await target.exists() && await target.length() == e.size && await _verify(target, e) == null) {
          present++;
          files++;
          done += e.size;
          report(e.path);
          continue;
        }
        await target.parent.create(recursive: true);
        final part = File('${target.path}.part');
        try {
          final request = await client.getUrl(urlFor(sdk, e));
          final response = await request.close();
          if (response.statusCode != 200) {
            await response.drain<void>();
            throw HttpException('HTTP ${response.statusCode} for ${urlFor(sdk, e)}');
          }
          final sink = part.openWrite();
          final base = done;
          var received = 0;
          try {
            await for (final chunk in response) {
              if (isCancelled?.call() ?? false) throw StateError('DLSS SDK fetch cancelled');
              sink.add(chunk);
              received += chunk.length;
              done = base + (received > e.size ? e.size : received);
              report(e.path);
            }
          } finally {
            await sink.close();
          }
          final problem = await _verify(part, e);
          if (problem != null) throw StateError('$problem (checksum or size mismatch against tool/dlss/manifest.txt)');
          if (await target.exists()) await target.delete();
          await part.rename(target.path);
          done = base + e.size;
        } catch (_) {
          if (await part.exists()) await part.delete();
          rethrow;
        }
        downloaded++;
        files++;
        report(e.path);
      }
    } finally {
      client.close(force: true);
    }
    report(null);
    return DlssSdkFetchResult(downloaded, present);
  }

  static Future<String?> _verify(File file, DlssManifestEntry e) {
    final path = file.path;
    return Isolate.run(() => DlssSdk.verifyFileSync(File(path), e));
  }
}
