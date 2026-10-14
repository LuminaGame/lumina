import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/object/actor.dart';

/// Distance-based hiding of meshes. A mesh component with a
/// [LuminaStaticMeshComponent.minDrawDistance] or
/// [LuminaStaticMeshComponent.maxDrawDistance] (cm, 0 = no limit) leaves the
/// scene while its origin is nearer than the minimum or farther than the
/// maximum from the point the world renders from
/// ([LuminaWorld.drawDistanceViewLocation]); checked once per rendered
/// frame, the scene changed only when the answer changes.
abstract final class LuminaDrawDistance {
  /// Whether something [distance] cm from the view is drawn between [min]
  /// and [max] (cm; 0 is no limit).
  static bool within(double distance, double min, double max) =>
      !(min > 0 && distance < min) && !(max > 0 && distance > max);

  /// The Details' Min / Max Draw Distance (metres) in cm, or null when
  /// neither limits anything.
  static ({double min, double max})? fromDetails(Map<String, Object?> properties) {
    double metres(Object? v) => v is num && v > 0 ? v.toDouble() * LuminaUnits.unitsPerMetre : 0.0;
    final min = metres(properties['minDrawDistance']), max = metres(properties['maxDrawDistance']);
    return min == 0 && max == 0 ? null : (min: min, max: max);
  }

  /// Gives every scene component of [actor] the limits [min] / [max] (cm);
  /// the ones that draw (meshes, instanced batches, procedural sections,
  /// particles) follow them. Returns [actor].
  static T apply<T extends LuminaActor>(T actor, {double min = 0, double max = 0}) {
    for (final c in actor.components.whereType<LuminaSceneComponent>()) {
      c
        ..minDrawDistance = min
        ..maxDrawDistance = max;
    }
    return actor;
  }
}
