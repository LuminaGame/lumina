import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../object/actor.dart';
import '../../utility/lumina_assets.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';

/// Environment skybox and Image-Based Lighting (IBL) indirect light component for a world.
class LuminaSkyComponent extends LuminaSceneComponent {
  final bool isColorMode;
  Vector4? _color;
  final String? environmentAssetPath;
  final String? skyboxAssetPath;
  final bool showSun;
  final Future<Uint8List> Function(String path)? assetProvider;

  double skyIntensity;
  double _iblIntensity;
  final SphericalHarmonics? _ambientSh;
  double rotationDegrees = 0.0;
  double? _lastSyncedRotationDegrees;
  bool _visible;

  FilamentSkybox? _skybox;
  FilamentIndirectLight? _indirectLight;
  FilamentTexture? _envTexture;
  FilamentTexture? _skyboxTexture;

  bool _isLoaded = false;
  final Completer<void> _loadCompleter = Completer<void>();

  /// Creates a solid color skybox with optional ambient spherical harmonics.
  LuminaSkyComponent.color({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required Vector4 color,
    this.skyIntensity = 30000.0,
    this._ambientSh,
    this._iblIntensity = 30000.0,
    this._visible = true,
  }) : isColorMode = true,
       _color = Vector4.copy(color),
       environmentAssetPath = null,
       skyboxAssetPath = null,
       showSun = false,
       assetProvider = null;

  /// Creates an image-based HDRI skybox and IBL indirect light from KTX1/KTX2 assets.
  LuminaSkyComponent.environment({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required this.environmentAssetPath,
    this.skyboxAssetPath,
    this.showSun = false,
    this.assetProvider,
    this.skyIntensity = 30000.0,
    this._iblIntensity = 30000.0,
    this._visible = true,
  }) : isColorMode = false,
       _color = null,
       _ambientSh = null;

  /// Whether asynchronous asset loading and native binding is complete.
  bool get isLoaded => _isLoaded;

  /// Future completing when the environment finishes loading and binding.
  Future<void> get loaded => _loadCompleter.future;

  /// Active solid color in color mode (throws [StateError] in environment mode).
  Vector4 get color {
    if (!isColorMode) {
      throw StateError('Cannot access color in environment mode');
    }
    return _color ?? Vector4(0, 0, 0, 1);
  }

  set color(Vector4 value) {
    if (!isColorMode) {
      throw StateError('Cannot set color in environment mode');
    }
    _color = Vector4.copy(value);
    _skybox?.color = _color!;
  }

  /// IBL ambient indirect light intensity in lux.
  double get iblIntensity => _iblIntensity;
  set iblIntensity(double value) {
    _iblIntensity = value;
    _indirectLight?.setIntensity(value);
  }

  /// Whether the skybox is visible in the background.
  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _updateVisibility();
  }

  void _updateVisibility() {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) return;
    final scene = w.filamentScene;
    if (_visible) {
      scene.setSkybox(_skybox);
    } else {
      scene.setSkybox(null);
    }
  }

  /// Derives estimated dominant sun light direction, color, and scaled intensity from the environment's SH.
  ({Vector3 direction, Vector3 color, double intensity}) deriveSunLight() {
    final indirectLight = _indirectLight;
    if (indirectLight != null) {
      final dir = indirectLight.getDirectionEstimate();
      final (col, relIntensity) = indirectLight.getColorEstimate(dir);
      return (direction: dir, color: col, intensity: relIntensity * _iblIntensity);
    }
    final ambientSh = _ambientSh;
    if (ambientSh != null && ambientSh.bands == 3) {
      final dir = FilamentIndirectLight.directionEstimateFromSh(ambientSh);
      final (col, relIntensity) = FilamentIndirectLight.colorEstimateFromSh(ambientSh, dir);
      return (direction: dir, color: col, intensity: relIntensity * _iblIntensity);
    }
    throw StateError('Cannot derive sun light without a 3-band spherical harmonics or loaded IndirectLight');
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);

    final w = ownerActor.world;
    if (w != null && w.hasNativeContext) {
      final scene = w.filamentScene;
      if (scene.skybox != null || scene.indirectLight != null) {
        throw StateError('A sky component is already active in this world');
      }
      _buildSky();
    }
  }

  Future<void> _buildSky() async {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) return;
    final engine = w.filamentEngine;
    final scene = w.filamentScene;

    try {
      if (isColorMode) {
        final c = _color ?? Vector4(0, 0, 0, 1);
        _skybox = FilamentSkybox.build(
          engine,
          color: c,
          intensity: skyIntensity,
        );

        // Derive 1-band default SH from color if none provided
        final sh = _ambientSh ??
            SphericalHarmonics(
              bands: 1,
              coefficients: [c.x, c.y, c.z],
            );

        _indirectLight = FilamentIndirectLight.build(
          engine,
          irradiance: sh,
          intensity: _iblIntensity,
        );

        if (_visible) {
          scene.setSkybox(_skybox);
        }
        scene.setIndirectLight(_indirectLight);

        _isLoaded = true;
        if (!_loadCompleter.isCompleted) {
          _loadCompleter.complete();
        }
      } else {
        await _loadEnvironmentAssets(engine, scene);
      }
    } catch (e, st) {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.completeError(e, st);
      }
    }
  }

  Future<void> _loadEnvironmentAssets(FilamentEngine engine, FilamentScene scene) async {
    final envPath = environmentAssetPath!;
    final envBytes = await LuminaAssets.resolve(assetProvider)(envPath);

    if (envPath.endsWith('.ktx2')) {
      final reader = Ktx2Reader(engine)
        ..requestFormats([
          TextureFormat.rgb8,
          TextureFormat.rgba8,
          TextureFormat.rgb16f,
          TextureFormat.rgba16f,
        ]);
      _envTexture = reader.load(envBytes, Ktx2TransferFunction.sRGB);
      reader.destroy();
      _skyboxTexture = _envTexture;

      _skybox = FilamentSkybox.build(
        engine,
        environment: _skyboxTexture,
        showSun: showSun,
        intensity: skyIntensity,
      );
      _indirectLight = FilamentIndirectLight.build(
        engine,
        reflections: _envTexture,
        intensity: _iblIntensity,
      );
    } else {
      final bundle = Ktx1Bundle(envBytes);
      final shFloats = bundle.getSphericalHarmonics();
      final SphericalHarmonics? shObj =
          shFloats != null ? SphericalHarmonics(bands: 3, coefficients: shFloats) : null;

      _envTexture = Ktx1Reader.createTexture(engine, bundle, srgb: true);
      _skyboxTexture = _envTexture;

      _skybox = FilamentSkybox.build(
        engine,
        environment: _skyboxTexture,
        showSun: showSun,
        intensity: skyIntensity,
      );
      _indirectLight = FilamentIndirectLight.build(
        engine,
        reflections: _envTexture,
        irradiance: shObj,
        intensity: _iblIntensity,
      );
    }

    if (_visible) {
      scene.setSkybox(_skybox);
    }
    scene.setIndirectLight(_indirectLight);

    _isLoaded = true;
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    if (_indirectLight == null || !world.hasNativeContext) return;

    if (_lastSyncedRotationDegrees != rotationDegrees) {
      final rad = rotationDegrees * math.pi / 180.0;
      _indirectLight!.rotation = Matrix3.rotationY(rad);
      _lastSyncedRotationDegrees = rotationDegrees;
    }
  }

  @override
  void onUnregister() {
    final w = owner?.world;
    if (w != null && w.hasNativeContext) {
      final scene = w.filamentScene;
      scene.setSkybox(null);
      scene.setIndirectLight(null);

      _skybox?.dispose();
      _skybox = null;

      _indirectLight?.dispose();
      _indirectLight = null;

      if (_skyboxTexture != null && _skyboxTexture != _envTexture) {
        _skyboxTexture?.dispose();
      }
      _skyboxTexture = null;

      _envTexture?.dispose();
      _envTexture = null;
    }
    super.onUnregister();
  }
}
