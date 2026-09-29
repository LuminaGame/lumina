import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntityManager Destruction Callbacks Tests', () {
    test('Bulk destroy delivers batch of destroyed entity IDs', () async {
      final destroyedIds = <int>{};
      final completer = Completer<void>();

      final entities = EntityManager.createEntities(5);
      final expectedSet = entities.toSet();

      final subscription = EntityManager.addDestructionListener((batch) {
        destroyedIds.addAll(batch);
        if (destroyedIds.containsAll(expectedSet) && !completer.isCompleted) {
          completer.complete();
        }
      });

      EntityManager.destroyEntities(entities);

      await completer.future.timeout(const Duration(seconds: 2));
      expect(destroyedIds.containsAll(expectedSet), isTrue);

      subscription.cancel();
    });

    test('Singular destroy delivers batch containing single entity ID', () async {
      final entity = EntityManager.get().create();
      final completer = Completer<Uint32List>();

      final subscription = EntityManager.addDestructionListener((batch) {
        if (batch.contains(entity) && !completer.isCompleted) {
          completer.complete(batch);
        }
      });

      EntityManager.get().destroy(entity);

      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received.contains(entity), isTrue);

      subscription.cancel();
    });

    test('After cancel(), further destroys deliver nothing', () async {
      final receivedIds = <int>[];
      final subscription = EntityManager.addDestructionListener((batch) {
        receivedIds.addAll(batch);
      });

      final e1 = EntityManager.get().create();
      EntityManager.get().destroy(e1);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(receivedIds.contains(e1), isTrue);

      subscription.cancel();
      receivedIds.clear();

      final e2 = EntityManager.get().create();
      EntityManager.get().destroy(e2);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(receivedIds.contains(e2), isFalse);
    });

    test('Two concurrent subscriptions both receive same destruction IDs', () async {
      final sub1Ids = <int>{};
      final sub2Ids = <int>{};
      final comp1 = Completer<void>();
      final comp2 = Completer<void>();

      final entities = EntityManager.createEntities(3);
      final expectedSet = entities.toSet();

      final sub1 = EntityManager.addDestructionListener((batch) {
        sub1Ids.addAll(batch);
        if (sub1Ids.containsAll(expectedSet) && !comp1.isCompleted) {
          comp1.complete();
        }
      });

      final sub2 = EntityManager.addDestructionListener((batch) {
        sub2Ids.addAll(batch);
        if (sub2Ids.containsAll(expectedSet) && !comp2.isCompleted) {
          comp2.complete();
        }
      });

      EntityManager.destroyEntities(entities);

      await Future.wait([
        comp1.future.timeout(const Duration(seconds: 2)),
        comp2.future.timeout(const Duration(seconds: 2)),
      ]);

      expect(sub1Ids.containsAll(expectedSet), isTrue);
      expect(sub2Ids.containsAll(expectedSet), isTrue);

      // Cancelling sub1 leaves sub2 working
      sub1.cancel();
      sub2Ids.clear();

      final e3 = EntityManager.get().create();
      final comp3 = Completer<void>();
      final sub2Next = EntityManager.addDestructionListener((batch) {
        if (batch.contains(e3) && !comp3.isCompleted) {
          comp3.complete();
        }
      });

      EntityManager.get().destroy(e3);
      await comp3.future.timeout(const Duration(seconds: 2));

      sub2.cancel();
      sub2Next.cancel();
    });

    test('gltfio integration: destroyAsset notifies destruction listener', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final provider = FilamentMaterialProvider.ubershader(engine);
      final loader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: provider,
      );

      final glbFile = File('example/assets/models/WaterBottle.glb');
      expect(glbFile.existsSync(), isTrue);
      if (glbFile.existsSync()) {
        final bytes = glbFile.readAsBytesSync();
        final asset = loader.createAsset(bytes);
        expect(asset, isNotNull);

        final assetEntities = asset!.entities.toSet();
        // WaterBottle.glb has a single node.
        expect(assetEntities, hasLength(1));

        final destroyed = <int>{};
        final completer = Completer<void>();

        final sub = EntityManager.addDestructionListener((batch) {
          destroyed.addAll(batch);
          if (destroyed.containsAll(assetEntities) && !completer.isCompleted) {
            completer.complete();
          }
        });

        // Destroy asset
        asset.dispose();

        await completer.future.timeout(const Duration(seconds: 2));
        expect(destroyed.containsAll(assetEntities), isTrue);

        sub.cancel();
      }

      loader.dispose();
      provider.dispose();
      engine.dispose();
    });

    test('Stress: 1000 entities destroyed in a loop', () async {
      final destroyedIds = <int>{};
      final completer = Completer<void>();
      const count = 1000;

      final entities = EntityManager.createEntities(count);
      final expectedSet = entities.toSet();

      final subscription = EntityManager.addDestructionListener((batch) {
        destroyedIds.addAll(batch);
        if (destroyedIds.length >= count && !completer.isCompleted) {
          completer.complete();
        }
      });

      for (int i = 0; i < count; i += 50) {
        final batch = entities.sublist(i, i + 50);
        EntityManager.destroyEntities(batch);
      }

      await completer.future.timeout(const Duration(seconds: 5));
      expect(destroyedIds.containsAll(expectedSet), isTrue);

      subscription.cancel();
    });
  });
}
