// Exposed-functions fixture: a project function that changes the world.
import 'dart:math' as math;

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

/// Marker colours, in the order an actor places its markers.
const List<(double, double, double)> _colours = [(0.9, 0.2, 0.15), (0.2, 0.75, 0.25), (0.2, 0.4, 0.95)];

final Expando<int> _placed = Expando<int>('markers');

/// How many markers [actor] has placed.
int markersPlacedBy(LuminaActor actor) => _placed[actor] ?? 0;

/// Places a marker post standing on [at] (cm, Z up) in the world of the actor
/// running the node.
@BlueprintCallable(category: 'Game|Markers', keywords: ['spawn', 'post', 'flag'])
void spawnMarker(LuminaActor self, Vector3 at) {
  final world = self.world;
  if (world == null) return;
  final n = markersPlacedBy(self);
  _placed[self] = n + 1;
  final c = _colours[n % _colours.length];
  world.spawnActor(LuminaPrimitiveActor(
    shape: LuminaPrimitiveShape.cylinder,
    size: Vector3(40.0, 180.0, 40.0),
    color: Vector3(c.$1, c.$2, c.$3),
    location: LuminaBlueprintFunctionLibrary.toRuntime(at + Vector3(0.0, 0.0, 90.0)),
  ));
}

/// Where marker [index] of [count] goes on a ring of [radius] cm, as an
/// offset on the ground (cm, Z up).
@BlueprintPure(category: 'Game|Markers', displayName: 'Marker Ring Offset')
Vector3 markerRing(int index, {double radius = 250.0, int count = 3}) {
  final angle = 2.0 * math.pi * index / (count <= 0 ? 1 : count);
  return Vector3(radius * math.sin(angle), radius * math.cos(angle), 0.0);
}
