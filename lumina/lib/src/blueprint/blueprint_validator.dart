import '../world/level_preloader.dart';
import '../input/input_action.dart';
import 'blueprint_function_library.dart';
import 'blueprint_function_registry.dart';
import 'blueprint_model.dart';
import 'editor_nodes.dart';
import 'level_blueprint.dart';
import 'node_library.dart';

enum LuminaBlueprintSeverity { error, warning }

/// One compiler-results row: what is wrong, and the node / pin it is on.
class LuminaBlueprintDiagnostic {
  final LuminaBlueprintSeverity severity;
  final String message;
  final String? nodeId;
  final String? pinId;

  const LuminaBlueprintDiagnostic(this.severity, this.message, {this.nodeId, this.pinId});

  bool get isError => severity == LuminaBlueprintSeverity.error;

  @override
  String toString() => '${severity.name}: $message${nodeId == null ? '' : ' [$nodeId${pinId == null ? '' : '.$pinId'}]'}';
}

/// Checks a Blueprint against the node library: unknown nodes,
/// wire types and multiplicity, pure cycles, unset required inputs, missing
/// input actions and variables, duplicate events. An empty list means it can
/// run in the VM and be generated to Dart.
List<LuminaBlueprintDiagnostic> validateBlueprint(
  LuminaBlueprintDocument doc, {
  List<LuminaInputAction> inputActions = const [],
  String? className,
  LuminaBlueprintTypeContext? typeContext,
}) {
  // Comment boxes and reroutes are the editor's.
  doc = LuminaBlueprintEditorNodes.forEngine(doc);
  final out = <LuminaBlueprintDiagnostic>[];
  void error(String m, {String? node, String? pin}) =>
      out.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, m, nodeId: node, pinId: pin));
  void warning(String m, {String? node, String? pin}) =>
      out.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning, m, nodeId: node, pinId: pin));

  final context = typeContext ??
      LuminaBlueprintTypeContext.forDocument(doc, inputActions: inputActions, className: className);
  // Function and macro graphs resolve Self as the event graph does.
  if (context.isLevelScope) className = LuminaLevelBlueprintDocument.parentClass;
  if (context.isWidgetScope) className = LuminaBlueprintObjectClass.name(context.selfClass);

  for (final v in doc.variables) {
    if (v.type == null) error("Variable '${v.name}' has an unknown type '${v.typeName}'.");
  }
  // A Level Blueprint scripts the level; it has no components,
  // and its placed actors are referred to by unique names.
  if (context.isLevelScope) {
    if (doc.components.isNotEmpty) {
      error('Level Blueprints have no components (${doc.components.map((c) => c.name).join(', ')}).');
    }
    final seen = <String>{};
    for (final a in context.levelActors!) {
      if (!seen.add(a.name)) error("Two actors in this level are named '${a.name}'; rename one so Get ${a.name} is unambiguous.");
    }
  }
  // A Widget Blueprint scripts its widget; it has no components.
  if (context.isWidgetScope && doc.components.isNotEmpty) {
    error('Widget Blueprints have no components (${doc.components.map((c) => c.name).join(', ')}).');
  }
  _validateGraph(doc.eventGraph, context, error, warning);
  // User functions and macros: their own graphs, in their own scope.
  for (final f in doc.functions) {
    final fc = LuminaBlueprintTypeContext.forDocument(doc,
        inputActions: inputActions,
        className: className,
        actorParents: context.actorParents,
        dispatcherOwners: context.dispatcherOwners,
        enums: context.enums,
        interfaces: context.interfaces,
        functionScope: f,
        levelActors: context.levelActors,
        customEventOwners: context.customEventOwners,
        widgetVariables: context.widgetVariables);
    for (final v in [...f.inputs, ...f.outputs, ...f.localVariables]) {
      if (v.type == null) error("Function '${f.name}': '${v.name}' has an unknown type '${v.typeName}'.");
    }
    if (f.graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry).length != 1) {
      error("Function '${f.name}' needs exactly one Function Entry node.");
    }
    if (f.outputs.isNotEmpty && !f.graph.nodes.any((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult)) {
      error("Function '${f.name}' has outputs but no Return node.");
    }
    _validateGraph(f.graph, fc, error, warning, scope: f.name);
  }
  for (final m in doc.macros) {
    final mc = LuminaBlueprintTypeContext.forDocument(doc,
        inputActions: inputActions,
        className: className,
        actorParents: context.actorParents,
        macroScope: m,
        levelActors: context.levelActors,
        customEventOwners: context.customEventOwners,
        widgetVariables: context.widgetVariables);
    if (!m.graph.nodes.any((n) => n.registryId == LuminaBlueprintNodeLibrary.macroInput)) {
      error("Macro '${m.name}' has no Inputs node.");
    }
    _validateGraph(m.graph, mc, error, warning, scope: m.name);
  }
  return out;
}

/// Nodes whose Target must be a Player Controller.
const Set<String> _controllerTargetNodes = {
  'set_show_mouse_cursor',
  'set_input_mode_game_and_ui',
  'set_input_mode_game_only',
  'set_input_mode_ui_only',
};

/// Checks one graph (the event graph, a function's or a macro's) in [context].
void _validateGraph(
  LuminaBlueprintGraph graph,
  LuminaBlueprintTypeContext context,
  void Function(String m, {String? node, String? pin}) error,
  void Function(String m, {String? node, String? pin}) warning, {
  String? scope,
}) {
  // Nodes: known, not deprecated, settings present, no duplicate ids/events.
  final pins = <String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})>{};
  final seenIds = <String>{};
  final seenEvents = <String, String>{};
  for (final node in graph.nodes) {
    if (!seenIds.add(node.id)) error("Two nodes share the id '${node.id}'.", node: node.id);
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec == null) {
      error("Unknown node '${node.registryId}'.", node: node.id);
      continue;
    }
    pins[node.id] = LuminaBlueprintNodeLibrary.pinsOf(node, context)!;
    if (spec.deprecation != null) warning('${spec.title}: ${spec.deprecation}', node: node.id);
    if (spec.unsupported != null) warning('${spec.title}: ${spec.unsupported}', node: node.id);
    // A controller-only node with no Target acts on player 0
    // (Lumina warns and picks the obvious one).
    if (_controllerTargetNodes.contains(spec.id) &&
        !graph.wires.any((w) => w.toNodeId == node.id && w.toPinId == 'target')) {
      warning('${spec.title}: Target is not connected; it acts on Player Controller 0. '
          'Wire Get Player Controller into Target to make that explicit.', node: node.id, pin: 'target');
    }

    if (spec.id == LuminaBlueprintNodeLibrary.enhancedInputAction) {
      final action = node.literals['action'];
      if (action is! String || action.isEmpty) {
        error('EnhancedInputAction has no input action selected.', node: node.id);
      } else if (context.inputAction(action) == null) {
        error("Input action '$action' does not exist in the project.", node: node.id);
      }
    }
    if (spec.id == LuminaBlueprintNodeLibrary.variableGet || spec.id == LuminaBlueprintNodeLibrary.variableSet) {
      final name = node.literals['variable'];
      if (name is! String || context.variable(name) == null) {
        error("${spec.title} names an unknown variable '${name ?? ''}'.", node: node.id);
      }
    }
    if (spec.id == LuminaBlueprintNodeLibrary.getWidgetElement) {
      final element = node.literals['element'];
      if (element is! String || element.isEmpty) {
        error('Get Element names no element.', node: node.id);
      } else if (context.widgetClasses.isNotEmpty && context.widgetElement(node.literals['class'] as String?, element) == null) {
        warning("Get $element: no widget class has an element '$element'; it reads null at run time.", node: node.id);
      }
    }
    if (spec.id == LuminaBlueprintNodeLibrary.getComponent) {
      final name = node.literals['component'];
      if (name is! String || context.component(name) == null) {
        error("Get Component names an unknown component '${name ?? ''}'.", node: node.id);
      }
    }
    if (LuminaBlueprintNodeLibrary.classTypedNodes.contains(spec.id) || spec.id == 'is_a') {
      final stored = node.literals['class'];
      final cls = stored ?? spec.inputs.where((p) => p.id == 'class').firstOrNull?.defaultValue;
      if (graph.wireInto(node.id, 'class') == null && (cls is! String || !LuminaBlueprintObjectClass.isClassString(cls))) {
        error("${spec.title} needs a class (Actor:BP_Door, Widget:WBP_HUD, Component:LuminaCameraComponent, …).",
            node: node.id, pin: 'class');
      }
    }
    if (LuminaBlueprintNodeLibrary.traceNodes.contains(spec.id) && graph.wireInto(node.id, 'channel') == null) {
      final channel = node.literals['channel'] ?? 'Visibility';
      if (channel is! String || !LuminaBlueprintFunctionLibrary.isTraceChannel(channel)) {
        error("${spec.title}: '$channel' is not a trace channel (Visibility, Camera, WorldStatic, WorldDynamic, Pawn, Layer 1–32).",
            node: node.id, pin: 'channel');
      }
    }
    if (spec.id == 'while_loop' && graph.wireInto(node.id, 'condition') == null && node.literals['condition'] == true) {
      warning('WhileLoop: the condition is always true; the loop stops at ${LuminaBlueprintNodeLibrary.whileLoopCap} iterations.',
          node: node.id, pin: 'condition');
    }
    // A literal Level Name should be a project level (a wired,
    // computed name is checked when it runs).
    if (LuminaBlueprintNodeLibrary.levelLoadLatents.contains(spec.id) && graph.wireInto(node.id, 'level_name') == null) {
      final level = node.literals['level_name'];
      if (level is! String || level.isEmpty) {
        warning('${spec.title} names no level.', node: node.id, pin: 'level_name');
      } else if (!LuminaProjectLevels.isKnown(level)) {
        warning("${spec.title}: '$level' is not a level of this project; the node reports On Error when it runs.",
            node: node.id, pin: 'level_name');
      }
    }
    if (spec.id == 'set_actor_location' && node.literals['sweep'] == true) {
      warning('SetActorLocation: Sweep is not supported; the actor teleports.', node: node.id, pin: 'sweep');
    }
    // Level-only nodes, level actors and components.
    if (LuminaBlueprintNodeLibrary.levelOnlyNodes.contains(spec.id) && !context.isLevelScope) {
      error('${spec.title} can only be placed in a Level Blueprint.', node: node.id);
    }
    if (context.isLevelScope && LuminaBlueprintNodeLibrary.selfComponentNodes.contains(spec.id)) {
      error('${node.title}: Level Blueprints have no components.', node: node.id);
    }
    if (spec.id == LuminaBlueprintNodeLibrary.getLevelActor && context.isLevelScope) {
      final actor = node.literals['actor'];
      if (actor is! String || actor.isEmpty) {
        error('Get Level Actor names no actor.', node: node.id);
      } else if (context.levelActor(actor) == null) {
        error("${node.title}: no actor named '$actor' in this level (was it deleted or renamed?).", node: node.id);
      }
    }
    // Widget-only nodes, widget variables and bound element events.
    final widgetError = LuminaBlueprintNodeLibrary.widgetScopeError(node, spec, context);
    if (widgetError != null) error(widgetError, node: node.id);
    // Names must resolve.
    String? lit(String key) => node.literals[key] is String ? node.literals[key] as String : null;
    switch (spec.id) {
      case LuminaBlueprintNodeLibrary.callFunction:
      case LuminaBlueprintNodeLibrary.callFunctionPure:
        if (context.function(lit('function')) == null) error("${spec.title} names an unknown function '${lit('function') ?? ''}'.", node: node.id);
      case LuminaBlueprintNodeLibrary.callCustomEvent:
        final targetClass = lit('class');
        if (targetClass != null && LuminaBlueprintObjectClass.isClassString(targetClass) && targetClass != context.selfClass) {
          // Another class's event: checked when that class is known.
          final owner = LuminaBlueprintObjectClass.name(targetClass);
          if (context.customEventOwners.containsKey(owner) && context.customEventOf(targetClass, lit('event')) == null) {
            error("${spec.title}: $owner has no custom event '${lit('event') ?? ''}'.", node: node.id);
          }
        } else if (context.customEvent(lit('event')) == null) {
          error("${spec.title} names an unknown custom event '${lit('event') ?? ''}'.", node: node.id);
        }
      case LuminaBlueprintNodeLibrary.callMacro:
        if (context.macro(lit('macro')) == null) error("Macro names an unknown macro '${lit('macro') ?? ''}'.", node: node.id);
      case LuminaBlueprintNodeLibrary.customEvent:
        if (lit('name') == null || lit('name')!.isEmpty) error('Custom Event has no name.', node: node.id);
      case LuminaBlueprintNodeLibrary.callDispatcher:
        if (context.dispatcher(lit('dispatcher')) == null) {
          error("${spec.title} names an unknown dispatcher '${lit('dispatcher') ?? ''}'.", node: node.id);
        }
      case LuminaBlueprintNodeLibrary.bindEventToDispatcher:
      case LuminaBlueprintNodeLibrary.unbindEventFromDispatcher:
      case LuminaBlueprintNodeLibrary.unbindAllEvents:
        // The dispatcher lives on the target; only an unwired target (Self)
        // or a known owner class can be checked here.
        if (lit('dispatcher') == null || lit('dispatcher')!.isEmpty) {
          error('${spec.title} names no dispatcher.', node: node.id);
        } else if (graph.wireInto(node.id, 'target') == null && context.dispatcher(lit('dispatcher')) == null) {
          error("${spec.title}: Self has no dispatcher '${lit('dispatcher')}'.", node: node.id);
        }
      case LuminaBlueprintNodeLibrary.interfaceMessage:
      case LuminaBlueprintNodeLibrary.eventInterfaceFunction:
        final iface = context.interface(lit('interface'));
        if (iface == null) {
          error("${spec.title} names an unknown interface '${lit('interface') ?? ''}'.", node: node.id);
        } else if (iface.function(lit('function')) == null) {
          error("${spec.title}: interface '${iface.name}' has no function '${lit('function') ?? ''}'.", node: node.id);
        }
      case LuminaBlueprintNodeLibrary.implementsInterface:
        if (context.interface(lit('interface')) == null) error("${spec.title} names an unknown interface '${lit('interface') ?? ''}'.", node: node.id);
      case LuminaBlueprintNodeLibrary.switchOnEnum:
      case LuminaBlueprintNodeLibrary.enumLiteral:
      case 'int_to_enum':
      case 'get_enum_value_count':
        if (context.enumeration(lit('enum')) == null) error("${spec.title} names an unknown enum '${lit('enum') ?? ''}'.", node: node.id);
      case LuminaBlueprintNodeLibrary.localVariableGet:
      case LuminaBlueprintNodeLibrary.localVariableSet:
        if (context.localVariable(lit('variable')) == null) error("${spec.title} names an unknown local variable '${lit('variable') ?? ''}'.", node: node.id);
      case LuminaBlueprintNodeLibrary.functionEntry:
      case LuminaBlueprintNodeLibrary.functionResult:
        if (context.functionScope == null) error('${spec.title} can only be placed in a function graph.', node: node.id);
      case LuminaBlueprintNodeLibrary.macroInput:
      case LuminaBlueprintNodeLibrary.macroOutput:
        if (context.macroScope == null) error('${spec.title} can only be placed in a macro graph.', node: node.id);
    }
    if (spec.kind == LuminaBlueprintNodeKind.event) {
      final key = switch (spec.id) {
        LuminaBlueprintNodeLibrary.enhancedInputAction => '${spec.id}:${node.literals['action']}',
        LuminaBlueprintNodeLibrary.customEvent => '${spec.id}:${node.literals['name']}',
        LuminaBlueprintNodeLibrary.eventInterfaceFunction => '${spec.id}:${node.literals['function']}',
        LuminaBlueprintNodeLibrary.eventWidgetElement => '${spec.id}:${node.literals['element']}:${node.literals['event']}',
        // Event Level BeginPlay is Event BeginPlay in a Level Blueprint.
        _ => LuminaBlueprintNodeLibrary.levelEvents[spec.id] ?? spec.id,
      };
      final first = seenEvents[key];
      if (first != null) {
        if (spec.id == LuminaBlueprintNodeLibrary.customEvent) {
          error("Custom event '${node.literals['name']}' is declared twice.", node: node.id);
        } else {
          error('${node.title} is placed twice; an event can have one node.', node: node.id);
        }
      } else {
        seenEvents[key] = node.id;
      }
    }
  }

  LuminaBlueprintPinSpec? pinOf(String nodeId, String pinId, {required bool output}) {
    final p = pins[nodeId];
    if (p == null) return null;
    for (final s in output ? p.outputs : p.inputs) {
      if (s.id == pinId) return s;
    }
    return null;
  }

  // Wires: ends exist, types match, multiplicity.
  final execOutWires = <String, int>{};
  final dataInWires = <String, int>{};
  for (final w in graph.wires) {
    final from = pinOf(w.fromNodeId, w.fromPinId, output: true);
    final to = pinOf(w.toNodeId, w.toPinId, output: false);
    if (!pins.containsKey(w.fromNodeId) || !pins.containsKey(w.toNodeId)) {
      if (graph.node(w.fromNodeId) == null || graph.node(w.toNodeId) == null) {
        error('A wire connects a node that does not exist.', node: graph.node(w.toNodeId) != null ? w.toNodeId : w.fromNodeId);
      }
      continue;
    }
    if (from == null) {
      error("Output pin '${w.fromPinId}' does not exist.", node: w.fromNodeId, pin: w.fromPinId);
      continue;
    }
    if (to == null) {
      error("Input pin '${w.toPinId}' does not exist.", node: w.toNodeId, pin: w.toPinId);
      continue;
    }
    final mismatch = LuminaBlueprintNodeLibrary.connectionError(from, to, context: context);
    if (mismatch != null) error(mismatch, node: w.toNodeId, pin: w.toPinId);
    if (to.type == LuminaPinType.delegate) {
      final source = graph.node(w.fromNodeId);
      if (source == null || source.registryId != LuminaBlueprintNodeLibrary.customEvent || w.fromPinId != 'delegate') {
        error("A delegate pin takes a custom event's Delegate output only.", node: w.toNodeId, pin: w.toPinId);
      } else {
        final target = graph.node(w.toNodeId)!;
        final params = LuminaBlueprintNodeLibrary.customEventParameters(source);
        if ((target.registryId == 'set_timer_by_event' || target.registryId == 'set_timer_for_next_tick') && params.isNotEmpty) {
          error("Set Timer: custom event '${source.literals['name']}' has parameters; a timer can only call an event without them.",
              node: w.toNodeId, pin: w.toPinId);
        }
        if (target.registryId == LuminaBlueprintNodeLibrary.bindEventToDispatcher) {
          final d = context.dispatcher(target.literals['dispatcher'] as String?);
          if (d != null && d.parameters.length != params.length) {
            warning("Bind Event: '${source.literals['name']}' takes ${params.length} parameter(s) but dispatcher '${d.name}' sends ${d.parameters.length}.",
                node: w.toNodeId, pin: w.toPinId);
          }
        }
      }
    }
    if (from.type == LuminaPinType.exec) {
      final key = '${w.fromNodeId}.${w.fromPinId}';
      if ((execOutWires[key] = (execOutWires[key] ?? 0) + 1) == 2) {
        error('An exec output can have one wire; use a Sequence to run several.', node: w.fromNodeId, pin: w.fromPinId);
      }
    } else {
      final key = '${w.toNodeId}.${w.toPinId}';
      if ((dataInWires[key] = (dataInWires[key] ?? 0) + 1) == 2) {
        error('A data input can have one wire.', node: w.toNodeId, pin: w.toPinId);
      }
    }
  }

  // Required inputs.
  for (final node in graph.nodes) {
    final p = pins[node.id];
    if (p == null) continue;
    for (final input in p.inputs) {
      if (!input.required) continue;
      if (graph.wireInto(node.id, input.id) != null || node.literals.containsKey(input.id)) continue;
      error("'${input.name}' must be connected.", node: node.id, pin: input.id);
    }
  }

  // Cycles through pure nodes (a pure node cannot depend on itself).
  bool isPure(String nodeId) {
    final spec = LuminaBlueprintNodeLibrary.spec(graph.node(nodeId)?.registryId ?? '');
    return spec?.kind == LuminaBlueprintNodeKind.pure;
  }

  final pureEdges = <String, List<String>>{};
  for (final w in graph.wires) {
    if (isPure(w.fromNodeId) && isPure(w.toNodeId)) {
      (pureEdges[w.toNodeId] ??= []).add(w.fromNodeId);
    }
  }
  final state = <String, int>{}; // 1 visiting, 2 done
  final reported = <String>{};
  bool visit(String n) {
    if (state[n] == 2) return false;
    if (state[n] == 1) return true;
    state[n] = 1;
    for (final dep in pureEdges[n] ?? const <String>[]) {
      if (visit(dep)) {
        if (reported.add(n)) error('A pure node depends on its own output (cycle).', node: n);
        state[n] = 2;
        return true;
      }
    }
    state[n] = 2;
    return false;
  }

  for (final n in pureEdges.keys) {
    visit(n);
  }

  // Every executable node has a behaviour.
  for (final node in graph.nodes) {
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec == null || spec.kind == LuminaBlueprintNodeKind.event) continue;
    if (LuminaBlueprintFunctionRegistry.isDeclaredOnly(spec.id)) {
      // A project function the editor knows from its manifest.
      warning('${spec.title} ${LuminaBlueprintFunctionRegistry.unavailableMessage}.', node: node.id);
      continue;
    }
    if (!LuminaBlueprintNodeLibrary.intrinsics.contains(spec.id) &&
        !LuminaBlueprintFunctionLibrary.functions.containsKey(spec.id)) {
      error('${spec.title} has no implementation.', node: node.id);
    }
  }
}

