import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class ViewTestSample extends StatefulWidget {
  const ViewTestSample({super.key});

  @override
  State<ViewTestSample> createState() => _ViewTestSampleState();
}

class _ViewTestSampleState extends State<ViewTestSample> {
  String _info = 'Initializing View Test sample...';
  bool _shadowsEnabled = true;
  bool _postProcessingEnabled = true;
  int _aaMode = 1; // 0=None, 1=FXAA

  FilamentView? _view;
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
    _view = view;

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

    _updateViewSettings();
  }

  void _updateViewSettings() {
    if (_view == null) return;
    _view!.shadowingEnabled = _shadowsEnabled;
    _view!.postProcessingEnabled = _postProcessingEnabled;
    _view!.antiAliasing = _aaMode;

    setState(() {
      _info = 'View Settings & Post-Processing (viewtest.cpp)\n'
          'FilamentView Controls Active:\n'
          'Shadowing: ${_shadowsEnabled ? "Enabled" : "Disabled"}\n'
          'Post-Processing: ${_postProcessingEnabled ? "Enabled" : "Disabled"}\n'
          'Anti-Aliasing: ${_aaMode == 1 ? "FXAA" : "NONE"}';
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
        title: const Text('View Test Sample (viewtest.cpp)'),
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
                    'Sample: viewtest.cpp\n'
                    'Demonstrates FilamentView configuration, anti-aliasing, post-processing toggles, and viewports in real time.',
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
                child: Text(_info, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Shadowing'),
                value: _shadowsEnabled,
                onChanged: (v) {
                  setState(() => _shadowsEnabled = v);
                  _updateViewSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Enable Post-Processing'),
                value: _postProcessingEnabled,
                onChanged: (v) {
                  setState(() => _postProcessingEnabled = v);
                  _updateViewSettings();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Anti-Aliasing Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('NONE'),
                    selected: _aaMode == 0,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _aaMode = 0);
                        _updateViewSettings();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('FXAA'),
                    selected: _aaMode == 1,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _aaMode = 1);
                        _updateViewSettings();
                      }
                    },
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
