import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('ManipulatorBuilder API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('ManipulatorBuilder orbit mode with targetPosition', () {
      final builder = ManipulatorBuilder()
          .viewport(800, 600)
          .targetPosition(1.0, 2.0, 3.0);
      
      final manipulator = builder.build(ManipulatorMode.orbit);
      final lookAt = manipulator.getLookAt();
      
      expect(lookAt.center, closeToVector3List(Vector3(1.0, 2.0, 3.0), 1e-4));
      
      manipulator.dispose();
    });

    test('ManipulatorBuilder orbit mode with orbitHomePosition', () {
      final manipulator = ManipulatorBuilder()
          .viewport(800, 600)
          .orbitHomePosition(0.0, 0.0, 10.0)
          .build(ManipulatorMode.orbit);
      
      final lookAt = manipulator.getLookAt();
      // Orbit default center is 0,0,0, so eye is at 0,0,10
      expect(lookAt.eye, closeToVector3List(Vector3(0.0, 0.0, 10.0), 1e-4));
      
      manipulator.dispose();
    });

    test('ManipulatorBuilder freeFlight mode with flightStartPosition', () {
      final manipulator = ManipulatorBuilder()
          .viewport(800, 600)
          .flightStartPosition(5.0, 5.0, 5.0)
          .build(ManipulatorMode.freeFlight);
      
      final lookAt = manipulator.getLookAt();
      expect(lookAt.eye, closeToVector3List(Vector3(5.0, 5.0, 5.0), 1e-4));
      
      manipulator.dispose();
    });

    test('ManipulatorBuilder map mode', () {
      final manipulator = ManipulatorBuilder()
          .viewport(800, 600)
          .mapExtent(10.0, 10.0)
          .mapMinDistance(1.0)
          .build(ManipulatorMode.map);
      
      expect(manipulator.isDisposed, isFalse);
      manipulator.dispose();
    });

    test('ManipulatorBuilder multiple properties', () {
      final manipulator = ManipulatorBuilder()
          .viewport(800, 600)
          .upVector(0.0, 1.0, 0.0)
          .zoomSpeed(2.0)
          .fovDirection(FovDirection.vertical)
          .fovDegrees(45.0)
          .farPlane(1000.0)
          .flightMaxMoveSpeed(10.0)
          .flightSpeedSteps(5)
          .flightPanSpeed(1.0, 1.0)
          .flightMoveDamping(15.0)
          .groundPlane(0.0, 1.0, 0.0, 0.0)
          .panning(true)
          .build(ManipulatorMode.orbit);
      
      expect(manipulator.isDisposed, isFalse);
      manipulator.dispose();
    });

    test('ManipulatorBuilder reuse', () {
      final builder = ManipulatorBuilder().viewport(800, 600);
      
      final manipulator1 = builder.build(ManipulatorMode.orbit);
      final manipulator2 = builder.build(ManipulatorMode.freeFlight);
      
      expect(manipulator1.isDisposed, isFalse);
      expect(manipulator2.isDisposed, isFalse);
      
      manipulator1.dispose();
      manipulator2.dispose();
    });

    test('ManipulatorBuilder raycastCallback', () {
      bool callbackFired = false;
      
      final manipulator = ManipulatorBuilder()
          .viewport(800, 600)
          .raycastCallback((origin, dir) {
            callbackFired = true;
            // Returning 10.0 means the hit is at origin + dir * 10
            return 10.0;
          })
          .build(ManipulatorMode.orbit);
      
      // Depending on Filament internals, raycastCallback is fired
      // during operations like raycast() or grabBegin() + raycast, etc.
      // We test that setting the callback does not crash and we can trigger raycast.
      manipulator.raycast(400, 300);
      
      expect(callbackFired, isTrue);
      manipulator.dispose();
    });
  });
}



Matcher closeToVector3List(Vector3 expected, double delta) {
  return predicate<List<double>>((List<double> actual) {
    return (actual[0] - expected.x).abs() <= delta &&
           (actual[1] - expected.y).abs() <= delta &&
           (actual[2] - expected.z).abs() <= delta;
  }, 'matches $expected within delta $delta');
}
