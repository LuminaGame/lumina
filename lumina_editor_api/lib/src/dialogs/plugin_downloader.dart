import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lumina/lumina.dart' show EngineLoggerService;
import 'package:path/path.dart' as p;

/// Definition of a single file to be downloaded and verified by [PluginDownloader].
class PluginFileDef {
  final String path;
  final int bytes;
  final String sha256;
  final String downloadUrl;

  const PluginFileDef({
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.downloadUrl,
  });
}

/// Progress information for an active file download batch.
class PluginDownloadProgress {
  final String fileName;
  final int fileIndex;
  final int totalFiles;
  final int fileBytesReceived;
  final int fileTotalBytes;
  final double fileProgress;
  final int overallBytesReceived;
  final int overallTotalBytes;
  final double overallProgress;
  final double bytesPerSecond;

  const PluginDownloadProgress({
    required this.fileName,
    required this.fileIndex,
    required this.totalFiles,
    required this.fileBytesReceived,
    required this.fileTotalBytes,
    required this.fileProgress,
    required this.overallBytesReceived,
    required this.overallTotalBytes,
    required this.overallProgress,
    this.bytesPerSecond = 0.0,
  });
}

/// Thrown when a download is aborted by user request.
class PluginDownloadCancellationException implements Exception {
  final String message;
  const PluginDownloadCancellationException([this.message = 'Download was cancelled by user']);

  @override
  String toString() => message;
}

/// A general, reusable downloader for plugins with HTTP Range resume,
/// SHA-256 validation, authorization token support, and free disk space checks.
class PluginDownloader {
  final HttpClient _client;
  final int Function(String path)? freeSpaceChecker;
  final String sourceName;
  bool _isCancelled = false;

  HttpClientRequest? _activeRequest;
  StreamSubscription<List<int>>? _activeResponseSub;
  StreamController<List<int>>? _activeChunkController;

  PluginDownloader({
    HttpClient? client,
    this.freeSpaceChecker,
    this.sourceName = 'PluginDownloader',
  }) : _client = client ?? HttpClient();

  bool get isCancelled => _isCancelled;

  void _log(
    String message, {
    String level = 'info',
    void Function(String message, {String level})? onLog,
  }) {
    EngineLoggerService().log(message, level: level, source: sourceName);
    onLog?.call(message, level: level);
  }

  /// Cancels any in-progress download.
  void cancel() {
    _isCancelled = true;
    try {
      _activeRequest?.abort();
    } catch (_) {}
    _activeResponseSub?.cancel();
    _activeResponseSub = null;
    if (_activeChunkController != null && !_activeChunkController!.isClosed) {
      _activeChunkController!.addError(const PluginDownloadCancellationException());
      _activeChunkController!.close();
    }
    _activeChunkController = null;
  }

  /// Closes the HTTP client and cleans up open connections.
  void dispose() {
    cancel();
    _client.close(force: true);
  }

  /// Downloads [files] into [targetDir], emitting [PluginDownloadProgress] updates.
  Stream<PluginDownloadProgress> download({
    required List<PluginFileDef> files,
    required String targetDir,
    String? authToken,
    String Function(PluginFileDef file)? urlOverride,
    void Function(String message, {String level})? onLog,
  }) async* {
    _isCancelled = false;
    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final overallTotalBytes = files.fold(0, (sum, f) => sum + f.bytes);
    final neededWithBuffer = (overallTotalBytes * 1.10).ceil();

    _log(
      'Starting download for ${files.length} files into $targetDir (total: ${(overallTotalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
      onLog: onLog,
    );

    if (freeSpaceChecker != null) {
      final available = freeSpaceChecker!(targetDir);
      if (available < neededWithBuffer) {
        final err =
            'Insufficient disk space in $targetDir: need ${(neededWithBuffer / (1024 * 1024)).toStringAsFixed(1)} MB, but only ${(available / (1024 * 1024)).toStringAsFixed(1)} MB available.';
        _log(err, level: 'error', onLog: onLog);
        throw StateError(err);
      }
    }

    var overallBytesReceived = 0;
    final totalFiles = files.length;

    // Account for already completed files
    for (final f in files) {
      final finalFile = File(p.join(targetDir, f.path));
      if (finalFile.existsSync() && finalFile.lengthSync() == f.bytes) {
        overallBytesReceived += f.bytes;
      }
    }

    for (var i = 0; i < files.length; i++) {
      if (_isCancelled) {
        _log('Download cancelled by user.', level: 'warning', onLog: onLog);
        throw const PluginDownloadCancellationException();
      }

      final fileDef = files[i];
      final finalPath = p.join(targetDir, fileDef.path);
      final finalFile = File(finalPath);

      final parentDir = finalFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      // If file already exists and valid, skip
      if (finalFile.existsSync() && finalFile.lengthSync() == fileDef.bytes) {
        _log(
          '[${i + 1}/$totalFiles] File already exists and verified, skipping: ${fileDef.path} (${fileDef.bytes} bytes)',
          onLog: onLog,
        );
        yield PluginDownloadProgress(
          fileName: fileDef.path,
          fileIndex: i + 1,
          totalFiles: totalFiles,
          fileBytesReceived: fileDef.bytes,
          fileTotalBytes: fileDef.bytes,
          fileProgress: 1.0,
          overallBytesReceived: overallBytesReceived,
          overallTotalBytes: overallTotalBytes,
          overallProgress: overallTotalBytes > 0 ? (overallBytesReceived / overallTotalBytes).clamp(0.0, 1.0) : 1.0,
        );
        continue;
      }

      final partPath = '$finalPath.part';
      final partFile = File(partPath);

      var downloadedBytes = partFile.existsSync() ? partFile.lengthSync() : 0;
      if (downloadedBytes > fileDef.bytes) {
        partFile.deleteSync();
        downloadedBytes = 0;
      }

      final url = urlOverride != null ? urlOverride(fileDef) : fileDef.downloadUrl;
      final uri = Uri.parse(url);

      if (downloadedBytes > 0) {
        _log(
          '[${i + 1}/$totalFiles] Resuming ${fileDef.path} from byte $downloadedBytes / ${fileDef.bytes}...',
          onLog: onLog,
        );
      } else {
        _log(
          '[${i + 1}/$totalFiles] Starting download: ${fileDef.path} (${(fileDef.bytes / (1024 * 1024)).toStringAsFixed(1)} MB) from $url',
          onLog: onLog,
        );
      }

      final req = await _client.getUrl(uri);
      _activeRequest = req;
      if (authToken != null && authToken.trim().isNotEmpty) {
        req.headers.set('Authorization', 'Bearer ${authToken.trim()}');
        _log('Authorization header set.', onLog: onLog);
      }
      if (downloadedBytes > 0) {
        req.headers.set('Range', 'bytes=$downloadedBytes-');
      }

      final resp = await req.close();
      _log(
        '[${i + 1}/$totalFiles] Server responded with HTTP ${resp.statusCode} (contentLength: ${resp.contentLength})',
        onLog: onLog,
      );

      final IOSink sink;
      if (resp.statusCode == HttpStatus.partialContent) {
        sink = partFile.openWrite(mode: FileMode.append);
      } else if (resp.statusCode == HttpStatus.ok) {
        downloadedBytes = 0;
        sink = partFile.openWrite(mode: FileMode.write);
      } else {
        final err = 'Download failed with HTTP ${resp.statusCode}: $url';
        _log(err, level: 'error', onLog: onLog);
        throw HttpException(err);
      }

      var lastReportTime = DateTime.now();
      var lastLogTime = DateTime.now();
      var bytesSinceLastReport = 0;
      var currentSpeed = 0.0;

      final chunkController = StreamController<List<int>>();
      _activeChunkController = chunkController;

      _activeResponseSub = resp.listen(
        (chunk) {
          if (_isCancelled) {
            _activeResponseSub?.cancel();
            if (!chunkController.isClosed) {
              chunkController.addError(const PluginDownloadCancellationException());
            }
          } else if (!chunkController.isClosed) {
            chunkController.add(chunk);
          }
        },
        onError: (e) {
          if (!chunkController.isClosed) {
            chunkController.addError(_isCancelled ? const PluginDownloadCancellationException() : e);
          }
        },
        onDone: () {
          if (!chunkController.isClosed) {
            chunkController.close();
          }
        },
        cancelOnError: true,
      );

      try {
        await for (final chunk in chunkController.stream) {
          if (_isCancelled) {
            throw const PluginDownloadCancellationException();
          }

          sink.add(chunk);
          downloadedBytes += chunk.length;
          overallBytesReceived += chunk.length;
          bytesSinceLastReport += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastReportTime).inMilliseconds;
          if (elapsed >= 100 || bytesSinceLastReport >= 100) {
            currentSpeed = elapsed > 0 ? (bytesSinceLastReport * 1000.0) / elapsed : 0.0;
            lastReportTime = now;
            bytesSinceLastReport = 0;

            final fileProg = fileDef.bytes > 0 ? (downloadedBytes / fileDef.bytes).clamp(0.0, 1.0) : 0.0;
            final overallProg = overallTotalBytes > 0 ? (overallBytesReceived / overallTotalBytes).clamp(0.0, 1.0) : 0.0;

            if (now.difference(lastLogTime).inSeconds >= 5) {
              lastLogTime = now;
              _log(
                '[${i + 1}/$totalFiles] ${fileDef.path}: ${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(fileDef.bytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(currentSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s, ${(overallProg * 100).toStringAsFixed(1)}% total)',
                onLog: onLog,
              );
            }

            yield PluginDownloadProgress(
              fileName: fileDef.path,
              fileIndex: i + 1,
              totalFiles: totalFiles,
              fileBytesReceived: downloadedBytes,
              fileTotalBytes: fileDef.bytes,
              fileProgress: fileProg,
              overallBytesReceived: overallBytesReceived,
              overallTotalBytes: overallTotalBytes,
              overallProgress: overallProg,
              bytesPerSecond: currentSpeed,
            );
          }
        }
      } on PluginDownloadCancellationException {
        _log('Download cancelled by user for ${fileDef.path}.', level: 'warning', onLog: onLog);
        rethrow;
      } catch (e) {
        if (_isCancelled) {
          _log('Download cancelled by user for ${fileDef.path}.', level: 'warning', onLog: onLog);
          throw const PluginDownloadCancellationException();
        }
        _log('Download stream error for ${fileDef.path}: $e', level: 'error', onLog: onLog);
        rethrow;
      } finally {
        await _activeResponseSub?.cancel();
        _activeResponseSub = null;
        if (!chunkController.isClosed) {
          await chunkController.close();
        }
        _activeChunkController = null;
        await sink.flush();
        await sink.close();
        _activeRequest = null;
      }

      if (_isCancelled) throw const PluginDownloadCancellationException();

      // Verify file size and SHA-256 before renaming .part to final
      _log('[${i + 1}/$totalFiles] Download complete for ${fileDef.path}. Verifying size & checksum...', onLog: onLog);

      final actualPartBytes = partFile.existsSync() ? partFile.lengthSync() : -1;
      if (actualPartBytes != fileDef.bytes) {
        if (partFile.existsSync()) partFile.deleteSync();
        final err =
            'Downloaded size ($actualPartBytes bytes) does not match expected size (${fileDef.bytes} bytes) for ${fileDef.path}';
        _log(err, level: 'error', onLog: onLog);
        throw StateError(err);
      }

      final computedHash = await _computeSha256(partFile);
      if (computedHash.toLowerCase() != fileDef.sha256.toLowerCase()) {
        if (partFile.existsSync()) partFile.deleteSync();
        final err =
            'SHA-256 verification failed for ${fileDef.path}: expected ${fileDef.sha256}, got $computedHash';
        _log(err, level: 'error', onLog: onLog);
        throw StateError(err);
      }
      _log('[${i + 1}/$totalFiles] SHA-256 verified successfully for ${fileDef.path} ($computedHash)', onLog: onLog);

      if (finalFile.existsSync()) finalFile.deleteSync();
      partFile.renameSync(finalPath);
      _log('[${i + 1}/$totalFiles] Successfully installed ${fileDef.path} to $finalPath', onLog: onLog);

      yield PluginDownloadProgress(
        fileName: fileDef.path,
        fileIndex: i + 1,
        totalFiles: totalFiles,
        fileBytesReceived: fileDef.bytes,
        fileTotalBytes: fileDef.bytes,
        fileProgress: 1.0,
        overallBytesReceived: overallBytesReceived,
        overallTotalBytes: overallTotalBytes,
        overallProgress: overallTotalBytes > 0 ? (overallBytesReceived / overallTotalBytes).clamp(0.0, 1.0) : 1.0,
      );
    }

    _log('All $totalFiles files downloaded and verified successfully.', onLog: onLog);
  }

  static Future<String> _computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
