import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('FilamentEntity API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('FilamentEntity creation, equality, and hashcode', () {
      final rawId = engine.createEntity();
      final entity1 = FilamentEntity(rawId, engine);
      final entity2 = FilamentEntity(rawId, engine);

      expect(entity1.id, equals(rawId));
      expect(entity1, equals(entity2));
      expect(entity1.hashCode, equals(entity2.hashCode));
      expect(entity1.toString(), equals('FilamentEntity($rawId)'));

      entity1.destroy();
    });
  });
}
