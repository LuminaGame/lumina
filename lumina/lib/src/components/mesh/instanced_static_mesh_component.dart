import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' hide Frustum;
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/components/base/scene_component.dart';

/// Descriptor for a single level of detail (LOD) geometry mesh in an [LuminaInstancedStaticMeshComponent].
class LuminaStaticMeshLod {
  final FilamentVertexBuffer vb;
  final FilamentIndexBuffer ib;
  final int indexCount;
  final double switchDistance;

  LuminaStaticMeshLod({
    required this.vb,
    required this.ib,
    required this.indexCount,
    required this.switchDistance,
  });
}

/// Scene component rendering thousands of mesh copies in a single GPU instanced draw call with LOD support.
class LuminaInstancedStaticMeshComponent extends LuminaSceneComponent {
  final List<LuminaStaticMeshLod> lods;
  final FilamentMaterialInstance material;
  final int capacity;
  final double lodHysteresis;
  final void Function(int fromIndex, int toIndex)? onInstanceRelocated;

  /// Bounding box the renderable is built with when the component registers.
  ///
  /// Filament bakes a renderable's bounds at build time, so a batch that is
  /// registered before (or faster than) its instances arrive would otherwise
  /// be culled against a placeholder box. Callers that already know the volume
  /// their instances will occupy — a landscape's footprint, a streamed cell —
  /// pass it here; everyone else keeps the previous behaviour, which derives
  /// the box from the instances added before registration.
  final Aabb3? initialBounds;

  /// Shadow flags of the instanced renderable; the defaults are Filament's
  /// own (not a caster, a receiver). Foliage passes `castShadows: true`.
  final bool castShadows;
  final bool receiveShadows;

  final InstanceBuffer? _instanceBufferOverride;
  InstanceBuffer? _instanceBuffer;
  int _liveInstanceCount = 0;
  late final Float32List _stagingTransforms;
  final List<Matrix4> _instanceTransforms = [];

  int? _minDirty;
  int? _maxDirty;
  int _entity = 0;
  Aabb3 _combinedBounds = Aabb3();
  int _currentLodIndex = 0;

  LuminaInstancedStaticMeshComponent({
    required this.lods,
    required this.material,
    this.capacity = 128,
    this.lodHysteresis = 0.1,
    this.onInstanceRelocated,
    this.initialBounds,
    this.castShadows = false,
    this.receiveShadows = true,
    this._instanceBufferOverride,
    super.key,
    super.location,
    super.rotation,
    super.scale,
  }) {
    if (capacity < 1 || capacity > 32767) {
      throw ArgumentError('capacity ($capacity) must be between 1 and 32767');
    }
    if (lods.isEmpty) {
      throw ArgumentError('lods cannot be empty');
    }
    for (int i = 1; i < lods.length; i++) {
      if (lods[i].switchDistance <= lods[i - 1].switchDistance) {
        throw ArgumentError('LOD switchDistance must be strictly increasing');
      }
    }
    _stagingTransforms = Float32List(capacity * 16);
  }

  /// Number of live active instances.
  int get instanceCount => _liveInstanceCount;

  /// Combined axis-aligned bounding box encompassing all live instances.
  Aabb3 get combinedBounds => _combinedBounds;

  /// Active LOD index (0 is highest detail).
  int get currentLodIndex => _currentLodIndex;

  /// Native Filament entity handle for this instanced renderable.
  int get entity => _entity;

  /// Active GPU instance buffer.
  InstanceBuffer? get instanceBuffer => _instanceBufferOverride ?? _instanceBuffer;

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);

    final world = ownerActor.world;
    if (world != null && world.hasNativeContext) {
      final engine = world.filamentEngine;
      if (engine.maxAutomaticInstances > 0 && capacity > engine.maxAutomaticInstances) {
        throw ArgumentError(
          'capacity ($capacity) exceeds engine.maxAutomaticInstances (${engine.maxAutomaticInstances})',
        );
      }

      _instanceBuffer = _instanceBufferOverride ??
          InstanceBuffer.create(
            engine,
            instanceCount: capacity,
            localTransforms: _stagingTransforms,
          );

      _entity = EntityManager.get().create();
      final builder = RenderableBuilder(1);
      final lod0 = lods[0];
      builder.geometry(0, PrimitiveType.triangles, lod0.vb, ib: lod0.ib, count: lod0.indexCount);
      builder.instances(capacity, _instanceBuffer!);
      builder.material(0, material);
      builder.castShadows(castShadows);
      builder.receiveShadows(receiveShadows);
      final buildBounds = initialBounds ?? _combinedBounds;
      var minX = buildBounds.min.x;
      var minY = buildBounds.min.y;
      var minZ = buildBounds.min.z;
      var maxX = buildBounds.max.x;
      var maxY = buildBounds.max.y;
      var maxZ = buildBounds.max.z;
      if (!minX.isFinite || (minX == 0 && maxX == 0 && minY == 0 && maxY == 0 && minZ == 0 && maxZ == 0)) {
        minX = -1000.0; minY = -1000.0; minZ = -1000.0;
        maxX = 1000.0; maxY = 1000.0; maxZ = 1000.0;
      }
      builder.boundingBox(
        minX == maxX ? minX - 1.0 : minX,
        minY == maxY ? minY - 1.0 : minY,
        minZ == maxZ ? minZ - 1.0 : minZ,
        minX == maxX ? maxX + 1.0 : maxX,
        minY == maxY ? maxY + 1.0 : maxY,
        minZ == maxZ ? maxZ + 1.0 : maxZ,
      );
      builder.build(engine, _entity);

      final scene = world.filamentScene;
      scene.addEntity(_entity);
    }
  }

  @override
  void onUnregister() {
    final world = owner?.world;
    if (world != null && world.hasNativeContext && _entity != 0) {
      final scene = world.filamentScene;
      scene.removeEntity(_entity);

      final rm = FilamentRenderableManager(world.filamentEngine);
      if (rm.hasComponent(_entity)) {
        rm.destroy(_entity);
      }
      EntityManager.get().destroy(_entity);
      _entity = 0;
    }

    _instanceBuffer?.dispose();
    _instanceBuffer = null;
    super.onUnregister();
  }

  /// Adds a new instance transform, returning its instance index.
  int addInstance(Matrix4 transform) {
    if (_liveInstanceCount >= capacity) {
      throw StateError('Cannot add instance: capacity of $capacity reached');
    }

    final index = _liveInstanceCount++;
    _instanceTransforms.add(transform.clone());
    transform.copyIntoArray(_stagingTransforms, index * 16);

    _expandBoundsWithTranslation(transform.getTranslation());
    _markDirty(index);
    return index;
  }

  /// Updates the transform for instance at [index].
  void updateInstanceTransform(int index, Matrix4 transform) {
    if (index < 0 || index >= _liveInstanceCount) {
      throw RangeError.range(index, 0, _liveInstanceCount - 1, 'index');
    }

    _instanceTransforms[index].setFrom(transform);
    transform.copyIntoArray(_stagingTransforms, index * 16);

    _expandBoundsWithTranslation(transform.getTranslation());
    _markDirty(index);
  }

  /// Removes instance at [index] using swap-remove, zero-scaling the freed slot.
  bool removeInstance(int index) {
    if (index < 0 || index >= _liveInstanceCount) {
      throw RangeError.range(index, 0, _liveInstanceCount - 1, 'index');
    }

    final lastIdx = _liveInstanceCount - 1;
    if (index < lastIdx) {
      // Swap last instance into removed index
      final movedTransform = _instanceTransforms[lastIdx];
      _instanceTransforms[index] = movedTransform;
      for (int k = 0; k < 16; k++) {
        _stagingTransforms[index * 16 + k] = _stagingTransforms[lastIdx * 16 + k];
      }
      _markDirty(index);
      onInstanceRelocated?.call(lastIdx, index);

      // Zero-scale freed slot at lastIdx
      for (int k = 0; k < 16; k++) {
        _stagingTransforms[lastIdx * 16 + k] = 0.0;
      }
      _markDirty(lastIdx);
    } else {
      // Zero-scale removed last index
      for (int k = 0; k < 16; k++) {
        _stagingTransforms[index * 16 + k] = 0.0;
      }
      _markDirty(index);
    }

    _instanceTransforms.removeLast();
    _liveInstanceCount--;
    return true;
  }

  /// Returns the local transform matrix of instance [index].
  Matrix4 instanceTransform(int index, {Matrix4? out}) {
    if (index < 0 || index >= _liveInstanceCount) {
      throw RangeError.range(index, 0, _liveInstanceCount - 1, 'index');
    }
    final mat = _instanceTransforms[index];
    if (out != null) {
      out.setFrom(mat);
      return out;
    }
    return mat.clone();
  }

  /// Recalculates [combinedBounds] tightly over all active instance positions.
  void recalculateBounds() {
    if (_instanceTransforms.isEmpty) {
      _combinedBounds = Aabb3();
      return;
    }

    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;

    for (final mat in _instanceTransforms) {
      final t = mat.getTranslation();
      if (t.x < minX) minX = t.x;
      if (t.y < minY) minY = t.y;
      if (t.z < minZ) minZ = t.z;
      if (t.x > maxX) maxX = t.x;
      if (t.y > maxY) maxY = t.y;
      if (t.z > maxZ) maxZ = t.z;
    }

    _combinedBounds = Aabb3.minMax(
      Vector3(minX, minY, minZ),
      Vector3(maxX, maxY, maxZ),
    );
  }

  void _expandBoundsWithTranslation(Vector3 t) {
    if (_instanceTransforms.length == 1) {
      _combinedBounds = Aabb3.minMax(t.clone(), t.clone());
    } else {
      _combinedBounds.hullPoint(t);
    }
  }

  void _markDirty(int index) {
    _minDirty = (_minDirty == null) ? index : (_minDirty! < index ? _minDirty : index);
    _maxDirty = (_maxDirty == null) ? index : (_maxDirty! > index ? _maxDirty : index);
  }

  /// Flushes any pending local transform updates to the GPU instance buffer in a single batched upload.
  void flushTransformsToGpu() {
    if (_minDirty == null || _maxDirty == null) return;

    final targetBuffer = instanceBuffer;
    if (targetBuffer != null) {
      final count = _maxDirty! - _minDirty! + 1;
      final offset = _minDirty!;
      final slice = _stagingTransforms.sublist(offset * 16, (offset + count) * 16);
      targetBuffer.setLocalTransforms(slice, count: count, offset: offset);
    }

    _minDirty = null;
    _maxDirty = null;
  }

  /// Evaluates distance-based LOD switching and whole-batch frustum culling.
  void updateLodAndCulling(Vector3 cameraPosition, {Matrix4? projViewMatrix}) {
    final world = owner?.world;
    if (world == null || !world.hasNativeContext || _entity == 0) return;

    // 1. Frustum culling
    if (projViewMatrix != null) {
      final frustum = Frustum(projViewMatrix);
      final center = _combinedBounds.center;
      final extents = (_combinedBounds.max - _combinedBounds.min) * 0.5;
      final box = Box(
        center: center,
        halfExtent: extents,
      );

      final inView = frustum.intersects(box);
      final scene = world.filamentScene;
      if (!inView) {
        if (scene.hasEntity(_entity)) {
          scene.removeEntity(_entity);
        }
        return;
      } else {
        if (!scene.hasEntity(_entity)) {
          scene.addEntity(_entity);
        }
      }
    }

    // 2. Distance-based LOD selection with hysteresis
    if (lods.length > 1) {
      final dist = (cameraPosition - _combinedBounds.center).length;
      int targetLod = 0;
      for (int i = 0; i < lods.length; i++) {
        final threshold = lods[i].switchDistance;
        final effectiveThreshold = (i == _currentLodIndex)
            ? threshold * (1.0 + lodHysteresis)
            : threshold;
        if (dist > effectiveThreshold) {
          targetLod = (i + 1 < lods.length) ? i + 1 : i;
        } else {
          break;
        }
      }

      if (targetLod != _currentLodIndex) {
        _currentLodIndex = targetLod;
        final lod = lods[_currentLodIndex];
        final rm = FilamentRenderableManager(world.filamentEngine);
        rm.setGeometryAt(
          _entity,
          0,
          PrimitiveType.triangles,
          lod.vb,
          lod.ib,
          count: lod.indexCount,
        );
      }
    }

    // 3. Flush transforms
    flushTransformsToGpu();
  }
}
