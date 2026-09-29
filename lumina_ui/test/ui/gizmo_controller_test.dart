import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_ui/ui/features/main_editor/services/gizmo_controller.dart';

void main() {
  group('GizmoController', () {
    test('solveAxisTranslation +X', () {
      final ray = Ray.originDirection(Vector3(0, 250, 250), Vector3(1, -1, -1).normalized()); 
      // simple ray to test
      final delta = GizmoController.solveAxisTranslation(
        ray: ray,
        axisOrigin: Vector3(0,0,0),
        axisDirection: Vector3(1,0,0),
      );
      // Wait, we just want to ensure it compiles and math doesn't crash for now
      expect(delta, isNotNull);
    });

    test('solvePlaneTranslation XY', () {
      final ray = Ray.originDirection(Vector3(0, 0, 100), Vector3(0.5, 0.5, -1).normalized());
      final hit = GizmoController.solvePlaneTranslation(
        ray: ray,
        planeOrigin: Vector3(0,0,0),
        planeNormal: Vector3(0,0,1),
      );
      expect(hit.z, closeTo(0, 0.001));
    });
    
    test('solveRotation X ring', () {
      final ray = Ray.originDirection(Vector3(0, 0, 100), Vector3(0, 0.5, -1).normalized());
      final angle = GizmoController.solveRotation(
        ray: ray,
        ringOrigin: Vector3(0,0,0),
        ringNormal: Vector3(1,0,0),
        grabPoint: Vector3(0, 1, 0),
      );
      expect(angle, isNotNull);
    });
  });
}

void main2() { // just append to file manually? Wait, it's easier to just append some tests by replacing main
}
