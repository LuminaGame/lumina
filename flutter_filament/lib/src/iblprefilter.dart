import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Filter kernel distribution used by specular and irradiance prefiltering.
enum SpecularFilterKernel {
  dGgx(0);

  final int value;
  const SpecularFilterKernel(this.value);
}

/// Configuration settings for [SpecularFilter].
class SpecularFilterConfig {
  /// Number of integration samples per pixel (max 2048).
  final int sampleCount;

  /// Number of roughness mipmap levels to generate.
  final int levelCount;

  /// Distribution kernel to evaluate.
  final SpecularFilterKernel kernel;

  SpecularFilterConfig({
    this.sampleCount = 1024,
    this.levelCount = 5,
    this.kernel = SpecularFilterKernel.dGgx,
  }) {
    if (sampleCount > 2048) {
      throw ArgumentError.value(sampleCount, 'sampleCount', 'sampleCount must be <= 2048');
    }
  }
}

/// Dynamic HDR filtering options for [SpecularFilter].
class SpecularFilterOptions {
  final double hdrLinear;
  final double hdrMax;
  final double lodOffset;
  final bool generateMipmap;

  const SpecularFilterOptions({
    this.hdrLinear = 1024.0,
    this.hdrMax = 16384.0,
    this.lodOffset = 1.0,
    this.generateMipmap = true,
  });
}

/// Configuration settings for [IrradianceFilter].
class IrradianceFilterConfig {
  /// Number of integration samples per pixel (max 2048).
  final int sampleCount;

  /// Distribution kernel to evaluate.
  final SpecularFilterKernel kernel;

  IrradianceFilterConfig({
    this.sampleCount = 1024,
    this.kernel = SpecularFilterKernel.dGgx,
  }) {
    if (sampleCount > 2048) {
      throw ArgumentError.value(sampleCount, 'sampleCount', 'sampleCount must be <= 2048');
    }
  }
}

/// Dynamic HDR filtering options for [IrradianceFilter].
class IrradianceFilterOptions {
  final double hdrLinear;
  final double hdrMax;
  final double lodOffset;
  final bool generateMipmap;

  const IrradianceFilterOptions({
    this.hdrLinear = 1024.0,
    this.hdrMax = 16384.0,
    this.lodOffset = 2.0,
    this.generateMipmap = true,
  });
}

/// Manages shared GPU state and shaders used by IBL prefiltering operations.
class IblPrefilterContext {
  final FilamentEngine engine;
  ffi.Pointer<c.FilIblPrefilterContext> _handle;
  bool _isDisposed = false;

  IblPrefilterContext(this.engine)
      : _handle = c.filament_iblprefilter_context_create(engine.nativePointer) {
    if (_handle == ffi.nullptr) {
      throw StateError('Failed to create IblPrefilterContext');
    }
  }

  void _checkDisposed() {
    if (_isDisposed || _handle == ffi.nullptr) {
      throw StateError('IblPrefilterContext has been destroyed');
    }
  }

  /// Destroys GPU state held by this context.
  void destroy() {
    if (_isDisposed) return;
    if (_handle != ffi.nullptr) {
      c.filament_iblprefilter_context_destroy(_handle);
      _handle = ffi.nullptr;
    }
    _isDisposed = true;
  }
}

/// Converts a 2D equirectangular panorama texture into a 6-faced cubemap on the GPU.
class EquirectangularToCubemap {
  final IblPrefilterContext context;
  ffi.Pointer<c.FilEquirectToCubemap> _handle;
  bool _isDisposed = false;

  EquirectangularToCubemap(this.context, {bool mirror = true})
      : _handle = ffi.nullptr {
    context._checkDisposed();
    _handle = c.filament_equirect_to_cubemap_create(context._handle, mirror);
    if (_handle == ffi.nullptr) {
      throw StateError('Failed to create EquirectangularToCubemap');
    }
  }

  void _checkDisposed() {
    if (_isDisposed || _handle == ffi.nullptr) {
      throw StateError('EquirectangularToCubemap has been destroyed');
    }
  }

  /// Converts [equirect] texture to a cubemap.
  ///
  /// If [outCubemap] is omitted, a 256x256 cubemap with 9 mip levels is allocated.
  /// The caller owns the returned texture and is responsible for destroying it.
  FilamentTexture run(FilamentTexture equirect, {FilamentTexture? outCubemap}) {
    _checkDisposed();
    context._checkDisposed();

    final outPtr = c.filament_equirect_to_cubemap_run(
      _handle,
      equirect.nativePointer,
      outCubemap?.nativePointer ?? ffi.nullptr,
    );

    if (outPtr == ffi.nullptr) {
      throw StateError('EquirectangularToCubemap conversion failed');
    }

    if (outCubemap != null) {
      return outCubemap;
    }

    return FilamentTexture.internal(outPtr, context.engine);
  }

  /// Destroys this converter.
  void destroy() {
    if (_isDisposed) return;
    if (_handle != ffi.nullptr) {
      c.filament_equirect_to_cubemap_destroy(_handle);
      _handle = ffi.nullptr;
    }
    _isDisposed = true;
  }
}

/// Prefilters an environment cubemap into specular reflection mipmaps according to roughness.
class SpecularFilter {
  final IblPrefilterContext context;
  final SpecularFilterConfig config;
  ffi.Pointer<c.FilSpecularFilter> _handle;
  bool _isDisposed = false;

  SpecularFilter(this.context, [SpecularFilterConfig? config])
      : config = config ?? SpecularFilterConfig(),
        _handle = ffi.nullptr {
    context._checkDisposed();
    if (this.config.sampleCount > 2048) {
      throw ArgumentError.value(
        this.config.sampleCount,
        'sampleCount',
        'Cannot exceed 2048',
      );
    }
    _handle = c.filament_specular_filter_create_config(
      context._handle,
      this.config.sampleCount,
      this.config.levelCount,
      this.config.kernel.value,
    );
    if (_handle == ffi.nullptr) {
      throw StateError('Failed to create SpecularFilter');
    }
  }

  void _checkDisposed() {
    if (_isDisposed || _handle == ffi.nullptr) {
      throw StateError('SpecularFilter has been destroyed');
    }
  }

  /// Runs specular prefiltering on [environment] cubemap.
  ///
  /// Returns the prefiltered specular cubemap texture (e.g. for `IndirectLight.reflections`).
  FilamentTexture run(
    FilamentTexture environment, {
    FilamentTexture? outReflections,
    SpecularFilterOptions? options,
  }) {
    _checkDisposed();
    context._checkDisposed();
    final opt = options ?? const SpecularFilterOptions();

    final outPtr = c.filament_specular_filter_run(
      _handle,
      environment.nativePointer,
      outReflections?.nativePointer ?? ffi.nullptr,
      opt.hdrLinear,
      opt.hdrMax,
      opt.lodOffset,
      opt.generateMipmap,
    );

    if (outPtr == ffi.nullptr) {
      throw StateError('SpecularFilter prefiltering failed');
    }

    if (outReflections != null) {
      return outReflections;
    }

    return FilamentTexture.internal(outPtr, context.engine);
  }

  /// Destroys this filter instance.
  void destroy() {
    if (_isDisposed) return;
    if (_handle != ffi.nullptr) {
      c.filament_specular_filter_destroy(_handle);
      _handle = ffi.nullptr;
    }
    _isDisposed = true;
  }
}

/// Generates a diffuse irradiance cubemap from an environment cubemap on the GPU.
class IrradianceFilter {
  final IblPrefilterContext context;
  final IrradianceFilterConfig config;
  ffi.Pointer<c.FilIrradianceFilter> _handle;
  bool _isDisposed = false;

  IrradianceFilter(this.context, [IrradianceFilterConfig? config])
      : config = config ?? IrradianceFilterConfig(),
        _handle = ffi.nullptr {
    context._checkDisposed();
    if (this.config.sampleCount > 2048) {
      throw ArgumentError.value(
        this.config.sampleCount,
        'sampleCount',
        'Cannot exceed 2048',
      );
    }
    _handle = c.filament_irradiance_filter_create_config(
      context._handle,
      this.config.sampleCount,
      this.config.kernel.value,
    );
    if (_handle == ffi.nullptr) {
      throw StateError('Failed to create IrradianceFilter');
    }
  }

  void _checkDisposed() {
    if (_isDisposed || _handle == ffi.nullptr) {
      throw StateError('IrradianceFilter has been destroyed');
    }
  }

  /// Generates an irradiance cubemap from [environment].
  FilamentTexture run(
    FilamentTexture environment, {
    FilamentTexture? outIrradiance,
    IrradianceFilterOptions? options,
  }) {
    _checkDisposed();
    context._checkDisposed();
    final opt = options ?? const IrradianceFilterOptions();

    final outPtr = c.filament_irradiance_filter_run(
      _handle,
      environment.nativePointer,
      outIrradiance?.nativePointer ?? ffi.nullptr,
      opt.hdrLinear,
      opt.hdrMax,
      opt.lodOffset,
      opt.generateMipmap,
    );

    if (outPtr == ffi.nullptr) {
      throw StateError('IrradianceFilter prefiltering failed');
    }

    if (outIrradiance != null) {
      return outIrradiance;
    }

    return FilamentTexture.internal(outPtr, context.engine);
  }

  /// Destroys this filter instance.
  void destroy() {
    if (_isDisposed) return;
    if (_handle != ffi.nullptr) {
      c.filament_irradiance_filter_destroy(_handle);
      _handle = ffi.nullptr;
    }
    _isDisposed = true;
  }
}
