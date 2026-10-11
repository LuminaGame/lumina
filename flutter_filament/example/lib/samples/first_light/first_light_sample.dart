import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

import 'package:flutter_filament_example/samples/first_light/first_light_models_io.dart'
    if (dart.library.js_interop) 'package:flutter_filament_example/samples/first_light/first_light_models_web.dart';

/// The application id the Android build installs as (android/app/build.gradle.kts).
const firstLightApplicationId = 'com.lumina.flutter_filament_example';

/// A device's first frames: real glTF models on disk, lit by a sun and an IBL,
/// turning, with the backend, the GPU and the frame times logged every two
/// seconds (`[first_light]` lines; logcat on Android). Launch it directly with
/// `--dart-define=FLUTTER_FILAMENT_SAMPLE=first_light`.
class FirstLightSample extends StatefulWidget {
  const FirstLightSample({super.key});

  @override
  State<FirstLightSample> createState() => _FirstLightSampleState();
}

class _FirstLightSampleState extends State<FirstLightSample> {
  String _info = 'Loading models...';
  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentAssetLoader? _loader;
  FilamentMaterialProvider? _materials;
  final List<FilamentAsset> _assets = [];
  final List<(int, double)> _roots = [];
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;
  int? _sun;
  FilamentCameraManipulator? _manipulator;
  final Stopwatch _clock = Stopwatch()..start();
  int _frames = 0;
  Duration _cpu = Duration.zero;
  Duration _frame = Duration.zero;
  int _lastReportMs = 0;
  String _device = '';

  Future<void> _setup(FilamentEngine engine, FilamentScene scene, FilamentCamera camera, FilamentView view) async {
    _engine = engine;
    _scene = scene;
    _device = 'backend ${engine.backend.name}, feature level ${engine.activeFeatureLevel.name}, '
        'GPU "${engine.gpuName}"';
    debugPrint('[first_light] engine: $_device');

    final sun = engine.createEntity();
    _sun = sun;
    FilamentLightManager(engine).createLight(
      entity: sun,
      type: LightType.sun,
      colorR: 0.98,
      colorG: 0.92,
      colorB: 0.89,
      intensity: 110000.0,
      dirX: 0.6,
      dirY: -1.0,
      dirZ: -0.8,
      castShadows: false,
    );
    scene.addEntity(sun);
    try {
      final iblBytes = await rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx');
      final skyBytes = await rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx');
      _ibl = FilamentIndirectLight.fromKtx(engine, iblBytes.buffer.asUint8List(), intensity: 30000.0);
      _skybox = FilamentSkybox.fromKtx(engine, skyBytes.buffer.asUint8List(), showSun: true);
      scene.setIndirectLight(_ibl!);
      scene.setSkybox(_skybox!);
    } catch (e) {
      debugPrint('[first_light] IBL not loaded: $e');
    }

    final models = await loadFirstLightModels(firstLightApplicationId);
    if (!mounted) return;
    if (models.isEmpty) {
      setState(() => _info = 'No .glb models in ${firstLightModelFolder(firstLightApplicationId)}');
      debugPrint('[first_light] $_info');
      return;
    }
    // Android's glTF loader has no JIT materials; the ubershader archive works everywhere.
    final materials = FilamentPlatformInfo.hasJitMaterialProvider
        ? FilamentMaterialProvider.jit(engine)
        : FilamentMaterialProvider.ubershader(engine);
    _materials = materials;
    final loader = FilamentAssetLoader.create(engine: engine, materialProvider: materials);
    _loader = loader;
    var extent = 0.0;
    final loaded = <String>[];
    for (final (name, bytes) in models) {
      final asset = loader.createAsset(bytes);
      if (asset == null) continue;
      final resources = FilamentResourceLoader.create(engine: engine, normalizeSkinningWeights: true);
      resources.loadResources(asset);
      resources.dispose();
      asset.addToScene(scene);
      _assets.add(asset);
      loaded.add(name);
      final box = asset.getBoundingBox();
      extent = math.max(extent, box.extent.length);
    }
    final spacing = math.max(extent * 2.2, 0.1);
    for (var i = 0; i < _assets.length; i++) {
      _roots.add((_assets[i].rootEntity, (i - (_assets.length - 1) / 2) * spacing));
    }
    final width = spacing * _assets.length;
    const halfFov = 22.5 * math.pi / 180.0;
    final distance = math.max(width * 0.6, extent) / math.sin(halfFov);
    final builder = ManipulatorBuilder()
        .viewport(800, 600)
        .targetPosition(0, 0, 0)
        .orbitHomePosition(0, extent * 0.6, distance)
        .zoomSpeed(distance / 20.0);
    try {
      _manipulator = builder.build(ManipulatorMode.orbit);
    } finally {
      builder.dispose();
    }
    setState(() => _info = '${loaded.join(', ')}\n$_device');
    debugPrint('[first_light] models: ${loaded.join(', ')}');
  }

  void _onFrame(Duration cpu, Duration frame) {
    final engine = _engine;
    if (engine == null) return;
    // Each model turns about its own vertical axis, a quarter turn every two seconds.
    final angle = _clock.elapsedMilliseconds / 1000.0 * math.pi / 4;
    final c = math.cos(angle), s = math.sin(angle);
    final transforms = FilamentTransformManager(engine);
    for (final (root, x) in _roots) {
      transforms.setTransform(root, [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, x, 0, 0, 1]);
    }
    _frames++;
    _cpu += cpu;
    _frame += frame;
    final now = _clock.elapsedMilliseconds;
    if (now - _lastReportMs >= 2000) {
      final seconds = (now - _lastReportMs) / 1000.0;
      debugPrint('[first_light] ${(_frames / seconds).toStringAsFixed(1)} fps, '
          'cpu ${(_cpu.inMicroseconds / _frames / 1000).toStringAsFixed(2)} ms, '
          'frame ${(_frame.inMicroseconds / _frames / 1000).toStringAsFixed(2)} ms over $_frames frames');
      _frames = 0;
      _cpu = Duration.zero;
      _frame = Duration.zero;
      _lastReportMs = now;
    }
  }

  void _cleanup() {
    final scene = _scene;
    for (final asset in _assets) {
      if (scene != null) asset.removeFromScene(scene);
      asset.dispose();
    }
    _assets.clear();
    _roots.clear();
    _loader?.dispose();
    _loader = null;
    _materials?.dispose();
    _materials = null;
    _skybox?.dispose();
    _skybox = null;
    _ibl?.dispose();
    _ibl = null;
    final sun = _sun;
    if (sun != null && scene != null) scene.removeEntity(sun);
    _sun = null;
    _manipulator?.dispose();
    _manipulator = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First light')),
      body: Column(
        children: [
          Expanded(
            child: FilamentWidget(
              cameraManipulator: _manipulator,
              showFpsBadge: true,
              onFrame: _onFrame,
              onSceneCreated: _setup,
              onDispose: _cleanup,
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Text(_info, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
