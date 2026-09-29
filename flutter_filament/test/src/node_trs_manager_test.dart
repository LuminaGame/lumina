import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Node and TRS Manager Tests', () {
    late FilamentEngine engine;
    late FilamentMaterialProvider materialProvider;
    late FilamentAssetLoader assetLoader;
    late FilamentResourceLoader resourceLoader;
    FilamentAsset? asset;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      materialProvider = FilamentMaterialProvider.createUbershader(engine: engine);
      assetLoader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: materialProvider,
      );
      resourceLoader = FilamentResourceLoader.create(engine: engine);

      // Using the generic glb from previous tests if blackjack is not found.
      var file = File('../test-assets/fixtures/blackjack_blender2.glb');
      if (!file.existsSync()) {
        file = File('../test-assets/fixtures/attackhelicopter.entity.glb');
      }
      
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        asset = assetLoader.createAsset(bytes);
        if (asset != null) {
          resourceLoader.loadResources(asset!);
          asset!.instance;
        }
      }
    });

    tearDown(() {
      if (asset != null) {
        asset!.dispose();
      }
      resourceLoader.dispose();
      assetLoader.dispose();
      materialProvider.dispose();
      if (!engine.isDisposed) engine.dispose();
    });

    test('NodeManager hasComponent works', () {
      if (asset == null) return;
      final nodeManager = assetLoader.nodeManager;
      expect(nodeManager, isNotNull);
      
      final entities = asset!.entities;
      expect(entities.isNotEmpty, isTrue);

      // Find an entity that has the component
      int? targetEntity;
      for (final e in entities) {
        if (nodeManager.hasComponent(e)) {
          targetEntity = e;
          break;
        }
      }
      expect(targetEntity, isNotNull);
    });

    test('Extras round trip', () {
      if (asset == null) return;
      final nodeManager = assetLoader.nodeManager;
      final entity = asset!.entities.last;

      if (!nodeManager.hasComponent(entity)) return;

      final extras = '{"tag":"spawn"}';
      nodeManager.setExtras(entity, extras);
      
      final got = nodeManager.getExtras(entity);
      expect(got, equals(extras));
    });

    test('Scene membership round trip', () {
      if (asset == null) return;
      final nodeManager = assetLoader.nodeManager;
      final entity = asset!.entities.last;

      if (!nodeManager.hasComponent(entity)) return;

      final mask = 2; // 0b10
      nodeManager.setSceneMembership(entity, mask);
      
      final got = nodeManager.getSceneMembership(entity);
      expect(got, equals(mask));
    });

    test('TrsTransformManager setters, getters, and composition', () {
      if (asset == null) return;
      final trs = asset!.trsTransformManager;
      
      final entities = asset!.entities;
      int? targetEntity;
      for (final e in entities) {
        if (trs.hasComponent(e)) {
          targetEntity = e;
          break;
        }
      }
      if (targetEntity == null) return;

      final entity = targetEntity;

      // setTranslation
      trs.setTranslation(entity, 1.0, 2.0, 3.0);
      final t = trs.getTranslation(entity);
      expect(t[0], closeTo(1.0, 1e-5));
      expect(t[1], closeTo(2.0, 1e-5));
      expect(t[2], closeTo(3.0, 1e-5));

      // setRotation (90 deg Y axis = 0, 0.7071, 0, 0.7071)
      trs.setRotation(entity, 0.0, 0.7071068, 0.0, 0.7071068);
      final r = trs.getRotation(entity);
      expect(r[0].abs(), closeTo(0.0, 1e-5));
      expect(r[1].abs(), closeTo(0.7071068, 1e-5));
      expect(r[2].abs(), closeTo(0.0, 1e-5));
      expect(r[3].abs(), closeTo(0.7071068, 1e-5));

      // getTransform (composed)
      final mat4 = trs.getTransform(entity);
      
      // We expect translation in index 12,13,14
      expect(mat4[12], closeTo(1.0, 1e-5));
      expect(mat4[13], closeTo(2.0, 1e-5));
      expect(mat4[14], closeTo(3.0, 1e-5));
    });

    test('TrsTransformManager setTrs equivalent to separate setters', () {
      if (asset == null) return;
      final trs = asset!.trsTransformManager;
      
      final entities = asset!.entities;
      int? entity;
      for (final e in entities) {
        if (trs.hasComponent(e)) {
          entity = e;
          break;
        }
      }
      if (entity == null) return;

      trs.setTranslation(entity, 1.0, 2.0, 3.0);
      trs.setRotation(entity, 0.0, 0.7071068, 0.0, 0.7071068);
      trs.setScale(entity, 2.0, 2.0, 2.0);
      final sepMat = trs.getTransform(entity);

      trs.setTrs(
        entity, 
        Float32List.fromList([1.0, 2.0, 3.0]), 
        Float32List.fromList([0.0, 0.7071068, 0.0, 0.7071068]), 
        Float32List.fromList([2.0, 2.0, 2.0])
      );
      final singleMat = trs.getTransform(entity);

      for (int i = 0; i < 16; i++) {
        expect(singleMat[i], closeTo(sepMat[i], 1e-5));
      }
    });
  });
}
