part of '../import_queue.dart';

// -----------------------------------------------------------------------------
// Worker isolate
// -----------------------------------------------------------------------------

/// One long-lived import isolate. Protocol (records over [SendPort]s of one
/// isolate group, so plain Dart data — maps, lists, typed data, enums — is
/// copied, never shared):
///
/// - UI → worker: `(id, 'prepare', (projectPath, ImportRequest))` stages and
///   converts, keeps the [PreparedImport] and answers with the
///   [ImportThumbnailJob] the UI isolate draws; `(id, 'write', ImportThumbnails)`
///   applies the drawn thumbnails, writes the family and answers with the
///   [ImportWriteResult]; `('decoded', request, DecodedRgbaImage?, error?)`
///   answers a decode; `null` shuts the isolate down.
/// - worker → UI: `(id, true, result)` / `(id, false, errorText)`; each
///   [EngineLogEntry] the worker logs, as it is logged, for the Output Log;
///   `('decode', request, bytes)` asks for an image decoded with the UI
///   isolate's platform codec, so the texels a thumbnail samples match a
///   direct import's.
class _ImportWorker {
  _ImportWorker._(this._isolate, this._commands, this._responses, this._logger, this._recordStep);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;
  final EngineLoggerService _logger;
  final void Function(String kind, Duration took) _recordStep;
  final Map<int, Completer<Object?>> _calls = {};
  int _nextCall = 0;

  static Future<_ImportWorker> spawn(EngineLoggerService logger, void Function(String, Duration) recordStep) async {
    final responses = ReceivePort('lumina-import-worker');
    final handshake = Completer<SendPort>();
    _ImportWorker? worker;
    final early = <dynamic>[];
    responses.listen((message) {
      if (!handshake.isCompleted && message is SendPort) {
        handshake.complete(message);
      } else if (worker == null) {
        early.add(message);
      } else {
        worker._onMessage(message);
      }
    });
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_importWorkerMain, responses.sendPort,
          debugName: 'lumina-import-worker', errorsAreFatal: false);
    } catch (_) {
      responses.close();
      rethrow;
    }
    final commands = await handshake.future;
    final w = worker = _ImportWorker._(isolate, commands, responses, logger, recordStep);
    early.forEach(w._onMessage);
    return w;
  }

  void _onMessage(dynamic message) {
    if (message is EngineLogEntry) {
      _logger.replay([message]);
      return;
    }
    if (message is (String, int, Uint8List) && message.$1 == 'decode') {
      unawaited(_decodeForWorker(message.$2, message.$3));
      return;
    }
    if (message is (int, bool, Object?)) {
      final call = _calls.remove(message.$1);
      if (call == null) return;
      if (message.$2) {
        call.complete(message.$3);
      } else {
        call.completeError(RemoteImportError('${message.$3}'));
      }
    }
  }

  /// Decodes an image with this (UI) isolate's platform codec for the
  /// worker ([EncodedImageDecoder.platformCodecProxy]).
  Future<void> _decodeForWorker(int request, Uint8List bytes) => timeSynchronousSlices(() async {
        try {
          final image = await EncodedImageDecoder.decodeRgba(bytes);
          _commands.send(('decoded', request, image, null));
        } catch (e) {
          _commands.send(('decoded', request, null, e is FormatException ? e.message : '$e'));
        }
      }, (longest) => _recordStep('decode', longest));

  Future<Object?> _call(String op, Object? argument) {
    final id = _nextCall++;
    final completer = _calls[id] = Completer<Object?>();
    _commands.send((id, op, argument));
    return completer.future;
  }

  Future<ImportThumbnailJob> prepare(int job, String projectPath, ImportRequest request) async =>
      await _call('prepare', (job, projectPath, request)) as ImportThumbnailJob;

  Future<ImportWriteResult> write(int job, ImportThumbnails thumbnails) async =>
      await _call('write', (job, thumbnails)) as ImportWriteResult;

  void close() {
    _commands.send(null);
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _responses.close();
    for (final call in _calls.values) {
      if (!call.isCompleted) call.completeError(StateError('import worker closed'));
    }
    _calls.clear();
  }
}

@pragma('vm:entry-point')
void _importWorkerMain(SendPort toUi) {
  final commands = ReceivePort('lumina-import-worker-commands');
  toUi.send(commands.sendPort);
  final repo = AssetRepository();
  final prepared = <int, PreparedImport>{};
  // Images decode on the UI isolate's platform codec, as they would in a
  // direct import there (see EncodedImageDecoder.platformCodecProxy).
  final decodes = <int, Completer<DecodedRgbaImage>>{};
  var nextDecode = 0;
  EncodedImageDecoder.platformCodecProxy = (bytes) {
    final request = nextDecode++;
    final completer = decodes[request] = Completer<DecodedRgbaImage>();
    toUi.send(('decode', request, bytes));
    return completer.future;
  };
  // The worker's logger is its own singleton: forward each line to the UI
  // isolate's Output Log, and keep the worker from printing it a second time.
  runZoned(
    () {
      EngineLoggerService().logStream.listen(toUi.send);
      commands.listen((message) async {
        if (message == null) {
          commands.close();
          return;
        }
        if (message is (String, int, DecodedRgbaImage?, String?) && message.$1 == 'decoded') {
          final completer = decodes.remove(message.$2);
          final image = message.$3;
          if (image != null) {
            completer?.complete(image);
          } else {
            completer?.completeError(FormatException(message.$4 ?? 'the image does not decode'));
          }
          return;
        }
        final (int id, String op, Object? argument) = message as (int, String, Object?);
        try {
          switch (op) {
            case 'prepare':
              final (int job, String projectPath, ImportRequest r) = argument as (int, String, ImportRequest);
              final p = await repo.prepareImport(
                projectPath: projectPath,
                sourceFilePath: r.sourcePath,
                targetSubFolder: r.targetSubFolder,
                autoOrganize: r.autoOrganize,
                generateLods: r.generateLods,
                targetSkeletonPath: r.targetSkeletonPath,
                renderThumbnails: false,
                targetBaseName: r.targetBaseName,
                textureSearchDirs: r.textureSearchDirs,
              );
              prepared[job] = p;
              toUi.send((id, true, repo.thumbnailJobFor(p)));
            case 'write':
              final (int job, ImportThumbnails drawn) = argument as (int, ImportThumbnails);
              final p = prepared.remove(job);
              if (p == null) throw StateError('no prepared import for job $job');
              repo.applyThumbnails(p, drawn);
              toUi.send((id, true, await repo.writeImport(p)));
            default:
              throw ArgumentError('unknown import worker op "$op"');
          }
        } catch (e) {
          toUi.send((id, false, describeImportError(e)));
        }
      });
    },
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {}),
  );
}
