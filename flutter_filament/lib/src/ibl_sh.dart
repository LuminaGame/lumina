import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/ibl_cubemap.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Spherical Harmonics decomposition and manipulation for IBL.
class CubemapSH {
  /// Computes spherical harmonics coefficients from [cm] with [numBands] (1..3).
  ///
  /// If [irradiance] is true, convolves with the cosine lobe to compute diffuse irradiance SH.
  /// Returns a [Float32List] of length `numBands * numBands * 3` (RGB interleaved).
  static Float32List computeSH(
    IblCubemap cm, {
    int numBands = 3,
    bool irradiance = true,
  }) {
    if (numBands < 1 || numBands > 5) {
      throw RangeError.range(numBands, 1, 5, 'numBands');
    }
    final count = numBands * numBands * 3;
    return using((Arena arena) {
      final outSh = arena<ffi.Float>(count);
      final ok = c.filament_cubemap_sh_compute(
        cm.handle,
        numBands,
        irradiance,
        outSh,
      );
      if (!ok) throw StateError('Failed to compute spherical harmonics');
      final result = Float32List(count);
      result.setAll(0, outSh.asTypedList(count));
      return result;
    });
  }

  /// Applies a Hanning window to [sh] to suppress Gibbs ringing.
  static void windowSH(
    Float32List sh,
    int numBands, {
    double cutoff = 0.0,
  }) {
    final count = numBands * numBands * 3;
    if (sh.length != count) {
      throw ArgumentError('sh.length (${sh.length}) does not match numBands $numBands (expected $count)');
    }
    using((Arena arena) {
      final ptr = arena<ffi.Float>(count);
      ptr.asTypedList(count).setAll(0, sh);
      c.filament_cubemap_sh_window(ptr, numBands, cutoff);
      sh.setAll(0, ptr.asTypedList(count));
    });
  }

  /// Pre-scales 3-band SH coefficients into the format expected by `IndirectLight::irradiance`.
  static void preprocessSHForShader(Float32List sh) {
    if (sh.length != 27) {
      throw ArgumentError('preprocessSHForShader expects exactly 27 floats (3 bands * 9 coeffs * 3 RGB)');
    }
    using((Arena arena) {
      final ptr = arena<ffi.Float>(27);
      ptr.asTypedList(27).setAll(0, sh);
      c.filament_cubemap_sh_preprocess_for_shader(ptr);
      sh.setAll(0, ptr.asTypedList(27));
    });
  }

  /// Evaluates and renders spherical harmonics [sh] into a cubemap [out].
  static void renderSH(
    IblCubemap out,
    Float32List sh,
    int numBands,
  ) {
    final count = numBands * numBands * 3;
    if (sh.length != count) {
      throw ArgumentError('sh.length must be numBands * numBands * 3');
    }
    using((Arena arena) {
      final ptr = arena<ffi.Float>(count);
      ptr.asTypedList(count).setAll(0, sh);
      c.filament_cubemap_sh_render(out.handle, ptr, numBands);
    });
  }

  /// Pure Dart spherical harmonics index calculation: $l(l+1) + m$.
  static int getShIndex(int m, int l) {
    return l * (l + 1) + m;
  }
}
