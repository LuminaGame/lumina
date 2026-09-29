import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('View Smoke Tests', () {
    late FilamentEngine engine;
    late FilamentSwapChain swapChain;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late int cameraEntity;
    
    final List<int> entities = [];

    setUp(() {
      final backendName = Platform.environment['FILAMENT_SMOKE_BACKEND'] ?? 'opengl';
      final backend = switch (backendName) {
        'vulkan' => FilamentBackend.vulkan,
        'noop' => FilamentBackend.noop,
        _ => FilamentBackend.opengl,
      };
      engine = FilamentEngine.create(backend: backend)!;
      swapChain = engine.createHeadlessSwapChain(256, 256);
      renderer = engine.createRenderer();
      scene = engine.createScene();
      view = engine.createView();
      
      cameraEntity = engine.createEntity();
      camera = engine.createCamera(cameraEntity);
      
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, 256, 256);
    });

    tearDown(() {
      for (final entity in entities) {
        engine.destroyEntity(entity);
      }
      engine.destroyEntity(cameraEntity);
      renderer.dispose();
      engine.dispose();
    });

    test('ViewOptions and Camera rendering', () async {
      final suzanne = scene.createSuzanneSample(view);
      entities.add(suzanne);

      // Create a directional light
      final dirLight = engine.createEntity();
      entities.add(dirLight);
      LightBuilder(LightType.directional)
        ..color(1.0, 1.0, 1.0)
        ..intensity(100000.0)
        ..direction(0.5, -1.0, -1.0)
        ..build(engine, dirLight);
      scene.addEntity(dirLight);

      // 1. Configure Camera
      // Using an extreme FOV to prove the projection works and is visible in the artifact
      camera.setProjection(fovDegrees: 120, aspect: 1.0, near: 0.1, far: 100);
      camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);

      // 2. Configure ViewOptions
      renderer.setClearOptions(r: 0.2, g: 0.1, b: 0.2, a: 1.0);
      view.antiAliasing = 1; // FXAA
      view.dithering = Dithering.temporal;
      view.shadowType = ShadowType.vsm;
      view.postProcessingEnabled = true;
      view.blendMode = BlendMode.opaque;

      await renderSmokeTest(
        engine: engine,
        renderer: renderer,
        view: view,
        swapChain: swapChain,
        width: 256,
        height: 256,
        artifactName: 'View Smoke Tests ViewOptions and Camera rendering',
      );
      
      scene.destroySuzanneSample();
    });
  });
}
