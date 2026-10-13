import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A placed skeletal mesh's Mesh Component Details reach Play: Slot and
/// Pose From (another skeletal mesh actor, never itself or one already
/// following it), Cast Shadow; Play builds an animated mesh that follows
/// the chosen actor's pose and holds its slot.
void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_level_skm_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  EditorViewModel vm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'LevelSkm'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  EditorActorNode skeletal(String id, String name) => EditorActorNode(
        id: id,
        name: name,
        type: 'SkeletalMesh',
        location: [0, 0, 0],
        meshAssetPath: 'contents/meshes/skeletal/$name.lmas',
      )..components.add(EditorComponentNode(id: '${id}_mesh', type: 'LuminaSkeletalMeshComponent', name: 'Mesh Component', properties: {}));

  testWidgets('the Details panel edits Slot and Pose From; Pose From offers no cycle', (tester) async {
    final model = vm();
    addTearDown(model.dispose);
    final body = skeletal('body_1', 'Body'), hair = skeletal('hair_1', 'Hair');
    model.addActorNodes([body, hair]);
    model.selectActorById(hair.id);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: model))));
    await tester.pumpAndSettle();
    expect(find.text('Slot', skipOffstage: false), findsWidgets);
    expect(find.text('Pose From', skipOffstage: false), findsWidgets);

    final slot = find.descendant(of: find.byKey(const ValueKey('details_text_hair_1_mesh_slot')), matching: find.byType(EditableText));
    await tester.enterText(slot, 'Hair');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(hair.components.single.properties['slot'], 'Hair');

    await tester.tap(find.byKey(const ValueKey('details_actor_ref_hair_1_mesh_poseFrom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Body').last);
    await tester.pumpAndSettle();
    expect(hair.components.single.properties['poseFrom'], 'body_1');

    // The body cannot follow its own follower.
    model.selectActorById(body.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('details_actor_ref_body_1_mesh_poseFrom')));
    await tester.pumpAndSettle();
    final labels = [
      for (final e in find.descendant(of: find.byType(SelectItemButton<String>), matching: find.byType(Text)).evaluate()) (e.widget as Text).data,
    ];
    expect(labels, ['None']);
    await tester.pumpWidget(const SizedBox());
  });

  test('Play builds the follower as an animated mesh following the chosen actor, with its slot and cast shadow', () {
    final body = skeletal('body_1', 'Body'), hair = skeletal('hair_1', 'Hair');
    hair.components.single.properties.addAll({'slot': 'Hair', 'poseFrom': 'body_1', 'castShadow': false});
    final game = EditorPieGame([body, hair]);
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    game.mountIntoWorldForTest(world);
    world.tick(1 / 60);
    final bodyActor = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('body_1'));
    final hairActor = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('hair_1'));
    final bodyMesh = bodyActor.rootComponent as LuminaAnimatedMeshComponent;
    final hairMesh = hairActor.rootComponent as LuminaAnimatedMeshComponent;
    expect(hairMesh.poseLeader, same(bodyMesh));
    expect(hairMesh.castShadows, isFalse);
    expect(bodyMesh.castShadows, isTrue);
    expect(LuminaCharacterSlots.of(hairActor).names, ['Hair']);
    expect(LuminaCharacterSlots.of(hairActor).component('Hair'), same(hairMesh));
  });

  test("Play runs the Anim Class the mesh's Details name, through the project's Blueprint registry", () {
    void write(String path, String name, AssetType type, Map<String, dynamic> payload) => File('${tempDir.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(
          LuminaAsset(assetId: name, name: name, type: type, rawPayload: utf8.encode(jsonEncode(payload))).toProtoBufferBytes());
    write(LuminaThirdPersonContent.projectAnimBlueprintPath, 'ABP_Character', AssetType.animBlueprint,
        LuminaThirdPersonContent.animBlueprint.toJson());
    write(LuminaThirdPersonContent.projectWalkBlendSpacePath, 'BS_Walk', AssetType.blendSpace,
        LuminaThirdPersonContent.walkBlendSpace.toJson());
    write(LuminaThirdPersonContent.projectLocomotionBlendSpacePath, 'BS_Locomotion', AssetType.blendSpace,
        LuminaThirdPersonContent.locomotionBlendSpace.toJson());
    final body = skeletal('body_1', 'Body'), still = skeletal('still_1', 'Still');
    body.components.single.properties['animClass'] = {
      'slot_name': 'animClass',
      'asset_id': 'ABP_Character',
      'asset_path': LuminaThirdPersonContent.projectAnimBlueprintPath,
    };
    final game = EditorPieGame([body, still], registry: EditorBlueprintClassRegistry(tempDir.path, inputActions: const []));
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    game.mountIntoWorldForTest(world);
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    LuminaActor actor(String id) => world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(id));
    final anim = actor('body_1').components.whereType<LuminaAnimBlueprintInstance>().single;
    expect(anim.mesh, same(actor('body_1').rootComponent));
    expect(anim.currentState, isNotNull);
    expect((actor('body_1').rootComponent as LuminaAnimatedMeshComponent).currentClip, isNotNull);
    expect(actor('still_1').components.whereType<LuminaAnimBlueprintInstance>(), isEmpty);
  });

  test('Play gives placed meshes their Details draw distances in cm; the Details offer no Volumetric Shadow', () {
    final far = skeletal('far_1', 'Far');
    far.components.single.properties.addAll({'minDrawDistance': 1.5, 'maxDrawDistance': 40.0});
    final rock = EditorActorNode(id: 'rock_1', name: 'Rock', type: 'StaticMesh', location: [0, 0, 0], meshAssetPath: 'contents/meshes/Rock.lmas')
      ..components.add(EditorComponentNode(id: 'rock_1_mesh', type: 'LuminaMeshComponent', name: 'Mesh Component', properties: {'maxDrawDistance': 12.0}));
    final plain = skeletal('plain_1', 'Plain');
    final game = EditorPieGame([far, rock, plain]);
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    game.mountIntoWorldForTest(world);
    LuminaStaticMeshComponent meshOf(String id) =>
        world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(id)).components.whereType<LuminaStaticMeshComponent>().first;
    expect([meshOf('far_1').minDrawDistance, meshOf('far_1').maxDrawDistance], [150.0, 4000.0]);
    expect(meshOf('rock_1').maxDrawDistance, 1200.0);
    expect([meshOf('plain_1').minDrawDistance, meshOf('plain_1').maxDrawDistance], [0.0, 0.0]);
    for (final type in ['LuminaSkeletalMeshComponent', 'LuminaMeshComponent']) {
      final ids = ComponentPropertyRegistry.descriptors[type]!.properties.map((p) => p.id);
      expect(ids, containsAll(['minDrawDistance', 'maxDrawDistance']));
      expect(ids, isNot(contains('volumetricShadow')), reason: 'no fog in the renderer is shadowed by geometry');
    }
  });
}
