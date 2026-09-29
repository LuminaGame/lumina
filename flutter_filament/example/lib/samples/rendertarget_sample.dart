import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class RenderTargetSample extends StatefulWidget {
  const RenderTargetSample({super.key});

  @override
  State<RenderTargetSample> createState() => _RenderTargetSampleState();
}

class _RenderTargetSampleState extends State<RenderTargetSample> {
  String _info = 'Initializing Render Target sample...';
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

    final frameDump = FilamentTools.dumpFramePipelineJson(
      view: view,
      scene: scene,
      camera: camera,
    );

    setState(() {
      _info = 'Render Target Sample (rendertarget.cpp)\n'
          'Offscreen Render Target & Pipeline Inspection:\n\n'
          '$frameDump';
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
        title: const Text('Render Target Sample (rendertarget.cpp)'),
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
                    'Sample: rendertarget.cpp\n'
                    'Demonstrates offscreen render target texture attachments and pipeline inspection (frame_pipeline_visualizer).',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilamentWidget(
                height: 300,
                cameraManipulator: _manipulator,
                onSceneCreated: _setup3dScene,
                onDispose: _cleanupResources,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade900,
                child: Text(_info, style: const TextStyle(color: Colors.lightBlueAccent, fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
