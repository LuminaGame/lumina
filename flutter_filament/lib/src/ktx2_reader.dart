import 'ffi_platform.dart' as ffi;
import 'dart:isolate';
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Color space transfer function used when loading KTX2 textures.
enum Ktx2TransferFunction {
  linear(0),
  sRGB(1);

  final int value;
  const Ktx2TransferFunction(this.value);
}

/// Result code from requesting a texture internal format in [Ktx2Reader].
enum Ktx2Result {
  success(0),
  compressedTranscodeFailure(1),
  uncompressedTranscodeFailure(2),
  formatUnsupported(3),
  formatAlreadyRequested(4);

  final int value;
  const Ktx2Result(this.value);

  static Ktx2Result fromValue(int v) {
    switch (v) {
      case 0:
        return Ktx2Result.success;
      case 1:
        return Ktx2Result.compressedTranscodeFailure;
      case 2:
        return Ktx2Result.uncompressedTranscodeFailure;
      case 3:
        return Ktx2Result.formatUnsupported;
      case 4:
        return Ktx2Result.formatAlreadyRequested;
      default:
        return Ktx2Result.formatUnsupported;
    }
  }
}

/// Handles an in-flight asynchronous KTX2 transcoding operation.
///
/// The underlying [FilamentTexture] is created immediately and can be assigned to materials,
/// while transcoding of mipmap levels runs in the background (e.g. via an isolate).
/// Once transcoding completes, call [uploadImages] on the engine thread to push mips to GPU.
class Ktx2AsyncLoad {
  final Ktx2Reader _reader;
  ffi.Pointer<c.FilKtx2Async> _handle;
  final FilamentTexture _texture;
  bool _isDisposed = false;

  Ktx2AsyncLoad._({
    required Ktx2Reader reader,
    required ffi.Pointer<c.FilKtx2Async> handle,
    required FilamentTexture texture,
  })  : _reader = reader,
        _handle = handle,
        _texture = texture;

  /// The [FilamentTexture] being populated.
  FilamentTexture get texture {
    _checkDisposed();
    return _texture;
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Ktx2AsyncLoad has been destroyed');
    }
  }

  /// Synchronously transcodes all mipmaps on the current thread.
  ///
  /// Safe to call from any thread/isolate.
  Ktx2Result doTranscoding() {
    _checkDisposed();
    final res = c.filament_ktx2_async_do_transcoding(_handle);
    return Ktx2Result.fromValue(res);
  }

  /// Transcodes all mipmaps asynchronously in a background Dart [Isolate].
  Future<Ktx2Result> transcode() async {
    _checkDisposed();
    final handleAddr = _handle.address;
    final resInt = await Isolate.run<int>(() {
      final ptr = ffi.Pointer<c.FilKtx2Async>.fromAddress(handleAddr);
      return c.filament_ktx2_async_do_transcoding(ptr);
    });
    return Ktx2Result.fromValue(resInt);
  }

  /// Uploads pending transcoded mipmaps to the GPU.
  ///
  /// MUST be called from the main / engine thread.
  void uploadImages() {
    _checkDisposed();
    c.filament_ktx2_async_upload_images(_handle);
  }

  /// Destroys the async transcoding context.
  ///
  /// Does NOT destroy the associated [texture].
  void destroy() {
    if (_isDisposed) return;
    c.filament_ktx2_reader_async_destroy(_reader._handle, _handle);
    _handle = ffi.nullptr;
    _isDisposed = true;
  }
}

/// Reads and transcodes KTX2 / Basis-Universal textures into native GPU texture formats.
///
/// Priority order recommendation:
/// - Mobile: `[TextureFormat.rgbaAstc4x4, TextureFormat.etc2EacSrgba8, TextureFormat.srgb8A8, TextureFormat.rgba8]`
/// - Desktop: `[TextureFormat.dxt5Srgba, TextureFormat.rgbaBptcUnorm, TextureFormat.srgb8A8, TextureFormat.rgba8]`
class Ktx2Reader {
  final FilamentEngine engine;
  ffi.Pointer<c.FilKtx2Reader> _handle;
  bool _isDisposed = false;

  Ktx2Reader(this.engine, {bool quiet = false})
      : _handle = c.filament_ktx2_reader_create(engine.nativePointer, quiet);

  /// Requests that the reader constructs textures with the given [format].
  ///
  /// Multiple formats can be requested; formats requested earlier have higher priority.
  Ktx2Result requestFormat(TextureFormat format) {
    if (_isDisposed) {
      throw StateError('Ktx2Reader has been destroyed');
    }
    final res = c.filament_ktx2_reader_request_format(_handle, format.value);
    return Ktx2Result.fromValue(res);
  }

  /// Requests a priority-ordered list of formats.
  void requestFormats(List<TextureFormat> formats) {
    for (final f in formats) {
      requestFormat(f);
    }
  }

  /// Removes [format] from the requested formats list.
  void unrequestFormat(TextureFormat format) {
    if (_isDisposed) {
      throw StateError('Ktx2Reader has been destroyed');
    }
    c.filament_ktx2_reader_unrequest_format(_handle, format.value);
  }

  /// Transcodes and constructs a [FilamentTexture] synchronously from binary KTX2 [data].
  ///
  /// Returns null if none of the requested formats could be transcoded or if data is invalid.
  FilamentTexture? load(Uint8List data, Ktx2TransferFunction transfer) {
    if (_isDisposed) {
      throw StateError('Ktx2Reader has been destroyed');
    }
    if (data.isEmpty) return null;

    final dataPtr = calloc<ffi.Uint8>(data.length);
    dataPtr.asTypedList(data.length).setAll(0, data);

    try {
      final texPtr = c.filament_ktx2_reader_load(
        _handle,
        dataPtr,
        data.length,
        transfer.value,
      );

      if (texPtr == ffi.nullptr) {
        return null;
      }

      return FilamentTexture.internal(texPtr, engine);
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Creates an asynchronous transcoding operation for non-blocking texture streaming.
  ///
  /// The returned [Ktx2AsyncLoad] provides a valid [FilamentTexture] immediately,
  /// allowing background transcoding and mipmap uploading.
  Ktx2AsyncLoad? loadAsync(Uint8List data, Ktx2TransferFunction transfer) {
    if (_isDisposed) {
      throw StateError('Ktx2Reader has been destroyed');
    }
    if (data.isEmpty) return null;

    final dataPtr = calloc<ffi.Uint8>(data.length);
    dataPtr.asTypedList(data.length).setAll(0, data);

    try {
      final asyncPtr = c.filament_ktx2_reader_async_create(
        _handle,
        dataPtr,
        data.length,
        transfer.value,
      );

      if (asyncPtr == ffi.nullptr) {
        return null;
      }

      final texPtr = c.filament_ktx2_async_get_texture(asyncPtr);
      if (texPtr == ffi.nullptr) {
        c.filament_ktx2_reader_async_destroy(_handle, asyncPtr);
        return null;
      }

      final texture = FilamentTexture.internal(texPtr, engine);
      return Ktx2AsyncLoad._(
        reader: this,
        handle: asyncPtr,
        texture: texture,
      );
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Convenience helper to stream a texture asynchronously without blocking the UI thread.
  ///
  /// Runs transcoding in a background isolate and uploads mipmaps on the calling isolate.
  Future<FilamentTexture?> loadStreamed(
    Uint8List data,
    Ktx2TransferFunction transfer, {
    void Function()? onMipUploaded,
  }) async {
    final asyncLoad = loadAsync(data, transfer);
    if (asyncLoad == null) return null;

    try {
      final result = await asyncLoad.transcode();
      if (result == Ktx2Result.success) {
        asyncLoad.uploadImages();
        onMipUploaded?.call();
        return asyncLoad.texture;
      } else {
        asyncLoad.texture.dispose();
        return null;
      }
    } finally {
      asyncLoad.destroy();
    }
  }

  /// Destroys the native reader instance.
  void destroy() {
    if (_isDisposed) return;
    c.filament_ktx2_reader_destroy(_handle);
    _handle = ffi.nullptr;
    _isDisposed = true;
  }
}
