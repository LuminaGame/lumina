part of '../gltf_loader.dart';

/// Controls glTF animation playbacks and skeletal bone matrices.
class FilamentAnimator {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentAnimator._(this._ptr);

  /// Applies rotation, translation, and scale to entities for animation [animationIndex] at [timeSeconds].
  void applyAnimation(int animationIndex, double timeSeconds) {
    c.filament_gltfio_animator_apply_animation(
      _ptr,
      animationIndex,
      timeSeconds,
    );
  }

  /// Applies a cross-fade transition from a previous animation to the current animation.
  /// 
  /// You must call [applyAnimation] with the *next* clip first, and then call [applyCrossFade].
  /// The [alpha] controls the blend between the previous clip (0.0) and the new clip (1.0).
  void applyCrossFade(int previousAnimIndex, double previousAnimTime, double alpha) {
    if (previousAnimIndex < 0 || previousAnimIndex >= animationCount) {
      throw RangeError.range(previousAnimIndex, 0, animationCount - 1, 'previousAnimIndex');
    }
    c.filament_gltfio_animator_apply_cross_fade(
      _ptr,
      previousAnimIndex,
      previousAnimTime,
      alpha,
    );
  }

  /// Updates bone matrices for skinned models.
  void updateBoneMatrices() {
    c.filament_gltfio_animator_update_bone_matrices(_ptr);
  }

  /// Resets the bone matrices to their rest pose.
  void resetBoneMatrices() {
    c.filament_gltfio_animator_reset_bone_matrices(_ptr);
  }

  /// Returns the number of animations in the asset.
  int get animationCount =>
      c.filament_gltfio_animator_get_animation_count(_ptr);

  /// Returns the duration of animation at [animationIndex] in seconds.
  double getAnimationDuration(int animationIndex) =>
      c.filament_gltfio_animator_get_animation_duration(_ptr, animationIndex);

  /// Returns the string name of animation at [animationIndex].
  String getAnimationName(int animationIndex) {
    final ptr = c.filament_gltfio_animator_get_animation_name(
      _ptr,
      animationIndex,
    );
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }
}



/// A specific instance of a [FilamentAsset].
class FilamentAssetInstance {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentAsset _asset;

  FilamentAssetInstance._(this._ptr, this._asset);

  FilamentAsset getAsset() => _asset;

  int get root => c.filament_gltfio_instance_get_root(_ptr);

  int get entityCount => c.filament_gltfio_instance_get_entity_count(_ptr);

  List<int> get entities {
    final count = entityCount;
    if (count == 0) return [];
    final ptr = c.filament_gltfio_instance_get_entities(_ptr);
    return ptr.asTypedList(count).toList();
  }

  FilamentAnimator get animator {
    final animPtr = c.filament_gltfio_instance_get_animator(_ptr);
    return FilamentAnimator._(animPtr);
  }

  int get skinCount => c.filament_gltfio_instance_get_skin_count(_ptr);

  String? skinNameAt(int skinIndex) {
    final ptr = c.filament_gltfio_instance_get_skin_name_at(_ptr, skinIndex);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  int jointCountAt(int skinIndex) => c.filament_gltfio_instance_get_joint_count_at(_ptr, skinIndex);

  List<int> jointsAt(int skinIndex) {
    final count = jointCountAt(skinIndex);
    if (count == 0) return [];
    final ptr = c.filament_gltfio_instance_get_joints_at(_ptr, skinIndex);
    return ptr.asTypedList(count).toList();
  }

  void attachSkin(int skinIndex, int targetEntity) {
    if (skinIndex < 0 || skinIndex >= skinCount) {
      throw RangeError.index(skinIndex, this, 'skinIndex', 'Skin index out of bounds', skinCount);
    }
    c.filament_gltfio_instance_attach_skin(_ptr, skinIndex, targetEntity);
  }

  void detachSkin(int skinIndex, int targetEntity) {
    if (skinIndex < 0 || skinIndex >= skinCount) {
      throw RangeError.index(skinIndex, this, 'skinIndex', 'Skin index out of bounds', skinCount);
    }
    c.filament_gltfio_instance_detach_skin(_ptr, skinIndex, targetEntity);
  }

  Float32List inverseBindMatricesAt(int skinIndex) {
    final count = jointCountAt(skinIndex);
    if (count == 0) return Float32List(0);
    final outPtr = calloc<ffi.Float>(count * 16);
    c.filament_gltfio_instance_get_inverse_bind_matrices_at(_ptr, skinIndex, outPtr);
    final result = Float32List.fromList(outPtr.asTypedList(count * 16));
    calloc.free(outPtr);
    return result;
  }

  int get materialInstanceCount => c.filament_gltfio_instance_get_material_instance_count(_ptr);

  List<FilamentMaterialInstance> get materialInstances {
    final count = materialInstanceCount;
    if (count == 0) return [];
    final outPtr = calloc<ffi.Pointer<ffi.Void>>(count);
    c.filament_gltfio_instance_get_material_instances(_ptr, outPtr, count);
    
    final result = <FilamentMaterialInstance>[];
    for (var i = 0; i < count; i++) {
      result.add(FilamentMaterialInstance.internal(outPtr[i], _asset._loader.engine));
    }
    calloc.free(outPtr);
    return result;
  }

  void detachMaterialInstances() {
    c.filament_gltfio_instance_detach_material_instances(_ptr);
  }

  int get materialVariantCount => c.filament_gltfio_instance_get_material_variant_count(_ptr);

  String? materialVariantName(int variantIndex) {
    final ptr = c.filament_gltfio_instance_get_material_variant_name(_ptr, variantIndex);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void applyMaterialVariant(int variantIndex) {
    if (materialVariantCount == 0) return;
    c.filament_gltfio_instance_apply_material_variant(_ptr, variantIndex);
  }

  void recomputeBoundingBoxes() {
    c.filament_gltfio_instance_recompute_bounding_boxes(_ptr);
  }

  Aabb get boundingBox {
    final minPtr = calloc<ffi.Float>(3);
    final maxPtr = calloc<ffi.Float>(3);
    c.filament_gltfio_instance_get_bounding_box(_ptr, minPtr, maxPtr);
    final min = Vector3(minPtr[0], minPtr[1], minPtr[2]);
    final max = Vector3(maxPtr[0], maxPtr[1], maxPtr[2]);
    calloc.free(minPtr);
    calloc.free(maxPtr);
    return Aabb(min: min, max: max);
  }
}

class FilamentNodeManager {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentNodeManager._(this._ptr);

  bool hasComponent(int entity) {
    return c.filament_gltfio_node_manager_has_component(_ptr, entity);
  }

  String? getExtras(int entity) {
    final ptr = c.filament_gltfio_node_manager_get_extras(_ptr, entity);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void setExtras(int entity, String json) {
    final jsonPtr = json.toNativeUtf8();
    c.filament_gltfio_node_manager_set_extras(_ptr, entity, jsonPtr.cast());
    calloc.free(jsonPtr);
  }

  int getMorphTargetNameCount(int entity) {
    return c.filament_gltfio_node_manager_get_morph_target_name_count(_ptr, entity);
  }

  String? getMorphTargetNameAt(int entity, int index) {
    final ptr = c.filament_gltfio_node_manager_get_morph_target_name_at(_ptr, entity, index);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  void setMorphTargetNames(int entity, List<String> names) {
    final count = names.length;
    final namesPtr = calloc<ffi.Pointer<ffi.Char>>(count);
    for (int i = 0; i < count; i++) {
      namesPtr[i] = names[i].toNativeUtf8().cast<ffi.Char>();
    }
    c.filament_gltfio_node_manager_set_morph_target_names(_ptr, entity, namesPtr.cast(), count);
    for (int i = 0; i < count; i++) {
      calloc.free(namesPtr[i]);
    }
    calloc.free(namesPtr);
  }

  int getSceneMembership(int entity) {
    return c.filament_gltfio_node_manager_get_scene_membership(_ptr, entity);
  }

  void setSceneMembership(int entity, int mask) {
    c.filament_gltfio_node_manager_set_scene_membership(_ptr, entity, mask);
  }
}

class FilamentTrsTransformManager {
  final ffi.Pointer<ffi.Void> _ptr;

  FilamentTrsTransformManager._(this._ptr);

  bool hasComponent(int entity) {
    return c.filament_gltfio_trs_transform_manager_has_component(_ptr, entity);
  }

  void setTranslation(int entity, double x, double y, double z) {
    c.filament_trs_set_translation(_ptr, entity, x, y, z);
  }

  Float32List getTranslation(int entity) {
    final out = calloc<ffi.Float>(3);
    c.filament_trs_get_translation(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(3));
    calloc.free(out);
    return result;
  }

  void setRotation(int entity, double qx, double qy, double qz, double qw) {
    c.filament_trs_set_rotation(_ptr, entity, qx, qy, qz, qw);
  }

  Float32List getRotation(int entity) {
    final out = calloc<ffi.Float>(4);
    c.filament_trs_get_rotation(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(4));
    calloc.free(out);
    return result;
  }

  void setScale(int entity, double x, double y, double z) {
    c.filament_trs_set_scale(_ptr, entity, x, y, z);
  }

  Float32List getScale(int entity) {
    final out = calloc<ffi.Float>(3);
    c.filament_trs_get_scale(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(3));
    calloc.free(out);
    return result;
  }

  void setTrs(int entity, Float32List translation, Float32List rotation, Float32List scale) {
    assert(translation.length >= 3 && rotation.length >= 4 && scale.length >= 3);
    final tPtr = calloc<ffi.Float>(3)..asTypedList(3).setAll(0, translation.take(3));
    final rPtr = calloc<ffi.Float>(4)..asTypedList(4).setAll(0, rotation.take(4));
    final sPtr = calloc<ffi.Float>(3)..asTypedList(3).setAll(0, scale.take(3));
    c.filament_trs_set_trs(_ptr, entity, tPtr, rPtr, sPtr);
    calloc.free(tPtr);
    calloc.free(rPtr);
    calloc.free(sPtr);
  }

  Float32List getTransform(int entity) {
    final out = calloc<ffi.Float>(16);
    c.filament_trs_get_transform(_ptr, entity, out);
    final result = Float32List.fromList(out.asTypedList(16));
    calloc.free(out);
    return result;
  }
}
