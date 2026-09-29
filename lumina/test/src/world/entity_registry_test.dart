import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaEntityRegistry Tests', () {
    test('registerEntities, lookup, and unregisterEntities cycle', () {
      final registry = LuminaEntityRegistry();
      final actor = LuminaActor();
      final comp = LuminaSceneComponent();
      actor.addComponent(comp);

      registry.registerEntities([5, 6, 7], comp);

      expect(registry.count, equals(3));
      expect(registry.componentForEntity(6), same(comp));
      expect(registry.actorForEntity(6), same(actor));
      expect(registry.componentForEntity(100), isNull);
      expect(registry.actorForEntity(100), isNull);

      registry.unregisterEntities([5, 6, 7]);
      expect(registry.count, equals(0));
      expect(registry.componentForEntity(6), isNull);
      expect(registry.actorForEntity(6), isNull);
    });
  });
}
