import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Transform Family Tests', () {
    late FilamentEngine engine;
    late FilamentCamera camera;
    late int entity;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      entity = engine.createEntity();
      camera = engine.createCamera(entity);
    });

    tearDown(() {
      engine.destroyCamera(camera);
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('Entity ID matches', () {
      expect(camera.entity, equals(entity));
    });

    test('Model matrix and position round trip (double precision)', () {
      final m = Matrix4.identity()..setTranslation(Vector3(1.0, 2.0, 3.0));
      camera.modelMatrix = m;

      final readBack = camera.modelMatrix;
      final pos = camera.position;

      expect(pos.x, closeTo(1.0, 1e-6));
      expect(pos.y, closeTo(2.0, 1e-6));
      expect(pos.z, closeTo(3.0, 1e-6));

      expect(readBack.entry(0, 3), closeTo(1.0, 1e-6));
      expect(readBack.entry(1, 3), closeTo(2.0, 1e-6));
      expect(readBack.entry(2, 3), closeTo(3.0, 1e-6));
    });

    test('View matrix equals inverse of model matrix', () {
      final m = Matrix4.identity()..setTranslation(Vector3(4.0, 5.0, 6.0));
      camera.modelMatrix = m;

      final viewMat = camera.viewMatrix;
      final prod = viewMat * m;

      // prod should be identity
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 4; col++) {
          final expected = (row == col) ? 1.0 : 0.0;
          expect(prod.entry(row, col), closeTo(expected, 1e-5));
        }
      }
    });

    test('Basis vectors for identity camera: forward is -Z, up is +Y, left is +X', () {
      camera.modelMatrix = Matrix4.identity();

      final fwd = camera.forwardVector;
      final up = camera.upVector;
      final left = camera.leftVector;

      expect(fwd.x, closeTo(0.0, 1e-6));
      expect(fwd.y, closeTo(0.0, 1e-6));
      expect(fwd.z, closeTo(-1.0, 1e-6));

      expect(up.x, closeTo(0.0, 1e-6));
      expect(up.y, closeTo(1.0, 1e-6));
      expect(up.z, closeTo(0.0, 1e-6));

      expect(left.x, closeTo(1.0, 1e-6));
      expect(left.y, closeTo(0.0, 1e-6));
      expect(left.z, closeTo(0.0, 1e-6));
    });

    test('lookAt up parameter verification', () {
      // Up along +X
      camera.lookAt(
        eyeX: 0, eyeY: 0, eyeZ: 5,
        centerX: 0, centerY: 0, centerZ: 0,
        upX: 1, upY: 0, upZ: 0,
      );
      final upX = camera.upVector;
      expect(upX.x, closeTo(1.0, 1e-4));
      expect(upX.y, closeTo(0.0, 1e-4));

      // Default up along +Y
      camera.lookAt(
        eyeX: 0, eyeY: 0, eyeZ: 5,
        centerX: 0, centerY: 0, centerZ: 0,
        upX: 0, upY: 1, upZ: 0,
      );
      final upY = camera.upVector;
      expect(upY.x, closeTo(0.0, 1e-4));
      expect(upY.y, closeTo(1.0, 1e-4));
    });

    test('lookAt consistency with position and forward vector', () {
      camera.lookAt(
        eyeX: 2, eyeY: 3, eyeZ: 4,
        centerX: 0, centerY: 0, centerZ: 0,
      );
      final pos = camera.position;
      expect(pos.x, closeTo(2.0, 1e-4));
      expect(pos.y, closeTo(3.0, 1e-4));
      expect(pos.z, closeTo(4.0, 1e-4));

      final fwd = camera.forwardVector;
      final expectedDir = (Vector3(0, 0, 0) - Vector3(2, 3, 4)).normalized();
      expect(fwd.x, closeTo(expectedDir.x, 1e-4));
      expect(fwd.y, closeTo(expectedDir.y, 1e-4));
      expect(fwd.z, closeTo(expectedDir.z, 1e-4));
    });

    test('Float overload setModelMatrixF', () {
      final fList = Float32List.fromList([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        7, 8, 9, 1,
      ]);
      camera.setModelMatrixF(fList);
      final pos = camera.position;
      expect(pos.x, closeTo(7.0, 1e-5));
      expect(pos.y, closeTo(8.0, 1e-5));
      expect(pos.z, closeTo(9.0, 1e-5));
    });

    test('Frustum planes extraction and containment', () {
      camera.modelMatrix = Matrix4.identity();
      camera.setProjectionFov(fovDegrees: 90, aspect: 1.0, near: 0.1, far: 100);

      final planes = camera.frustumPlanes;
      expect(planes.length, equals(6));

      // Check near plane (index 5: near in left, right, bottom, top, far, near)
      final nearPlane = planes[5];
      // Near plane normal points along +Z in view space: (0, 0, 1, 0.1)
      expect(nearPlane.x, closeTo(0.0, 1e-3));
      expect(nearPlane.y, closeTo(0.0, 1e-3));
      expect(nearPlane.z, closeTo(1.0, 1e-3));
    });
  });

  group('Camera Projection Expansion Tests', () {
    late FilamentEngine engine;
    late FilamentCamera camera;
    late int entity;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      entity = engine.createEntity();
      camera = engine.createCamera(entity);
    });

    tearDown(() {
      engine.destroyCamera(camera);
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('Fov direction vertical vs horizontal', () {
      camera.setProjectionFov(fovDegrees: 90, aspect: 2.0, near: 0.1, far: 100, direction: FovDirection.vertical);
      final projV = camera.projectionMatrix;

      camera.setProjectionFov(fovDegrees: 90, aspect: 2.0, near: 0.1, far: 100, direction: FovDirection.horizontal);
      final projH = camera.projectionMatrix;

      // In vertical, entry(1, 1) = 1/tan(45 deg) = 1.0
      expect(projV.entry(1, 1), closeTo(1.0, 1e-5));
      // In horizontal, entry(0, 0) = 1/tan(45 deg) = 1.0
      expect(projH.entry(0, 0), closeTo(1.0, 1e-5));
    });

    test('6-plane projection matches setProjectionFov for symmetric case', () {
      camera.setProjectionFov(fovDegrees: 90, aspect: 1.0, near: 0.1, far: 100);
      final fovMat = camera.projectionMatrix;

      camera.setProjectionPlanes(
        ProjectionType.perspective,
        left: -0.1,
        right: 0.1,
        bottom: -0.1,
        top: 0.1,
        near: 0.1,
        far: 100,
      );
      final planeMat = camera.projectionMatrix;

      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          expect(planeMat.entry(i, j), closeTo(fovMat.entry(i, j), 1e-5));
        }
      }
    });

    test('Lens projection focal length and 24mm sensor convention', () {
      camera.setLensProjection(focalLengthMm: 50.0, aspect: 1.5, near: 0.1, far: 100.0);
      final proj = camera.projectionMatrix;

      // In Filament, sensor height is 24mm -> m[1][1] = (2 * 50) / 24 = 100 / 24 ≈ 4.166667
      expect(proj.entry(1, 1), closeTo(100.0 / 24.0, 1e-4));
    });

    test('Custom projection and culling matrices', () {
      final custom = Matrix4.diagonal3Values(1.0, 2.0, 3.0);
      final cull = Matrix4.diagonal3Values(4.0, 5.0, 6.0);

      camera.setCustomProjection(custom, culling: cull, near: 0.2, far: 50.0);

      final projRead = camera.projectionMatrix;
      final cullRead = camera.cullingProjectionMatrix;

      expect(projRead.entry(0, 0), closeTo(1.0, 1e-5));
      expect(cullRead.entry(0, 0), closeTo(4.0, 1e-5));
      expect(camera.near, closeTo(0.2, 1e-5));
      expect(camera.cullingFar, closeTo(50.0, 1e-5));
    });

    test('Scaling and Shift get/set', () {
      camera.scaling = const (0.5, 2.0);
      final s = camera.scaling;
      expect(s.x, closeTo(0.5, 1e-5));
      expect(s.y, closeTo(2.0, 1e-5));

      camera.shift = const (0.1, -0.2);
      final sh = camera.shift;
      expect(sh.x, closeTo(0.1, 1e-5));
      expect(sh.y, closeTo(-0.2, 1e-5));
    });

    test('Static Camera.projection and Camera.inverseProjection', () {
      final p = FilamentCamera.projection(
        direction: FovDirection.vertical,
        fovDegrees: 60.0,
        aspect: 1.0,
        near: 0.1,
        far: 100.0,
      );
      final invP = FilamentCamera.inverseProjection(p);
      final prod = p * invP;

      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          final expected = (i == j) ? 1.0 : 0.0;
          expect(prod.entry(i, j), closeTo(expected, 1e-5));
        }
      }
    });
  });

  group('Camera Exposure & Focus Tests', () {
    late FilamentEngine engine;
    late FilamentCamera camera;
    late int entity;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      entity = engine.createEntity();
      camera = engine.createCamera(entity);
    });

    tearDown(() {
      engine.destroyCamera(camera);
      engine.destroyEntity(entity);
      engine.dispose();
    });

    test('Physical exposure 3-arg round trip', () {
      camera.setExposure(aperture: 2.8, shutterSpeed: 1.0 / 60.0, sensitivity: 400.0);

      expect(camera.aperture, closeTo(2.8, 1e-4));
      expect(camera.shutterSpeed, closeTo(1.0 / 60.0, 1e-4));
      expect(camera.sensitivity, closeTo(400.0, 1e-4));
    });

    // setExposureEv100 passed the EV as Filament's exposure *factor*.
    test('setExposureEv100(ev) exposes at EV100 = ev: log2(N²/t · 100/S) == ev', () {
      for (final ev in [-10.0, -2.0, 0.0, 6.0, 10.0, 15.0, 20.0]) {
        camera.setExposureEv100(ev);
        final n = camera.aperture, t = camera.shutterSpeed, s = camera.sensitivity;
        final measured = math.log(n * n / t * 100.0 / s) / math.ln2;
        expect(measured, closeTo(ev, 1e-3), reason: 'ev $ev → N $n, t $t, S $s');
      }
    });

    test('Default exposure (sunny-16)', () {
      expect(camera.aperture, closeTo(16.0, 1e-4));
      expect(camera.shutterSpeed, closeTo(1.0 / 125.0, 1e-4));
      expect(camera.sensitivity, closeTo(100.0, 1e-4));
    });

    test('focalLength getter in meters after setLensProjection', () {
      camera.setLensProjection(focalLengthMm: 35.0, aspect: 1.0, near: 0.1, far: 100.0);
      expect(camera.focalLength, closeTo(0.035, 1e-4));
    });

    test('Field of view getters in degrees', () {
      camera.setProjectionFov(fovDegrees: 60.0, aspect: 2.0, near: 0.1, far: 100.0, direction: FovDirection.vertical);
      expect(camera.getFieldOfViewInDegrees(FovDirection.vertical), closeTo(60.0, 1e-3));
      expect(camera.getFieldOfViewInDegrees(FovDirection.horizontal), greaterThan(60.0));
    });

    test('focusDistance get/set and DoF headless render smoke', () {
      camera.focusDistance = 3.5;
      expect(camera.focusDistance, closeTo(3.5, 1e-4));

      final view = engine.createView();
      view.camera = camera;
      view.scene = engine.createScene();
      view.depthOfFieldOptions = const DepthOfFieldOptions(
        cocScale: 1.0,
        cocAspectRatio: 1.0,
        maxForegroundCOC: 16,
        maxBackgroundCOC: 16,
      );

      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(100, 100);

      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }

      engine.destroyView(view);
    });
  });
}
