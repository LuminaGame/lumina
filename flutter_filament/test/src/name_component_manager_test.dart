import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NameComponentManager Tests', () {
    test('Create entity, addComponent, setName, and getName', () {
      final ncm = NameComponentManager();
      final entity = EntityManager.get().create();

      expect(ncm.hasComponent(entity), isFalse);
      expect(ncm.getName(entity), isNull);

      ncm.addComponent(entity);
      expect(ncm.hasComponent(entity), isTrue);

      ncm.setName(entity, 'player');
      expect(ncm.getName(entity), equals('player'));

      EntityManager.get().destroy(entity);
      ncm.destroy();
    });

    test('Rename entity updates the name', () {
      final ncm = NameComponentManager();
      final entity = EntityManager.get().create();

      ncm.addComponent(entity);
      ncm.setName(entity, 'player');
      expect(ncm.getName(entity), equals('player'));

      ncm.setName(entity, 'boss');
      expect(ncm.getName(entity), equals('boss'));

      EntityManager.get().destroy(entity);
      ncm.destroy();
    });

    test('getName on entity without component returns null and hasComponent is false', () {
      final ncm = NameComponentManager();
      final entity = EntityManager.get().create();

      expect(ncm.hasComponent(entity), isFalse);
      expect(ncm.getName(entity), isNull);

      EntityManager.get().destroy(entity);
      ncm.destroy();
    });

    test('removeComponent drops component and adding again works', () {
      final ncm = NameComponentManager();
      final entity = EntityManager.get().create();

      ncm.addComponent(entity);
      ncm.setName(entity, 'temp_node');
      expect(ncm.getName(entity), equals('temp_node'));

      ncm.removeComponent(entity);
      expect(ncm.hasComponent(entity), isFalse);
      expect(ncm.getName(entity), isNull);

      ncm.addComponent(entity);
      ncm.setName(entity, 'readded_node');
      expect(ncm.getName(entity), equals('readded_node'));

      EntityManager.get().destroy(entity);
      ncm.destroy();
    });

    test('gc drops dead entities after EntityManager destruction', () {
      final ncm = NameComponentManager();
      final entities = EntityManager.createEntities(10);

      for (int i = 0; i < entities.length; i++) {
        ncm.addComponent(entities[i]);
        ncm.setName(entities[i], 'entity_$i');
        expect(ncm.getName(entities[i]), equals('entity_$i'));
      }

      // Destroy entities in EntityManager
      EntityManager.destroyEntities(entities);

      // Run GC
      ncm.gc();

      for (final e in entities) {
        expect(ncm.hasComponent(e), isFalse);
        expect(ncm.getName(e), isNull);
      }

      ncm.destroy();
    });

    test('UTF-8 characters round-trip correctly', () {
      final ncm = NameComponentManager();
      final entity = EntityManager.get().create();

      ncm.addComponent(entity);
      const testName = 'kale_kapısı_🏰_öçşğü_日本語';
      ncm.setName(entity, testName);
      expect(ncm.getName(entity), equals(testName));

      EntityManager.get().destroy(entity);
      ncm.destroy();
    });

    test('gltfio integration: GltfLoader with names shares NameComponentManager', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final ncm = NameComponentManager();
      final provider = FilamentMaterialProvider.ubershader(engine);
      final loader = GltfLoader(
        engine: engine,
        materialProvider: provider,
        names: ncm,
      );

      final glbFile = File('example/assets/models/WaterBottle.glb');
      expect(glbFile.existsSync(), isTrue);
      if (glbFile.existsSync()) {
        final bytes = glbFile.readAsBytesSync();
        final asset = loader.loadGltf(bytes);
        expect(asset, isNotNull);

        final entities = asset!.entities;
        expect(entities.isNotEmpty, isTrue);

        // The model's only node is named "WaterBottle".
        final names = [for (final e in entities) ncm.getName(e)];
        expect(names, contains('WaterBottle'));
        asset.dispose();
      }

      loader.dispose();
      provider.dispose();
      ncm.destroy();
      engine.dispose();
    });
  });
}
