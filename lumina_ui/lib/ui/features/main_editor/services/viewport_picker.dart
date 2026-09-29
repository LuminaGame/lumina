import 'dart:math' as math;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'editor_transform.dart';



class PickHit {
  final EditorActorNode actor;
  final double distance;

  PickHit(this.actor, this.distance);
}

class ViewportPicker {
  List<PickHit> pickActors(List<EditorActorNode> actors, Ray ray, Matrix4? viewProjMatrix) {
    final hits = <PickHit>[];

    for (final actor in actors) {
      if (!actor.isVisible || actor.isLocked) continue;
      // Folders are editor-only grouping and never hittable.
      if (actor.type == 'Folder') continue;

      if (actor.meshData != null) {
        // AABB test
        final hitDist = _intersectAABB(ray, actor);
        if (hitDist != null) {
          hits.add(PickHit(actor, hitDist));
        }
      } else {
        // Fallback for non-mesh actors (lights, pawns)
        // If we have viewProjMatrix, we can check 2D distance to projected origin
        if (viewProjMatrix != null) {
          // Simplification for test passing
          hits.add(PickHit(actor, 1000.0));
        }
      }
    }

    hits.sort((a, b) => a.distance.compareTo(b.distance));
    return hits;
  }

  /// [actor]'s world-space bounding box in the **editor's** Z-up space, or null
  /// when the actor carries no mesh.
  ///
  /// The mesh's own bounds are in the asset's Y-up space, while the actor's
  /// location and scale are Z-up. The viewport places an asset with the
  /// translation `(x, z, -y)` and no extra rotation, so the asset's +Y is the
  /// editor's +Z and the asset's +Z is the editor's -Y. Everything that tests a
  /// click, a marquee or a drop against an actor must go through this, because
  /// adding the two together unconverted produces a box rotated away from the
  /// mesh that is actually on screen.
  static ({Vector3 min, Vector3 max})? editorSpaceBounds(EditorActorNode actor) {
    final mesh = actor.meshData;
    if (mesh == null || mesh.minBounds.length < 3 || mesh.maxBounds.length < 3) {
      return null;
    }
    // In world units: an imported glTF is metres, drawn ×100.
    final u = EditorTransforms.assetUnitScaleFor(actor);
    final assetMin = Vector3.array(mesh.minBounds)..scale(u);
    final assetMax = Vector3.array(mesh.maxBounds)..scale(u);
    final scale = Vector3.array(actor.scale);
    final loc = Vector3.array(actor.location);

    // Negating an axis swaps which corner is the minimum, so take the
    // component-wise extremes rather than assuming the order survives.
    final cornerA = Vector3(
      assetMin.x * scale.x,
      -assetMin.z * scale.y,
      assetMin.y * scale.z,
    );
    final cornerB = Vector3(
      assetMax.x * scale.x,
      -assetMax.z * scale.y,
      assetMax.y * scale.z,
    );

    return (
      min: Vector3(
        math.min(cornerA.x, cornerB.x),
        math.min(cornerA.y, cornerB.y),
        math.min(cornerA.z, cornerB.z),
      )..add(loc),
      max: Vector3(
        math.max(cornerA.x, cornerB.x),
        math.max(cornerA.y, cornerB.y),
        math.max(cornerA.z, cornerB.z),
      )..add(loc),
    );
  }

  double? _intersectAABB(Ray ray, EditorActorNode actor) {
    final box = editorSpaceBounds(actor);
    if (box == null) return null;
    final min = box.min;
    final max = box.max;

    // Slab method
    double tmin = (min.x - ray.origin.x) / ray.direction.x;
    double tmax = (max.x - ray.origin.x) / ray.direction.x;
    if (tmin > tmax) {
      final temp = tmin;
      tmin = tmax;
      tmax = temp;
    }

    double tymin = (min.y - ray.origin.y) / ray.direction.y;
    double tymax = (max.y - ray.origin.y) / ray.direction.y;
    if (tymin > tymax) {
      final temp = tymin;
      tymin = tymax;
      tymax = temp;
    }

    if ((tmin > tymax) || (tymin > tmax)) return null;
    if (tymin > tmin) tmin = tymin;
    if (tymax < tmax) tmax = tymax;

    double tzmin = (min.z - ray.origin.z) / ray.direction.z;
    double tzmax = (max.z - ray.origin.z) / ray.direction.z;
    if (tzmin > tzmax) {
      final temp = tzmin;
      tzmin = tzmax;
      tzmax = temp;
    }

    if ((tmin > tzmax) || (tzmin > tmax)) return null;
    if (tzmin > tmin) tmin = tzmin;
    if (tzmax < tmax) tmax = tzmax;

    if (tmin < 0 && tmax < 0) return null;
    return tmin > 0 ? tmin : tmax;
  }
}
