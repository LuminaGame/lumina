import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// What every trace and sweep reports in a hit (runtime axes, Y up): a line
/// trace's Location is its Impact Point; a sweep's Location is the shape's
/// centre at the hit and its Impact Point the contact; Time is the fraction
/// of the trace, Distance the length from Trace Start to Location.
class _Ball extends LuminaActor {
  _Ball(Vector3 at, {double radius = 50.0})
      : super(root: LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: radius), location: at);
}

class _Crate extends LuminaActor {
  _Crate(Vector3 at, Vector3 extent)
      : super(root: LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = extent, location: at);
}

Matcher _near(Vector3 v, [double tol = 1e-6]) =>
    predicate<Vector3>((a) => (a - v).length <= tol, 'within $tol of $v');

void main() {
  late LuminaWorld world;
  late LuminaCollisionSubsystem collision;
  setUp(() {
    world = LuminaWorld(worldType: LuminaWorldType.game);
    collision = world.registerSubsystem(LuminaCollisionSubsystem());
  });

  test('a line trace reports Location at the impact point with trace start, end, time and normals', () {
    world.persistentLevel.registerActor(_Ball(Vector3(300, 0, 0)));
    world.beginPlay();
    final start = Vector3(0, 0, 0), end = Vector3(1000, 0, 0);
    final hit = HitResult();
    expect(collision.lineTraceSingle(start: start, end: end, out: hit), isTrue);
    expect(hit.impactPoint, _near(Vector3(250, 0, 0)));
    expect(hit.location, _near(hit.impactPoint), reason: 'a ray has no extent: it stops where it hits');
    expect(hit.traceStart, _near(start));
    expect(hit.traceEnd, _near(end));
    expect(hit.time, closeTo(0.25, 1e-9));
    expect(hit.distance, closeTo(250, 1e-6));
    expect(hit.impactNormal, _near(Vector3(-1, 0, 0)));
    expect(hit.normal, _near(hit.impactNormal));

    final multi = collision.lineTraceMulti(start: start, end: end);
    expect(multi, hasLength(1));
    expect(multi.single.location, _near(Vector3(250, 0, 0)));
    expect(multi.single.traceStart, _near(start));
    expect(multi.single.traceEnd, _near(end));
  });

  test('raycast reports Location at the impact point and Time as the fraction of its length', () {
    world.persistentLevel.registerActor(_Crate(Vector3(500, 0, 0), Vector3(20, 20, 20)));
    world.beginPlay();
    final hit = HitResult();
    expect(collision.raycast(Vector3.zero(), Vector3(1, 0, 0), 960.0, hit), isTrue);
    expect(hit.impactPoint, _near(Vector3(480, 0, 0)));
    expect(hit.location, _near(hit.impactPoint));
    expect(hit.time, closeTo(0.5, 1e-9));
    expect(hit.distance, closeTo(480, 1e-6));
    expect(hit.traceEnd, _near(Vector3(960, 0, 0)));
    expect(hit.normal, _near(hit.impactNormal));
  });

  test('a capsule sweep reports Location at the capsule centre when it touches and Impact Point on the floor', () {
    final floor = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
      ..boxExtent = Vector3(1000, 100, 1000)
      ..location = Vector3(0, -100, 0);
    CollisionProfile.applyBlockAll(floor);
    collision.register(floor);
    final start = Vector3(0, 200, 0), delta = Vector3(0, -200, 0);
    final hit = HitResult();
    expect(collision.sweep(CapsuleShape(40, 90), Matrix4.translation(start), delta, hit), isTrue);
    expect(hit.time, closeTo(0.55, 0.02));
    expect(hit.location, _near(start + delta * hit.time, 1e-6), reason: 'the centre where the sweep stopped');
    expect(hit.location.y, closeTo(90, 4), reason: 'the capsule bottom (90 cm below the centre) rests on y = 0');
    expect(hit.impactPoint.y, closeTo(0, 4), reason: 'the contact is on the floor, not at the centre');
    expect(hit.traceStart, _near(start));
    expect(hit.traceEnd, _near(start + delta));
    expect(hit.distance, closeTo(200 * hit.time, 1e-6));
    expect(hit.normal.y, closeTo(1, 1e-3));
  });

  test('a sphere trace reports the sphere centre as Location, the contact as Impact Point and Normal from the centre', () {
    world.persistentLevel.registerActor(_Crate(Vector3(500, 0, 0), Vector3(20, 20, 20)));
    world.beginPlay();
    final start = Vector3(0, 0, 0), end = Vector3(1000, 0, 0);
    final hit = HitResult();
    expect(collision.sphereTraceSingle(start: start, end: end, radius: 50, out: hit), isTrue);
    expect(hit.location.x, closeTo(430, 1.0), reason: 'the face at x = 480 minus the radius');
    expect(hit.impactPoint.x, closeTo(480, 1.0));
    expect(hit.traceStart, _near(start));
    expect(hit.traceEnd, _near(end));
    expect(hit.time, closeTo(hit.location.x / 1000, 1e-6));
    expect(hit.distance, closeTo(hit.location.x, 1e-6));
    expect(hit.normal, _near((hit.location - hit.impactPoint).normalized(), 1e-6));
  });

  group('Blueprint hit result', () {
    late LuminaActor tracer;
    setUp(() {
      tracer = LuminaActor(location: Vector3.zero());
      world.persistentLevel.registerActor(tracer);
    });

    test('Line Trace By Channel → Break Hit Result gives Location = Impact Point and the trace fields', () {
      // Authoring axes (Z up): the ball sits 300 cm ahead on +X.
      world.persistentLevel.registerActor(_Ball(LuminaBlueprintFunctionLibrary.toRuntime(Vector3(300, 0, 0))));
      world.beginPlay();
      final r = LuminaBlueprintFunctionLibrary.lineTraceByChannel(tracer, Vector3(0, 0, 0), Vector3(1000, 0, 0));
      expect(r.returnValue, isTrue);
      final h = LuminaBlueprintFunctionLibrary.breakHitResult(r.outHit);
      expect(h.impactPoint, _near(Vector3(250, 0, 0), 1e-4));
      expect(h.location, _near(h.impactPoint, 1e-4));
      expect(h.traceStart, _near(Vector3.zero(), 1e-4));
      expect(h.traceEnd, _near(Vector3(1000, 0, 0), 1e-4));
      expect(h.time, closeTo(0.25, 1e-6));
      expect(h.distance, closeTo(250, 1e-4));
      expect(h.impactNormal, _near(Vector3(-1, 0, 0), 1e-4));
      expect(h.normal, _near(h.impactNormal, 1e-4));
    });

    test('a miss reports Location and Impact Point at the trace end with Time 1', () {
      world.beginPlay();
      final r = LuminaBlueprintFunctionLibrary.lineTraceByChannel(tracer, Vector3(0, 0, 0), Vector3(1000, 0, 0));
      expect(r.returnValue, isFalse);
      final h = LuminaBlueprintFunctionLibrary.breakHitResult(r.outHit);
      expect(h.blockingHit, isFalse);
      expect(h.location, _near(Vector3(1000, 0, 0)));
      expect(h.impactPoint, _near(Vector3(1000, 0, 0)));
      expect(h.traceStart, _near(Vector3.zero()));
      expect(h.traceEnd, _near(Vector3(1000, 0, 0)));
      expect(h.time, 1.0);
    });

    test('Sphere Trace By Channel → Break Hit Result gives the sphere centre as Location', () {
      world.persistentLevel.registerActor(_Crate(LuminaBlueprintFunctionLibrary.toRuntime(Vector3(500, 0, 0)), Vector3(20, 20, 20)));
      world.beginPlay();
      final r = LuminaBlueprintFunctionLibrary.sphereTraceByChannel(tracer, Vector3(0, 0, 0), Vector3(1000, 0, 0), 50.0);
      expect(r.returnValue, isTrue);
      final h = LuminaBlueprintFunctionLibrary.breakHitResult(r.outHit);
      expect(h.location.x, closeTo(430, 1.0));
      expect(h.impactPoint.x, closeTo(480, 1.0));
      expect(h.time, closeTo(h.location.x / 1000, 1e-4));
    });

    test('the VM Break Hit Result node outputs Normal, Time, Trace Start and Trace End', () {
      final spec = LuminaBlueprintNodeLibrary.spec('break_hit_result')!;
      expect(spec.outputs.map((p) => p.id),
          containsAll(['location', 'impact_point', 'normal', 'impact_normal', 'time', 'distance', 'trace_start', 'trace_end']));
      final hit = LuminaBlueprintFunctionLibrary.makeHitResult(true, Vector3(1, 2, 3), Vector3(1, 2, 2.5), Vector3(0, 0, 1), 42.0);
      final r = LuminaBlueprintFunctionLibrary.breakHitResult(hit);
      expect(r.normal, _near(Vector3(0, 0, 1)), reason: 'Normal falls back to Impact Normal');
    });
  });
}
