import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/scaffold_game_project.dart';

/// The Blueprint editor's 3D Viewport preview, in a world without a
/// renderer: the actor is built the way Play builds it (lumina's component
/// construction, `LuminaAxes`, the project's asset resolver and Anim Class),
/// its overlays are where its components are, and selection highlights one.
void main() {
  late Directory root;
  late String dir;
  late LuminaBlueprintDocument character;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp_preview_scene_');
    dir = await scaffoldGameProject(root, name: 'bp_preview_scene', widgetLibrary: 'flutter');
    final vm = BlueprintEditorViewModel(assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}');
    await vm.load();
    character = LuminaBlueprintDocument.fromJson(vm.document.toJson());
    vm.dispose();
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  const halfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
  const radius = LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius;

  test('BP_ThirdPersonCharacter is built as Play builds it: Quinn through its .entity.glb, at its relative transform, idling', () {
    final scene = BlueprintPreviewScene()..setDocument(character, projectDir: dir);
    addTearDown(scene.dispose);
    scene.attachHeadless();

    expect(scene.actor, isA<LuminaCharacter>());
    final mesh = scene.componentFor('mesh') as LuminaAnimatedMeshComponent;
    expect(mesh.meshAssetPath, '$dir/${LuminaThirdPersonContent.projectMeshGlbPath}');
    // Authoring (0, 0, -90) cm, Z up → runtime (0, -90, 0), Y up (LuminaAxes).
    expect(mesh.worldLocation.x, closeTo(0, 1e-9));
    expect(mesh.worldLocation.y, closeTo(-halfHeight, 1e-9));
    expect(mesh.worldLocation.z, closeTo(0, 1e-9));

    final anim = scene.animInstanceFor('mesh')!;
    for (var i = 0; i < 30; i++) {
      scene.advance(BlueprintPreviewScene.tickSeconds);
    }
    expect(anim.currentState, 'Idle', reason: 'a pawn standing still idles');
    expect(mesh.currentClip, LuminaThirdPersonContent.idleClip);
    expect(scene.summary, contains('ABP_Character Idle'));

    // Nothing looks through the Blueprint's camera in the editor.
    final camera = scene.componentFor('camera') as LuminaCameraComponent;
    expect(camera.isActive, isFalse);
    expect(scene.world!.activeCamera, isNull);
  });

  test('the capsule, the spring arm and the camera are drawn where Play puts them', () {
    final scene = BlueprintPreviewScene()..setDocument(character, projectDir: dir);
    addTearDown(scene.dispose);
    final byId = {for (final s in scene.overlays) s.id: s};
    expect(byId.keys, containsAll(['capsule', 'boom', 'camera']));
    expect(byId.keys, isNot(contains('mesh')), reason: 'the mesh draws itself; its box only when selected');

    List<Vector3> points(String id) {
      final p = byId[id]!.positions;
      return [for (var i = 0; i < p.length; i += 3) Vector3(p[i], p[i + 1], p[i + 2])];
    }

    // The capsule: 35 cm radius, 90 cm half height, centred on the actor.
    final capsule = points('capsule');
    expect(capsule.map((p) => p.y).reduce((a, b) => a > b ? a : b), closeTo(halfHeight, 1e-6));
    expect(capsule.map((p) => p.y).reduce((a, b) => a < b ? a : b), closeTo(-halfHeight, 1e-6));
    expect(capsule.map((p) => p.x.abs()).reduce((a, b) => a > b ? a : b), closeTo(radius, 1e-6));

    // The boom: from 60 cm above the actor origin to 350 cm behind it (+Z,
    // the actor faces −Z), where the camera sits.
    final boom = points('boom');
    expect(boom[0].y, closeTo(LuminaTemplateCharacterTuning.boomHeight, 1e-6));
    expect(boom[1].z, closeTo(LuminaTemplateCharacterTuning.boomLength, 1e-6));
    final camera = scene.componentFor('camera') as LuminaCameraComponent;
    expect((camera.worldLocation - boom[1]).length, lessThan(1e-6), reason: 'the camera is at the boom socket');
    expect(points('camera').first, camera.worldLocation, reason: 'the frustum starts at the camera');
    expect(camera.forwardVector.z, lessThan(-0.99), reason: 'and looks along the actor forward');

    // Framed on the body: centred on the capsule, which fills a good part
    // of the 45° view, from far enough to keep the camera in front of the eye.
    final framing = scene.framing;
    expect(framing.target.length, lessThan(1e-6), reason: 'the capsule is centred on the actor');
    expect(framing.distance, inInclusiveRange(2 * halfHeight, 8 * halfHeight));
    expect((camera.worldLocation - framing.target).length, lessThan(framing.distance));
  });

  test('selecting a component highlights it, in front of the mesh', () {
    final scene = BlueprintPreviewScene()..setDocument(character, projectDir: dir);
    addTearDown(scene.dispose);
    scene.select('boom');
    final boom = scene.overlays.firstWhere((s) => s.id == 'boom');
    expect(boom.selected, isTrue);
    expect(boom.xray, isTrue);
    expect((boom.r, boom.g, boom.b), BlueprintPreviewScene.selectionColor);
    final capsule = scene.overlays.firstWhere((s) => s.id == 'capsule');
    expect(capsule.selected, isFalse);
    expect((capsule.r, capsule.g, capsule.b), BlueprintPreviewScene.capsuleColor);
    scene.select('capsule');
    expect({for (final s in scene.overlays) if (s.selected) s.id}, {'capsule'});
  });

  test('editing a component rebuilds the preview; an event graph edit does not', () {
    final scene = BlueprintPreviewScene()..setDocument(character, projectDir: dir);
    addTearDown(scene.dispose);
    scene.attachHeadless();
    final revision = scene.revision;
    final doc = LuminaBlueprintDocument.fromJson(character.toJson());
    doc.eventGraph.nodes.removeLast();
    scene.setDocument(doc, projectDir: dir);
    expect(scene.revision, revision, reason: 'the graph does not change what the viewport draws');

    doc.components.firstWhere((c) => c.id == 'mesh').properties['location'] = [0.0, 50.0, -90.0];
    scene.setDocument(doc, projectDir: dir);
    expect(scene.revision, greaterThan(revision));
    final mesh = scene.componentFor('mesh') as LuminaSceneComponent;
    expect(mesh.worldLocation.z, closeTo(-50.0, 1e-9), reason: 'authoring +Y (right) is runtime −Z');
  });

  test('a Skeletal Mesh without an Animation Blueprint shows its reference pose, and says so', () {
    final doc = LuminaBlueprintDocument.fromJson(character.toJson());
    doc.components.firstWhere((c) => c.id == 'mesh').properties
      ..['animMode'] = 'Use Animation Asset'
      ..remove('animClass');
    final scene = BlueprintPreviewScene()..setDocument(doc, projectDir: dir);
    addTearDown(scene.dispose);
    scene.attachHeadless();
    expect(scene.animInstanceFor('mesh'), isNull);
    expect(scene.summary, contains('reference pose'));
  });

  test("the editor's default Character keeps its arrow, drawn in its colour", () {
    final doc = BlueprintEditorViewModel.createDefaultDocument('BP_Default');
    final scene = BlueprintPreviewScene()..setDocument(doc, projectDir: dir);
    addTearDown(scene.dispose);
    final arrow = scene.overlays.firstWhere((s) => s.id == 'arrow_comp');
    expect(arrow.b, closeTo(1.0, 1e-9));
    expect(arrow.r, closeTo(0.0, 1e-9));
  });

  test('the Blueprint editor keeps its preview on the document and the Components selection', () async {
    final vm = BlueprintEditorViewModel(assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}');
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.preview.componentFor('mesh'), isA<LuminaAnimatedMeshComponent>());
    vm.selectComponent('camera');
    expect(vm.preview.selected, 'camera');
    vm.setProperty('boom', 'targetArmLength', 500.0);
    final boom = vm.preview.componentFor('boom') as LuminaSpringArmComponent;
    expect(boom.targetArmLength, 500.0, reason: 'the preview follows the edit');
    vm.undo();
    expect((vm.preview.componentFor('boom') as LuminaSpringArmComponent).targetArmLength,
        LuminaTemplateCharacterTuning.boomLength, reason: 'and its undo');
  });
  test("a Static Mesh component's Material Override is read from the project folder, before any Play", () async {
    // Play sets LuminaAssets.projectDir; the editor's preview must not need it.
    expect(LuminaAssets.projectDir, isNull);
    const material = LuminaThirdPersonContent.characterBlueprintPath;
    final doc = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'barrel',
          'name': 'Barrel',
          'type': 'LuminaStaticMeshComponent',
          'properties': {'staticMeshAsset': 'contents/meshes/static/SM_Barrel.lmas', 'materialOverride': material},
        },
      ],
    });
    final scene = BlueprintPreviewScene()..setDocument(doc, projectDir: dir);
    addTearDown(scene.dispose);
    scene.attachHeadless();
    final mesh = scene.componentFor('barrel') as LuminaStaticMeshComponent;
    expect(mesh.materialOverrideAsset, material);
    final read = LuminaAssets.resolve(mesh.assetProvider);
    expect(await read(material), File('$dir/$material').readAsBytesSync(), reason: 'contents/… is the project folder');
    final absolute = '$dir/$material';
    expect(await read(absolute), File(absolute).readAsBytesSync(), reason: 'an absolute path is read as it is');
  });

  test('a Spot Light component produces cone wireframe overlay with inner and outer cone rays', () {
    final doc = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'root',
          'name': 'DefaultSceneRoot',
          'type': 'LuminaSceneComponent',
        },
        {
          'id': 'spot',
          'name': 'SpotLight',
          'type': 'LuminaSpotLightComponent',
          'parentId': 'root',
          'properties': {
            'location': [0.0, 0.0, 100.0],
            'intensity': 50000.0,
            'attenuationRadius': 800.0,
            'innerConeAngle': 25.0,
            'outerConeAngle': 45.0,
          },
        },
      ],
    });
    final scene = BlueprintPreviewScene()..setDocument(doc, projectDir: dir);
    addTearDown(scene.dispose);
    final byId = {for (final s in scene.overlays) s.id: s};
    expect(byId.containsKey('spot'), isTrue);
    final spotOverlay = byId['spot']!;
    expect(spotOverlay.positions.isNotEmpty, isTrue);
    expect(spotOverlay.positions.length % 6, equals(0)); // 3 floats per vertex, 2 vertices per line segment
    expect((spotOverlay.r, spotOverlay.g, spotOverlay.b), BlueprintPreviewScene.spotLightColor);

    // When selected, it uses selection color
    scene.select('spot');
    final selectedSpot = scene.overlays.firstWhere((s) => s.id == 'spot');
    expect(selectedSpot.selected, isTrue);
    expect((selectedSpot.r, selectedSpot.g, selectedSpot.b), BlueprintPreviewScene.selectionColor);
  });

  test('a Point Light component produces sphere wireframe overlay', () {
    final doc = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'point',
          'name': 'PointLight',
          'type': 'LuminaPointLightComponent',
          'properties': {
            'attenuationRadius': 500.0,
          },
        },
      ],
    });
    final scene = BlueprintPreviewScene()..setDocument(doc, projectDir: dir);
    addTearDown(scene.dispose);
    final byId = {for (final s in scene.overlays) s.id: s};
    expect(byId.containsKey('point'), isTrue);
    final pointOverlay = byId['point']!;
    expect(pointOverlay.positions.isNotEmpty, isTrue);
    expect((pointOverlay.r, pointOverlay.g, pointOverlay.b), BlueprintPreviewScene.pointLightColor);
  });

  test('hasSceneLights and renderSceneLights control environment lighting', () {
    final docNoLight = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'root',
          'name': 'DefaultSceneRoot',
          'type': 'LuminaSceneComponent',
        },
      ],
    });
    final sceneNoLight = BlueprintPreviewScene()..setDocument(docNoLight, projectDir: dir);
    addTearDown(sceneNoLight.dispose);
    expect(sceneNoLight.hasSceneLights, isFalse);

    final docWithLight = LuminaBlueprintDocument.fromJson({
      'parentClass': 'LuminaActor',
      'components': [
        {
          'id': 'root',
          'name': 'DefaultSceneRoot',
          'type': 'LuminaSceneComponent',
        },
        {
          'id': 'spot',
          'name': 'SpotLight',
          'type': 'SpotLightComponent',
          'parentId': 'root',
          'properties': {
            'intensity': 50000.0,
          },
        },
      ],
    });
    final scene = BlueprintPreviewScene()..setDocument(docWithLight, projectDir: dir);
    addTearDown(scene.dispose);
    expect(scene.hasSceneLights, isTrue);
    expect(scene.renderSceneLights, isFalse);

    scene.setRenderSceneLights(true);
    expect(scene.renderSceneLights, isTrue);

    scene.toggleRenderSceneLights();
    expect(scene.renderSceneLights, isFalse);
  });
}

