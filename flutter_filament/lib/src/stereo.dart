/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';
import 'package:flutter_filament/src/view_options.dart';

/// Stereo rendering of a view: both eyes in one pass into a layered render
/// target (multiview), when the engine was created with
/// `EngineConfig(stereoscopicType: StereoscopicType.multiview,
/// stereoscopicEyeCount: 2)` and the device supports it. The materials need a
/// multiview variant (the engine's own and the glTF ubershaders of the
/// prebuilt have one); without stereo support the options are ignored and
/// [isStereoActive] says so.
extension FilamentViewStereo on FilamentView {
  set stereoscopicOptions(StereoscopicOptions options) {
    final ptr = calloc<c.filament_stereoscopic_options>();
    try {
      options.copyToNative(ptr.ref);
      c.filament_view_set_stereoscopic_options(nativePointer, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  StereoscopicOptions get stereoscopicOptions {
    final ptr = calloc<c.filament_stereoscopic_options>();
    try {
      c.filament_view_get_stereoscopic_options(nativePointer, ptr);
      return StereoscopicOptions.fromNative(ptr.ref);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Whether this view renders both eyes: its options ask for stereo and
  /// [engine] (the view's engine) can render it. False is the explicit
  /// fallback: one eye, the camera's own projection.
  bool isStereoActive(FilamentEngine engine) =>
      c.filament_view_is_stereo_active(nativePointer, engine.nativePointer);
}

/// Per-eye placement and projection of a stereo camera: the camera's model
/// matrix is the head, each eye sits at its model matrix relative to it.
extension FilamentCameraStereo on FilamentCamera {
  /// Places [eye] (0 = left, 1 = right) relative to the head.
  void setEyeModelMatrix(int eye, Matrix4 model) {
    final m = calloc<ffi.Double>(16);
    try {
      for (var i = 0; i < 16; i++) {
        m[i] = model.storage[i];
      }
      c.filament_camera_set_eye_model_matrix(nativePointer, eye, m);
    } finally {
      calloc.free(m);
    }
  }

  /// [eye]'s model matrix relative to the head.
  Matrix4 getEyeModelMatrix(int eye) {
    final m = calloc<ffi.Double>(16);
    try {
      c.filament_camera_get_eye_model_matrix(nativePointer, eye, m);
      return Matrix4.fromList([for (var i = 0; i < 16; i++) m[i]]);
    } finally {
      calloc.free(m);
    }
  }

  /// One projection per eye (an OpenXR view's asymmetric field of view) and
  /// the projection culling uses, which must enclose every eye's frustum.
  void setCustomEyeProjection(List<Matrix4> projections, Matrix4 culling,
      {required double near, required double far}) {
    if (projections.isEmpty) return;
    final p = calloc<ffi.Double>(16 * projections.length);
    final cull = calloc<ffi.Double>(16);
    try {
      for (var e = 0; e < projections.length; e++) {
        for (var i = 0; i < 16; i++) {
          p[e * 16 + i] = projections[e].storage[i];
        }
      }
      for (var i = 0; i < 16; i++) {
        cull[i] = culling.storage[i];
      }
      c.filament_camera_set_custom_eye_projection(nativePointer, p, projections.length, cull, near, far);
    } finally {
      calloc.free(p);
      calloc.free(cull);
    }
  }

  /// [eye]'s projection matrix.
  Matrix4 getEyeProjectionMatrix(int eye) {
    final m = calloc<ffi.Double>(16);
    try {
      c.filament_camera_get_eye_projection_matrix(nativePointer, eye, m);
      return Matrix4.fromList([for (var i = 0; i < 16; i++) m[i]]);
    } finally {
      calloc.free(m);
    }
  }
}
