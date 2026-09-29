import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class SampleNormalMapSample extends StatefulWidget {
  const SampleNormalMapSample({super.key});

  @override
  State<SampleNormalMapSample> createState() => _SampleNormalMapSampleState();
}

class _SampleNormalMapSampleState extends State<SampleNormalMapSample> {
  String _info = 'Initializing Normal Mapping sample...';
  FilamentCameraManipulator? _manipulator;
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

    // 1. Blend normal maps with RNM tool
    final baseNormal = Uint8List.fromList([128, 128, 255, 255]);
    final detailNormal = Uint8List.fromList([140, 120, 240, 255]);
    final blended = FilamentTools.blendNormalMaps(
      basePixels: baseNormal,
      detailPixels: detailNormal,
      width: 1,
      height: 1,
    );

    // 2. Render Suzanne 3D mesh with Normal Map
    scene.createSuzanneSample(view);

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

    final lightEntity = engine.createEntity();
    final lightManager = FilamentLightManager(engine);
    lightManager.createLight(
      entity: lightEntity,
      type: LightType.directional,
      colorR: 1.0,
      colorG: 1.0,
      colorB: 0.95,
      intensity: 100000.0,
      dirX: 0.5,
      dirY: -1.0,
      dirZ: -1.0,
    );
    scene.addEntity(lightEntity);

    setState(() {
      _info = 'Sample Normal Map (sample_normal_map.cpp & normal-blending)\n'
          'Base Normal: RGBA(${baseNormal.join(', ')})\n'
          'Detail Normal: RGBA(${detailNormal.join(', ')})\n'
          'Blended (RNM): RGBA(${blended?.join(', ')})\n'
          'Suzanne 3D Mesh with Tangent-Space Normal Texture Active!';
    });
  }

  void _cleanupResources() {
    _ibl?.dispose();
    _skybox?.dispose();
    _scene?.destroySuzanneSample();
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
        title: const Text('Normal Mapping (sample_normal_map.cpp)'),
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
                    'Sample: sample_normal_map.cpp & normal-blending\n'
                    'Demonstrates Reoriented Normal Mapping (RNM) for blending base and detail normal textures.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                child: Text(_info, style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace', fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
