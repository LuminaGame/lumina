part of '../material.dart';

/// The render state overrides of a [FilamentMaterialInstance]: culling, colour
/// and depth writes, depth test, transparency, mask threshold, polygon offset,
/// scissor and stencil.
mixin _MaterialInstanceRenderState {
  ffi.Pointer<ffi.Void> get _ptr;
  void _checkDisposed();

  // --- Render State Overrides ---

  /// Gets the face culling mode.
  CullingMode get cullingMode {
    _checkDisposed();
    final mode = c.filament_material_instance_get_culling_mode(_ptr);
    return CullingMode.values.firstWhere((e) => e.value == mode, orElse: () => CullingMode.back);
  }

  /// Sets the face culling mode for all passes.
  void setCullingMode(CullingMode mode) {
    _checkDisposed();
    c.filament_material_instance_set_culling_mode(_ptr, mode.value);
  }

  /// Sets the face culling mode separately for the color pass and shadow pass.
  void setCullingModeSeparate(CullingMode colorPassMode, CullingMode shadowPassMode) {
    _checkDisposed();
    c.filament_material_instance_set_culling_mode2(_ptr, colorPassMode.value, shadowPassMode.value);
  }

  /// Gets whether this instance is double sided.
  bool get isDoubleSided {
    _checkDisposed();
    return c.filament_material_instance_is_double_sided(_ptr);
  }

  /// Sets whether this instance is double sided.
  /// 
  /// Note: Setting this to true disables culling inside Filament. 
  /// Calling `setCullingMode` afterwards re-overrides this behavior.
  void setDoubleSided(bool doubleSided) {
    _checkDisposed();
    c.filament_material_instance_set_double_sided(_ptr, doubleSided);
  }

  /// Gets whether color write is enabled.
  bool get isColorWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_color_write_enabled(_ptr);
  }

  /// Enables or disables writing into the color buffer.
  void setColorWrite(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_color_write(_ptr, enable);
  }

  /// Gets whether depth write is enabled.
  bool get isDepthWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_depth_write_enabled(_ptr);
  }

  /// Enables or disables writing into the depth buffer.
  void setDepthWrite(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_depth_write(_ptr, enable);
  }

  /// Gets whether depth culling is enabled.
  bool get isDepthCullingEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_depth_culling_enabled(_ptr);
  }

  /// Enables or disables depth testing (culling).
  void setDepthCulling(bool enable) {
    _checkDisposed();
    c.filament_material_instance_set_depth_culling(_ptr, enable);
  }

  /// Gets the depth comparison function.
  DepthFunc get depthFunc {
    _checkDisposed();
    final func = c.filament_material_instance_get_depth_func(_ptr);
    return DepthFunc.values.firstWhere((e) => e.value == func, orElse: () => DepthFunc.le);
  }

  /// Sets the depth comparison function.
  void setDepthFunc(DepthFunc func) {
    _checkDisposed();
    c.filament_material_instance_set_depth_func(_ptr, func.value);
  }

  /// Gets the transparency mode.
  TransparencyMode get transparencyMode {
    _checkDisposed();
    final mode = c.filament_material_instance_get_transparency_mode(_ptr);
    return TransparencyMode.values.firstWhere((e) => e.value == mode, orElse: () => TransparencyMode.defaultMode);
  }

  /// Sets the transparency mode.
  void setTransparencyMode(TransparencyMode mode) {
    _checkDisposed();
    c.filament_material_instance_set_transparency_mode(_ptr, mode.value);
  }

  /// Gets the mask threshold (alpha cutoff).
  double get maskThreshold {
    _checkDisposed();
    return c.filament_material_instance_get_mask_threshold(_ptr);
  }

  /// Sets the mask threshold (alpha cutoff). 
  /// Only affects materials built with `blending: masked`.
  void setMaskThreshold(double threshold) {
    _checkDisposed();
    c.filament_material_instance_set_mask_threshold(_ptr, threshold);
  }

  /// Sets the polygon offset for this instance (useful for decals).
  void setPolygonOffset(double scale, double constant) {
    _checkDisposed();
    c.filament_material_instance_set_polygon_offset(_ptr, scale, constant);
  }

  /// Sets a custom scissor rectangle for this instance.
  /// WARNING: Scissor coordinates use a BOTTOM-LEFT origin (Filament convention), 
  /// unlike Flutter's top-left origin.
  void setScissor({required int left, required int bottom, required int width, required int height}) {
    _checkDisposed();
    c.filament_material_instance_set_scissor(_ptr, left, bottom, width, height);
  }

  /// Removes the custom scissor rectangle, reverting to the view's viewport.
  void unsetScissor() {
    _checkDisposed();
    c.filament_material_instance_unset_scissor(_ptr);
  }

  /// Sets whether stencil buffer writing is enabled for this instance.
  void setStencilWrite(bool enabled) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_write(_ptr, enabled);
  }

  /// Gets whether stencil buffer writing is enabled for this instance.
  bool get isStencilWriteEnabled {
    _checkDisposed();
    return c.filament_material_instance_is_stencil_write_enabled(_ptr);
  }

  /// Sets the stencil comparison function.
  void setStencilCompareFunction(DepthFunc func, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_compare_function(_ptr, func.value, face.value);
  }

  /// Sets the stencil fail operation.
  void setStencilOpStencilFail(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_stencil_fail(_ptr, op.value, face.value);
  }

  /// Sets the depth fail operation.
  void setStencilOpDepthFail(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_depth_fail(_ptr, op.value, face.value);
  }

  /// Sets the depth-stencil pass operation.
  void setStencilOpDepthStencilPass(StencilOperation op, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    c.filament_material_instance_set_stencil_op_depth_stencil_pass(_ptr, op.value, face.value);
  }

  /// Sets the stencil reference value.
  void setStencilReferenceValue(int value, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (value < 0 || value > 255) {
      throw RangeError.range(value, 0, 255, 'value');
    }
    c.filament_material_instance_set_stencil_reference_value(_ptr, value, face.value);
  }

  /// Sets the stencil read mask.
  void setStencilReadMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (mask < 0 || mask > 255) {
      throw RangeError.range(mask, 0, 255, 'mask');
    }
    c.filament_material_instance_set_stencil_read_mask(_ptr, mask, face.value);
  }

  /// Sets the stencil write mask.
  void setStencilWriteMask(int mask, {StencilFace face = StencilFace.frontAndBack}) {
    _checkDisposed();
    if (mask < 0 || mask > 255) {
      throw RangeError.range(mask, 0, 255, 'mask');
    }
    c.filament_material_instance_set_stencil_write_mask(_ptr, mask, face.value);
  }
}
