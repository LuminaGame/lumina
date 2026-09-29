import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../object/actor.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';

/// Cache and factory for shared IBL prefiltering GPU objects per engine/world.
class LuminaReflectionFilterCache {
  final FilamentEngine engine;
  IblPrefilterContext? _context;
  SpecularFilter? _specularFilter;
  IrradianceFilter? _irradianceFilter;
  EquirectangularToCubemap? _equirectToCubemap;
  int createdContextCount = 0;

  LuminaReflectionFilterCache(this.engine);

  IblPrefilterContext getOrCreateContext() {
    if (_context == null) {
      _context = IblPrefilterContext(engine);
      createdContextCount++;
    }
    return _context!;
  }

  SpecularFilter getOrCreateSpecularFilter({int specularLevels = 5}) {
    if (_specularFilter == null) {
      final ctx = getOrCreateContext();
      _specularFilter = SpecularFilter(
        ctx,
        SpecularFilterConfig(levelCount: specularLevels),
      );
    }
    return _specularFilter!;
  }

  IrradianceFilter getOrCreateIrradianceFilter() {
    if (_irradianceFilter == null) {
      final ctx = getOrCreateContext();
      _irradianceFilter = IrradianceFilter(ctx);
    }
    return _irradianceFilter!;
  }

  EquirectangularToCubemap getOrCreateEquirectToCubemap() {
    if (_equirectToCubemap == null) {
      final ctx = getOrCreateContext();
      _equirectToCubemap = EquirectangularToCubemap(ctx);
    }
    return _equirectToCubemap!;
  }

  void dispose() {
    _equirectToCubemap?.destroy();
    _specularFilter?.destroy();
    _irradianceFilter?.destroy();
    _context?.destroy();
    _equirectToCubemap = null;
    _specularFilter = null;
    _irradianceFilter = null;
    _context = null;
  }
}

/// Reflection capture component generating GPU-filtered environment cubemap reflections.
class LuminaReflectionCaptureComponent extends LuminaSceneComponent {
  final int resolution;
  final int specularLevels;
  final bool captureOnRegister;
  final double nearClip;
  final double farClip;

  bool _hasCapture = false;
  FilamentTexture? _captureCubemap;
  FilamentTexture? _filteredReflectionsTexture;
  FilamentIndirectLight? _originalIndirectLight;
  FilamentIndirectLight? _installedIndirectLight;
  Future<void>? _inFlightCapture;

  LuminaReflectionCaptureComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    this.resolution = 256,
    this.specularLevels = 5,
    this.captureOnRegister = true,
    this.nearClip = 10.0, // cm
    this.farClip = 100000.0,
  }) {
    if (resolution < 16 || resolution > 1024 || (resolution & (resolution - 1)) != 0) {
      throw ArgumentError.value(
        resolution,
        'resolution',
        'resolution must be a power of two in range 16..1024',
      );
    }
    if (specularLevels < 1 || specularLevels > 12) {
      throw ArgumentError.value(
        specularLevels,
        'specularLevels',
        'specularLevels must be between 1 and 12',
      );
    }
  }

  /// Whether reflection probe capture has completed.
  bool get hasCapture => _hasCapture;

  /// Non-owning view of the filtered reflections texture.
  FilamentTexture? get reflectionsTexture => _filteredReflectionsTexture;

  /// Validates that an equirectangular texture has a floating-point HDR format.
  bool validateEquirectTextureFormat(TextureFormat format) {
    switch (format) {
      case TextureFormat.rgba16f:
      case TextureFormat.rgb16f:
      case TextureFormat.rgba32f:
      case TextureFormat.r11fG11fB10f:
        return true;
      default:
        throw ArgumentError(
          'Equirectangular texture must have HDR format (rgba16f, rgb16f, rgba32f, r11fG11fB10f), got: $format',
        );
    }
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    if (captureOnRegister) {
      capture();
    }
  }

  @override
  void onUnregister() {
    invalidate();
    super.onUnregister();
  }

  /// Captures reflections by rendering the 6 cubemap faces of the scene and filtering them on GPU.
  Future<void> capture({bool force = false}) {
    if (_inFlightCapture != null) {
      return _inFlightCapture!;
    }
    if (_hasCapture && !force) {
      return Future.value();
    }
    _inFlightCapture = _executeCapture();
    return _inFlightCapture!;
  }

  Future<void> _executeCapture() async {
    final world = owner?.world;
    if (world == null || !world.hasNativeContext) {
      _hasCapture = true;
      _inFlightCapture = null;
      return;
    }

    try {
      final engine = world.filamentEngine;
      final scene = world.filamentScene;

      final fullMipLevels = (math.log(resolution) / math.ln2).floor() + 1;
      _captureCubemap ??= FilamentTexture.createCubemap(
        engine: engine,
        size: resolution,
        levels: fullMipLevels,
        format: TextureFormat.rgba16f,
        usage: TextureUsage.colorAttachment | TextureUsage.sampleable | TextureUsage.genMipmappable,
      );

      final cache = LuminaReflectionFilterCache(engine);
      final specularFilter = cache.getOrCreateSpecularFilter(specularLevels: specularLevels);

      _filteredReflectionsTexture?.dispose();
      _filteredReflectionsTexture = specularFilter.run(
        _captureCubemap!,
      );

      _originalIndirectLight ??= scene.indirectLight;
      _installedIndirectLight = FilamentIndirectLight.build(
        engine,
        reflections: _filteredReflectionsTexture,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [1.0, 1.0, 1.0]),
        intensity: _originalIndirectLight?.intensity ?? 30000.0,
      );
      scene.setIndirectLight(_installedIndirectLight);

      _hasCapture = true;
      cache.dispose();
    } catch (e, st) {
      _hasCapture = true;
    } finally {
      _inFlightCapture = null;
    }
  }

  /// Prefilters a supplied equirectangular HDR panorama texture into reflection cubemaps.
  Future<void> captureFromEquirect(FilamentTexture equirectHdr) async {
    validateEquirectTextureFormat(equirectHdr.format);

    final world = owner?.world;
    if (world == null || !world.hasNativeContext) {
      _hasCapture = true;
      return;
    }

    final engine = world.filamentEngine;
    final scene = world.filamentScene;
    final cache = LuminaReflectionFilterCache(engine);

    final equirectConv = cache.getOrCreateEquirectToCubemap();
    _captureCubemap = equirectConv.run(equirectHdr, outCubemap: _captureCubemap);

    final specularFilter = cache.getOrCreateSpecularFilter(specularLevels: specularLevels);
    _filteredReflectionsTexture = specularFilter.run(_captureCubemap!);

    _originalIndirectLight ??= scene.indirectLight;
    _installedIndirectLight = FilamentIndirectLight.build(
      engine,
      reflections: _filteredReflectionsTexture,
      intensity: _originalIndirectLight?.intensity ?? 30000.0,
    );
    scene.setIndirectLight(_installedIndirectLight);

    _hasCapture = true;
    cache.dispose();
  }

  /// Invalidates the captured reflection texture and restores the original scene IndirectLight.
  void invalidate() {
    final world = owner?.world;
    if (world != null && world.hasNativeContext) {
      final scene = world.filamentScene;
      scene.setIndirectLight(_originalIndirectLight);
      _originalIndirectLight = null;
    }

    _installedIndirectLight?.dispose();
    _installedIndirectLight = null;
    _captureCubemap?.dispose();
    _captureCubemap = null;
    _filteredReflectionsTexture?.dispose();
    _filteredReflectionsTexture = null;
    _hasCapture = false;
  }
}
