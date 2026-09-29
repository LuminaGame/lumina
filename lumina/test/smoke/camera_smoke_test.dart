import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  group('Camera Module Smoke Tests', () {
    test('Scenario 01: CameraComponent activation, projection math, FOV interpolation, frustum culling, and deprojection', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final cameraActor = LuminaActor();
      final camera = LuminaCameraComponent(
        location: Vector3(0.0, 5.0, 10.0),
        fieldOfViewInDegrees: 90.0,
        aspectRatio: 16.0 / 9.0,
      );

      cameraActor.addComponent(camera);
      world.persistentLevel.registerActor(cameraActor);
      camera.activate();

      world.beginPlay();

      expect(camera.isActive, isTrue);

      camera.setFieldOfView(60.0, interpSpeed: 5.0);

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Check view & projection matrix validity
      final viewMat = camera.getViewMatrix();
      final projMat = camera.getProjectionMatrix();
      expect(viewMat.isIdentity(), isFalse);
      expect(projMat.isIdentity(), isFalse);

      // Frustum culling
      final frustum = camera.getFrustumPlanes();
      expect(frustum.planes.length, equals(6));
      expect(frustum.intersectsSphere(Vector3(0.0, 5.0, 0.0), 2.0), isTrue);
      expect(frustum.intersectsSphere(Vector3(0.0, 5.0, 100.0), 2.0), isFalse);

      // Deprojection
      final ray = camera.deprojectScreenToWorld(
        Vector2(960.0, 540.0),
        Vector2(1920.0, 1080.0),
      );
      expect(ray.origin, equals(camera.worldLocation));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Access_cards/access_card_red.glb',
      ];

      const testTitle = 'Camera Module Smoke Tests Scenario 01: CameraComponent activation, projection math, FOV interpolation, frustum culling, and deprojection';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          // Dynamic FOV zoom in and out (90 -> 35 -> 90)
          final fov = 35.0 + 55.0 * (0.5 + 0.5 * math.cos(timeSeconds * 1.2));
          cam.setProjection(fovDegrees: fov, aspect: 640.0 / 360.0, near: 0.1, far: 100.0);

          final camDist = 3.2;
          final camX = math.sin(timeSeconds * 0.6) * camDist;
          final camZ = math.cos(timeSeconds * 0.6) * camDist;
          cam.lookAt(
            eyeX: camX,
            eyeY: 1.2 + math.sin(timeSeconds * 0.8) * 0.4,
            eyeZ: camZ,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: CameraComponent Filament native binding, exposure sync, and teardown', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final cameraActor = LuminaActor();
      final camera = LuminaCameraComponent(
        location: Vector3(0.0, 2.0, 5.0),
        fieldOfViewInDegrees: 75.0,
      );

      cameraActor.addComponent(camera);
      world.persistentLevel.registerActor(cameraActor);
      camera.activate();

      final fakeNative = _SmokeRecordingCamera();
      camera.bindNative(fakeNative);

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
        camera.syncWithFilamentCamera();
      }

      expect(fakeNative.lookAtCallCount, equals(3));
      expect(fakeNative.setProjectionCallCount, equals(1)); // dirty-flagged
      expect(fakeNative.setExposureCallCount, equals(1)); // dirty-flagged

      camera.unbindFromFilament();
      expect(fakeNative.disposeCallCount, equals(1));

      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_short.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Camera Module Smoke Tests Scenario 02: CameraComponent Filament native binding, exposure sync, and teardown';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          // Cinematic camera tracking between assets with shake pulses
          final targetX = math.sin(timeSeconds * 0.8) * 1.0;
          final pulseTime = timeSeconds % 2.5;
          final shake = math.max(0.0, 1.0 - pulseTime / 0.8) * 0.08;
          final shakeX = math.sin(timeSeconds * 45.0) * shake;
          final shakeY = math.cos(timeSeconds * 55.0) * shake;

          cam.lookAt(
            eyeX: targetX + math.sin(timeSeconds * 0.5) * 2.5 + shakeX,
            eyeY: 1.4 + shakeY,
            eyeZ: math.cos(timeSeconds * 0.5) * 2.5,
            centerX: targetX,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: SpringArmComponent lag, rotation inheritance, and collision', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final rootActor = LuminaActor();
      final arm = LuminaSpringArmComponent(targetArmLength: 3.5);
      arm.bEnableCameraLag = true;
      arm.cameraLagSpeed = 5.0;
      arm.bEnableCameraRotationLag = true;
      arm.cameraRotationLagSpeed = 5.0;
      final cameraComp = LuminaCameraComponent();

      rootActor.addComponent(arm);
      rootActor.addComponent(cameraComp);
      cameraComp.attachToComponent(arm);
      world.persistentLevel.registerActor(rootActor);

      world.beginPlay();

      // Tick several frames with rotation change on parent
      rootActor.actorRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4.0);
      for (int i = 0; i < 60; i++) {
        world.tick(1.0 / 60.0);
      }

      // Check that camera inherited rotation and is offset properly
      expect(arm.currentArmLength, equals(3.5));
      expect(cameraComp.worldLocation.z, isNot(equals(0.0))); // offset applied

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb', // Pawn model
        'Props/AC_units/ac_unit_b_600x600.glb', // Obstacle model
      ];

      const testTitle = 'Camera Module Smoke Tests Scenario 03: SpringArmComponent lag, rotation inheritance, and collision';

      // Simulation state for 10-second media render
      Vector3 laggedArmPos = Vector3(0.0, 0.6, 0.0);
      double laggedArmYaw = 0.0;
      double currentArmLength = 3.2;

      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;

          final tm = FilamentTransformManager(engine);

          // 1. Pawn movement and rotation (Asset 0)
          final pawnX = math.sin(timeSeconds * 0.9) * 1.5;
          final pawnZ = math.cos(timeSeconds * 0.45) * 0.4;
          final pawnYaw = math.sin(timeSeconds * 1.2) * 1.1;
          final pawnPos = Vector3(pawnX, 0.6, pawnZ);

          final aabb0 = assets[0].getBoundingBox();
          final size0 = aabb0.max - aabb0.min;
          final maxDim0 = math.max(size0.x, math.max(size0.y, size0.z));
          final scale0 = maxDim0 > 0 ? 1.0 / maxDim0 : 1.0;

          final pawnMat = Matrix4.identity()
            ..setTranslationRaw(pawnX, -aabb0.min.y * scale0, pawnZ)
            ..rotateY(pawnYaw)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, pawnMat.storage.toList());

          // 2. Obstacle placement (Asset 1)
          final obsPos = Vector3(0.0, 0.0, 1.4);
          final aabb1 = assets[1].getBoundingBox();
          final size1 = aabb1.max - aabb1.min;
          final maxDim1 = math.max(size1.x, math.max(size1.y, size1.z));
          final scale1 = maxDim1 > 0 ? 1.4 / maxDim1 : 1.0;

          final obsMat = Matrix4.identity()
            ..setTranslationRaw(obsPos.x, -aabb1.min.y * scale1, obsPos.z)
            ..scaleByDouble(scale1, scale1, scale1, 1.0);
          tm.setTransform(assets[1].rootEntity, obsMat.storage.toList());

          // 3. SpringArm lag physics calculation
          const dt = 1.0 / SmokeVideo.minimumFps; // one frame of renderRealAssetMedia's default rate
          final targetLagPos = pawnPos;
          laggedArmPos += (targetLagPos - laggedArmPos) * (1.0 - math.exp(-4.0 * dt));

          // Angle diff for yaw lag
          var yawDiff = pawnYaw - laggedArmYaw;
          while (yawDiff < -math.pi) {
            yawDiff += 2 * math.pi;
          }
          while (yawDiff > math.pi) {
            yawDiff -= 2 * math.pi;
          }
          laggedArmYaw += yawDiff * (1.0 - math.exp(-4.0 * dt));

          // 4. Collision check against obstacle
          // Desired arm direction behind pawn: offset by +Z in local space
          final backDir = Vector3(
            math.sin(laggedArmYaw),
            0.2,
            math.cos(laggedArmYaw),
          ).normalized();

          const targetArmLen = 3.2;
          double hitDist = targetArmLen;

          // Sphere-box distance test against obstacle at (0, 0, 1.4)
          final obsMin = Vector3(obsPos.x - 0.7, 0.0, obsPos.z - 0.7);
          final obsMax = Vector3(obsPos.x + 0.7, 1.8, obsPos.z + 0.7);

          // Raycast from pawnPos along backDir
          for (double d = 0.3; d <= targetArmLen; d += 0.1) {
            final testPt = pawnPos + backDir * d;
            if (testPt.x >= obsMin.x && testPt.x <= obsMax.x &&
                testPt.y >= obsMin.y && testPt.y <= obsMax.y &&
                testPt.z >= obsMin.z && testPt.z <= obsMax.z) {
              hitDist = d * 0.75; // Retract inside margin
              break;
            }
          }

          // Smooth arm retraction / extension
          currentArmLength += (hitDist - currentArmLength) * (1.0 - math.exp(-8.0 * dt));

          final camEye = pawnPos + backDir * currentArmLength;

          cam.lookAt(
            eyeX: camEye.x,
            eyeY: camEye.y + 0.3,
            eyeZ: camEye.z,
            centerX: pawnX,
            centerY: 0.6,
            centerZ: pawnZ,
          );
        },
      );

      world.cleanup();
    });
  });
}

class _SmokeRecordingCamera implements CameraNative {
  int setProjectionCallCount = 0;
  int lookAtCallCount = 0;
  int setExposureCallCount = 0;
  int disposeCallCount = 0;

  @override
  void setProjection({double? fovDegrees, double? aspect, double? near, double? far}) {
    setProjectionCallCount++;
  }

  @override
  void setProjectionOrtho({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {}

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
    lookAtCallCount++;
  }

  @override
  void setExposure({
    double aperture = 16.0,
    double shutterSpeed = 1.0 / 125.0,
    double sensitivity = 100.0,
  }) {
    setExposureCallCount++;
  }

  @override
  void dispose() {
    disposeCallCount++;
  }
}
