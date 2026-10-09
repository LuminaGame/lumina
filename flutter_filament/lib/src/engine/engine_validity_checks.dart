part of '../engine.dart';

/// The `isValid*` queries of a [FilamentEngine]: whether a handle still names
/// a live object of that engine.
mixin _EngineValidityChecks {
  ffi.Pointer<ffi.Void> get _ptr;
  void _checkDisposed();

  // =========================================================================
  // isValid family
  // =========================================================================

  /// Tells whether a [FilamentRenderer] is valid.
  bool isValidRenderer(FilamentRenderer renderer) {
    _checkDisposed();
    if (renderer.isDisposed) return false;
    return c.filament_engine_is_valid_renderer(_ptr, renderer.nativePointer);
  }

  /// Tells whether a [FilamentView] is valid.
  bool isValidView(FilamentView view) {
    _checkDisposed();
    if (view.isDisposed) return false;
    return c.filament_engine_is_valid_view(_ptr, view.nativePointer);
  }

  /// Tells whether a [FilamentScene] is valid.
  bool isValidScene(FilamentScene scene) {
    _checkDisposed();
    if (scene.isDisposed) return false;
    return c.filament_engine_is_valid_scene(_ptr, scene.nativePointer);
  }

  /// Tells whether a [FilamentSwapChain] is valid.
  bool isValidSwapChain(FilamentSwapChain swapChain) {
    _checkDisposed();
    if (swapChain.isDisposed) return false;
    return c.filament_engine_is_valid_swap_chain(_ptr, swapChain.nativePointer);
  }

  /// Tells whether a [FilamentCamera] component is valid.
  bool isValidCamera(FilamentCamera camera) {
    _checkDisposed();
    if (camera.isDisposed) return false;
    return c.filament_engine_is_valid_camera(_ptr, camera.nativePointer);
  }

  /// Tells whether a Texture native handle is valid.
  bool isValidTexture(ffi.Pointer<ffi.Void> texture) {
    _checkDisposed();
    if (texture == ffi.nullptr) return false;
    return c.filament_engine_is_valid_texture(_ptr, texture);
  }

  /// Tells whether a Material native handle is valid.
  bool isValidMaterial(ffi.Pointer<ffi.Void> material) {
    _checkDisposed();
    if (material == ffi.nullptr) return false;
    return c.filament_engine_is_valid_material(_ptr, material);
  }

  /// Tells whether a MaterialInstance is valid when its parent Material is known.
  bool isValidMaterialInstance(ffi.Pointer<ffi.Void> material, ffi.Pointer<ffi.Void> mi) {
    _checkDisposed();
    if (material == ffi.nullptr || mi == ffi.nullptr) return false;
    return c.filament_engine_is_valid_material_instance(_ptr, material, mi);
  }

  /// Tells whether a MaterialInstance is valid (expensive full scan).
  bool isValidMaterialInstanceExpensive(ffi.Pointer<ffi.Void> mi) {
    _checkDisposed();
    if (mi == ffi.nullptr) return false;
    return c.filament_engine_is_valid_expensive_material_instance(_ptr, mi);
  }

  /// Tells whether a VertexBuffer native handle is valid.
  bool isValidVertexBuffer(ffi.Pointer<ffi.Void> vb) {
    _checkDisposed();
    if (vb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_vertex_buffer(_ptr, vb);
  }

  /// Tells whether an IndexBuffer native handle is valid.
  bool isValidIndexBuffer(ffi.Pointer<ffi.Void> ib) {
    _checkDisposed();
    if (ib == ffi.nullptr) return false;
    return c.filament_engine_is_valid_index_buffer(_ptr, ib);
  }

  /// Tells whether a BufferObject native handle is valid.
  bool isValidBufferObject(ffi.Pointer<ffi.Void> bo) {
    _checkDisposed();
    if (bo == ffi.nullptr) return false;
    return c.filament_engine_is_valid_buffer_object(_ptr, bo);
  }

  /// Tells whether a SkinningBuffer native handle is valid.
  bool isValidSkinningBuffer(ffi.Pointer<ffi.Void> sb) {
    _checkDisposed();
    if (sb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_skinning_buffer(_ptr, sb);
  }

  /// Tells whether a MorphTargetBuffer native handle is valid.
  bool isValidMorphTargetBuffer(ffi.Pointer<ffi.Void> mtb) {
    _checkDisposed();
    if (mtb == ffi.nullptr) return false;
    return c.filament_engine_is_valid_morph_target_buffer(_ptr, mtb);
  }

  /// Tells whether an InstanceBuffer native handle is valid.
  bool isValidInstanceBuffer(ffi.Pointer<ffi.Void> ibuf) {
    _checkDisposed();
    if (ibuf == ffi.nullptr) return false;
    return c.filament_engine_is_valid_instance_buffer(_ptr, ibuf);
  }

  /// Tells whether an [IndirectLight] native handle or instance is valid.
  bool isValidIndirectLight(FilamentIndirectLight ibl) {
    _checkDisposed();
    if (ibl.isDisposed) return false;
    return c.filament_engine_is_valid_indirect_light(_ptr, ibl.nativePointer);
  }

  /// Tells whether a [Skybox] instance is valid.
  bool isValidSkybox(FilamentSkybox skybox) {
    _checkDisposed();
    if (skybox.isDisposed) return false;
    return c.filament_engine_is_valid_skybox(_ptr, skybox.nativePointer);
  }

  /// Tells whether a RenderTarget native handle is valid.
  bool isValidRenderTarget(ffi.Pointer<ffi.Void> rt) {
    _checkDisposed();
    if (rt == ffi.nullptr) return false;
    return c.filament_engine_is_valid_render_target(_ptr, rt);
  }

  /// Tells whether a Fence native handle is valid.
  bool isValidFence(ffi.Pointer<ffi.Void> fence) {
    _checkDisposed();
    if (fence == ffi.nullptr) return false;
    return c.filament_engine_is_valid_fence(_ptr, fence);
  }

  /// Tells whether a [ColorGrading] instance is valid.
  bool isValidColorGrading(ColorGrading cg) {
    _checkDisposed();
    if (cg.isDisposed) return false;
    return c.filament_engine_is_valid_color_grading(_ptr, cg.nativePointer);
  }
}
