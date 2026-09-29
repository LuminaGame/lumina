import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class StrobeColorSample extends StatefulWidget {
  const StrobeColorSample({super.key});

  @override
  State<StrobeColorSample> createState() => _StrobeColorSampleState();
}

class _StrobeColorSampleState extends State<StrobeColorSample> {
  String _info = 'Initializing Strobe Color 3D Scene...';
  FilamentEngine? _engine;
  FilamentCameraManipulator? _manipulator;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;
  FilamentScene? _scene;
  FilamentLightManager? _lightManager;
  int? _lightEntity;
  Timer? _timer;
  double _now = 0.0;

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
      eyeY: 0.0,
      eyeZ: 3.5,
      centerX: 0.0,
      centerY: 0.0,
      centerZ: 0.0,
      upX: 0.0,
      upY: 1.0,
      upZ: 0.0,
    );

    scene.createSuzanneSample(view);

    rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx').then((iblData) {
      if (mounted) {
        final ibl = FilamentIndirectLight.fromKtx(
          engine,
          iblData.buffer.asUint8List(),
          intensity: 50000.0,
        );
        _ibl = ibl;
        scene.setIndirectLight(ibl);
      }
    });

    rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx').then((skyData) {
      if (mounted) {
        final skybox = FilamentSkybox.fromKtx(
          engine,
          skyData.buffer.asUint8List(),
          showSun: true,
        );
        _skybox = skybox;
        scene.setSkybox(skybox);
      }
    });

    _lightManager = FilamentLightManager(engine);
    _updateStrobeLight(1.0, 1.0, 1.0);

    const double speed = 3.0;
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted || _lightManager == null || _scene == null) return;
      _now += 0.033;

      final r = 0.5 + 0.5 * sin(speed * _now);
      final g = 0.5 + 0.5 * sin(speed * _now + pi * 2.0 / 3.0);
      final b = 0.5 + 0.5 * sin(speed * _now + pi * 4.0 / 3.0);

      _updateStrobeLight(r, g, b);

      if (mounted) {
        setState(() {
          _info = 'Strobe Color Animation (strobecolor.cpp)\n'
              'Directional Light Color Modulating RGB Sine Waves\n'
              'Current RGB: (${(r * 255).round()}, ${(g * 255).round()}, ${(b * 255).round()})\n'
              'Elapsed Time: ${_now.toStringAsFixed(1)}s';
        });
      }
    });
  }

  void _updateStrobeLight(double r, double g, double b) {
    if (_engine == null || _scene == null || _lightManager == null) return;

    if (_lightEntity != null) {
      _scene!.removeEntity(_lightEntity!);
      _lightManager!.destroy(_lightEntity!);
      _engine!.destroyEntity(_lightEntity!);
      _lightEntity = null;
    }

    final entity = _engine!.createEntity();
    _lightEntity = entity;

    _lightManager!.createLight(
      entity: entity,
      type: LightType.directional,
      colorR: r,
      colorG: g,
      colorB: b,
      intensity: 150000.0,
      dirX: 0.5,
      dirY: -1.0,
      dirZ: -1.0,
    );

    _scene!.addEntity(entity);
  }

  void _cleanupResources() {
    _timer?.cancel();
    _timer = null;
    _ibl?.dispose();
    _skybox?.dispose();
    _scene?.destroySuzanneSample();
    if (_lightEntity != null && _engine != null) {
      _lightManager?.destroy(_lightEntity!);
      _engine?.destroyEntity(_lightEntity!);
    }
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
        title: const Text('Strobe Color Sample (strobecolor.cpp)'),
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
                    'Sample: strobecolor.cpp\n'
                    'Renders an animated 3D Filament scene with dynamic RGB strobe lighting cycling over time.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilamentWidget(
                height: 340,
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
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
