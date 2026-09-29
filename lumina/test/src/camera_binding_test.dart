import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

class FakeFilamentCamera implements CameraNative {
  int setProjectionCount = 0;
  int setProjectionOrthoCount = 0;
  int lookAtCount = 0;
  int setExposureCount = 0;
  int disposeCount = 0;
  bool isDisposed = false;

  double? lastFov;
  double? lastAspect;
  double? lastNear;
  double? lastFar;

  double? lastLeft;
  double? lastRight;
  double? lastBottom;
  double? lastTop;

  Vector3? lastEye;
  Vector3? lastCenter;
  Vector3? lastUp;

  double? lastAperture;
  double? lastShutterSpeed;
  double? lastSensitivity;

  @override
  void setProjection({double? fovDegrees, double? aspect, double? near, double? far}) {
    _checkDisposed();
    setProjectionCount++;
    lastFov = fovDegrees;
    lastAspect = aspect;
    lastNear = near;
    lastFar = far;
  }

  @override
  void setProjectionOrtho({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    _checkDisposed();
    setProjectionOrthoCount++;
    lastLeft = left;
    lastRight = right;
    lastBottom = bottom;
    lastTop = top;
    lastNear = near;
    lastFar = far;
  }

  @override
  void lookAt({
    required double eyeX,
    required double eyeY,
    required double eyeZ,
    required double centerX,
    required double centerY,
    required double centerZ,
    double upX = 0,
    double upY = 1,
    double upZ = 0,
  }) {
    _checkDisposed();
    lookAtCount++;
    lastEye = Vector3(eyeX, eyeY, eyeZ);
    lastCenter = Vector3(centerX, centerY, centerZ);
    lastUp = Vector3(upX, upY, upZ);
  }

  @override
  void setExposure({
    double aperture = 16.0,
    double shutterSpeed = 1.0 / 125.0,
    double sensitivity = 100.0,
  }) {
    _checkDisposed();
    setExposureCount++;
    lastAperture = aperture;
    lastShutterSpeed = shutterSpeed;
    lastSensitivity = sensitivity;
  }

  @override
  void dispose() {
    disposeCount++;
    isDisposed = true;
  }

  void _checkDisposed() {
    if (isDisposed) {
      throw StateError('FakeFilamentCamera is disposed');
    }
  }
}

void main() {
  group('CameraComponent Filament Binding Tests (Camera Task 02)', () {
    test('bindToNative then one frame sync in perspective mode calls setProjection once and lookAt with worldLocation eye', () {
      final camera = LuminaCameraComponent(
        location: Vector3(1000.0, 500.0, -200.0),
        fieldOfViewInDegrees: 60.0,
        aspectRatio: 16.0 / 9.0,
      );
      camera.isActive = true;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();

      expect(fakeNative.setProjectionCount, equals(1));
      expect(fakeNative.lastFov, closeTo(60.0, 1e-6));
      expect(fakeNative.lastAspect, closeTo(16.0 / 9.0, 1e-6));
      expect(fakeNative.lastNear, closeTo(10.0, 1e-4));
      expect(fakeNative.lastFar, closeTo(100000.0, 1e-4));

      expect(fakeNative.lookAtCount, equals(1));
      expect(fakeNative.lastEye, equals(camera.worldLocation));
    });

    test('Switch projectionMode to orthographic calls setProjectionOrtho and no setProjection', () {
      final camera = LuminaCameraComponent(aspectRatio: 2.0);
      camera.isActive = true;
      camera.projectionMode = CameraProjectionMode.orthographic;
      camera.orthographicWidth = 1000.0;
      camera.nearClipPlane = 10.0;
      camera.farClipPlane = 100000.0;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();

      expect(fakeNative.setProjectionCount, equals(0));
      expect(fakeNative.setProjectionOrthoCount, equals(1));
      expect(fakeNative.lastLeft, closeTo(-500.0, 1e-4));
      expect(fakeNative.lastRight, closeTo(500.0, 1e-4));
      expect(fakeNative.lastBottom, closeTo(-250.0, 1e-4));
      expect(fakeNative.lastTop, closeTo(250.0, 1e-4));
    });

    test('Two frames with unchanged projection fields sends setProjection once and lookAt twice (dirty-flag behavior)', () {
      final camera = LuminaCameraComponent();
      camera.isActive = true;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();
      camera.syncWithFilamentCamera();

      expect(fakeNative.setProjectionCount, equals(1));
      expect(fakeNative.lookAtCount, equals(2));
    });

    test('Camera rotated 90 deg yaw produces rotated forwardVector delta and matches upVector', () {
      final camera = LuminaCameraComponent();
      camera.isActive = true;
      camera.relativeRotation = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 90.0 * 3.141592653589793 / 180.0);

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();

      final delta = fakeNative.lastCenter! - fakeNative.lastEye!;
      expect(delta.x, closeTo(camera.forwardVector.x, 1e-6));
      expect(delta.y, closeTo(camera.forwardVector.y, 1e-6));
      expect(delta.z, closeTo(camera.forwardVector.z, 1e-6));
      expect(fakeNative.lastUp, equals(camera.upVector));
    });

    test('Active shake with location amplitude offsets lookAt eye during shake and returns to worldLocation afterwards', () {
      final initialLoc = Vector3(0.0, 100.0, 200.0);
      final camera = LuminaCameraComponent(location: initialLoc.clone());
      camera.isActive = true;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      final shake = CameraShake(
        locationAmplitude: Vector3(200.0, 0.0, 0.0),
        frequency: 5.0,
        duration: 0.5,
        decay: 1.0,
      );
      camera.startCameraShake(shake);

      camera.onTick(0.05);
      camera.syncWithFilamentCamera();

      expect(fakeNative.lastEye, isNot(equals(initialLoc)));

      // Advance past shake duration
      camera.onTick(0.5);
      camera.syncWithFilamentCamera();

      expect(fakeNative.lastEye, equals(initialLoc));
    });

    test('Changing aperture to 2.8 triggers setExposure on next sync and unchanged frame sends no second call', () {
      final camera = LuminaCameraComponent();
      camera.isActive = true;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();
      expect(fakeNative.setExposureCount, equals(1));

      // Unchanged sync
      camera.syncWithFilamentCamera();
      expect(fakeNative.setExposureCount, equals(1));

      // Modify aperture
      camera.aperture = 2.8;
      camera.syncWithFilamentCamera();
      expect(fakeNative.setExposureCount, equals(2));
      expect(fakeNative.lastAperture, closeTo(2.8, 1e-6));
    });

    test('Inactive bound camera makes zero native calls during sync; activating starts sync', () {
      final camera = LuminaCameraComponent();
      camera.isActive = false;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.syncWithFilamentCamera();
      expect(fakeNative.setProjectionCount, equals(0));
      expect(fakeNative.lookAtCount, equals(0));
      expect(fakeNative.setExposureCount, equals(0));

      camera.activate();
      camera.syncWithFilamentCamera();
      expect(fakeNative.setProjectionCount, equals(1));
      expect(fakeNative.lookAtCount, equals(1));
      expect(fakeNative.setExposureCount, equals(1));
    });

    test('unbindFromFilament called twice executes single dispose on native camera and subsequent sync throws StateError', () {
      final camera = LuminaCameraComponent();
      camera.isActive = true;

      final fakeNative = FakeFilamentCamera();
      camera.bindNative(fakeNative);

      camera.unbindFromFilament();
      expect(fakeNative.disposeCount, equals(1));

      // Second unbind is a no-op
      camera.unbindFromFilament();
      expect(fakeNative.disposeCount, equals(1));

      expect(() => camera.syncWithFilamentCamera(), throwsStateError);
    });
  });
}
