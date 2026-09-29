import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Instanced Asset API Tests', () {
    late FilamentEngine engine;
    late Uint8List glbBytes;

    setUpAll(() {
      final file = File('../test-assets/fixtures/blackjack_blender2.glb');
      if (file.existsSync()) {
        glbBytes = file.readAsBytesSync();
      } else {
        glbBytes = Uint8List(0);
      }
    });

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('createInstancedAsset returns distinct instances with shared buffer cost', () {
      if (glbBytes.isEmpty) return; // Skip if no glb

      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      
      final singleAsset = loader.createAsset(glbBytes);
      final singleVbCount = engine.vertexBufferCount;
      final singleIbCount = engine.indexBufferCount;
      singleAsset!.dispose();

      // Ensure disposed
      loader.gc();

      final initialVbCount = engine.vertexBufferCount;
      final initialIbCount = engine.indexBufferCount;

      final (asset, instances) = loader.createInstancedAsset(glbBytes, 3);
      expect(asset, isNotNull);
      expect(instances.length, equals(3));
      
      final instancedVbCount = engine.vertexBufferCount;
      final instancedIbCount = engine.indexBufferCount;

      // Buffer cost should be the same as single asset (plus initial base)
      expect(instancedVbCount - initialVbCount, equals(singleVbCount - initialVbCount));
      expect(instancedIbCount - initialIbCount, equals(singleIbCount - initialIbCount));

      // distinct entities
      final root0 = instances[0].root;
      final root1 = instances[1].root;
      final root2 = instances[2].root;
      expect(root0, isNot(equals(root1)));
      expect(root1, isNot(equals(root2)));
      expect(root0, isNot(equals(root2)));

      final entities0 = instances[0].entities.toSet();
      final entities1 = instances[1].entities.toSet();
      expect(entities0.intersection(entities1).isEmpty, isTrue);

      // createInstance on loaded instanced asset
      final instance4 = loader.createInstance(asset!);
      expect(instance4, isNotNull);
      expect(instance4!.root, isNot(equals(root0)));

      // destroy Asset -> instances become invalid
      asset.dispose();
      
      loader.dispose();
      provider.dispose();
    });

    test('createInstance on non-instanced asset returns null', () {
      if (glbBytes.isEmpty) return;

      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      
      final asset = loader.createAsset(glbBytes);
      expect(asset, isNotNull);

      final instance = loader.createInstance(asset!);
      expect(instance, isNull);

      asset.dispose();
      loader.dispose();
      provider.dispose();
    });
  });
}
