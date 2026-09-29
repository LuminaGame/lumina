import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';

import 'engine.dart';
import 'texture.dart';
import 'filament_bindings.dart' as c;

/// A Skybox fills all untouched background pixels in a scene.
///
/// Can be configured with an environment cubemap texture or a solid color,
/// with optional sun disk rendering and rendering priority.
class FilamentSkybox {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  FilamentSkybox._(this._ptr, this._engine);

  /// Internal constructor.
  FilamentSkybox.internal(this._ptr, this._engine);

  /// Constructs a [FilamentSkybox] with full builder parameters.
  ///
  /// - [environment]: Environment cubemap texture (mutually exclusive with [color]).
  /// - [color]: Solid RGBA background color.
  /// - [showSun]: Whether to render the sun disk of the brightest directional sun light.
  /// - [intensity]: Skybox intensity in lux / cd/m² (default = 30000).
  /// - [priority]: Render priority band (0..7, where 7 is rendered last/lowest priority).
  factory FilamentSkybox.build(
    FilamentEngine engine, {
    FilamentTexture? environment,
    Vector4? color,
    bool showSun = false,
    double intensity = 30000.0,
    int priority = 7,
  }) {
    if (priority < 0 || priority > 7) {
      throw ArgumentError.value(
        priority,
        'priority',
        'Skybox priority must be between 0 and 7',
      );
    }
    if (environment != null && color != null) {
      throw ArgumentError(
        'Skybox cannot specify both an environment texture and a solid color',
      );
    }

    final cColor = color ?? Vector4(0.0, 0.0, 0.0, 1.0);

    final ptr = c.filament_skybox_create_ex(
      engine.nativePointer,
      environment != null ? environment.nativePointer : ffi.nullptr,
      cColor.x,
      cColor.y,
      cColor.z,
      cColor.w,
      showSun,
      intensity,
      priority,
    );

    if (ptr == ffi.nullptr) {
      throw Exception('Failed to build FilamentSkybox');
    }

    return FilamentSkybox._(ptr, engine);
  }

  /// Creates a solid color Skybox.
  static FilamentSkybox createColor({
    required FilamentEngine engine,
    double r = 0.0,
    double g = 0.0,
    double b = 0.0,
    double a = 1.0,
  }) {
    final ptr = c.filament_skybox_create_color(
      engine.nativePointer,
      r,
      g,
      b,
      a,
    );
    return FilamentSkybox.internal(ptr, engine);
  }

  /// Creates a Skybox from a KTX environment texture byte buffer.
  factory FilamentSkybox.fromKtx(
    FilamentEngine engine,
    Uint8List ktxBytes, {
    bool showSun = true,
  }) {
    final nativeBuffer = calloc<ffi.Uint8>(ktxBytes.length);
    final nativeList = nativeBuffer.asTypedList(ktxBytes.length);
    nativeList.setAll(0, ktxBytes);

    final ptr = c.filament_skybox_create_from_ktx(
      engine.nativePointer,
      nativeBuffer.cast(),
      ktxBytes.length,
      showSun,
    );
    calloc.free(nativeBuffer);

    if (ptr == ffi.nullptr) {
      throw Exception('Failed to create FilamentSkybox from KTX bytes');
    }
    return FilamentSkybox.internal(ptr, engine);
  }

  /// Sets the solid color of this Skybox at runtime (fades/transitions).
  set color(Vector4 col) {
    _checkDisposed();
    c.filament_skybox_set_color(_ptr, col.x, col.y, col.z, col.w);
  }

  /// Sets the solid color with individual RGBA components.
  void setColor({
    double r = 0.0,
    double g = 0.0,
    double b = 0.0,
    double a = 1.0,
  }) {
    _checkDisposed();
    c.filament_skybox_set_color(_ptr, r, g, b, a);
  }

  /// Sets layer mask visibility bits on this Skybox.
  void setLayerMask({required int select, required int values}) {
    _checkDisposed();
    if (select < 0 || select > 255 || values < 0 || values > 255) {
      throw ArgumentError('Layer mask select and values must fit in an 8-bit unsigned integer (0..255)');
    }
    c.filament_skybox_set_layer_mask(_ptr, select, values);
  }

  /// Gets the layer mask visibility bits.
  int get layerMask {
    _checkDisposed();
    return c.filament_skybox_get_layer_mask(_ptr);
  }

  /// Gets the skybox intensity in lux / cd/m².
  double get intensity {
    _checkDisposed();
    return c.filament_skybox_get_intensity(_ptr);
  }

  /// Gets the associated environment texture, or null if this is a solid color skybox.
  FilamentTexture? get texture {
    _checkDisposed();
    final texPtr = c.filament_skybox_get_texture(_ptr);
    if (texPtr == ffi.nullptr) return null;
    return FilamentTexture.internal(texPtr, _engine);
  }

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Destroys this Skybox.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_skybox(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentSkybox has been disposed');
    }
  }
}
