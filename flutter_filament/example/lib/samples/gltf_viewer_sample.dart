import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class GltfViewerSample extends StatefulWidget {
  const GltfViewerSample({super.key});

  @override
  State<GltfViewerSample> createState() => _GltfViewerSampleState();
}

class _GltfViewerSampleState extends State<GltfViewerSample> {
  String _info = 'Loading 3D glTF Model (WaterBottle.glb)...';
  FilamentScene? _scene;
  FilamentAsset? _asset;
  FilamentAssetLoader? _loader;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;
  FilamentCameraManipulator? _cameraManipulator;

  Future<void> _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) async {
    _scene = scene;

    // 1. Load IBL & Skybox from Flutter assets
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
      debugPrint('[GltfViewerSample]: IBL loading fallback: $e');
    }

    // 2. Load WaterBottle.glb
    try {
      final glbBytes = await rootBundle.load('assets/models/WaterBottle.glb');
      final materialProvider = FilamentMaterialProvider.createJitShader(
        engine: engine,
      );
      final loader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: materialProvider,
      );
      _loader = loader;

      final asset = loader.createAsset(glbBytes.buffer.asUint8List());
      _asset = asset;

      if (asset != null) {
        final resourceLoader = FilamentResourceLoader.create(
          engine: engine,
          normalizeSkinningWeights: true,
        );
        resourceLoader.loadResources(asset);
        resourceLoader.dispose();

        asset.addToScene(scene);

        // 3. Orbit camera framed on the model's bounds (the bottle is about
        // 0.26 m tall, so a fixed home position would leave it tiny).
        final bounds = asset.instance?.boundingBox;
        final manipulator = bounds == null || bounds.isEmpty
            ? _defaultManipulator()
            : _framedManipulator(bounds);

        if (mounted) {
          setState(() {
            _cameraManipulator = manipulator;
            _info = 'glTF Model Loaded Successfully (gltf_viewer.cpp)!\n'
                'Model: WaterBottle.glb\n'
                'Entity Count: ${asset.entityCount}\n'
                'IBL Lighting: lightroom_14b\n'
                'Camera: Drag mouse to Orbit, Wheel to Zoom';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cameraManipulator = _defaultManipulator();
            _info = 'Failed to load WaterBottle.glb asset';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraManipulator ??= _defaultManipulator();
          _info = 'Error loading glTF model: $e';
        });
      }
    }
  }

  FilamentCameraManipulator _defaultManipulator() => FilamentCameraManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 800,
        viewportHeight: 600,
      );

  /// An orbit manipulator aimed at the centre of [bounds], far enough back
  /// that the bounding sphere fits the widget's 45 degree vertical field of
  /// view with a small margin.
  FilamentCameraManipulator _framedManipulator(Aabb bounds) {
    final center = bounds.center;
    final radius = bounds.extent.length;
    const halfFov = 22.5 * math.pi / 180.0;
    final distance = radius / math.sin(halfFov) * 1.1;
    final builder = ManipulatorBuilder()
        .viewport(800, 600)
        .targetPosition(center.x, center.y, center.z)
        .orbitHomePosition(center.x, center.y, center.z + distance)
        .zoomSpeed(distance / 20.0);
    try {
      return builder.build(ManipulatorMode.orbit);
    } finally {
      builder.dispose();
    }
  }

  void _cleanupResources() {
    if (_asset != null && _scene != null) {
      _asset!.removeFromScene(_scene!);
    }
    _asset?.dispose();
    _asset = null;
    _loader?.dispose();
    _loader = null;
    _skybox?.dispose();
    _skybox = null;
    _ibl?.dispose();
    _ibl = null;
    _cameraManipulator?.dispose();
    _cameraManipulator = null;
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
        title: const Text('glTF Viewer Sample (gltf_viewer.cpp)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.view_in_ar, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sample: gltf_viewer.cpp\n'
                        'Renders a full 3D PBR glTF asset (WaterBottle.glb) with IBL lighting & interactive mouse camera manipulator.',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FilamentWidget(
                  height: 550,
                  cameraManipulator: _cameraManipulator,
                  onSceneCreated: (engine, scene, camera, view) {
                    _setup3dScene(engine, scene, camera, view);
                  },
                  onDispose: _cleanupResources,
                ),
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
          ],
        ),
      ),
    );
  }
}
