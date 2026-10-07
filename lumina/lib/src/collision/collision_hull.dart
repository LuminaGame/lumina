import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_core/lumina_core.dart';

/// One convex element of a static mesh's simple collision, as authored.
///
/// [points] are flattened `x, y, z` in **centimetres, Z up**, in the mesh's
/// model space: the frame the level's `metadata.actors` and the Details panel
/// use. The generated level carries them as constants and
/// Play-In-Editor builds the same values from the mesh asset, so a shipped
/// (or web) game never reads `.lmas` metadata. [runtimePoints] converts them
/// to the runtime's Y-up frame through [LuminaAxes], the one place that rule
/// is written.
class LuminaCollisionHull {
  /// The source mesh name, e.g. `UCX_SM_Casino_Chair` (a piece of a
  /// disconnected `UCX_` mesh gets a `_<n>` suffix).
  final String name;

  /// Authored points: `x, y, z` triples, cm, Z up.
  final List<double> points;

  /// The FBX collision-mesh name prefix it came from: `convex` (UCX_), `box` (UBX_), `sphere`
  /// (USP_) or `capsule` (UCP_). Every kind collides as the convex hull of
  /// its points.
  final String shape;

  const LuminaCollisionHull(this.name, this.points, {this.shape = 'convex'});

  /// Number of authored points.
  int get pointCount => points.length ~/ 3;

  /// The points in the runtime's frame (cm, Y up), relative to the mesh.
  List<Vector3> get runtimePoints => [
        for (var i = 0; i + 2 < points.length; i += 3) LuminaAxes.location([points[i], points[i + 1], points[i + 2]]),
      ];
}
