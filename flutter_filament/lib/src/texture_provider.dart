import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Flags for texture decoding. Matches filament::gltfio::TextureProvider::TextureFlags.
enum TextureProviderFlags {
  none(0),
  srgb(1 << 0);

  final int value;
  const TextureProviderFlags(this.value);
}

/// A provider that decodes image data into Filament textures.
class TextureProvider {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  TextureProvider._(this._ptr, this._engine);

  /// Raw native pointer to the underlying C++ TextureProvider.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Creates a TextureProvider using stb_image (PNG, JPEG, etc.).
  static TextureProvider stb({required FilamentEngine engine}) {
    final ptr = c.filament_gltfio_create_stb_provider(engine.nativePointer);
    return TextureProvider._(ptr, engine);
  }

  /// Creates a TextureProvider using ktx2.
  static TextureProvider ktx2({required FilamentEngine engine}) {
    final ptr = c.filament_gltfio_create_ktx2_provider(engine.nativePointer);
    return TextureProvider._(ptr, engine);
  }

  /// Creates a TextureProvider using WebP. Throws [UnsupportedError] if not compiled with WebP.
  static TextureProvider webp({required FilamentEngine engine}) {
    if (!isWebpSupported()) {
      throw UnsupportedError('WebP is not supported in this Filament build.');
    }
    final ptr = c.filament_gltfio_create_webp_provider(engine.nativePointer);
    return TextureProvider._(ptr, engine);
  }

  /// Returns true if the Filament library was built with WebP support.
  static bool isWebpSupported() {
    return c.filament_gltfio_is_webp_supported();
  }

  /// Pushes image data to the decoding queue.
  /// Note: The [data] bytes must remain valid until decoding is completed.
  FilamentTexture? pushTexture(
    Uint8List data, {
    required String mime,
    TextureProviderFlags flags = TextureProviderFlags.none,
  }) {
    _checkDisposed();
    final ptr = calloc<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    final mimePtr = mime.toNativeUtf8();

    final texPtr = c.filament_gltfio_texture_provider_push_texture(
      _ptr,
      ptr.cast(),
      data.length,
      mimePtr.cast(),
      flags.value,
    );

    calloc.free(mimePtr);
    calloc.free(ptr);

    if (texPtr == ffi.nullptr) {
      return null;
    }
    return FilamentTexture.internal(texPtr, _engine);
  }

  /// Retrieves the next decoded texture from the queue.
  FilamentTexture? popTexture() {
    _checkDisposed();
    final texPtr = c.filament_gltfio_texture_provider_pop_texture(_ptr);
    if (texPtr == ffi.nullptr) return null;
    return FilamentTexture.internal(texPtr, _engine);
  }

  /// Pumps the decoding queue. Must be called repeatedly (usually once per frame).
  void updateQueue() {
    _checkDisposed();
    c.filament_gltfio_texture_provider_update_queue(_ptr);
  }

  /// Blocks until all queued textures have finished decoding.
  void waitForCompletion() {
    _checkDisposed();
    c.filament_gltfio_texture_provider_wait_for_completion(_ptr);
  }

  /// Cancels any pending decode tasks.
  void cancelDecoding() {
    _checkDisposed();
    c.filament_gltfio_texture_provider_cancel_decoding(_ptr);
  }

  /// Gets the number of textures pushed to the queue.
  int get pushedCount {
    _checkDisposed();
    return c.filament_gltfio_texture_provider_get_pushed_count(_ptr);
  }

  /// Gets the number of textures popped from the queue.
  int get poppedCount {
    _checkDisposed();
    return c.filament_gltfio_texture_provider_get_popped_count(_ptr);
  }

  /// Gets the number of textures successfully decoded.
  int get decodedCount {
    _checkDisposed();
    return c.filament_gltfio_texture_provider_get_decoded_count(_ptr);
  }

  /// Gets the last push message (diagnostic).
  String? get pushMessage {
    _checkDisposed();
    final ptr = c.filament_gltfio_texture_provider_get_push_message(_ptr);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Gets the last pop message (diagnostic).
  String? get popMessage {
    _checkDisposed();
    final ptr = c.filament_gltfio_texture_provider_get_pop_message(_ptr);
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Cancels remaining work, drains the queue, and destroys the provider.
  void destroy() {
    if (_disposed) return;
    _disposed = true;
    
    // Drain remaining
    c.filament_gltfio_texture_provider_cancel_decoding(_ptr);
    while (c.filament_gltfio_texture_provider_pop_texture(_ptr) != ffi.nullptr) {}
    
    c.filament_gltfio_texture_provider_destroy(_ptr);
  }

  void dispose() => destroy();

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('TextureProvider has been disposed');
    }
  }

  /// Convenience method to asynchronously decode a single image (e.g. PNG).
  /// This internally creates an STB TextureProvider, pushes the data,
  /// pumps the queue, and yields until completion.
  static Future<FilamentTexture> decodeImage(
    FilamentEngine engine,
    Uint8List data, {
    required String mime,
    bool srgb = false,
  }) async {
    final provider = TextureProvider.stb(engine: engine);
    try {
      final tex = provider.pushTexture(
        data,
        mime: mime,
        flags: srgb ? TextureProviderFlags.srgb : TextureProviderFlags.none,
      );
      if (tex == null) {
        throw StateError('Failed to push texture: ${provider.pushMessage ?? "Unknown error"}');
      }
      
      // Wait asynchronously
      while (true) {
        provider.updateQueue();
        final popped = provider.popTexture();
        if (popped != null) {
          if (popped.nativePointer != tex.nativePointer) {
            // Unlikely to happen in single-texture use case, but handle it
            popped.dispose();
            continue;
          }
          return popped;
        }
        
        if (provider.decodedCount > 0 && provider.poppedCount == 1) {
             throw StateError('Failed to pop texture: ${provider.popMessage ?? "Unknown error"}');
        }

        await Future.delayed(const Duration(milliseconds: 2));
      }
    } finally {
      provider.destroy();
    }
  }
}
