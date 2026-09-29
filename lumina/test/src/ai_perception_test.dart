import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaAIPerception Tests', () {
    test('Target in cone and clear LOS within sightRadius is sensed', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0), rotation: Quaternion.identity()); // facing +Z
      final target = LuminaActor(location: Vector3(0.0, 0.0, 1000.0)); // 10m (1000cm) ahead along +Z

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, loseSightRadius: 1800.0, peripheralVisionAngleDegrees: 70.0),
        updateInterval: 0.1,
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      world.persistentLevel.registerActor(target);
      percepSys.registerSource(target);

      world.beginPlay();

      int perceptionUpdates = 0;
      AIStimulus? receivedStimulus;
      perceptionComp.onTargetPerceptionUpdated = (actor, stimulus) {
        perceptionUpdates++;
        receivedStimulus = stimulus;
      };

      // Tick 0.1s to trigger update
      world.tick(0.1);

      expect(perceptionUpdates, equals(1));
      expect(receivedStimulus, isNotNull);
      expect(receivedStimulus!.wasSuccessfullySensed, isTrue);
      expect(receivedStimulus!.type, equals(AISenseType.sight));
      expect(perceptionComp.getCurrentlyPerceivedActors(sense: AISenseType.sight), contains(target));
    });

    test('Hysteresis: unsensed target at 16m (1600cm) is not sensed, already-sensed target remains until loseSightRadius', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final target = LuminaActor(location: Vector3(0.0, 0.0, 1600.0)); // > 1500cm, < 1800cm

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, loseSightRadius: 1800.0),
        updateInterval: 0.1,
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      world.persistentLevel.registerActor(target);
      percepSys.registerSource(target);
      world.beginPlay();

      // 1. Initial check at 1600cm: never seen -> NOT sensed
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);

      // 2. Move to 1000cm -> Sensed
      target.actorLocation = Vector3(0.0, 0.0, 1000.0);
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(target));

      // 3. Move to 1700cm -> Stays sensed due to loseSightRadius: 1800
      target.actorLocation = Vector3(0.0, 0.0, 1700.0);
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(target));

      // 4. Move to 1900cm -> Lost (fires wasSuccessfullySensed = false)
      bool lostFired = false;
      perceptionComp.onTargetPerceptionUpdated = (actor, stimulus) {
        if (!stimulus.wasSuccessfullySensed) lostFired = true;
      };
      target.actorLocation = Vector3(0.0, 0.0, 1900.0);
      world.tick(0.1);
      expect(lostFired, isTrue);
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);
    });

    test('Target behind viewer is not sensed until viewer rotates', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0)); // facing +Z
      final target = LuminaActor(location: Vector3(0.0, 0.0, -500.0)); // 500cm behind viewer (-Z)

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, peripheralVisionAngleDegrees: 70.0),
        updateInterval: 0.1,
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      world.persistentLevel.registerActor(target);
      percepSys.registerSource(target);
      world.beginPlay();

      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);

      // Rotate viewer by 180 degrees (yaw = pi) to face behind
      viewer.actorRotation = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi);
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(target));
    });

    test('Blocking wall blocks sight perception; removing wall allows perception', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final colSys = LuminaCollisionSubsystem();
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaCollisionSubsystem>(colSys);
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final target = LuminaActor(location: Vector3(0.0, 0.0, 1000.0));

      final wall = LuminaActor(location: Vector3(0.0, 0.0, 500.0));
      final wallCol = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(500.0, 500.0, 100.0);
      CollisionProfile.applyBlockAll(wallCol);
      wall.addComponent(wallCol);

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0),
        updateInterval: 0.1,
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      world.persistentLevel.registerActor(target);
      world.persistentLevel.registerActor(wall);
      percepSys.registerSource(target);
      world.beginPlay();

      // 1. With wall present: LOS blocked -> not sensed
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);

      // 2. Remove wall -> LOS clear -> sensed
      world.persistentLevel.unregisterActor(wall);
      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(target));
    });

    test('reportNoiseEvent delivers hearing stimulus with proportional strength through obstacles', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final perceptionComp = LuminaAIPerceptionComponent(
        hearingConfig: AISenseConfigHearing(hearingRange: 2000.0),
      );
      viewer.addComponent(perceptionComp);
      world.persistentLevel.registerActor(viewer);
      world.beginPlay();

      AIStimulus? heardStimulus;
      perceptionComp.onTargetPerceptionUpdated = (actor, stimulus) {
        heardStimulus = stimulus;
      };

      // 1. Noise at 1000cm away
      final noisePos = Vector3(1000.0, 0.0, 0.0);
      LuminaAIPerceptionSystem.reportNoiseEvent(world, noisePos, loudness: 1.0);

      expect(heardStimulus, isNotNull);
      expect(heardStimulus!.type, equals(AISenseType.hearing));
      expect(heardStimulus!.strength, closeTo(0.5, 1e-4)); // 1 - 1000/2000 = 0.5
      expect(heardStimulus!.stimulusLocation, equals(noisePos));

      // 2. Noise beyond hearing range (2500cm) produces no stimulus
      heardStimulus = null;
      LuminaAIPerceptionSystem.reportNoiseEvent(world, Vector3(2500.0, 0.0, 0.0), loudness: 1.0);
      expect(heardStimulus, isNull);
    });

    test('Stimulus aging removes forgotten actor after maxAge', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final target = LuminaActor(location: Vector3(0.0, 0.0, 500.0));

      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0, maxAge: 2.0),
        updateInterval: 0.1,
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      world.persistentLevel.registerActor(target);
      percepSys.registerSource(target);
      world.beginPlay();

      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), contains(target));

      // Unregister target as source so sight stops refreshing it
      percepSys.unregisterSource(target);

      LuminaActor? forgottenActor;
      perceptionComp.onTargetPerceptionForgotten = (actor) {
        forgottenActor = actor;
      };

      // Age stimulus by ticking 2.5 seconds
      for (int i = 0; i < 25; i++) {
        world.tick(0.1);
      }

      expect(forgottenActor, equals(target));
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);
    });

    test('Viewer self-filter prevents perceiving self or own noise', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final percepSys = LuminaAIPerceptionSystem();
      world.registerSubsystem<LuminaAIPerceptionSystem>(percepSys);

      final viewer = LuminaPawn(location: Vector3(0.0, 0.0, 0.0));
      final perceptionComp = LuminaAIPerceptionComponent(
        sightConfig: AISenseConfigSight(sightRadius: 1500.0),
        hearingConfig: AISenseConfigHearing(hearingRange: 2000.0),
      );
      viewer.addComponent(perceptionComp);

      world.persistentLevel.registerActor(viewer);
      percepSys.registerSource(viewer);
      world.beginPlay();

      world.tick(0.1);
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);

      LuminaAIPerceptionSystem.reportNoiseEvent(
        world,
        Vector3(0.0, 0.0, 0.0),
        instigator: viewer,
      );
      expect(perceptionComp.getCurrentlyPerceivedActors(), isEmpty);
    });
  });
}
