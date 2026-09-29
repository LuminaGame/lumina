import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_filament/flutter_filament.dart' show FilamentSkybox;

import '../../object/actor.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';
import 'procedural_sky_binding.dart';

/// A fully procedural sky and ocean: single-pass atmospheric scattering
/// (Preetham & Hoffman), volumetric FBM clouds, a day/night cycle with stars
/// and the Milky Way, and a real-time ocean water reflection.
///
/// This is the runtime form of flutter_filament's "Procedural Sky & Ocean"
/// gallery sample (`example/lib/samples/simulated_skybox_sample.dart`, itself a
/// port of Filament's `web/examples/sky/SimulatedSkybox.js`). The sample's
/// shader is shipped with this package as
/// `packages/lumina/assets/sky/simulated_skybox.filamat`.
///
/// The component is the declarative face of [LuminaProceduralSkyBinding]: it
/// owns the parameters as mutable fields, and the binding owns the GPU
/// resources and the uniform maths. The Lumina Studio level viewport drives the
/// same binding directly, without a world, so the editor and the game cannot
/// render different skies.
///
/// Unlike [LuminaSkyComponent] this does **not** create a Filament `Skybox`:
/// the sky is a full-screen triangle renderable with `depthWrite: false`, which
/// is what lets it animate per frame and what lets a level carry both. Pair it
/// with a [LuminaSkyComponent] (or the editor's Environment actor) when the
/// scene also needs image-based lighting — a procedural sky lights nothing.
class LuminaProceduralSkyComponent extends LuminaSceneComponent {
  /// Hour of the day, 0..24. 12.0 is noon, 0/24 is midnight.
  double timeOfDay;

  /// Atmospheric haze. 1 is a crystal-clear day, 10 is heavy smog.
  double turbidity;

  /// Rayleigh scattering strength — how blue the sky is.
  double rayleigh;

  /// Mie scattering coefficient (forward scattering around the sun).
  double mieCoefficient;

  /// Mie directionality, 0..1. Higher values tighten the sun's halo.
  double mieG;

  /// Cloud cover, 0 (clear) .. 1 (overcast).
  double cloudCoverage;

  /// Cloud opacity.
  double cloudDensity;

  /// Ocean wave strength. 0 disables the water reflection.
  double waterStrength;

  /// Ocean wave speed.
  double waterSpeed;

  /// Simulated hours advanced per real second. 0 freezes the sky at
  /// [timeOfDay]. A multiple of 24 is a no-op: the sky returns to the same
  /// hour every tick.
  double dayCycleSpeed;

  bool _visible;

  /// Overrides the bundled shader/texture reads (tests, or a game that ships
  /// its own variant).
  final Future<Uint8List> Function(String assetKey)? assetProvider;

  /// Whether to load the bundled moon and Milky Way textures. When false (or
  /// when a load fails) 1×1 neutral textures are used, which is enough for the
  /// atmosphere, clouds and ocean.
  final bool loadNightSkyTextures;

  static const String filamatAsset = LuminaProceduralSkyBinding.filamatAsset;
  static const String moonDiskAsset = LuminaProceduralSkyBinding.moonDiskAsset;
  static const String moonNormalAsset = LuminaProceduralSkyBinding.moonNormalAsset;
  static const String milkyWayAsset = LuminaProceduralSkyBinding.milkyWayAsset;

  LuminaProceduralSkyBinding? _binding;
  final Completer<void> _loadCompleter = Completer<void>();

  /// A [FilamentSkybox] this component took off the scene while it is active,
  /// put back on unregister. See [_syncSkyboxSuppression].
  FilamentSkybox? _suppressedSkybox;

  LuminaProceduralSkyComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    this.timeOfDay = 12.0,
    this.turbidity = 2.0,
    this.rayleigh = 1.0,
    this.mieCoefficient = 1.0,
    this.mieG = 0.8,
    this.cloudCoverage = 0.4,
    this.cloudDensity = 0.15,
    this.waterStrength = 30.0,
    this.waterSpeed = 1.0,
    this.dayCycleSpeed = 0.0,
    this.assetProvider,
    this.loadNightSkyTextures = true,
    bool visible = true,
    // ignore: prefer_initializing_formals
  }) : _visible = visible;

  /// Builds a component from a `LuminaProceduralSkyComponent` property map —
  /// what the editor stores on the actor and the `.lmas` round-trips.
  factory LuminaProceduralSkyComponent.fromProperties(
    Map<String, dynamic>? properties, {
    Future<Uint8List> Function(String assetKey)? assetProvider,
    bool loadNightSkyTextures = true,
  }) {
    final d = LuminaProceduralSkyDescription.fromProperties(properties);
    return LuminaProceduralSkyComponent(
      timeOfDay: d.timeOfDay,
      turbidity: d.turbidity,
      rayleigh: d.rayleigh,
      mieCoefficient: d.mieCoefficient,
      mieG: d.mieG,
      cloudCoverage: d.cloudCoverage,
      cloudDensity: d.cloudDensity,
      waterStrength: d.waterStrength,
      waterSpeed: d.waterSpeed,
      dayCycleSpeed: d.dayCycleSpeed,
      visible: d.visible,
      assetProvider: assetProvider,
      loadNightSkyTextures: loadNightSkyTextures,
    );
  }

  /// The current parameters as a value.
  LuminaProceduralSkyDescription get description => LuminaProceduralSkyDescription(
        timeOfDay: timeOfDay,
        turbidity: turbidity,
        rayleigh: rayleigh,
        mieCoefficient: mieCoefficient,
        mieG: mieG,
        cloudCoverage: cloudCoverage,
        cloudDensity: cloudDensity,
        waterStrength: waterStrength,
        waterSpeed: waterSpeed,
        dayCycleSpeed: dayCycleSpeed,
        visible: _visible,
      );

  /// Whether the shader is compiled and the sky renderable is in the scene.
  bool get isLoaded => _binding?.isLoaded ?? false;

  /// Completes once the sky is in the scene (or completes with an error).
  Future<void> get loaded => _loadCompleter.future;

  /// The scene entity carrying the sky triangle, once loaded.
  int? get skyEntity => _binding?.skyEntity;

  /// Unit sun direction for the current [timeOfDay] (+Y is up).
  List<double> get sunDirection => description.sunDirection;

  /// Whether the sun is below the horizon at [timeOfDay].
  bool get isNight => description.isNight;

  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _binding?.apply(description);
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    final w = ownerActor.world;
    if (w == null || !w.hasNativeContext) return;

    final binding = LuminaProceduralSkyBinding(
      engine: w.filamentEngine,
      scene: w.filamentScene,
      assetProvider: assetProvider ?? _bundleAsset,
      loadNightSkyTextures: loadNightSkyTextures,
    );
    _binding = binding;
    unawaited(binding.load(description).then((_) {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }, onError: (Object e, StackTrace st) {
      if (!_loadCompleter.isCompleted) _loadCompleter.completeError(e, st);
    }));
  }

  static Future<Uint8List> _bundleAsset(String key) async {
    final data = await rootBundle.load(key);
    return data.buffer.asUint8List();
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    updateUniforms();
    _syncSkyboxSuppression(world);
  }

  /// Takes the world's `Skybox` off the scene while this sky is visible, and
  /// puts it back when it is not.
  ///
  /// Filament draws a `Skybox` into every pixel nothing wrote depth to, and the
  /// procedural sky is a `depthWrite: false` renderable — so a level carrying
  /// both this and a [LuminaSkyComponent] would show the static skybox painted
  /// straight over the procedural one. The procedural sky is the background;
  /// the sky component is there for the image-based lighting a procedural sky
  /// cannot provide, and that is left completely alone.
  ///
  /// Lumina Studio's level viewport applies the same rule in
  /// `EditorSceneEnvironment.describeLevel`, so the editor and the shipped game
  /// cannot disagree about which sky is visible.
  void _syncSkyboxSuppression(LuminaWorld world) {
    if (!world.hasNativeContext) return;
    final scene = world.filamentScene;
    final active = _visible && (_binding?.isLoaded ?? false);
    if (active) {
      final current = scene.skybox;
      if (current != null) {
        _suppressedSkybox = current;
        scene.setSkybox(null);
      }
    } else {
      _restoreSkybox(world);
    }
  }

  void _restoreSkybox(LuminaWorld world) {
    final held = _suppressedSkybox;
    _suppressedSkybox = null;
    if (held == null || !world.hasNativeContext) return;
    // The sky component may have been unregistered and destroyed its skybox in
    // the meantime; handing a dangling pointer back to the scene would crash.
    if (world.filamentEngine.isValidSkybox(held)) {
      world.filamentScene.setSkybox(held);
    }
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (dayCycleSpeed == 0.0) return;
    timeOfDay = description.advancedTimeOfDay(deltaTime);
  }

  /// Uploads every sky uniform for the current parameters. A no-op before the
  /// component is registered on a world with a native context.
  void updateUniforms() => _binding?.apply(description);

  @override
  void onUnregister() {
    final w = owner?.world;
    if (w != null) _restoreSkybox(w);
    _binding?.dispose();
    _binding = null;
    super.onUnregister();
  }
}
