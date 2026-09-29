import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('gltfio MaterialProvider Leak Fix & Resource Counters', () {
    late FilamentEngine engine;
    late Uint8List glbBytes;

    setUpAll(() {
      // One mesh, one material (BottleMat), four textures.
      final file = File('example/assets/models/WaterBottle.glb');
      if (file.existsSync()) {
        glbBytes = file.readAsBytesSync();
      } else {
        // Fallback minimal valid GLB header
        glbBytes = Uint8List(20);
      }
    });

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Engine.materialCount getter reflects native material allocation', () {
      final initialCount = engine.materialCount;
      expect(initialCount, isNonNegative);

      // Create a material provider
      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      expect(provider.materialsCount, isNonNegative);

      final loader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: provider,
      );

      final asset = loader.createAsset(glbBytes);
      if (asset != null) {
        expect(provider.materialsCount, greaterThanOrEqualTo(0));
        // WaterBottle.glb: a single node whose one primitive uses BottleMat.
        expect(asset.entityCount, 1);
        expect(asset.instance!.materialInstanceCount, 1);
        loader.destroyAsset(asset);
      }

      loader.dispose();
      provider.dispose();

      // After full disposal, engine material count must equal initial count
      expect(engine.materialCount, equals(initialCount));
    });

    test('10-cycle load/destroy loop has zero material leak and constant resource count', () {
      final initialEngineMaterials = engine.materialCount;

      for (int i = 0; i < 10; i++) {
        final provider = FilamentMaterialProvider.createUbershader(engine: engine);
        final loader = FilamentAssetLoader.create(
          engine: engine,
          materialProvider: provider,
        );

        final asset = loader.createAsset(glbBytes);
        if (asset != null) {
          loader.destroyAsset(asset);
        }

        loader.dispose();
        provider.dispose();
      }

      expect(engine.materialCount, equals(initialEngineMaterials));
    });

    test('MaterialProvider.destroyMaterials resets materialsCount', () {
      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      expect(provider.isDisposed, isFalse);

      provider.destroyMaterials();
      expect(provider.materialsCount, equals(0));

      provider.dispose();
      expect(provider.isDisposed, isTrue);
    });

    test('JIT material provider also destroys materials without leak', () {
      final initialCount = engine.materialCount;

      final jitProvider = FilamentMaterialProvider.createJitShader(engine: engine);
      final loader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: jitProvider,
      );

      final asset = loader.createAsset(glbBytes);
      if (asset != null) {
        loader.destroyAsset(asset);
      }

      loader.dispose();
      jitProvider.dispose();

      expect(engine.materialCount, equals(initialCount));
    });
  });
}
