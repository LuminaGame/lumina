import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory projectDir;
  late Directory contentsDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_project_test_');
    contentsDir = Directory('${projectDir.path}/contents/Blueprints')..createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
  });

  test('BlueprintEditorViewModel resolves inherited variables and components from parent Blueprint', () async {
    // 1. Create parent blueprint: BP_Base
    final baseDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      variables: [
        const LuminaBlueprintVariable(name: 'maxHealth', typeName: 'Float', defaultValue: 100.0),
        const LuminaBlueprintVariable(name: 'heroName', typeName: 'String', defaultValue: 'Player'),
      ],
      components: [
        LuminaBlueprintComponent(
          id: 'base_capsule',
          name: 'CapsuleComponent',
          type: 'LuminaCapsuleComponent',
          parentId: null,
          properties: {'capsuleRadius': 40.0},
        ),
        LuminaBlueprintComponent(
          id: 'base_mesh',
          name: 'CharacterMesh',
          type: 'LuminaSkinnedMeshComponent',
          parentId: 'base_capsule',
          properties: {},
        ),
      ],
    );

    final baseFile = File('${contentsDir.path}/BP_Base.lmas');
    final baseAsset = LuminaAsset(
      assetId: 'BP_Base',
      name: 'BP_Base',
      type: AssetType.actor,
      rawPayload: utf8.encode(baseDoc.toFormattedJson()),
    );
    await baseFile.writeAsBytes(baseAsset.toProtoBufferBytes());

    // 2. Create child blueprint: BP_Warrior inheriting from BP_Base
    final childDoc = LuminaBlueprintDocument(
      parentClass: 'BP_Base',
      variables: [
        const LuminaBlueprintVariable(name: 'stamina', typeName: 'Float', defaultValue: 50.0),
      ],
      components: [
        LuminaBlueprintComponent(
          id: 'child_sword',
          name: 'SwordMesh',
          type: 'LuminaSceneComponent',
          parentId: 'base_mesh',
          properties: {},
        ),
      ],
      classDefaults: {'maxHealth': 150.0},
    );

    final childFile = File('${contentsDir.path}/BP_Warrior.lmas');
    final childAsset = LuminaAsset(
      assetId: 'BP_Warrior',
      name: 'BP_Warrior',
      type: AssetType.actor,
      rawPayload: utf8.encode(childDoc.toFormattedJson()),
    );
    await childFile.writeAsBytes(childAsset.toProtoBufferBytes());

    // 3. Open child blueprint in BlueprintEditorViewModel
    final vm = BlueprintEditorViewModel(assetPath: childFile.path, initialAsset: childAsset);
    await vm.load();

    // Verify inherited variables
    expect(vm.inheritedVariables.length, equals(2));
    expect(vm.inheritedVariables.map((v) => v.name), containsAll(['maxHealth', 'heroName']));
    expect(vm.allVariables.length, equals(3));
    expect(vm.allVariables.map((v) => v.name), containsAll(['maxHealth', 'heroName', 'stamina']));
    expect(vm.isInheritedVariable('maxHealth'), isTrue);
    expect(vm.isInheritedVariable('heroName'), isTrue);
    expect(vm.isInheritedVariable('stamina'), isFalse);

    // Verify inherited components
    expect(vm.inheritedComponents.length, equals(2));
    expect(vm.inheritedComponents.map((c) => c.id), containsAll(['base_capsule', 'base_mesh']));
    expect(vm.allComponents.length, equals(3));
    expect(vm.allComponents.map((c) => c.id), containsAll(['base_capsule', 'base_mesh', 'child_sword']));
    expect(vm.isInheritedComponent('base_capsule'), isTrue);
    expect(vm.isInheritedComponent('base_mesh'), isTrue);
    expect(vm.isInheritedComponent('child_sword'), isFalse);

    // Verify root component resolves from parent components
    expect(vm.rootComponent?.id, equals('base_capsule'));

    // Verify delete, rename and reparent protection for inherited components
    expect(vm.removeComponent('base_capsule'), isFalse);
    expect(vm.renameComponent('base_capsule', 'NewCapsule'), isFalse);
    expect(vm.canReparent('base_capsule', 'child_sword'), isFalse);

    // Verify child can override class default of inherited variable
    final defaultOverridden = vm.setVariableDefault('maxHealth', 200.0);
    expect(defaultOverridden, isTrue);
    expect(vm.document.classDefaults['maxHealth'], equals(200.0));

    // Verify child can override inherited component properties (e.g. staticMeshAsset or transform)
    expect(vm.isComponentOverridden('base_mesh'), isFalse);
    vm.setProperty('base_mesh', 'staticMeshAsset', 'contents/Meshes/Hero.lmas');
    expect(vm.isComponentOverridden('base_mesh'), isTrue);
    expect(vm.isInheritedComponent('base_mesh'), isTrue);
    expect(vm.document.components.any((c) => c.id == 'base_mesh'), isTrue);
    final overriddenMesh = vm.allComponents.firstWhere((c) => c.id == 'base_mesh');
    expect(overriddenMesh.properties['staticMeshAsset'], equals('contents/Meshes/Hero.lmas'));

    // Verify type context sees both parent and child members
    final typeContext = vm.typeContext;
    expect(typeContext.variable('maxHealth'), isNotNull);
    expect(typeContext.variable('stamina'), isNotNull);
    expect(typeContext.component('CharacterMesh'), isNotNull);
    expect(typeContext.component('SwordMesh'), isNotNull);

    // Verify compile succeeds and generates Dart code referencing parent class and overridden component
    final compiled = await vm.compile();
    expect(compiled, isTrue);
    final dartCode = vm.generatedDartCode;
    expect(dartCode, contains('class BpWarrior extends BpBase'));
    expect(dartCode, contains("import 'bp_base.dart';"));
    expect(dartCode, contains("'base_mesh'"));
  });

  test('BlueprintEditorViewModel resolves inherited custom events, offers them in Node Palette as Event <Name>, and places override node with parameters', () async {
    // 1. Create parent blueprint: BP_Interactable with custom event OnInteract(Energy: Float)
    final interactableDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      eventGraph: LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNode(
            id: 'event_on_interact',
            registryId: LuminaBlueprintNodeLibrary.customEvent,
            title: 'OnInteract',
            literals: const {
              'name': 'OnInteract',
              'parameters': [
                {'name': 'Energy', 'type': 'Float', 'default': 10.0}
              ],
            },
          ),
        ],
      ),
    );

    final interactableFile = File('${contentsDir.path}/BP_Interactable.lmas');
    final interactableAsset = LuminaAsset(
      assetId: 'BP_Interactable',
      name: 'BP_Interactable',
      type: AssetType.actor,
      rawPayload: utf8.encode(interactableDoc.toFormattedJson()),
    );
    await interactableFile.writeAsBytes(interactableAsset.toProtoBufferBytes());

    // 2. Create child blueprint: BP_LightTower inheriting from BP_Interactable
    final towerDoc = LuminaBlueprintDocument(
      parentClass: 'BP_Interactable',
      variables: const [
        LuminaBlueprintVariable(name: 'LightOn', typeName: 'Bool', defaultValue: false),
      ],
    );

    final towerFile = File('${contentsDir.path}/BP_LightTower.lmas');
    final towerAsset = LuminaAsset(
      assetId: 'BP_LightTower',
      name: 'BP_LightTower',
      type: AssetType.actor,
      rawPayload: utf8.encode(towerDoc.toFormattedJson()),
    );
    await towerFile.writeAsBytes(towerAsset.toProtoBufferBytes());

    // 3. Open child blueprint in BlueprintEditorViewModel
    final vm = BlueprintEditorViewModel(assetPath: towerFile.path, initialAsset: towerAsset);
    await vm.load();

    // Verify inherited custom event is resolved
    expect(vm.inheritedCustomEvents.length, equals(1));
    expect(vm.inheritedCustomEvents.first.name, equals('OnInteract'));
    expect(vm.inheritedCustomEvents.first.parameters.single.name, equals('Energy'));
    expect(vm.isInheritedCustomEvent('OnInteract'), isTrue);

    // 4. Verify Node Palette contains Event OnInteract under Add Event, and Call OnInteract under Call Event
    final paletteEntries = BlueprintPalette.entriesFor(vm.typeContext, null);
    final overrideEntry = paletteEntries.firstWhere((e) => e.keyOverride == 'override_custom_event_OnInteract');
    expect(overrideEntry.title, equals('Event OnInteract'));
    expect(overrideEntry.category, equals('Add Event'));
    expect(overrideEntry.registryId, equals(LuminaBlueprintNodeLibrary.customEvent));
    expect(overrideEntry.keywords, containsAll(['override', 'event', 'oninteract', 'energy']));

    final callEntry = paletteEntries.where((e) => e.registryId == LuminaBlueprintNodeLibrary.callCustomEvent && e.literals['event'] == 'OnInteract').firstOrNull;
    expect(callEntry, isNotNull);
    expect(callEntry!.category, equals('Call Event'));

    // 5. Place the override custom event node in the child graph
    final placedNode = vm.eventGraph.placeEntry(overrideEntry, const Offset(300, 200));
    expect(placedNode, isNotNull);
    expect(placedNode!.registryId, equals(LuminaBlueprintNodeLibrary.customEvent));
    expect(placedNode.title, equals('OnInteract'));
    expect(placedNode.literals['name'], equals('OnInteract'));

    // Verify output pins: exec_out, delegate, and Energy (Float)
    final pinIds = placedNode.outputs.map((p) => p.id).toList();
    expect(pinIds, containsAll(['exec_out', 'delegate', 'Energy']));
    final energyPin = placedNode.outputs.firstWhere((p) => p.id == 'Energy');
    expect(energyPin.type, equals(LuminaPinType.float));

    // 6. After placing, the override event is already in the graph, so the palette should no longer offer placing it again
    final updatedPalette = BlueprintPalette.entriesFor(vm.typeContext, null);
    final duplicateOverride = updatedPalette.where((e) => e.keyOverride == 'override_custom_event_OnInteract').firstOrNull;
    expect(duplicateOverride, isNull, reason: 'Palette must not offer duplicate override event entries once placed in the graph');

    // 7. Verify compilation generates override in Dart code
    final compiled = await vm.compile();
    expect(compiled, isTrue);
    final dartCode = vm.generatedDartCode;
    expect(dartCode, contains('class BpLightTower extends BpInteractable'));
    expect(dartCode, contains("case 'OnInteract':"));
    expect(dartCode, contains('return super.callBlueprint(name, args);'));
  });
}
