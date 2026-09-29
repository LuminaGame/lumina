import 'engine.dart';
import 'gpu.dart';

/// A claim on a shared [FilamentEngine].
///
/// Every holder — a viewport, a thumbnail renderer, a sub-editor that frees
/// engine objects in its own `dispose` — takes one and releases it when it is
/// done with the engine. The engine stays alive while any lease is held and is
/// destroyed by [FilamentEngineHost] after the last [release], once its
/// engine-scoped resources are gone.
class FilamentEngineLease {
  FilamentEngineLease._(this._entry, this.owner);

  final _HostedEngine _entry;

  /// Who holds this lease, for leak reports (`FilamentEngineHost.leaseOwners`).
  final String owner;
  bool _released = false;

  /// The shared engine. Throws after [release].
  FilamentEngine get engine {
    if (_released) throw StateError('FilamentEngineLease($owner) was released');
    return _entry.engine;
  }

  /// Whether [release] was called.
  bool get isReleased => _released;

  /// Gives the engine back. The last release destroys it (engine-scoped
  /// resources first). Calling it again does nothing.
  void release() {
    if (_released) return;
    _released = true;
    FilamentEngineHost._release(this);
  }

  @override
  String toString() => 'FilamentEngineLease($owner${_released ? ', released' : ''})';
}

class _HostedEngine {
  _HostedEngine(this.key, this.engine);
  final _EngineKey key;
  final FilamentEngine engine;
  final List<FilamentEngineLease> leases = [];
}

class _EngineKey {
  const _EngineKey(this.backend, this.gpu);
  final FilamentBackend backend;
  final FilamentGpuPreference gpu;

  @override
  bool operator ==(Object other) => other is _EngineKey && other.backend == backend && other.gpu == gpu;

  @override
  int get hashCode => Object.hash(backend, gpu);
}

/// One Filament engine per process and GPU, shared by every viewport.
///
/// Engines are keyed by backend and GPU preference (`gpu`, else
/// [FilamentEngine.defaultGpuPreference] at the time of the call), so viewports
/// asking for the same GPU share one engine, and changing the preference gives
/// new viewports a new engine while existing ones keep theirs. Each viewport
/// still owns its own swap chain, renderer, view, scene and camera on it.
abstract final class FilamentEngineHost {
  static final Map<_EngineKey, _HostedEngine> _engines = {};

  /// A lease on the shared engine for [backend] and [gpu], creating the engine
  /// (with [config], only used then) when there is none. Null when no engine
  /// can be created on this host.
  static FilamentEngineLease? acquire({
    String owner = 'anonymous',
    FilamentBackend backend = FilamentBackend.defaultBackend,
    FilamentGpuPreference? gpu,
    EngineConfig? config,
  }) {
    final key = _EngineKey(backend, gpu ?? FilamentEngine.defaultGpuPreference);
    var entry = _engines[key];
    if (entry == null || entry.engine.isDisposed) {
      final engine = FilamentEngine.create(backend: backend, gpu: key.gpu, config: config);
      if (engine == null) return null;
      entry = _HostedEngine(key, engine);
      final owned = entry;
      markHostOwnedEngine(engine, () => owned.leases.map((l) => l.owner).join(', '));
      _engines[key] = entry;
    }
    final lease = FilamentEngineLease._(entry, owner);
    entry.leases.add(lease);
    return lease;
  }

  /// Another lease on [engine] if the host owns it; null for an engine created
  /// directly with `FilamentEngine.create` (its creator owns it).
  static FilamentEngineLease? retain(FilamentEngine engine, {String owner = 'anonymous'}) {
    final entry = _entryFor(engine);
    if (entry == null) return null;
    final lease = FilamentEngineLease._(entry, owner);
    entry.leases.add(lease);
    return lease;
  }

  /// Whether the host owns [engine].
  static bool owns(FilamentEngine engine) => _entryFor(engine) != null;

  /// How many leases hold [engine] (0 when the host does not own it).
  static int leaseCount(FilamentEngine engine) => _entryFor(engine)?.leases.length ?? 0;

  /// The owners of [engine]'s leases, in the order they were taken.
  static List<String> leaseOwners(FilamentEngine engine) =>
      _entryFor(engine)?.leases.map((l) => l.owner).toList() ?? const [];

  /// The engines the host currently owns.
  static List<FilamentEngine> get liveEngines => [for (final e in _engines.values) e.engine];

  /// How many engines the host currently owns.
  static int get liveEngineCount => _engines.length;

  static _HostedEngine? _entryFor(FilamentEngine engine) {
    for (final e in _engines.values) {
      if (identical(e.engine, engine)) return e;
    }
    return null;
  }

  static void _release(FilamentEngineLease lease) {
    final entry = lease._entry;
    entry.leases.remove(lease);
    if (entry.leases.isNotEmpty) return;
    if (identical(_engines[entry.key], entry)) _engines.remove(entry.key);
    if (entry.engine.isDisposed) return;
    // The last holder is gone: wait for the GPU, tear down engine-scoped
    // resources (caches) with the engine still alive, then destroy it.
    try {
      entry.engine.flushAndWait();
    } catch (_) {}
    disposeHostOwnedEngine(entry.engine);
  }
}
