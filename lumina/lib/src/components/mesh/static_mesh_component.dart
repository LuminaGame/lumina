import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/material/lumina_material.dart';
import 'package:lumina/src/material/lumina_material_instance.dart';
import 'package:lumina/src/material/dynamic_material_instance.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/physics/primitive_physics.dart';

/// Scene component rendering a static (non-skinned) 3D mesh via Filament and gltfio.
///
/// With Simulate Physics on ([LuminaPrimitivePhysics]) it is a
/// rigid body made of the collision components under it (a box around its
/// bounds when it has none).
class LuminaStaticMeshComponent extends LuminaSceneComponent with LuminaPrimitivePhysics {
  final String meshAssetPath;
  final Future<Uint8List> Function(String path)? assetProvider;

  /// Asset units → world units, applied below the component's own transform.
  /// glTF is metres by specification and the world is
  /// centimetres, so an imported asset draws ×[LuminaUnits.unitsPerMetre];
  /// geometry generated in world units (primitives) passes 1.
  final double assetUnitScale;

  bool _castShadows;
  bool _receiveShadows;
  bool _visible;

  FilamentAssetInstance? _instance;
  final Completer<void> _loadCompleter = Completer<void>();
  Matrix4? _lastSyncedTransform;
  Aabb3? _localBounds;

  LuminaStaticMeshComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required this.meshAssetPath,
    bool castShadows = true,
    bool receiveShadows = true,
    bool visible = true,
    this.assetProvider,
    this.assetUnitScale = LuminaUnits.unitsPerMetre,
    this.materialOverrideAsset,
  })  : _castShadows = castShadows, // ignore: prefer_initializing_formals
        _receiveShadows = receiveShadows, // ignore: prefer_initializing_formals
        _visible = visible,
        super(isVisible: visible);

  /// A material asset (a material `.lmas` or `.filamat`) drawn on every
  /// section in place of the mesh's own materials; null keeps them — or the
  /// materials the mesh asset's slots name (see [drawsSlotMaterials]).
  final String? materialOverrideAsset;

  /// Whether the materials assigned to the mesh asset's slots (the
  /// `element_<n>` / `material_slot_<n>` references of its `.lmas`) are drawn
  /// on its sections. Only a slot material with a compiled package is: an
  /// import's source-only material describes what the mesh already draws.
  @protected
  bool get drawsSlotMaterials => true;

  /// The transform the asset's root is drawn with: the component's world
  /// transform, then the asset → world unit scale.
  Matrix4 get renderTransform => assetUnitScale == 1.0
      ? worldTransform
      : (worldTransform..multiply(Matrix4.diagonal3Values(assetUnitScale, assetUnitScale, assetUnitScale)));

  /// Whether the glTF/GLB asset has completed loading and is active in the scene.
  bool get isLoaded => _instance != null;

  /// Future completing when the mesh asset finishes asynchronous loading and scene attachment.
  Future<void> get loaded => _loadCompleter.future;

  /// The gltfio instance this component draws, once loaded. Each component
  /// owns its own instance (and so its own animator), even when several share
  /// one cached asset.
  FilamentAssetInstance? get assetInstance => _instance;

  /// Called once the loaded instance is in the scene, before [loaded]
  /// completes. Subclasses that drive the instance (animation, morphs) hook in
  /// here; call `super`.
  @protected
  @mustCallSuper
  void onAssetLoaded(FilamentAssetInstance instance) {}

  /// Root Filament entity of the loaded mesh hierarchy.
  int? get rootEntity => _instance?.root;

  /// All Filament entities belonging to the loaded mesh hierarchy (including root transform entity).
  List<int> get entities {
    final list = <int>[];
    if (rootEntity != null && rootEntity != 0) {
      list.add(rootEntity!);
    }
    if (_instance != null) {
      for (final e in _instance!.entities) {
        if (!list.contains(e)) {
          list.add(e);
        }
      }
    }
    return list;
  }

  /// Local bounding box of the loaded mesh.
  Aabb3? get localBounds => _localBounds;

  bool get castShadows => _castShadows;
  set castShadows(bool value) {
    _castShadows = value;
    _updateShadowFlags();
  }

  bool get receiveShadows => _receiveShadows;
  set receiveShadows(bool value) {
    _receiveShadows = value;
    _updateShadowFlags();
  }

  /// Whether the mesh is drawn: the same switch as [isVisible] (an actor's
  /// `hiddenInGame`, a Blueprint's Set Visibility), kept in step both ways.
  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    if (isVisible != value) isVisible = value;
    _updateVisibility();
  }

  @override
  void onVisibilityChanged(bool visible) => this.visible = visible;

  void _updateShadowFlags() {
    final w = owner?.world;
    if (w == null || _instance == null || !w.hasNativeContext) return;
    final rm = FilamentRenderableManager(w.filamentEngine);
    for (final entity in entities) {
      if (rm.hasComponent(entity)) {
        rm.setCastShadows(entity, _castShadows);
        rm.setReceiveShadows(entity, _receiveShadows);
      }
    }
  }

  void _updateVisibility() {
    final w = owner?.world;
    if (w == null || _instance == null || !w.hasNativeContext) return;
    final scene = w.filamentScene;
    if (_visible) {
      for (final entity in entities) {
        if (!scene.hasEntity(entity)) {
          scene.addEntity(entity);
        }
      }
    } else {
      for (final entity in entities) {
        if (scene.hasEntity(entity)) {
          scene.removeEntity(entity);
        }
      }
    }
  }

  final Map<int, LuminaMaterialInstance> _materialOverrides = {};
  final Map<int, LuminaDynamicMaterialInstance> _dynamicMaterialInstances = {};

  /// Every override set, by section, drawn once the mesh has loaded.
  final Map<int, FilamentMaterialInstance> _nativeOverrides = {};

  /// The latest material asset load per section: a load only applies while it
  /// is still the latest request for its section.
  final Map<int, Object> _materialRequests = {};

  /// The material asset load of each section still in flight.
  final Map<int, Future<void>> _materialLoads = {};

  /// What an overridden section drew before (the mesh's own material), put
  /// back when the override is cleared or the component leaves the world.
  final Map<int, FilamentMaterialInstance> _ownMaterials = {};

  /// What [setMaterialAsset] loaded per section: the cached material (one
  /// reference held) and the instance made of it, let go of when the
  /// section's override is replaced or cleared, or the component leaves the
  /// world, so the cache destroys the material with its last user.
  final Map<int, (LuminaMaterial, LuminaMaterialInstance)> _assetMaterials = {};

  void _releaseAssetMaterial(int primitiveIndex) {
    final held = _assetMaterials.remove(primitiveIndex);
    if (held == null) return;
    final (material, instance) = held;
    if (!instance.isDisposed && !material.isDisposed) instance.dispose();
    material.release();
  }

  /// Sets a material override for section [primitiveIndex]: the mesh's
  /// renderables in entity order, each one's primitives in order (a
  /// single-mesh asset's primitives). Set before the mesh has loaded, it is
  /// drawn once it does.
  void setMaterialOverride(dynamic mi, {int primitiveIndex = 0}) {
    _materialRequests.remove(primitiveIndex);
    _setOverride(mi, primitiveIndex);
    if (!identical(_assetMaterials[primitiveIndex]?.$2, mi)) _releaseAssetMaterial(primitiveIndex);
  }

  void _setOverride(dynamic mi, int primitiveIndex) {
    final FilamentMaterialInstance nativeMi;
    if (mi is LuminaMaterialInstance) {
      _materialOverrides[primitiveIndex] = mi;
      nativeMi = mi.nativeInstance;
    } else if (mi is FilamentMaterialInstance) {
      nativeMi = mi;
    } else {
      throw ArgumentError('Expected LuminaMaterialInstance or FilamentMaterialInstance');
    }
    _nativeOverrides[primitiveIndex] = nativeMi;

    final w = owner?.world;
    if (w == null || _instance == null || !w.hasNativeContext) return;
    final rm = FilamentRenderableManager(w.filamentEngine);
    final section = _section(rm, primitiveIndex);
    if (section == null) return;
    if (!_ownMaterials.containsKey(primitiveIndex)) {
      final own = rm.getMaterialInstanceAt(section.$1, section.$2);
      if (own != null) _ownMaterials[primitiveIndex] = own;
    }
    rm.setMaterialInstanceAt(section.$1, section.$2, nativeMi);
  }

  /// Draws section [primitiveIndex] with its own material again.
  void _restoreOwnMaterial(FilamentRenderableManager rm, int primitiveIndex) {
    final own = _ownMaterials.remove(primitiveIndex);
    final section = _section(rm, primitiveIndex);
    if (section == null) return;
    if (own != null) {
      rm.setMaterialInstanceAt(section.$1, section.$2, own);
    } else {
      rm.clearMaterialInstanceAt(section.$1, section.$2);
    }
  }

  /// Draws the material asset at [path] (a material `.lmas` saved by the
  /// Material Editor, or a `.filamat`) on section [primitiveIndex], loaded
  /// through the world's material cache. A later assignment to the same
  /// section wins over a load still in flight. Throws when the component is
  /// not in a world that renders, or the asset holds no compiled material.
  Future<void> setMaterialAsset(String path, {int primitiveIndex = 0}) {
    final load = _loadMaterialAsset(path, primitiveIndex);
    _materialLoads[primitiveIndex] = load;
    void settled() {
      if (identical(_materialLoads[primitiveIndex], load)) _materialLoads.remove(primitiveIndex);
    }

    load.then((_) => settled(), onError: (Object _) => settled());
    return load;
  }

  Future<void> _loadMaterialAsset(String path, int primitiveIndex) async {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) {
      throw StateError('Cannot load material $path: the mesh is not in a rendering world');
    }
    final request = _materialRequests[primitiveIndex] = Object();
    final material = await w.materialCache.load(w, path, assetProvider: assetProvider);
    if (!identical(_materialRequests[primitiveIndex], request) || owner == null) {
      material.release();
      return;
    }
    _materialRequests.remove(primitiveIndex);
    final instance = material.createInstance();
    _setOverride(instance, primitiveIndex);
    _releaseAssetMaterial(primitiveIndex);
    _assetMaterials[primitiveIndex] = (material, instance);
  }

  /// Draws [materialOverrideAsset] on every section, else the [slots]
  /// materials — on each section nothing was assigned to meanwhile.
  void _applyMaterialAssets(LuminaWorld w, Map<int, String> slots) {
    final override = materialOverrideAsset ?? '';
    if (override.isEmpty && slots.isEmpty) return;
    final rm = FilamentRenderableManager(w.filamentEngine);
    var sections = 0;
    for (final entity in entities) {
      if (rm.hasComponent(entity)) sections += rm.getPrimitiveCount(entity);
    }
    for (var i = 0; i < sections; i++) {
      if (_nativeOverrides.containsKey(i) || _materialRequests.containsKey(i)) continue;
      final path = override.isNotEmpty ? override : slots[i];
      if (path == null) continue;
      unawaited(setMaterialAsset(path, primitiveIndex: i).catchError((Object e) {
        developer.log('Cannot draw material $path on $meshAssetPath: $e', name: 'StaticMesh', level: 900);
      }));
    }
  }

  /// Slot materials by mesh `.lmas`, read once per world.
  static final Expando<Map<String, Future<Map<int, String>>>> _slotCache = Expando();

  /// The materials with a compiled package that the mesh asset's slots name,
  /// by section; empty when the mesh is not an imported asset, draws
  /// [materialOverrideAsset] or does not draw slot materials.
  Future<Map<int, String>> _slotMaterials(LuminaWorld w) {
    if ((materialOverrideAsset ?? '').isNotEmpty || !drawsSlotMaterials) return Future.value(const {});
    final path = meshAssetPath;
    final lower = path.toLowerCase();
    final String lmas;
    if (lower.endsWith('.entity.glb')) {
      lmas = '${path.substring(0, path.length - '.entity.glb'.length)}.lmas';
    } else if (lower.endsWith('.lmas')) {
      lmas = path;
    } else {
      return Future.value(const {});
    }
    final cache = _slotCache[w] ??= {};
    return cache[lmas] ??= _readSlotMaterials(lmas);
  }

  Future<Map<int, String>> _readSlotMaterials(String lmas) async {
    final read = LuminaAssets.resolve(assetProvider);
    final LuminaAssetSummary mesh;
    try {
      // The references only: the mesh payload is not decoded again.
      mesh = LuminaAssetSummary.fromBytes(await read(lmas));
    } catch (_) {
      return const {};
    }
    // The Static Mesh editor's `element_<n>` wins over the import's
    // `material_slot_<n>`.
    final named = <int, String>{};
    for (final prefix in const ['material_slot_', 'element_']) {
      for (final r in mesh.references) {
        if (!r.slotName.startsWith(prefix) || r.assetPath.isEmpty) continue;
        final index = int.tryParse(r.slotName.substring(prefix.length));
        if (index != null) named[index] = _storedAssetPath(r.assetPath);
      }
    }
    final out = <int, String>{};
    final compiled = <String, Future<bool>>{};
    for (final e in named.entries) {
      final ok = await (compiled[e.value] ??= () async {
        try {
          final payload = LuminaAsset.fromBytes(await read(e.value)).rawPayload;
          return payload != null && payload.isNotEmpty;
        } catch (_) {
          return false;
        }
      }());
      if (ok) out[e.key] = e.value;
    }
    return out;
  }

  /// [stored] as this mesh reads it: `/`-separated, and a project asset's
  /// absolute path (what the Static Mesh editor stores) cut to `contents/…`
  /// when a provider — a built game's bundle — serves the assets.
  String _storedAssetPath(String stored) {
    final p = stored.replaceAll(r'\', '/');
    if ((assetProvider ?? LuminaAssets.defaultProvider) == null) return p;
    final i = p.indexOf('/contents/');
    return i < 0 ? p : p.substring(i + 1);
  }

  /// The renderable entity and primitive that draw section [index].
  (int, int)? _section(FilamentRenderableManager rm, int index) {
    var first = 0;
    for (final entity in entities) {
      if (!rm.hasComponent(entity)) continue;
      final count = rm.getPrimitiveCount(entity);
      if (index < first + count) return (entity, index - first);
      first += count;
    }
    return null;
  }

  /// Creates (or returns existing) dynamic material instance for [primitiveIndex].
  LuminaDynamicMaterialInstance createDynamicMaterialInstance({
    int primitiveIndex = 0,
    String? name,
  }) {
    final existing = _dynamicMaterialInstances[primitiveIndex];
    if (existing != null && !existing.isDisposed) {
      return existing;
    }

    final currentOverride = _materialOverrides[primitiveIndex];
    if (currentOverride == null) {
      throw StateError('Cannot create dynamic material instance: primitive $primitiveIndex has no material override assigned');
    }

    final dynamicInst = LuminaDynamicMaterialInstance.from(
      currentOverride,
      name: name ?? '${currentOverride.name}_dyn_p$primitiveIndex',
    );
    _dynamicMaterialInstances[primitiveIndex] = dynamicInst;
    setMaterialOverride(dynamicInst, primitiveIndex: primitiveIndex);
    return dynamicInst;
  }

  /// Whether section [primitiveIndex] has no material override yet but may
  /// get one from a material asset still loading: the mesh (and with it
  /// [materialOverrideAsset] or its slot materials) has not loaded, or a
  /// [setMaterialAsset] load is in flight. A Blueprint's BeginPlay runs
  /// while they load.
  bool isMaterialLoading([int primitiveIndex = 0]) {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext || _materialOverrides.containsKey(primitiveIndex)) return false;
    return !_loadCompleter.isCompleted || _materialLoads.containsKey(primitiveIndex);
  }

  /// The override section [primitiveIndex] draws once the mesh and the
  /// material assets it draws have loaded (null when it gets none, or the
  /// mesh failed to load).
  Future<LuminaMaterialInstance?> materialOverrideWhenLoaded([int primitiveIndex = 0]) async {
    try {
      await loaded;
    } catch (_) {
      return null;
    }
    while (true) {
      final pending = _materialLoads[primitiveIndex];
      if (pending == null) break;
      try {
        await pending;
      } catch (_) {}
    }
    return _materialOverrides[primitiveIndex];
  }

  /// The material override at [primitiveIndex], if any.
  LuminaMaterialInstance? materialOverride([int primitiveIndex = 0]) => _materialOverrides[primitiveIndex];

  /// The dynamic instance made for [primitiveIndex], if any.
  LuminaDynamicMaterialInstance? dynamicMaterialInstance([int primitiveIndex = 0]) => _dynamicMaterialInstances[primitiveIndex];

  /// Clears the material override of section [primitiveIndex].
  void clearMaterialOverride({int primitiveIndex = 0}) {
    _materialOverrides.remove(primitiveIndex);
    _nativeOverrides.remove(primitiveIndex);
    _materialRequests.remove(primitiveIndex);
    _materialLoads.remove(primitiveIndex);
    final w = owner?.world;
    if (w != null && _instance != null && w.hasNativeContext) {
      _restoreOwnMaterial(FilamentRenderableManager(w.filamentEngine), primitiveIndex);
    }
    _dynamicMaterialInstances.remove(primitiveIndex)?.dispose();
    _releaseAssetMaterial(primitiveIndex);
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _loadMeshAsset();
  }

  Future<void> _loadMeshAsset() async {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) {
      return;
    }
    if (_instance != null) {
      return;
    }

    try {
      final cache = w.meshAssetCache;
      final instance = await cache.acquireInstance(
        meshAssetPath,
        assetProvider: assetProvider,
      );

      if (instance == null) {
        if (w.isCleanedUp) {
          // World torn down mid-load (editor tab closed, test teardown): not an error.
          if (!_loadCompleter.isCompleted) _loadCompleter.complete();
          return;
        }
        throw Exception('Could not acquire mesh instance for $meshAssetPath');
      }

      _instance = instance;

      // Add entities to scene if visible
      if (_visible) {
        final scene = w.filamentScene;
        for (final entity in entities) {
          if (!scene.hasEntity(entity)) {
            scene.addEntity(entity);
          }
        }
      }

      // Apply initial shadow flags
      _updateShadowFlags();

      // Compute local bounds
      // The instance's bounding box covers the whole hierarchy (a glTF root is
      // usually a transform node, not a renderable), in asset units; express
      // it in the component's own (world-unit) space.
      final u = assetUnitScale;
      final box = instance.boundingBox;
      final valid = box.min.x <= box.max.x && box.min.y <= box.max.y && box.min.z <= box.max.z;
      _localBounds = valid
          ? Aabb3.minMax(Vector3.copy(box.min)..scale(u), Vector3.copy(box.max)..scale(u))
          : Aabb3.minMax(Vector3.all(-u), Vector3.all(u));

      // Initial transform sync
      if (rootEntity != null) {
        final tm = FilamentTransformManager(w.filamentEngine);
        final mtx = renderTransform;
        tm.setTransform(rootEntity!, mtx.storage.toList());
        _lastSyncedTransform = Matrix4.copy(mtx);
      }

      // Overrides set while the mesh was loading.
      for (final e in _nativeOverrides.entries.toList()) {
        _setOverride(e.value, e.key);
      }

      onAssetLoaded(instance);
      // The mesh asset's slot materials: its `.lmas` is read after the mesh.
      _applyMaterialAssets(w, await _slotMaterials(w));

      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    } catch (e, st) {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.completeError(e, st);
      }
    }
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    if (_instance == null || rootEntity == null || !world.hasNativeContext) return;

    final currentMtx = renderTransform;
    if (_lastSyncedTransform != null && _isMatrixEqual(_lastSyncedTransform!, currentMtx)) {
      return;
    }

    final tm = FilamentTransformManager(world.filamentEngine);
    tm.setTransform(rootEntity!, currentMtx.storage.toList());
    _lastSyncedTransform = Matrix4.copy(currentMtx);
  }

  bool _isMatrixEqual(Matrix4 a, Matrix4 b) {
    for (int i = 0; i < 16; i++) {
      if ((a.storage[i] - b.storage[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  @override
  void onUnregister() {
    final world = owner?.world;
    if (world != null && _instance != null && world.hasNativeContext) {
      // The mesh's own materials go back before overrides can be destroyed.
      final rm = FilamentRenderableManager(world.filamentEngine);
      for (final index in _ownMaterials.keys.toList()) {
        _restoreOwnMaterial(rm, index);
      }
    }
    _ownMaterials.clear();
    for (final d in _dynamicMaterialInstances.values) {
      d.dispose();
    }
    _dynamicMaterialInstances.clear();
    for (final index in _assetMaterials.keys.toList()) {
      _releaseAssetMaterial(index);
    }
    _materialOverrides.clear();
    _nativeOverrides.clear();
    _materialRequests.clear();
    _materialLoads.clear();

    final w = owner?.world;
    if (w != null && _instance != null && w.hasNativeContext) {
      final scene = w.filamentScene;
      for (final entity in entities) {
        if (scene.hasEntity(entity)) {
          scene.removeEntity(entity);
        }
      }
      w.meshAssetCache.releaseInstance(meshAssetPath, _instance!);
      _instance = null;
    }
    super.onUnregister();
  }
}
