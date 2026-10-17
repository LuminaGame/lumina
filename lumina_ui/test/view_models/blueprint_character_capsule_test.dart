import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

/// A Character Blueprint's capsule is the character's own capsule, centred
/// on the actor in Play: its authored transform does nothing, so the editor
/// does not offer one, and the preview stands the capsule on the floor with
/// the meshes placed relative to it.
void main() {
  LuminaBlueprintDocument metaHuman({List<double> capsuleLocation = const [0.0, 0.0, 70.0]}) =>
      LuminaBlueprintDocument(parentClass: 'LuminaCharacter', components: [
        LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
          id: 'capsule',
          name: 'CapsuleComponent',
          type: 'LuminaCapsuleComponent',
          parentId: 'root',
          properties: {'location': capsuleLocation, 'capsuleRadius': 40.0, 'capsuleHalfHeight': 88.0},
        ),
        LuminaBlueprintComponent(
          id: 'body',
          name: 'Body',
          type: 'LuminaSceneComponent',
          parentId: 'capsule',
          properties: {'location': [0.0, 0.0, -88.0]},
        ),
      ]);

  test("a Character's capsule cannot be moved by the gizmo and says why; an Actor's capsule can", () {
    final vm = BlueprintEditorViewModel(
      assetPath: 'contents/blueprints/BP_MH_1.lmas',
      initialAsset: LuminaAsset(assetId: 'BP_MH_1', name: 'BP_MH_1', type: AssetType.actor),
    );
    addTearDown(vm.dispose);
    vm.document.parentClass = 'LuminaCharacter';
    final root = vm.addComponent('LuminaSceneComponent')!;
    final capsule = vm.addComponent('LuminaCapsuleComponent', parentId: root.id)!;
    final arm = vm.addComponent('LuminaSpringArmComponent', parentId: capsule.id)!;
    expect(vm.isCharacterCapsule(capsule.id), isTrue);
    expect(vm.canTransformComponent(capsule.id), isFalse);
    expect(vm.transformLockReason(capsule.id), contains("Character's capsule is centred"));
    expect(vm.canTransformComponent(arm.id), isTrue);
    expect(vm.transformLockReason(arm.id), isNull);
    vm.updateComponentTransform(capsule.id, location: [0.0, 0.0, 70.0]);
    expect(capsule.properties['location'], isNot([0.0, 0.0, 70.0]));

    vm.document.parentClass = 'LuminaActor';
    expect(vm.isCharacterCapsule(capsule.id), isFalse);
    expect(vm.canTransformComponent(capsule.id), isTrue);
  });

  test('the preview stands the capsule on the floor whatever location it was given, and a body at −half height on it', () {
    final scene = BlueprintPreviewScene()..setDocument(metaHuman());
    addTearDown(scene.dispose);
    scene.attachHeadless();
    final capsule = scene.componentFor('capsule') as LuminaCollisionComponent;
    expect(capsule.getAABB().min.y, closeTo(0, 1e-6), reason: 'the capsule bottom is on the floor');
    final body = scene.componentFor('body') as LuminaSceneComponent;
    expect(body.worldLocation.y, closeTo(0, 1e-6), reason: 'a body at −half height has its feet on the floor');
  });
}
