import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Structured representation of an in-memory KTX1 texture bundle.
///
/// Contains one or more mipmap levels, cubemap faces, or array slices, along with key-value metadata.
class Ktx1Bundle {
  ffi.Pointer<c.FilKtx1Bundle> _handle;
  bool _isDisposed = false;

  /// Creates a [Ktx1Bundle] by parsing raw binary KTX1 [bytes].
  ///
  /// Throws [ArgumentError] if the bytes are invalid, corrupted, or not in KTX1 format.
  Ktx1Bundle(Uint8List bytes) : _handle = ffi.nullptr {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Cannot be empty');
    }
    final ptr = calloc<ffi.Uint8>(bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    try {
      _handle = c.filament_ktx1_bundle_create(ptr, bytes.length);
      if (_handle == ffi.nullptr) {
        throw ArgumentError('Failed to parse KTX1 bundle from given bytes');
      }
    } finally {
      calloc.free(ptr);
    }
  }

  /// Creates an empty hierarchy of texture blobs to be populated via [setBlob].
  Ktx1Bundle.empty({
    int numMipLevels = 1,
    int arrayLength = 1,
    bool isCubemap = false,
  }) : _handle = c.filament_ktx1_bundle_create_empty(
          numMipLevels,
          arrayLength,
          isCubemap,
        ) {
    if (_handle == ffi.nullptr) {
      throw StateError('Failed to create empty KTX1 bundle');
    }
  }

  void _checkDisposed() {
    if (_isDisposed || _handle == ffi.nullptr) {
      throw StateError('Ktx1Bundle has been destroyed or consumed');
    }
  }

  /// Number of mip levels stored in this bundle.
  int get numMipLevels {
    _checkDisposed();
    return c.filament_ktx1_bundle_get_num_mip_levels(_handle);
  }

  /// Array length of textures in this bundle.
  int get arrayLength {
    _checkDisposed();
    return c.filament_ktx1_bundle_get_array_length(_handle);
  }

  /// Whether this bundle represents a 6-faced cubemap.
  bool get isCubemap {
    _checkDisposed();
    return c.filament_ktx1_bundle_is_cubemap(_handle);
  }

  /// Size in bytes when serialized to KTX1 format.
  int get serializedLength {
    _checkDisposed();
    return c.filament_ktx1_bundle_get_serialized_length(_handle);
  }

  /// Whether this bundle has been destroyed or consumed by [Ktx1Reader.createTexture].
  bool get isDestroyed => _isDisposed || _handle == ffi.nullptr;

  /// Returns 3 bands of spherical harmonics (9 RGB coefficients = 27 floats) parsed from `key="sh"` metadata.
  ///
  /// Returns null if no valid SH metadata is found.
  Float32List? getSphericalHarmonics() {
    _checkDisposed();
    final outPtr = calloc<ffi.Float>(27);
    try {
      final ok = c.filament_ktx1_bundle_get_spherical_harmonics(_handle, outPtr);
      if (!ok) return null;
      return Float32List.fromList(outPtr.asTypedList(27));
    } finally {
      calloc.free(outPtr);
    }
  }

  /// Retrieves metadata string for the given [key], or null if absent.
  String? getMetadata(String key) {
    _checkDisposed();
    final keyPtr = key.toNativeUtf8();
    try {
      final valPtr = c.filament_ktx1_bundle_get_metadata(_handle, keyPtr.cast());
      if (valPtr == ffi.nullptr) return null;
      return valPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(keyPtr);
    }
  }

  /// Sets metadata [key] to [value].
  void setMetadata(String key, String value) {
    _checkDisposed();
    final keyPtr = key.toNativeUtf8();
    final valPtr = value.toNativeUtf8();
    try {
      c.filament_ktx1_bundle_set_metadata(_handle, keyPtr.cast(), valPtr.cast());
    } finally {
      calloc.free(keyPtr);
      calloc.free(valPtr);
    }
  }

  /// Copies [data] into the blob at the specified [mipLevel] and [face].
  bool setBlob({
    required int mipLevel,
    required int face,
    required Uint8List data,
  }) {
    _checkDisposed();
    if (data.isEmpty) return false;
    final ptr = calloc<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    try {
      return c.filament_ktx1_bundle_set_blob(
        _handle,
        mipLevel,
        face,
        ptr,
        data.length,
      );
    } finally {
      calloc.free(ptr);
    }
  }

  /// Returns a copy of the blob stored at [mipLevel] / [face], or null if
  /// the bundle has no data there.
  Uint8List? getBlob({required int mipLevel, required int face}) {
    _checkDisposed();
    final dataPtr = calloc<ffi.Pointer<ffi.Uint8>>();
    final sizePtr = calloc<ffi.Uint32>();
    try {
      final ok = c.filament_ktx1_bundle_get_blob(_handle, mipLevel, face, dataPtr, sizePtr);
      if (!ok || dataPtr.value == ffi.nullptr || sizePtr.value == 0) return null;
      return Uint8List.fromList(dataPtr.value.asTypedList(sizePtr.value));
    } finally {
      calloc.free(dataPtr);
      calloc.free(sizePtr);
    }
  }

  /// Serializes the entire bundle into a KTX1 binary byte buffer.
  Uint8List serialize() {
    _checkDisposed();
    final len = serializedLength;
    if (len == 0) return Uint8List(0);
    final outPtr = calloc<ffi.Uint8>(len);
    try {
      final ok = c.filament_ktx1_bundle_serialize(_handle, outPtr, len);
      if (!ok) {
        throw StateError('Failed to serialize Ktx1Bundle');
      }
      return Uint8List.fromList(outPtr.asTypedList(len));
    } finally {
      calloc.free(outPtr);
    }
  }

  /// Destroys this bundle manually.
  void destroy() {
    if (_isDisposed) return;
    if (_handle != ffi.nullptr) {
      c.filament_ktx1_bundle_destroy(_handle);
      _handle = ffi.nullptr;
    }
    _isDisposed = true;
  }
}

/// Utility to construct Filament textures from KTX1 bundles.
class Ktx1Reader {
  /// Creates a [FilamentTexture] from [bundle] and uploads all faces and mip levels.
  ///
  /// IMPORTANT: Calling this transfers ownership of the underlying native bundle
  /// to the engine upload pipeline. The [bundle] is marked as consumed/destroyed
  /// and cannot be accessed after this call.
  static FilamentTexture? createTexture(
    FilamentEngine engine,
    Ktx1Bundle bundle, {
    required bool srgb,
  }) {
    bundle._checkDisposed();
    final handle = bundle._handle;
    final texPtr = c.filament_ktx1_reader_create_texture(
      engine.nativePointer,
      handle,
      srgb,
    );

    // Bundle was consumed / destroyed by C++
    c.filament_ktx1_bundle_destroy(handle);
    bundle._handle = ffi.nullptr;
    bundle._isDisposed = true;

    if (texPtr == ffi.nullptr) {
      return null;
    }

    return FilamentTexture.internal(texPtr, engine);
  }
}
