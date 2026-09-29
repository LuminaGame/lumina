import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../data/project_template_test.dart' show realFilesystemRunner;
import 'anim_blueprints.dart';
import 'generated/abp_character.g.dart';
import 'generated/bp_third_person_template.g.dart';

/// The Third Person template's BP_ThirdPersonCharacter plays
/// exactly like the Dart `LuminaTemplateCharacter(thirdPerson: true)` it
/// replaces — run by the VM (Play) and as generated code (the built game).
void main() {
  LuminaWorld yard() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaCollisionSubsystem());
    w.persistentLevel.registerActor(
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(8000, 0, 8000), color: Vector3.all(0.5)));
    return w;
  }

  ({
    LuminaWorld world,
    LuminaCharacter character,
    LuminaPlayerController pc,
    LuminaInputSubsystem input,
    LuminaCameraComponent camera,
    LuminaAnimatedMeshComponent mesh,
  }) spawn(String kind) {
    final w = yard();
    final input = w.registerSubsystem(LuminaInputSubsystem());
    // Each world binds its own contexts: triggers hold state.
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final actions = bound.actions.values.toList();
    final start = Vector3(0, 100, 0);
    final LuminaCharacter character;
    if (kind == 'dart') {
      character = LuminaTemplateCharacter(thirdPerson: true, meshAssetPath: 'never_loaded.glb', location: start);
    } else {
      for (final c in bound.contexts) {
        input.addMappingContext(c.context, priority: c.priority);
      }
      if (kind == 'vm') {
        final anim = templateAnimClass();
        character = LuminaBlueprintClass.fromDocument(
          LuminaThirdPersonContent.characterBlueprint(inputActions: actions, meshAsset: 'never_loaded.glb'),
          name: LuminaThirdPersonContent.characterBlueprintName,
          inputActions: actions,
          animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null,
        ).instantiate(location: start) as LuminaCharacter;
      } else {
        character = BpThirdPersonCharacter(location: start);
      }
    }
    final pc = LuminaPlayerController();
    w.persistentLevel.registerActor(character);
    pc.possess(character);
    if (character is LuminaTemplateCharacter) {
      bindTemplateCharacterInput(character: character, world: w, input: bound);
    }
    w.beginPlay();
    final components = character is LuminaBlueprintRuntime ? (character as LuminaBlueprintRuntime).blueprintComponents : null;
    return (
      world: w,
      character: character,
      pc: pc,
      input: input,
      camera: components == null
          ? (character as LuminaTemplateCharacter).cameraComponent
          : components['camera'] as LuminaCameraComponent,
      mesh: components == null
          ? (character as LuminaTemplateCharacter).bodyMesh!
          : components['mesh'] as LuminaAnimatedMeshComponent,
    );
  }

  test('the same 4 s of W, W+D, a mouse sweep and Space: VM and generated match the Dart character', () {
    final runs = {for (final k in ['dart', 'vm', 'generated']) k: spawn(k)};
    expect(runs['generated']!.character, isA<BpThirdPersonCharacter>());
    expect((runs['generated']!.character as LuminaBlueprintRuntime).blueprintComponents['mesh.anim'], isA<AbpCharacter>());
    final clips = {for (final k in runs.keys) k: <String?>[]};
    for (var frame = 0; frame < 240; frame++) {
      for (final r in runs.values) {
        if (frame == 20) r.input.injectKeyDown(LuminaKey.keyW);
        if (frame == 60) r.input.injectKeyDown(LuminaKey.keyD);
        if (frame == 100) r.input.injectKeyUp(LuminaKey.keyD);
        if (frame >= 110 && frame < 170) r.input.injectAnalog(LuminaKey.mouseX, 4.0);
        if (frame >= 110 && frame < 140) r.input.injectAnalog(LuminaKey.mouseY, 1.5);
        if (frame == 180) r.input.injectKeyDown(LuminaKey.keySpace);
        if (frame == 186) r.input.injectKeyUp(LuminaKey.keySpace);
        if (frame == 230) r.input.injectKeyUp(LuminaKey.keyW);
        r.pc.onTick(1 / 60);
        r.world.tick(1 / 60);
      }
      for (final e in runs.entries) {
        clips[e.key]!.add(e.value.mesh.currentClip);
      }
    }
    final dart = runs['dart']!;
    expect((dart.character.actorLocation - Vector3(0, 100, 0)).length, greaterThan(300), reason: 'the script walked');
    expect(clips['dart']!.toSet(), containsAll(['Idle_Loop', 'Walk_Fwd_Loop', 'Walk_Fwd_Right_Loop']));
    for (final kind in ['vm', 'generated']) {
      final r = runs[kind]!;
      expect((r.character.actorLocation - dart.character.actorLocation).length, lessThan(1e-3), reason: '$kind location');
      final rotation = r.pc.controlRotation - dart.pc.controlRotation;
      expect(rotation.length, lessThan(1e-6), reason: '$kind control rotation');
      expect((r.camera.worldLocation - dart.camera.worldLocation).length, lessThan(1e-3), reason: '$kind camera');
      // From the Space press on, ABP_Character plays Jump_Start /
      // Jump_Loop / Jump_Land where the Dart driver holds the walk pose.
      expect(clips[kind]!.sublist(0, 180), clips['dart']!.sublist(0, 180), reason: '$kind mannequin clips, frame by frame');
      expect(clips[kind]!.sublist(180).toSet(), containsAll(['Jump_Start', 'Jump_Land']), reason: '$kind jumped and landed');
    }
    expect(clips['generated'], clips['vm'], reason: 'generated and VM mannequin clips, frame by frame');
  });

  test('a scaffolded Third Person project spawns BP_ThirdPersonCharacter at its PlayerStart, standing on the ground',
      () async {
    final root = Directory.systemTemp.createTempSync('lumina_bp06_play_');
    final configDir = Directory.systemTemp.createTempSync('lumina_bp06_play_cfg_');
    addTearDown(() {
      root.deleteSync(recursive: true);
      configDir.deleteSync(recursive: true);
    });
    await ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner())
        .createProject(projectName: 'tp_play', projectLocation: root.path, template: kThirdPersonTemplateId);
    final dir = '${root.path}/tp_play';
    final project = LuminaProject.fromMap(jsonDecode(File('$dir/tp_play.lmproject').readAsStringSync()) as Map<String, dynamic>);
    final level = jsonDecode(File('$dir/contents/levels/L_DefaultLevel.lmas').readAsStringSync()) as Map<String, dynamic>;

    // The level as the generated game builds it (stored Z-up cm).
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaCollisionSubsystem());
    w.registerSubsystem(LuminaInputSubsystem());
    Vector3? start;
    for (final a in ((level['metadata'] as Map)['actors'] as List).cast<Map<String, dynamic>>()) {
      final loc = (a['location'] as List).cast<num>();
      if (a['type'] == 'PlayerStart') {
        start = LuminaAxes.location(loc);
        w.persistentLevel.registerActor(LuminaPlayerStart(location: start.clone()));
      }
      if (a['type'] != 'Primitive') continue;
      final props = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
      w.persistentLevel.registerActor(LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)));
    }
    final registry = LuminaBlueprintClassRegistry(dir);
    w.gameMode = registry.createGameMode(project.mapsAndModes);
    expect(w.gameMode, isNotNull, reason: '${registry.diagnostics}');
    w.beginPlay();
    final pc = w.gameMode!.login();
    for (var i = 0; i < 60; i++) {
      pc.onTick(1 / 60);
      w.tick(1 / 60);
    }
    final pawn = pc.pawn as LuminaBlueprintCharacter;
    expect(pawn.blueprintClass.name, LuminaThirdPersonContent.characterBlueprintName);
    expect(pawn.characterMovement.isFalling, isFalse, reason: 'standing on the ground');
    expect(((pawn.actorLocation - start!)..y = 0).length, lessThan(1.0), reason: 'at the PlayerStart');
    expect(registry.diagnostics.where((d) => d.isError), isEmpty);
    expect((pawn.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance).currentState, 'Idle');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
