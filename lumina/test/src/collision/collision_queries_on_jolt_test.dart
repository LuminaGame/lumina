import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../blueprint/collision_nodes_test.dart' as collision_nodes;
import '../collision_events_test.dart' as collision_events;
import '../collision_filter_test.dart' as collision_filter;
import '../collision_primitive_test.dart' as collision_primitive;
import '../collision_query_test.dart' as collision_query;
import '../kinematic_sweep_test.dart' as kinematic_sweep;
import '../landscape_collision_test.dart' as landscape_collision;
import 'hit_result_locations_test.dart' as hit_result_locations;
import 'shape_components_and_presets_test.dart' as shape_components;
import 'trace_multi_sphere_test.dart' as trace_multi_sphere;

/// The collision queries and the overlap pass on Jolt's broad phase give
/// the results the Dart reference gives: the query, filter, sweep, event,
/// landscape, hit location and Blueprint collision node tests run again
/// with every collision subsystem asking Jolt which components to test.
void main() {
  setUpAll(() => LuminaCollisionSubsystem.defaultQueryBackend = LuminaCollisionQueryBackendKind.jolt);
  tearDownAll(() => LuminaCollisionSubsystem.defaultQueryBackend = LuminaCollisionQueryBackendKind.auto);

  test('a collision subsystem on Jolt answers through its broad phase', () {
    expect(LuminaPhysicsSubsystem.joltUnavailableReason, isNull, reason: 'the Jolt library must load here');
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    final collision = world.registerSubsystem(LuminaCollisionSubsystem());
    for (var i = 0; i < 20; i++) {
      world.persistentLevel.registerActor(LuminaActor(root: LuminaSphereComponent(location: Vector3(i * 100.0, 0, 0), radius: 10)));
    }
    final hit = HitResult();
    expect(collision.lineTraceSingle(start: Vector3(550, 0, -100), end: Vector3(550, 0, 100), out: hit), isFalse);
    expect(collision.lineTraceSingle(start: Vector3(500, 0, -100), end: Vector3(500, 0, 100), out: hit), isTrue);
    expect(hit.component!.worldLocation.x, 500);
    expect(collision.queryAccelerator?.name, 'jolt');
  });

  group('collision query tests', collision_query.main);
  group('kinematic sweep tests', kinematic_sweep.main);
  group('collision filter tests', collision_filter.main);
  group('landscape collision tests', landscape_collision.main);
  group('collision node tests', collision_nodes.main);
  group('collision event tests', collision_events.main);
  group('collision primitive tests', collision_primitive.main);
  group('hit result location tests', hit_result_locations.main);
  group('shape component and preset tests', shape_components.main);
  group('multi sphere trace tests', trace_multi_sphere.main);
}
