import 'ffi_platform.dart' as ffi;
import 'dart:async';
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/color_grading.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/entity.dart';
import 'package:flutter_filament/src/math/viewport.dart';
import 'package:flutter_filament/src/render_target.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view_options.dart';

class PickingResult {
  final FilamentEntity? renderable;
  final double depth;
  final (double, double) fragCoords;
  PickingResult(this.renderable, this.depth, this.fragCoords);
}

/// A View encompasses all the state needed for rendering a Scene.
///
/// A View specifies the Scene, Camera, Viewport, and rendering parameters.
class FilamentView {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  FilamentScene? _scene;
  FilamentCamera? _camera;
  FilamentRenderTarget? _renderTarget;

  /// Internal constructor.
  FilamentView.internal(this._ptr, this._engine);

  /// The raw native pointer to the Filament View.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Sets the Scene associated with this View.
  set scene(FilamentScene scene) {
    _checkDisposed();
    _scene = scene;
    c.filament_view_set_scene(_ptr, scene.nativePointer);
  }

  FilamentScene? get scene {
    _checkDisposed();
    final nativeScene = c.filament_view_get_scene(_ptr);
    if (nativeScene.address == 0) return null;
    if (_scene?.nativePointer.address == nativeScene.address) return _scene;
    return null;
  }

  /// Sets the Camera associated with this View.
  set camera(FilamentCamera camera) {
    _checkDisposed();
    _camera = camera;
    c.filament_view_set_camera(_ptr, camera.nativePointer);
  }

  FilamentCamera? get camera {
    _checkDisposed();
    if (!c.filament_view_has_camera(_ptr)) return null;
    final nativeCamera = c.filament_view_get_camera(_ptr);
    if (_camera?.nativePointer.address == nativeCamera.address) return _camera;
    return null;
  }

  set renderTarget(FilamentRenderTarget? renderTarget) {
    _checkDisposed();
    _renderTarget = renderTarget;
    c.filament_view_set_render_target(_ptr, renderTarget?.nativePointer ?? ffi.nullptr);
  }

  FilamentRenderTarget? get renderTarget {
    _checkDisposed();
    final nativeRT = c.filament_view_get_render_target(_ptr);
    if (nativeRT.address == 0) return null;
    if (_renderTarget?.nativePointer.address == nativeRT.address) return _renderTarget;
    return null;
  }

  /// Sets the viewport for this View from explicit coordinates (in bottom-left origin).
  void setViewport(int left, int bottom, int width, int height) {
    _checkDisposed();
    c.filament_view_set_viewport(_ptr, left, bottom, width, height);
  }

  /// Sets the viewport for this View from a [Viewport] model.
  void setViewportModel(Viewport vp) {
    setViewport(vp.left, vp.bottom, vp.width, vp.height);
  }

  /// Gets the current viewport as (left, bottom, width, height) tuple.
  (int, int, int, int) get viewport {
    _checkDisposed();
    final leftBottom = calloc<ffi.Int32>(2);
    final widthHeight = calloc<ffi.Uint32>(2);
    c.filament_view_get_viewport(_ptr, leftBottom, widthHeight);
    final res = (leftBottom[0], leftBottom[1], widthHeight[0], widthHeight[1]);
    calloc.free(leftBottom);
    calloc.free(widthHeight);
    return res;
  }

  /// Gets the current viewport as a [Viewport] model.
  Viewport get viewportModel {
    final vp = viewport;
    return Viewport(left: vp.$1, bottom: vp.$2, width: vp.$3, height: vp.$4);
  }

  ColorGrading? _colorGrading;

  /// Sets or clears the ColorGrading on this View. Passing null restores the default color grading.
  set colorGrading(ColorGrading? cg) {
    _checkDisposed();
    _colorGrading = cg;
    c.filament_view_set_color_grading(_ptr, cg?.nativePointer ?? ffi.nullptr);
  }

  /// Sets the ColorGrading using a method call.
  void setColorGradingModel(ColorGrading? cg) {
    colorGrading = cg;
  }

  /// Gets the currently assigned [ColorGrading], if any.
  ColorGrading? get colorGrading => _colorGrading;

  /// Sets the View's name (for debugging).
  set name(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_view_set_name(_ptr, nativeName.cast());
    calloc.free(nativeName);
  }

  String? get name {
    _checkDisposed();
    final cName = c.filament_view_get_name(_ptr);
    if (cName.address == 0) return null;
    return cName.cast<Utf8>().toDartString();
  }

  /// Enables or disables shadow mapping on this View.
  set shadowingEnabled(bool enabled) {
    _checkDisposed();
    c.filament_view_set_shadowing_enabled(_ptr, enabled);
  }

  bool get shadowingEnabled {
    _checkDisposed();
    return c.filament_view_is_shadowing_enabled(_ptr);
  }

  /// Enables or disables post-processing on this View.
  set postProcessingEnabled(bool enabled) {
    _checkDisposed();
    c.filament_view_set_post_processing_enabled(_ptr, enabled);
  }

  bool get postProcessingEnabled {
    _checkDisposed();
    return c.filament_view_is_post_processing_enabled(_ptr);
  }

  set shadowType(ShadowType type) {
    _checkDisposed();
    c.filament_view_set_shadow_type(_ptr, type.toNative());
  }

  ShadowType get shadowType {
    _checkDisposed();
    return ShadowType.fromNative(c.filament_view_get_shadow_type(_ptr));
  }

  set vsmShadowOptions(VsmShadowOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_vsm_shadow_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_vsm_shadow_options(_ptr, ptr);
    calloc.free(ptr);
  }

  VsmShadowOptions get vsmShadowOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_vsm_shadow_options>();
    c.filament_view_get_vsm_shadow_options(_ptr, ptr);
    final opts = VsmShadowOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return opts;
  }

  set softShadowOptions(SoftShadowOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_soft_shadow_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_soft_shadow_options(_ptr, ptr);
    calloc.free(ptr);
  }

  SoftShadowOptions get softShadowOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_soft_shadow_options>();
    c.filament_view_get_soft_shadow_options(_ptr, ptr);
    final opts = SoftShadowOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return opts;
  }

  set blendMode(BlendMode mode) {
    _checkDisposed();
    c.filament_view_set_blend_mode(_ptr, mode.toNative());
  }

  BlendMode get blendMode {
    _checkDisposed();
    return BlendMode.fromNative(c.filament_view_get_blend_mode(_ptr));
  }

  set stencilBufferEnabled(bool enabled) {
    _checkDisposed();
    c.filament_view_set_stencil_buffer_enabled(_ptr, enabled);
  }

  bool get stencilBufferEnabled {
    _checkDisposed();
    return c.filament_view_is_stencil_buffer_enabled(_ptr);
  }

  set frontFaceWindingInverted(bool inverted) {
    _checkDisposed();
    c.filament_view_set_front_face_winding_inverted(_ptr, inverted);
  }

  bool get frontFaceWindingInverted {
    _checkDisposed();
    return c.filament_view_is_front_face_winding_inverted(_ptr);
  }

  void setDynamicLightingOptions(double zLightNear, double zLightFar) {
    _checkDisposed();
    c.filament_view_set_dynamic_lighting_options(_ptr, zLightNear, zLightFar);
  }

  void setMaterialGlobal(int index, double x, double y, double z, double w) {
    if (index < 0 || index > 3) throw RangeError('Material global index must be 0..3');
    _checkDisposed();
    c.filament_view_set_material_global(_ptr, index, x, y, z, w);
  }

  (double, double, double, double) getMaterialGlobal(int index) {
    if (index < 0 || index > 3) throw RangeError('Material global index must be 0..3');
    _checkDisposed();
    final ptr = calloc<ffi.Float>(4);
    c.filament_view_get_material_global(_ptr, index, ptr);
    final res = (ptr[0], ptr[1], ptr[2], ptr[3]);
    calloc.free(ptr);
    return res;
  }

  void clearFrameHistory(FilamentEngine engine) {
    _checkDisposed();
    c.filament_view_clear_frame_history(_ptr, engine.nativePointer);
  }

  void setLayerEnabled(int layer, bool enabled) {
    _checkDisposed();
    c.filament_view_set_layer_enabled(_ptr, layer, enabled);
  }

  int get visibleRenderableCount {
    _checkDisposed();
    return c.filament_view_get_visible_renderable_count(_ptr);
  }

  /// Sets the anti-aliasing type (e.g., 0 for None, 1 for FXAA).
  set antiAliasing(int type) {
    _checkDisposed();
    c.filament_view_set_anti_aliasing(_ptr, type);
  }

  /// Gets the anti-aliasing type.
  int get antiAliasing {
    _checkDisposed();
    return c.filament_view_get_anti_aliasing(_ptr);
  }

  /// Enables or disables screen space refraction.
  set screenSpaceRefractionEnabled(bool enabled) {
    _checkDisposed();
    c.filament_view_set_screen_space_refraction_enabled(_ptr, enabled);
  }

  /// Gets whether screen space refraction is enabled.
  bool get screenSpaceRefractionEnabled {
    _checkDisposed();
    return c.filament_view_is_screen_space_refraction_enabled(_ptr);
  }

  /// Sets visible layers bitmask.
  void setVisibleLayers(int select, int values) {
    _checkDisposed();
    c.filament_view_set_visible_layers(_ptr, select, values);
  }

  int get visibleLayers {
    _checkDisposed();
    return c.filament_view_get_visible_layers(_ptr);
  }

  set bloomOptions(BloomOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_bloom_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_bloom_options(_ptr, ptr);
    calloc.free(ptr);
  }

  BloomOptions get bloomOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_bloom_options>();
    c.filament_view_get_bloom_options(_ptr, ptr);
    final result = BloomOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set fogOptions(FogOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_fog_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_fog_options(_ptr, ptr);
    calloc.free(ptr);
  }

  FogOptions get fogOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_fog_options>();
    c.filament_view_get_fog_options(_ptr, ptr);
    final result = FogOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set depthOfFieldOptions(DepthOfFieldOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_depth_of_field_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_depth_of_field_options(_ptr, ptr);
    calloc.free(ptr);
  }

  DepthOfFieldOptions get depthOfFieldOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_depth_of_field_options>();
    c.filament_view_get_depth_of_field_options(_ptr, ptr);
    final result = DepthOfFieldOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set vignetteOptions(VignetteOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_vignette_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_vignette_options(_ptr, ptr);
    calloc.free(ptr);
  }

  VignetteOptions get vignetteOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_vignette_options>();
    c.filament_view_get_vignette_options(_ptr, ptr);
    final result = VignetteOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set ambientOcclusionOptions(AmbientOcclusionOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_ambient_occlusion_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_ambient_occlusion_options(_ptr, ptr);
    calloc.free(ptr);
  }

  AmbientOcclusionOptions get ambientOcclusionOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_ambient_occlusion_options>();
    c.filament_view_get_ambient_occlusion_options(_ptr, ptr);
    final result = AmbientOcclusionOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set temporalAntiAliasingOptions(TemporalAntiAliasingOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_temporal_anti_aliasing_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_temporal_anti_aliasing_options(_ptr, ptr);
    calloc.free(ptr);
  }

  TemporalAntiAliasingOptions get temporalAntiAliasingOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_temporal_anti_aliasing_options>();
    c.filament_view_get_temporal_anti_aliasing_options(_ptr, ptr);
    final result = TemporalAntiAliasingOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  /// Whether this view's engine can render motion vectors
  /// ([TemporalAntiAliasingOptions.motionVectors]): a GPU backend at feature
  /// level 1 or higher with RG16F colour attachments. False on the noop backend.
  bool get motionVectorsSupported {
    _checkDisposed();
    return c.filament_view_motion_vectors_supported(_engine.nativePointer);
  }

  FilamentTexture? _motionVectorTexture;

  /// The texture the motion vectors are exported into while
  /// [TemporalAntiAliasingOptions.motionVectors] is on, or null.
  ///
  /// The texture must be a two-or-more-channel float colour texture created
  /// with [TextureUsage.colorAttachment] and [TextureUsage.sampleable], exactly
  /// the size of the view's render target (a texture of another size is
  /// ignored). Each texel holds the screen-space offset of the surface since
  /// the previous frame, in texels, x to the right and y up; the background is
  /// zero. [MotionVectorBuffer] wraps the texture, its render target and the
  /// readback. The texture must outlive its use by the view.
  FilamentTexture? get motionVectorTexture {
    _checkDisposed();
    final ptr = c.filament_view_get_motion_vector_texture(_ptr);
    return ptr == ffi.nullptr ? null : _motionVectorTexture;
  }

  set motionVectorTexture(FilamentTexture? texture) {
    _checkDisposed();
    _motionVectorTexture = texture;
    c.filament_view_set_motion_vector_texture(_ptr, texture?.nativePointer ?? ffi.nullptr);
  }

  set multiSampleAntiAliasingOptions(MultiSampleAntiAliasingOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_multi_sample_anti_aliasing_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_multi_sample_anti_aliasing_options(_ptr, ptr);
    calloc.free(ptr);
  }

  MultiSampleAntiAliasingOptions get multiSampleAntiAliasingOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_multi_sample_anti_aliasing_options>();
    c.filament_view_get_multi_sample_anti_aliasing_options(_ptr, ptr);
    final result = MultiSampleAntiAliasingOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set screenSpaceReflectionsOptions(ScreenSpaceReflectionsOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_screen_space_reflections_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_screen_space_reflections_options(_ptr, ptr);
    calloc.free(ptr);
  }

  ScreenSpaceReflectionsOptions get screenSpaceReflectionsOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_screen_space_reflections_options>();
    c.filament_view_get_screen_space_reflections_options(_ptr, ptr);
    final result = ScreenSpaceReflectionsOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set guardBandOptions(GuardBandOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_guard_band_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_guard_band_options(_ptr, ptr);
    calloc.free(ptr);
  }

  GuardBandOptions get guardBandOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_guard_band_options>();
    c.filament_view_get_guard_band_options(_ptr, ptr);
    final result = GuardBandOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set dynamicResolutionOptions(DynamicResolutionOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_dynamic_resolution_options>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_dynamic_resolution_options(_ptr, ptr);
    calloc.free(ptr);
  }

  DynamicResolutionOptions get dynamicResolutionOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_dynamic_resolution_options>();
    c.filament_view_get_dynamic_resolution_options(_ptr, ptr);
    final result = DynamicResolutionOptions.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  (double, double) get lastDynamicResolutionScale {
    _checkDisposed();
    final ptr = calloc<ffi.Float>(2);
    c.filament_view_get_last_dynamic_resolution_scale(_ptr, ptr);
    final result = (ptr[0], ptr[1]);
    calloc.free(ptr);
    return result;
  }

  set renderQuality(RenderQuality options) {
    _checkDisposed();
    final ptr = calloc<c.filament_render_quality>();
    options.copyToNative(ptr.ref);
    c.filament_view_set_render_quality(_ptr, ptr);
    calloc.free(ptr);
  }

  RenderQuality get renderQuality {
    _checkDisposed();
    final ptr = calloc<c.filament_render_quality>();
    c.filament_view_get_render_quality(_ptr, ptr);
    final result = RenderQuality.fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }

  set dithering(Dithering d) {
    _checkDisposed();
    c.filament_view_set_dithering(_ptr, d.toNative());
  }

  Dithering get dithering {
    _checkDisposed();
    final d = c.filament_view_get_dithering(_ptr);
    return Dithering.fromNative(d);
  }

  set transparentPickingEnabled(bool enabled) {
    _checkDisposed();
    c.filament_view_set_transparent_picking_enabled(_ptr, enabled);
  }

  bool get transparentPickingEnabled {
    _checkDisposed();
    return c.filament_view_is_transparent_picking_enabled(_ptr);
  }

  /// Picks a pixel on the screen and returns the rendered entity and depth at that pixel.
  /// Note: The coordinates (x, y) are based on a bottom-left origin.
  Future<PickingResult> pick(int x, int y) {
    _checkDisposed();
    final completer = Completer<PickingResult>();
    late ffi.NativeCallable<c.FilamentPickCallbackFunction> callable;
    callable = ffi.NativeCallable<c.FilamentPickCallbackFunction>.listener((int renderable, double depth, double fragX, double fragY, ffi.Pointer<ffi.Void> userData) {
      final entity = renderable != 0 ? FilamentEntity(renderable, _engine) : null;
      final pickingResult = PickingResult(
        entity,
        depth,
        (fragX, fragY),
      );
      callable.close();
      completer.complete(pickingResult);
    });
    c.filament_view_pick(_ptr, x, y, callable.nativeFunction, ffi.nullptr);
    return completer.future;
  }

  /// Destroys this view and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_view(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentView has been disposed');
    }
  }
}
