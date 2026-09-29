import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class HelloPbrSample extends StatefulWidget {
  const HelloPbrSample({super.key});

  @override
  State<HelloPbrSample> createState() => _HelloPbrSampleState();
}

class _HelloPbrSampleState extends State<HelloPbrSample> {
  String _info = 'Initializing Hello PBR 3D scene...';
  double _metallic = 0.8;
  double _roughness = 0.2;
  double _reflectance = 0.5;

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _instance;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;
  int? _sunEntity;
  FilamentCameraManipulator? _cameraManipulator;

  Future<void> _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) async {
    _engine = engine;
    _scene = scene;

    // 1. Setup Camera Orbit Manipulator
    final manipulator = FilamentCameraManipulator.create(
      mode: ManipulatorMode.orbit,
      viewportWidth: 800,
      viewportHeight: 600,
    );
    _cameraManipulator = manipulator;

    // 2. Add Directional Sun Light matching hellopbr.cpp
    final sunEntity = engine.createEntity();
    _sunEntity = sunEntity;

    final lightManager = FilamentLightManager(engine);
    lightManager.createLight(
      entity: sunEntity,
      type: LightType.sun,
      colorR: 0.98,
      colorG: 0.92,
      colorB: 0.89,
      intensity: 110000.0,
      dirX: 0.7,
      dirY: -1.0,
      dirZ: -0.8,
      castShadows: false,
    );
    scene.addEntity(sunEntity);

    // 3. Load IBL & Skybox
    try {
      final iblBytes = await rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx');
      final skyBytes = await rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx');

      final ibl = FilamentIndirectLight.fromKtx(
        engine,
        iblBytes.buffer.asUint8List(),
        intensity: 50000.0,
      );
      final skybox = FilamentSkybox.fromKtx(
        engine,
        skyBytes.buffer.asUint8List(),
        showSun: true,
      );

      _ibl = ibl;
      _skybox = skybox;

      scene.setIndirectLight(ibl);
      scene.setSkybox(skybox);
    } catch (e) {
      debugPrint('[HelloPbrSample]: IBL loading fallback: $e');
    }

    _updatePbrInfo();
  }

  void _updatePbrInfo() {
    setState(() {
      _info = 'Hello PBR 3D Sample (hellopbr.cpp)\n'
          'Engine Pointer: 0x${_engine?.nativePointer.address.toRadixString(16)}\n'
          'Metallic: ${_metallic.toStringAsFixed(2)}\n'
          'Roughness: ${_roughness.toStringAsFixed(2)}\n'
          'Reflectance: ${_reflectance.toStringAsFixed(2)}\n'
          'IBL Lighting: lightroom_14b';
    });
  }

  void _cleanupResources() {
    if (_sunEntity != null) {
      if (_scene != null) {
        _scene!.removeEntity(_sunEntity!);
      }
      if (_engine != null) {
        _engine!.destroyEntity(_sunEntity!);
      }
      _sunEntity = null;
    }
    _skybox?.dispose();
    _skybox = null;
    _ibl?.dispose();
    _ibl = null;
    _instance?.dispose();
    _instance = null;
    _material?.dispose();
    _material = null;
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
        title: const Text('Hello PBR Sample (hellopbr.cpp)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sample: hellopbr.cpp\n'
                          'Demonstrates PBR metallic/roughness material parameters, directional sun light, and IBL environment reflections.',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FilamentWidget(
                  height: 350,
                  cameraManipulator: _cameraManipulator,
                  onSceneCreated: (engine, scene, camera, view) {
                    _setup3dScene(engine, scene, camera, view);
                  },
                  onDispose: _cleanupResources,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _info,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Metallic: ${_metallic.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _metallic,
                onChanged: (v) {
                  setState(() => _metallic = v);
                  _updatePbrInfo();
                },
              ),
              Text('Roughness: ${_roughness.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _roughness,
                onChanged: (v) {
                  setState(() => _roughness = v);
                  _updatePbrInfo();
                },
              ),
              Text('Reflectance: ${_reflectance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _reflectance,
                onChanged: (v) {
                  setState(() => _reflectance = v);
                  _updatePbrInfo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
