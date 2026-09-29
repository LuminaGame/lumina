part of '../blueprint_dart_generator.dart';

const _ignoreForFile = '// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, '
    'prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression';

/// What makes a [_ClassWriter] write a level script.
class _LevelScript {
  final String levelName;
  final List<LuminaBlueprintLevelActorRef> actors;
  final Map<String, String> actorParents;
  final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners;
  final List<String> members;
  final List<String> beginPlay;
  final List<String> tick;
  _LevelScript(this.levelName, this.actors, this.actorParents, this.customEventOwners, this.members, this.beginPlay, this.tick);

  LuminaBlueprintTypeContext context(LuminaBlueprintDocument doc, List<LuminaInputAction> inputActions) =>
      LuminaBlueprintTypeContext.forLevel(LuminaLevelBlueprintDocument(levelPath: levelName, blueprint: doc),
          levelActors: actors, inputActions: inputActions, actorParents: actorParents, customEventOwners: customEventOwners);

  late final Map<String, String> _fields = () {
    final used = <String>{};
    return {
      for (final a in actors)
        a.name: () {
          var f = _var(a.name);
          while (!used.add(f)) {
            f = '${f}_';
          }
          return f;
        }(),
    };
  }();

  /// The field of placed actor [a] (`Door_01` → `door01`).
  String fieldOf(LuminaBlueprintLevelActorRef a) => _fields[a.name]!;

  /// The runtime type the field of [a] holds: its engine class, or
  /// `LuminaActor` for a Blueprint class (generated in another library).
  String dartTypeOf(LuminaBlueprintLevelActorRef a) {
    final name = LuminaBlueprintObjectClass.name(a.actorClass);
    return const {'LuminaPlayerStart', 'LuminaTriggerVolume', 'LuminaBlockingVolume', 'LuminaVolume', 'LuminaPawn', 'LuminaCharacter'}
            .contains(name)
        ? name
        : 'LuminaActor';
  }
}

/// What makes a [_ClassWriter] write a widget's graph script.
class _WidgetScript {
  final LuminaWidgetBlueprintDocument widget;
  final Map<String, String> actorParents;
  _WidgetScript(this.widget, this.actorParents);

  LuminaBlueprintTypeContext context(List<LuminaInputAction> inputActions) =>
      LuminaBlueprintTypeContext.forWidget(widget, inputActions: inputActions, actorParents: actorParents);

  /// The lifecycle events: the hook each is dispatched from, its frame's
  /// outputs, and the hook's parameters (the VM's `LuminaBlueprintUserWidget`).
  static const Map<String, ({String hook, Map<String, String> outputs, String params, String args})> events = {
    LuminaBlueprintNodeLibrary.eventWidgetPreConstruct: (
      hook: 'onWidgetPreConstruct',
      outputs: {'is_design_time': 'isDesignTime'},
      params: 'bool isDesignTime',
      args: 'isDesignTime',
    ),
    LuminaBlueprintNodeLibrary.eventWidgetConstruct: (hook: 'onWidgetConstruct', outputs: {}, params: '', args: ''),
    LuminaBlueprintNodeLibrary.eventWidgetDestruct: (hook: 'onWidgetDestruct', outputs: {}, params: '', args: ''),
    LuminaBlueprintNodeLibrary.eventWidgetTick: (
      hook: 'onWidgetTick',
      outputs: {'in_delta_time': 'inDeltaTime'},
      params: 'double inDeltaTime',
      args: 'inDeltaTime',
    ),
  };
}

class _ClassWriter {
  final LuminaBlueprintDocument doc;
  final String className;
  final String? assetPath;
  final List<LuminaInputAction> inputActions;
  final List<LuminaBlueprintDiagnostic> issues;
  final Map<String, BlueprintAnimClassRef> animBlueprints;
  final Map<String, String> functionImports;
  /// Set when the class is a Level Blueprint's script.
  final _LevelScript? level;

  /// Set when the class is a widget's graph script.
  final _WidgetScript? widget;

  /// The imports a level or widget script needs (see [BlueprintGenerationResult.imports]).
  final List<String> levelImports = [];

  late final String blueprintName =
      level?.levelName ?? widget?.widget.widgetClass ?? BlueprintDartGenerator._blueprintName(className, assetPath);
  late final LuminaBlueprintTypeContext context = level?.context(doc, inputActions) ??
      widget?.context(inputActions) ??
      LuminaBlueprintTypeContext.forDocument(doc, inputActions: inputActions, className: blueprintName);

  /// The event graph with every macro call expanded.
  late final LuminaBlueprintGraph expandedGraph = LuminaBlueprintMacroExpander.expand(doc.eventGraph, doc.macros);
  final _Counter _counter = _Counter();
  late final _GraphCompiler compiler = _GraphCompiler(
    expandedGraph,
    context,
    _counter,
    self: 'this',
    readVariable: _var,
    writeVariable: (name, value) => '${_var(name)} = $value;',
    error: _error,
    timelineOf: _timelineGetter,
  );
  var failed = false;

  /// Timeline nodes by id → the getter of their runtime.
  final Map<String, LuminaBlueprintNode> _timelines = {};

  String _timelineGetter(LuminaBlueprintNode node) {
    _timelines[node.id] = node;
    return '_tl${_cap(_id(node.id))}';
  }

  _ClassWriter(
      this.doc, this.className, this.assetPath, this.inputActions, this.issues, this.animBlueprints, this.functionImports,
      {this.level, this.widget});

  LuminaBlueprintGraph get graph => expandedGraph;
  Map<String, _Pins> get pins => compiler.pins;
  bool get _isPawn => doc.parentClass == 'LuminaPawn' || doc.parentClass == 'LuminaCharacter';

  void _error(String message, {String? node}) {
    failed = true;
    issues.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, message, nodeId: node));
  }

  /// The Anim Classes this Blueprint's skeletal meshes name that have a
  /// generated class, by the stored path.
  Map<String, BlueprintAnimClassRef> _usedAnimClasses() {
    final used = <String, BlueprintAnimClassRef>{};
    for (final c in doc.components) {
      final animClass = c.properties['animClass'];
      if (c.properties['animMode'] != 'Use Animation Blueprint' || animClass is! String || animClass.isEmpty) continue;
      final ref = animBlueprints[animClass];
      if (ref == null) {
        issues.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
            "Mesh '${c.name}': Animation Blueprint '$animClass' is not available; the mesh plays no animation."));
      } else {
        used[animClass] = ref;
      }
    }
    return used;
  }

  // --- The file -------------------------------------------------------------

  String write(Map<String, String> userRegions) {
    final events = <String>[];
    final tickCalls = <String>[];
    final beginCalls = <String>[];
    final bindings = <String>[];
    // Actor events: hook name → the event-method calls its
    // override makes, in graph order.
    final hookCalls = <String, List<String>>{};
    // `callBlueprint` cases (name → the call), in graph order.
    final callCases = <String, String>{};
    // Level Loaded / Unloaded event-method calls.
    final loadedCalls = <String>[];
    final unloadedCalls = <String>[];
    // Widget lifecycle hook → its event-method calls; bound element
    // events as `onWidgetEvent` cases, in graph order.
    final widgetHookCalls = <String, List<String>>{};
    final widgetEventCases = <String>[];
    for (final node in graph.nodes) {
      final lifecycle = _WidgetScript.events[node.registryId];
      if (this.widget != null && lifecycle != null) {
        final method = '_on${_cap(_id(node.id))}';
        (widgetHookCalls[lifecycle.hook] ??= []).add('$method(${lifecycle.args});');
        events.add(compiler.eventMethod(
            method, _Frame(node.id, _id(node.id), lifecycle.outputs, lifecycle.params, lifecycle.args), node, 'exec_out', node.title));
        continue;
      }
      if (this.widget != null && node.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement) {
        final method = '_on${_cap(_id(node.id))}';
        final params = [for (final p in pins[node.id]!.outputs) if (p.type != LuminaPinType.exec) p];
        final frame = _Frame(node.id, _id(node.id), {for (final p in params) p.id: _var(p.id)},
            params.map((p) => '${_dartType(p.type)} ${_var(p.id)}').join(', '), params.map((p) => _var(p.id)).join(', '));
        events.add(compiler.eventMethod(method, frame, node, 'exec_out', node.title));
        widgetEventCases.add("case (${_str('${node.literals['element'] ?? ''}')}, ${_str('${node.literals['event'] ?? ''}')}):\n"
            '        $method(${params.map(_argOf).join(', ')});');
        continue;
      }
      if (node.registryId == LuminaBlueprintNodeLibrary.customEvent ||
          node.registryId == LuminaBlueprintNodeLibrary.eventInterfaceFunction) {
        final name = node.literals[node.registryId == LuminaBlueprintNodeLibrary.customEvent ? 'name' : 'function'] as String? ?? '';
        final method = '_on${_cap(_id(node.id))}';
        final params = [
          for (final p in pins[node.id]!.outputs)
            if (p.type != LuminaPinType.exec && p.type != LuminaPinType.delegate) p
        ];
        final frame = _Frame(node.id, _id(node.id), {for (final p in params) p.id: _var(p.id)},
            params.map((p) => '${_dartType(p.type)} ${_var(p.id)}').join(', '), params.map((p) => _var(p.id)).join(', '));
        events.add(compiler.eventMethod(method, frame, node, 'exec_out', node.title));
        callCases[name] = '$method(${params.map((p) => _argOf(p)).join(', ')}); return const {};';
        continue;
      }
      // A Level Blueprint's level events are its actor events.
      final registryId = switch (node.registryId) {
        LuminaBlueprintNodeLibrary.eventLevelBeginPlay => 'event_beginplay',
        LuminaBlueprintNodeLibrary.eventLevelTick => 'event_tick',
        LuminaBlueprintNodeLibrary.eventLevelEndPlay => 'event_end_play',
        final id => id,
      };
      if (registryId == LuminaBlueprintNodeLibrary.eventLevelLoaded || registryId == LuminaBlueprintNodeLibrary.eventLevelUnloaded) {
        final method = '_on${_cap(_id(node.id))}';
        (registryId == LuminaBlueprintNodeLibrary.eventLevelLoaded ? loadedCalls : unloadedCalls).add('$method();');
        events.add(compiler.eventMethod(method, _Frame(node.id, _id(node.id), const {}, '', ''), node, 'exec_out', node.title));
        continue;
      }
      final hook = LuminaBlueprintNodeLibrary.actorEventHooks[registryId];
      if (hook != null) {
        final e = _actorEvents[registryId]!;
        final method = '_on${_cap(_id(node.id))}';
        final frame = _Frame(node.id, _id(node.id), e.outputs, e.params, e.args);
        (hookCalls[hook] ??= []).add('$method(${e.args});');
        events.add(compiler.eventMethod(method, frame, node, 'exec_out', node.title));
        continue;
      }
      switch (registryId) {
        case 'event_beginplay':
          final frame = _Frame(node.id, _id(node.id), const {}, '', '');
          beginCalls.add('_on${_cap(_id(node.id))}();');
          events.add(compiler.eventMethod('_on${_cap(_id(node.id))}', frame, node, 'exec_out', node.title));
        case 'event_tick':
          final frame = _Frame(node.id, _id(node.id), const {'delta_seconds': 'deltaSeconds'}, 'double deltaSeconds', 'deltaSeconds');
          tickCalls.add('_on${_cap(_id(node.id))}(deltaSeconds);');
          events.add(compiler.eventMethod('_on${_cap(_id(node.id))}', frame, node, 'exec_tick_out', node.title));
        case LuminaBlueprintNodeLibrary.enhancedInputAction:
          final name = node.literals['action'] as String;
          final action = inputActions.firstWhere((a) => a.name == name);
          final valueType = pins[node.id]!.outputs.firstWhere((p) => p.id == 'action_value').type;
          final (dartType, accessor) = switch (valueType) {
            LuminaPinType.boolean => ('bool', 'asBool'),
            LuminaPinType.float => ('double', 'asAxis1D'),
            LuminaPinType.vector2D => ('Vector2', 'asAxis2D'),
            _ => ('Vector3', 'asAxis3D'),
          };
          for (final state in TriggerState.values) {
            if (graph.wiresFrom(node.id, state.name).isEmpty) continue;
            final method = '_on${_cap(_id(node.id))}${_cap(state.name)}';
            final frame = _Frame(node.id, '${_id(node.id)}${_cap(state.name)}', const {'action_value': 'actionValue'},
                '$dartType actionValue', 'actionValue');
            bindings.add('LuminaBlueprintInputBinding(const LuminaInputAction(${_str(action.name)}, '
                'valueType: InputValueType.${action.valueType.name}), TriggerState.${state.name}, '
                '(value) => $method(value.$accessor)),');
            events.add(compiler.eventMethod(method, frame, node, state.name, '${node.title} ${_cap(state.name)}'));
          }
      }
    }
    final animClasses = _usedAnimClasses();
    // User functions as methods.
    final functionMethods = <String>[];
    for (final f in doc.functions) {
      final method = '_fn${_cap(_var(f.name))}';
      final code = _functionMethod(f, method);
      if (code == null) continue;
      functionMethods.add(code);
      callCases[f.name] = 'return $method(args);';
    }

    final b = StringBuffer();
    final level = this.level;
    final widget = this.widget;
    if (widget != null) {
      // A widget's graph is written into its generated widget file.
      final imports = StringBuffer();
      _functionImports(imports, compiler.libraries, functionImports);
      levelImports.addAll(imports.toString().split('\n').where((l) => l.isNotEmpty));
      b.writeln('/// Widget `${widget.widget.widgetClass}`\'s graph, compiled by Lumina: the script');
      b.writeln('/// `Create Widget` gives every instance of the widget in the built game.');
      b.writeln('class $className extends LuminaUserWidget with LuminaBlueprintRuntime {');
      b.writeln('  $className() {');
    } else if (level != null) {
      // A level script is written into its level's file.
      final imports = StringBuffer();
      _functionImports(imports, compiler.libraries, functionImports);
      levelImports.addAll(imports.toString().split('\n').where((l) => l.isNotEmpty));
      b.writeln('/// Level `${level.levelName}`\'s script: its Level Blueprint, compiled by Lumina.');
      b.writeln('class $className extends LuminaLevelScriptActor with LuminaBlueprintRuntime, LuminaBlueprintLevelActors {');
      b.writeln("  $className() : super(key: const ValueKey(${_str('${level.levelName}_script')})) {");
    } else {
      b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).');
      b.writeln('// Blueprint ${assetPath ?? className}, compiled by Lumina.');
      b.writeln(_ignoreForFile);
      b.writeln();
      b.writeln("import 'package:lumina/lumina_runtime.dart';");
      b.writeln("import 'package:vector_math/vector_math_64.dart';");
      for (final uri in {for (final r in animClasses.values) if (r.importUri != null) r.importUri!}) {
        b.writeln('import ${_str(uri)};');
      }
      _functionImports(b, compiler.libraries, functionImports);
      b.writeln();
      b.writeln('class $className extends ${BlueprintDartGenerator._parents[doc.parentClass]} with LuminaBlueprintRuntime {');
      b.writeln('  $className({super.key, super.location, super.rotation}) {');
    }
    for (final line in _classDefaults()) {
      b.writeln('    $line');
    }
    b.writeln('    blueprintComponentTree = _components;');
    if (doc.interfaces.isNotEmpty) b.writeln('    blueprintInterfaces = const [${doc.interfaces.map(_str).join(', ')}];');
    if (animClasses.isNotEmpty) b.writeln('    blueprintAnimClasses = _animBlueprints;');
    b.writeln(animClasses.isEmpty
        ? '    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);'
        : '    blueprintComponents = LuminaBlueprintComponents.construct(this, _components, animBlueprints: _animBlueprints);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  String get blueprintClassName => ${_str(blueprintName)};');
    b.writeln();
    b.writeln("  /// The component tree (the Blueprint's construction script).");
    b.writeln('  static final List<LuminaBlueprintComponent> _components = [');
    for (final c in doc.components) {
      b.writeln('    LuminaBlueprintComponent(');
      b.writeln('      id: ${_str(c.id)},');
      b.writeln('      name: ${_str(c.name)},');
      b.writeln('      type: ${_str(c.type)},');
      b.writeln('      parentId: ${c.parentId == null ? 'null' : _str(c.parentId!)},');
      b.writeln('      properties: ${_json(c.properties)},');
      b.writeln('      isSceneComponent: ${c.isSceneComponent},');
      b.writeln('    ),');
    }
    b.writeln('  ];');
    if (animClasses.isNotEmpty) {
      b.writeln();
      b.writeln("  /// The Animation Blueprints this Blueprint's meshes name as their Anim Class.");
      b.writeln('  static LuminaAnimBlueprintFactory? _animBlueprints(String animClass) => switch (animClass) {');
      for (final e in animClasses.entries) {
        b.writeln('        ${_str(e.key)} => ${e.value.className}.create,');
      }
      b.writeln('        _ => null,');
      b.writeln('      };');
    }
    if (level != null) {
      b.writeln();
      b.writeln('  /// The placed actors this script refers to, by name → the id the level mounts them with.');
      b.writeln('  @override');
      b.writeln('  final Map<String, String> levelActorIds = const {');
      for (final a in level.actors) {
        b.writeln('    ${_str(a.name)}: ${_str(a.id)},');
      }
      b.writeln('  };');
      if (level.actors.isNotEmpty) {
        b.writeln();
        b.writeln('  // The placed actors, resolved once the level is loaded.');
        for (final a in level.actors) {
          b.writeln('  ${level.dartTypeOf(a)}? ${level.fieldOf(a)};');
        }
      }
      if (level.members.isNotEmpty) b.writeln();
      for (final m in level.members) {
        b.writeln(m.isEmpty ? '' : '  $m');
      }
    }
    if (doc.variables.isNotEmpty) {
      b.writeln();
      for (final v in doc.variables) {
        final value = doc.classDefaults.containsKey(v.name) ? doc.classDefaults[v.name] : v.defaultValue;
        final literal = _literal(v.type!, value);
        b.writeln('  ${_dartType(v.type!)} ${_var(v.name)}${literal == 'null' ? '' : ' = $literal'};');
      }
    }
    if (compiler.stateFields.isNotEmpty) {
      b.writeln();
      b.writeln('  // Flow-control state (DoOnce, FlipFlop, Gate, DoN, MultiGate), reset at BeginPlay.');
      for (final f in compiler.stateFields) {
        b.writeln('  $f');
      }
    }
    if (doc.dispatchers.isNotEmpty) {
      b.writeln();
      b.writeln('  // Event dispatchers.');
      for (final d in doc.dispatchers) {
        b.writeln('  LuminaMulticastDelegate get ${_var(d.name)} => blueprintDispatcher(${_str(d.name)});');
      }
    }
    if (callCases.isNotEmpty) {
      b.writeln();
      b.writeln('  /// Custom events, functions and interface events by name.');
      b.writeln('  @override');
      b.writeln('  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {');
      b.writeln('    switch (name) {');
      for (final e in callCases.entries) {
        b.writeln('      case ${_str(e.key)}:');
        b.writeln('        ${e.value}');
      }
      b.writeln('      default:');
      b.writeln('        return super.callBlueprint(name, args);');
      b.writeln('    }');
      b.writeln('  }');
    }
    // A Blueprint with nothing to do at BeginPlay (no Event BeginPlay, no
    // flow state, no input) keeps the inherited one: an override that only
    // calls super fails `dart analyze --fatal-infos`.
    final beginPlayBody = [
      ...?level?.beginPlay,
      ...compiler.stateResets,
      if (bindings.isNotEmpty) '_bindInput();',
      ...beginCalls,
    ];
    if (beginPlayBody.isNotEmpty) {
      b.writeln();
      b.writeln('  @override');
      b.writeln('  void onBeginPlay() {');
      b.writeln('    super.onBeginPlay();');
      for (final line in beginPlayBody) {
        b.writeln('    $line');
      }
      b.writeln('  }');
    }
    b.writeln();
    b.writeln('  @override');
    b.writeln('  void onTick(double deltaSeconds) {');
    b.writeln('    super.onTick(deltaSeconds);');
    for (final line in level?.tick ?? const <String>[]) {
      b.writeln('    $line');
    }
    b.writeln('    advanceBlueprintLatent(deltaSeconds);');
    for (final c in tickCalls) {
      b.writeln('    $c');
    }
    b.writeln('  }');
    for (final hook in hookCalls.keys) {
      final h = _actorHooks[hook]!;
      b.writeln();
      b.writeln('  @override');
      b.writeln('  void $hook(${h.signature}) {');
      b.writeln('    super.$hook(${h.args});');
      for (final line in h.before) {
        b.writeln('    $line');
      }
      for (final call in hookCalls[hook]!) {
        b.writeln('    $call');
      }
      b.writeln('  }');
    }
    if (level != null) {
      if (level.actors.isNotEmpty || loadedCalls.isNotEmpty) {
        b.writeln();
        b.writeln('  @override');
        b.writeln('  void onLevelLoaded() {');
        b.writeln('    super.onLevelLoaded();');
        for (final a in level.actors) {
          final field = level.fieldOf(a);
          final type = level.dartTypeOf(a);
          if (type == 'LuminaActor') {
            b.writeln('    $field = super.levelActor(${_str(a.name)});');
          } else {
            b.writeln('    final ${field}Found = super.levelActor(${_str(a.name)});');
            b.writeln('    $field = ${field}Found is $type ? ${field}Found : null;');
          }
        }
        for (final c in loadedCalls) {
          b.writeln('    $c');
        }
        b.writeln('  }');
      }
      if (unloadedCalls.isNotEmpty) {
        b.writeln();
        b.writeln('  @override');
        b.writeln('  void onLevelUnloaded() {');
        for (final c in unloadedCalls) {
          b.writeln('    $c');
        }
        b.writeln('    super.onLevelUnloaded();');
        b.writeln('  }');
      }
      if (level.actors.isNotEmpty) {
        b.writeln();
        b.writeln('  /// The placed actor [name]: its field while it is in play.');
        b.writeln('  @override');
        b.writeln('  LuminaActor? levelActor(String name) => switch (name) {');
        for (final a in level.actors) {
          b.writeln('        ${_str(a.name)} => liveLevelActor(${level.fieldOf(a)} ?? super.levelActor(name)),');
        }
        b.writeln('        _ => super.levelActor(name),');
        b.writeln('      };');
      }
    }
    for (final hook in widgetHookCalls.keys) {
      final e = _WidgetScript.events.values.firstWhere((e) => e.hook == hook);
      b.writeln();
      b.writeln('  @override');
      b.writeln('  void $hook(${e.params}) {');
      for (final call in widgetHookCalls[hook]!) {
        b.writeln('    $call');
      }
      b.writeln('  }');
    }
    if (widgetEventCases.isNotEmpty) {
      b.writeln();
      b.writeln('  /// The bound element events (`On Clicked (StartButton)`, …) by element and event.');
      b.writeln('  @override');
      b.writeln('  void onWidgetEvent(String element, String event, Map<String, Object?> args) {');
      b.writeln('    switch ((element, event)) {');
      for (final c in widgetEventCases) {
        b.writeln('      $c');
      }
      b.writeln('    }');
      b.writeln('  }');
    }
    if (bindings.isNotEmpty) {
      if (_isPawn) {
        b.writeln();
        b.writeln('  @override');
        b.writeln('  void possessedBy(LuminaController newController) {');
        b.writeln('    super.possessedBy(newController);');
        b.writeln('    _bindInput();');
        b.writeln('  }');
        b.writeln();
        b.writeln('  @override');
        b.writeln('  void unpossessed() {');
        b.writeln('    unbindBlueprintInput();');
        b.writeln('    super.unpossessed();');
        b.writeln('  }');
      }
      b.writeln();
      b.writeln('  void _bindInput() => bindBlueprintInput([');
      for (final line in bindings) {
        b.writeln('        $line');
      }
      b.writeln('      ]);');
    }
    for (final m in [...events, ...functionMethods, ...compiler.methods, ..._timelineMembers()]) {
      b.writeln();
      b.write(m);
    }
    if (level == null && widget == null) _userRegion(b, userRegions);
    b.writeln('}');
    return b.toString();
  }

  /// A signature parameter read from a `callBlueprint` argument map, typed
  /// and defaulted as the VM reads it.
  static String _argOf(LuminaBlueprintPinSpec p) {
    final zero = _literal(p.type, p.defaultValue);
    final type = _dartType(p.type);
    if (type == 'Object?') return 'args[${_str(p.id)}]';
    return zero == 'null' ? 'args[${_str(p.id)}] as $type?' : '(args[${_str(p.id)}] as $type?) ?? $zero';
  }

  /// A user function as a method taking its argument map and returning its
  /// outputs: inputs are the entry's outputs, locals are Dart
  /// locals, the Return node returns.
  String? _functionMethod(LuminaBlueprintFunctionGraph f, String method) {
    final fc = level != null || widget != null
        ? context.scoped(doc, function: f)
        : LuminaBlueprintTypeContext.forDocument(doc, inputActions: inputActions, className: blueprintName, functionScope: f);
    final graph = LuminaBlueprintMacroExpander.expand(f.graph, doc.macros);
    final entry = graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry).firstOrNull;
    if (entry == null) {
      _error("Function '${f.name}' has no Function Entry node.");
      return null;
    }
    String localName(String name) => 'l${_cap(_var(name))}';
    final zeros = {for (final o in f.outputs) o.name: _literal(o.type ?? LuminaPinType.float, o.defaultValue)};
    final c = _GraphCompiler(
      graph,
      fc,
      _counter,
      self: 'this',
      readVariable: _var,
      writeVariable: (name, value) => '${_var(name)} = $value;',
      readLocal: localName,
      writeLocal: (name, value) => '${localName(name)} = $value;',
      returnStatement: (outputs) => 'return ${_map({...zeros, ...outputs})};',
      timelineOf: _timelineGetter,
      error: _error,
      libraries: compiler.libraries,
    );
    final frame = _Frame(entry.id, _id(entry.id), {for (final i in f.inputs) i.name: _var(i.name)}, '', '');
    final body = <String>[];
    final result = graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult).firstOrNull;
    if (f.pure) {
      if (result != null) {
        final outputs = <String, String>{};
        for (final o in f.outputs) {
          outputs[o.name] = c._input(frame, result, o.name, <String, Map<String, String>>{}, body, '    ');
        }
        body.add('    return ${_map({...zeros, ...outputs})};');
      } else {
        body.add('    return ${_map(zeros)};');
      }
    } else {
      c._chain(frame, entry.id, 'exec_out', body, 2, {});
      body.add('    return ${_map(zeros)};');
    }
    final b = StringBuffer();
    b.writeln('  /// Function ${f.name}${f.pure ? ' (pure)' : ''}.');
    b.writeln('  Map<String, Object?> $method(Map<String, Object?> args) {');
    for (final i in f.inputs) {
      b.writeln('    final ${_var(i.name)} = ${_argOf(LuminaBlueprintPinSpec.ofVariable(i))};');
    }
    for (final l in f.localVariables) {
      b.writeln('    ${_dartType(l.type ?? LuminaPinType.float)} ${localName(l.name)} = ${_literal(l.type ?? LuminaPinType.float, l.defaultValue)};');
    }
    for (final d in frame.declarations) {
      b.writeln('    $d');
    }
    for (final line in body) {
      b.writeln(line);
    }
    b.writeln('  }');
    // The compiler's resume methods (after a Delay inside the function) ride along.
    compiler.methods.addAll(c.methods);
    compiler.stateFields.addAll(c.stateFields);
    compiler.stateResets.addAll(c.stateResets);
    return b.toString();
  }

  /// Each Timeline node's runtime getter and its Update / Finished methods:
  /// the track values are the node's outputs for that run,
  /// traced under the node's id as the VM does.
  List<String> _timelineMembers() {
    final out = <String>[];
    for (final node in _timelines.values) {
      final getter = '_tl${_cap(_id(node.id))}';
      final outputs = [for (final p in pins[node.id]!.outputs) if (p.type != LuminaPinType.exec) p];
      final b = StringBuffer();
      b.writeln('  /// Timeline ${node.title} (node ${node.id}).');
      b.writeln('  LuminaTimeline get $getter => blueprintTimelines[${_str(node.id)}] ??= (LuminaTimeline.fromLiterals(${_json(node.literals)})');
      b.writeln('    ..onUpdate = ${getter}Update');
      b.writeln('    ..onFinished = ${getter}Finished);');
      out.add(b.toString());
      for (final pin in const ['update', 'finished']) {
        final method = '$getter${_cap(pin)}';
        final frame = _Frame(node.id, '${_id(node.id)}${_cap(pin)}', {
          for (final o in outputs)
            o.id: o.id == 'direction' ? '$getter.direction' : '(values[${_str(o.id)}] as ${_dartType(o.type)})',
        }, '', '');
        final body = <String>[];
        compiler._chain(frame, node.id, pin, body, 1, {});
        final m = StringBuffer();
        m.writeln('  void $method() {');
        m.writeln('    final values = $getter.values();');
        for (final d in frame.declarations) {
          m.writeln('    $d');
        }
        for (final line in body) {
          m.writeln('  $line');
        }
        m.writeln('  }');
        out.add(m.toString());
      }
    }
    return out;
  }

  /// The actor hooks generated classes override for the actor events:
  /// the override's signature, the arguments the super call
  /// forwards, and statements run before the event methods (the VM computes
  /// the same values when it dispatches).
  static const Map<String, ({String signature, String args, List<String> before})> _actorHooks = {
    'onEndPlay': (signature: 'LuminaEndPlayReason reason', args: 'reason', before: []),
    'onDestroyed': (signature: '', args: '', before: []),
    'onAnyDamage': (
      signature: 'double damage, String damageType, LuminaController? instigator, LuminaActor? damageCauser',
      args: 'damage, damageType, instigator, damageCauser',
      before: [],
    ),
    'onPointDamage': (
      signature: 'double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType, LuminaController? instigator, LuminaActor? damageCauser',
      args: 'damage, hitLocation, hitFromDirection, damageType, instigator, damageCauser',
      before: [
        'final hitLocationA = LuminaBlueprintFunctionLibrary.toAuthoring(hitLocation);',
        'final hitFromDirectionA = LuminaBlueprintFunctionLibrary.toAuthoring(hitFromDirection);',
      ],
    ),
    'notifyActorBeginOverlap': (
      signature: 'LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent',
      args: 'other, selfComponent, otherComponent',
      before: [],
    ),
    'notifyActorEndOverlap': (
      signature: 'LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent',
      args: 'other, selfComponent, otherComponent',
      before: [],
    ),
    'notifyActorHit': (
      signature: 'LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent, HitResult hit',
      args: 'other, selfComponent, otherComponent, hit',
      before: ['final hitOutputs = LuminaBlueprintFunctionLibrary.hitEventOutputs(this, other, hit);'],
    ),
    'onMontageEnded': (signature: 'String montage, bool interrupted', args: 'montage, interrupted', before: []),
    'onAnimNotify': (signature: 'String notifyName', args: 'notifyName', before: []),
  };

  /// Each actor event's method: the pin → expression map its frame reads,
  /// and the method's parameters / arguments (from the hook's scope).
  static const Map<String, ({Map<String, String> outputs, String params, String args})> _actorEvents = {
    'event_end_play': (outputs: {'end_play_reason': 'endPlayReason'}, params: 'String endPlayReason', args: 'reason.displayName'),
    'event_destroyed': (outputs: {}, params: '', args: ''),
    'event_any_damage': (
      outputs: {'damage': 'damage', 'damage_type': 'damageType', 'instigated_by': 'instigator', 'damage_causer': 'damageCauser'},
      params: 'double damage, String damageType, Object? instigator, Object? damageCauser',
      args: 'damage, damageType, instigator, damageCauser',
    ),
    'event_take_point_damage': (
      outputs: {
        'damage': 'damage',
        'hit_location': 'hitLocation',
        'hit_from_direction': 'hitFromDirection',
        'damage_type': 'damageType',
        'instigated_by': 'instigator',
        'damage_causer': 'damageCauser',
      },
      params: 'double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType, Object? instigator, Object? damageCauser',
      args: 'damage, hitLocationA, hitFromDirectionA, damageType, instigator, damageCauser',
    ),
    'event_actor_begin_overlap': (outputs: {'other_actor': 'other'}, params: 'Object? other', args: 'other'),
    'event_actor_end_overlap': (outputs: {'other_actor': 'other'}, params: 'Object? other', args: 'other'),
    'event_begin_overlap': (
      outputs: {'other_actor': 'other', 'other_comp': 'otherComponent'},
      params: 'Object? other, Object? otherComponent',
      args: 'other, otherComponent',
    ),
    'event_end_overlap': (
      outputs: {'other_actor': 'other', 'other_comp': 'otherComponent'},
      params: 'Object? other, Object? otherComponent',
      args: 'other, otherComponent',
    ),
    'event_montage_ended': (outputs: {'montage': 'montage', 'interrupted': 'interrupted'}, params: 'String montage, bool interrupted', args: 'montage, interrupted'),
    'event_anim_notify': (outputs: {'notify_name': 'notifyName'}, params: 'String notifyName', args: 'notifyName'),
    'event_hit': (
      outputs: {
        'self_actor': "hitOutputs['self_actor']",
        'other_actor': "hitOutputs['other_actor']",
        'normal_impulse': "(hitOutputs['normal_impulse'] as Vector3)",
        'hit': "hitOutputs['hit']",
        'hit_normal': "(hitOutputs['hit_normal'] as Vector3)",
        'impact_point': "(hitOutputs['impact_point'] as Vector3)",
      },
      params: 'Map<String, Object?> hitOutputs',
      args: 'hitOutputs',
    ),
  };

  List<String> _classDefaults() {
    final d = doc.classDefaults;
    return [
      if (_isPawn && d['bUseControllerRotationYaw'] is bool) 'bUseControllerRotationYaw = ${d['bUseControllerRotationYaw']};',
      if (_isPawn && d['bUseControllerRotationPitch'] is bool) 'bUseControllerRotationPitch = ${d['bUseControllerRotationPitch']};',
      if (_isPawn && d['bUseControllerRotationRoll'] is bool) 'bUseControllerRotationRoll = ${d['bUseControllerRotationRoll']};',
      if (_isPawn && d['baseEyeHeight'] is num) 'baseEyeHeight = ${_double((d['baseEyeHeight'] as num).toDouble())};',
    ];
  }
}
