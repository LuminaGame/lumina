// A placed skeletal mesh's Anim Class (Mesh Component Details) plays in the
// generated game: the level generator compiles the Animation Blueprint into
// lib/anim/ first (async file I/O) and the level builds the mesh with the
// compiled class, which animates it as the Blueprint VM does in Play.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/anim_blueprints.dart';
import '../../../lumina/test/blueprint/generated/abp_character.g.dart';

void main() {
  late Directory project;
  setUp(() => project = Directory.systemTemp.createTempSync('lumina_lvl_abp_'));
  tearDown(() => project.deleteSync(recursive: true));

  void writeAsset(String path, String name, AssetType type, Map<String, dynamic> payload) {
    File('${project.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(
          LuminaAsset(assetId: name, name: name, type: type, rawPayload: utf8.encode(jsonEncode(payload))).toProtoBufferBytes());
  }

  void writeTemplateAnimBlueprint() {
    writeAsset(LuminaThirdPersonContent.projectAnimBlueprintPath, 'ABP_Character', AssetType.animBlueprint,
        LuminaThirdPersonContent.animBlueprint.toJson());
    writeAsset(LuminaThirdPersonContent.projectWalkBlendSpacePath, 'BS_Walk', AssetType.blendSpace,
        LuminaThirdPersonContent.walkBlendSpace.toJson());
    writeAsset(LuminaThirdPersonContent.projectLocomotionBlendSpacePath, 'BS_Locomotion', AssetType.blendSpace,
        LuminaThirdPersonContent.locomotionBlendSpace.toJson());
  }

  Map<String, dynamic> skeletal(String id, Object? animClass) => {
        'id': id,
        'name': id,
        'type': 'SkeletalMesh',
        'location': [0.0, 0.0, 0.0],
        'meshAssetPath': 'contents/Characters/Manny.lmas',
        'components': [
          {
            'id': '${id}_mesh',
            'type': 'LuminaSkeletalMeshComponent',
            'name': 'Mesh Component',
            'properties': {'animClass': animClass},
          },
        ],
      };

  test('the level generator compiles the Anim Class into lib/anim and the level plays it; a missing one is noted', () async {
    writeTemplateAnimBlueprint();
    const missing = 'contents/animations/Gone/ABP_Gone.lmas';
    final code = await DartCodeGeneratorService().generateLevelDartAsync(
      levelName: 'L_Anim',
      actors: const [],
      actorMaps: [
        // The Details' asset reference, as the asset picker stores it.
        skeletal('mh_1', {'slot_name': 'animClass', 'asset_id': 'ABP_Character', 'asset_path': LuminaThirdPersonContent.projectAnimBlueprintPath}),
        skeletal('mh_2', missing),
        skeletal('mh_3', null),
      ],
      projectDir: project.path,
    );
    final anim = File('${project.path}/lib/anim/abp_character.dart');
    expect(await anim.exists(), isTrue);
    expect(await anim.readAsString(), File('../lumina/test/blueprint/generated/abp_character.g.dart').readAsStringSync(),
        reason: 'the class the level plays is the committed golden the parity run below uses');
    expect(code, contains("import '../anim/abp_character.dart';"));
    final lines = code.split('\n');
    String line(String id) => lines.firstWhere((l) => l.contains("LuminaObjectKey('$id')"));
    expect(line('mh_1'), endsWith(', animBlueprint: AbpCharacter.create),'));
    expect(line('mh_2'), isNot(contains('animBlueprint:')));
    expect(code, contains("// Anim Class '$missing' is not compiled (missing or has errors): the mesh plays no animation."));
    expect(line('mh_3'), isNot(contains('animBlueprint:')));
    expect(await File('${project.path}/lib/anim/abp_gone.dart').exists(), isFalse);

    // The synchronous generator, without the compile step, plays none.
    final plain = DartCodeGeneratorService()
        .generateLevelDart(levelName: 'L_Anim', actors: const [], actorMaps: [skeletal('mh_1', LuminaThirdPersonContent.projectAnimBlueprintPath)]);
    expect(plain, isNot(contains('animBlueprint:')));
  });

  test('an Anim Class that does not compile (a blend space missing) leaves the mesh without one', () async {
    writeAsset(LuminaThirdPersonContent.projectAnimBlueprintPath, 'ABP_Character', AssetType.animBlueprint,
        LuminaThirdPersonContent.animBlueprint.toJson());
    final refs = await DartCodeGeneratorService()
        .compileLevelAnimBlueprints(project.path, [skeletal('mh_1', LuminaThirdPersonContent.projectAnimBlueprintPath)]);
    expect(refs, isEmpty);
    expect(await File('${project.path}/lib/anim/abp_character.dart').exists(), isFalse);
  });

  test('the Anim Class path comes from an asset reference or a path; None and non-assets are none', () {
    const path = 'contents/animations/ABP_X.lmas';
    expect(LuminaLevelSkeletalMesh.animClassPath({'animClass': path}), path);
    expect(LuminaLevelSkeletalMesh.animClassPath({'animClass': {'asset_path': path}}), path);
    expect(LuminaLevelSkeletalMesh.animClassPath({'animClass': r'C:\Proj\contents\animations\ABP_X.lmas'}), path);
    expect(LuminaLevelSkeletalMesh.animClassPath({'animClass': 'None'}), isNull);
    expect(LuminaLevelSkeletalMesh.animClassPath({'animClass': {'asset_path': ''}}), isNull);
    expect(LuminaLevelSkeletalMesh.animClassPath({}), isNull);
  });

  test('a placed skeletal mesh animates the same with the VM class (Play) and the compiled one (game)', () {
    ({LuminaAnimBlueprintInstance anim, LuminaAnimatedMeshComponent mesh, List<LuminaBlueprintTraceEvent> trace, List<String?> clips})
        run(LuminaAnimBlueprintFactory factory) {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      addTearDown(world.cleanup);
      final actor = LuminaLevelSkeletalMesh.build(
          key: const LuminaObjectKey('mh_1'), meshAssetPath: 'never_loaded.glb', animBlueprint: factory);
      final anim = actor.components.whereType<LuminaAnimBlueprintInstance>().single;
      final mesh = actor.rootComponent as LuminaAnimatedMeshComponent;
      expect(anim.mesh, same(mesh));
      // Random clips (idle breaks) pick the same in both runs.
      anim.random = math.Random(3);
      final trace = <LuminaBlueprintTraceEvent>[];
      anim.trace = trace.add;
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      final clips = <String?>[];
      for (var frame = 0; frame < 600; frame++) {
        world.tick(1 / 60);
        clips.add(mesh.currentClip);
      }
      return (anim: anim, mesh: mesh, trace: trace, clips: clips);
    }

    final vm = run(templateAnimClass().factory);
    final gen = run(AbpCharacter.create);
    expect(gen.anim, isA<AbpCharacter>());
    expect(vm.trace.length, greaterThan(500), reason: 'the update graph ran every frame');
    expect(gen.trace.map((t) => (t.eventNodeId, t.nodeId)).toList(), vm.trace.map((t) => (t.eventNodeId, t.nodeId)).toList());
    expect(vm.clips.whereType<String>(), isNotEmpty, reason: 'the Anim Class picks the clip the mesh plays');
    expect(gen.clips, vm.clips);
    expect(gen.anim.currentState, vm.anim.currentState);
  });
}
