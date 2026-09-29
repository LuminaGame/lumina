import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('glTF Material Leak Tests', () {
    late FilamentEngine engine;
    late Uint8List glbBytes;

    setUpAll(() {
      final file = File('../test-assets/fixtures/blackjack_blender2.glb');
      if (file.existsSync()) {
        glbBytes = file.readAsBytesSync();
      } else {
        // Fallback for CI if not present
        glbBytes = Uint8List(0);
      }
    });

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('Engine material counter returns to initial after ubershader asset destroy', () {
      if (glbBytes.isEmpty) return; // Skip if no glb
      
      final initialMaterialCount = engine.materialCount;

      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      
      final asset = loader.createAsset(glbBytes);
      expect(asset, isNotNull);

      // Loading materials takes place, counter should be higher
      final loadedMaterialCount = engine.materialCount;
      expect(loadedMaterialCount, greaterThan(initialMaterialCount));
      expect(provider.materialsCount, greaterThan(0));

      // Destroy order: Asset -> Loader -> Provider
      asset!.dispose();
      loader.dispose();
      provider.dispose(); // This should invoke destroyMaterials

      final finalMaterialCount = engine.materialCount;
      expect(finalMaterialCount, equals(initialMaterialCount));
      // provider.materialsCount is disposed so we can't check it directly, but it should be 0.
    });

    test('Leak regression: 10 iterations do not monotonically grow material count', () {
      if (glbBytes.isEmpty) return;
      
      final initialMaterialCount = engine.materialCount;

      for (int i = 0; i < 10; i++) {
        final provider = FilamentMaterialProvider.createUbershader(engine: engine);
        final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
        final asset = loader.createAsset(glbBytes);
        
        asset!.dispose();
        loader.dispose();
        provider.dispose();
      }

      final finalMaterialCount = engine.materialCount;
      expect(finalMaterialCount, equals(initialMaterialCount));
    });

    test('Same leak test for JIT provider', () {
      if (glbBytes.isEmpty) return;
      
      final initialMaterialCount = engine.materialCount;

      final provider = FilamentMaterialProvider.createJitShader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      final asset = loader.createAsset(glbBytes);
      
      asset!.dispose();
      loader.dispose();
      provider.dispose();

      final finalMaterialCount = engine.materialCount;
      expect(finalMaterialCount, equals(initialMaterialCount));
    });

    test('Wrong-order guard raises StateError', () {
      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      
      // Should throw if provider is disposed before loader
      expect(() => provider.dispose(), throwsA(isA<StateError>()));

      loader.dispose();
      
      // Now it should succeed
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
