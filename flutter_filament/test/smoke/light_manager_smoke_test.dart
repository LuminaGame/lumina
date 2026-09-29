import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('LightManager Smoke Tests', () {
    late FilamentEngine engine;
    late FilamentSwapChain swapChain;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late int cameraEntity;
    
    // We keep track of entities to clean them up
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
      
      camera.setProjection(fovDegrees: 45, aspect: 1.0, near: 0.1, far: 100);
      camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 5, centerX: 0, centerY: 0, centerZ: 0);
      
      renderer.setClearOptions(r: 0.1, g: 0.1, b: 0.1, a: 1);
    });

    tearDown(() {
      for (final entity in entities) {
        engine.destroyEntity(entity);
      }
      engine.destroyEntity(cameraEntity);
      
      renderer.dispose();
      engine.dispose();
    });

    test('Directional and Spot Light rendering', () async {
      final suzanne = scene.createSuzanneSample(view);
      entities.add(suzanne);
      
      // 1. Add Directional Light
      final dirLight = engine.createEntity();
      entities.add(dirLight);
      LightBuilder(LightType.directional)
        ..color(1.0, 0.9, 0.8)
        ..intensity(100000.0)
        ..direction(0.5, -1.0, -1.0)
        ..castShadows(true)
        ..build(engine, dirLight);
      scene.addEntity(dirLight);

      // 2. Add Spot Light (red)
      final spotLight = engine.createEntity();
      entities.add(spotLight);
      LightBuilder(LightType.spot)
        ..color(1.0, 0.0, 0.0)
        ..intensity(500000.0)
        ..position(-2.0, 2.0, 2.0)
        ..direction(1.0, -1.0, -1.0)
        ..spotLightCone(0.1, 0.5)
        ..falloff(10.0)
        ..build(engine, spotLight);
      scene.addEntity(spotLight);
      
      await renderSmokeTest(
        engine: engine,
        renderer: renderer,
        view: view,
        swapChain: swapChain,
        width: 256,
        height: 256,
        artifactName: 'LightManager Smoke Tests Directional and Spot Light rendering',
      );
      
      scene.destroySuzanneSample();
    });
  });
}
