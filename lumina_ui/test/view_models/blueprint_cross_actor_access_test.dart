import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory projectDir;
  late Directory contentsDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_cross_actor_test_');
    contentsDir = Directory('${projectDir.path}/contents/Blueprints')..createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
  });

  test('Cross-actor member variables and components are exposed and compatible with typed Actor pins', () async {
    // 1. Create target blueprint: BP_Interactable
    final interactableDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      variables: [
        const LuminaBlueprintVariable(name: 'Message', typeName: 'String', defaultValue: 'Press E to Interact'),
        const LuminaBlueprintVariable(name: 'IsCollectable', typeName: 'Boolean', defaultValue: true),
      ],
      components: [
        LuminaBlueprintComponent(
          id: 'mesh_comp',
          name: 'StaticMeshComponent',
          type: 'LuminaStaticMeshComponent',
          parentId: null,
          properties: {},
        ),
      ],
    );

    final interactableFile = File('${contentsDir.path}/BP_Interactable.lmas');
    final interactableAsset = LuminaAsset(
      assetId: 'BP_Interactable',
      name: 'BP_Interactable',
      type: AssetType.actor,
      rawPayload: utf8.encode(interactableDoc.toFormattedJson()),
    );
    await interactableFile.writeAsBytes(interactableAsset.toProtoBufferBytes());

    // 2. Create caller blueprint: BP_ThirdPersonCharacter with variable InteractedObject
    final characterDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      variables: [
        const LuminaBlueprintVariable(
          name: 'InteractedObject',
          typeName: 'Actor:BP_Interactable',
        ),
      ],
      components: [],
    );

    final characterFile = File('${contentsDir.path}/BP_ThirdPersonCharacter.lmas');
    final characterAsset = LuminaAsset(
      assetId: 'BP_ThirdPersonCharacter',
      name: 'BP_ThirdPersonCharacter',
      type: AssetType.actor,
      rawPayload: utf8.encode(characterDoc.toFormattedJson()),
    );
    await characterFile.writeAsBytes(characterAsset.toProtoBufferBytes());

    // 3. Open character in BlueprintEditorViewModel
    final vm = BlueprintEditorViewModel(assetPath: characterFile.path, initialAsset: characterAsset);
    await vm.load();

    final context = vm.typeContext;
    expect(context.variableOwners.containsKey('BP_Interactable'), isTrue);
    expect(context.variableOwners['BP_Interactable']!.map((v) => v.name), containsAll(['Message', 'IsCollectable']));
    expect(context.componentOwners.containsKey('BP_Interactable'), isTrue);
    expect(context.componentOwners['BP_Interactable']!.map((c) => c.name), contains('StaticMeshComponent'));

    // 4. Test dragging from typed object pin (As BP_Interactable or InteractedObject)
    final fromPin = BlueprintPinRef(
      nodeId: 'cast_node',
      pinId: 'as_class',
      isOutput: true,
      type: LuminaPinType.object,
      objectClass: 'Actor:BP_Interactable',
    );

    final entries = BlueprintPalette.entriesFor(context, fromPin);
    final entryTitles = entries.map((e) => e.title).toList();

    expect(entryTitles, contains('Get Message'));
    expect(entryTitles, contains('Set Message'));
    expect(entryTitles, contains('Get IsCollectable'));
    expect(entryTitles, contains('Set IsCollectable'));
    expect(entryTitles, contains('Get StaticMeshComponent'));

    // 5. Verify the placed node structure for Get Message
    final getNode = LuminaBlueprintNodeLibrary.place(
      LuminaBlueprintNodeLibrary.variableGet,
      nodeId: 'get_msg_node',
      literals: {'variable': 'Message', 'class': 'Actor:BP_Interactable'},
      context: context,
    );

    expect(getNode.title, equals('Get Message'));
    expect(getNode.category, equals('Variables|BP_Interactable'));
    final targetInput = getNode.inputs.firstWhere((p) => p.id == 'target');
    expect(targetInput.objectClass, equals('Actor:BP_Interactable'));
    final valueOutput = getNode.outputs.firstWhere((p) => p.id == 'value');
    expect(valueOutput.type, equals(LuminaPinType.string));

    // 6. Verify the placed node structure for Set Message
    final setNode = LuminaBlueprintNodeLibrary.place(
      LuminaBlueprintNodeLibrary.variableSet,
      nodeId: 'set_msg_node',
      literals: {'variable': 'Message', 'class': 'Actor:BP_Interactable'},
      context: context,
    );

    expect(setNode.title, equals('Set Message'));
    expect(setNode.category, equals('Variables|BP_Interactable'));
    expect(setNode.inputs.map((p) => p.id), containsAll(['exec_in', 'target', 'value']));
    expect(setNode.outputs.map((p) => p.id), containsAll(['exec_out', 'value']));

    // 7. Verify the placed node structure for Get StaticMeshComponent
    final getCompNode = LuminaBlueprintNodeLibrary.place(
      LuminaBlueprintNodeLibrary.getComponent,
      nodeId: 'get_mesh_node',
      literals: {'component': 'StaticMeshComponent', 'class': 'Actor:BP_Interactable'},
      context: context,
    );

    expect(getCompNode.title, equals('Get StaticMeshComponent'));
    expect(getCompNode.category, equals('Components|BP_Interactable'));
    expect(getCompNode.inputs.any((p) => p.id == 'target' && p.objectClass == 'Actor:BP_Interactable'), isTrue);
    expect(getCompNode.outputs.first.objectClass, equals(LuminaBlueprintObjectClass.component('LuminaStaticMeshComponent')));

    // 8. Validate that a graph with targeted nodes validates cleanly
    final testDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      variables: [
        const LuminaBlueprintVariable(
          name: 'InteractedObject',
          typeName: 'Actor:BP_Interactable',
        ),
      ],
      eventGraph: LuminaBlueprintGraph(
        nodes: [getNode],
        wires: [],
      ),
    );

    final diagnostics = validateBlueprint(testDoc, typeContext: context);
    expect(diagnostics.where((d) => d.isError), isEmpty);

    // 9. Verify BlueprintGraphEditor does not report unknown variable/component problems
    expect(vm.eventGraph.problems(getNode), isEmpty);
    expect(vm.eventGraph.problems(setNode), isEmpty);
    expect(vm.eventGraph.problems(getCompNode), isEmpty);

    // 10. Verify an actually unknown variable DOES report an error
    final unknownNode = LuminaBlueprintNodeLibrary.place(
      LuminaBlueprintNodeLibrary.variableGet,
      nodeId: 'bad_node',
      literals: {'variable': 'NonExistent', 'class': 'Actor:BP_Interactable'},
      context: context,
    );
    expect(vm.eventGraph.problems(unknownNode).map((p) => p.message), contains("Unknown variable 'NonExistent'"));
  });

  test('EditorBlueprintClassRegistry compiles cross-actor variables and passes PIE preflight validation', () async {
    // 1. Create target blueprint: BP_Interactable with variable Message
    final interactableDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      variables: [
        const LuminaBlueprintVariable(name: 'Message', typeName: 'String', defaultValue: 'Press E to Interact'),
      ],
      components: [
        LuminaBlueprintComponent(
          id: 'mesh_comp',
          name: 'StaticMeshComponent',
          type: 'LuminaStaticMeshComponent',
          parentId: null,
          properties: {},
        ),
      ],
    );

    final interactableFile = File('${contentsDir.path}/BP_Interactable.lmas');
    final interactableAsset = LuminaAsset(
      assetId: 'BP_Interactable',
      name: 'BP_Interactable',
      type: AssetType.actor,
      rawPayload: utf8.encode(interactableDoc.toFormattedJson()),
    );
    await interactableFile.writeAsBytes(interactableAsset.toProtoBufferBytes());

    // 2. Create caller blueprint: BP_ThirdPersonCharacter with TargetActor and Get Message wired to Print String
    final characterDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      variables: const [
        LuminaBlueprintVariable(
          name: 'TargetActor',
          typeName: 'Actor:BP_Interactable',
        ),
      ],
      eventGraph: LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNode(
            id: 'begin_play',
            registryId: 'event_beginplay',
            title: 'Event BeginPlay',
          ),
          LuminaBlueprintNode(
            id: 'get_target',
            registryId: LuminaBlueprintNodeLibrary.variableGet,
            title: 'Get TargetActor',
            literals: const {'variable': 'TargetActor'},
          ),
          LuminaBlueprintNode(
            id: 'get_msg',
            registryId: LuminaBlueprintNodeLibrary.variableGet,
            title: 'Get Message',
            literals: const {'variable': 'Message', 'class': 'BP_Interactable'},
          ),
          LuminaBlueprintNode(
            id: 'print_str',
            registryId: 'print_string',
            title: 'Print String',
          ),
        ],
        wires: const [
          LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin_play', fromPinId: 'exec_out', toNodeId: 'print_str', toPinId: 'exec_in'),
          LuminaBlueprintWire(id: 'w2', fromNodeId: 'get_target', fromPinId: 'value', toNodeId: 'get_msg', toPinId: 'target'),
          LuminaBlueprintWire(id: 'w3', fromNodeId: 'get_msg', fromPinId: 'value', toNodeId: 'print_str', toPinId: 'in_string'),
        ],
      ),
    );

    final characterFile = File('${contentsDir.path}/BP_ThirdPersonCharacter.lmas');
    final characterAsset = LuminaAsset(
      assetId: 'BP_ThirdPersonCharacter',
      name: 'BP_ThirdPersonCharacter',
      type: AssetType.actor,
      rawPayload: utf8.encode(characterDoc.toFormattedJson()),
    );
    await characterFile.writeAsBytes(characterAsset.toProtoBufferBytes());

    // 3. Create EditorBlueprintClassRegistry
    final registry = EditorBlueprintClassRegistry(
      projectDir.path,
      inputActions: const [],
    );

    // 4. Validate via BlueprintPlayPreflight
    final blockers = BlueprintPlayPreflight.validate(
      registry,
      const ProjectMapsAndModes(),
      ['Blueprints/BP_ThirdPersonCharacter.lmas'],
    );
    expect(blockers, isEmpty, reason: blockers.map((b) => b.toString()).join('\n'));

    // 5. Test openDocuments in-memory overlay:
    // User adds UnsavedVar to BP_Interactable in editor without saving to disk
    final updatedInteractableDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      variables: [
        const LuminaBlueprintVariable(name: 'Message', typeName: 'String', defaultValue: 'Press E to Interact'),
        const LuminaBlueprintVariable(name: 'UnsavedVar', typeName: 'String', defaultValue: 'Hot Reloaded'),
      ],
      components: [],
    );

    final callerWithUnsavedDoc = LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      variables: const [
        LuminaBlueprintVariable(
          name: 'TargetActor',
          typeName: 'Actor:BP_Interactable',
        ),
      ],
      eventGraph: LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNode(
            id: 'begin_play',
            registryId: 'event_beginplay',
            title: 'Event BeginPlay',
          ),
          LuminaBlueprintNode(
            id: 'get_target',
            registryId: LuminaBlueprintNodeLibrary.variableGet,
            title: 'Get TargetActor',
            literals: const {'variable': 'TargetActor'},
          ),
          LuminaBlueprintNode(
            id: 'get_unsaved',
            registryId: LuminaBlueprintNodeLibrary.variableGet,
            title: 'Get UnsavedVar',
            literals: const {'variable': 'UnsavedVar', 'class': 'BP_Interactable'},
          ),
          LuminaBlueprintNode(
            id: 'print_str',
            registryId: 'print_string',
            title: 'Print String',
          ),
        ],
        wires: const [
          LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin_play', fromPinId: 'exec_out', toNodeId: 'print_str', toPinId: 'exec_in'),
          LuminaBlueprintWire(id: 'w2', fromNodeId: 'get_target', fromPinId: 'value', toNodeId: 'get_unsaved', toPinId: 'target'),
          LuminaBlueprintWire(id: 'w3', fromNodeId: 'get_unsaved', fromPinId: 'value', toNodeId: 'print_str', toPinId: 'in_string'),
        ],
      ),
    );

    final openRegistry = EditorBlueprintClassRegistry(
      projectDir.path,
      inputActions: const [],
      openDocuments: () => {
        'contents/Blueprints/BP_Interactable.lmas': updatedInteractableDoc,
        'contents/Blueprints/BP_ThirdPersonCharacter.lmas': callerWithUnsavedDoc,
      },
    );

    final openBlockers = BlueprintPlayPreflight.validate(
      openRegistry,
      const ProjectMapsAndModes(),
      ['Blueprints/BP_ThirdPersonCharacter.lmas'],
    );
    expect(openBlockers, isEmpty, reason: openBlockers.map((b) => b.toString()).join('\n'));
  });
}
