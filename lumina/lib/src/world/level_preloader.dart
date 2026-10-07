import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine;

import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// The levels of the open project, by name (`L_Arena`): what the Blueprint
/// validator checks a Load Level / Change Level node's Level Name against.
/// Empty — nothing registered — checks nothing. Play-In-Editor
/// and the editor register them from the project's asset index.
abstract final class LuminaProjectLevels {
  static final Set<String> _names = {};

  static Set<String> get names => Set.unmodifiable(_names);

  static void register(Iterable<String> levelNames) => _names.addAll(levelNames.map(nameOf));

  static void clear() => _names.clear();

  /// `L_Arena` for `L_Arena`, `L_Arena.lmas` or `contents/levels/L_Arena.lmas`.
  static String nameOf(String level) => level.replaceAll(r'\', '/').split('/').last.replaceAll('.lmas', '');

  /// Whether [level] is a registered project level (always, when none is).
  static bool isKnown(String level) => _names.isEmpty || _names.contains(nameOf(level));
}

/// What kind of content a level asset is: it decides how the
/// [LuminaLevelPreloader] makes it resident.
enum LuminaAssetKind {
  mesh,
  texture,
  material,
  animation,
  sound,
  blueprint,
  landscape,
  environment,
  other;

  /// The kind named [name] (`mesh`, `texture`…), [other] when unknown.
  static LuminaAssetKind fromName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return other;
  }
}

/// One asset a level loads: the path its components read (a bundle path such
/// as `contents/meshes/SM_Rock.lmas` in a built game, an absolute path in the
/// editor) and its [kind]. The level code generator emits a level's list as
/// `static const List<LuminaAssetRef> assetManifest`.
class LuminaAssetRef {
  final String path;
  final LuminaAssetKind kind;
  const LuminaAssetRef(this.path, [this.kind = LuminaAssetKind.other]);

  /// `SM_Rock`: the file name without its extension, what progress reports
  /// as the content being loaded.
  String get name {
    final file = path.replaceAll(r'\', '/').split('/').last;
    final dot = file.lastIndexOf('.');
    return dot <= 0 ? file : file.substring(0, dot);
  }

  Map<String, Object?> toJson() => {'path': path, 'kind': kind.name};

  static LuminaAssetRef fromJson(Map<String, Object?> json) =>
      LuminaAssetRef(json['path'] as String? ?? '', LuminaAssetKind.fromName(json['kind'] as String?));

  @override
  bool operator ==(Object other) => other is LuminaAssetRef && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => 'LuminaAssetRef($path, ${kind.name})';
}

/// One update of a level preload: after each asset ([loaded] of [total],
/// [current] is the asset that just finished), then either the final
/// [done] update (Success) or one carrying [error] and [stackTrace].
class LuminaLevelLoadProgress {
  final String levelName;
  final int total;
  final int loaded;

  /// The asset this update is about ([LuminaAssetRef.name]); empty on the
  /// final update.
  final String current;
  final Object? error;
  final StackTrace? stackTrace;

  /// Every asset is resident: the level can be switched to at once.
  final bool done;

  const LuminaLevelLoadProgress({
    required this.levelName,
    required this.total,
    required this.loaded,
    this.current = '',
    this.error,
    this.stackTrace,
    this.done = false,
  });

  /// Loaded of total, 0–100 (a level with nothing to load is 100).
  double get percent => total == 0 ? 100.0 : loaded * 100.0 / total;

  bool get hasError => error != null;

  @override
  String toString() => hasError
      ? 'LuminaLevelLoadProgress($levelName error: $error)'
      : 'LuminaLevelLoadProgress($levelName $loaded/$total${done ? ' done' : ' $current'})';
}

/// The asset list of the level [levelName], or null when there is no such
/// level. A built game answers from the generated levels' `assetManifest`s,
/// the editor from the level `.lmas` through the asset index.
typedef LuminaLevelManifestResolver = FutureOr<List<LuminaAssetRef>?> Function(String levelName);

/// Makes one asset resident: reads it through [provider] (a recording
/// provider: whatever it returns stays pinned) and returns anything else to
/// keep alive until the level is switched to or released (a GPU handle, a
/// compiled class). Throws when the asset cannot be loaded.
typedef LuminaAssetPreloadStep = Future<Object?> Function(LuminaAssetRef ref, LuminaAssetProvider provider);

/// What a finished (or running) preload holds.
class _Preload {
  _Preload(this.levelName);
  final String levelName;
  final Map<String, Uint8List> bytes = {};
  final Map<String, Object> misses = {};
  final List<Object> handles = [];
  final StreamController<LuminaLevelLoadProgress> updates = StreamController<LuminaLevelLoadProgress>.broadcast();
  final List<LuminaLevelLoadProgress> history = [];
  bool cancelled = false;
  bool done = false;
  Object? error;
  StackTrace? stackTrace;
  Completer<void>? _finished;

  Future<void> get finished => (_finished ??= Completer<void>()).future;

  void emit(LuminaLevelLoadProgress p) {
    history.add(p);
    if (!updates.isClosed) updates.add(p);
  }

  void finish() {
    final f = _finished ??= Completer<void>();
    if (f.isCompleted) return;
    if (error != null) {
      f.future.ignore();
      f.completeError(error!, stackTrace);
    } else if (cancelled) {
      f.future.ignore();
      f.completeError(StateError("Loading level '$levelName' was cancelled."));
    } else {
      f.complete();
    }
    updates.close();
  }
}

/// Preloads persistent levels in the background — the loading-screen flow
/// (async loading with progress, then Open Level).
///
/// [preload] resolves the level's asset list ([manifestResolver]) and loads
/// every asset through the engine's loaders — bytes through
/// [LuminaAssets.resolve] ([assetProvider], else the game's
/// `LuminaAssets.defaultProvider`, else the disk), meshes into the engine's
/// [LuminaMeshAssetCache] when an [engine] is set, anything a
/// [kindLoaders] step adds — at most [maxConcurrent] at a time, yielding
/// between items, and reports one [LuminaLevelLoadProgress] per asset, then
/// Success (or the first error). What it loaded stays pinned — its bytes are
/// served to the level's components through [LuminaAssets.resolve], its mesh
/// handles keep the GPU assets — until [changeLevel] hands them to the new
/// level or [release] / [cancel] drops them.
class LuminaLevelPreloader {
  LuminaLevelPreloader({this.manifestResolver, this.assetProvider, this.engine, this.maxConcurrent = 4});

  /// The game's preloader: what the Load Level / Change Level nodes and the
  /// game hosts use. The generated `main()` sets its [manifestResolver],
  /// Play-In-Editor its resolver and engine.
  static LuminaLevelPreloader instance = LuminaLevelPreloader();

  LuminaLevelManifestResolver? manifestResolver;
  LuminaAssetProvider? assetProvider;

  /// The engine whose mesh cache preloaded meshes are uploaded to (the
  /// engine the next level renders with). Null: meshes are only read.
  FilamentEngine? engine;
  int maxConcurrent;

  /// What the preloader awaits after each asset before the next (default:
  /// one turn of the event loop). A host can wait for its next frame here to
  /// spread a load over frames.
  Future<void> Function()? betweenItems;

  /// Extra steps by kind (Play-In-Editor compiles Blueprint classes).
  final Map<LuminaAssetKind, LuminaAssetPreloadStep> kindLoaders = {};

  final Map<String, _Preload> _preloads = {};

  /// Whether [levelName] is fully preloaded (Success reached, not released).
  bool isLoaded(String levelName) => _preloads[levelName]?.done ?? false;

  /// Whether [levelName] is being preloaded.
  bool isLoading(String levelName) {
    final p = _preloads[levelName];
    return p != null && !p.done && p.error == null && !p.cancelled;
  }

  /// The levels preloaded or loading.
  Iterable<String> get levels => _preloads.keys;

  /// The paths [levelName]'s preload pinned (bytes read), for diagnostics.
  Set<String> pinnedPaths(String levelName) => {...?_preloads[levelName]?.bytes.keys};

  /// Starts (or joins) preloading [levelName]. The stream replays the updates
  /// so far to a late listener, then continues: one per asset, then the
  /// final `done` update, or an update with an error; it closes after either,
  /// or silently when the load is cancelled.
  Stream<LuminaLevelLoadProgress> preload(String levelName) {
    var p = _preloads[levelName];
    if (p == null || p.cancelled || p.error != null) {
      if (p != null) _drop(p);
      p = _Preload(levelName);
      _preloads[levelName] = p;
      unawaited(_run(p));
    }
    return _replay(p);
  }

  Stream<LuminaLevelLoadProgress> _replay(_Preload p) {
    final controller = StreamController<LuminaLevelLoadProgress>();
    StreamSubscription<LuminaLevelLoadProgress>? sub;
    controller.onListen = () {
      for (final h in List.of(p.history)) {
        controller.add(h);
      }
      if (p.updates.isClosed) {
        controller.close();
        return;
      }
      sub = p.updates.stream.listen(controller.add, onDone: controller.close);
    };
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  /// Preloads [levelName] to the end; throws its error (or a cancellation).
  Future<void> ensureLoaded(String levelName) {
    final existing = _preloads[levelName];
    if (existing != null && existing.done) return Future<void>.value();
    preload(levelName);
    return _preloads[levelName]!.finished;
  }

  /// Stops preloading [levelName] (every level when null) and drops what it
  /// pinned. A cancelled stream sends nothing more.
  void cancel([String? levelName]) {
    final targets = levelName == null || levelName.isEmpty
        ? _preloads.values.toList()
        : [?_preloads[levelName]];
    for (final p in targets) {
      if (p.done) continue;
      p.cancelled = true;
      _drop(p);
      p.finish();
    }
  }

  /// Drops [levelName]'s preload (bytes, GPU handles): an abandoned load, or
  /// a level switched to already.
  void release(String levelName) {
    final p = _preloads[levelName];
    if (p == null) return;
    _drop(p);
  }

  /// Cancels everything, releases every preload and forgets the resolver,
  /// provider and engine (a Play session ending).
  void reset() {
    cancel();
    for (final p in _preloads.values.toList()) {
      _drop(p);
    }
    manifestResolver = null;
    assetProvider = null;
    engine = null;
    betweenItems = null;
    kindLoaders.clear();
  }

  /// Switches to [levelName] with [swap] — the host's own level change,
  /// which completes once the new level has begun play — after preloading it
  /// when it is not preloaded yet; then hands the pinned assets over (the new
  /// level's components have taken their own references) and releases the
  /// preload. Throws what the preload or [swap] throws.
  Future<void> changeLevel(String levelName, Future<void> Function() swap) async {
    // Never switch inside the tick that asked for it.
    await Future<void>.value();
    await ensureLoaded(levelName);
    try {
      await swap();
      // The new level's meshes are loading from what the preload holds; let
      // them take their own references before it lets go.
      final e = engine;
      final cache = e == null || e.isDisposed ? null : LuminaMeshAssetCache.existingFor(e);
      if (cache != null && !cache.isDisposed) await cache.whenIdle();
    } finally {
      release(levelName);
    }
  }

  void _drop(_Preload p) {
    if (identical(_preloads[p.levelName], p)) _preloads.remove(p.levelName);
    LuminaAssets.unpinResident(p);
    for (final h in p.handles) {
      if (h is LuminaMeshHandle) h.release();
    }
    p.handles.clear();
    p.bytes.clear();
    p.misses.clear();
  }

  Future<void> _run(_Preload p) async {
    // The first update goes out after the caller has subscribed.
    await Future<void>.value();
    List<LuminaAssetRef>? refs;
    try {
      final resolver = manifestResolver;
      if (resolver == null) throw StateError("Load Level '${p.levelName}': this game has no level manifest.");
      refs = await resolver(p.levelName);
      if (refs == null) throw StateError("Load Level: no level named '${p.levelName}' in this game.");
    } catch (e, st) {
      _fail(p, 0, 0, e, st);
      return;
    }
    if (p.cancelled) return;
    final unique = <String, LuminaAssetRef>{};
    for (final r in refs) {
      unique.putIfAbsent(r.path, () => r);
    }
    final items = unique.values.toList();
    final total = items.length;
    final base = LuminaAssets.resolve(assetProvider);
    // Everything the steps read is pinned, and served back to the level's
    // components once they load (LuminaAssets.resolve).
    Future<Uint8List> recording(String path) async {
      final pinned = p.bytes[path];
      if (pinned != null) return pinned;
      try {
        final bytes = await base(path);
        if (!p.cancelled) p.bytes[path] = bytes;
        return bytes;
      } catch (e) {
        if (!p.cancelled) p.misses[path] = e;
        rethrow;
      }
    }

    LuminaAssets.pinResident(p, p.bytes, p.misses);
    var next = 0;
    var loaded = 0;
    var failed = false;
    Future<void> worker() async {
      while (!failed && !p.cancelled && next < items.length) {
        final ref = items[next++];
        try {
          final handle = await _load(ref, recording);
          if (p.cancelled) {
            if (handle is LuminaMeshHandle) handle.release();
            return;
          }
          if (handle != null) p.handles.add(handle);
        } catch (e, st) {
          if (failed || p.cancelled) return;
          failed = true;
          _fail(p, total, loaded, Exception("Loading '${ref.path}' for level '${p.levelName}' failed: $e"), st);
          return;
        }
        if (failed || p.cancelled) return;
        loaded++;
        p.emit(LuminaLevelLoadProgress(levelName: p.levelName, total: total, loaded: loaded, current: ref.name));
        // Off the frame budget: one asset per turn of the event loop.
        await (betweenItems?.call() ?? Future<void>.delayed(Duration.zero));
      }
    }

    final workers = maxConcurrent < 1 ? 1 : maxConcurrent;
    await Future.wait([for (var i = 0; i < workers && i < (total == 0 ? 1 : total); i++) worker()]);
    if (failed || p.cancelled) return;
    p.done = true;
    p.emit(LuminaLevelLoadProgress(levelName: p.levelName, total: total, loaded: total, done: true));
    p.finish();
  }

  void _fail(_Preload p, int total, int loaded, Object error, StackTrace stackTrace) {
    p.error = error;
    p.stackTrace = stackTrace;
    p.emit(LuminaLevelLoadProgress(
        levelName: p.levelName, total: total, loaded: loaded, error: error, stackTrace: stackTrace));
    _drop(p);
    p.finish();
  }

  Future<Object?> _load(LuminaAssetRef ref, LuminaAssetProvider provider) async {
    final step = kindLoaders[ref.kind];
    if (step != null) return step(ref, provider);
    if (ref.kind == LuminaAssetKind.mesh) {
      final e = engine;
      if (e != null && !e.isDisposed) {
        // Uploaded now, read through the provider the level's mesh components
        // use: the cache knows the path under the same key, so their acquire
        // takes an instance at once, before the preload lets go of its own.
        final handle = await LuminaMeshAssetCache.forEngine(e).acquire(ref.path, assetProvider: assetProvider);
        if (handle == null) throw StateError('the mesh cache is gone');
        return handle;
      }
      await LuminaMeshAssetCache.meshBytes(provider, ref.path);
      return null;
    }
    await provider(ref.path);
    return null;
  }
}
