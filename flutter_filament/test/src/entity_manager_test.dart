import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('EntityManager tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.dispose();
    });

    test('Freshly created entity has isAlive == true, then false after destroy', () {
      final entity = engine.createEntity();
      expect(entity, isNot(equals(0)));
      expect(EntityManager.isAlive(entity), isTrue);

      engine.destroyEntity(entity);
      expect(EntityManager.isAlive(entity), isFalse);
    });

    test('Entity.none (0) reports isAlive == false and destroying it is safe', () {
      const none = 0; // Entity.none
      expect(EntityManager.isAlive(none), isFalse);
      
      // Should not crash
      engine.destroyEntity(none);
      EntityManager.destroyEntities([none]);
    });

    test('Bulk create/destroy 1000 entities and entityCount', () {
      final initialCount = EntityManager.entityCount;

      final entities = EntityManager.createEntities(1000);
      expect(entities.length, equals(1000));
      expect(EntityManager.entityCount, equals(initialCount + 1000));

      final uniqueIds = <int>{};
      for (final e in entities) {
        expect(e, isNot(equals(0)));
        expect(EntityManager.isAlive(e), isTrue);
        uniqueIds.add(e);
      }
      expect(uniqueIds.length, equals(1000)); // All distinct

      EntityManager.destroyEntities(entities);
      expect(EntityManager.entityCount, equals(initialCount));

      for (final e in entities) {
        expect(EntityManager.isAlive(e), isFalse);
      }
    });

    test('Recycling check: old handle reports isAlive == false', () {
      final entity = engine.createEntity();
      expect(EntityManager.isAlive(entity), isTrue);

      engine.destroyEntity(entity);
      expect(EntityManager.isAlive(entity), isFalse);

      // Force a bunch of creates to potentially recycle
      final newEntities = EntityManager.createEntities(1000);
      
      // The OLD handle must STILL report isAlive == false due to generation counter
      expect(EntityManager.isAlive(entity), isFalse);

      EntityManager.destroyEntities(newEntities);
    });

    test('Singular and bulk paths interoperate', () {
      // Create bulk, destroy singular
      final entities = EntityManager.createEntities(2);
      expect(EntityManager.isAlive(entities[0]), isTrue);
      expect(EntityManager.isAlive(entities[1]), isTrue);

      engine.destroyEntity(entities[0]);
      engine.destroyEntity(entities[1]);
      
      expect(EntityManager.isAlive(entities[0]), isFalse);
      expect(EntityManager.isAlive(entities[1]), isFalse);

      // Create singular, destroy bulk
      final e1 = engine.createEntity();
      final e2 = engine.createEntity();
      expect(EntityManager.isAlive(e1), isTrue);
      expect(EntityManager.isAlive(e2), isTrue);

      EntityManager.destroyEntities([e1, e2]);
      
      expect(EntityManager.isAlive(e1), isFalse);
      expect(EntityManager.isAlive(e2), isFalse);
    });

    test('Micro-benchmark: Bulk vs Singular FFI costs', () {
      final sw1 = Stopwatch()..start();
      final entities1 = <int>[];
      for (var i = 0; i < 10000; i++) {
        entities1.add(engine.createEntity());
      }
      sw1.stop();

      final sw2 = Stopwatch()..start();
      final entities2 = EntityManager.createEntities(10000);
      sw2.stop();

      printOnFailure('10k Singular Creates: ${sw1.elapsedMilliseconds} ms');
      printOnFailure('10k Bulk Creates: ${sw2.elapsedMilliseconds} ms');

      final sw3 = Stopwatch()..start();
      for (final e in entities1) {
        engine.destroyEntity(e);
      }
      sw3.stop();

      final sw4 = Stopwatch()..start();
      EntityManager.destroyEntities(entities2);
      sw4.stop();

      printOnFailure('10k Singular Destroys: ${sw3.elapsedMilliseconds} ms');
      printOnFailure('10k Bulk Destroys: ${sw4.elapsedMilliseconds} ms');
    });
  });
}
