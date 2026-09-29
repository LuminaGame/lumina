import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Filament Engine & Core Lifecycle', () {
    test('create and dispose engine', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);
      expect(engine!.isDisposed, isFalse);

      engine.dispose();
      expect(engine.isDisposed, isTrue);
      expect(() => engine.createRenderer(), throwsStateError);
    });

    test('create renderer, view, scene, camera', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final renderer = engine!.createRenderer();
      expect(renderer.isDisposed, isFalse);

      final view = engine.createView();
      expect(view.isDisposed, isFalse);

      final scene = engine.createScene();
      expect(scene.isDisposed, isFalse);

      final entity = engine.createEntity();
      expect(entity, greaterThan(0));

      final camera = engine.createCamera(entity);
      expect(camera.isDisposed, isFalse);

      view.scene = scene;
      view.camera = camera;

      camera.dispose();
      scene.dispose();
      view.dispose();
      renderer.dispose();
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('headless swap chain creation', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final swapChain = engine!.createHeadlessSwapChain(800, 600);
      expect(swapChain.isDisposed, isFalse);

      swapChain.dispose();
      engine.dispose();
    });

    test('camera configuration (projection, lookAt, exposure)', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final entity = engine!.createEntity();
      final camera = engine.createCamera(entity);

      camera.setProjection(
        fovDegrees: 45,
        aspect: 16 / 9,
        near: 0.1,
        far: 100.0,
      );

      camera.lookAt(
        eyeX: 0,
        eyeY: 0,
        eyeZ: 5,
        centerX: 0,
        centerY: 0,
        centerZ: 0,
      );

      camera.setExposure(
        aperture: 16.0,
        shutterSpeed: 1 / 125,
        sensitivity: 100,
      );

      camera.dispose();
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('transform manager API', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final transformManager = FilamentTransformManager(engine!);
      final entity = engine.createEntity();

      transformManager.create(entity);

      final identityMatrix = [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ];
      transformManager.setTransform(entity, identityMatrix);

      transformManager.destroy(entity);
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('buffers and geometry creation', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final vb = FilamentVertexBuffer.create(
        engine: engine!,
        vertexCount: 3,
        bufferCount: 1,
      );
      expect(vb.isDisposed, isFalse);

      final positions = Float32List.fromList([
        0.0, 1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
      ]);
      vb.setData(positions);

      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 3,
        type: IndexType.ushort,
      );
      expect(ib.isDisposed, isFalse);

      final indices = Uint16List.fromList([0, 1, 2]);
      ib.setUint16Data(indices);

      ib.dispose();
      vb.dispose();
      engine.dispose();
    });

    test('light manager API', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final lightManager = FilamentLightManager(engine!);
      final entity = engine.createEntity();

      lightManager.createLight(
        entity: entity,
        type: LightType.sun,
        intensity: 100000.0,
        colorR: 1.0,
        colorG: 0.95,
        colorB: 0.9,
      );

      lightManager.destroy(entity);
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('skybox and texture creation', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final skybox = FilamentSkybox.createColor(
        engine: engine!,
        r: 0.1,
        g: 0.2,
        b: 0.3,
      );
      expect(skybox.isDisposed, isFalse);

      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 64,
        height: 64,
      );
      expect(texture.isDisposed, isFalse);

      texture.dispose();
      skybox.dispose();
      engine.dispose();
    });

    test('glTF loader and animator API', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final resourceLoader = FilamentResourceLoader.create(engine: engine!);
      expect(resourceLoader.isDisposed, isFalse);

      resourceLoader.dispose();
      engine.dispose();
    });

    test('manipulator API', () {
      final manipulator = FilamentCameraManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 1024,
        viewportHeight: 768,
      );
      expect(manipulator.isDisposed, isFalse);

      manipulator.grabBegin(100, 100);
      manipulator.grabUpdate(150, 120);
      manipulator.grabEnd();

      final lookAt = manipulator.getLookAt();
      expect(lookAt.eye.length, equals(3));
      expect(lookAt.center.length, equals(3));
      expect(lookAt.up.length, equals(3));

      manipulator.dispose();
    });

    test('filamat runtime material builder API', () {
      FilamentMaterialBuilder.initEngine();

      final builder = FilamentMaterialBuilder.create();
      expect(builder.isDisposed, isFalse);

      builder.setName('DynamicRedMaterial');
      builder.setShading(FilamatShading.lit);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor.rgb = float3(1.0, 0.0, 0.0);
        }
      ''');

      builder.dispose();
    });
  });
}



