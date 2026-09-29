import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaInterpToMovementComponent Tests', () {
    test('One-shot interpolation stops at end and fires onInterpToStop', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interp = LuminaInterpToMovementComponent(
        duration: 2.0,
        behaviourType: InterpToBehaviourType.oneShot,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0), positionIsRelative: true),
          InterpControlPoint(Vector3(10.0, 0.0, 0.0), positionIsRelative: true),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      bool stopped = false;
      interp.onInterpToStop = () => stopped = true;

      world.beginPlay();

      // Half duration (1.0s) -> x = 5.0
      for (int i = 0; i < 50; i++) {
        world.tick(0.02);
      }
      expect(actor.actorLocation.x, closeTo(5.0, 1e-4));
      expect(stopped, isFalse);

      // Full duration (2.0s) -> x = 10.0
      for (int i = 0; i < 50; i++) {
        world.tick(0.02);
      }
      expect(actor.actorLocation.x, closeTo(10.0, 1e-4));
      expect(stopped, isTrue);

      // Further ticks move nothing
      world.tick(1.0);
      expect(actor.actorLocation.x, closeTo(10.0, 1e-4));
    });

    test('Arc-length parameterization ensures uniform speed across unequal segments', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      // Total length = 1.0 + 10.0 = 11.0m. Duration = 1.1s -> speed = 10.0 m/s
      final interp = LuminaInterpToMovementComponent(
        duration: 1.1,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(1.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(11.0, 0.0, 0.0)),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // At t = 0.05s, expected distance = 10.0 m/s * 0.05s = 0.5m
      world.tick(0.05);
      expect(actor.actorLocation.x, closeTo(0.5, 1e-4));
    });

    test('Waypoint events fire in order on crossing', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interp = LuminaInterpToMovementComponent(
        duration: 2.0,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(5.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(10.0, 0.0, 0.0)),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      final reachedWaypoints = <int>[];
      interp.onWaypointReached = (idx, pos) {
        reachedWaypoints.add(idx);
      };

      world.beginPlay();

      // Jump straight from t=0 to t=1.5 (crossing waypoint 1 at t=1.0)
      world.tick(1.5);
      expect(reachedWaypoints, contains(1));
    });

    test('loopReset wraps progress and repositions to start', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interp = LuminaInterpToMovementComponent(
        duration: 1.0,
        behaviourType: InterpToBehaviourType.loopReset,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(10.0, 0.0, 0.0)),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // After 1.5 durations (1.5s), progress = 0.5 -> x = 5.0
      world.tick(1.5);
      expect(actor.actorLocation.x, closeTo(5.0, 1e-3));
    });

    test('pingPong reflects direction and moves continuously', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interp = LuminaInterpToMovementComponent(
        duration: 1.0,
        behaviourType: InterpToBehaviourType.pingPong,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(10.0, 0.0, 0.0)),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();

      // t = 1.5s -> returning from 10 to 0 -> x = 5.0
      world.tick(1.5);
      expect(actor.actorLocation.x, closeTo(5.0, 1e-3));

      // t = 2.0s -> back at start -> x = 0.0
      world.tick(0.5);
      expect(actor.actorLocation.x, closeTo(0.0, 1e-3));
    });

    test('pause and resume control movement', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor(location: Vector3(0.0, 0.0, 0.0));
      final interp = LuminaInterpToMovementComponent(
        duration: 1.0,
        controlPoints: [
          InterpControlPoint(Vector3(0.0, 0.0, 0.0)),
          InterpControlPoint(Vector3(10.0, 0.0, 0.0)),
        ],
      );
      actor.addComponent(interp);
      world.persistentLevel.registerActor(actor);

      world.beginPlay();
      world.tick(0.5);
      expect(actor.actorLocation.x, closeTo(5.0, 1e-3));

      interp.pause();
      expect(interp.isPaused, isTrue);
      world.tick(0.5);
      expect(actor.actorLocation.x, closeTo(5.0, 1e-3)); // did not move while paused

      interp.resume();
      expect(interp.isPaused, isFalse);
      world.tick(0.5);
      expect(actor.actorLocation.x, closeTo(10.0, 1e-3));
    });
  });
}
