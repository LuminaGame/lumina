import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';

/// One stored (Z-up, cm) transform lands at the same
/// world transform in the editor viewport and in Play-In-Editor.
void main() {
  test('a rotated, scaled actor sits at the same world transform in the viewport and in PIE', () {
    final actor = EditorActorNode(
      id: 'marker',
      name: 'Marker',
      type: 'Camera',
      location: [400.0, 0.0, 60.0],
      rotation: [0.0, 0.0, 90.0],
      scale: [1.0, 2.0, 3.0],
    );
    final viewport = EditorTransforms.actorMatrix(actor);
    final pie = EditorPieGame.mapEditorActor(actor)! as LuminaActor;
    final runtime = pie.rootComponent.worldTransform;
    for (var i = 0; i < 16; i++) {
      expect(runtime.storage[i], closeTo(viewport.storage[i], 1e-9), reason: 'element $i');
    }
    expect(pie.rootComponent.worldLocation, Vector3(400, 60, 0), reason: 'Z is up in the editor, Y in the runtime');
  });

  test('a PIE mesh actor draws its glTF ×100 like the viewport; a primitive is already in cm', () {
    final mesh = EditorActorNode(id: 'rock', name: 'Rock', type: 'StaticMesh', location: [0.0, 0.0, 0.0], meshAssetPath: '/tmp/rock.glb');
    final prim = EditorActorNode(id: 'box', name: 'Box', type: 'Primitive', location: [0.0, 0.0, 0.0]);
    expect(EditorTransforms.assetUnitScaleFor(mesh), LuminaUnits.unitsPerMetre);
    expect(EditorTransforms.assetUnitScaleFor(prim), 1.0);
    final root = (EditorPieGame.mapEditorActor(mesh)! as LuminaActor).rootComponent as LuminaStaticMeshComponent;
    expect(root.assetUnitScale, LuminaUnits.unitsPerMetre);
  });
}
