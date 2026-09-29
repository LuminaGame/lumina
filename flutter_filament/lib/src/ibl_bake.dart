import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/ibl_cubemap.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

typedef IblProgressCallback = void Function(int index, double progress);

/// Offline IBL baking operations: roughness filtering, diffuse irradiance, and DFG LUT generation.
class CubemapIBL {
  /// Computes a roughness filtered LOD using prefiltered importance sampling GGX.
  static void roughnessFilter(
    IblCubemap dst,
    List<IblCubemap> levels,
    double linearRoughness, {
    int maxNumSamples = 1024,
    Vector3? mirror,
    bool prefilter = false,
    IblProgressCallback? onProgress,
  }) {
    if (levels.isEmpty) throw ArgumentError('levels must not be empty');
    final m = mirror ?? Vector3(1.0, 1.0, 1.0);

    using((Arena arena) {
      final levelsPtr = arena<ffi.Pointer<c.FilIblCubemap>>(levels.length);
      for (var i = 0; i < levels.length; i++) {
        levelsPtr[i] = levels[i].handle;
      }

      c.FilIblProgress progressFn = ffi.nullptr;
      ffi.NativeCallable<c.FilIblProgressFunction>? callable;
      if (onProgress != null) {
        callable = ffi.NativeCallable<c.FilIblProgressFunction>.isolateLocal(
          (int index, double progress, ffi.Pointer<ffi.Void> _) {
            onProgress(index, progress);
          },
        );
        progressFn = callable.nativeFunction;
      }

      try {
        c.filament_cubemap_ibl_roughness_filter(
          dst.handle,
          levelsPtr,
          levels.length,
          linearRoughness,
          maxNumSamples,
          m.x,
          m.y,
          m.z,
          prefilter,
          progressFn,
          ffi.nullptr,
        );
      } finally {
        callable?.close();
      }
    });
  }

  /// Computes the diffuse irradiance using prefiltered importance sampling GGX.
  static void diffuseIrradiance(
    IblCubemap dst,
    List<IblCubemap> levels, {
    int maxNumSamples = 1024,
    IblProgressCallback? onProgress,
  }) {
    if (levels.isEmpty) throw ArgumentError('levels must not be empty');

    using((Arena arena) {
      final levelsPtr = arena<ffi.Pointer<c.FilIblCubemap>>(levels.length);
      for (var i = 0; i < levels.length; i++) {
        levelsPtr[i] = levels[i].handle;
      }

      c.FilIblProgress progressFn = ffi.nullptr;
      ffi.NativeCallable<c.FilIblProgressFunction>? callable;
      if (onProgress != null) {
        callable = ffi.NativeCallable<c.FilIblProgressFunction>.isolateLocal(
          (int index, double progress, ffi.Pointer<ffi.Void> _) {
            onProgress(index, progress);
          },
        );
        progressFn = callable.nativeFunction;
      }

      try {
        c.filament_cubemap_ibl_diffuse_irradiance(
          dst.handle,
          levelsPtr,
          levels.length,
          maxNumSamples,
          progressFn,
          ffi.nullptr,
        );
      } finally {
        callable?.close();
      }
    });
  }

  /// Computes the DFG LUT term of the split-sum approximation into [dst].
  static void dfg(
    IblImage dst, {
    bool multiscatter = false,
    bool cloth = false,
  }) {
    c.filament_cubemap_ibl_dfg(dst.handle, multiscatter, cloth);
  }
}
