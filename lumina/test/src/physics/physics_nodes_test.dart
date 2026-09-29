import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/physics_blueprint.dart';
import 'physics_fixture.dart';

/// The Blueprint Physics nodes (authoring space) and physics hit
/// events reaching `onComponentHit` and Blueprint Event Hit.
void main() {
  test('physics contacts raise hit events with a normal impulse, once per frame, not while resting', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final box = w.box(Vector3(0, 125, 0), Vector3.all(25));
    final hits = <(int, HitResult)>[];
    var frame = 0;
    box.onComponentHit = (self, other, hit) => hits.add((frame, hit));
    var floorHits = 0;
    w.floor.onComponentHit = (self, other, hit) => floorHits++;
    w.begin();
    w.run(3, (_) => frame++);
    expect(hits, isNotEmpty, reason: 'the landing is a hit');
    final (landingFrame, landing) = hits.first;
    expect(landing.normalImpulse, greaterThan(1000), reason: '10 kg at ~443 cm/s is ~4400 kg·cm/s');
    expect(landing.impactNormal.y, closeTo(1, 1e-6), reason: 'pointing away from the floor, towards the box');
    expect(landing.component, same(w.floor));
    expect(floorHits, hits.length, reason: 'both sides are told');
    expect(hits.map((h) => h.$1).toSet().length, hits.length, reason: 'at most once per frame per pair');
    expect(hits.last.$1 - landingFrame, lessThan(40), reason: 'no hits once it rests (last at ${hits.last.$1})');
  });

  test('the Physics nodes drive bodies in authoring space and Event Hit receives physics contacts (VM)', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final actor = LuminaBlueprintClass.fromDocument(physicsBlueprint(), name: 'bp_physics').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    w.world.persistentLevel.registerActor(actor as LuminaActor);
    w.begin();
    w.run(2);
    final printed = [for (final t in trace) if (t.printed != null) t.printed!];
    // Crate mass (override), simulating, ball mass override, the kick (900 / 3
    // kg along authoring X), the spin about authoring Y, and asleep.
    expect(printed.take(4), ['10.0', 'true', '3.0', 'X=300.000 Y=0.000 Z=0.000']);
    expect(printed[4], 'X=0.000 Y=90.000 Z=0.000');
    expect(printed[5], 'false', reason: 'put to sleep, then woken again');
    final hitImpulses = [
      for (final t in trace)
        if (t.printed != null && t.registryId == 'print_string' && t.nodeId == 'say_hit') double.parse(t.printed!),
    ];
    expect(hitImpulses, isNotEmpty, reason: 'Event Hit fired for the crate and ball landing');
    expect(hitImpulses.every((i) => i > 0), isTrue);
    final components = actor.blueprintComponents;
    final crate = components['crate'] as LuminaBoxComponent;
    final ball = components['ball'] as LuminaSphereComponent;
    expect(crate.physicsBody!.linearDamping, 0.05);
    expect(ball.physicsBody!.angularDamping, 0.1);
    // Put to Sleep zeroes the kick; woken, it just falls.
    expect(ball.worldLocation.y, closeTo(20, 1.0), reason: 'the ball rests on the floor');
    expect(ball.worldLocation.x, closeTo(150, 1.0));
  });

  test('add_impulse of 1000 kg·cm/s on a 10 kg body adds 100 cm/s; set_simulate_physics false freezes it', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final box = w.box(Vector3(0, 400, 0), Vector3.all(25))..enableGravity = false;
    w.begin();
    LuminaBlueprintFunctionLibrary.addImpulse(box, Vector3(0, 1000, 0));
    // Authoring +Y is runtime −z.
    expect(box.physicsBody!.linearVelocity.z, closeTo(-100, 1e-9));
    expect(LuminaBlueprintFunctionLibrary.getPhysicsLinearVelocity(box).y, closeTo(100, 1e-9));
    w.run(0.5);
    final at = box.worldLocation;
    LuminaBlueprintFunctionLibrary.setSimulatePhysics(box, false);
    expect(LuminaBlueprintFunctionLibrary.isSimulatingPhysics(box), isFalse);
    w.run(1);
    expect(box.worldLocation.distanceTo(at), lessThan(1e-9));
    LuminaBlueprintFunctionLibrary.setSimulatePhysics(box, true);
    expect(LuminaBlueprintFunctionLibrary.isSimulatingPhysics(box), isTrue, reason: 'switched back on during play');
  });

  test('a placed Blueprint overrides its component physics (level actor map → generated level and PIE)', () {
    final actor = LuminaBlueprintClass.fromDocument(physicsBlueprint(), name: 'bp_physics').instantiate();
    final overrides = LuminaBlueprintCollisionOverrides.fromActorMap({
      'components': [
        {
          'id': 'a1.physics.crate',
          'type': 'LuminaBoxComponent',
          'properties': {
            'blueprintComponentId': 'crate',
            'physics': {'simulate': false, 'massKg': 42.0},
          },
        },
      ],
    });
    expect(overrides['crate'], {
      'physics': {'simulate': false, 'massKg': 42.0},
    });
    expect(LuminaBlueprintCollisionOverrides.apply(actor, overrides), 1);
    final crate = (actor as LuminaBlueprintRuntime).blueprintComponents['crate'] as LuminaBoxComponent;
    expect(crate.simulatePhysics, isFalse);
    expect(crate.massKg, 42.0);
    expect(crate.getResponse(CollisionObjectType.pawn), CollisionResponse.block, reason: 'collision untouched');
  });
}
