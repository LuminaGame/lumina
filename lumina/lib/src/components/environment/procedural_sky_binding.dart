import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_filament/filament.dart';

/// Immutable description of a procedural sky and ocean.
///
/// This is the value type the editor's `ProceduralSky` actor speaks: it is
/// parsed straight out of a `LuminaProceduralSkyComponent` property map — the
/// map the Details panel writes onto the actor and the `.lmas` level file — so
/// the editor viewport, the runtime component and the code generator all agree
/// on what a level's procedural sky is.
class LuminaProceduralSkyDescription {
  /// Hour of the day, 0..24. 12.0 is noon, 0/24 is midnight.
  final double timeOfDay;

  /// Atmospheric haze. 1 is a crystal-clear day, 10 is heavy smog.
  final double turbidity;

  /// Rayleigh scattering strength — how blue the sky is.
  final double rayleigh;

  /// Mie scattering coefficient (forward scattering around the sun).
  final double mieCoefficient;

  /// Mie directionality, 0..1. Higher values tighten the sun's halo.
  final double mieG;

  /// Cloud cover, 0 (clear) .. 1 (overcast).
  final double cloudCoverage;

  /// Cloud opacity.
  final double cloudDensity;

  /// Ocean wave strength. 0 disables the water reflection.
  final double waterStrength;

  /// Ocean wave speed.
  final double waterSpeed;

  /// Simulated hours advanced per real second. 0 freezes the sky.
  final double dayCycleSpeed;

  /// Whether the sky renders at all.
  final bool visible;

  const LuminaProceduralSkyDescription({
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
    this.visible = true,
  });

  /// A clear midday sky with an animated ocean and a frozen day cycle.
  static const LuminaProceduralSkyDescription defaults = LuminaProceduralSkyDescription();

  /// Builds a description from a `LuminaProceduralSkyComponent` property map,
  /// falling back to [defaults] for every missing or malformed entry.
  factory LuminaProceduralSkyDescription.fromProperties(Map<String, dynamic>? props) {
    if (props == null || props.isEmpty) return defaults;

    double num_(String key, double fallback) {
      final v = props[key];
      return v is num && v.isFinite ? v.toDouble() : fallback;
    }

    final v = props['visible'];
    return LuminaProceduralSkyDescription(
      timeOfDay: num_('timeOfDay', defaults.timeOfDay),
      turbidity: num_('turbidity', defaults.turbidity),
      rayleigh: num_('rayleigh', defaults.rayleigh),
      mieCoefficient: num_('mieCoefficient', defaults.mieCoefficient),
      mieG: num_('mieG', defaults.mieG),
      cloudCoverage: num_('cloudCoverage', defaults.cloudCoverage),
      cloudDensity: num_('cloudDensity', defaults.cloudDensity),
      waterStrength: num_('waterStrength', defaults.waterStrength),
      waterSpeed: num_('waterSpeed', defaults.waterSpeed),
      dayCycleSpeed: num_('dayCycleSpeed', defaults.dayCycleSpeed),
      visible: v is bool ? v : defaults.visible,
    );
  }

  /// The property map the editor stores on the actor's component and the code
  /// generator reads back.
  Map<String, dynamic> toProperties() => {
        'timeOfDay': timeOfDay,
        'turbidity': turbidity,
        'rayleigh': rayleigh,
        'mieCoefficient': mieCoefficient,
        'mieG': mieG,
        'cloudCoverage': cloudCoverage,
        'cloudDensity': cloudDensity,
        'waterStrength': waterStrength,
        'waterSpeed': waterSpeed,
        'dayCycleSpeed': dayCycleSpeed,
        'visible': visible,
      };

  LuminaProceduralSkyDescription copyWith({
    double? timeOfDay,
    double? turbidity,
    double? rayleigh,
    double? mieCoefficient,
    double? mieG,
    double? cloudCoverage,
    double? cloudDensity,
    double? waterStrength,
    double? waterSpeed,
    double? dayCycleSpeed,
    bool? visible,
  }) =>
      LuminaProceduralSkyDescription(
        timeOfDay: timeOfDay ?? this.timeOfDay,
        turbidity: turbidity ?? this.turbidity,
        rayleigh: rayleigh ?? this.rayleigh,
        mieCoefficient: mieCoefficient ?? this.mieCoefficient,
        mieG: mieG ?? this.mieG,
        cloudCoverage: cloudCoverage ?? this.cloudCoverage,
        cloudDensity: cloudDensity ?? this.cloudDensity,
        waterStrength: waterStrength ?? this.waterStrength,
        waterSpeed: waterSpeed ?? this.waterSpeed,
        dayCycleSpeed: dayCycleSpeed ?? this.dayCycleSpeed,
        visible: visible ?? this.visible,
      );

  /// Unit sun direction for [timeOfDay] (+Y is up, noon is near the zenith).
  List<double> get sunDirection {
    final sunAngle = (timeOfDay - 6.0) / 12.0 * math.pi;
    final x = 0.3 * math.cos(sunAngle);
    final y = math.sin(sunAngle);
    final z = -0.8 * math.cos(sunAngle);
    final len = math.sqrt(x * x + y * y + z * z);
    return [x / len, y / len, z / len];
  }

  /// Whether the sun is below the horizon at [timeOfDay].
  bool get isNight => sunDirection[1] <= 0;

  /// [timeOfDay] advanced by [deltaSeconds] of the day cycle, wrapped to 0..24.
  double advancedTimeOfDay(double deltaSeconds) {
    if (dayCycleSpeed == 0.0) return timeOfDay;
    var t = (timeOfDay + dayCycleSpeed * deltaSeconds) % 24.0;
    if (t < 0) t += 24.0;
    return t;
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaProceduralSkyDescription &&
      other.timeOfDay == timeOfDay &&
      other.turbidity == turbidity &&
      other.rayleigh == rayleigh &&
      other.mieCoefficient == mieCoefficient &&
      other.mieG == mieG &&
      other.cloudCoverage == cloudCoverage &&
      other.cloudDensity == cloudDensity &&
      other.waterStrength == waterStrength &&
      other.waterSpeed == waterSpeed &&
      other.dayCycleSpeed == dayCycleSpeed &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(timeOfDay, turbidity, rayleigh, mieCoefficient,
      mieG, cloudCoverage, cloudDensity, waterStrength, waterSpeed, dayCycleSpeed, visible);

  @override
  String toString() => 'LuminaProceduralSkyDescription(t=$timeOfDay turbidity=$turbidity '
      'rayleigh=$rayleigh clouds=$cloudCoverage/$cloudDensity water=$waterStrength/$waterSpeed '
      'cycle=$dayCycleSpeed visible=$visible)';
}

/// Uploads every sky uniform for [d] onto [mi].
///
/// The maths is the Preetham & Hoffman atmospheric model exactly as
/// flutter_filament's `SimulatedSkyboxSample` computes it, lifted verbatim so
/// the sample and the engine cannot drift. It lives here, at top level, so the
/// component and the world-free binding share one copy.
void applyProceduralSkyUniforms(
  FilamentMaterialInstance mi,
  LuminaProceduralSkyDescription d,
) {
  final sunDir = d.sunDirection;
  final sunY = sunDir[1];
  final moonDir = [-sunDir[0], -sunDir[1], -sunDir[2]];

  const fPi = math.pi;
  const lambdaR = 680e-9;
  const lambdaG = 550e-9;
  const lambdaB = 440e-9;
  const n = 1.0003;
  const bigN = 2.545e25;
  const term = (8.0 * fPi * fPi * fPi * (n * n - 1.0) * (n * n - 1.0)) / (3.0 * bigN);

  final depthR = [
    (term / (lambdaR * lambdaR * lambdaR * lambdaR)) * 8000.0 * d.rayleigh,
    (term / (lambdaG * lambdaG * lambdaG * lambdaG)) * 8000.0 * d.rayleigh,
    (term / (lambdaB * lambdaB * lambdaB * lambdaB)) * 8000.0 * d.rayleigh,
  ];

  const mieBase = 2.0e-5;
  const mieAlpha = 1.3;
  final depthM = [
    mieBase * d.turbidity * math.pow(550e-9 / lambdaR, mieAlpha) * 1200.0 * d.mieCoefficient,
    mieBase * d.turbidity * math.pow(550e-9 / lambdaG, mieAlpha) * 1200.0 * d.mieCoefficient,
    mieBase * d.turbidity * math.pow(550e-9 / lambdaB, mieAlpha) * 1200.0 * d.mieCoefficient,
  ];

  final sunCosRad = math.cos(0.5 * math.pi / 180.0);
  final sunSolidAngle = 2.0 * fPi * (1.0 - sunCosRad);
  final sunRadConv = 1.0 / math.max(1e-9, sunSolidAngle);
  final g2 = d.mieG * d.mieG;

  // Physically-based EV100 pre-exposure, matching the sample's f/16 1/125 ISO100.
  const aperture = 16.0;
  const shutterSpeed = 125.0;
  const iso = 100.0;
  const ev100Linear = (aperture * aperture) / (1.0 / shutterSpeed) * (100.0 / iso);
  const exposure = 1.0 / (1.2 * ev100Linear);

  final rawSunIntensity = sunY > 0 ? 100000.0 * sunY : 1000.0;
  final physSunIntensity = rawSunIntensity * exposure;

  mi.setFloat3('sunDirection', sunDir[0], sunDir[1], sunDir[2]);
  mi.setFloat3('sunDirection2', moonDir[0], moonDir[1], moonDir[2]);
  mi.setFloat3('depthR', depthR[0], depthR[1], depthR[2]);
  mi.setFloat3('depthM', depthM[0].toDouble(), depthM[1].toDouble(), depthM[2].toDouble());
  mi.setFloat3('ozone', 0.0, 0.05, 0.0);
  mi.setFloat3('nightColor', 0.0, 3e-9 * physSunIntensity, 7.5e-9 * physSunIntensity);

  mi.setFloat4('sunHalo', sunCosRad, 0.5, 1.0 * sunRadConv, 1.0);
  mi.setFloat4('sunHalo2', sunCosRad, 0.5, 1.0 * sunRadConv, 0.0);
  mi.setFloat4('multiScatParams', depthR[0] * 0.1, depthR[1] * 0.1, depthR[2] * 0.1, 0.1);
  mi.setFloat2('miePhaseParams', 1.0 + g2, -2.0 * d.mieG);
  mi.setFloat('sunIntensity', physSunIntensity);
  mi.setFloat('sunIntensity2', sunY <= 0 ? 50.0 * exposure : 0.0);
  mi.setFloat('contrast', 1.0);
  mi.setFloat('exposure', exposure);
  mi.setFloat('eclipseFactor', 1.0);

  mi.setFloat4('shimmerControl', 0.0, 20.0, 0.1, 6360.0);

  const planetRadius = 6360.0;
  const cloudHeight = 8.0;
  const intersectC =
      planetRadius * planetRadius - (planetRadius + cloudHeight) * (planetRadius + cloudHeight);
  mi.setFloat4('cloudControl', d.cloudCoverage, d.cloudDensity, intersectC, 0.0005);
  mi.setFloat4('cloudControl2', 0.0, 0.0, 0.0, 0.0);

  mi.setFloat4('waterControl', d.waterStrength, d.waterSpeed, 1.0, 4.0);

  final night = sunY <= 0;
  mi.setFloat4('starControl', 0.001, night ? 1.0 : 0.0, 350.0, 0.0005);
  mi.setFloat('starIntensity', night ? 1.5 : 0.0);

  final mwIntensity = night ? physSunIntensity * 1.5e-8 : 0.0;
  mi.setFloat3('milkyWayControl', mwIntensity, 1.2, 0.05);
  mi.setMat3('milkyWayRotation', const [
    -0.054876, 0.494109, -0.867666, //
    -0.873437, -0.444830, -0.198076, //
    -0.483835, 0.746982, 0.455984,
  ]);
}

/// Binds a [LuminaProceduralSkyDescription] onto a live Filament engine + scene
/// as a real, animating sky renderable.
///
/// [LuminaProceduralSkyComponent] wraps one of these for a full [LuminaWorld];
/// this binding exists for surfaces that render a Filament scene *without* a
/// world — the Lumina Studio level viewport — so those viewports never have to
/// build the geometry, compile the shader or compute the uniforms themselves.
/// It mirrors [LuminaSkyBinding], which does the same for the `Environment`
/// actor's skybox and image-based lighting.
///
/// The sky is a full-screen triangle renderable with `depthWrite: false`, not a
/// Filament `Skybox`, which is what lets it animate per frame and what lets a
/// level carry both it and an `Environment` actor. It lights nothing.
class LuminaProceduralSkyBinding {
  final FilamentEngine engine;
  final FilamentScene scene;

  /// Reads a shader/texture asset. The host owns asset resolution: lumina_ui
  /// reads the package bundle, the runtime reads `rootBundle`, tests read disk.
  final Future<Uint8List> Function(String assetKey) assetProvider;

  /// Whether to load the real moon and Milky Way textures. When false (or when
  /// a load fails) 1×1 neutral textures stay bound, which is enough for the
  /// atmosphere, clouds and ocean.
  final bool loadNightSkyTextures;

  static const String filamatAsset = 'packages/lumina/assets/sky/simulated_skybox.filamat';
  static const String moonDiskAsset = 'packages/lumina/assets/sky/moon_disk.png';
  static const String moonNormalAsset = 'packages/lumina/assets/sky/moon_normal.png';
  static const String milkyWayAsset = 'packages/lumina/assets/sky/milkyway.png';

  FilamentMaterial? _material;
  FilamentMaterialInstance? _materialInstance;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;
  FilamentTexture? _moonTexture;
  FilamentTexture? _moonNormal;
  FilamentTexture? _milkyWayTexture;
  int? _skyEntity;

  LuminaProceduralSkyDescription _description = LuminaProceduralSkyDescription.defaults;
  bool _isLoaded = false;
  bool _disposed = false;
  final Completer<void> _loadCompleter = Completer<void>();

  LuminaProceduralSkyBinding({
    required this.engine,
    required this.scene,
    required this.assetProvider,
    this.loadNightSkyTextures = true,
  });

  /// Whether the shader is compiled and the sky renderable is in the scene.
  bool get isLoaded => _isLoaded;

  /// Completes once the sky is in the scene, or completes with an error.
  Future<void> get loaded => _loadCompleter.future;

  /// The scene entity carrying the sky triangle, once loaded.
  int? get skyEntity => _skyEntity;

  /// The description currently bound to the scene.
  LuminaProceduralSkyDescription get description => _description;

  /// Compiles the shader, builds the geometry and puts the sky in the scene.
  ///
  /// Safe to call more than once; later calls are no-ops.
  Future<void> load(LuminaProceduralSkyDescription description) async {
    if (_disposed || _isLoaded || _loadCompleter.isCompleted) return _loadCompleter.future;
    // Only a *starting* value: reading the shader off the bundle is
    // asynchronous, and apply() may well land before it finishes. Whatever
    // apply() left in _description is what gets uploaded below, so an edit
    // made during the load is never thrown away.
    _description = description;

    try {
      // 1. Full-screen triangle. The shader reconstructs the view ray per
      //    fragment, so three vertices cover the whole sky.
      _vb = FilamentVertexBuffer.create(engine: engine, vertexCount: 3, bufferCount: 1)
        ..setData(Float32List.fromList([
          -1.0, -1.0, 0.0, //
          3.0, -1.0, 0.0, //
          -1.0, 3.0, 0.0,
        ]));
      _ib = FilamentIndexBuffer.create(engine: engine, indexCount: 3, type: IndexType.ushort)
        ..setUint16Data(Uint16List.fromList([0, 1, 2]));

      // 2. Compiled shader.
      final filamat = await assetProvider(filamatAsset);
      if (_disposed) return;
      // _description may have moved on while that await was in flight.
      final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: filamat);
      _material = material;
      final mi = material.createInstance();
      _materialInstance = mi;

      // 3. Bind 1×1 fallbacks *before* the first draw — Filament will not
      //    render a material instance with an unbound sampler.
      _moonTexture = _create1x1(255, 255, 255, 255);
      _moonNormal = _create1x1(128, 128, 255, 255);
      _milkyWayTexture = _create1x1(0, 0, 0, 255);
      mi.setTexture('moonTexture', _moonTexture!.nativePointer);
      mi.setTexture('moonNormal', _moonNormal!.nativePointer);
      mi.setTexture('milkyWayTexture', _milkyWayTexture!.nativePointer);

      applyProceduralSkyUniforms(mi, _description);

      // 4. Only now is it safe to put the renderable in the scene.
      final entity = engine.createEntity();
      _skyEntity = entity;
      FilamentRenderableManager(engine).createRenderable(
        entity: entity,
        vertexBuffer: _vb!,
        indexBuffer: _ib!,
        materialInstance: mi,
        count: 3,
      );
      if (_description.visible) scene.addEntity(entity);

      _isLoaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();

      if (loadNightSkyTextures) {
        unawaited(_loadNightTextures(mi));
      }
    } catch (e, st) {
      if (!_loadCompleter.isCompleted) _loadCompleter.completeError(e, st);
    }
  }

  /// Pushes [description] onto the scene.
  ///
  /// Cheap and idempotent: the uniforms are re-uploaded only when something
  /// changed, and nothing is ever rebuilt, so it is safe to call on every
  /// Details-panel keystroke and on every frame of a day cycle.
  void apply(LuminaProceduralSkyDescription description) {
    if (_disposed) return;
    final was = _description;
    _description = description;
    if (!_isLoaded) return;

    if (description.visible != was.visible) {
      final e = _skyEntity;
      if (e != null) {
        if (description.visible) {
          scene.addEntity(e);
        } else {
          scene.removeEntity(e);
        }
      }
    }
    if (description != was) {
      final mi = _materialInstance;
      if (mi != null) applyProceduralSkyUniforms(mi, description);
    }
  }

  /// Advances the day cycle by [deltaSeconds] and re-uploads. Returns the new
  /// time of day, so a host can write it back onto the actor it came from.
  double advance(double deltaSeconds) {
    final next = _description.advancedTimeOfDay(deltaSeconds);
    if (next != _description.timeOfDay) {
      apply(_description.copyWith(timeOfDay: next));
    }
    return next;
  }

  FilamentTexture _create1x1(int r, int g, int b, int a) {
    final tex = FilamentTexture.create2D(
      engine: engine,
      width: 1,
      height: 1,
      format: TextureFormat.rgba8,
      levels: 1,
    );
    tex.setImage(
      pixelData: Uint8List.fromList([r, g, b, a]),
      width: 1,
      height: 1,
      pixelFormat: PixelFormat.rgba,
      pixelType: PixelType.ubyte,
    );
    return tex;
  }

  Future<void> _loadNightTextures(FilamentMaterialInstance mi) async {
    Future<void> swap(String key, String uniform, void Function(FilamentTexture) assign) async {
      try {
        final tex = await _textureFromPng(key);
        if (tex == null || _disposed || _skyEntity == null) return;
        assign(tex);
        mi.setTexture(uniform, tex.nativePointer);
      } catch (_) {
        // The 1×1 fallback stays bound; the daytime sky is unaffected.
      }
    }

    await swap(moonDiskAsset, 'moonTexture', (t) {
      _moonTexture?.dispose();
      _moonTexture = t;
    });
    await swap(moonNormalAsset, 'moonNormal', (t) {
      _moonNormal?.dispose();
      _moonNormal = t;
    });
    await swap(milkyWayAsset, 'milkyWayTexture', (t) {
      _milkyWayTexture?.dispose();
      _milkyWayTexture = t;
    });
  }

  Future<FilamentTexture?> _textureFromPng(String key) async {
    final bytes = await assetProvider(key);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final tex = FilamentTexture.create2D(
      engine: engine,
      width: image.width,
      height: image.height,
      format: TextureFormat.rgba8,
      levels: 1,
    );
    tex.setImage(
      pixelData: byteData.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      pixelFormat: PixelFormat.rgba,
      pixelType: PixelType.ubyte,
    );
    return tex;
  }

  /// Removes the sky from the scene and destroys every resource it owns.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final e = _skyEntity;
    if (e != null) {
      scene.removeEntity(e);
      engine.destroyEntity(e);
    }
    _skyEntity = null;
    _moonTexture?.dispose();
    _moonTexture = null;
    _moonNormal?.dispose();
    _moonNormal = null;
    _milkyWayTexture?.dispose();
    _milkyWayTexture = null;
    _materialInstance?.dispose();
    _materialInstance = null;
    _material?.dispose();
    _material = null;
    _ib?.dispose();
    _ib = null;
    _vb?.dispose();
    _vb = null;
    _isLoaded = false;
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.completeError(StateError('procedural sky binding disposed before it loaded'));
    }
  }
}
