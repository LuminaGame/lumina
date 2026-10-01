import 'package:lumina/lumina.dart' show LuminaCameraSettings;

import '../../details/models/editor_component_node.dart';
import '../view_models/editor_view_model.dart';

/// A placed `Camera` actor's settings live on its `LuminaCameraComponent`
/// (`<actorId>_camera`), under the names and units
/// [LuminaCameraSettings] reads: the Details panel's Camera section, Play
/// (`EditorPieGame.mapEditorActor`), the code generator, the Sequencer camera
/// lock and MCP all go through them.
class CameraActorProperties {
  const CameraActorProperties._();

  static const String componentType = LuminaCameraSettings.componentType;

  /// Whether [actor] is a placed camera (not a Blueprint).
  static bool isCameraActor(EditorActorNode actor) => actor.type == 'Camera' && actor.blueprintClass == null;

  /// The camera component of [actor], if it has one.
  static EditorComponentNode? componentOf(EditorActorNode actor) {
    for (final c in actor.components) {
      if (c.type == componentType) return c;
    }
    return null;
  }

  /// The component a freshly placed camera starts with: the runtime camera's
  /// defaults.
  static EditorComponentNode seedComponent(String actorId) => EditorComponentNode(
        id: '${actorId}_camera',
        type: componentType,
        name: 'Camera',
        properties: const LuminaCameraSettings().toProperties(),
      );

  /// Gives a camera from an older level (no component) its
  /// component with the defaults. Returns it, existing or new; null for other
  /// actors.
  static EditorComponentNode? ensureComponent(EditorActorNode actor) {
    if (!isCameraActor(actor)) return null;
    final existing = componentOf(actor);
    if (existing != null) return existing;
    final seeded = seedComponent(actor.id);
    actor.components.add(seeded);
    return seeded;
  }

  /// [actor]'s settings as every consumer sees them.
  static LuminaCameraSettings read(EditorActorNode actor) =>
      LuminaCameraSettings.fromProperties(componentOf(actor)?.properties);
}
