import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class ProceduralTextureSample extends StatefulWidget {
  const ProceduralTextureSample({super.key});

  @override
  State<ProceduralTextureSample> createState() => _ProceduralTextureSampleState();
}

class _ProceduralTextureSampleState extends State<ProceduralTextureSample> {
  String _info = 'Initializing Procedural Texture sample...';
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

    // 1. Generate procedural 64x64 checkerboard texture
    const int texSize = 64;
    final srcPixels = Uint8List(texSize * texSize * 4);
    for (int y = 0; y < texSize; y++) {
      for (int x = 0; x < texSize; x++) {
        final idx = (y * texSize + x) * 4;
        final bool check = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
        srcPixels[idx] = check ? 255 : 30; // R
        srcPixels[idx + 1] = check ? 180 : 30; // G
        srcPixels[idx + 2] = check ? 50 : 200; // B
        srcPixels[idx + 3] = 255; // A
      }
    }

    final mipLevel1 = FilamentTools.generateMipmap(
      srcPixels: srcPixels,
      width: texSize,
      height: texSize,
      targetLevel: 1,
    );

    final mipLevel2 = FilamentTools.generateMipmap(
      srcPixels: srcPixels,
      width: texSize,
      height: texSize,
      targetLevel: 2,
    );

    // Render Suzanne 3D mesh
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
      _info = 'Procedural Texture Sample (procedural_texture_quad.cpp & mipgen)\n'
          'Source Texture: ${texSize}x$texSize RGBA8 (${srcPixels.length} bytes)\n'
          'Mipmap Level 1: ${mipLevel1?.width}x${mipLevel1?.height} (${mipLevel1?.pixels.length} bytes)\n'
          'Mipmap Level 2: ${mipLevel2?.width}x${mipLevel2?.height} (${mipLevel2?.pixels.length} bytes)\n'
          'Procedural Checkerboard Texture Generated and Rendered in 3D!';
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
        title: const Text('Procedural Texture (procedural_texture_quad.cpp)'),
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
                    'Sample: procedural_texture_quad.cpp & mipgen\n'
                    'Demonstrates procedural texture pattern generation and downsampled mipmap pyramid generation.',
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
                child: Text(_info, style: const TextStyle(color: Colors.orangeAccent, fontFamily: 'monospace', fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
