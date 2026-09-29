import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Camera Manipulator API Tests', () {
    late FilamentEngine engine;
    late int entity;
    late FilamentCamera camera;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      entity = engine.createEntity();
      camera = engine.createCamera(entity);
    });

    tearDown(() {
      if (!camera.isDisposed) camera.dispose();
      engine.destroyEntity(entity);
      if (!engine.isDisposed) engine.dispose();
    });

    test('ManipulatorMode enum indices', () {
      expect(ManipulatorMode.orbit.index, equals(0));
      expect(ManipulatorMode.map.index, equals(1));
      expect(ManipulatorMode.freeFlight.index, equals(2));
    });

    test('FilamentCameraManipulator full lifecycle and gesture update', () {
      final manipulator = FilamentCameraManipulator.create(
        mode: ManipulatorMode.orbit,
        viewportWidth: 1280,
        viewportHeight: 720,
      );

      expect(manipulator.isDisposed, isFalse);
      expect(manipulator.nativePointer, isNotNull);

      expect(() => manipulator.setViewport(1920, 1080), returnsNormally);
      expect(() => manipulator.grabBegin(100, 100, strafe: false), returnsNormally);
      expect(() => manipulator.grabUpdate(120, 150), returnsNormally);
      expect(() => manipulator.grabEnd(), returnsNormally);
      expect(() => manipulator.scroll(500, 500, -10.0), returnsNormally);

      final lookAt = manipulator.getLookAt();
      expect(lookAt.eye.length, equals(3));
      expect(lookAt.center.length, equals(3));
      expect(lookAt.up.length, equals(3));

      expect(() => manipulator.updateCamera(camera), returnsNormally);

      manipulator.dispose();
      expect(manipulator.isDisposed, isTrue);
      expect(() => manipulator.nativePointer, throwsStateError);
      expect(() => manipulator.setViewport(800, 600), throwsStateError);
      expect(() => manipulator.grabBegin(0, 0), throwsStateError);
      expect(() => manipulator.grabUpdate(0, 0), throwsStateError);
      expect(() => manipulator.grabEnd(), throwsStateError);
      expect(() => manipulator.scroll(0, 0, 1), throwsStateError);
      expect(() => manipulator.getLookAt(), throwsStateError);
    });
  });
}
