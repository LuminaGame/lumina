import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Where an editor actor is drawn. Stored transforms are
/// centimetres, Z up; the viewport's Filament scene is the runtime's Y up.
/// The conversion is lumina's [LuminaAxes] — the same rule the generated
/// game and Play-In-Editor use, so the three agree.
abstract final class EditorTransforms {
  /// [actor]'s transform in the viewport (runtime) space.
  static Matrix4 actorMatrix(EditorActorNode actor) => matrixFor(actor.location, actor.rotation, actor.scale);

  static Matrix4 matrixFor(List<double> location, List<double> rotation, List<double> scale) =>
      Matrix4.compose(LuminaAxes.location(location), LuminaAxes.rotation(rotation), LuminaAxes.scale(scale));

  /// Asset units → world units for the mesh [actor] draws: an imported glTF
  /// is metres (×100); a primitive's GLB is generated in centimetres.
  static double assetUnitScaleFor(EditorActorNode actor) => actor.type == 'Primitive' ? 1.0 : LuminaUnits.unitsPerMetre;

  /// [actorMatrix] followed by the asset unit scale: what a mesh's root is
  /// drawn with.
  static Matrix4 meshMatrix(EditorActorNode actor) {
    final u = assetUnitScaleFor(actor);
    final preview = actor.blueprintPreview;
    if (actor.blueprintClass != null && preview != null) {
      // A placed Blueprint: the actor's location and
      // rotation, as Play and the generated level construct it, then its
      // mesh component's offset inside the class.
      return blueprintActorMatrix(actor)
        ..multiply(preview.meshRelative)
        ..multiply(Matrix4.diagonal3Values(u, u, u));
    }
    return actorMatrix(actor)..multiply(Matrix4.diagonal3Values(u, u, u));
  }

  /// A placed Blueprint's actor transform: location and rotation only
  /// (lumina constructs placed Blueprints without a scale).
  static Matrix4 blueprintActorMatrix(EditorActorNode actor) =>
      Matrix4.compose(LuminaAxes.location(actor.location), LuminaAxes.rotation(actor.rotation), Vector3.all(1));
}
