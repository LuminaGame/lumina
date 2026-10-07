import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:path/path.dart' as p;

import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// One mesh drawn from the engine-scoped cache: an instance of a shared
/// glTF asset. [release] it when the component or viewport stops
/// drawing it — after removing [instance]'s entities from its scene.
class LuminaMeshHandle {
  LuminaMeshHandle._(this._entry, this.instance);

  final _MeshEntry _entry;

  /// This holder's own entities, transforms and material instances; the
  /// vertex/index buffers and textures are shared with every other handle.
  final FilamentAssetInstance instance;
  bool _released = false;

  /// The content key (`<bytes>:<digest>`) the asset is cached under.
  String get key => _entry.key;

  /// The canonical source path the asset was first loaded from.
  String get sourcePath => _entry.sourcePath;

  /// The shared asset (textures, buffers, materials).
  FilamentAsset get asset => _entry.asset;

  bool get isReleased => _released;

  /// Gives the instance back; the asset is destroyed with its last handle.
  void release() {
    if (_released) return;
    _released = true;
    _entry.cache._release(this);
  }
}

class _MeshEntry {
  _MeshEntry(this.cache, this.key, this.sourcePath, this.asset, this.byteLength, this.spare);
  final LuminaMeshAssetCache cache;
  final String key;
  final String sourcePath;
  final Set<String> sourcePaths = {};
  final FilamentAsset asset;
  final int byteLength;

  /// The instance `createInstancedAsset` made, until the first handle takes it.
  FilamentAssetInstance? spare;
  final List<LuminaMeshHandle> handles = [];
  int instances = 1;
}

/// What the cache holds for one asset, for diagnostics and tests.
class LuminaMeshCacheEntryInfo {
  const LuminaMeshCacheEntryInfo({
    required this.key,
    required this.sourcePath,
    required this.sourcePaths,
    required this.handles,
    required this.instances,
    required this.byteLength,
  });
  final String key;
  final String sourcePath;
  final Set<String> sourcePaths;
  final int handles;
  final int instances;
  final int byteLength;

  @override
  String toString() => 'LuminaMeshCacheEntry($sourcePath, $handles handles, $instances instances, $byteLength bytes)';
}

/// The glTF meshes one Filament engine has uploaded, shared by every world
/// and viewport drawing on that engine (one render resource per mesh
/// however many viewports show it).
///
/// Get it with [forEngine]: it is an engine-scoped resource
/// (`FilamentEngine.engineScoped`), so it is torn
/// down just before its engine. Entries are keyed by **content** — the length
/// and digest of the bytes actually parsed — and reached by **path**: a
/// path-based [acquire] remembers which content a canonical source path (and,
/// on disk, its size and mtime) resolved to, so an unchanged file is neither
/// re-read nor re-uploaded, an edited one gets a new entry, and a payload the
/// editor already holds ([acquireBytes]) meets the path-based load of the same
/// file in one GPU asset.
class LuminaMeshAssetCache {
  final FilamentEngine engine;
  final FilamentMaterialProvider materialProvider;
  late final FilamentAssetLoader assetLoader;
  late final FilamentResourceLoader resourceLoader;
  final List<TextureProvider> _textureProviders = [];

  final Map<String, _MeshEntry> _entries = {};
  final Map<String, Future<_MeshEntry?>> _loadingByContent = {};
  final Map<String, Future<String?>> _resolvingByPath = {};
  final Map<String, String> _contentByPath = {};

  /// Assets parsed but still loading their resources. [dispose] cancels the
  /// load and destroys them.
  final Set<FilamentAsset> _loading = {};
  Future<void> _resourceQueue = Future<void>.value();
  bool _isDisposed = false;
  int _uploadCount = 0;

  /// The engine's cache, created on first use and destroyed with the engine.
  static LuminaMeshAssetCache forEngine(FilamentEngine engine) => engine.engineScoped<LuminaMeshAssetCache>(
        LuminaMeshAssetCache,
        () => LuminaMeshAssetCache._(engine),
        dispose: (cache) => cache.dispose(),
      );

  /// The engine's cache if one was made.
  static LuminaMeshAssetCache? existingFor(FilamentEngine engine) =>
      engine.engineScopedOrNull<LuminaMeshAssetCache>(LuminaMeshAssetCache);

  /// Editor hook (lumina_ui installs its texture budget): transforms the
  /// bytes a path-based [acquire] read before they are parsed. Null in games,
  /// which ship their cooked `.entity.glb` as is.
  static Future<Uint8List> Function(String sourcePath, Uint8List bytes)? sourceFilter;

  LuminaMeshAssetCache._(this.engine) : materialProvider = FilamentMaterialProvider.ubershader(engine) {
    assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider);
    resourceLoader = FilamentResourceLoader.create(engine: engine);
    for (final (mime, make) in <(String, TextureProvider Function())>[
      ('image/jpeg', () => TextureProvider.stb(engine: engine)),
      ('image/png', () => TextureProvider.stb(engine: engine)),
      ('image/ktx2', () => TextureProvider.ktx2(engine: engine)),
      ('image/webp', () => TextureProvider.webp(engine: engine)),
    ]) {
      try {
        final provider = make();
        resourceLoader.addTextureProvider(mime, provider);
        _textureProviders.add(provider);
      } catch (_) {
        // A build without that decoder (WebP on some platforms).
      }
    }
  }

  /// Assets parsed and uploaded since this cache was made.
  int get uploadCount => _uploadCount;

  /// Assets alive now.
  int get liveAssetCount => _entries.length;

  /// Every live asset, with its holders.
  List<LuminaMeshCacheEntryInfo> get entries => [
        for (final e in _entries.values)
          LuminaMeshCacheEntryInfo(
            key: e.key,
            sourcePath: e.sourcePath,
            sourcePaths: Set.unmodifiable(e.sourcePaths),
            handles: e.handles.length,
            instances: e.instances,
            byteLength: e.byteLength,
          ),
      ];

  bool get isDisposed => _isDisposed;

  // ---------------------------------------------------------------------------
  // Keys
  // ---------------------------------------------------------------------------

  /// The file a mesh path is loaded from: an `.lmas` with an `.entity.glb`
  /// companion on disk is that companion; a path that exists on disk
  /// is made absolute and normalized; anything else (an asset-bundle key) is
  /// returned as is.
  static String canonicalSourcePath(String meshAssetPath) {
    var path = meshAssetPath;
    try {
      if (path.toLowerCase().endsWith('.lmas')) {
        final companion = '${path.substring(0, path.length - '.lmas'.length)}.entity.glb';
        if (File(companion).existsSync()) path = companion;
      }
      if (File(path).existsSync()) return p.normalize(File(path).absolute.path);
    } catch (_) {
      // No file system (the web): bundle keys are canonical already.
    }
    return path;
  }

  static final Expando<String> _digests = Expando<String>('LuminaMeshAssetCache.digest');

  /// `<length>:<two 31-bit polynomial hashes over 32-bit words>` of [bytes],
  /// memoized per list. Plain double-safe arithmetic (every product stays
  /// under 2^53), so the web computes the same key; not cryptographic — it
  /// tells edits of a file apart, it does not resist crafted collisions.
  static String contentDigest(Uint8List bytes) {
    final memo = _digests[bytes];
    if (memo != null) return memo;
    const p1 = 2147483647, m1 = 1000003;
    const p2 = 2147483629, m2 = 999983;
    var h1 = 17, h2 = 31;
    final words = bytes.length ~/ 4;
    if (bytes.offsetInBytes % 4 == 0) {
      final view = Uint32List.view(bytes.buffer, bytes.offsetInBytes, words);
      for (var i = 0; i < words; i++) {
        final w = view[i];
        h1 = (h1 * m1 + w) % p1;
        h2 = (h2 * m2 + w) % p2;
      }
    } else {
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < words; i++) {
        final w = data.getUint32(i * 4, Endian.little);
        h1 = (h1 * m1 + w) % p1;
        h2 = (h2 * m2 + w) % p2;
      }
    }
    for (var i = words * 4; i < bytes.length; i++) {
      h1 = (h1 * m1 + bytes[i]) % p1;
      h2 = (h2 * m2 + bytes[i]) % p2;
    }
    final digest = '${bytes.length}:${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
    _digests[bytes] = digest;
    return digest;
  }

  static final Expando<int> _providerTags = Expando<int>('LuminaMeshAssetCache.provider');
  static int _nextProviderTag = 1;

  /// The key a path-based load is remembered under: canonical path, where the
  /// bytes come from, the filter, and on disk the file's size and mtime.
  String? _pathKey(String canonical, LuminaAssetProvider? explicit) {
    final provider = explicit ?? LuminaAssets.defaultProvider;
    final filter = sourceFilter;
    final filterTag = filter == null ? 0 : identityHashCode(filter);
    if (provider == null) {
      try {
        final stat = File(canonical).statSync();
        if (stat.type == FileSystemEntityType.notFound) return null;
        return '$canonical|disk|$filterTag|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
      } catch (_) {
        return null;
      }
    }
    final tag = _providerTags[provider] ??= _nextProviderTag++;
    return '$canonical|provider$tag|$filterTag';
  }

  // ---------------------------------------------------------------------------
  // Acquire / release
  // ---------------------------------------------------------------------------

  /// Completes once no load is in flight: every path being resolved and
  /// every asset being uploaded has landed (or failed). A level preload
  /// waits for it after the switch, so the new level's meshes
  /// hold their own handles before the preload lets go of its.
  Future<void> whenIdle() async {
    while (_resolvingByPath.isNotEmpty || _loadingByContent.isNotEmpty) {
      await Future.wait<Object?>([
        for (final f in _resolvingByPath.values) f.then<Object?>((v) => v, onError: (_) => null),
        for (final f in _loadingByContent.values) f.then<Object?>((v) => v, onError: (_) => null),
      ]);
      // The acquires waiting on those futures take their handles next.
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The glTF bytes a mesh path names. A mesh asset's `.lmas` — what
  /// the editor stores for a placed imported mesh, and what PIE and the
  /// generated level pass on — is a container, not a GLB: it loads through
  /// the `.entity.glb` the import writes next to it (as Blueprints do,
  /// `luminaBlueprintMeshPath`), else through the `.lmas` payload. Both are
  /// read with [provider], so a game's asset bundle serves them too.
  static Future<Uint8List> meshBytes(LuminaAssetProvider provider, String meshAssetPath) async {
    if (!meshAssetPath.toLowerCase().endsWith('.lmas')) return provider(meshAssetPath);
    final glbPath = '${meshAssetPath.substring(0, meshAssetPath.length - '.lmas'.length)}.entity.glb';
    try {
      return await provider(glbPath);
    } catch (_) {
      // No companion GLB (an older import): the container's payload.
    }
    final payload = LuminaAsset.fromBytes(await provider(meshAssetPath)).rawPayload;
    if (payload == null || payload.isEmpty) {
      throw Exception('$meshAssetPath carries no mesh: no $glbPath next to it and no payload');
    }
    return payload;
  }

  /// A new instance of the mesh at [meshAssetPath], loading (and uploading)
  /// it only when this engine has no asset with its content yet. Null when the
  /// cache was disposed or [cancelled] turned true during the load.
  Future<LuminaMeshHandle?> acquire(
    String meshAssetPath, {
    LuminaAssetProvider? assetProvider,
    bool Function()? cancelled,
  }) async {
    _checkNotDisposed();
    // A game reads through its asset bundle and has no file system to ask:
    // only disk loads are canonicalized and stat'ed.
    final onDisk = assetProvider == null && LuminaAssets.defaultProvider == null;
    final canonical = onDisk ? canonicalSourcePath(meshAssetPath) : meshAssetPath;
    final pathKey = _pathKey(canonical, assetProvider);
    String? contentKey = pathKey == null ? null : _contentByPath[pathKey];
    if (contentKey != null && _entries.containsKey(contentKey)) {
      return _handleFor(_entries[contentKey]!, cancelled);
    }

    Future<String?> resolve() async {
      final provider = LuminaAssets.resolve(assetProvider);
      var bytes = await meshBytes(provider, meshAssetPath);
      if (_isDisposed) return null;
      final filter = sourceFilter;
      if (filter != null) bytes = await filter(canonical, bytes);
      if (_isDisposed) return null;
      final key = contentDigest(bytes);
      final entry = await _entryFor(key, bytes, canonical);
      return entry?.key;
    }

    Future<String?> resolving;
    if (pathKey != null) {
      // A block body: returning the removed future from whenComplete would
      // make the future wait for itself.
      resolving = _resolvingByPath[pathKey] ??= resolve().whenComplete(() {
        _resolvingByPath.remove(pathKey);
      });
    } else {
      resolving = resolve();
    }
    contentKey = await resolving;
    if (contentKey == null || _isDisposed) return null;
    if (pathKey != null) _contentByPath[pathKey] = contentKey;
    final entry = _entries[contentKey];
    if (entry == null) return null;
    return _handleFor(entry, cancelled);
  }

  /// A new instance of the glTF [bytes] (a payload the caller already holds,
  /// e.g. the editor's budgeted mesh data), uploaded only when this engine has
  /// no asset with this content. [sourcePath] is recorded (canonicalized).
  Future<LuminaMeshHandle?> acquireBytes(
    Uint8List bytes, {
    required String sourcePath,
    bool Function()? cancelled,
  }) async {
    _checkNotDisposed();
    final key = contentDigest(bytes);
    final canonical = LuminaAssets.defaultProvider == null ? canonicalSourcePath(sourcePath) : sourcePath;
    final entry = await _entryFor(key, bytes, canonical);
    if (entry == null || _isDisposed) return null;
    return _handleFor(entry, cancelled);
  }

  Future<_MeshEntry?> _entryFor(String key, Uint8List bytes, String canonical) async {
    final live = _entries[key];
    if (live != null) {
      live.sourcePaths.add(canonical);
      return live;
    }
    final pending = _loadingByContent[key];
    if (pending != null) {
      final entry = await pending;
      entry?.sourcePaths.add(canonical);
      return entry;
    }
    final load = _load(key, bytes, canonical);
    _loadingByContent[key] = load;
    try {
      return await load;
    } finally {
      _loadingByContent.remove(key);
    }
  }

  Future<_MeshEntry?> _load(String key, Uint8List bytes, String canonical) async {
    final (asset, instances) = assetLoader.createInstancedAsset(bytes, 1);
    if (asset == null || instances.isEmpty) {
      if (asset != null) assetLoader.destroyAsset(asset);
      throw Exception('Failed to parse glTF / GLB asset at $canonical');
    }
    _loading.add(asset);
    try {
      await _loadResources(asset);
    } catch (_) {
      // dispose() cancelled the load and destroyed the asset.
      if (_isDisposed) return null;
      rethrow;
    } finally {
      _loading.remove(asset);
    }
    if (_isDisposed) return null;
    _uploadCount++;
    final entry = _MeshEntry(this, key, canonical, asset, bytes.length, instances.first)..sourcePaths.add(canonical);
    _entries[key] = entry;
    return entry;
  }

  /// gltfio's `ResourceLoader` tracks one asynchronous asset at a time
  /// (`mAsyncAsset`), so loads queue.
  Future<void> _loadResources(FilamentAsset asset) {
    final done = _resourceQueue.then((_) {
      if (_isDisposed || asset.isDisposed) throw StateError('mesh cache disposed during the load');
      return resourceLoader.loadAsync(asset);
    });
    _resourceQueue = done.then((_) {}, onError: (_) {});
    return done;
  }

  LuminaMeshHandle? _handleFor(_MeshEntry entry, bool Function()? cancelled) {
    final instance = entry.spare ?? assetLoader.createInstance(entry.asset);
    if (instance == null) return null;
    if (identical(instance, entry.spare)) {
      entry.spare = null;
    } else {
      entry.instances++;
    }
    final handle = LuminaMeshHandle._(entry, instance);
    entry.handles.add(handle);
    if (cancelled != null && cancelled()) {
      handle.release();
      return null;
    }
    return handle;
  }

  void _release(LuminaMeshHandle handle) {
    if (_isDisposed) return;
    final entry = handle._entry;
    entry.handles.remove(handle);
    if (entry.handles.isNotEmpty) {
      // Others still draw the asset: take this instance apart now rather
      // than leave it allocated until the asset goes.
      _destroyInstance(handle.instance);
      return;
    }
    if (!identical(_entries[entry.key], entry)) return;
    _entries.remove(entry.key);
    _contentByPath.removeWhere((_, v) => v == entry.key);
    try {
      assetLoader.destroyAsset(entry.asset);
      assetLoader.gc();
    } catch (_) {}
  }

  /// gltfio cannot destroy a single instance (`AssetLoader` has no
  /// `destroyInstance`), so a released instance of an asset other holders
  /// still draw is taken apart here: its renderable, light and transform
  /// components and entities, then its material instances — detached from
  /// the instance first, so the asset's own teardown does not free them a
  /// second time. That teardown later meets the dead entities and skips them
  /// (the entity manager ignores dead ids; the component managers find no
  /// component). Without this, every sub-editor opened and closed on a mesh
  /// the level shows would leave one more instance allocated.
  void _destroyInstance(FilamentAssetInstance instance) {
    try {
      final materialInstances = instance.materialInstances;
      final entities = <int>{...instance.entities, instance.root};
      instance.detachMaterialInstances();
      for (final entity in entities) {
        engine.destroyEntity(entity);
      }
      for (final mi in materialInstances) {
        mi.dispose();
      }
    } catch (_) {
      // A half-destroyed instance is still never drawn again.
    }
  }

  // ---------------------------------------------------------------------------
  // Compatibility: instance-only API over handles.
  // ---------------------------------------------------------------------------

  final Map<FilamentAssetInstance, LuminaMeshHandle> _byInstance = Map.identity();

  /// Acquires a new [FilamentAssetInstance] for [meshAssetPath]; pair with
  /// [releaseInstance].
  Future<FilamentAssetInstance?> acquireInstance(
    String meshAssetPath, {
    Future<Uint8List> Function(String path)? assetProvider,
  }) async {
    final handle = await acquire(meshAssetPath, assetProvider: assetProvider);
    if (handle == null) return null;
    _byInstance[handle.instance] = handle;
    return handle.instance;
  }

  /// Releases an instance from [acquireInstance].
  void releaseInstance(String meshAssetPath, FilamentAssetInstance instance) {
    _byInstance.remove(instance)?.release();
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot acquire instances from a disposed LuminaMeshAssetCache.');
    }
  }

  /// Destroys every asset and the loaders. Runs as the engine's scoped
  /// teardown (before the engine), never while a viewport still draws.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    if (_loading.isNotEmpty) {
      try {
        resourceLoader.asyncCancelLoad();
      } catch (_) {}
      for (final asset in _loading) {
        try {
          assetLoader.destroyAsset(asset);
        } catch (_) {}
      }
      _loading.clear();
    }
    for (final entry in _entries.values) {
      try {
        assetLoader.destroyAsset(entry.asset);
      } catch (_) {}
    }
    _entries.clear();
    _contentByPath.clear();
    _byInstance.clear();

    resourceLoader.dispose();
    for (final provider in _textureProviders) {
      try {
        provider.dispose();
      } catch (_) {}
    }
    _textureProviders.clear();
    assetLoader.dispose();
    materialProvider.dispose();
  }
}

/// A world's view of its engine's [LuminaMeshAssetCache]: the
/// same API, but it remembers what this world holds, so [LuminaWorld.cleanup]
/// releases this world's meshes — removing their entities from the world's
/// scene — and never another world's.
class LuminaWorldMeshCache {
  LuminaWorldMeshCache(this.shared, this._scene);

  /// The engine-wide cache.
  final LuminaMeshAssetCache shared;
  final FilamentScene _scene;
  final Map<FilamentAssetInstance, LuminaMeshHandle> _held = Map.identity();
  bool _closed = false;

  /// This world's live handles.
  int get handleCount => _held.length;

  bool get isClosed => _closed;

  Future<LuminaMeshHandle?> acquire(String meshAssetPath, {LuminaAssetProvider? assetProvider}) async {
    if (_closed) return null;
    final handle = await shared.acquire(meshAssetPath, assetProvider: assetProvider, cancelled: () => _closed);
    return _keep(handle);
  }

  Future<LuminaMeshHandle?> acquireBytes(Uint8List bytes, {required String sourcePath}) async {
    if (_closed) return null;
    final handle = await shared.acquireBytes(bytes, sourcePath: sourcePath, cancelled: () => _closed);
    return _keep(handle);
  }

  LuminaMeshHandle? _keep(LuminaMeshHandle? handle) {
    if (handle == null) return null;
    if (_closed) {
      handle.release();
      return null;
    }
    _held[handle.instance] = handle;
    return handle;
  }

  /// Acquires a new [FilamentAssetInstance]; null once the world is cleaned up.
  Future<FilamentAssetInstance?> acquireInstance(String meshAssetPath, {LuminaAssetProvider? assetProvider}) async {
    if (_closed) return null;
    return (await acquire(meshAssetPath, assetProvider: assetProvider))?.instance;
  }

  /// Releases an instance from [acquireInstance] / [acquire].
  void releaseInstance(String meshAssetPath, FilamentAssetInstance instance) {
    _held.remove(instance)?.release();
  }

  /// Releases everything this world still holds (its entities leave the
  /// world's scene first). Loads still in flight release when they land.
  void close() {
    if (_closed) return;
    _closed = true;
    // After the engine went (a test disposing it first) there is no scene
    // left to touch and the cache already destroyed everything.
    final engineAlive = !shared.isDisposed && !shared.engine.isDisposed;
    for (final handle in _held.values) {
      try {
        if (engineAlive && !_scene.isDisposed) _scene.removeEntities(handle.instance.entities);
      } catch (_) {}
      handle.release();
    }
    _held.clear();
  }
}
