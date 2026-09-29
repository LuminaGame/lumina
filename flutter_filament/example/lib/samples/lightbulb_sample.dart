import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class LightbulbSample extends StatefulWidget {
  const LightbulbSample({super.key});

  @override
  State<LightbulbSample> createState() => _LightbulbSampleState();
}

class _LightbulbSampleState extends State<LightbulbSample> {
  String _info = 'Initializing Lightbulb sample...';
  LightType _selectedType = LightType.point;
  Color _lightColor = Colors.amber;
  final double _intensity = 100000.0;

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentLightManager? _lightManager;
  int? _lightEntity;
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
    _updateLight();
  }

  void _updateLight() {
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
      type: _selectedType,
      colorR: _lightColor.r,
      colorG: _lightColor.g,
      colorB: _lightColor.b,
      intensity: _intensity,
      dirX: 0.5,
      dirY: -1.0,
      dirZ: -1.0,
      castShadows: true,
    );

    _scene!.addEntity(entity);

    setState(() {
      _info = 'Lightbulb Sample (lightbulb.cpp)\n'
          'Active Light Type: ${_selectedType.name.toUpperCase()}\n'
          'Color: RGB(${(_lightColor.r * 255).toInt()}, ${(_lightColor.g * 255).toInt()}, ${(_lightColor.b * 255).toInt()})\n'
          'Intensity: ${_intensity.toInt()} lm | Cast Shadows: True';
    });
  }

  void _cleanupResources() {
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
        title: const Text('Lightbulb & Shadows Sample (lightbulb.cpp)'),
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
                    'Sample: lightbulb.cpp\n'
                    'Demonstrates dynamic 3D lighting management (Point, Spot, Directional, Sun) and shadow casting.',
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
                child: Text(
                  _info,
                  style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Light Type:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: LightType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.name.toUpperCase()),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                        _updateLight();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Color Preset: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.circle, color: Colors.amber),
                    onPressed: () {
                      setState(() => _lightColor = Colors.amber);
                      _updateLight();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.circle, color: Colors.cyanAccent),
                    onPressed: () {
                      setState(() => _lightColor = Colors.cyanAccent);
                      _updateLight();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.circle, color: Colors.deepOrange),
                    onPressed: () {
                      setState(() => _lightColor = Colors.deepOrange);
                      _updateLight();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.circle, color: Colors.purpleAccent),
                    onPressed: () {
                      setState(() => _lightColor = Colors.purpleAccent);
                      _updateLight();
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
