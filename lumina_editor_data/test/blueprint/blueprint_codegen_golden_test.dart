import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../../lumina/test/blueprint/anim_blueprints.dart';
import '../../../lumina/test/blueprint/collision_shapes_blueprint.dart';
import '../../../lumina/test/blueprint/physics_blueprint.dart';
import '../../../lumina/test/blueprint/engine_nodes_blueprint.dart';
import '../../../lumina/test/blueprint/flow_blueprint.dart';
import '../../../lumina/test/blueprint/flow_nodes_blueprint.dart';
import '../../../lumina/test/blueprint/gameplay_nodes_blueprint.dart';
import '../../../lumina/test/blueprint/level_load_blueprint.dart';
import '../../../lumina/test/blueprint/motion_matching_blueprint.dart';
import '../../../lumina/test/blueprint/no_begin_play_blueprint.dart';
import '../../../lumina/test/blueprint/reusable_graphs_blueprint.dart';
import '../../../lumina/test/blueprint/third_person_blueprint.dart';
import '../../../lumina/test/blueprint/typed_pins_blueprint.dart';

/// Generated Blueprint Dart is committed under
/// test/blueprint/generated/ and compiled by the suite (the parity tests
/// import it). Regenerate after an intentional generator change with
/// `UPDATE_GOLDENS=1 flutter test test/blueprint/blueprint_codegen_golden_test.dart`.
List<LuminaInputAction> templateInputActions() =>
    ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();

Map<String, (LuminaBlueprintDocument, String, List<LuminaInputAction>)> goldens() => {
      'bp_editor_character': (
        LuminaBlueprintDocument.fromJson(
            jsonDecode(File('../lumina/test/blueprint/fixtures/editor_character.json').readAsStringSync()) as Map<String, dynamic>),
        'BpEditorCharacter',
        const <LuminaInputAction>[],
      ),
      'bp_third_person_character': (
        thirdPersonCharacterBlueprint(inputActions: templateInputActions()),
        'BpThirdPersonCharacter',
        templateInputActions(),
      ),
      'bp_flow': (flowBlueprint(), 'BpFlow', const <LuminaInputAction>[]),
      // Typed object pins, widget elements, components.
      'bp_typed_pins': (typedPinsBlueprint(), 'BpTypedPins', const <LuminaInputAction>[]),
      // Flow-control macros and every pure math / string / array node.
      'bp_flow_nodes': (flowNodesBlueprint(), 'BpFlowNodes', const <LuminaInputAction>[]),
      'bp_pure_nodes': (pureNodesBlueprint(), 'BpPureNodes', const <LuminaInputAction>[]),
      // Engine stats, traces, view target, actor nodes and the actor events.
      'bp_engine_nodes': (engineNodesBlueprint(), 'BpEngineNodes', const <LuminaInputAction>[]),
      // Custom events, functions, macros, dispatchers, interfaces, enums, timers, timeline.
      'bp_reusable_graphs': (reusableGraphsBlueprint(), 'BpReusableGraphs', const <LuminaInputAction>[]),
      // Shape collision components with presets and the Collision nodes.
      'bp_collision_shapes': (collisionShapesBlueprint(), 'BpCollisionShapes', const <LuminaInputAction>[]),
      // Simulating components, the Physics nodes and Event Hit.
      'bp_physics': (physicsBlueprint(), 'BpPhysics', const <LuminaInputAction>[]),
      // Load Level, Change Level, Load And Change Level, Cancel Level Load, Is Level Loaded.
      'bp_level_load': (levelLoadBlueprint(), 'BpLevelLoad', const <LuminaInputAction>[]),
      // No Event BeginPlay, only a custom event with a latent Delay.
      'bp_no_begin_play': (noBeginPlayBlueprint(), 'BpNoBeginPlay', const <LuminaInputAction>[]),
    };

void main() {
  const generator = BlueprintDartGenerator();
  // BP_TypedPins' Get FPSCounter is typed from the registered widget class.
  setUpAll(() {
    LuminaWidgetClassRegistry.register(typedPinsHud);
    // BP_ReusableGraphs' enum and interface assets.
    LuminaBlueprintEnums.register(reusableDoorState);
    LuminaBlueprintInterfaces.register(reusableInteractable);
    // BP_GameplayNodes' montage, save class and particle template.
    registerGameplayAssets();
  });
  tearDownAll(() {
    LuminaWidgetClassRegistry.clear();
    LuminaBlueprintEnums.clear();
    LuminaBlueprintInterfaces.clear();
    clearGameplayAssets();
  });
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';

  final results = <String, BlueprintGenerationResult Function()>{
    for (final entry in goldens().entries)
      entry.key: () => generator.generate(entry.value.$1,
          className: entry.value.$2, assetPath: 'contents/blueprints/${entry.key}.lmas', inputActions: entry.value.$3),
    // ABP_Character, and a character whose mesh names it.
    'abp_character': () => generator.generateAnimBlueprint(LuminaThirdPersonContent.animBlueprint,
        className: 'AbpCharacter', assetPath: LuminaThirdPersonContent.projectAnimBlueprintPath, blendSpaces: templateBlendSpaces()),
    // A Motion Matching state over an inline pose search database.
    'abp_motion_matching': () => generator.generateAnimBlueprint(MotionMatchingBlueprintFixture.animBlueprint(),
        className: 'AbpMotionMatching',
        assetPath: 'contents/animations/ABP_MotionMatching.lmas',
        poseDatabases: {MotionMatchingBlueprintFixture.databasePath: MotionMatchingBlueprintFixture.database}),
    // What the Third Person scaffold compiles for its character.
    'bp_third_person_template': () => generator.generate(
        LuminaThirdPersonContent.characterBlueprint(inputActions: templateInputActions()),
        className: 'BpThirdPersonCharacter',
        assetPath: LuminaThirdPersonContent.characterBlueprintPath,
        inputActions: templateInputActions(),
        animBlueprints: {
          LuminaThirdPersonContent.projectAnimBlueprintPath: const BlueprintAnimClassRef('AbpCharacter', 'abp_character.g.dart'),
        }),
    // Game framework, save, input, audio, animation, fx, material, light and debug nodes.
    'bp_gameplay_nodes': () => generator.generate(gameplayNodesBlueprint(inputActions: templateInputActions()),
        className: 'BpGameplayNodes',
        assetPath: 'contents/blueprints/bp_gameplay_nodes.lmas',
        inputActions: templateInputActions(),
        animBlueprints: {
          LuminaThirdPersonContent.projectAnimBlueprintPath: const BlueprintAnimClassRef('AbpCharacter', 'abp_character.g.dart'),
        }),
    'bp_anim_character': () => generator.generate(templateCharacterBlueprint(inputActions: templateInputActions()),
        className: 'BpAnimCharacter',
        assetPath: 'contents/blueprints/bp_anim_character.lmas',
        inputActions: templateInputActions(),
        animBlueprints: {
          LuminaThirdPersonContent.projectAnimBlueprintPath: const BlueprintAnimClassRef('AbpCharacter', 'abp_character.g.dart'),
        }),
  };

  for (final entry in results.entries) {
    test('${entry.key} regenerates byte-identically', () {
      final result = entry.value();
      expect(result.errors, isEmpty, reason: '${result.issues}');
      expect(result.issues, isEmpty, reason: 'no warnings either');
      final file = File('../lumina/test/blueprint/generated/${entry.key}.g.dart');
      if (update) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(result.code!);
      }
      expect(file.existsSync(), isTrue, reason: 'run with UPDATE_GOLDENS=1 to create it');
      expect(result.code, file.readAsStringSync(), reason: 'the generator changed; review and update the golden');
    });
  }

  test('the generated goldens analyze clean', () async {
    final r = await Process.run('dart', ['analyze', '--fatal-infos', '../lumina/test/blueprint/generated'], runInShell: Platform.isWindows);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
