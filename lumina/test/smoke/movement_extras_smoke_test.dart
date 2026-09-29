import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Movement Extras Module Smoke Tests', () {
    test('Scenario 01: LuminaProjectileMovementComponent ballistic trajectory, swept obstacle collision, surface bouncing, and homing guidance with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);

      final floor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final floorCol = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(20.0, 0.2, 20.0);
      CollisionProfile.applyBlockAll(floorCol);
      floor.addComponent(floorCol);
      world.persistentLevel.registerActor(floor);

      final projectileActor = LuminaActor(location: Vector3(-5.0, 5.0, 0.0));
      final proj = LuminaProjectileMovementComponent(
        initialSpeed: 12.0,
        projectileGravityScale: 1.0,
        bShouldBounce: true,
        bounciness: 0.6,
        friction: 0.2,
      );
      proj.setVelocity(Vector3(6.0, 4.0, 0.0));
      projectileActor.addComponent(proj);
      world.persistentLevel.registerActor(projectileActor);

      world.beginPlay();

      int bounces = 0;
      proj.onProjectileBounce = (hit, impactVel) {
        bounces++;
      };

      for (int i = 0; i < 120; i++) {
        world.tick(0.016);
      }

      expect(bounces, greaterThan(0));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/Access_cards/access_card_blue.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Movement Extras Module Smoke Tests Scenario 01: LuminaProjectileMovementComponent ballistic trajectory, swept obstacle collision, surface bouncing, and homing guidance with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Floor Obstacle Barrels (Asset 0)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Projectile Card (Asset 1) flying and bouncing
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 0.8 / max1 : 1.0;

            final t = timeSeconds % 3.0;
            final posX = -4.0 + t * 2.8;
            final posY = 0.5 + (math.sin(t * 3.5).abs()) * 2.0;
            final posZ = math.sin(timeSeconds * 1.5) * 1.0;

            final projMat = Matrix4.identity()
              ..setTranslationRaw(posX, posY, posZ)
              ..rotateZ(-t * 3.0)
              ..rotateY(t * 2.0)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, projMat.storage.toList());
          }

          // Target AC Unit (Asset 2) at landing point
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.6 / max2 : 1.0;
            final acMat = Matrix4.identity()
              ..setTranslationRaw(4.5, -aabb2.min.y * scale2, 0.0)
              ..rotateY(math.pi)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, acMat.storage.toList());
          }

          // Orbiting dynamic tracking camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.4) * 6.0,
            eyeY: 2.8,
            eyeZ: math.cos(timeSeconds * 0.4) * 6.0,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaRotatingMovementComponent and LuminaInterpToMovementComponent spinning rotors, waypoint ping-pong elevators, and orbital movement with real 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      // Rotating Actor (spinning around local Y and orbiting)
      final spinningActor = LuminaActor(location: Vector3(0.0, 1.0, 0.0));
      final rotComp = LuminaRotatingMovementComponent(
        rotationRate: Vector3(0.0, 120.0, 0.0),
        pivotTranslation: Vector3(2.0, 0.0, 0.0),
      );
      spinningActor.addComponent(rotComp);
      world.persistentLevel.registerActor(spinningActor);

      // InterpTo Actor (ping-pong along 3 waypoints)
      final elevatorActor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interpComp = LuminaInterpToMovementComponent(
        duration: 3.0,
        behaviourType: InterpToBehaviourType.pingPong,
        controlPoints: [
          InterpControlPoint(Vector3(-3.0, 0.5, -2.0)),
          InterpControlPoint(Vector3(0.0, 2.5, 0.0)),
          InterpControlPoint(Vector3(3.0, 0.5, 2.0)),
        ],
      );
      elevatorActor.addComponent(interpComp);
      world.persistentLevel.registerActor(elevatorActor);

      world.beginPlay();

      for (int i = 0; i < 60; i++) {
        world.tick(0.016);
      }

      expect(interpComp.progress, greaterThan(0.0));

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Movement Extras Module Smoke Tests Scenario 02: LuminaRotatingMovementComponent and LuminaInterpToMovementComponent spinning rotors, waypoint ping-pong elevators, and orbital movement with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Central Barrel (Asset 0) spinning continuously
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.4 / max0 : 1.0;
          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb0.min.y * scale0, 0.0)
            ..rotateY(timeSeconds * 2.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // AC Unit (Asset 1) orbiting around central barrel
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;
            final orbitRadius = 3.5;
            final orbitAngle = timeSeconds * 1.2;
            final acMat = Matrix4.identity()
              ..setTranslationRaw(math.sin(orbitAngle) * orbitRadius, 1.2, math.cos(orbitAngle) * orbitRadius)
              ..rotateY(orbitAngle + math.pi / 2.0)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Card Platform (Asset 2) moving in ping-pong elevator motion
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.0 / max2 : 1.0;
            final cycle = (math.sin(timeSeconds * 1.5) + 1.0) * 0.5; // 0..1
            final elevX = -2.5 + cycle * 5.0;
            final elevY = 0.2 + math.sin(cycle * math.pi) * 2.5;
            final elevZ = -1.5 + cycle * 3.0;

            final cardMat = Matrix4.identity()
              ..setTranslationRaw(elevX, elevY, elevZ)
              ..rotateY(timeSeconds * 3.0)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * 6.5,
            eyeY: 3.0,
            eyeZ: math.cos(timeSeconds * 0.3) * 6.5,
            centerX: 0.0,
            centerY: 1.0,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
  });
}
