import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Material Smoke Tests', () {
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

    test('Material compilation and parameters rendering', () async {
      final suzanne = scene.createSuzanneSample(view);
      entities.add(suzanne);

      // Create a directional light so we can see the shaded material
      final dirLight = engine.createEntity();
      entities.add(dirLight);
      LightBuilder(LightType.directional)
        ..color(1.0, 1.0, 1.0)
        ..intensity(100000.0)
        ..direction(0.5, -1.0, -1.0)
        ..build(engine, dirLight);
      scene.addEntity(dirLight);

      // 1. Compile a lit material
      FilamentMaterialBuilder.initEngine();
      final matBuilder = FilamentMaterialBuilder.create();
      matBuilder.setName('LitMaterial');
      matBuilder.setShading(FilamatShading.lit);
      matBuilder.requireAttribute(VertexAttribute.position.value);
      matBuilder.requireAttribute(VertexAttribute.tangents.value);
      matBuilder.addParameter('baseColor', UniformType.float3);
      matBuilder.addParameter('roughness', UniformType.floatType);
      matBuilder.addParameter('metallic', UniformType.floatType);
      matBuilder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = materialParams.baseColor;
            material.roughness = materialParams.roughness;
            material.metallic = materialParams.metallic;
        }
      ''');
      final matBytes = matBuilder.build();
      matBuilder.dispose();
      expect(matBytes, isNotNull);
      
      final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: matBytes!);
      
      // 2. Create MaterialInstance and adjust parameters
      final instance = material.createInstance();
      instance.setFloat3('baseColor', 0.2, 0.4, 0.8);
      instance.setFloat('roughness', 0.1); // shiny
      instance.setFloat('metallic', 1.0);  // metallic
      
      // Assign the new material instance to the Suzanne model
      final renderableManager = FilamentRenderableManager(engine);
      renderableManager.setMaterialInstanceAt(suzanne, 0, instance);
      
      await renderSmokeTest(
        engine: engine,
        renderer: renderer,
        view: view,
        swapChain: swapChain,
        width: 256,
        height: 256,
        artifactName: 'Material Smoke Tests Material compilation and parameters rendering',
      );
      
      scene.destroySuzanneSample();
      instance.dispose();
      material.dispose();
    });
  });
}
