part of '../blueprint_vm.dart';

/// What every Blueprint actor carries: its class, variables, component map,
/// the trace hook, and the interpreter.
mixin LuminaBlueprintInstance on LuminaBlueprintRuntime implements LuminaBlueprintGraphHost {
  late final LuminaBlueprintClass blueprintClass;

  /// Current variable values by name.
  final Map<String, Object?> variables = {};

  /// A single event run stops after this many nodes (an infinite-loop
  /// guard).
  int maxNodesPerEvent = 100000;

  late final Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> _pins;

  /// The event graph with every macro call expanded.
  late final LuminaBlueprintGraph _graph;

  /// Each user function's expanded graph, pins and entry / result nodes.
  final Map<String, _FunctionGraph> _functions = {};
  int _callDepth = 0;

  /// A function call nests at most this deep (a stack limit).
  static const int maxCallDepth = 256;

  @override
  String get blueprintClassName => blueprintClass.name;

  @override
  List<String> get blueprintParentClasses => blueprintClass.parentClasses;

  void _initBlueprint(LuminaBlueprintClass cls) {
    blueprintClass = cls;
    final doc = cls.document;
    final context = cls.typeContext();
    blueprintComponentTree = cls.allComponents;
    blueprintAnimClasses = cls.animBlueprints;
    blueprintInterfaces = List.unmodifiable(doc.interfaces);
    _graph = LuminaBlueprintMacroExpander.expand(doc.eventGraph, doc.macros);
    _pins = {
      for (final n in _graph.nodes) n.id: LuminaBlueprintNodeLibrary.pinsOf(n, context)!,
    };
    for (final f in doc.functions) {
      final fc = cls.typeContext(function: f);
      final graph = LuminaBlueprintMacroExpander.expand(f.graph, doc.macros);
      _functions[f.name] = _FunctionGraph(
        f,
        graph,
        {for (final n in graph.nodes) n.id: LuminaBlueprintNodeLibrary.pinsOf(n, fc)!},
      );
    }
    for (final v in cls.allVariables) {
      variables[v.name] = _typed(v.type!, v.defaultValue);
    }
    final defaults = cls.allClassDefaults;
    final allVarMap = {for (final v in cls.allVariables) v.name: v};
    for (final entry in defaults.entries) {
      final variable = allVarMap[entry.key];
      if (variable != null) variables[variable.name] = _typed(variable.type!, entry.value);
    }
    final self = this;
    if (self is LuminaPawn) {
      final pawn = self as LuminaPawn;
      if (defaults['bUseControllerRotationYaw'] is bool) pawn.bUseControllerRotationYaw = defaults['bUseControllerRotationYaw'] as bool;
      if (defaults['bUseControllerRotationPitch'] is bool) {
        pawn.bUseControllerRotationPitch = defaults['bUseControllerRotationPitch'] as bool;
      }
      if (defaults['bUseControllerRotationRoll'] is bool) pawn.bUseControllerRotationRoll = defaults['bUseControllerRotationRoll'] as bool;
      if (defaults['baseEyeHeight'] is num) pawn.baseEyeHeight = (defaults['baseEyeHeight'] as num).toDouble();
    }
    blueprintComponents = LuminaBlueprintComponents.construct(
      this,
      cls.allComponents,
      resolveAsset: cls.resolveAsset,
      assetProvider: cls.assetProvider,
      animBlueprints: cls.animBlueprints,
    );
  }

  // --- Events --------------------------------------------------------------

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _bindInput();
    _dispatch('event_beginplay', 'exec_out', const {});
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    advanceBlueprintLatent(deltaTime);
    _dispatch('event_tick', 'exec_tick_out', {'delta_seconds': deltaTime});
  }

  // --- Actor events, from the actor's own hooks ------------

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    _dispatch('event_end_play', 'exec_out', {'end_play_reason': reason.displayName});
  }

  @override
  void onDestroyed() {
    super.onDestroyed();
    _dispatch('event_destroyed', 'exec_out', const {});
  }

  @override
  void onAnyDamage(double damage, String damageType, LuminaController? instigator, LuminaActor? damageCauser) {
    super.onAnyDamage(damage, damageType, instigator, damageCauser);
    _dispatch('event_any_damage', 'exec_out',
        {'damage': damage, 'damage_type': damageType, 'instigated_by': instigator, 'damage_causer': damageCauser});
  }

  @override
  void onPointDamage(double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType,
      LuminaController? instigator, LuminaActor? damageCauser) {
    super.onPointDamage(damage, hitLocation, hitFromDirection, damageType, instigator, damageCauser);
    _dispatch('event_take_point_damage', 'exec_out', {
      'damage': damage,
      'hit_location': LuminaBlueprintFunctionLibrary.toAuthoring(hitLocation),
      'hit_from_direction': LuminaBlueprintFunctionLibrary.toAuthoring(hitFromDirection),
      'damage_type': damageType,
      'instigated_by': instigator,
      'damage_causer': damageCauser,
    });
  }

  @override
  void notifyActorBeginOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {
    super.notifyActorBeginOverlap(other, selfComponent, otherComponent);
    _dispatch('event_actor_begin_overlap', 'exec_out', {'other_actor': other});
    _dispatch('event_begin_overlap', 'exec_out', {'other_actor': other, 'other_comp': otherComponent});
  }

  @override
  void notifyActorEndOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {
    super.notifyActorEndOverlap(other, selfComponent, otherComponent);
    _dispatch('event_actor_end_overlap', 'exec_out', {'other_actor': other});
    _dispatch('event_end_overlap', 'exec_out', {'other_actor': other, 'other_comp': otherComponent});
  }

  @override
  void notifyActorHit(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent, HitResult hit) {
    super.notifyActorHit(other, selfComponent, otherComponent, hit);
    _dispatch('event_hit', 'exec_out', LuminaBlueprintFunctionLibrary.hitEventOutputs(this, other, hit));
  }

  @override
  void onMontageEnded(String montage, bool interrupted) {
    super.onMontageEnded(montage, interrupted);
    _dispatch('event_montage_ended', 'exec_out', {'montage': montage, 'interrupted': interrupted});
  }

  @override
  void onAnimNotify(String notifyName) {
    super.onAnimNotify(notifyName);
    _dispatch('event_anim_notify', 'exec_out', {'notify_name': notifyName});
  }

  void _dispatch(String registryId, String execPin, Map<String, Object?> outputs) {
    for (final node in _graph.nodes) {
      if (node.registryId == registryId) _run(node.id, execPin, outputs);
    }
  }

  // --- Custom events, functions and interface events --------

  /// A custom event, a user function, or an implemented interface function,
  /// by [name]: the event's chain runs (no outputs), the function's graph
  /// runs on its own frame and returns its outputs. Unknown names do nothing.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    final function = _functions[name];
    if (function != null) return _callBlueprintFunction(function, args);
    for (final node in _graph.nodes) {
      if (node.registryId == LuminaBlueprintNodeLibrary.customEvent && node.literals['name'] == name) {
        _run(node.id, 'exec_out', _eventArgs(node, args));
        return const {};
      }
      if (node.registryId == LuminaBlueprintNodeLibrary.eventInterfaceFunction && node.literals['function'] == name) {
        _run(node.id, 'exec_out', _eventArgs(node, args));
        return const {};
      }
    }
    return const {};
  }

  /// [args] as the event node's outputs, typed and defaulted from its pins.
  Map<String, Object?> _eventArgs(LuminaBlueprintNode node, Map<String, Object?> args) => {
        for (final p in _pins[node.id]!.outputs)
          if (p.type != LuminaPinType.exec && p.type != LuminaPinType.delegate)
            p.id: args.containsKey(p.id) ? (args[p.id] ?? _typed(p.type, p.defaultValue)) : _typed(p.type, p.defaultValue),
      };

  /// Runs [function] with [args] on a fresh frame: inputs are the entry
  /// node's outputs, the Return node's inputs are the result. Recursion past
  /// [maxCallDepth] is a runtime error (the editor shows it), not a stack
  /// overflow.
  Map<String, Object?> _callBlueprintFunction(_FunctionGraph function, Map<String, Object?> args) {
    final f = function.function;
    final zeros = {for (final o in f.outputs) o.name: _typed(o.type ?? LuminaPinType.float, o.defaultValue)};
    if (_callDepth >= maxCallDepth) {
      final message = "Function '${f.name}' in ${blueprintClass.name} recursed past $maxCallDepth frames and was stopped.";
      lastError = message;
      developer.log(message, name: 'Blueprint', level: 1000);
      return zeros;
    }
    final entry = function.entry;
    if (entry == null) return zeros;
    final scope = _FunctionScope(this, function);
    for (final v in f.localVariables) {
      scope.locals[v.name] = _typed(v.type ?? LuminaPinType.float, v.defaultValue);
    }
    final inputs = {
      for (final i in f.inputs) i.name: args.containsKey(i.name) ? (args[i.name] ?? _typed(i.type ?? LuminaPinType.float, i.defaultValue)) : _typed(i.type ?? LuminaPinType.float, i.defaultValue),
    };
    _callDepth++;
    try {
      if (f.pure) {
        final result = function.result;
        if (result == null) return zeros;
        final frame = _Frame(scope, entry.id, inputs);
        return {for (final o in f.outputs) o.name: frame._input(result, o.name, function.pins[result.id]!)};
      }
      LuminaBlueprintInterpreter.run(scope, entry.id, 'exec_out', inputs, eventNodeId: entry.id);
      return scope.result ?? zeros;
    } finally {
      _callDepth--;
    }
  }

  /// Binds each EnhancedInputAction node's wired trigger pins once the pawn
  /// is player-controlled and in a world.
  void _bindInput() {
    if (blueprintInputBound) return;
    final bindings = <LuminaBlueprintInputBinding>[];
    for (final node in _graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction)) {
      final name = node.literals['action'] as String;
      final action = blueprintClass.inputActions.where((a) => a.name == name).firstOrNull ?? LuminaInputAction(name);
      final valueType = _pins[node.id]!.outputs.firstWhere((p) => p.id == 'action_value').type;
      for (final state in TriggerState.values) {
        if (_graph.wiresFrom(node.id, state.name).isEmpty) continue;
        bindings.add(LuminaBlueprintInputBinding(action, state, (value) {
          _run(node.id, state.name, {'action_value': _actionValue(valueType, value)});
        }));
      }
    }
    bindBlueprintInput(bindings);
  }

  static Object? _actionValue(LuminaPinType type, LuminaInputActionValue value) => switch (type) {
        LuminaPinType.boolean => value.asBool,
        LuminaPinType.float => value.asAxis1D,
        LuminaPinType.vector2D => value.asAxis2D,
        LuminaPinType.vector => value.asAxis3D,
        _ => null,
      };

  // --- The interpreter host ------------------------------------------------

  @override
  LuminaBlueprintGraph get hostGraph => _graph;
  @override
  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins => _pins;
  @override
  Map<String, Object?> get hostVariables => variables;
  @override
  LuminaActor get hostSelf => this;
  @override
  int get hostMaxNodes => maxNodesPerEvent;
  @override
  String get hostName => blueprintClass.name;
  @override
  void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? printed}) =>
      blueprintTrace(eventNodeId, nodeId, registryId, values, printed: printed);
  @override
  void hostDelay(String nodeId, double seconds, void Function() resume) => blueprintDelay(nodeId, seconds, resume);
  @override
  void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume) =>
      blueprintRetriggerableDelay(nodeId, seconds, resume);
  @override
  void hostError(String message) => lastError = message;
  @override
  Map<String, Object?> get hostFlowState => blueprintFlowState;
  @override
  Map<String, Object?> get hostLocals => const {};
  @override
  LuminaBlueprintInstance get hostInstance => this;

  void _run(String nodeId, String execPin, Map<String, Object?> eventOutputs, {String? eventNodeId}) =>
      LuminaBlueprintInterpreter.run(this, nodeId, execPin, eventOutputs, eventNodeId: eventNodeId);

  /// A Timeline node's runtime, wired to re-enter the graph at its Update /
  /// Finished pins with the track values as the node's outputs.
  LuminaTimeline timelineFor(LuminaBlueprintGraphHost host, LuminaBlueprintNode node) {
    final existing = blueprintTimelines[node.id];
    if (existing != null) return existing;
    final timeline = blueprintTimeline(node.id, node.literals);
    void fire(String pin) {
      final outputs = <String, Object?>{...timeline.values(), 'direction': timeline.direction};
      // The track values are the node's outputs for this run, as an event's are.
      LuminaBlueprintInterpreter.run(host, node.id, pin, outputs, eventNodeId: node.id);
    }

    timeline.onUpdate = () => fire('update');
    timeline.onFinished = () => fire('finished');
    return timeline;
  }
}
