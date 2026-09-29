import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Multi line traces, sphere traces and the actor / distance
/// fields of a hit, on the real collision subsystem (runtime axes, Y up).
class _Ball extends LuminaActor {
  _Ball(Vector3 at, {double radius = 50.0})
      : super(root: LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: radius), location: at);
}

class _Crate extends LuminaActor {
  _Crate(Vector3 at, Vector3 extent)
      : super(root: LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = extent, location: at);
}

void main() {
  late LuminaWorld world;
  late LuminaCollisionSubsystem collision;
  setUp(() {
    world = LuminaWorld(worldType: LuminaWorldType.game);
    collision = world.registerSubsystem(LuminaCollisionSubsystem());
  });

  test('lineTraceMulti returns every hit sorted by distance with actor and distance filled', () {
    final a = _Ball(Vector3(300, 0, 0)), b = _Ball(Vector3(600, 0, 0)), c = _Ball(Vector3(900, 0, 0));
    for (final actor in [c, a, b]) {
      world.persistentLevel.registerActor(actor);
    }
    world.beginPlay();
    final hits = collision.lineTraceMulti(start: Vector3.zero(), end: Vector3(2000, 0, 0));
    expect(hits.map((h) => h.actor), [a, b, c]);
    expect(hits.map((h) => h.distance), [closeTo(250, 1e-6), closeTo(550, 1e-6), closeTo(850, 1e-6)]);
    expect(hits.every((h) => h.blockingHit), isTrue);
    expect(hits.first.impactPoint.x, closeTo(250, 1e-6));

    final single = HitResult();
    expect(collision.lineTraceSingle(start: Vector3.zero(), end: Vector3(2000, 0, 0), out: single), isTrue);
    expect(single.actor, a);
    expect(single.distance, closeTo(250, 1e-6));

    // Filters: ignore an actor, keep only a class.
    expect(collision.lineTraceMulti(start: Vector3.zero(), end: Vector3(2000, 0, 0), ignoreActors: [a]).map((h) => h.actor),
        [b, c]);
    expect(
        collision
            .lineTraceMulti(start: Vector3.zero(), end: Vector3(2000, 0, 0), actorFilter: (actor) => identical(actor, c))
            .map((h) => h.actor),
        [c]);
    expect(collision.lineTraceMulti(start: Vector3.zero(), end: Vector3(100, 0, 0)), isEmpty);
  });

  test('a sphere trace of radius 50 hits a box a line trace 30 cm to the side misses', () {
    final crate = _Crate(Vector3(500, 0, 0), Vector3(20, 20, 20));
    world.persistentLevel.registerActor(crate);
    world.beginPlay();
    final start = Vector3(0, 0, 50), end = Vector3(1000, 0, 50);
    final line = HitResult();
    expect(collision.lineTraceSingle(start: start, end: end, out: line), isFalse);
    final sphere = HitResult();
    expect(collision.sphereTraceSingle(start: start, end: end, radius: 50, out: sphere), isTrue);
    expect(sphere.actor, crate);
    expect(sphere.distance, greaterThan(400));
    expect(sphere.distance, lessThan(500));
    expect(collision.sphereTraceSingle(start: start, end: end, radius: 10, out: HitResult()), isFalse);
  });

  test('sphereTraceMulti keeps every actor along the sweep, sorted, and honours the class filter', () {
    final near = _Ball(Vector3(300, 0, 0)), far = _Crate(Vector3(700, 0, 0), Vector3(30, 30, 30));
    world.persistentLevel.registerActor(far);
    world.persistentLevel.registerActor(near);
    world.beginPlay();
    final hits = collision.sphereTraceMulti(start: Vector3.zero(), end: Vector3(1000, 0, 0), radius: 25);
    expect(hits.map((h) => h.actor), [near, far]);
    expect(hits.first.distance, lessThan(hits.last.distance));
    final crates =
        collision.sphereTraceMulti(start: Vector3.zero(), end: Vector3(1000, 0, 0), radius: 25, actorFilter: (a) => a is _Crate);
    expect(crates.map((h) => h.actor), [far]);
  });
}
