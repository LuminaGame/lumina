import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';

import 'engine.dart';
import 'texture.dart';
import 'filament_bindings.dart' as c;

/// Represents spherical harmonics (SH) coefficients of 1, 2, or 3 bands.
///
/// SH coefficients are stored as 3 floats (RGB) per coefficient.
/// The number of coefficients is `bands * bands` (1, 4, or 9 coefficients,
/// or 3, 12, or 27 float values).
/// The index formula is: `index(l, m) = l * (l + 1) + m`.
class SphericalHarmonics {
  /// Number of spherical harmonics bands (1, 2, or 3).
  final int bands;

  /// Packed float3 coefficients (length must be `bands * bands * 3`).
  final Float32List coefficients;

  /// Creates a [SphericalHarmonics] instance.
  ///
  /// [bands] must be in 1..3 range.
  /// [coefficients] length must match `bands * bands * 3`.
  SphericalHarmonics({
    required this.bands,
    required List<double> coefficients,
  }) : coefficients = coefficients is Float32List
            ? coefficients
            : Float32List.fromList(coefficients) {
    if (bands < 1 || bands > 3) {
      throw ArgumentError.value(
        bands,
        'bands',
        'Spherical harmonics bands must be 1, 2, or 3',
      );
    }
    final expectedFloats = bands * bands * 3;
    if (this.coefficients.length != expectedFloats) {
      throw ArgumentError.value(
        this.coefficients.length,
        'coefficients',
        'Expected $expectedFloats floats for $bands bands, but got ${this.coefficients.length}',
      );
    }
  }

  /// Calculates the index of the spherical harmonic coefficient for band [l] and degree [m].
  ///
  /// Formula: `index(l, m) = l * (l + 1) + m`.
  static int shIndex(int l, int m) => l * (l + 1) + m;
}

/// Represents an Image-Based Lighting (IBL) IndirectLight source in Filament.
///
/// Simulates global illumination from a distant environment, supporting
/// reflections cubemaps and spherical harmonics irradiance / radiance.
class FilamentIndirectLight {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Strong reference to keep the reflection texture alive.
  final FilamentTexture? _reflectionsTexture;

  FilamentIndirectLight._(this._ptr, this._engine, [this._reflectionsTexture]);

  /// Internal constructor.
  FilamentIndirectLight.internal(this._ptr, this._engine, [this._reflectionsTexture]);

  /// Builds an [FilamentIndirectLight] with full builder parameters.
  ///
  /// - [reflections]: Reflections cubemap texture.
  /// - [irradiance]: Spherical harmonics irradiance (1, 2, or 3 bands).
  /// - [radiance]: Spherical harmonics radiance (1, 2, or 3 bands).
  /// - [intensity]: Environment intensity in lux (default = 30000).
  /// - [rotation]: 3x3 rigid-body rotation matrix.
  factory FilamentIndirectLight.build(
    FilamentEngine engine, {
    FilamentTexture? reflections,
    SphericalHarmonics? irradiance,
    SphericalHarmonics? radiance,
    double intensity = 30000.0,
    Matrix3? rotation,
  }) {
    ffi.Pointer<ffi.Float> irradPtr = ffi.nullptr;
    ffi.Pointer<ffi.Float> radPtr = ffi.nullptr;
    ffi.Pointer<ffi.Float> rotPtr = ffi.nullptr;

    try {
      if (irradiance != null) {
        irradPtr = calloc<ffi.Float>(irradiance.coefficients.length);
        irradPtr.asTypedList(irradiance.coefficients.length).setAll(0, irradiance.coefficients);
      }
      if (radiance != null) {
        radPtr = calloc<ffi.Float>(radiance.coefficients.length);
        radPtr.asTypedList(radiance.coefficients.length).setAll(0, radiance.coefficients);
      }
      if (rotation != null) {
        rotPtr = calloc<ffi.Float>(9);
        final rotList = rotPtr.asTypedList(9);
        final storage = rotation.storage;
        for (var i = 0; i < 9; i++) {
          rotList[i] = storage[i];
        }
      }

      final ptr = c.filament_indirect_light_create_ex(
        engine.nativePointer,
        reflections != null ? reflections.nativePointer : ffi.nullptr,
        irradiance?.bands ?? 0,
        irradPtr,
        radiance?.bands ?? 0,
        radPtr,
        intensity,
        rotPtr,
      );

      if (ptr == ffi.nullptr) {
        throw Exception('Failed to build FilamentIndirectLight');
      }

      return FilamentIndirectLight._(ptr, engine, reflections);
    } finally {
      if (rotPtr != ffi.nullptr) calloc.free(rotPtr);
      if (radPtr != ffi.nullptr) calloc.free(radPtr);
      if (irradPtr != ffi.nullptr) calloc.free(irradPtr);
    }
  }

  /// Creates an IndirectLight from a KTX IBL byte buffer.
  factory FilamentIndirectLight.fromKtx(
    FilamentEngine engine,
    Uint8List ktxBytes, {
    double intensity = 100000.0,
  }) {
    final nativeBuffer = calloc<ffi.Uint8>(ktxBytes.length);
    final nativeList = nativeBuffer.asTypedList(ktxBytes.length);
    nativeList.setAll(0, ktxBytes);

    final ptr = c.filament_indirect_light_create_from_ktx(
      engine.nativePointer,
      nativeBuffer.cast(),
      ktxBytes.length,
      intensity,
    );
    calloc.free(nativeBuffer);

    if (ptr == ffi.nullptr) {
      throw Exception('Failed to create FilamentIndirectLight from KTX bytes');
    }
    return FilamentIndirectLight._(ptr, engine);
  }

  /// Sets the light intensity of this indirect light source in lux (lumen/m²).
  void setIntensity(double intensity) {
    _checkDisposed();
    c.filament_indirect_light_set_intensity(_ptr, intensity);
  }

  /// Gets the light intensity of this indirect light source in lux (lumen/m²).
  double get intensity {
    _checkDisposed();
    return c.filament_indirect_light_get_intensity(_ptr);
  }

  /// Sets the 3x3 rigid-body rotation matrix applied to this IBL.
  set rotation(Matrix3 m) {
    _checkDisposed();
    final rotPtr = calloc<ffi.Float>(9);
    try {
      final list = rotPtr.asTypedList(9);
      final storage = m.storage;
      for (var i = 0; i < 9; i++) {
        list[i] = storage[i];
      }
      c.filament_indirect_light_set_rotation(_ptr, rotPtr);
    } finally {
      calloc.free(rotPtr);
    }
  }

  /// Gets the 3x3 rigid-body rotation matrix applied to this IBL.
  Matrix3 get rotation {
    _checkDisposed();
    final outPtr = calloc<ffi.Float>(9);
    try {
      c.filament_indirect_light_get_rotation(_ptr, outPtr);
      final list = outPtr.asTypedList(9);
      return Matrix3(
        list[0], list[1], list[2],
        list[3], list[4], list[5],
        list[6], list[7], list[8],
      );
    } finally {
      calloc.free(outPtr);
    }
  }

  /// Returns the associated reflections texture, or null if none.
  FilamentTexture? get reflectionsTexture {
    _checkDisposed();
    final texPtr = c.filament_indirect_light_get_reflections_texture(_ptr);
    if (texPtr == ffi.nullptr) return null;
    return FilamentTexture.internal(texPtr, _engine);
  }

  /// Returns the associated irradiance texture, or null if none.
  FilamentTexture? get irradianceTexture {
    _checkDisposed();
    final texPtr = c.filament_indirect_light_get_irradiance_texture(_ptr);
    if (texPtr == ffi.nullptr) return null;
    return FilamentTexture.internal(texPtr, _engine);
  }

  /// Estimates the direction of the dominant light from this IBL's spherical harmonics.
  ///
  /// Points *toward* the dominant light.
  Vector3 getDirectionEstimate() {
    _checkDisposed();
    final outPtr = calloc<ffi.Float>(3);
    try {
      c.filament_indirect_light_get_direction_estimate(_ptr, outPtr);
      final list = outPtr.asTypedList(3);
      return Vector3(list[0], list[1], list[2]);
    } finally {
      calloc.free(outPtr);
    }
  }

  /// Estimates the color and relative intensity of the environment in a given [direction].
  ///
  /// Returns a record with `(Vector3 color, double intensity)` where intensity is
  /// a relative multiplier (multiply by [intensity] for the true lux value).
  (Vector3, double) getColorEstimate(Vector3 direction) {
    _checkDisposed();
    final outPtr = calloc<ffi.Float>(4);
    try {
      c.filament_indirect_light_get_color_estimate(
        _ptr,
        direction.x,
        direction.y,
        direction.z,
        outPtr,
      );
      final list = outPtr.asTypedList(4);
      return (Vector3(list[0], list[1], list[2]), list[3]);
    } finally {
      calloc.free(outPtr);
    }
  }

  /// Derives dominant light direction from a 3-band [SphericalHarmonics] set.
  static Vector3 directionEstimateFromSh(SphericalHarmonics sh) {
    if (sh.bands != 3) {
      throw ArgumentError.value(
        sh.bands,
        'sh.bands',
        'Direction estimation requires exactly 3 spherical harmonics bands (27 floats)',
      );
    }
    final inPtr = calloc<ffi.Float>(27);
    final outPtr = calloc<ffi.Float>(3);
    try {
      inPtr.asTypedList(27).setAll(0, sh.coefficients);
      c.filament_indirect_light_direction_estimate_static(inPtr, outPtr);
      final list = outPtr.asTypedList(3);
      return Vector3(list[0], list[1], list[2]);
    } finally {
      calloc.free(outPtr);
      calloc.free(inPtr);
    }
  }

  /// Derives color and relative intensity from a 3-band [SphericalHarmonics] set in [direction].
  static (Vector3, double) colorEstimateFromSh(
    SphericalHarmonics sh,
    Vector3 direction,
  ) {
    if (sh.bands != 3) {
      throw ArgumentError.value(
        sh.bands,
        'sh.bands',
        'Color estimation requires exactly 3 spherical harmonics bands (27 floats)',
      );
    }
    final inPtr = calloc<ffi.Float>(27);
    final outPtr = calloc<ffi.Float>(4);
    try {
      inPtr.asTypedList(27).setAll(0, sh.coefficients);
      c.filament_indirect_light_color_estimate_static(
        inPtr,
        direction.x,
        direction.y,
        direction.z,
        outPtr,
      );
      final list = outPtr.asTypedList(4);
      return (Vector3(list[0], list[1], list[2]), list[3]);
    } finally {
      calloc.free(outPtr);
      calloc.free(inPtr);
    }
  }

  /// Gets the raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Destroys this IndirectLight.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_indirect_light(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentIndirectLight has been disposed');
    }
  }
}
