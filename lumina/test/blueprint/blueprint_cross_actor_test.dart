import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina/src/blueprint/blueprint.dart';
import 'package:lumina/src/blueprint/vm/blueprint_vm.dart';

void main() {
  group('Blueprint cross-actor variable and component access', () {
    const interactableVars = [
      LuminaBlueprintVariable(name: 'Message', typeName: 'String', defaultValue: 'Press E to interact'),
      LuminaBlueprintVariable(name: 'IsCollectable', typeName: 'Bool', defaultValue: true),
    ];

    const interactableComps = [
      LuminaBlueprintComponentRef(name: 'StaticMeshComponent', componentClass: 'LuminaStaticMeshComponent'),
    ];

    final context = LuminaBlueprintTypeContext(
      variableOwners: {'BP_Interactable': interactableVars},
      componentOwners: {'BP_Interactable': interactableComps},
    );

    test('type context resolves member variables and components by raw and Actor: prefixed class name', () {
      expect(context.variableOf('BP_Interactable', 'Message')?.typeName, 'String');
      expect(context.variableOf('Actor:BP_Interactable', 'IsCollectable')?.typeName, 'Bool');
      expect(context.variableOf('Actor:BP_Interactable', 'NonExistent'), isNull);

      expect(context.componentOf('BP_Interactable', 'StaticMeshComponent')?.componentClass, 'LuminaStaticMeshComponent');
      expect(context.componentOf('Actor:BP_Interactable', 'StaticMeshComponent')?.componentClass, 'LuminaStaticMeshComponent');
      expect(context.componentOf('Actor:BP_Interactable', 'UnknownComp'), isNull);
    });

    test('NodeLibrary creates target pin on cross-actor variableGet, variableSet, and getComponent', () {
      final getVarNode = LuminaBlueprintNodeLibrary.place(
        LuminaBlueprintNodeLibrary.variableGet,
        nodeId: 'get_msg',
        literals: {'variable': 'Message', 'class': 'Actor:BP_Interactable'},
        context: context,
      );
      final getPins = LuminaBlueprintNodeLibrary.pinsOf(getVarNode, context)!;
      expect(getPins.inputs.any((p) => p.id == 'target' && p.objectClass == 'Actor:BP_Interactable'), isTrue);
      expect(getPins.outputs.any((p) => p.id == 'value' && p.type == LuminaPinType.string), isTrue);

      final setVarNode = LuminaBlueprintNodeLibrary.place(
        LuminaBlueprintNodeLibrary.variableSet,
        nodeId: 'set_msg',
        literals: {'variable': 'Message', 'class': 'Actor:BP_Interactable'},
        context: context,
      );
      final setPins = LuminaBlueprintNodeLibrary.pinsOf(setVarNode, context)!;
      expect(setPins.inputs.any((p) => p.id == 'target' && p.objectClass == 'Actor:BP_Interactable'), isTrue);
      expect(setPins.inputs.any((p) => p.id == 'value' && p.type == LuminaPinType.string), isTrue);

      final getCompNode = LuminaBlueprintNodeLibrary.place(
        'get_component',
        nodeId: 'get_comp',
        literals: {'component': 'StaticMeshComponent', 'class': 'Actor:BP_Interactable'},
        context: context,
      );
      final compPins = LuminaBlueprintNodeLibrary.pinsOf(getCompNode, context)!;
      expect(compPins.inputs.any((p) => p.id == 'target' && p.objectClass == 'Actor:BP_Interactable'), isTrue);
      expect(compPins.outputs.any((p) => p.id == 'return_value' && p.objectClass == 'Component:LuminaStaticMeshComponent'), isTrue);
    });

    test('VM execution can read and write cross-actor variables on target instance', () {
      // 1. Create BP_Interactable class & instance
      final interactableDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: interactableVars,
      );
      final interactableCls = LuminaBlueprintClass.fromDocument(interactableDoc, name: 'BP_Interactable');
      final targetActor = interactableCls.instantiate() as LuminaBlueprintActor;
      expect(targetActor.variables['Message'], 'Press E to interact');

      // 2. Create BP_Caller with variable InteractedObject (Actor:BP_Interactable)
      // and graph that reads Message, appends '!', and writes it back to target
      final callerDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: const [
          LuminaBlueprintVariable(name: 'InteractedObject', typeName: 'Actor:BP_Interactable'),
        ],
        eventGraph: LuminaBlueprintGraph(
          nodes: [
            LuminaBlueprintNode(
              id: 'begin_play',
              registryId: 'event_beginplay',
              title: 'Event BeginPlay',
            ),
            LuminaBlueprintNode(
              id: 'get_interacted',
              registryId: LuminaBlueprintNodeLibrary.variableGet,
              title: 'Get InteractedObject',
              literals: const {'variable': 'InteractedObject'},
            ),
            LuminaBlueprintNode(
              id: 'get_target_msg',
              registryId: LuminaBlueprintNodeLibrary.variableGet,
              title: 'Get Message',
              literals: const {'variable': 'Message', 'class': 'BP_Interactable'},
            ),
            LuminaBlueprintNode(
              id: 'set_target_msg',
              registryId: LuminaBlueprintNodeLibrary.variableSet,
              title: 'Set Message',
              literals: const {'variable': 'Message', 'class': 'BP_Interactable', 'value': 'Door Opened!'},
            ),
          ],
          wires: const [
            LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin_play', fromPinId: 'exec_out', toNodeId: 'set_target_msg', toPinId: 'exec_in'),
            LuminaBlueprintWire(id: 'w2', fromNodeId: 'get_interacted', fromPinId: 'value', toNodeId: 'set_target_msg', toPinId: 'target'),
          ],
        ),
      );

      final callerCls = LuminaBlueprintClass.fromDocument(
        callerDoc,
        name: 'BP_Caller',
        variableOwners: {'BP_Interactable': interactableVars},
        componentOwners: {'BP_Interactable': interactableComps},
      );
      expect(callerCls.hasErrors, isFalse, reason: '${callerCls.diagnostics}');

      final callerActor = callerCls.instantiate() as LuminaBlueprintActor;
      callerActor.variables['InteractedObject'] = targetActor;

      callerActor.onBeginPlay();

      expect(targetActor.variables['Message'], 'Door Opened!');
    });

    test('codegen emits targeted variable reads, writes, and component gets', () {
      final doc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: const [
          LuminaBlueprintVariable(name: 'TargetActor', typeName: 'Actor:BP_Interactable'),
          LuminaBlueprintVariable(name: 'TargetComp', typeName: 'Object'),
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
              id: 'set_msg',
              registryId: LuminaBlueprintNodeLibrary.variableSet,
              title: 'Set Message',
              literals: const {'variable': 'Message', 'class': 'BP_Interactable', 'value': 'New Value'},
            ),
            LuminaBlueprintNode(
              id: 'get_comp',
              registryId: 'get_component',
              title: 'Get StaticMeshComponent',
              literals: const {'component': 'StaticMeshComponent', 'class': 'BP_Interactable'},
            ),
            LuminaBlueprintNode(
              id: 'set_comp',
              registryId: LuminaBlueprintNodeLibrary.variableSet,
              title: 'Set TargetComp',
              literals: const {'variable': 'TargetComp'},
            ),
          ],
          wires: const [
            LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin_play', fromPinId: 'exec_out', toNodeId: 'set_msg', toPinId: 'exec_in'),
            LuminaBlueprintWire(id: 'w2', fromNodeId: 'get_target', fromPinId: 'value', toNodeId: 'set_msg', toPinId: 'target'),
            LuminaBlueprintWire(id: 'w3', fromNodeId: 'set_msg', fromPinId: 'exec_out', toNodeId: 'set_comp', toPinId: 'exec_in'),
            LuminaBlueprintWire(id: 'w4', fromNodeId: 'get_target', fromPinId: 'value', toNodeId: 'get_comp', toPinId: 'target'),
            LuminaBlueprintWire(id: 'w5', fromNodeId: 'get_comp', fromPinId: 'return_value', toNodeId: 'set_comp', toPinId: 'value'),
          ],
        ),
      );

      final generator = const BlueprintDartGenerator();
      final result = generator.generate(
        doc,
        className: 'BP_Caller',
        blueprintClasses: {
          'BP_Interactable': const BlueprintClassRef('BP_Interactable', 'package:game/blueprints/bp_interactable.dart'),
        },
        variableOwners: {
          'BP_Interactable': const [
            LuminaBlueprintVariable(name: 'Message', typeName: 'String'),
          ],
        },
        componentOwners: {
          'BP_Interactable': const [
            LuminaBlueprintComponentRef(name: 'StaticMeshComponent', componentClass: 'LuminaStaticMeshComponent'),
          ],
        },
      );

      expect(result.ok, isTrue, reason: '${result.issues}');
      final code = result.code!;
      expect(code, contains(r'.message = '));
      expect(code, contains(r'LuminaBlueprintFunctionLibrary.getComponent('));
    });

    test('type context resolves inherited member variables, components, and events through actorParents', () {
      final inheritContext = LuminaBlueprintTypeContext(
        selfClass: 'Actor:BP_Caller',
        actorParents: {
          'BP_DerivedInteractable': 'BP_Interactable',
          'BP_Interactable': 'LuminaActor',
        },
        variableOwners: {
          'BP_Interactable': interactableVars,
          'BP_DerivedInteractable': const [
            LuminaBlueprintVariable(name: 'DerivedProp', typeName: 'Int', defaultValue: 42),
          ],
        },
        componentOwners: {
          'BP_Interactable': interactableComps,
        },
      );

      expect(inheritContext.variableOf('BP_DerivedInteractable', 'DerivedProp')?.typeName, 'Int');
      expect(inheritContext.variableOf('BP_DerivedInteractable', 'Message')?.typeName, 'String');
      expect(inheritContext.variableOf('Actor:BP_DerivedInteractable', 'IsCollectable')?.typeName, 'Bool');
      expect(inheritContext.componentOf('BP_DerivedInteractable', 'StaticMeshComponent')?.componentClass, 'LuminaStaticMeshComponent');
    });

    test('validator resolves cross-actor variable and component with class literal', () {
      final doc = LuminaBlueprintDocument(
        parentClass: 'LuminaCharacter',
        variables: const [
          LuminaBlueprintVariable(name: 'InteractableRef', typeName: 'Actor:BP_Interactable'),
        ],
        eventGraph: LuminaBlueprintGraph(
          nodes: [
            LuminaBlueprintNode(
              id: 'get_ref',
              title: 'Get InteractableRef',
              registryId: LuminaBlueprintNodeLibrary.variableGet,
              literals: const {'variable': 'InteractableRef'},
            ),
            LuminaBlueprintNode(
              id: 'get_msg',
              title: 'Get Message',
              registryId: LuminaBlueprintNodeLibrary.variableGet,
              literals: const {'variable': 'Message', 'class': 'BP_Interactable'},
            ),
          ],
          wires: const [
            LuminaBlueprintWire(id: 'w1', fromNodeId: 'get_ref', fromPinId: 'value', toNodeId: 'get_msg', toPinId: 'target'),
          ],
        ),
      );

      final docContext = LuminaBlueprintTypeContext.forDocument(
        doc,
        variableOwners: {'BP_Interactable': interactableVars},
        componentOwners: {'BP_Interactable': interactableComps},
      );
      final diags = validateBlueprint(doc, typeContext: docContext);
      expect(diags.where((d) => d.isError), isEmpty);
    });
  });
}
