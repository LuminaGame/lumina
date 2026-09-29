import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

enum EnvironmentPreset {
  lightroom('Lightroom 14b', 'assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx', 'assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx'),
  venetian('Venetian Crossroads 2K', 'assets/ibl/venetian_crossroads_2k/venetian_crossroads_2k_ibl.ktx', 'assets/ibl/venetian_crossroads_2k/venetian_crossroads_2k_skybox.ktx'),
  pillars('Pillars 2K', 'assets/ibl/pillars_2k/pillars_2k_ibl.ktx', 'assets/ibl/pillars_2k/pillars_2k_skybox.ktx'),
  defaultEnv('Default Studio', 'assets/ibl/default_env/default_env_ibl.ktx', 'assets/ibl/default_env/default_env_skybox.ktx');

  final String title;
  final String iblPath;
  final String skyboxPath;

  const EnvironmentPreset(this.title, this.iblPath, this.skyboxPath);
}

class SkyboxSample extends StatefulWidget {
  const SkyboxSample({super.key});

  @override
  State<SkyboxSample> createState() => _SkyboxSampleState();
}

class _SkyboxSampleState extends State<SkyboxSample> {
  String _info = 'Initializing Skybox & Environment sample...';
  EnvironmentPreset _selectedPreset = EnvironmentPreset.venetian;
  bool _showSun = true;
  final double _iblIntensity = 100000.0;

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentCameraManipulator? _manipulator;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;

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

    _loadEnvironment(_selectedPreset);
  }

  void _loadEnvironment(EnvironmentPreset preset) {
    if (_engine == null || _scene == null) return;

    _ibl?.dispose();
    _skybox?.dispose();
    _ibl = null;
    _skybox = null;

    rootBundle.load(preset.iblPath).then((iblData) {
      if (mounted && _engine != null) {
        final ibl = FilamentIndirectLight.fromKtx(
          _engine!,
          iblData.buffer.asUint8List(),
          intensity: _iblIntensity,
        );
        _ibl = ibl;
        _scene?.setIndirectLight(ibl);
      }
    });

    rootBundle.load(preset.skyboxPath).then((skyData) {
      if (mounted && _engine != null) {
        final skybox = FilamentSkybox.fromKtx(
          _engine!,
          skyData.buffer.asUint8List(),
          showSun: _showSun,
        );
        _skybox = skybox;
        _scene?.setSkybox(skybox);
      }
    });

    setState(() {
      _info = 'Skybox & Environment Sample\n'
          'Active Preset: ${preset.title}\n'
          'IBL Intensity: ${_iblIntensity.toInt()} lx | Show Sun: $_showSun\n'
          'KTX Cubemap Textures Loaded Successfully!';
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
        title: const Text('Skybox & Environment Sample'),
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
                    'Sample: skybox & Image-Based Lighting (IBL)\n'
                    'Demonstrates cubemap skybox rendering, HDR environment lighting, and real-time environment preset switching.',
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
              const SizedBox(height: 16),
              const Text('Select Environment Preset:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: EnvironmentPreset.values.map((preset) {
                  return ChoiceChip(
                    label: Text(preset.title),
                    selected: _selectedPreset == preset,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPreset = preset);
                        _loadEnvironment(preset);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Show Sun in Skybox'),
                value: _showSun,
                onChanged: (val) {
                  setState(() => _showSun = val);
                  _loadEnvironment(_selectedPreset);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
