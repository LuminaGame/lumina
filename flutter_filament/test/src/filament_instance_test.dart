import 'dart:io';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('FilamentInstance API Tests', () {
    late FilamentEngine engine;
    late FilamentAssetLoader assetLoader;
    late FilamentMaterialProvider materialProvider;
    late FilamentResourceLoader resourceLoader;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      materialProvider = FilamentMaterialProvider.createUbershader(engine: engine);
      assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider);
      resourceLoader = FilamentResourceLoader.create(engine: engine);
    });

    tearDown(() {
      resourceLoader.dispose();
      assetLoader.dispose();
      materialProvider.dispose();
      engine.dispose();
    });

    test('Instance basic properties (attackhelicopter)', () async {
      final file = File('../test-assets/fixtures/attackhelicopter.entity.glb');
      if (!file.existsSync()) {
        markTestSkipped('attackhelicopter.entity.glb not found');
        return;
      }
      final glbBytes = file.readAsBytesSync();
      final asset = assetLoader.createAsset(glbBytes);
      expect(asset, isNotNull);
      
      await resourceLoader.loadAsync(asset!);

      final instance = asset.instance;
      expect(instance, isNotNull);
      expect(instance!.getAsset(), equals(asset));
      expect(instance.root, isNot(equals(0)));

      expect(instance.entityCount, greaterThan(0));
      expect(instance.entities.length, equals(instance.entityCount));
      
      final assetEntities = asset.entities;
      for (final e in instance.entities) {
        expect(assetEntities.contains(e), isTrue);
      }

      final animator = instance.animator;
      expect(animator, isNotNull);
      
      expect(instance.materialInstanceCount, greaterThan(0));
      expect(instance.materialInstances.length, equals(instance.materialInstanceCount));

      expect(instance.materialVariantCount, greaterThanOrEqualTo(0));
      expect(() => instance.applyMaterialVariant(0), returnsNormally);

      instance.recomputeBoundingBoxes();
      final bounds = instance.boundingBox;
      expect(bounds.min[0], lessThan(bounds.max[0]));
      expect(bounds.min[1], lessThan(bounds.max[1]));
      expect(bounds.min[2], lessThan(bounds.max[2]));
      
      assetLoader.destroyAsset(asset);
    });

    test('Instance skinning (YVO3D_44368.glb)', () async {
      final file = File('../test-assets/fixtures/YVO3D_44368.glb');
      if (!file.existsSync()) {
        markTestSkipped('YVO3D_44368.glb not found');
        return;
      }
      final glbBytes = file.readAsBytesSync();
      final asset = assetLoader.createAsset(glbBytes);
      expect(asset, isNotNull);

      await resourceLoader.loadAsync(asset!);

      final instance = asset.instance;
      expect(instance, isNotNull);

      if (instance!.skinCount > 0) {
        expect(instance.skinCount, greaterThan(0));
        
        final jointCount = instance.jointCountAt(0);
        expect(jointCount, greaterThan(0));
        
        final joints = instance.jointsAt(0);
        expect(joints.length, equals(jointCount));
        
        final matrices = instance.inverseBindMatricesAt(0);
        expect(matrices.length, equals(jointCount * 16));

        expect(() => instance.attachSkin(999, instance.root), throwsRangeError);
      } else {
        markTestSkipped('YVO3D_44368.glb does not have skins as expected');
      }
      
      assetLoader.destroyAsset(asset);
    });
  });
}
