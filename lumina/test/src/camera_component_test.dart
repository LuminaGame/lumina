import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('CameraComponent Core Tests (Camera Task 01)', () {
    test('Perspective 90 deg FOV, aspect 1.0, near 1.0, far 100.0 projection matrix elements', () {
      final camera = LuminaCameraComponent(
        fieldOfViewInDegrees: 90.0,
        aspectRatio: 1.0,
      );
      camera.nearClipPlane = 1.0;
      camera.farClipPlane = 100.0;
      camera.projectionMode = CameraProjectionMode.perspective;

      final proj = camera.getProjectionMatrix();
      // In column-major matrix:
      // entry(0, 0) is cot(fov/2)/aspect = cot(45) = 1.0
      // entry(1, 1) is cot(fov/2) = 1.0
      // entry(3, 2) is -1.0
      expect(proj.entry(0, 0), closeTo(1.0, 1e-6));
      expect(proj.entry(1, 1), closeTo(1.0, 1e-6));
      expect(proj.entry(3, 2), closeTo(-1.0, 1e-6));
    });

    test('Orthographic projection with orthographicWidth 10 and aspect 2.0 maps x=5.0 to NDC x=1.0', () {
      final camera = LuminaCameraComponent(
        aspectRatio: 2.0,
      );
      camera.projectionMode = CameraProjectionMode.orthographic;
      camera.orthographicWidth = 10.0;
      camera.nearClipPlane = 0.1;
      camera.farClipPlane = 100.0;

      final proj = camera.getProjectionMatrix();
      final point = Vector4(5.0, 0.0, -10.0, 1.0);
      final ndc = proj * point;

      expect(ndc.x / ndc.w, closeTo(1.0, 1e-6));
    });

    test('Camera at (0, 0, 5) identity rotation transforms world origin to (0, 0, -5) in view space', () {
      final camera = LuminaCameraComponent(
        location: Vector3(0.0, 0.0, 5.0),
      );

      final view = camera.getViewMatrix();
      final worldOrigin = Vector4(0.0, 0.0, 0.0, 1.0);
      final viewSpacePoint = view * worldOrigin;

      expect(viewSpacePoint.x, closeTo(0.0, 1e-6));
      expect(viewSpacePoint.y, closeTo(0.0, 1e-6));
      expect(viewSpacePoint.z, closeTo(-5.0, 1e-6));
    });

    test('getViewMatrix(out: m) writes into caller matrix without allocating new object', () {
      final camera = LuminaCameraComponent(
        location: Vector3(1.0, 2.0, 3.0),
      );

      final outMatrix = Matrix4.zero();
      final result = camera.getViewMatrix(out: outMatrix);

      expect(identical(result, outMatrix), isTrue);

      final secondMatrix = Matrix4.zero();
      camera.getViewMatrix(out: secondMatrix);
      expect(outMatrix, equals(secondMatrix));
    });

    test('activate() deactivates previous camera on same actor and activates target', () {
      final actor = LuminaActor();
      final camA = LuminaCameraComponent();
      final camB = LuminaCameraComponent();

      actor.addComponent(camA);
      actor.addComponent(camB);

      camA.activate();
      expect(camA.isActive, isTrue);
      expect(camB.isActive, isFalse);

      camB.activate();
      expect(camA.isActive, isFalse);
      expect(camB.isActive, isTrue);
    });

    test('setFieldOfView with interpSpeed interpolates FOV correctly across deltaTime', () {
      final camera = LuminaCameraComponent(fieldOfViewInDegrees: 60.0);

      // Snap
      camera.setFieldOfView(90.0, interpSpeed: 0.0);
      expect(camera.fieldOfViewInDegrees, equals(90.0));

      // Smooth interp
      camera.fieldOfViewInDegrees = 60.0;
      camera.setFieldOfView(30.0, interpSpeed: 10.0);

      // dt = 0.05 -> step = (30 - 60) * clamp(0.05 * 10, 0, 1) = -30 * 0.5 = -15 -> 45.0
      camera.onTick(0.05);
      expect(camera.fieldOfViewInDegrees, closeTo(45.0, 1e-6));

      // dt = 0.1 -> step = (30 - 45) * clamp(0.1 * 10, 0, 1) = -15 * 1.0 = -15 -> 30.0
      camera.onTick(0.1);
      expect(camera.fieldOfViewInDegrees, closeTo(30.0, 1e-6));
    });

    test('Camera shake produces offset during duration and auto-removes at completion without mutating relativeLocation', () {
      final initialLoc = Vector3(10.0, 0.0, 0.0);
      final camera = LuminaCameraComponent(location: initialLoc.clone());

      final shake = CameraShake(
        locationAmplitude: Vector3(1.0, 1.0, 0.0),
        duration: 0.5,
        decay: 1.0,
      );

      camera.startCameraShake(shake);
      camera.onTick(0.25);

      expect(camera.relativeLocation, equals(initialLoc)); // Relative transform untouched

      // Advance past duration
      camera.onTick(0.3);
      expect(camera.relativeLocation, equals(initialLoc));
    });

    test('Frustum extraction and sphere culling at near, far, and in-view positions', () {
      final camera = LuminaCameraComponent(
        fieldOfViewInDegrees: 90.0,
        aspectRatio: 1.0,
      );
      camera.nearClipPlane = 1.0;
      camera.farClipPlane = 100.0;

      final frustum = camera.getFrustumPlanes();

      // Sphere inside view
      expect(frustum.intersectsSphere(Vector3(0.0, 0.0, -10.0), 1.0), isTrue);

      // Sphere behind camera (positive Z)
      expect(frustum.intersectsSphere(Vector3(0.0, 0.0, 10.0), 1.0), isFalse);

      // Sphere past far plane
      expect(frustum.intersectsSphere(Vector3(0.0, 0.0, -200.0), 1.0), isFalse);
    });

    test('deprojectScreenToWorld at viewport center produces forwardVector ray direction and worldLocation origin', () {
      final camera = LuminaCameraComponent(
        location: Vector3(5.0, 2.0, 10.0),
      );
      final viewportSize = Vector2(1920.0, 1080.0);
      final center = Vector2(960.0, 540.0);

      final ray = camera.deprojectScreenToWorld(center, viewportSize);

      expect(ray.origin, equals(camera.worldLocation));
      expect(ray.direction.dot(camera.forwardVector), greaterThan(0.9999));
    });

    test('projectWorldToScreen of straight-ahead point returns center pixel; behind returns null', () {
      final camera = LuminaCameraComponent(
        location: Vector3.zero(),
        fieldOfViewInDegrees: 60.0,
        aspectRatio: 16.0 / 9.0,
      );
      camera.nearClipPlane = 0.1;
      camera.farClipPlane = 1000.0;

      final viewportSize = Vector2(1920.0, 1080.0);
      final straightAhead = Vector3(0.0, 0.0, -10.0);

      final screenCoord = camera.projectWorldToScreen(straightAhead, viewportSize);
      expect(screenCoord, isNotNull);
      expect(screenCoord!.x, closeTo(960.0, 0.5));
      expect(screenCoord.y, closeTo(540.0, 0.5));

      final behindPoint = Vector3(0.0, 0.0, 10.0);
      expect(camera.projectWorldToScreen(behindPoint, viewportSize), isNull);
    });
  });
}
