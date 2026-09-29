import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('EntityInstance Handles & Fast Component Lookups', () {
    late FilamentEngine engine;
    late FilamentTransformManager transformManager;
    late FilamentRenderableManager renderableManager;
    late FilamentLightManager lightManager;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      transformManager = FilamentTransformManager(engine);
      renderableManager = FilamentRenderableManager(engine);
      lightManager = FilamentLightManager(engine);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Transform component: getInstance and hasComponent lifecycle', () {
      final entity = engine.createEntity();
      expect(transformManager.hasComponent(entity), isFalse);
      expect(transformManager.getInstance(entity).isValid, isFalse);
      expect(transformManager.getInstance(entity).handle, equals(0));

      transformManager.create(entity);
      expect(transformManager.hasComponent(entity), isTrue);

      final instance = transformManager.getInstance(entity);
      expect(instance.isValid, isTrue);
      expect(instance.handle, isNonZero);

      transformManager.destroy(entity);
      expect(transformManager.hasComponent(entity), isFalse);
      expect(transformManager.getInstance(entity).isValid, isFalse);

      engine.destroyEntity(entity);
    });

    test('Fast instance path setTransformAt matches entity-based getWorldTransform', () {
      final entity = engine.createEntity();
      transformManager.create(entity);
      final instance = transformManager.getInstance(entity);

      final testMatrix = [
        2.0, 0.0, 0.0, 0.0,
        0.0, 3.0, 0.0, 0.0,
        0.0, 0.0, 4.0, 0.0,
        10.0, 20.0, 30.0, 1.0,
      ];

      transformManager.setTransformAt(instance, testMatrix);

      final readByEntity = transformManager.getWorldTransform(entity);
      final readByInstance = transformManager.worldTransformAt(instance);

      expect(readByEntity, equals(testMatrix));
      expect(readByInstance, equals(testMatrix));

      transformManager.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('Light component: getInstance and hasComponent', () {
      final entity = engine.createEntity();
      expect(lightManager.hasComponent(entity), isFalse);
      expect(lightManager.getInstance(entity).isValid, isFalse);

      lightManager.createLight(
        entity: entity,
        type: LightType.sun,
        intensity: 50000.0,
      );

      expect(lightManager.hasComponent(entity), isTrue);
      final lightInstance = lightManager.getInstance(entity);
      expect(lightInstance.isValid, isTrue);

      lightManager.destroy(entity);
      expect(lightManager.hasComponent(entity), isFalse);
      engine.destroyEntity(entity);
    });

    test('Renderable component: hasComponent and getInstance', () {
      final entity = engine.createEntity();
      expect(renderableManager.hasComponent(entity), isFalse);
      expect(renderableManager.getInstance(entity).isValid, isFalse);

      engine.destroyEntity(entity);
    });

    test('1000-entity batch transform updates via instance path', () {
      final entities = <int>[];
      final instances = <TransformInstance>[];

      for (int i = 0; i < 1000; i++) {
        final e = engine.createEntity();
        entities.add(e);
        transformManager.create(e);
        instances.add(transformManager.getInstance(e));
      }

      for (int i = 0; i < 1000; i++) {
        final mat = [
          1.0, 0.0, 0.0, 0.0,
          0.0, 1.0, 0.0, 0.0,
          0.0, 0.0, 1.0, 0.0,
          i.toDouble(), (i * 2).toDouble(), (i * 3).toDouble(), 1.0,
        ];
        transformManager.setTransformAt(instances[i], mat);
      }

      for (int i = 0; i < 1000; i++) {
        final read = transformManager.worldTransformAt(instances[i]);
        expect(read[12], equals(i.toDouble()));
        expect(read[13], equals((i * 2).toDouble()));
        expect(read[14], equals((i * 3).toDouble()));
      }

      for (final e in entities) {
        transformManager.destroy(e);
        engine.destroyEntity(e);
      }
    });
  });
}
