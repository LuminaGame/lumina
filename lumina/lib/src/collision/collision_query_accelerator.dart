import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';

/// Which broad phase narrows the collision subsystem's queries and overlap
/// pass: [dart] tests every component (the reference, and the web's);
/// [jolt] asks Jolt's broad phase for the components a query can touch and
/// tests only those, with the same narrow phase, so results are the same;
/// [auto] uses Jolt where it runs once a world has
/// `LuminaCollisionSubsystem.autoAcceleratorThreshold` components.
enum LuminaCollisionQueryBackendKind { auto, dart, jolt }

/// A broad phase over a collision subsystem's components: given a segment
/// or a box, the components whose bounds it may touch (a superset; never
/// one it misses). The subsystem tells it every component it registers,
/// unregisters and every one whose bounds changed (`markCollisionDirty`).
abstract interface class LuminaCollisionQueryAccelerator {
  /// A short name for diagnostics ("jolt").
  String get name;

  void add(LuminaCollisionComponent component);
  void remove(LuminaCollisionComponent component);

  /// [component]'s bounds changed (it moved, turned or was resized).
  void dirty(LuminaCollisionComponent component);

  /// The components whose bounds the segment [start]..[end] may cross.
  Iterable<LuminaCollisionComponent> alongSegment(Vector3 start, Vector3 end);

  /// The components whose bounds [box] may cross when moved by [delta].
  Iterable<LuminaCollisionComponent> alongSweep(Aabb3 box, Vector3 delta);

  /// The components whose bounds may overlap [box].
  Iterable<LuminaCollisionComponent> inBox(Aabb3 box);

  void dispose();
}
