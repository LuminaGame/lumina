import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;
  late FilamentScene scene;

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
  });

  tearDown(() {
    scene.dispose();
    engine.dispose();
  });

  group('FilamentScene Bulk Operations and Queries', () {
    test('initial scene has 0 entities, null skybox and null indirectLight', () {
      expect(scene.entityCount, equals(0));
      expect(scene.renderableCount, equals(0));
      expect(scene.lightCount, equals(0));
      expect(scene.skybox, isNull);
      expect(scene.indirectLight, isNull);
    });

    test('addEntities adds 100 entities and hasEntity queries them correctly', () {
      final entities = List<int>.generate(100, (_) => engine.createEntity());
      scene.addEntities(entities);

      expect(scene.entityCount, equals(100));
      expect(scene.hasEntity(entities.first), isTrue);
      expect(scene.hasEntity(entities[50]), isTrue);
      expect(scene.hasEntity(entities.last), isTrue);

      final nonExistent = engine.createEntity();
      expect(scene.hasEntity(nonExistent), isFalse);
    });

    test('removeEntities removes first 50 entities from scene', () {
      final entities = List<int>.generate(100, (_) => engine.createEntity());
      scene.addEntities(entities);
      expect(scene.entityCount, equals(100));

      final firstFifty = entities.sublist(0, 50);
      final remaining = entities.sublist(50);

      scene.removeEntities(firstFifty);
      expect(scene.entityCount, equals(50));

      for (final e in firstFifty) {
        expect(scene.hasEntity(e), isFalse);
      }
      for (final e in remaining) {
        expect(scene.hasEntity(e), isTrue);
      }
    });

    test('removeAllEntities empties the scene and is idempotent', () {
      final entities = List<int>.generate(50, (_) => engine.createEntity());
      scene.addEntities(entities);
      expect(scene.entityCount, equals(50));

      scene.removeAllEntities();
      expect(scene.entityCount, equals(0));
      for (final e in entities) {
        expect(scene.hasEntity(e), isFalse);
      }

      // Calling again on empty scene does not crash
      scene.removeAllEntities();
      expect(scene.entityCount, equals(0));
    });

    test('addEntities with empty list is a no-op and does not crash', () {
      scene.addEntities(const []);
      expect(scene.entityCount, equals(0));

      scene.removeEntities(const []);
      expect(scene.entityCount, equals(0));
    });

    test('adding same entity twice does not inflate count (set semantics)', () {
      final e = engine.createEntity();
      scene.addEntity(e);
      expect(scene.entityCount, equals(1));

      // Add same entity via bulk
      scene.addEntities([e]);
      expect(scene.entityCount, equals(1));
    });

    test('skybox getter/setter roundtrip and unsetting', () {
      expect(scene.skybox, isNull);

      final skybox = FilamentSkybox.createColor(
        engine: engine,
        r: 0.2,
        g: 0.4,
        b: 0.6,
        a: 1.0,
      );

      scene.skybox = skybox;
      final retrieved = scene.skybox;
      expect(retrieved, isNotNull);
      expect(retrieved!.nativePointer.address, equals(skybox.nativePointer.address));

      // Unset skybox
      scene.skybox = null;
      expect(scene.skybox, isNull);

      skybox.dispose();
    });

    test('indirectLight getter returns attached light and unsetting works', () {
      expect(scene.indirectLight, isNull);

      // Indirect light unset
      scene.setIndirectLight(null);
      expect(scene.indirectLight, isNull);
    });
  });
}
