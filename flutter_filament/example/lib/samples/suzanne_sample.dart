import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class SuzanneSample extends StatefulWidget {
  const SuzanneSample({super.key});

  @override
  State<SuzanneSample> createState() => _SuzanneSampleState();
}

class _SuzanneSampleState extends State<SuzanneSample> {
  String _info = 'Initializing Suzanne 3D Monkey Scene...';
  FilamentCameraManipulator? _manipulator;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _instance;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;

  FilamentScene? _scene;

  void _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    _scene = scene;
    // 1. Setup Camera Manipulator & Position Camera
    final manipulator = FilamentCameraManipulator.create(
      mode: ManipulatorMode.orbit,
      viewportWidth: 1024,
      viewportHeight: 768,
    );
    _manipulator = manipulator;

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

    // Use Perspective projection matching exact viewport aspect ratio
    camera.setProjection(
      fovDegrees: 45.0,
      aspect: 800.0 / 320.0,
      near: 0.1,
      far: 100.0,
    );

    // 2. Instantiate official TexturedLit PBR material, KTX textures, normal map, & Suzanne mesh
    scene.createSuzanneSample(view);

    // Load Lightroom 14b IBL (IndirectLight) and Skybox directly in Dart via rootBundle
    rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx').then((iblData) {
      if (mounted) {
        final ibl = FilamentIndirectLight.fromKtx(
          engine,
          iblData.buffer.asUint8List(),
          intensity: 100000.0,
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

    // 3. Create Directional Light
    final lightEntity = engine.createEntity();
    final lightManager = FilamentLightManager(engine);
    lightManager.createLight(
      entity: lightEntity,
      type: LightType.directional,
      colorR: 1.0,
      colorG: 0.95,
      colorB: 0.9,
      intensity: 100000.0,
      dirX: 0.5,
      dirY: -1.0,
      dirZ: -1.0,
    );
    scene.addEntity(lightEntity);

    final lookAt = manipulator.getLookAt();
    setState(() {
      _info =
          'Official Suzanne 3D Scene Loaded (suzanne.cpp)!\n'
          '5 KTX2/PBR Textures (Albedo, AO, Metallic, Roughness, Normal Map)\n'
          'Lightroom 14b IBL & Skybox loaded directly via Dart rootBundle\n'
          'Camera Position: ${lookAt.eye} -> ${lookAt.center}';
    });
  }

  void _cleanupResources() {
    _ibl?.dispose();
    _skybox?.dispose();
    _scene?.destroySuzanneSample();
    _instance?.dispose();
    _material?.dispose();
    _vb?.dispose();
    _ib?.dispose();
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
      appBar: AppBar(title: const Text('Suzanne Sample (suzanne.cpp)')),
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
                    'Sample: suzanne.cpp\n'
                    'Demonstrates 3D monkey mesh rendering and interactive camera orbit manipulator (FilamentCameraManipulator).',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Live 3D Filament Widget Viewport
              FilamentWidget(
                height: 320,
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
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
