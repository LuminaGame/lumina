import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart' as pkg_ffi;
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/exception.dart';
import 'package:flutter_filament/src/index_buffer.dart';
import 'package:flutter_filament/src/instance.dart';
import 'package:flutter_filament/src/material.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/vertex_buffer.dart';
import 'package:flutter_filament/src/skinning_buffer.dart';
import 'package:flutter_filament/src/math/box.dart';
import 'package:vector_math/vector_math_64.dart';

export 'package:flutter_filament/src/enums.dart' show PrimitiveType, GeometryType;
export 'package:flutter_filament/src/instance.dart' show RenderableInstance;

/// Helper for constructing Bone instances.
extension BoneExt on c.FilamentBone {
  /// Allocates a Bone from a Quaternion and translation Vector3 using the provided allocator.
  static ffi.Pointer<c.FilamentBone> allocate(ffi.Allocator allocator, Float32List quat, Float32List trans) {
    final ptr = allocator<c.FilamentBone>();
    ptr.ref.unit_quat[0] = quat[0];
    ptr.ref.unit_quat[1] = quat[1];
    ptr.ref.unit_quat[2] = quat[2];
    ptr.ref.unit_quat[3] = quat[3];
    ptr.ref.translation[0] = trans[0];
    ptr.ref.translation[1] = trans[1];
    ptr.ref.translation[2] = trans[2];
    ptr.ref.reserved = 0.0;
    return ptr;
  }
}

/// Pure Dart implementation of Filament's `RenderableManager::computeAABB`.
Aabb computeAabb({
  required Float32List positionsFloat3,
  TypedData? indices,
  int? count,
  int strideBytes = 12,
  int offsetBytes = 0,
}) {
  final actualCount = count ?? (indices != null ? indices.lengthInBytes ~/ (indices is Uint32List ? 4 : 2) : (positionsFloat3.lengthInBytes - offsetBytes) ~/ strideBytes);
  if (actualCount == 0) {
    return Aabb();
  }

  double minX = double.infinity;
  double minY = double.infinity;
  double minZ = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;
  double maxZ = -double.infinity;

  final byteData = ByteData.view(positionsFloat3.buffer, positionsFloat3.offsetInBytes, positionsFloat3.lengthInBytes);

  for (int i = 0; i < actualCount; i++) {
    int vertexIndex = i;
    if (indices is Uint16List) {
      vertexIndex = indices[i];
    } else if (indices is Uint32List) {
      vertexIndex = indices[i];
    } else if (indices != null) {
      throw ArgumentError('indices must be either Uint16List or Uint32List');
    }

    final byteOffset = offsetBytes + vertexIndex * strideBytes;
    if (byteOffset + 12 > byteData.lengthInBytes) {
      continue;
    }
    final x = byteData.getFloat32(byteOffset, Endian.host);
    final y = byteData.getFloat32(byteOffset + 4, Endian.host);
    final z = byteData.getFloat32(byteOffset + 8, Endian.host);

    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (z < minZ) minZ = z;

    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
    if (z > maxZ) maxZ = z;
  }

  return Aabb(min: Vector3(minX, minY, minZ), max: Vector3(maxX, maxY, maxZ));
}

/// Builder for creating multi-primitive renderables.
class RenderableBuilder {
  ffi.Pointer<ffi.Void> _builder;

  RenderableBuilder(int primitiveCount) : _builder = c.filament_renderable_builder_create(primitiveCount) {
    if (_builder == ffi.nullptr) {
      throw FilamentException('Failed to create RenderableManager::Builder');
    }
  }

  /// Sets the geometry for a given [index].
  void geometry(
    int index,
    PrimitiveType type,
    FilamentVertexBuffer vb, {
    FilamentIndexBuffer? ib,
    int? offset,
    int? count,
    ({int min, int max})? indexRange,
  }) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    
    if (ib != null) {
      if (indexRange != null) {
        c.filament_renderable_builder_geometry_min_max(
          _builder,
          index,
          type.rawValue,
          vb.nativePointer,
          ib.nativePointer,
          offset ?? 0,
          indexRange.min,
          indexRange.max,
          count ?? ib.indexCount,
        );
      } else if (offset != null || count != null) {
        c.filament_renderable_builder_geometry(
          _builder,
          index,
          type.rawValue,
          vb.nativePointer,
          ib.nativePointer,
          offset ?? 0,
          count ?? ib.indexCount,
        );
      } else {
        c.filament_renderable_builder_geometry_full(
          _builder,
          index,
          type.rawValue,
          vb.nativePointer,
          ib.nativePointer,
        );
      }
    } else {
      c.filament_renderable_builder_geometry_no_index(
        _builder,
        index,
        type.rawValue,
        vb.nativePointer,
      );
    }
  }

  /// Sets the optimization hint for this renderable's geometry.
  /// Note: With `GeometryType.static_`, Filament makes optimization assumptions.
  /// Binding a different buffer later is undefined.
  void geometryType(GeometryType type) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_geometry_type(_builder, type.value);
  }

  /// Assigns a [materialInstance] to the primitive at [index].
  void material(int index, FilamentMaterialInstance mi) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_material(_builder, index, mi.nativePointer);
  }

  /// Sets the axis-aligned bounding box. Mandatory if culling is enabled!
  void boundingBox(double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_bounding_box(_builder, minX, minY, minZ, maxX, maxY, maxZ);
  }

  void culling(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_culling(_builder, enabled);
  }

  void castShadows(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_cast_shadows(_builder, enabled);
  }

  void receiveShadows(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_receive_shadows(_builder, enabled);
  }

  void priority(int priority) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_priority(_builder, priority);
  }

  void layerMask(int select, int mask) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_layer_mask(_builder, select, mask);
  }

  /// Sets the render channel (0..7) this renderable is associated to.
  void channel(int channel) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    if (channel < 0 || channel > 7) throw RangeError.range(channel, 0, 7, 'channel');
    c.filament_renderable_builder_channel(_builder, channel);
  }

  /// Enables or disables a light channel (0..7).
  void lightChannel(int channel, bool enable) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    if (channel < 0 || channel > 7) throw RangeError.range(channel, 0, 7, 'channel');
    c.filament_renderable_builder_light_channel(_builder, channel, enable);
  }

  /// Sets drawing order for blended primitives (0..65535).
  void blendOrder(int primitiveIndex, int order) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    if (order < 0 || order > 65535) throw RangeError.range(order, 0, 65535, 'order');
    c.filament_renderable_builder_blend_order(_builder, primitiveIndex, order);
  }

  /// Sets whether the blend order is global or local (default) to this renderable.
  void globalBlendOrderEnabled(int primitiveIndex, bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_global_blend_order_enabled(_builder, primitiveIndex, enabled);
  }

  /// Enables or disables screen-space contact shadows.
  void screenSpaceContactShadows(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_screen_space_contact_shadows(_builder, enabled);
  }

  /// Enables or disables large-scale fog application to this renderable.
  void fog(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_fog(_builder, enabled);
  }

  /// Configures morphing for [targetCount] targets.
  void morphing(int targetCount) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_morphing(_builder, targetCount);
  }

  /// Associates a MorphTargetBuffer to this renderable.
  void morphingBuffer(dynamic morphTargetBuffer) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    ffi.Pointer<ffi.Void> ptr;
    if (morphTargetBuffer is ffi.Pointer<ffi.Void>) {
      ptr = morphTargetBuffer;
    } else if (morphTargetBuffer is ffi.Pointer) {
      ptr = morphTargetBuffer.cast<ffi.Void>();
    } else {
      try {
        ptr = (morphTargetBuffer as dynamic).nativePointer as ffi.Pointer<ffi.Void>;
      } catch (_) {
        ptr = (morphTargetBuffer as dynamic).nativePtr as ffi.Pointer<ffi.Void>;
      }
    }
    c.filament_renderable_builder_morphing_buffer(_builder, ptr);
  }

  /// Specifies the range of the MorphTargetBuffer to use with this primitive.
  void morphingOffsetAt(int primitiveIndex, int offset, {int level = 0}) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_morphing_offset_at(_builder, level, primitiveIndex, offset);
  }

  /// Specifies draw instance count (1..32767) optionally with an [instanceBuffer].
  void instances(int count, [dynamic instanceBuffer]) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    if (count < 1 || count > 32767) {
      throw RangeError.range(count, 1, 32767, 'count', 'Hardware instance count limit is 32767.');
    }
    if (instanceBuffer != null) {
      final bufCount = (instanceBuffer as dynamic).instanceCount as int?;
      if (bufCount != null && count > bufCount) {
        throw ArgumentError('count ($count) exceeds InstanceBuffer capacity ($bufCount).');
      }
      ffi.Pointer<ffi.Void> ptr;
      if (instanceBuffer is ffi.Pointer<ffi.Void>) {
        ptr = instanceBuffer;
      } else if (instanceBuffer is ffi.Pointer) {
        ptr = instanceBuffer.cast<ffi.Void>();
      } else {
        try {
          ptr = (instanceBuffer as dynamic).nativePointer as ffi.Pointer<ffi.Void>;
        } catch (_) {
          ptr = (instanceBuffer as dynamic).nativePtr as ffi.Pointer<ffi.Void>;
        }
      }
      c.filament_renderable_builder_instances_buffer(_builder, count, ptr);
    } else {
      c.filament_renderable_builder_instances(_builder, count);
    }
  }

  /// Configures skinning for [boneCount] bones.
  void skinning(int boneCount) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    assert(boneCount <= 256, 'Filament supports a maximum of 256 bones per region.');
    c.filament_renderable_builder_skinning(_builder, boneCount);
  }

  /// Enables advanced skinning buffers. Must be called if boneIndicesAndWeights is used.
  void enableSkinningBuffers(bool enabled) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_enable_skinning_buffers(_builder, enabled);
  }

  /// Configures the renderable to use a SkinningBuffer for bone transforms.
  void skinningBuffer(SkinningBuffer buffer, {required int count, int offset = 0}) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    c.filament_renderable_builder_skinning_buffer(_builder, buffer.nativePtr, count, offset);
  }

  /// Configures skinning with initial [bones].
  void skinningBones(int boneCount, {required List<ffi.Pointer<c.FilamentBone>> bones}) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    assert(boneCount <= 256, 'Filament supports a maximum of 256 bones per region.');
    assert(bones.length == boneCount, 'bones.length must match boneCount');
    
    pkg_ffi.using((pkg_ffi.Arena arena) {
      final bonesArray = arena<c.FilamentBone>(boneCount);
      for (var i = 0; i < boneCount; i++) {
        bonesArray[i] = bones[i].ref;
      }
      c.filament_renderable_builder_skinning_bones(_builder, boneCount, bonesArray);
    });
  }

  /// Configures skinning with initial [matrices].
  void skinningMatrices(int boneCount, {required Float32List matrices}) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    assert(boneCount <= 256, 'Filament supports a maximum of 256 bones per region.');
    assert(matrices.length >= boneCount * 16, 'matrices Float32List is too small for boneCount');

    pkg_ffi.using((pkg_ffi.Arena arena) {
      final matricesArray = arena<ffi.Float>(boneCount * 16);
      matricesArray.asTypedList(boneCount * 16).setAll(0, matrices.take(boneCount * 16));
      c.filament_renderable_builder_skinning_matrices(_builder, boneCount, matricesArray);
    });
  }

  /// Binds bone indices and weights directly from a flat float array.
  void boneIndicesAndWeights(int primitiveIndex, Float32List pairs, {required int bonesPerVertex}) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    
    pkg_ffi.using((pkg_ffi.Arena arena) {
      final pairsArray = arena<ffi.Float>(pairs.length);
      pairsArray.asTypedList(pairs.length).setAll(0, pairs);
      final pairsCount = pairs.length ~/ 2;
      c.filament_renderable_builder_bone_indices_and_weights(_builder, primitiveIndex, pairsArray, pairsCount, bonesPerVertex);
    });
  }

  /// Builds the renderable component onto [entity].
  ///
  /// Throws [FilamentException] if the build fails (e.g., missing geometry).
  void build(FilamentEngine engine, int entity) {
    if (_builder == ffi.nullptr) throw StateError('Builder already consumed or destroyed.');
    final result = c.filament_renderable_builder_build(_builder, engine.nativePointer, entity);
    _builder = ffi.nullptr; // consumed
    if (result != 0) {
      throw FilamentException('Failed to build renderable for entity $entity');
    }
  }

  /// Cancels the build and frees the underlying handle.
  void destroy() {
    if (_builder != ffi.nullptr) {
      c.filament_renderable_builder_destroy(_builder);
      _builder = ffi.nullptr;
    }
  }
}

/// Helper for constructing renderable components on entities.
typedef RenderableManager = FilamentRenderableManager;

class FilamentRenderableManager {
  final FilamentEngine engine;

  /// Creates a renderable manager wrapper.
  const FilamentRenderableManager(this.engine);

  /// Resolves an entity ID to its cached [RenderableInstance] handle.
  RenderableInstance getInstance(int entity) {
    final handle = c.filament_renderable_get_instance(
      engine.nativePointer,
      entity,
    );
    return RenderableInstance(handle);
  }

  /// Whether [entity] has a renderable component.
  bool hasComponent(int entity) {
    return c.filament_renderable_has_component(
      engine.nativePointer,
      entity,
    );
  }

  /// Number of renderable components managed by the engine.
  int get componentCount => c.filament_renderable_get_component_count(engine.nativePointer);

  /// All entities with a renderable component.
  List<int> get entities {
    final count = componentCount;
    if (count == 0) return const [];
    final ptr = pkg_ffi.calloc<ffi.Uint32>(count);
    try {
      c.filament_renderable_get_entities(engine.nativePointer, ptr, count);
      return List<int>.generate(count, (i) => ptr[i]);
    } finally {
      pkg_ffi.calloc.free(ptr);
    }
  }

  /// Makes [entity] renderable using the provided [vertexBuffer], [indexBuffer],
  /// and [materialInstance].
  void createRenderable({
    required int entity,
    required FilamentVertexBuffer vertexBuffer,
    required FilamentIndexBuffer indexBuffer,
    required FilamentMaterialInstance materialInstance,
    int offset = 0,
    required int count,
    PrimitiveType primitiveType = PrimitiveType.triangles,
  }) {
    RenderableBuilder(1)
      ..boundingBox(-1, -1, -1, 1, 1, 1)
      ..material(0, materialInstance)
      ..geometry(0, primitiveType, vertexBuffer, ib: indexBuffer, offset: offset, count: count)
      ..culling(false)
      ..receiveShadows(false)
      ..castShadows(false)
      ..build(engine, entity);
  }

  /// Gets the primitive count for the given [entity].
  int getPrimitiveCount(int entity) {
    return c.filament_renderable_get_primitive_count(engine.nativePointer, entity);
  }

  /// Dynamically updates the geometry for the primitive at [primitiveIndex] on [entity].
  /// This is useful for LOD swapping without rebuilding the renderable.
  void setGeometryAt(
    int entity,
    int primitiveIndex,
    PrimitiveType type,
    FilamentVertexBuffer vb,
    FilamentIndexBuffer? ib, {
    int offset = 0,
    required int count,
  }) {
    c.filament_renderable_set_geometry_at(
      engine.nativePointer,
      entity,
      primitiveIndex,
      type.rawValue,
      vb.nativePointer,
      ib?.nativePointer ?? ffi.nullptr,
      offset,
      count,
    );
  }

  /// Gets the [FilamentMaterialInstance] bound at [primitiveIndex] on [entity].
  /// Note: Returns a borrowed instance. You should not rely on it outliving the entity.
  FilamentMaterialInstance? getMaterialInstanceAt(int entity, int primitiveIndex) {
    final ptr = c.filament_renderable_get_material_instance_at(engine.nativePointer, entity, primitiveIndex);
    if (ptr == ffi.nullptr) return null;
    return FilamentMaterialInstance.internal(ptr, engine, null, true);
  }

  /// Clears the material instance bound at [primitiveIndex] on [entity], returning it to the default material.
  void clearMaterialInstanceAt(int entity, int primitiveIndex) {
    c.filament_renderable_clear_material_instance_at(engine.nativePointer, entity, primitiveIndex);
  }

  /// Creates the official 3D Suzanne Monkey Head mesh renderable.
  int createSuzanneMonkeyMesh(FilamentMaterialInstance materialInstance) {
    return c.filament_geometry_create_suzanne_monkey_mesh(
      engine.nativePointer,
      materialInstance.nativePointer,
    );
  }

  /// Sets the axis-aligned bounding box for [entity].
  void setBoundingBox({
    required int entity,
    required double minX,
    required double minY,
    required double minZ,
    required double maxX,
    required double maxY,
    required double maxZ,
  }) {
    c.filament_renderable_set_bounding_box(
      engine.nativePointer,
      entity,
      minX,
      minY,
      minZ,
      maxX,
      maxY,
      maxZ,
    );
  }

  /// Gets the axis-aligned bounding box for [entity].
  Box getAxisAlignedBoundingBox(int entity) {
    final ptr = pkg_ffi.calloc<ffi.Float>(6);
    try {
      c.filament_renderable_get_axis_aligned_bounding_box(engine.nativePointer, entity, ptr);
      return Box(
        center: Vector3(ptr[0], ptr[1], ptr[2]),
        halfExtent: Vector3(ptr[3], ptr[4], ptr[5]),
      );
    } finally {
      pkg_ffi.calloc.free(ptr);
    }
  }

  /// Sets the rendering priority of [entity] (0..7, where 7 renders first / behind).
  void setPriority(int entity, int priority) {
    c.filament_renderable_set_priority(engine.nativePointer, entity, priority);
  }

  /// Enables or disables frustum culling for [entity].
  void setCulling(int entity, bool enabled) {
    c.filament_renderable_set_culling(engine.nativePointer, entity, enabled);
  }

  /// Enables or disables shadow casting for [entity].
  void setCastShadows(int entity, bool enabled) {
    c.filament_renderable_set_cast_shadows(engine.nativePointer, entity, enabled);
  }

  /// Checks if [entity] casts shadows.
  bool isShadowCaster(int entity) => c.filament_renderable_is_shadow_caster(engine.nativePointer, entity);

  /// Enables or disables receiving shadows for [entity].
  void setReceiveShadows(int entity, bool enabled) {
    c.filament_renderable_set_receive_shadows(engine.nativePointer, entity, enabled);
  }

  /// Checks if [entity] receives shadows.
  bool isShadowReceiver(int entity) => c.filament_renderable_is_shadow_receiver(engine.nativePointer, entity);

  /// Sets the 8-bit layer mask for [entity].
  void setLayerMask(int entity, int select, int mask) {
    c.filament_renderable_set_layer_mask(engine.nativePointer, entity, select, mask);
  }

  /// Sets the render channel (0..7) of [entity].
  void setChannel(int entity, int channel) {
    if (channel < 0 || channel > 7) throw RangeError.range(channel, 0, 7, 'channel');
    c.filament_renderable_set_channel(engine.nativePointer, entity, channel);
  }

  /// Gets the render channel of [entity].
  int getChannel(int entity) {
    return c.filament_renderable_get_channel(engine.nativePointer, entity);
  }

  /// Sets the blend order for primitive at [primitiveIndex] on [entity].
  void setBlendOrderAt(int entity, int primitiveIndex, int order) {
    if (order < 0 || order > 65535) throw RangeError.range(order, 0, 65535, 'order');
    c.filament_renderable_set_blend_order_at(engine.nativePointer, entity, primitiveIndex, order);
  }

  /// Gets the blend order for primitive at [primitiveIndex] on [entity].
  int getBlendOrderAt(int entity, int primitiveIndex) {
    return c.filament_renderable_get_blend_order_at(engine.nativePointer, entity, primitiveIndex);
  }

  /// Sets whether the blend order is global or local for primitive at [primitiveIndex] on [entity].
  void setGlobalBlendOrderEnabledAt(int entity, int primitiveIndex, bool enabled) {
    c.filament_renderable_set_global_blend_order_enabled_at(engine.nativePointer, entity, primitiveIndex, enabled);
  }

  /// Gets whether the blend order is global for primitive at [primitiveIndex] on [entity].
  bool isGlobalBlendOrderEnabledAt(int entity, int primitiveIndex) {
    return c.filament_renderable_is_global_blend_order_enabled_at(engine.nativePointer, entity, primitiveIndex);
  }

  /// Enables or disables light channel [channel] (0..7) on [entity].
  void setLightChannel(int entity, int channel, bool enable) {
    if (channel < 0 || channel > 7) throw RangeError.range(channel, 0, 7, 'channel');
    c.filament_renderable_set_light_channel(engine.nativePointer, entity, channel, enable);
  }

  /// Gets whether light channel [channel] is enabled on [entity].
  bool getLightChannel(int entity, int channel) {
    if (channel < 0 || channel > 7) throw RangeError.range(channel, 0, 7, 'channel');
    return c.filament_renderable_get_light_channel(engine.nativePointer, entity, channel);
  }

  /// Enables or disables screen-space contact shadows on [entity].
  void setScreenSpaceContactShadows(int entity, bool enabled) {
    c.filament_renderable_set_screen_space_contact_shadows(engine.nativePointer, entity, enabled);
  }

  /// Checks if screen-space contact shadows are enabled on [entity].
  bool isScreenSpaceContactShadowsEnabled(int entity) {
    return c.filament_renderable_is_screen_space_contact_shadows_enabled(engine.nativePointer, entity);
  }

  /// Enables or disables large-scale fog on [entity].
  void setFogEnabled(int entity, bool enabled) {
    c.filament_renderable_set_fog_enabled(engine.nativePointer, entity, enabled);
  }

  /// Gets whether large-scale fog is enabled on [entity].
  bool getFogEnabled(int entity) {
    return c.filament_renderable_get_fog_enabled(engine.nativePointer, entity);
  }

  /// Gets the set of enabled VertexAttributes at [primitiveIndex] for [entity].
  Set<VertexAttribute> getEnabledAttributesAt(int entity, int primitiveIndex) {
    final mask = c.filament_renderable_get_enabled_attributes_at(engine.nativePointer, entity, primitiveIndex);
    final set = <VertexAttribute>{};
    for (final attr in VertexAttribute.values) {
      if ((mask & (1 << attr.value)) != 0) {
        set.add(attr);
      }
    }
    return set;
  }

  /// Updates vertex morphing weights on [entity].
  void setMorphWeights(int entity, Float32List weights, {int offset = 0}) {
    final targetCount = getMorphTargetCount(entity);
    if (targetCount > 0 && offset + weights.length > targetCount) {
      throw RangeError('offset + weights.length (${offset + weights.length}) exceeds morphTargetCount ($targetCount).');
    }
    final ptr = pkg_ffi.calloc<ffi.Float>(weights.length);
    try {
      ptr.asTypedList(weights.length).setAll(0, weights);
      c.filament_renderable_set_morph_weights(engine.nativePointer, entity, ptr, weights.length, offset);
    } finally {
      pkg_ffi.calloc.free(ptr);
    }
  }

  /// Associates a MorphTargetBuffer region to the given primitive.
  void setMorphTargetBufferOffsetAt(int entity, int primitiveIndex, int offset, {int level = 0}) {
    c.filament_renderable_set_morph_target_buffer_offset_at(engine.nativePointer, entity, level, primitiveIndex, offset);
  }

  /// Gets the number of morph targets for [entity].
  int getMorphTargetCount(int entity) {
    return c.filament_renderable_get_morph_target_count(engine.nativePointer, entity);
  }

  /// Gets the number of draw instances for [entity].
  int getInstanceCount(int entity) {
    return c.filament_renderable_get_instance_count(engine.nativePointer, entity);
  }

  /// Binds a [materialInstance] to the primitive index of [entity].
  void setMaterialInstanceAt(int entity, int primitiveIndex, FilamentMaterialInstance materialInstance) {
    c.filament_renderable_set_material_instance_at(
      engine.nativePointer,
      entity,
      primitiveIndex,
      materialInstance.nativePointer,
    );
  }

  /// Updates bones at runtime using [bones].
  void setBones(int entity, List<ffi.Pointer<c.FilamentBone>> bones, {int offset = 0}) {
    pkg_ffi.using((pkg_ffi.Arena arena) {
      final bonesArray = arena<c.FilamentBone>(bones.length);
      for (var i = 0; i < bones.length; i++) {
        bonesArray[i] = bones[i].ref;
      }
      c.filament_renderable_set_bones(
        engine.nativePointer,
        entity,
        bonesArray,
        bones.length,
        offset,
      );
    });
  }

  /// Updates bones at runtime using column-major [matrices].
  void setBonesMatrices(int entity, Float32List matrices, {int offset = 0, int? count}) {
    final actualCount = count ?? (matrices.length ~/ 16);
    assert(matrices.length >= actualCount * 16, 'matrices Float32List is too small for count');

    pkg_ffi.using((pkg_ffi.Arena arena) {
      final matricesArray = arena<ffi.Float>(actualCount * 16);
      matricesArray.asTypedList(actualCount * 16).setAll(0, matrices.take(actualCount * 16));
      c.filament_renderable_set_bones_matrices(
        engine.nativePointer,
        entity,
        matricesArray,
        actualCount,
        offset,
      );
    });
  }

  /// Sets the SkinningBuffer to be used for this entity.
  void setSkinningBuffer(int entity, SkinningBuffer buffer, {required int count, int offset = 0}) {
    c.filament_renderable_set_skinning_buffer(
      engine.nativePointer,
      entity,
      buffer.nativePtr,
      count,
      offset,
    );
  }

  /// Destroys the renderable component of [entity].
  void destroy(int entity) {
    c.filament_renderable_destroy(engine.nativePointer, entity);
  }
}

