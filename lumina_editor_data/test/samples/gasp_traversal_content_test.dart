import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../lumina/test/blueprint/traversal_blueprint.dart';
import '../helpers/locomotion_fbx_fixture.dart';

/// The example's character with traversal: the export's traversal clips go
/// into the character mesh, the character gets the traversal component and
/// its Jump tries a traversal action before jumping.
void main() {
  test('the character Blueprint carries the traversal rows and Jump tries a traversal action first', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    TraversalBlueprintFixture.level(world);
    final bound = ProjectInputBinder.bind(GaspCharacterContent.input);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    final actions = bound.actions.values.toList();
    final doc = GaspCharacterContent.characterBlueprint(
        meshAssetPath: 'never_loaded.lmas', inputActions: actions, traversal: TraversalBlueprintFixture.animations);
    final component = doc.components.firstWhere((c) => c.type == 'LuminaTraversalComponent');
    expect(component.properties['rootBone'], GaspTraversal.rootBone);
    expect((component.properties['animations'] as List).length, TraversalBlueprintFixture.animations.length);
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: GaspCharacterContent.characterName, inputActions: actions, animBlueprints: (_) => null);
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final character = cls.instantiate(location: Vector3(0, 90.2, 0)) as LuminaCharacter;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    final traversal = (character as LuminaBlueprintRuntime).blueprintComponents['traversal'] as LuminaTraversalComponent
      ..useRig(TraversalBlueprintFixture.rig());
    pc.onTick(1 / 60);
    world.tick(1 / 60);
    character.characterMovement.velocity.setValues(0, 0, -400);
    input.injectKeyDown(LuminaKey.keySpace);
    pc.onTick(1 / 60);
    world.tick(1 / 60);
    expect(traversal.isTraversing, isTrue, reason: '${traversal.lastCheck}');
    expect(character.characterMovement.isFalling, isFalse, reason: 'the traversal replaced the jump');

    // Without rows the character jumps as before and has no component.
    final plain = GaspCharacterContent.characterBlueprint(meshAssetPath: 'never_loaded.lmas', inputActions: actions);
    expect(plain.components.any((c) => c.type == 'LuminaTraversalComponent'), isFalse);
    expect(plain.eventGraph.nodes.any((n) => n.registryId == 'try_traversal_action'), isFalse);
  });

  final metadata = File('${LocomotionFbxFixture.directory.path}/Traversal/metadata.json');
  test('the export parses its traversal rows and imports their clips into the character mesh', () {
    final json = jsonDecode(metadata.readAsStringSync()) as Map<String, dynamic>;
    final root = Directory.systemTemp.path.replaceAll(r'\', '/');
    final fbx = [
      for (final r in GaspTraversal.rows(json)) '$root/${GaspExport.animationsFolder}/Traversal/${r.clip}.fbx',
    ];
    final export = GaspExport.parse(root, json, fbx);
    expect(export.traversal, isNotEmpty);
    expect({for (final r in export.traversal) r.action},
        {LuminaTraversalActionType.hurdle, LuminaTraversalActionType.vault, LuminaTraversalActionType.mantle});
    final jobs = GameAnimationSampleBuilder.jobsFor(export);
    for (final r in export.traversal) {
      final job = jobs.firstWhere((j) => j.name == r.clip);
      expect(job.library, isFalse, reason: '${r.clip} plays from the character mesh');
      expect(job.removeRootHeight, isFalse, reason: '${r.clip} keeps its root motion');
    }
  }, skip: metadata.existsSync() ? null : 'test-assets/FBX/GameAnimationSample/Traversal is missing');
}
