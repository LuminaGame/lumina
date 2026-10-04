import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina/src/blueprint/vm/blueprint_vm.dart';

void main() {
  group('Blueprint inheritance', () {
    test('child inherits variables and can override class defaults', () {
      final parentDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: const [
          LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 100.0),
          LuminaBlueprintVariable(name: 'Speed', typeName: 'Float', defaultValue: 600.0),
          LuminaBlueprintVariable(name: 'HeroName', typeName: 'String', defaultValue: 'Hero'),
        ],
      );

      final parentCls = LuminaBlueprintClass.fromDocument(parentDoc, name: 'BP_BaseHero');

      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_BaseHero',
        variables: const [
          LuminaBlueprintVariable(name: 'Mana', typeName: 'Float', defaultValue: 50.0),
        ],
        classDefaults: const {
          'Health': 250.0,
          'HeroName': 'Paladin',
        },
      );

      final childCls = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_Paladin',
        resolveClass: (path) => path == 'BP_BaseHero' ? parentCls : null,
      );

      expect(childCls.hasErrors, isFalse);
      expect(childCls.parentBlueprintClass, equals(parentCls));
      expect(childCls.allVariables.map((v) => v.name).toSet(), containsAll(['Health', 'Speed', 'HeroName', 'Mana']));
      expect(childCls.allClassDefaults['Health'], 250.0);
      expect(childCls.allClassDefaults['HeroName'], 'Paladin');

      // Test VM instance
      final instance = childCls.instantiate() as LuminaBlueprintActor;
      expect(instance.variables['Health'], 250.0);
      expect(instance.variables['Speed'], 600.0);
      expect(instance.variables['HeroName'], 'Paladin');
      expect(instance.variables['Mana'], 50.0);
    });

    test('child node graph can access and modify inherited variables', () {
      final parentDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: const [
          LuminaBlueprintVariable(name: 'Health', typeName: 'Float', defaultValue: 100.0),
        ],
      );

      final parentCls = LuminaBlueprintClass.fromDocument(parentDoc, name: 'BP_Base');

      // Child graph has Event BeginPlay -> Set Health (Health + 25.0)
      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_Base',
        eventGraph: LuminaBlueprintGraph(
          nodes: [
            LuminaBlueprintNode(
              id: 'begin_play',
              registryId: 'event_beginplay',
              title: 'Event BeginPlay',
            ),
            LuminaBlueprintNode(
              id: 'get_health',
              registryId: LuminaBlueprintNodeLibrary.variableGet,
              title: 'Get Health',
              literals: const {'variable': 'Health'},
            ),
            LuminaBlueprintNode(
              id: 'add',
              registryId: 'float_add',
              title: 'Add',
              literals: const {'b': 25.0},
            ),
            LuminaBlueprintNode(
              id: 'set_health',
              registryId: LuminaBlueprintNodeLibrary.variableSet,
              title: 'Set Health',
              literals: const {'variable': 'Health'},
            ),
          ],
          wires: const [
            LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin_play', fromPinId: 'exec_out', toNodeId: 'set_health', toPinId: 'exec_in'),
            LuminaBlueprintWire(id: 'w2', fromNodeId: 'get_health', fromPinId: 'value', toNodeId: 'add', toPinId: 'a'),
            LuminaBlueprintWire(id: 'w3', fromNodeId: 'add', fromPinId: 'return_value', toNodeId: 'set_health', toPinId: 'value'),
          ],
        ),
      );

      final childCls = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_Derived',
        resolveClass: (path) => path == 'BP_Base' ? parentCls : null,
      );

      expect(childCls.hasErrors, isFalse);

      final instance = childCls.instantiate() as LuminaBlueprintActor;
      expect(instance.variables['Health'], 100.0);
      instance.onBeginPlay();
      expect(instance.variables['Health'], 125.0);
    });

    test('child attaches components to inherited parent components', () {
      final parentDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(
            id: 'root_scene',
            name: 'DefaultSceneRoot',
            type: 'LuminaSceneComponent',
            isSceneComponent: true,
          ),
          LuminaBlueprintComponent(
            id: 'parent_comp',
            name: 'ParentComp',
            type: 'LuminaSceneComponent',
            parentId: 'root_scene',
            isSceneComponent: true,
          ),
        ],
      );

      final parentCls = LuminaBlueprintClass.fromDocument(parentDoc, name: 'BP_ParentActor');

      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_ParentActor',
        components: [
          LuminaBlueprintComponent(
            id: 'child_light',
            name: 'ChildLight',
            type: 'LuminaPointLightComponent',
            parentId: 'parent_comp',
            isSceneComponent: true,
          ),
        ],
      );

      final childCls = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_ChildActor',
        resolveClass: (path) => path == 'BP_ParentActor' ? parentCls : null,
      );

      expect(childCls.hasErrors, isFalse);
      expect(childCls.allComponents.length, 3);

      final instance = childCls.instantiate() as LuminaBlueprintActor;
      final light = instance.blueprintComponents['child_light'];
      final parentComp = instance.blueprintComponents['parent_comp'];
      expect(light, isNotNull);
      expect(parentComp, isNotNull);
      expect(light, isA<LuminaPointLightComponent>());
      expect(parentComp, isA<LuminaSceneComponent>());
      expect((light as LuminaPointLightComponent).parentComponent, equals(parentComp));
    });

    test('multi-level hierarchy resolves rootEngineClass correctly', () {
      final grandParentDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaCharacter',
        variables: const [
          LuminaBlueprintVariable(name: 'GVar', typeName: 'Int', defaultValue: 1),
        ],
      );
      final grandParent = LuminaBlueprintClass.fromDocument(grandParentDoc, name: 'BP_GrandParent');

      final parentDoc = LuminaBlueprintDocument(
        parentClass: 'BP_GrandParent',
        variables: const [
          LuminaBlueprintVariable(name: 'PVar', typeName: 'Int', defaultValue: 2),
        ],
      );
      final parent = LuminaBlueprintClass.fromDocument(
        parentDoc,
        name: 'BP_Parent',
        resolveClass: (p) => p == 'BP_GrandParent' ? grandParent : null,
      );

      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_Parent',
        variables: const [
          LuminaBlueprintVariable(name: 'CVar', typeName: 'Int', defaultValue: 3),
        ],
      );
      final child = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_Child',
        resolveClass: (p) => p == 'BP_Parent' ? parent : (p == 'BP_GrandParent' ? grandParent : null),
      );

      expect(child.rootEngineClass, 'LuminaCharacter');
      expect(child.allVariables.map((v) => v.name).toList(), containsAll(['GVar', 'PVar', 'CVar']));

      final instance = child.instantiate() as LuminaBlueprintCharacter;
      expect(instance, isA<LuminaBlueprintCharacter>());
      expect(instance.variables['GVar'], 1);
      expect(instance.variables['PVar'], 2);
      expect(instance.variables['CVar'], 3);
    });

    test('circular inheritance is detected and reported as diagnostic error', () {
      final docA = LuminaBlueprintDocument(parentClass: 'BP_B');
      final docB = LuminaBlueprintDocument(parentClass: 'BP_A');

      LuminaBlueprintClass? clsA;
      LuminaBlueprintClass? clsB;

      LuminaBlueprintClass? resolver(String path) {
        if (path == 'BP_B') {
          return clsB ??= LuminaBlueprintClass.fromDocument(
            docB,
            name: 'BP_B',
            resolveClass: resolver,
            visitedClassNames: {'BP_A'},
          );
        }
        if (path == 'BP_A') {
          return clsA ??= LuminaBlueprintClass.fromDocument(
            docA,
            name: 'BP_A',
            resolveClass: resolver,
            visitedClassNames: {'BP_B'},
          );
        }
        return null;
      }

      clsA = LuminaBlueprintClass.fromDocument(
        docA,
        name: 'BP_A',
        resolveClass: resolver,
      );

      expect(clsA!.diagnostics.any((d) => d.message.contains('Circular inheritance')), isTrue);
    });

    test('codegen emits extends parent Blueprint class and blueprintParentClasses', () {
      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_BaseHero',
        variables: const [
          LuminaBlueprintVariable(name: 'Shield', typeName: 'Float', defaultValue: 100.0),
        ],
        classDefaults: const {
          'Health': 200.0,
        },
      );

      final generator = const BlueprintDartGenerator();
      final result = generator.generate(
        childDoc,
        className: 'BP_Paladin',
        blueprintClasses: {
          'BP_BaseHero': const BlueprintClassRef('BP_BaseHero', 'package:game/blueprints/bp_base_hero.dart'),
        },
      );

      expect(result.ok, isTrue);
      final code = result.code!;
      expect(code, contains("import 'package:game/blueprints/bp_base_hero.dart';"));
      expect(code, contains('class BP_Paladin extends BP_BaseHero {'));
      expect(code, contains("List<String> get blueprintParentClasses => ['BP_BaseHero', ...super.blueprintParentClasses];"));
      expect(code, contains('health = 200.0;'));
      expect(code, contains('blueprintComponentTree = ['));
      expect(code, contains('..._components,'));
    });

    test('Cast To and isA succeed for inherited parent Blueprint classes', () {
      final parentDoc = LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        variables: const [
          LuminaBlueprintVariable(name: 'InteractableId', typeName: 'String', defaultValue: 'id_1'),
        ],
      );
      final parentCls = LuminaBlueprintClass.fromDocument(parentDoc, name: 'BP_Interactable');

      final childDoc = LuminaBlueprintDocument(
        parentClass: 'BP_Interactable',
        variables: const [
          LuminaBlueprintVariable(name: 'TowerHeight', typeName: 'Float', defaultValue: 1000.0),
        ],
      );
      final childCls = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_LightTower',
        resolveClass: (p) => p == 'BP_Interactable' ? parentCls : null,
      );

      final tower = childCls.instantiate();
      expect(LuminaBlueprintFunctionLibrary.classOf(tower), 'Actor:BP_LightTower');
      expect(LuminaBlueprintFunctionLibrary.isA(tower, 'Actor:BP_LightTower'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.isA(tower, 'Actor:BP_Interactable'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.isA(tower, 'BP_Interactable'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.isA(tower, 'Actor:LuminaActor'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.isA(tower, 'Actor:BP_Other'), isFalse);

      expect(LuminaBlueprintFunctionLibrary.castTo(tower, 'Actor:BP_Interactable'), same(tower));
      expect(LuminaBlueprintFunctionLibrary.castTo(tower, 'BP_Interactable'), same(tower));
      expect(LuminaBlueprintFunctionLibrary.castTo(tower, 'Actor:BP_LightTower'), same(tower));
      expect(LuminaBlueprintFunctionLibrary.castTo(tower, 'Actor:LuminaActor'), same(tower));
      expect(LuminaBlueprintFunctionLibrary.castTo(tower, 'Actor:BP_Other'), isNull);

      final chain = LuminaBlueprintFunctionLibrary.actorClassChain(tower);
      expect(chain, containsAllInOrder(['BP_LightTower', 'BP_Interactable', 'LuminaActor']));
    });

    test('multi-level hierarchy Cast To succeeds across all ancestor Blueprints', () {
      final grandParentDoc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter');
      final grandParent = LuminaBlueprintClass.fromDocument(grandParentDoc, name: 'BP_GrandParent');

      final parentDoc = LuminaBlueprintDocument(parentClass: 'BP_GrandParent');
      final parent = LuminaBlueprintClass.fromDocument(
        parentDoc,
        name: 'BP_Parent',
        resolveClass: (p) => p == 'BP_GrandParent' ? grandParent : null,
      );

      final childDoc = LuminaBlueprintDocument(parentClass: 'BP_Parent');
      final childCls = LuminaBlueprintClass.fromDocument(
        childDoc,
        name: 'BP_Child',
        resolveClass: (p) => p == 'BP_Parent' ? parent : (p == 'BP_GrandParent' ? grandParent : null),
      );

      final child = childCls.instantiate();
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:BP_Parent'), same(child));
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:BP_GrandParent'), same(child));
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:LuminaCharacter'), same(child));
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:LuminaPawn'), same(child));
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:LuminaActor'), same(child));
      expect(LuminaBlueprintFunctionLibrary.castTo(child, 'Actor:BP_Unrelated'), isNull);
    });

    test('Cast To node in graph routes execution to cast_succeeded when casting child to parent Blueprint', () {
      final interactableDoc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
      final interactableCls = LuminaBlueprintClass.fromDocument(interactableDoc, name: 'BP_Interactable');

      final lightTowerDoc = LuminaBlueprintDocument(parentClass: 'BP_Interactable');
      final lightTowerCls = LuminaBlueprintClass.fromDocument(
        lightTowerDoc,
        name: 'BP_LightTower',
        resolveClass: (p) => p == 'BP_Interactable' ? interactableCls : null,
      );
      final tower = lightTowerCls.instantiate();

      const variables = [LuminaBlueprintVariable(name: 'HitActor', typeName: 'Object')];
      const context = LuminaBlueprintTypeContext(variables: variables);
      LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
          LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);

      final casterDoc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
        place('event_beginplay', 'begin'),
        place(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'HitActor'}),
        place(LuminaBlueprintNodeLibrary.castTo, 'cast', {'class': 'Actor:BP_Interactable'}),
        place('print_string', 'ok', {'in_string': 'cast_succeeded'}),
        place('print_string', 'fail', {'in_string': 'cast_failed'}),
      ], wires: [
        const LuminaBlueprintWire(id: 'w1', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'cast', toPinId: 'exec_in'),
        const LuminaBlueprintWire(id: 'w2', fromNodeId: 'get', fromPinId: 'value', toNodeId: 'cast', toPinId: 'object'),
        const LuminaBlueprintWire(id: 'w3', fromNodeId: 'cast', fromPinId: 'cast_succeeded', toNodeId: 'ok', toPinId: 'exec_in'),
        const LuminaBlueprintWire(id: 'w4', fromNodeId: 'cast', fromPinId: 'cast_failed', toNodeId: 'fail', toPinId: 'exec_in'),
      ]));

      final casterCls = LuminaBlueprintClass.fromDocument(casterDoc, name: 'BP_Caster');
      final caster = casterCls.instantiate() as LuminaBlueprintInstance;
      caster.variables['HitActor'] = tower;

      final trace = <LuminaBlueprintTraceEvent>[];
      caster.trace = trace.add;
      caster.onBeginPlay();

      expect(trace.any((t) => t.printed == 'cast_succeeded'), isTrue,
          reason: 'Casting BP_LightTower to BP_Interactable must succeed');
      expect(trace.any((t) => t.printed == 'cast_failed'), isFalse);
      final castEvent = trace.firstWhere((t) => t.registryId == 'cast_to');
      expect(castEvent.values['as_class'], same(tower));
    });
  });
}
