import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import '../repositories/asset_repository.dart';
import 'encoded_image_decoder.dart';
import 'engine_logger_service.dart';

/// Where one file of an import batch is. A file moves
/// queued → converting → writing → thumbnail → done, or ends failed /
/// cancelled.
enum ImportStage {
  /// Waiting for a worker.
  queued,

  /// Staged, converted and routed in the worker isolate; its placeholder
  /// thumbnails drawn on the UI isolate.
  converting,

  /// The asset family being written under `contents/` by the worker.
  writing,

  /// Written and indexed (it shows in the Content Browser); its rendered
  /// thumbnail is being made on the UI isolate.
  thumbnail,

  done,
  failed,

  /// Never started: the batch was cancelled first.
  cancelled;

  bool get isTerminal => this == done || this == failed || this == cancelled;
}

/// One file to import and how.
class ImportRequest {
  const ImportRequest({
    required this.sourcePath,
    this.targetSubFolder,
    this.autoOrganize = true,
    this.generateLods = false,
    this.targetSkeletonPath,
    this.targetBaseName,
    this.textureSearchDirs = const [],
  });

  /// The external file (`.glb`, `.gltf`, `.obj`, `.fbx`, an image, …).
  final String sourcePath;

  /// The Content Browser folder it lands in when [autoOrganize] is off.
  final String? targetSubFolder;
  final bool autoOrganize;
  final bool generateLods;

  /// For an animation: the skeletal mesh to retarget onto (see
  /// [AssetRepository.convertStagedAsset]).
  final String? targetSkeletonPath;

  /// The asset's name when it is not the file's (the folder importer's
  /// "rename" conflict policy: `Barrel_01` → `Barrel_01_1`).
  final String? targetBaseName;

  /// For an FBX: folders searched first for its textures (the Import
  /// dialog's "Textures Folder").
  final List<String> textureSearchDirs;

  String get fileName => sourcePath.substring(sourcePath.replaceAll(r'\', '/').lastIndexOf('/') + 1);

  /// Staging a `.webp` decodes it with `dart:ui`, which only the UI isolate
  /// may use, so such a file is converted there instead of in a worker.
  bool get needsUiIsolate => sourcePath.toLowerCase().endsWith('.webp');
}

/// One file's state, as [ImportQueue.progress] reports it.
class ImportProgress {
  const ImportProgress({
    required this.batch,
    required this.index,
    required this.total,
    required this.request,
    required this.stage,
    required this.fileFraction,
    required this.overallFraction,
    required this.message,
    required this.elapsed,
    this.result,
    this.assets = const [],
    this.error,
  });

  /// Which batch (1, 2, …): a batch lasts from the first file queued while
  /// the queue was idle until every file queued since is finished.
  final int batch;

  /// This file's position in its batch (0-based) and the batch's size when
  /// this event was sent (it grows when files are added mid-batch).
  final int index;
  final int total;

  final ImportRequest request;
  final ImportStage stage;

  /// How far this file is (0–1) and how far the batch is: the mean of every
  /// file's fraction, monotonic while no file is added.
  final double fileFraction;
  final double overallFraction;

  /// What is happening, for the progress panel.
  final String message;

  /// Since the batch started.
  final Duration elapsed;

  /// The primary asset, from [ImportStage.thumbnail] on.
  final RealAssetInfo? result;

  /// Every asset the file produced (primary, materials, textures, clips),
  /// as the Content Browser lists them, from [ImportStage.thumbnail] on.
  final List<RealAssetInfo> assets;

  /// Why it failed ([ImportStage.failed]).
  final String? error;

  String get fileName => request.fileName;
}

/// How a batch ended.
class ImportBatchSummary {
  const ImportBatchSummary({
    required this.batch,
    required this.total,
    required this.imported,
    required this.failed,
    required this.cancelled,
    required this.errors,
    required this.elapsed,
  });

  final int batch;
  final int total;
  final int imported;
  final int failed;
  final int cancelled;

  /// File name → error, for every failed file.
  final Map<String, String> errors;
  final Duration elapsed;
}

/// The UI isolate's last step for a written file (the editor renders its
/// Filament thumbnails here). Gets the file's [ImportStage.thumbnail] event.
typedef ImportThumbnailStep = Future<void> Function(ImportProgress written);

/// Imports files in the background: each file is staged and converted — glTF / OBJ /
/// FBX parsing, Assimp, texture decoding and downscaling, the thumbnail's
/// mesh projection — in a long-lived worker isolate, and written there too;
/// the UI isolate only paints the placeholder thumbnails, indexes the new
/// files and runs [thumbnailStep], one short step at a time with the event
/// loop yielded between steps, so the editor keeps drawing frames.
///
/// Files go through the same [AssetRepository] steps as
/// [AssetRepository.importExternalFile], so what lands on disk is identical.
/// A file that fails never stops the batch; [cancel] lets the files in
/// flight finish and skips the rest. Each worker loads its own FFI
/// libraries (Assimp); no native pointer or Filament object ever crosses an
/// isolate.
class ImportQueue {
  ImportQueue({
    required this.projectPath,
    int workers = 1,
    this.thumbnailStep,
    Future<void> Function()? frameYield,
    AssetRepository? repository,
  })  : _workers = workers.clamp(1, maxWorkers),
        _frameYield = frameYield ?? _yieldEventLoop,
        _repo = repository ?? AssetRepository();

  /// The most worker isolates a queue runs ([workers]).
  static const int maxWorkers = 4;

  final String projectPath;
  ImportThumbnailStep? thumbnailStep;
  final Future<void> Function() _frameYield;
  final AssetRepository _repo;
  final EngineLoggerService _logger = EngineLoggerService();

  static Future<void> _yieldEventLoop() => Future<void>.delayed(Duration.zero);

  int _workers;

  /// How many files convert at once, each in its own worker isolate (1–4).
  /// A change applies to the files not yet started.
  int get workers => _workers;
  set workers(int value) {
    _workers = value.clamp(1, maxWorkers);
    _pump();
  }

  final StreamController<ImportProgress> _progress = StreamController<ImportProgress>.broadcast();
  final StreamController<ImportBatchSummary> _summaries = StreamController<ImportBatchSummary>.broadcast();

  /// Every file's every stage change, in order.
  Stream<ImportProgress> get progress => _progress.stream;

  /// One summary per finished batch.
  Stream<ImportBatchSummary> get summaries => _summaries.stream;

  int _batch = 0;
  final List<_Job> _jobs = [];
  final Queue<_Job> _pending = Queue<_Job>();
  final Stopwatch _clock = Stopwatch();
  final List<_ImportWorker?> _pool = [];
  final List<Future<_ImportWorker>?> _spawning = [];
  int _activeSlots = 0;
  bool _cancelRequested = false;
  bool _disposed = false;
  Completer<void>? _idle;
  ImportBatchSummary? _lastSummary;

  /// The current (or last) batch, one entry per file, in queue order.
  List<ImportProgress> get files => [for (final j in _jobs) j.latest];

  bool get isRunning => _jobs.any((j) => !j.latest.stage.isTerminal);

  /// Whether [cancel] was called during the current batch.
  bool get isCancelling => _cancelRequested && isRunning;

  int get total => _jobs.length;
  int get finished => _jobs.where((j) => j.latest.stage.isTerminal).length;
  int get imported => _count(ImportStage.done);
  int get failed => _count(ImportStage.failed);
  int get cancelled => _count(ImportStage.cancelled);
  int _count(ImportStage stage) => _jobs.where((j) => j.latest.stage == stage).length;

  /// The batch's progress, 0–1.
  double get overallFraction => _jobs.isEmpty ? 0 : _jobs.fold<double>(0, (s, j) => s + j.fraction) / _jobs.length;

  /// Since the current (or last) batch started.
  Duration get elapsed => _clock.elapsed;

  ImportBatchSummary? get lastSummary => _lastSummary;

  /// Completes when no file is in flight.
  Future<void> get idle {
    if (!isRunning) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  /// The longest stretch any UI-isolate step of the queue held the isolate
  /// without yielding ([timeSynchronousSlices]) — the frame-budget figure,
  /// kept under 100 ms — and how many steps ran.
  Duration get longestMainIsolateStep => _longestStep;
  int get mainIsolateSteps => _steps;
  Duration _longestStep = Duration.zero;
  int _steps = 0;

  /// The longest run of each kind of UI-isolate step in the current batch
  /// (`thumbnails`, `index`, `decode`, …), for the smoke report.
  Map<String, Duration> get longestMainIsolateStepByKind => Map.unmodifiable(_longestByKind);
  final Map<String, Duration> _longestByKind = {};

  /// Queues [requests] and returns at once; the future completes with each
  /// file's final state, in order, once all of them are finished.
  Future<List<ImportProgress>> enqueue(List<ImportRequest> requests) {
    if (_disposed) throw StateError('ImportQueue was disposed');
    if (requests.isEmpty) return Future.value(const []);
    if (!isRunning) {
      _batch++;
      _jobs.clear();
      _cancelRequested = false;
      _longestStep = Duration.zero;
      _steps = 0;
      _longestByKind.clear();
      _clock
        ..reset()
        ..start();
    }
    final jobs = [
      for (var i = 0; i < requests.length; i++) _Job(this, _jobs.length + i, requests[i]),
    ];
    _jobs.addAll(jobs);
    for (final job in jobs) {
      _emit(job, ImportStage.queued, 0, 'Queued');
      _pending.add(job);
    }
    _pump();
    return Future.wait([for (final j in jobs) j.completer.future]);
  }

  /// Stops the batch after the files already converting: those finish and
  /// keep what they wrote; every file not yet started is cancelled.
  void cancel() {
    if (!isRunning || _cancelRequested) return;
    _cancelRequested = true;
    final skipped = _pending.length;
    while (_pending.isNotEmpty) {
      final job = _pending.removeFirst();
      _emit(job, ImportStage.cancelled, 1, 'Cancelled');
    }
    _logger.log('Import cancelled: $skipped file${skipped == 1 ? '' : 's'} skipped; the files in progress finish.',
        level: 'warning', source: 'ImportQueue');
    _maybeFinish();
  }

  /// Stops the worker isolates. Files in flight are abandoned (their
  /// futures complete as cancelled); the queue cannot be used afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    for (final w in _pool) {
      w?.close();
    }
    for (final s in _spawning) {
      s?.then((w) => w.close(), onError: (_) {});
    }
    _pool.clear();
    // Whoever still waits on a file hears it was cancelled, not an error
    // nobody may be listening for.
    for (final j in _jobs) {
      if (!j.completer.isCompleted) {
        j.completer.complete(ImportProgress(
          batch: _batch,
          index: j.id,
          total: _jobs.length,
          request: j.request,
          stage: ImportStage.cancelled,
          fileFraction: 1,
          overallFraction: overallFraction,
          message: 'Cancelled: the editor closed',
          elapsed: _clock.elapsed,
        ));
      }
    }
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
    await _progress.close();
    await _summaries.close();
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  void _pump() {
    if (_disposed) return;
    while (_activeSlots < _workers && _pending.isNotEmpty && !_cancelRequested) {
      final slot = _activeSlots++;
      unawaited(_runSlot(slot));
    }
  }

  Future<void> _runSlot(int slot) async {
    try {
      while (!_disposed && !_cancelRequested && _pending.isNotEmpty && slot < _workers) {
        await _process(slot, _pending.removeFirst());
      }
    } finally {
      _activeSlots--;
      _maybeFinish();
    }
  }

  Future<_ImportWorker> _workerFor(int slot) {
    while (_pool.length <= slot) {
      _pool.add(null);
      _spawning.add(null);
    }
    final ready = _pool[slot];
    if (ready != null) return Future.value(ready);
    return _spawning[slot] ??= _ImportWorker.spawn(_logger, _recordStep).then((w) {
      _spawning[slot] = null;
      if (_disposed) {
        w.close();
        throw StateError('ImportQueue was disposed');
      }
      _pool[slot] = w;
      return w;
    });
  }

  /// Runs [step] on this isolate after yielding the event loop (so a frame
  /// can be drawn first), and records how long it held the isolate.
  Future<T> _mainStep<T>(String kind, FutureOr<T> Function() step) async {
    await _frameYield();
    return timeSynchronousSlices(step, (longest) => _recordStep(kind, longest));
  }

  void _recordStep(String kind, Duration took) {
    _steps++;
    if (took > _longestStep) _longestStep = took;
    if (took > (_longestByKind[kind] ?? Duration.zero)) _longestByKind[kind] = took;
  }

  Future<void> _process(int slot, _Job job) async {
    final request = job.request;
    try {
      _emit(job, ImportStage.converting, 0.1, 'Converting ${request.fileName}');
      final ImportWriteResult written;
      if (request.needsUiIsolate) {
        written = await _processHere(job);
      } else {
        final worker = await _workerFor(slot);
        final thumbnails = await worker.prepare(job.id, projectPath, request);
        job.fraction = 0.3;
        final drawn = await _mainStep('thumbnails', () => _repo.renderThumbnailJob(thumbnails));
        _emit(job, ImportStage.writing, 0.4, 'Writing ${request.fileName}');
        written = await worker.write(job.id, drawn);
      }
      final assets = await _mainStep('index', () => _repo.indexAndDescribe(projectPath, written.writtenPaths));
      final primary = assets.where((a) => a.relativePath == written.info.relativePath).firstOrNull ?? written.info;
      // In the editor the rendered thumbnails are the slowest part (Filament,
      // one at a time on the UI isolate), so a written file is half done.
      final event = _emit(job, ImportStage.thumbnail, 0.5, 'Rendering thumbnails for ${request.fileName}',
          result: primary, assets: assets);
      job.thumbnailStage = _finishThumbnail(job, event);
    } catch (e) {
      final reason = describeImportError(e);
      _logger.log('Import failed for ${request.fileName}: $reason', level: 'error', source: 'ImportQueue');
      _emit(job, ImportStage.failed, 1, 'Failed: $reason', error: reason);
    }
  }

  /// A file the UI isolate has to convert itself ([ImportRequest.needsUiIsolate]).
  Future<ImportWriteResult> _processHere(_Job job) async {
    final r = job.request;
    final prepared = await _mainStep('convert', () => _repo.prepareImport(
          projectPath: projectPath,
          sourceFilePath: r.sourcePath,
          targetSubFolder: r.targetSubFolder,
          autoOrganize: r.autoOrganize,
          generateLods: r.generateLods,
          targetSkeletonPath: r.targetSkeletonPath,
          renderThumbnails: false,
          targetBaseName: r.targetBaseName,
          textureSearchDirs: r.textureSearchDirs,
        ));
    await _mainStep('thumbnails', () => _repo.renderImportThumbnails(prepared));
    _emit(job, ImportStage.writing, 0.4, 'Writing ${r.fileName}');
    return _mainStep('write', () => _repo.writeImport(prepared));
  }

  Future<void> _finishThumbnail(_Job job, ImportProgress written) async {
    final step = thumbnailStep;
    if (step != null) {
      try {
        await step(written);
      } catch (e) {
        _logger.log('Thumbnail for ${job.request.fileName} failed: $e', level: 'warning', source: 'ImportQueue');
      }
    }
    if (_disposed) return;
    _emit(job, ImportStage.done, 1, 'Imported ${job.request.fileName}', result: written.result, assets: written.assets);
    _maybeFinish();
  }

  ImportProgress _emit(
    _Job job,
    ImportStage stage,
    double fraction,
    String message, {
    RealAssetInfo? result,
    List<RealAssetInfo> assets = const [],
    String? error,
  }) {
    job.fraction = fraction;
    final event = ImportProgress(
      batch: _batch,
      index: job.id,
      total: _jobs.length,
      request: job.request,
      stage: stage,
      fileFraction: fraction,
      overallFraction: overallFraction,
      message: message,
      elapsed: _clock.elapsed,
      result: result,
      assets: assets,
      error: error,
    );
    job.latest = event;
    if (!_progress.isClosed) _progress.add(event);
    if (stage.isTerminal && !job.completer.isCompleted) job.completer.complete(event);
    return event;
  }

  void _maybeFinish() {
    if (_disposed || _jobs.isEmpty || isRunning || _activeSlots > 0) return;
    if (_lastSummary?.batch == _batch) return;
    _clock.stop();
    final summary = ImportBatchSummary(
      batch: _batch,
      total: _jobs.length,
      imported: imported,
      failed: failed,
      cancelled: cancelled,
      errors: {
        for (final j in _jobs)
          if (j.latest.stage == ImportStage.failed) j.request.fileName: j.latest.error ?? 'failed',
      },
      elapsed: _clock.elapsed,
    );
    _lastSummary = summary;
    final seconds = (summary.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    _logger.log(
      'Imported ${summary.imported} of ${summary.total} file${summary.total == 1 ? '' : 's'} in $seconds s'
      '${summary.failed == 0 ? '' : ' · ${summary.failed} failed'}'
      '${summary.cancelled == 0 ? '' : ' · ${summary.cancelled} cancelled'}',
      level: summary.failed == 0 ? 'success' : 'warning',
      source: 'ImportQueue',
    );
    if (!_summaries.isClosed) _summaries.add(summary);
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }
}

/// Runs [body] and reports the longest stretch it held this isolate without
/// yielding — each synchronous run of its code and of every callback it
/// schedules (future continuations, microtasks), not the time it spent
/// waiting on I/O, other isolates or the engine (a codec, a raster). That is
/// the most a step can delay a frame.
Future<T> timeSynchronousSlices<T>(FutureOr<T> Function() body, void Function(Duration longest) report) async {
  var longest = Duration.zero;
  final slice = Stopwatch();
  var depth = 0;
  R timed<R>(R Function() run) {
    if (depth++ == 0) {
      slice
        ..reset()
        ..start();
    }
    try {
      return run();
    } finally {
      if (--depth == 0) {
        slice.stop();
        if (slice.elapsed > longest) longest = slice.elapsed;
      }
    }
  }

  try {
    return await runZoned(
      () => Future<T>.sync(body),
      zoneSpecification: ZoneSpecification(
        run: <R>(self, parent, zone, f) => timed(() => parent.run(zone, f)),
        runUnary: <R, A>(self, parent, zone, f, a) => timed(() => parent.runUnary(zone, f, a)),
        runBinary: <R, A, B>(self, parent, zone, f, a, b) => timed(() => parent.runBinary(zone, f, a, b)),
      ),
    );
  } finally {
    report(longest);
  }
}

/// [error] as one readable line (no `Exception:` / `FormatException:` prefix).
String describeImportError(Object error) {
  if (error is FormatException) return error.message;
  if (error is RemoteImportError) return error.message;
  final text = '$error';
  for (final prefix in const ['Exception: ', 'FileSystemException: ']) {
    if (text.startsWith(prefix)) return text.substring(prefix.length);
  }
  return text;
}

/// An error raised in an import worker, carried back as its text.
class RemoteImportError implements Exception {
  const RemoteImportError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Job {
  _Job(ImportQueue queue, this.id, this.request)
      : latest = ImportProgress(
          batch: queue._batch,
          index: id,
          total: 0,
          request: request,
          stage: ImportStage.queued,
          fileFraction: 0,
          overallFraction: 0,
          message: 'Queued',
          elapsed: Duration.zero,
        );

  final int id;
  final ImportRequest request;
  final Completer<ImportProgress> completer = Completer<ImportProgress>();
  ImportProgress latest;
  double fraction = 0;
  Future<void>? thumbnailStage;
}

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
