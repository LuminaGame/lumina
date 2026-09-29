import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class SimulatedSkyboxSample extends StatefulWidget {
  const SimulatedSkyboxSample({super.key});

  @override
  State<SimulatedSkyboxSample> createState() => _SimulatedSkyboxSampleState();
}

class _SimulatedSkyboxSampleState extends State<SimulatedSkyboxSample> {
  final String _info = 'Initializing Procedural Skybox & Atmosphere...';

  // Sky Controls
  double _timeOfDay = 12.0; // 0..24 hours
  double _turbidity = 2.0;
  double _rayleigh = 1.0;
  final double _mieCoefficient = 1.0;
  final double _mieG = 0.8;
  double _cloudCoverage = 0.4;
  final double _cloudDensity = 0.15;
  double _waterStrength = 30.0;
  final double _waterSpeed = 1.0;
  bool _animateTime = true;

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _materialInstance;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;
  int? _skyEntity;
  FilamentCameraManipulator? _manipulator;

  FilamentTexture? _moonTexture;
  FilamentTexture? _moonNormal;
  FilamentTexture? _milkyWayTexture;
  Timer? _animTimer;

  FilamentTexture _create1x1Texture(FilamentEngine engine, int r, int g, int b, int a) {
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

  void _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    _engine = engine;
    _scene = scene;

    _manipulator = FilamentCameraManipulator.create(
      mode: ManipulatorMode.orbit,
      viewportWidth: 1024,
      viewportHeight: 768,
    );

    camera.lookAt(
      eyeX: 0.0,
      eyeY: 1.5,
      eyeZ: 4.0,
      centerX: 0.0,
      centerY: 0.0,
      centerZ: 0.0,
      upX: 0.0,
      upY: 1.0,
      upZ: 0.0,
    );

    // Physically-based EV100 camera exposure for 100,000 Lux sunlight
    camera.setExposure(
      aperture: 16.0,
      shutterSpeed: 1.0 / 125.0,
      sensitivity: 100.0,
    );

    view.postProcessingEnabled = true;

    // 1. Create full screen triangle geometry for procedural skybox
    final vertices = Float32List.fromList([
      -1.0, -1.0, 0.0,
       3.0, -1.0, 0.0,
      -1.0,  3.0, 0.0,
    ]);
    final indices = Uint16List.fromList([0, 1, 2]);

    _vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: 3,
      bufferCount: 1,
    );
    _vb!.setData(vertices);

    _ib = FilamentIndexBuffer.create(
      engine: engine,
      indexCount: 3,
      type: IndexType.ushort,
    );
    _ib!.setUint16Data(indices);

    // 2. Load compiled simulated_skybox.filamat shader
    rootBundle.load('assets/sky/simulated_skybox.filamat').then((matData) {
      if (!mounted || _engine == null) return;

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: matData.buffer.asUint8List(),
      );
      _material = material;
      final mi = material.createInstance();
      _materialInstance = mi;

      // 3. Create 1x1 fallback textures immediately so Filament samplers are NEVER unbound!
      _moonTexture = _create1x1Texture(engine, 255, 255, 255, 255);
      _moonNormal = _create1x1Texture(engine, 128, 128, 255, 255);
      _milkyWayTexture = _create1x1Texture(engine, 0, 0, 0, 255);

      mi.setTexture('moonTexture', _moonTexture!.nativePointer);
      mi.setTexture('moonNormal', _moonNormal!.nativePointer);
      mi.setTexture('milkyWayTexture', _milkyWayTexture!.nativePointer);

      // 4. Upload initial sky uniforms
      _updateSkyUniforms();

      // 5. Create renderable entity & add to scene ONLY AFTER all samplers & uniforms are bound
      final entity = engine.createEntity();
      _skyEntity = entity;

      final rm = FilamentRenderableManager(engine);
      rm.createRenderable(
        entity: entity,
        vertexBuffer: _vb!,
        indexBuffer: _ib!,
        materialInstance: mi,
        count: 3,
      );
      scene.addEntity(entity);

      // 6. Asynchronously load high-res PNG textures
      _loadTextures(engine, mi);
    });

    // 7. Setup Animation Ticker (Wind, Waves, Time)
    _animTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted || _materialInstance == null) return;
      if (_animateTime) {
        _timeOfDay = (_timeOfDay + 0.005) % 24.0;
      }
      _updateSkyUniforms();
    });
  }

  Future<void> _loadTextures(FilamentEngine engine, FilamentMaterialInstance mi) async {
    try {
      final realMoon = await _createTextureFromAsset(engine, 'assets/sky/moon_disk.png');
      if (realMoon != null && mounted) {
        _moonTexture?.dispose();
        _moonTexture = realMoon;
        mi.setTexture('moonTexture', realMoon.nativePointer);
      }

      final realNormal = await _createTextureFromAsset(engine, 'assets/sky/moon_normal.png');
      if (realNormal != null && mounted) {
        _moonNormal?.dispose();
        _moonNormal = realNormal;
        mi.setTexture('moonNormal', realNormal.nativePointer);
      }

      final realMilkyWay = await _createTextureFromAsset(engine, 'assets/sky/milkyway.png');
      if (realMilkyWay != null && mounted) {
        _milkyWayTexture?.dispose();
        _milkyWayTexture = realMilkyWay;
        mi.setTexture('milkyWayTexture', realMilkyWay.nativePointer);
      }
    } catch (e) {
      debugPrint('Texture load error: $e');
    }
  }

  Future<FilamentTexture?> _createTextureFromAsset(FilamentEngine engine, String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
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
    } catch (e) {
      return null;
    }
  }

  void _updateSkyUniforms() {
    final mi = _materialInstance;
    if (mi == null) return;

    // Calculate Sun Direction from Time of Day (0..24h)
    final sunAngle = (_timeOfDay - 6.0) / 12.0 * pi;
    final sunX = 0.3 * cos(sunAngle);
    final sunY = sin(sunAngle);
    final sunZ = -0.8 * cos(sunAngle);
    final sunLen = sqrt(sunX * sunX + sunY * sunY + sunZ * sunZ);
    final sunDir = [sunX / sunLen, sunY / sunLen, sunZ / sunLen];

    // Moon Direction (opposite sun)
    final moonDir = [-sunDir[0], -sunDir[1], -sunDir[2]];

    // Rayleigh & Mie Coefficients Math (Preetham & Hoffman Atmospheric Model)
    const fPi = pi;
    const lambdaR = 680e-9;
    const lambdaG = 550e-9;
    const lambdaB = 440e-9;
    const n = 1.0003;
    const N = 2.545e25;
    const term = (8.0 * fPi * fPi * fPi * (n * n - 1.0) * (n * n - 1.0)) / (3.0 * N);

    final depthR = [
      (term / (lambdaR * lambdaR * lambdaR * lambdaR)) * 8000.0 * _rayleigh,
      (term / (lambdaG * lambdaG * lambdaG * lambdaG)) * 8000.0 * _rayleigh,
      (term / (lambdaB * lambdaB * lambdaB * lambdaB)) * 8000.0 * _rayleigh,
    ];

    const mieBase = 2.0e-5;
    const mieAlpha = 1.3;
    final depthM = [
      mieBase * _turbidity * pow(550e-9 / lambdaR, mieAlpha) * 1200.0 * _mieCoefficient,
      mieBase * _turbidity * pow(550e-9 / lambdaG, mieAlpha) * 1200.0 * _mieCoefficient,
      mieBase * _turbidity * pow(550e-9 / lambdaB, mieAlpha) * 1200.0 * _mieCoefficient,
    ];

    // Sun Radiance Conversion
    final sunCosRad = cos(0.5 * pi / 180.0);
    final sunSolidAngle = 2.0 * fPi * (1.0 - sunCosRad);
    final sunRadConv = 1.0 / max(1e-9, sunSolidAngle);

    // Mie Phase
    final g2 = _mieG * _mieG;

    // Physically-based EV100 Pre-Exposure Calculation (matching SimulatedSkybox.js)
    const aperture = 16.0;
    const shutterSpeed = 125.0;
    const iso = 100.0;
    const ev100Linear = (aperture * aperture) / (1.0 / shutterSpeed) * (100.0 / iso);
    const exposure = 1.0 / (1.2 * ev100Linear);

    final rawSunIntensity = sunY > 0 ? 100000.0 * sunY : 1000.0;
    final physSunIntensity = rawSunIntensity * exposure;

    // Uniform Uploads
    mi.setFloat3('sunDirection', sunDir[0], sunDir[1], sunDir[2]);
    mi.setFloat3('sunDirection2', moonDir[0], moonDir[1], moonDir[2]);
    mi.setFloat3('depthR', depthR[0], depthR[1], depthR[2]);
    mi.setFloat3('depthM', depthM[0], depthM[1], depthM[2]);
    mi.setFloat3('ozone', 0.0, 0.05, 0.0);
    mi.setFloat3('nightColor', 0.0, 3e-9 * physSunIntensity, 7.5e-9 * physSunIntensity);

    // Sun & Moon Halo Parameters
    mi.setFloat4('sunHalo', sunCosRad, 0.5, 1.0 * sunRadConv, 1.0);
    mi.setFloat4('sunHalo2', sunCosRad, 0.5, 1.0 * sunRadConv, 0.0);
    mi.setFloat4('multiScatParams', depthR[0] * 0.1, depthR[1] * 0.1, depthR[2] * 0.1, 0.1);
    mi.setFloat2('miePhaseParams', 1.0 + g2, -2.0 * _mieG);
    mi.setFloat('sunIntensity', physSunIntensity);
    mi.setFloat('sunIntensity2', sunY <= 0 ? 50.0 * exposure : 0.0);
    mi.setFloat('contrast', 1.0);
    mi.setFloat('exposure', exposure);
    mi.setFloat('eclipseFactor', 1.0);

    // Shimmer (x=strength, y=frequency, z=maskHeight, w=planetRadius)
    mi.setFloat4('shimmerControl', 0.0, 20.0, 0.1, 6360.0);

    // Clouds (x=coverage, y=density, z=quadraticConst, w=windSpeed)
    const r = 6360.0;
    const h = 8.0;
    const intersectC = r * r - (r + h) * (r + h);
    mi.setFloat4('cloudControl', _cloudCoverage, _cloudDensity, intersectC, 0.0005);
    mi.setFloat4('cloudControl2', 0.0, 0.0, 0.0, 0.0);

    // Ocean Water Reflection (x=strength, y=speed, z=derivativeTrick, w=octaves)
    mi.setFloat4('waterControl', _waterStrength, _waterSpeed, 1.0, 4.0);

    // Stars & Milky Way (Only enabled at night when sunY <= 0)
    final isNight = sunY <= 0;
    mi.setFloat4('starControl', 0.001, isNight ? 1.0 : 0.0, 350.0, 0.0005);
    mi.setFloat('starIntensity', isNight ? 1.5 : 0.0);

    final mwIntensity = isNight ? physSunIntensity * 1.5e-8 : 0.0;
    mi.setFloat3('milkyWayControl', mwIntensity, 1.2, 0.05);
    mi.setMat3('milkyWayRotation', const [
      -0.054876, 0.494109, -0.867666,
      -0.873437, -0.444830, -0.198076,
      -0.483835, 0.746982, 0.455984
    ]);
  }

  void _cleanupResources() {
    _animTimer?.cancel();
    _animTimer = null;
    _moonTexture?.dispose();
    _moonNormal?.dispose();
    _milkyWayTexture?.dispose();
    if (_skyEntity != null && _scene != null) {
      _scene?.removeEntity(_skyEntity!);
    }
    _vb?.dispose();
    _ib?.dispose();
    _materialInstance?.dispose();
    _material?.dispose();
    _manipulator?.dispose();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procedural Skybox & Ocean (SimulatedSkybox)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Sample: filament/web/examples/sky (SimulatedSkybox.js)\n'
                    'Single-pass procedural atmospheric scattering (Preetham & Hoffman), volumetric FBM clouds, day/night cycle, stars, and real-time ocean water reflections.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilamentWidget(
                height: 360,
                cameraManipulator: _manipulator,
                onSceneCreated: _setup3dScene,
                onDispose: _cleanupResources,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade900,
                child: Text(
                  _info,
                  style: const TextStyle(color: Colors.lightGreenAccent, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),

              // Time of Day Slider
              Row(
                children: [
                  const Text('Time of Day: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _timeOfDay,
                      min: 0.0,
                      max: 24.0,
                      onChanged: (val) {
                        setState(() => _timeOfDay = val);
                        _updateSkyUniforms();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(_animateTime ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      setState(() => _animateTime = !_animateTime);
                    },
                  ),
                ],
              ),

              // Rayleigh Slider
              Row(
                children: [
                  const Text('Rayleigh Scattering: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _rayleigh,
                      min: 0.1,
                      max: 5.0,
                      onChanged: (val) {
                        setState(() => _rayleigh = val);
                        _updateSkyUniforms();
                      },
                    ),
                  ),
                ],
              ),

              // Turbidity Slider
              Row(
                children: [
                  const Text('Atmosphere Turbidity: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _turbidity,
                      min: 1.0,
                      max: 10.0,
                      onChanged: (val) {
                        setState(() => _turbidity = val);
                        _updateSkyUniforms();
                      },
                    ),
                  ),
                ],
              ),

              // Cloud Coverage Slider
              Row(
                children: [
                  const Text('Cloud Coverage: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _cloudCoverage,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _cloudCoverage = val);
                        _updateSkyUniforms();
                      },
                    ),
                  ),
                ],
              ),

              // Ocean Waves Slider
              Row(
                children: [
                  const Text('Ocean Wave Strength: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _waterStrength,
                      min: 0.0,
                      max: 100.0,
                      onChanged: (val) {
                        setState(() => _waterStrength = val);
                        _updateSkyUniforms();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
