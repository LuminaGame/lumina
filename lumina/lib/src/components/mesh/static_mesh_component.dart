import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../material/lumina_material_instance.dart';
import '../../material/dynamic_material_instance.dart';
import '../../object/actor.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';
import '../../math/units.dart';
import '../../physics/primitive_physics.dart';

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
    this._castShadows = true,
    this._receiveShadows = true,
    this._visible = true,
    this.assetProvider,
    this.assetUnitScale = LuminaUnits.unitsPerMetre,
  });

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

  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _updateVisibility();
  }

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

  /// Sets a material override for the root renderable entity at [primitiveIndex].
  void setMaterialOverride(dynamic mi, {int primitiveIndex = 0}) {
    final FilamentMaterialInstance nativeMi;
    if (mi is LuminaMaterialInstance) {
      _materialOverrides[primitiveIndex] = mi;
      nativeMi = mi.nativeInstance;
    } else if (mi is FilamentMaterialInstance) {
      nativeMi = mi;
    } else {
      throw ArgumentError('Expected LuminaMaterialInstance or FilamentMaterialInstance');
    }

    final w = owner?.world;
    if (w == null || _instance == null || !w.hasNativeContext) return;
    final rm = FilamentRenderableManager(w.filamentEngine);
    if (rootEntity != null && rm.hasComponent(rootEntity!)) {
      rm.setMaterialInstanceAt(rootEntity!, primitiveIndex, nativeMi);
    }
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

  /// The material override at [primitiveIndex], if any.
  LuminaMaterialInstance? materialOverride([int primitiveIndex = 0]) => _materialOverrides[primitiveIndex];

  /// The dynamic instance made for [primitiveIndex], if any.
  LuminaDynamicMaterialInstance? dynamicMaterialInstance([int primitiveIndex = 0]) => _dynamicMaterialInstances[primitiveIndex];

  /// Clears material override for the root renderable entity at [primitiveIndex].
  void clearMaterialOverride({int primitiveIndex = 0}) {
    _materialOverrides.remove(primitiveIndex);
    _dynamicMaterialInstances.remove(primitiveIndex)?.dispose();
    final w = owner?.world;
    if (w == null || _instance == null || !w.hasNativeContext) return;
    final rm = FilamentRenderableManager(w.filamentEngine);
    if (rootEntity != null && rm.hasComponent(rootEntity!)) {
      rm.clearMaterialInstanceAt(rootEntity!, primitiveIndex);
    }
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

      onAssetLoaded(instance);

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
    for (final d in _dynamicMaterialInstances.values) {
      d.dispose();
    }
    _dynamicMaterialInstances.clear();
    _materialOverrides.clear();

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
