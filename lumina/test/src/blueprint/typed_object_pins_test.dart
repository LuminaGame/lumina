import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Object pins and variables carry a class; incompatible
/// classes cannot be wired; Cast bridges them; Is Valid sees null.
void main() {
  const hud = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
    LuminaBlueprintWidgetElement(name: 'FPSCounter', typeName: 'text', props: {'text': 'FPS: 0'}),
    LuminaBlueprintWidgetElement(name: 'Health', typeName: 'progressBar', props: {'percent': 1.0}),
  ]);
  const menu = LuminaBlueprintWidgetClass(name: 'WBP_Menu');

  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  group('model', () {
    test('a variable declared Widget:WBP_HUD is an object with that class and round-trips unchanged', () {
      const v = LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD');
      expect(v.type, LuminaPinType.object);
      expect(v.objectClass, 'Widget:WBP_HUD');
      expect(const LuminaBlueprintVariable(name: 'Any', typeName: 'Object').objectClass, isNull);
      expect(const LuminaBlueprintVariable(name: 'A', typeName: 'Actor').objectClass, 'Actor:LuminaActor');
      expect(const LuminaBlueprintVariable(name: 'C', typeName: 'Component:LuminaSpringArmComponent').type,
          LuminaPinType.object);
      expect(const LuminaBlueprintVariable(name: 'E', typeName: 'WidgetElement:text').objectClass, 'WidgetElement:text');

      final doc = LuminaBlueprintDocument(variables: [v], eventGraph: LuminaBlueprintGraph(nodes: [
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet,
            nodeId: 'g', literals: {'variable': 'HudWidget'}, context: const LuminaBlueprintTypeContext(variables: [v])),
      ]));
      final json = jsonEncode(doc.toJson());
      expect(json, contains('"type":"Widget:WBP_HUD"'));
      expect(json, contains('"class":"Widget:WBP_HUD"'), reason: 'the placed Get pin stores its class');
      final back = LuminaBlueprintDocument.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(back.variables.single.typeName, 'Widget:WBP_HUD');
      expect(back.eventGraph.node('g')!.pin('value')!.objectClass, 'Widget:WBP_HUD');
      expect(jsonEncode(back.toJson()), json);
    });

    test('display names and assignability follow the class kind and the parent chain', () {
      expect(LuminaBlueprintObjectClass.displayName('Widget:WBP_HUD'), 'Widget (WBP_HUD)');
      expect(LuminaBlueprintObjectClass.displayName('WidgetElement:text'), 'Text Block');
      expect(LuminaBlueprintObjectClass.displayName('Component:LuminaSpringArmComponent'), 'Spring Arm');
      expect(LuminaBlueprintObjectClass.displayName('Actor:BP_Door'), 'BP_Door');
      expect(LuminaBlueprintObjectClass.displayName(null), 'Object');

      expect(LuminaBlueprintObjectClass.isAssignable('Widget:WBP_HUD', null), isTrue, reason: 'typed → any');
      expect(LuminaBlueprintObjectClass.isAssignable(null, 'Widget:WBP_HUD'), isFalse, reason: 'any → typed');
      expect(LuminaBlueprintObjectClass.assignError(null, 'Widget:WBP_HUD'), contains('needs a Cast'));
      expect(LuminaBlueprintObjectClass.isAssignable('Widget:WBP_HUD', 'Widget:WBP_HUD'), isTrue);
      expect(LuminaBlueprintObjectClass.isAssignable('Widget:WBP_HUD', 'Widget:WBP_Menu'), isFalse);
      expect(LuminaBlueprintObjectClass.isAssignable('Widget:WBP_HUD', 'Widget'), isTrue, reason: 'any widget');
      expect(LuminaBlueprintObjectClass.isAssignable('Actor:BP_Door', 'Actor:LuminaActor'), isTrue);
      expect(LuminaBlueprintObjectClass.isAssignable('Actor:LuminaCharacter', 'Actor:LuminaPawn'), isTrue);
      expect(LuminaBlueprintObjectClass.isAssignable('Actor:LuminaPawn', 'Actor:LuminaCharacter'), isFalse);
      expect(LuminaBlueprintObjectClass.isAssignable('Actor:BP_Door', 'Actor:LuminaCharacter'), isFalse);
      expect(
          LuminaBlueprintObjectClass.isAssignable('Actor:BP_Door', 'Actor:LuminaCharacter',
              parents: const {'BP_Door': 'LuminaCharacter'}),
          isTrue,
          reason: 'the class registry gives the parent chain');
      expect(LuminaBlueprintObjectClass.isAssignable('Component:LuminaSpringArmComponent', 'Component:LuminaSceneComponent'),
          isTrue);
      expect(LuminaBlueprintObjectClass.assignError('Widget:WBP_HUD', 'WidgetElement:text'),
          'Cannot connect Widget (WBP_HUD) to Text Block.');
    });
  });

  group('node library', () {
    final context = LuminaBlueprintTypeContext(
      variables: const [
        LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD'),
        LuminaBlueprintVariable(name: 'MenuWidget', typeName: 'Widget:WBP_Menu'),
        LuminaBlueprintVariable(name: 'Anything', typeName: 'Object'),
      ],
      widgetClasses: const [hud, menu],
    );

    test('Create Widget with a class literal returns Widget:<class>; wiring is refused across classes', () {
      final create = LuminaBlueprintNodeLibrary.place('create_widget',
          nodeId: 'create', literals: {'class': 'WBP_HUD'}, context: context);
      expect(create.pin('return_value')!.objectClass, 'Widget:WBP_HUD');
      final setMenu = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableSet,
          nodeId: 'set_menu', literals: {'variable': 'MenuWidget'}, context: context);
      final setHud = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableSet,
          nodeId: 'set_hud', literals: {'variable': 'HudWidget'}, context: context);
      final setAny = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableSet,
          nodeId: 'set_any', literals: {'variable': 'Anything'}, context: context);
      final getAny = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet,
          nodeId: 'get_any', literals: {'variable': 'Anything'}, context: context);
      final begin = LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin');

      LuminaBlueprintPinSpec out(LuminaBlueprintNode n, String pin) =>
          LuminaBlueprintNodeLibrary.pinsOf(n, context)!.outputs.firstWhere((p) => p.id == pin);
      LuminaBlueprintPinSpec inp(LuminaBlueprintNode n, String pin) =>
          LuminaBlueprintNodeLibrary.pinsOf(n, context)!.inputs.firstWhere((p) => p.id == pin);
      expect(LuminaBlueprintNodeLibrary.canConnect(out(create, 'return_value'), inp(setHud, 'value'), context: context), isTrue);
      expect(LuminaBlueprintNodeLibrary.canConnect(out(create, 'return_value'), inp(setAny, 'value'), context: context), isTrue);
      expect(LuminaBlueprintNodeLibrary.connectionError(out(create, 'return_value'), inp(setMenu, 'value'), context: context),
          'Cannot connect Widget (WBP_HUD) to Widget (WBP_Menu).');
      expect(LuminaBlueprintNodeLibrary.connectionError(out(getAny, 'value'), inp(setHud, 'value'), context: context),
          contains('needs a Cast'));

      // The validator says the same about a stored document.
      final doc = LuminaBlueprintDocument(
        variables: context.variables,
        eventGraph: LuminaBlueprintGraph(nodes: [begin, create, setMenu, setAny, getAny, setHud], wires: [
          wire('begin', 'exec_out', 'create', 'exec_in'),
          wire('create', 'exec_out', 'set_menu', 'exec_in'),
          wire('create', 'return_value', 'set_menu', 'value'),
          wire('set_menu', 'exec_out', 'set_any', 'exec_in'),
          wire('create', 'return_value', 'set_any', 'value'),
          wire('set_any', 'exec_out', 'set_hud', 'exec_in'),
          wire('get_any', 'value', 'set_hud', 'value'),
        ]),
      );
      final errors = validateBlueprint(doc, typeContext: context).where((d) => d.isError).toList();
      expect(errors.map((e) => e.nodeId), ['set_menu', 'set_hud']);
      expect(errors.first.message, 'Cannot connect Widget (WBP_HUD) to Widget (WBP_Menu).');
      expect(errors.last.message, contains('needs a Cast'));
    });

    test('Get <Element> is typed from the widget class; element nodes accept only their element type', () {
      final get = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getWidgetElement,
          nodeId: 'fps', literals: {'element': 'FPSCounter'}, context: context);
      expect(get.title, 'Get FPSCounter');
      expect(get.category, 'Widget|WBP_HUD');
      expect(get.pin('target')!.objectClass, 'Widget:WBP_HUD');
      expect(get.pin('return_value')!.objectClass, 'WidgetElement:text');
      final health = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getWidgetElement,
          nodeId: 'health', literals: {'element': 'Health'}, context: context);
      expect(health.pin('return_value')!.objectClass, 'WidgetElement:progressBar');

      final fpsOut = LuminaBlueprintNodeLibrary.pinsOf(get, context)!.outputs.single;
      LuminaBlueprintPinSpec target(String id) =>
          LuminaBlueprintNodeLibrary.spec(id)!.inputs.firstWhere((p) => p.id == 'target');
      expect(LuminaBlueprintNodeLibrary.canConnect(fpsOut, target('set_element_text')), isTrue);
      expect(LuminaBlueprintNodeLibrary.canConnect(fpsOut, target('set_element_visibility')), isTrue, reason: 'common');
      expect(LuminaBlueprintNodeLibrary.connectionError(fpsOut, target('set_element_percent')),
          'Cannot connect Text Block to Progress Bar.');
      expect(LuminaBlueprintNodeLibrary.spec('set_element_text')!.title, 'Set Text (Text)');
      expect(LuminaBlueprintNodeLibrary.spec('set_element_color')!.title, 'Set Color and Opacity');
      expect(LuminaBlueprintNodeLibrary.spec('set_element_percent')!.title, 'Set Percent');
    });

    test('every new node has a spec, a behaviour or intrinsic, and a call shape', () {
      for (final id in const [
        'is_valid', 'is_valid_branch', 'cast_to', 'get_class_name', 'is_a', 'get_display_name',
        'get_widget_element', 'set_element_text', 'get_element_text', 'set_element_percent',
        'get_component', 'get_component_by_class', 'add_component', 'set_target_arm_length', 'set_camera_active',
        'set_max_walk_speed', 'launch_character', 'set_movement_mode', 'crouch', 'un_crouch', 'is_crouched',
      ]) {
        final spec = LuminaBlueprintNodeLibrary.spec(id);
        expect(spec, isNotNull, reason: id);
        final intrinsic = LuminaBlueprintNodeLibrary.intrinsics.contains(id);
        expect(intrinsic || LuminaBlueprintFunctionLibrary.functions.containsKey(id), isTrue, reason: id);
        expect(intrinsic || LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: '$id call shape');
      }
      expect(LuminaBlueprintNodeLibrary.spec('set_widget_text')!.deprecation, contains('Set Text (Text)'));
    });
  });

  group('VM', () {
    LuminaWorld world() {
      final w = LuminaWorld(worldType: LuminaWorldType.game);
      w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
      return w;
    }

    setUp(() => LuminaWidgetClassRegistry.registerAll(const [hud, menu]));
    tearDown(LuminaWidgetClassRegistry.clear);

    test('Is Valid on an unset widget variable is false; the flow takes Is Not Valid until Create Widget', () {
      const variables = [LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD')];
      const context = LuminaBlueprintTypeContext(variables: variables);
      LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
          LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
      final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
        place('event_tick', 'tick'),
        place(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'HudWidget'}),
        place('is_valid', 'valid'),
        place(LuminaBlueprintNodeLibrary.isValidBranch, 'check'),
        place('print_string', 'yes', {'in_string': 'valid'}),
        place('create_widget', 'create', {'class': 'WBP_HUD'}),
        place(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'HudWidget'}),
      ], wires: [
        wire('tick', 'exec_tick_out', 'check', 'exec_in'),
        wire('get', 'value', 'check', 'input_object'),
        wire('get', 'value', 'valid', 'input_object'),
        wire('check', 'is_valid', 'yes', 'exec_in'),
        wire('check', 'is_not_valid', 'create', 'exec_in'),
        wire('create', 'exec_out', 'set', 'exec_in'),
        wire('create', 'return_value', 'set', 'value'),
      ]));
      final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Hud');
      expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
      final w = world();
      final actor = cls.instantiate() as LuminaBlueprintInstance;
      final trace = <LuminaBlueprintTraceEvent>[];
      actor.trace = trace.add;
      w.persistentLevel.registerActor(actor);
      w.beginPlay();
      expect(actor.variables['HudWidget'], isNull);
      expect(LuminaBlueprintInterpreter.evaluateInput(actor, 'valid', 'input_object'), isNull);
      w.tick(1 / 60);
      expect(trace.where((t) => t.printed == 'valid'), isEmpty, reason: 'first tick: not valid → Create Widget');
      expect(actor.variables['HudWidget'], isA<Map<String, Object?>>());
      w.tick(1 / 60);
      expect(trace.where((t) => t.printed == 'valid').length, 1, reason: 'second tick: valid');
      expect(trace.where((t) => t.registryId == 'create_widget').length, 1);
      w.cleanup();
    });

    test('Cast To Actor:BP_Door succeeds on a BP_Door and fails on a plain LuminaActor', () {
      final door = LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument(), name: 'BP_Door').instantiate();
      final plain = LuminaActor();
      expect(LuminaBlueprintFunctionLibrary.classOf(door), 'Actor:BP_Door');
      expect(LuminaBlueprintFunctionLibrary.castTo(door, 'Actor:BP_Door'), same(door));
      expect(LuminaBlueprintFunctionLibrary.castTo(door, 'Actor:LuminaActor'), same(door));
      expect(LuminaBlueprintFunctionLibrary.castTo(plain, 'Actor:BP_Door'), isNull);
      expect(LuminaBlueprintFunctionLibrary.castTo(null, 'Actor:BP_Door'), isNull);
      expect(LuminaBlueprintFunctionLibrary.isA(LuminaCharacter(), 'Actor:LuminaPawn'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.getClassName(door), 'BP_Door');
      expect(LuminaBlueprintFunctionLibrary.getClassName(null), 'None');

      // In a graph: Get Player Pawn → Cast To BP_Door on both kinds of actor.
      const variables = [LuminaBlueprintVariable(name: 'Other', typeName: 'Object')];
      const context = LuminaBlueprintTypeContext(variables: variables);
      LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
          LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
      final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
        place('event_beginplay', 'begin'),
        place(LuminaBlueprintNodeLibrary.variableGet, 'other', {'variable': 'Other'}),
        place(LuminaBlueprintNodeLibrary.castTo, 'cast', {'class': 'Actor:BP_Door'}),
        place('get_class_name', 'name'),
        place('print_string', 'ok'),
        place('print_string', 'failed', {'in_string': 'failed'}),
      ], wires: [
        wire('begin', 'exec_out', 'cast', 'exec_in'),
        wire('other', 'value', 'cast', 'object'),
        wire('cast', 'cast_succeeded', 'ok', 'exec_in'),
        wire('cast', 'as_class', 'name', 'object'),
        wire('name', 'return_value', 'ok', 'in_string'),
        wire('cast', 'cast_failed', 'failed', 'exec_in'),
      ]));
      final caster = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Caster');
      expect(caster.diagnostics, isEmpty, reason: '${caster.diagnostics}');
      expect(caster.document.eventGraph.node('cast')!.title, 'Cast To BP_Door');
      expect(caster.document.eventGraph.node('cast')!.pin('as_class')!.objectClass, 'Actor:BP_Door');
      final printed = <Object?, String?>{};
      for (final other in [door, plain]) {
        final w = world();
        final a = caster.instantiate() as LuminaBlueprintInstance;
        a.variables['Other'] = other;
        final trace = <LuminaBlueprintTraceEvent>[];
        a.trace = trace.add;
        w.persistentLevel.registerActor(a);
        w.beginPlay();
        printed[other] = trace.firstWhere((t) => t.printed != null).printed;
        final cast = trace.firstWhere((t) => t.registryId == 'cast_to');
        expect(cast.values['as_class'], identical(other, door) ? same(door) : isNull);
        w.cleanup();
      }
      expect(printed[door], 'BP_Door');
      expect(printed[plain], 'failed');
    });

    test('a Set Relative Location on a component is authoring space (cm, Z up)', () {
      final component = LuminaSceneComponent();
      LuminaBlueprintFunctionLibrary.setRelativeLocation(component, Vector3(10, 20, 30));
      expect(component.relativeLocation, Vector3(10, 30, -20));
      expect(LuminaBlueprintFunctionLibrary.getRelativeLocation(component), Vector3(10, 20, 30));
    });
  });
}
