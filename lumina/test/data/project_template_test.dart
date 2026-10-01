import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/code_generator_service.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/src/game/template_content.dart';
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/lumina.dart' show LuminaBlueprintDocument, LuminaTemplateCharacterTuning;
import '../helpers/analyze_generated_project.dart';

/// A [ProcessRunner] that performs the real filesystem effects of the two
/// external commands the pipeline shells out to, without paying for a full
/// `flutter create` / network `pub get`. Everything it writes is real on-disk
/// content — no mock data, no stubbed manifest.
ProcessRunner realFilesystemRunner({List<String>? log, bool offlinePubGet = false}) {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    log?.add('$exec ${args.join(' ')}');
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final projectName = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      Directory('$target/test').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync('''
name: $projectName
description: A Lumina game.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  vector_math: ^2.1.4

flutter:
  uses-material-design: true
''');
      File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
      File('$target/analysis_options.yaml').writeAsStringSync('''
include: package:flutter_lints/flutter.yaml
''');
      return ProcessResult(0, 0, '', '');
    }
    if (args.isNotEmpty && args.first == 'pub') {
      if (offlinePubGet) {
        return Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: workingDirectory, runInShell: Platform.isWindows);
      }
      return ProcessResult(0, 0, '', '');
    }
    return ProcessResult(0, 0, '', '');
  };
}

Map<String, dynamic> readLevelActorsFile(String projectDir) {
  final file = File('$projectDir/contents/levels/L_DefaultLevel.lmas');
  expect(file.existsSync(), isTrue, reason: 'level .lmas must exist at ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

List<Map<String, dynamic>> readSeededActors(String projectDir) {
  final map = readLevelActorsFile(projectDir);
  final metadata = Map<String, dynamic>.from(map['metadata'] as Map);
  return (metadata['actors'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<String> createTemplateProject({
  required Directory root,
  required Directory configDir,
  required String name,
  required String template,
  bool offlinePubGet = false,
}) async {
  final repo = ProjectRepository(
    configDir: configDir,
    processRunner: realFilesystemRunner(offlinePubGet: offlinePubGet),
  );
  await repo.createProject(projectName: name, projectLocation: root.path, template: template);
  return '${root.path}/$name';
}

void main() {
  group('LuminaProject.template', () {
    test('round-trips through the .lmproject and defaults to blank_3d for older manifests', () {
      final tempDir = Directory.systemTemp.createTempSync('lumina_tpl_manifest_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      const project = LuminaProject(projectName: 'fp_game', template: kFirstPersonTemplateId);
      final file = File('${tempDir.path}/fp_game.lmproject');
      file.writeAsStringSync(jsonEncode(project.toMap()));

      final reloaded = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
      );
      expect(reloaded.template, kFirstPersonTemplateId);

      // A manifest written before templates existed has no `template` key.
      final legacyMap = Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map)
        ..remove('template');
      expect(LuminaProject.fromMap(legacyMap).template, kBlank3dTemplateId);

      expect(reloaded.copyWith(template: kThirdPersonTemplateId).template, kThirdPersonTemplateId);
    });
  });

  group('GameTemplateCatalog', () {
    test('exposes exactly the three templates and resolves unknown/legacy ids to blank 3D', () {
      expect(
        GameTemplateCatalog.all.map((t) => t.id).toList(),
        [kBlank3dTemplateId, kFirstPersonTemplateId, kThirdPersonTemplateId],
      );
      for (final t in GameTemplateCatalog.all) {
        expect(t.title.isNotEmpty, isTrue);
        expect(t.description.isNotEmpty, isTrue);
        expect(t.description.toLowerCase(), isNot(contains('pending')));
      }
      expect(GameTemplateCatalog.byId('Blank 3D').id, kBlank3dTemplateId);
      expect(GameTemplateCatalog.byId('nonsense').id, kBlank3dTemplateId);
      expect(GameTemplateCatalog.byId(null).id, kBlank3dTemplateId);
    });

    test('blank 3D keeps the editor starter actor set', () {
      final actors = GameTemplateCatalog.byId(kBlank3dTemplateId).levelActors;
      expect(actors.map((a) => a['name']).toList(), [
        'PlayerPawn_Default',
        'DirectionalLight_Sun',
        'SkyAtmosphere_Env',
        'StaticMesh_Rock_01',
      ]);
      expect(actors.first['type'], 'Pawn');
      expect(actors.first['location'], [-60.0, 40.0, 0.0]);
    });

    test('returns a fresh, independently mutable actor list on every read', () {
      final a = GameTemplateCatalog.byId(kFirstPersonTemplateId).levelActors;
      a.first['name'] = 'mutated';
      final b = GameTemplateCatalog.byId(kFirstPersonTemplateId).levelActors;
      expect(b.first['name'], isNot('mutated'));
    });
  });

  group('First Person scaffold', () {
    late Directory root;
    late Directory configDir;
    late String projectDir;

    setUpAll(() async {
      root = Directory.systemTemp.createTempSync('lumina_tpl_fp_');
      configDir = Directory.systemTemp.createTempSync('lumina_tpl_fp_cfg_');
      projectDir = await createTemplateProject(
        root: root,
        configDir: configDir,
        name: 'fp_probe',
        template: kFirstPersonTemplateId,
      );
    });

    tearDownAll(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });

    test('seeds metadata.actors with the template set, read back from disk', () {
      final actors = readSeededActors(projectDir);
      final types = actors.map((a) => a['type']).toSet();
      expect(types, contains('PlayerStart'));
      expect(types, contains('DirectionalLight'));
      expect(types, contains('Environment'));
      expect(types, contains('Primitive'));

      final floor = actors.firstWhere((a) => a['name'] == 'Floor');
      final mesh = (floor['components'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .firstWhere((c) => c['type'] == 'LuminaProceduralMeshComponent');
      expect(mesh['properties']['shape'], 'plane');

      final boxes = actors.where((a) => a['type'] == 'Primitive' && a['name'] != 'Floor');
      expect(boxes.length, greaterThanOrEqualTo(3), reason: 'a test room needs a few boxes');
    });

    test('manifest records the template, input actions and the generated game mode', () {
      final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(File('$projectDir/fp_probe.lmproject').readAsStringSync()) as Map,
        ),
      );
      expect(manifest.template, kFirstPersonTemplateId);
      expect(manifest.mapsAndModes.defaultGameMode, 'FpProbeGameMode');
      expect(manifest.mapsAndModes.gameDefaultMap, 'contents/levels/L_DefaultLevel.lmas');

      final actionNames = manifest.input.actions.map((a) => a.name).toList();
      expect(actionNames, containsAll(['IA_Move', 'IA_Look', 'IA_Jump']));
      expect(
        manifest.input.actions.firstWhere((a) => a.name == 'IA_Move').valueType,
        ProjectInputValueType.axis2D,
      );
      expect(
        manifest.input.actions.firstWhere((a) => a.name == 'IA_Jump').valueType,
        ProjectInputValueType.digital,
      );

      final gameplay = manifest.input.mappingContexts.firstWhere((c) => c.name == 'Gameplay');
      ProjectInputMapping byLabel(String label) =>
          gameplay.mappings.firstWhere((m) => m.keyLabel == label);

      expect(byLabel('W').axis, 'Y');
      expect(byLabel('W').scale, 1.0);
      expect(byLabel('S').axis, 'Y');
      expect(byLabel('S').scale, -1.0);
      expect(byLabel('A').axis, 'X');
      expect(byLabel('A').scale, -1.0);
      expect(byLabel('D').axis, 'X');
      expect(byLabel('D').scale, 1.0);
      expect(byLabel('W').action, 'IA_Move');
      expect(byLabel('Space').action, 'IA_Jump');
      expect(gameplay.mappings.where((m) => m.action == 'IA_Look').length, 2);
    });

    test('writes a user-owned character with a first-person camera and no spring arm', () {
      final character = File('$projectDir/lib/pawns/fp_probe_character.dart');
      expect(character.existsSync(), isTrue);
      final src = character.readAsStringSync();
      expect(src, contains('class FpProbeCharacter extends LuminaCharacter'));
      expect(src, contains('LuminaCameraComponent'));
      expect(src, contains('baseEyeHeight'));
      expect(src, isNot(contains('LuminaSpringArmComponent')));
      expect(src, contains('// BEGIN USER CODE'));
      expect(src, contains('// END USER CODE'));
      expect(src, contains('bindAction('));
      expect(src, contains('IA_Move'));
      expect(src, contains('IA_Look'));
      expect(src, contains('IA_Jump'));
      expect(src, isNot(contains('GENERATED CODE - DO NOT MODIFY')));
    });

    test('first person carries no mannequin content', () {
      expect(File('$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}').existsSync(), isFalse);
      expect(Directory('$projectDir/${LuminaThirdPersonContent.projectAnimationDir}').existsSync(), isFalse);
    });

    test('writes a user-owned game mode wired to the character', () {
      final gameMode = File('$projectDir/lib/game/fp_probe_game_mode.dart');
      expect(gameMode.existsSync(), isTrue);
      final src = gameMode.readAsStringSync();
      expect(src, contains('class FpProbeGameMode extends LuminaGameMode'));
      expect(src, contains('defaultPawnFactory: () => FpProbeCharacter()'));
      expect(src, contains('playerControllerFactory'));
      expect(src, contains('// BEGIN USER CODE'));
    });

    test('regenerating level/main code on save never rewrites the character or game mode', () {
      final character = File('$projectDir/lib/pawns/fp_probe_character.dart');
      final gameMode = File('$projectDir/lib/game/fp_probe_game_mode.dart');
      final characterBytes = character.readAsBytesSync();
      final gameModeBytes = gameMode.readAsBytesSync();

      // Exactly what the editor's saveLevelAndGenerateCode() does.
      final gen = DartCodeGeneratorService();
      File('$projectDir/lib/main.dart').writeAsStringSync(
        gen.generateMainDart(projectName: 'fp_probe', levelName: 'L_DefaultLevel'),
      );
      File('$projectDir/lib/levels/l_default_level.dart').writeAsStringSync(
        gen.generateLevelDart(
          levelName: 'L_DefaultLevel',
          actors: const [],
          actorMaps: readSeededActors(projectDir),
        ),
      );

      expect(character.readAsBytesSync(), characterBytes);
      expect(gameMode.readAsBytesSync(), gameModeBytes);
    });
  });

  group('Third Person scaffold', () {
    late Directory root;
    late Directory configDir;
    late String projectDir;

    setUpAll(() async {
      root = Directory.systemTemp.createTempSync('lumina_tpl_tp_');
      configDir = Directory.systemTemp.createTempSync('lumina_tpl_tp_cfg_');
      projectDir = await createTemplateProject(
        root: root,
        configDir: configDir,
        name: 'tp_probe',
        template: kThirdPersonTemplateId,
      );
    });

    tearDownAll(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });

    // The character, game mode and animation are Blueprints.
    LuminaBlueprintDocument blueprint(String path) => LuminaBlueprintDocument.fromJson(
        jsonDecode(utf8.decode(LuminaAsset.fromBytes(File('$projectDir/$path').readAsBytesSync()).rawPayload!))
            as Map<String, dynamic>);

    test('the character is BP_ThirdPersonCharacter: spring arm, camera, capsule, movement, Move/Look/Jump graph', () {
      final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/tp_probe.lmproject').readAsStringSync()) as Map),
      );
      expect(manifest.template, kThirdPersonTemplateId);
      expect(manifest.mapsAndModes.defaultGameMode, LuminaThirdPersonContent.gameModeBlueprintPath);
      expect(Directory('$projectDir/lib/pawns').existsSync(), isFalse, reason: 'no Dart character any more');
      expect(Directory('$projectDir/lib/game').existsSync(), isFalse, reason: 'no Dart game mode any more');

      final character = blueprint(LuminaThirdPersonContent.characterBlueprintPath);
      expect(character.parentClass, 'LuminaCharacter');
      final boom = character.components.firstWhere((c) => c.type == 'LuminaSpringArmComponent');
      expect(boom.properties['usePawnControlRotation'], isTrue);
      expect(boom.properties['doCollisionTest'], isTrue);
      expect(boom.properties['enableCameraLag'], isTrue);
      expect(boom.properties['targetArmLength'], LuminaTemplateCharacterTuning.boomLength);
      expect(character.components.where((c) => c.type == 'LuminaCameraComponent').single.parentId, boom.id);
      // Compiled as Play compiles it: the manifest's input actions, the Anim
      // Class and its blend space read from the project.
      final cls = LuminaBlueprintClassRegistry(projectDir).classFor(LuminaThirdPersonContent.characterBlueprintPath)!;
      expect(cls.diagnostics, isEmpty, reason: 'validates against the manifest input: ${cls.diagnostics}');

      final mode = blueprint(LuminaThirdPersonContent.gameModeBlueprintPath);
      expect(mode.parentClass, 'LuminaGameMode');
      expect(mode.classDefaults['defaultPawnClass'], LuminaThirdPersonContent.characterBlueprintPath);

      for (final file in [
        'lib/actors/bp_third_person_character.dart',
        'lib/actors/bp_third_person_game_mode.dart',
        'lib/actors/actors.g.dart',
        'lib/anim/abp_character.dart',
        'lib/input/project_input.g.dart',
      ]) {
        expect(File('$projectDir/$file').existsSync(), isTrue, reason: file);
      }
      final main = File('$projectDir/lib/main.dart').readAsStringSync();
      expect(main, contains("luminaGameModeFactories['${LuminaThirdPersonContent.gameModeBlueprintPath}']!()"));
      expect(main, contains('luminaAddProjectInput('));
    });

    test('the manifest binds IA_Sprint to Left Shift and IA_Dash to Left Ctrl (+ gamepad); project_input.g.dart maps all four', () {
      final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/tp_probe.lmproject').readAsStringSync()) as Map),
      );
      for (final name in ['IA_Sprint', 'IA_Dash']) {
        expect(manifest.input.actions.firstWhere((a) => a.name == name).valueType, ProjectInputValueType.digital);
      }
      final gameplay = manifest.input.mappingContexts.firstWhere((c) => c.name == 'Gameplay');
      final sprintKeys = gameplay.mappings.where((m) => m.action == 'IA_Sprint').toList();
      final dashKeys = gameplay.mappings.where((m) => m.action == 'IA_Dash').toList();
      expect(sprintKeys.map((m) => m.keyLabel), ['Left Shift', 'Gamepad Left Thumbstick']);
      expect(sprintKeys.first.keyId, kKeyIdShiftLeft);
      expect(dashKeys.map((m) => m.keyLabel), ['Left Ctrl', 'Gamepad Face Button Right']);
      expect(dashKeys.first.keyId, kKeyIdControlLeft);
      // The generated input file (compiled by the scaffold's analyze run below) binds the same keys.
      final input = File('$projectDir/lib/input/project_input.g.dart').readAsStringSync();
      expect(input, contains("'IA_Sprint': LuminaInputAction('IA_Sprint', valueType: InputValueType.digitalBool)"));
      expect(input, contains("'IA_Dash': LuminaInputAction('IA_Dash', valueType: InputValueType.digitalBool)"));
      expect(input, contains("mapKey(LuminaKey.keyLeftShift, luminaProjectInputActions['IA_Sprint']!)"));
      expect(input, contains("mapKey(LuminaKey.gamepadLeftThumbstick, luminaProjectInputActions['IA_Sprint']!)"));
      expect(input, contains("mapKey(LuminaKey.keyLeftControl, luminaProjectInputActions['IA_Dash']!)"));
      expect(input, contains("mapKey(LuminaKey.gamepadFaceButtonRight, luminaProjectInputActions['IA_Dash']!)"));
      expect(input, isNot(contains('Unbound')));
      // The character Blueprint sprints and dashes on them.
      final character = blueprint(LuminaThirdPersonContent.characterBlueprintPath);
      expect(character.eventGraph.nodes.map((n) => n.literals['action']), containsAll(['IA_Sprint', 'IA_Dash']));
      expect(character.eventGraph.nodes.map((n) => n.registryId),
          containsAll(['set_max_walk_speed', 'launch_character', 'set_timer_by_event', 'line_trace_forward']));
    });

    test('the manifest binds IA_FreeLook to Left Alt (+ the right thumbstick); project_input.g.dart maps both', () {
      final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/tp_probe.lmproject').readAsStringSync()) as Map),
      );
      expect(manifest.input.actions.firstWhere((a) => a.name == 'IA_FreeLook').valueType, ProjectInputValueType.digital);
      final gameplay = manifest.input.mappingContexts.firstWhere((c) => c.name == 'Gameplay');
      final keys = gameplay.mappings.where((m) => m.action == 'IA_FreeLook').toList();
      expect(keys.map((m) => m.keyLabel), ['Left Alt', 'Gamepad Right Thumbstick']);
      expect(keys.first.keyId, kKeyIdAltLeft);
      // The generated input file (compiled by the scaffold's analyze run below) binds the same keys.
      final input = File('$projectDir/lib/input/project_input.g.dart').readAsStringSync();
      expect(input, contains("'IA_FreeLook': LuminaInputAction('IA_FreeLook', valueType: InputValueType.digitalBool)"));
      expect(input, contains("mapKey(LuminaKey.keyLeftAlt, luminaProjectInputActions['IA_FreeLook']!)"));
      expect(input, contains("mapKey(LuminaKey.gamepadRightThumbstick, luminaProjectInputActions['IA_FreeLook']!)"));
      expect(input, isNot(contains('Unbound')));
      // The character Blueprint free-looks on it; the generated main forwards Left Alt.
      final character = blueprint(LuminaThirdPersonContent.characterBlueprintPath);
      expect(character.eventGraph.nodes.map((n) => n.literals['action']), contains('IA_FreeLook'));
      expect(character.eventGraph.nodes.map((n) => n.registryId), containsAll(['set_free_look', 'is_free_looking']));
      // The generated main forwards every key through LuminaKey.fromKeyId (Left Alt included).
      expect(File('$projectDir/lib/main.dart').readAsStringSync(), contains('LuminaKey.fromKeyId(event.logicalKey.keyId)'));
    });

    test('the mannequin plays ABP_Character, and the scaffold compiles exactly the committed goldens', () {
      final character = blueprint(LuminaThirdPersonContent.characterBlueprintPath);
      final mesh = character.components.firstWhere((c) => c.type == 'LuminaSkeletalMeshComponent');
      expect(mesh.properties['skeletalMeshAsset'], LuminaThirdPersonContent.projectMeshAssetPath);
      expect(mesh.properties['animMode'], 'Use Animation Blueprint');
      expect(mesh.properties['animClass'], LuminaThirdPersonContent.projectAnimBlueprintPath);
      final abp = LuminaAsset.fromBytes(File('$projectDir/${LuminaThirdPersonContent.projectAnimBlueprintPath}').readAsBytesSync());
      expect(abp.type, AssetType.animBlueprint);
      final bs = LuminaAsset.fromBytes(File('$projectDir/${LuminaThirdPersonContent.projectWalkBlendSpacePath}').readAsBytesSync());
      expect(bs.type, AssetType.blendSpace);
      // The editor's Animation Blueprint and Blend Space editors preview this mesh.
      expect(abp.metadata['target_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);
      expect(bs.metadata['target_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);

      // The same generator output the suite compiles and runs (test/blueprint/generated/).
      expect(File('$projectDir/lib/anim/abp_character.dart').readAsStringSync(),
          File('test/blueprint/generated/abp_character.g.dart').readAsStringSync());
      expect(
          File('$projectDir/lib/actors/bp_third_person_character.dart')
              .readAsStringSync()
              .replaceFirst("import '../anim/abp_character.dart';", "import 'abp_character.g.dart';"),
          File('test/blueprint/generated/bp_third_person_template.g.dart').readAsStringSync());

      // The generated pubspec bundles the folder the mesh loads from.
      final pubspec = File('$projectDir/pubspec.yaml').readAsStringSync();
      final folder = LuminaThirdPersonContent.projectMeshGlbPath.substring(
          0, LuminaThirdPersonContent.projectMeshGlbPath.lastIndexOf('/') + 1);
      expect(pubspec, contains('- $folder'));
    });

    test('copies the mannequin into contents as a skeletal mesh asset with its GLB companion', () {
      final lmas = File('$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}');
      final glb = File('$projectDir/${LuminaThirdPersonContent.projectMeshGlbPath}');
      expect(lmas.existsSync(), isTrue);
      expect(glb.existsSync(), isTrue);

      final asset = LuminaAsset.fromBytes(lmas.readAsBytesSync());
      expect(asset.type, AssetType.filameshSk);
      expect(asset.name, LuminaThirdPersonContent.meshAssetName);
      expect(asset.rawPayload, isNull, reason: 'the 12 MB GLB lives once, in the companion');
      expect(asset.hasThumbnail, isTrue);
      expect(asset.metadata['animation_clips'], LuminaThirdPersonContent.clipNames.join(','));

      final bytes = glb.readAsBytesSync();
      expect(GlbAnimationMerger.animationNames(bytes), LuminaThirdPersonContent.clipNames);
      // Influences are capped at the four gltfio reads, the way an import stores them.
      final doc = GlbDocument.parse(bytes);
      for (final mesh in (doc.json['meshes'] as List).cast<Map<String, dynamic>>()) {
        for (final prim in (mesh['primitives'] as List).cast<Map<String, dynamic>>()) {
          final attributes = prim['attributes'] as Map<String, dynamic>;
          expect(attributes.containsKey('JOINTS_1'), isFalse);
          expect(attributes.containsKey('WEIGHTS_1'), isFalse);
        }
      }
    });

    test('the mesh asset opens through the editor\'s loader with all nine clips', () async {
      final mesh = await AssetRepository.loadMeshFromDisk(
        '$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}',
      );
      expect(mesh, isNotNull);
      expect(mesh!.animations.map((a) => a.name).toList(), LuminaThirdPersonContent.clipNames);
    });

    test('writes one animation asset per clip that references the mesh instead of copying it', () {
      final meshAsset = LuminaAsset.fromBytes(
        File('$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}').readAsBytesSync(),
      );
      final clips = LuminaThirdPersonContent.clipNames;
      for (var i = 0; i < clips.length; i++) {
        final file = File('$projectDir/${LuminaThirdPersonContent.projectAnimationDir}/${clips[i]}.lmas');
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(file.lengthSync(), lessThan(64 * 1024), reason: 'no embedded GLB copy');

        final anim = LuminaAsset.fromBytes(file.readAsBytesSync());
        expect(anim.type, AssetType.animation);
        expect(anim.name, clips[i]);
        expect(anim.rawPayload, isNull);
        expect(anim.metadata['source_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);
        expect(anim.metadata['clip_name'], clips[i]);
        expect(anim.metadata['clip_index'], '$i');
        final props = jsonDecode(anim.metadata['anim_properties']!) as Map<String, dynamic>;
        expect(props['default_clip'], i);
        expect(props['preview_mesh_path'], LuminaThirdPersonContent.projectMeshAssetPath);
        expect(anim.references.single.assetId, meshAsset.assetId);
        expect(anim.references.single.assetPath, LuminaThirdPersonContent.projectMeshAssetPath);
      }
    });

    test('the level is a walkable map: wide ground, walls, and a platform reached by climbable stairs', () {
      final actors = readSeededActors(projectDir);
      Map<String, dynamic> props(Map<String, dynamic> actor) => Map<String, dynamic>.from(
            (actor['components'] as List)
                .map((c) => Map<String, dynamic>.from(c as Map))
                .firstWhere((c) => c['type'] == 'LuminaProceduralMeshComponent')['properties'] as Map,
          );
      // Stored Z-up in cm: height is location[2], and a primitive's
      // sizeZ is its own (mesh) height.
      double top(Map<String, dynamic> actor) =>
          ((actor['location'] as List)[2] as num).toDouble() + (props(actor)['sizeZ'] as num) / 2.0;

      expect(actors.any((a) => a['type'] == 'PlayerStart'), isTrue);
      final ground = actors.firstWhere((a) => a['name'] == 'Ground');
      expect(props(ground)['shape'], 'plane');
      expect(props(ground)['sizeX'], greaterThanOrEqualTo(6000.0));
      expect(props(ground)['sizeY'], greaterThanOrEqualTo(6000.0));
      expect(actors.where((a) => (a['name'] as String).startsWith('Wall_')).length, 4);

      final stairs = actors.where((a) => (a['name'] as String).startsWith('Stair_')).toList()
        ..sort((a, b) => top(a).compareTo(top(b)));
      expect(stairs.length, greaterThanOrEqualTo(5));
      const maxStep = 30.0; // LuminaCharacterMovementComponent.maxStepHeight, cm
      var previous = 0.0;
      for (final step in stairs) {
        expect(top(step) - previous, lessThanOrEqualTo(maxStep + 1e-9), reason: '${step['name']} is a climbable rise');
        previous = top(step);
      }
      final platform = actors.firstWhere((a) => a['name'] == 'Platform');
      expect(top(platform) - previous, lessThanOrEqualTo(maxStep + 1e-9));
      expect(top(platform), greaterThanOrEqualTo(150.0));
      expect(actors.where((a) => a['type'] == 'Primitive').length, greaterThanOrEqualTo(20));
    });

    test('a missing mannequin bundle fails the step, names the tool, and rolls back', () async {
      final emptyEngine = Directory.systemTemp.createTempSync('lumina_tpl_no_bundle_');
      final localRoot = Directory.systemTemp.createTempSync('lumina_tpl_tp_missing_');
      addTearDown(() {
        emptyEngine.deleteSync(recursive: true);
        localRoot.deleteSync(recursive: true);
      });
      final repo = ProjectRepository(
        configDir: configDir,
        processRunner: realFilesystemRunner(),
        enginePackageDir: emptyEngine.path,
      );
      await expectLater(
        repo.createProject(projectName: 'tp_missing', projectLocation: localRoot.path, template: kThirdPersonTemplateId),
        throwsA(isA<ProjectCreationException>().having(
          (e) => e.message,
          'message',
          allOf(contains(LuminaThirdPersonContent.bundledMeshPath), contains('build_third_person_content')),
        )),
      );
      expect(Directory('${localRoot.path}/tp_missing').existsSync(), isFalse);
    });
  });

  group('Blank 3D regression and rollback', () {
    test('blank 3D scaffolds the classic tree and records its id', () async {
      final root = Directory.systemTemp.createTempSync('lumina_tpl_blank_');
      final configDir = Directory.systemTemp.createTempSync('lumina_tpl_blank_cfg_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
        if (configDir.existsSync()) configDir.deleteSync(recursive: true);
      });

      final projectDir = await createTemplateProject(
        root: root,
        configDir: configDir,
        name: 'blank_probe',
        template: kBlank3dTemplateId,
      );

      expect(File('$projectDir/blank_probe.lmproject').existsSync(), isTrue);
      expect(File('$projectDir/lib/main.dart').existsSync(), isTrue);
      expect(File('$projectDir/lib/levels/l_default_level.dart').existsSync(), isTrue);
      expect(Directory('$projectDir/contents/levels').existsSync(), isTrue);
      // No game source is generated for the blank template.
      expect(Directory('$projectDir/lib/pawns').existsSync(), isFalse);

      final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(File('$projectDir/blank_probe.lmproject').readAsStringSync()) as Map,
        ),
      );
      expect(manifest.template, kBlank3dTemplateId);
      expect(manifest.mapsAndModes.defaultGameMode, 'LuminaGameMode');
      expect(manifest.input.actions, isEmpty);

      final actors = readSeededActors(projectDir);
      expect(actors.map((a) => a['name']).toList(), [
        'PlayerPawn_Default',
        'DirectionalLight_Sun',
        'SkyAtmosphere_Env',
        'StaticMesh_Rock_01',
      ]);
    });

    test('rollback leaves nothing on disk when a pipeline step throws', () async {
      final root = Directory.systemTemp.createTempSync('lumina_tpl_rollback_');
      final configDir = Directory.systemTemp.createTempSync('lumina_tpl_rollback_cfg_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
        if (configDir.existsSync()) configDir.deleteSync(recursive: true);
      });

      final repo = ProjectRepository(
        configDir: configDir,
        processRunner: (exec, args, {workingDirectory, runInShell = false}) async {
          if (args.isNotEmpty && args.first == 'pub') {
            return ProcessResult(0, 1, '', 'simulated pub get failure');
          }
          return realFilesystemRunner()(exec, args, workingDirectory: workingDirectory);
        },
      );

      await expectLater(
        repo.createProject(
          projectName: 'doomed_probe',
          projectLocation: root.path,
          template: kFirstPersonTemplateId,
        ),
        throwsA(isA<ProjectCreationException>()),
      );
      expect(Directory('${root.path}/doomed_probe').existsSync(), isFalse);
    });
  });

  group('the UMG widget library shapes the scaffold', () {
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      test('$library: manifest, pubspec and launcher match, and the project analyzes clean', () async {
        final root = Directory.systemTemp.createTempSync('lumina_tpl_umg_');
        final configDir = Directory.systemTemp.createTempSync('lumina_tpl_umg_cfg_');
        addTearDown(() {
          if (root.existsSync()) root.deleteSync(recursive: true);
          if (configDir.existsSync()) configDir.deleteSync(recursive: true);
        });
        final repo = ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner(offlinePubGet: true));
        final name = 'tp_umg_$library';
        final project = await repo.createProject(
          projectName: name,
          projectLocation: root.path,
          template: kThirdPersonTemplateId,
          widgetLibrary: library,
        );
        expect(project.ui.widgetLibrary, library);
        final projectDir = '${root.path}/$name';
        final manifest = jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map;
        expect(manifest['ui'], {'widget_library': library});
        final pubspec = File('$projectDir/pubspec.yaml').readAsStringSync();
        final main = File('$projectDir/lib/main.dart').readAsStringSync();
        if (library == kUmgWidgetLibraryShadcn) {
          expect(pubspec, contains('shadcn_flutter: $kGameShadcnFlutterVersion'));
          expect(main, contains('ShadcnLayer('));
        } else {
          expect(pubspec, isNot(contains('shadcn_flutter')));
          expect(main, isNot(contains('shadcn')));
        }
        File('$projectDir/analysis_options.yaml').writeAsStringSync('');
        final analyze = await analyzeGeneratedProject(projectDir);
        expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });

  group('generated projects analyze clean', () {
    for (final (template, name, label) in [
      (kFirstPersonTemplateId, 'fp_analyze', 'First Person'),
      (kThirdPersonTemplateId, 'tp_analyze', 'Third Person'),
    ]) {
      test('$label: dart analyze --fatal-infos lib', () async {
        final root = Directory.systemTemp.createTempSync('lumina_tpl_analyze_');
        final configDir = Directory.systemTemp.createTempSync('lumina_tpl_analyze_cfg_');
        addTearDown(() {
          if (root.existsSync()) root.deleteSync(recursive: true);
          if (configDir.existsSync()) configDir.deleteSync(recursive: true);
        });

        final repo = ProjectRepository(
          configDir: configDir,
          processRunner: realFilesystemRunner(offlinePubGet: true),
        );
        await repo.createProject(
          projectName: name,
          projectLocation: root.path,
          template: template,
        );

        final projectDir = '${root.path}/$name';
        // analysis_options from `flutter create` pulls in flutter_lints, which is
        // not resolvable offline here; the template's own code is what we analyze.
        File('$projectDir/analysis_options.yaml').writeAsStringSync('');
        if (template == kThirdPersonTemplateId) {
          // A project that binds keys outside the template's set (V, F5,
          // a numpad key, Right Ctrl) gets them mapped in project_input.g.dart,
          // and that file compiles.
          final base = GameTemplateCatalog.byId(template).input;
          final gameplay = base.mappingContexts.single;
          final settings = ProjectInputSettings(
            actions: [...base.actions, const ProjectInputAction(name: 'IA_ChangeCamera')],
            mappingContexts: [
              ProjectMappingContext(name: gameplay.name, priority: gameplay.priority, mappings: [
                ...gameplay.mappings,
                const ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x76, keyLabel: 'V'),
                const ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x100000805, keyLabel: 'F5'),
                const ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x200000231, keyLabel: 'Numpad 1'),
                const ProjectInputMapping(action: 'IA_ChangeCamera', keyId: 0x200000101, keyLabel: 'Control Right'),
              ]),
            ],
          );
          final input = DartCodeGeneratorService().generateProjectInputDart(settings);
          expect(input, isNot(contains('Unbound')));
          for (final key in ['keyV', 'keyF5', 'keyNumpad1', 'keyRightControl']) {
            expect(input, contains("mapKey(LuminaKey.$key, luminaProjectInputActions['IA_ChangeCamera']!)"), reason: key);
          }
          File('$projectDir/lib/input/project_input.g.dart').writeAsStringSync(input);
          expect(File('$projectDir/lib/main.dart').readAsStringSync(), contains('LuminaKey.fromKeyId(event.logicalKey.keyId)'),
              reason: "the built game's key bridge takes every key");
        }
        final analyze = await analyzeGeneratedProject(projectDir);
        expect(
          analyze.exitCode,
          0,
          reason: 'generated $label project must analyze clean:\n'
              '${analyze.stdout}\n${analyze.stderr}',
        );
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}
