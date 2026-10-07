import 'dart:convert';
import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/widgets.dart' show BuildContext, Widget;

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

/// What a [BlueprintGraphEditor] edits against: the document's variables and
/// input actions, and its undo history. The Blueprint editor, the Animation
/// Blueprint editor's event graph and each transition rule share one canvas
/// through this seam (one graph canvas).
abstract interface class BlueprintGraphHost implements Listenable {
  LuminaBlueprintTypeContext get typeContext;

  /// Available widget classes in the project (UMG widgets).
  List<String> get availableWidgetClasses;

  /// Adds [variable] to the document without recording an undo step: called
  /// inside [mutate] by Promote to Variable, so the
  /// variable and its Set node are one step. Hosts without variables ignore it.
  void declareVariable(LuminaBlueprintVariable variable);

  /// Runs [mutation] as one undoable step labelled [label]. A mutation that
  /// returns null or false changes nothing and records nothing.
  T mutate<T>(String label, T Function() mutation);

  /// Starts a coalesced interaction (a node drag): edits between this and
  /// [endInteraction] become one undo step.
  void beginInteraction(String label);

  /// Ends the interaction. [layoutOnly] edits (moving nodes) do not make the
  /// compiled code stale.
  void endInteraction({bool layoutOnly = false});
}

/// A live problem on a node, drawn as the node's banner.
class BlueprintNodeProblem {
  final String message;
  final bool isError;
  const BlueprintNodeProblem(this.message, {this.isError = true});
}

typedef BlueprintResolvedPins = ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs});

/// Edits one [LuminaBlueprintGraph] through lumina's node library: placing
/// nodes, wiring typed pins, literals, input actions and variables, with
/// every change an undoable step on the [host]. Selection lives here; the
/// document lives in the host.
class BlueprintGraphEditor extends ChangeNotifier {
  final BlueprintGraphHost host;
  /// The graph edited now; looked up on every access because an undo
  /// replaces the host's document.
  final LuminaBlueprintGraph? Function() graphSource;

  /// Library nodes this graph accepts (a transition rule: pure nodes only).
  final bool Function(LuminaBlueprintNodeSpec spec)? nodeFilter;

  /// The last compile's diagnostics, for outlining failing nodes.
  final Iterable<LuminaBlueprintDiagnostic> Function()? diagnosticsSource;

  /// The type context this graph resolves pins in when it is not the
  /// host's own (a function graph scopes its entry / result / local
  /// variables, a macro its inputs / outputs).
  final LuminaBlueprintTypeContext Function()? contextSource;

  /// Dropdown choices for a pin the host knows better than the library: the
  /// project's asset paths of a kind (`sound`, `montage`, `material`,
  /// `particle`, `level`, `savegame`) for asset pins.
  final List<String>? Function(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin)? pinOptionsProvider;

  /// Rows the right-click palette pins first (e.g.
  /// `Create a Reference to <Actor>` for the outliner's selected actors).
  final List<BlueprintPaletteEntry> Function()? pinnedEntriesSource;

  final Set<String> _selected = {};

  /// Asks the canvas to frame a node (Compiler Results navigation).
  final ValueNotifier<({String nodeId, int serial})?> focusRequest = ValueNotifier(null);
  int _focusSerial = 0;
  static int _ids = 0;

  BlueprintGraphEditor({
    required this.host,
    required this.graphSource,
    this.nodeFilter,
    this.diagnosticsSource,
    this.contextSource,
    this.pinOptionsProvider,
    this.pinnedEntriesSource,
  });

  static final LuminaBlueprintGraph _none = LuminaBlueprintGraph();

  LuminaBlueprintGraph get graph => graphSource() ?? _none;
  List<LuminaBlueprintNode> get nodes => graph.nodes;
  List<LuminaBlueprintWire> get wires => graph.wires;
  LuminaBlueprintTypeContext get context => contextSource?.call() ?? host.typeContext;

  /// The host replaced or edited the document: repaint.
  void documentChanged() => notifyListeners();

  BlueprintTraceRecorder? _debug;

  /// Live execution of the running instance this graph belongs to, during
  /// Play; null otherwise.
  BlueprintTraceRecorder? get debug => _debug;
  set debug(BlueprintTraceRecorder? value) {
    if (identical(_debug, value)) return;
    _debug = value;
    notifyListeners();
  }

  static String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_ids++}';

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  LuminaBlueprintNode? node(String id) => graph.node(id);

  /// The node's pins as the library resolves them now (an input action's
  /// Action Value takes the action's type); stored pins for an unknown node.
  BlueprintResolvedPins pinsOf(LuminaBlueprintNode node) {
    if (BlueprintEditorNodes.isReroute(node)) return BlueprintEditorNodes.reroutePins(node);
    if (BlueprintEditorNodes.isComment(node)) return (inputs: const [], outputs: const []);
    final resolved = LuminaBlueprintNodeLibrary.pinsOf(node, context);
    if (resolved != null) {
      if (node.registryId == 'format_string') return _formatStringPins(node, resolved);
      return resolved;
    }
    LuminaBlueprintPinSpec spec(LuminaBlueprintPin p) => LuminaBlueprintPinSpec(p.id, p.name, p.type ?? LuminaPinType.exec);
    return (inputs: node.inputs.map(spec).toList(), outputs: node.outputs.map(spec).toList());
  }

  /// Format Text grows one `{n}` pin per placeholder of its Format literal:
  /// the library declares `{0}`..`{3}`; the editor
  /// shows the ones the format names, plus any that is still wired.
  BlueprintResolvedPins _formatStringPins(LuminaBlueprintNode node, BlueprintResolvedPins resolved) {
    final format = (node.literals['format'] ?? resolved.inputs.firstWhere((p) => p.id == 'format').defaultValue)?.toString() ?? '';
    final used = {for (final m in RegExp(r'\{(\d+)\}').allMatches(format)) 'arg_${m.group(1)}'};
    final wired = {for (final w in wires) if (w.toNodeId == node.id) w.toPinId};
    return (
      inputs: [
        for (final p in resolved.inputs)
          if (!p.id.startsWith('arg_') || used.contains(p.id) || wired.contains(p.id)) p
      ],
      outputs: resolved.outputs,
    );
  }

  LuminaBlueprintPinSpec? pin(String nodeId, String pinId, {required bool output}) {
    final n = node(nodeId);
    if (n == null) return null;
    final pins = pinsOf(n);
    for (final p in output ? pins.outputs : pins.inputs) {
      if (p.id == pinId) return p;
    }
    return null;
  }

  bool isConnected(String nodeId, String pinId, {required bool output}) => output
      ? wires.any((w) => w.fromNodeId == nodeId && w.fromPinId == pinId)
      : wires.any((w) => w.toNodeId == nodeId && w.toPinId == pinId);

  /// The palette for this graph: library nodes allowed here, variable nodes
  /// per declared variable.
  List<BlueprintPaletteEntry> paletteEntries() => BlueprintPalette.entriesFor(context, null, filter: nodeFilter);

  /// The graph actions the right-click palette pins first:
  /// Add Custom Event… where events are allowed, Add
  /// Comment, and the collapse actions when [canCollapse].
  List<BlueprintPaletteEntry> paletteActions({bool canCollapse = false}) => [
        for (final e in pinnedEntriesSource?.call() ?? const <BlueprintPaletteEntry>[])
          if (e.isAction || accepts(e.registryId)) e,
        if (accepts(LuminaBlueprintNodeLibrary.customEvent)) BlueprintPalette.addCustomEvent,
        BlueprintPalette.addComment,
        if (canCollapse && selectedNodeIds.isNotEmpty) ...[
          BlueprintPalette.collapseNodes,
          BlueprintPalette.collapseToFunction,
          BlueprintPalette.collapseToMacro,
        ],
      ];

  /// The context-sensitive palette for a drag off [from]:
  /// only nodes with a pin [from] can join, the typed rows of its class
  /// (`Get <Element>` of its widget class, the component tree from Self,
  /// `Cast To`), with Promote to Variable pinned first for a data output.
  List<BlueprintPaletteEntry> paletteEntriesFor(BlueprintPinRef from) =>
      BlueprintPalette.entriesFor(context, from, filter: nodeFilter, allowPromote: accepts(LuminaBlueprintNodeLibrary.variableSet));

  /// Live problems of [node]: an unknown or deprecated node, a missing input
  /// action or variable. Shown as a banner before any compile.
  List<BlueprintNodeProblem> problems(LuminaBlueprintNode node) {
    if (BlueprintEditorNodes.isEditorOnly(node.registryId)) return const [];
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec == null) return [BlueprintNodeProblem("Unknown node '${node.registryId}'")];
    final out = <BlueprintNodeProblem>[];
    String? lit(String key) => node.literals[key] is String ? node.literals[key] as String : null;
    switch (spec.id) {
      case LuminaBlueprintNodeLibrary.callFunction:
      case LuminaBlueprintNodeLibrary.callFunctionPure:
        if (context.function(lit('function')) == null) out.add(BlueprintNodeProblem("Unknown function '${lit('function') ?? ''}'"));
      case LuminaBlueprintNodeLibrary.callMacro:
        if (context.macro(lit('macro')) == null) out.add(BlueprintNodeProblem("Unknown macro '${lit('macro') ?? ''}'"));
      case LuminaBlueprintNodeLibrary.callCustomEvent:
        // Another class's event, on a Target of that class.
        var target = lit('class');
        if (target == null || target.isEmpty) {
          final inWire = graph.wireInto(node.id, 'target');
          if (inWire != null) {
            final fromPin = pin(inWire.fromNodeId, inWire.fromPinId, output: true);
            if (fromPin != null && fromPin.objectClass != null && fromPin.objectClass!.isNotEmpty) {
              target = fromPin.objectClass;
            }
          }
        }
        if (target != null && target.isNotEmpty && target != context.selfClass) {
          final raw = LuminaBlueprintObjectClass.name(target);
          final owner = raw.isEmpty ? target : raw;
          if (context.customEventOwners.containsKey(owner) && context.customEventOf(target, lit('event')) == null) {
            out.add(BlueprintNodeProblem("$owner has no custom event '${lit('event') ?? ''}'"));
          }
        } else if (context.customEvent(lit('event')) == null) {
          out.add(BlueprintNodeProblem("Unknown custom event '${lit('event') ?? ''}'"));
        }
      case LuminaBlueprintNodeLibrary.getLevelActor:
        // The placed actor was deleted or renamed.
        if (context.isLevelScope && context.levelActor(lit('actor')) == null) {
          out.add(BlueprintNodeProblem("No actor named '${lit('actor') ?? ''}' in this level"));
        }
      case LuminaBlueprintNodeLibrary.callDispatcher:
      case LuminaBlueprintNodeLibrary.bindEventToDispatcher:
      case LuminaBlueprintNodeLibrary.unbindEventFromDispatcher:
      case LuminaBlueprintNodeLibrary.unbindAllEvents:
        final dName = lit('dispatcher');
        final targetClass = lit('class');
        final exists = (targetClass != null && targetClass.isNotEmpty)
            ? context.dispatcher(dName, ownerClass: targetClass) != null
            : context.dispatcher(dName) != null;
        if (!exists) out.add(BlueprintNodeProblem("Unknown dispatcher '${dName ?? ''}'"));
      case LuminaBlueprintNodeLibrary.interfaceMessage:
      case LuminaBlueprintNodeLibrary.eventInterfaceFunction:
        if (context.interface(lit('interface'))?.function(lit('function')) == null) {
          out.add(BlueprintNodeProblem("Unknown interface function '${lit('interface') ?? ''}.${lit('function') ?? ''}'"));
        }
      case LuminaBlueprintNodeLibrary.switchOnEnum:
      case LuminaBlueprintNodeLibrary.enumLiteral:
        if (context.enumeration(lit('enum')) == null) out.add(BlueprintNodeProblem("Unknown enum '${lit('enum') ?? ''}'"));
      case LuminaBlueprintNodeLibrary.localVariableGet:
      case LuminaBlueprintNodeLibrary.localVariableSet:
        if (context.localVariable(lit('variable')) == null) out.add(BlueprintNodeProblem("Unknown local variable '${lit('variable') ?? ''}'"));
      case LuminaBlueprintNodeLibrary.customEvent:
        final name = lit('name') ?? '';
        if (name.isEmpty) {
          out.add(const BlueprintNodeProblem('The custom event needs a name'));
        } else if (nodes.any((n) => n.id != node.id && n.registryId == spec.id && n.literals['name'] == name)) {
          out.add(BlueprintNodeProblem("Duplicate custom event '$name'"));
        }
    }
    if (spec.deprecation != null) out.add(BlueprintNodeProblem(spec.deprecation!, isError: false));
    if (spec.unsupported != null) out.add(BlueprintNodeProblem(spec.unsupported!, isError: false));
    if (spec.id == LuminaBlueprintNodeLibrary.enhancedInputAction) {
      final action = node.literals['action'];
      if (action is! String || action.isEmpty) {
        out.add(const BlueprintNodeProblem('No input action selected'));
      } else if (context.inputAction(action) == null) {
        out.add(BlueprintNodeProblem("Input action '$action' is not in the project"));
      }
    }
    if (spec.id == LuminaBlueprintNodeLibrary.variableGet || spec.id == LuminaBlueprintNodeLibrary.variableSet) {
      final name = node.literals['variable'];
      var targetClass = node.literals['class'] as String?;
      if (targetClass == null || targetClass.isEmpty) {
        final inWire = graph.wireInto(node.id, 'target');
        if (inWire != null) {
          final fromPin = pin(inWire.fromNodeId, inWire.fromPinId, output: true);
          if (fromPin != null && fromPin.objectClass != null && fromPin.objectClass!.isNotEmpty) {
            targetClass = fromPin.objectClass;
          }
        }
      }
      final exists = (targetClass != null && targetClass.isNotEmpty)
          ? context.variableOf(targetClass, name as String?) != null
          : (name is String && context.variable(name) != null);
      if (!exists) {
        out.add(BlueprintNodeProblem("Unknown variable '${name ?? ''}'"));
      }
    }
    if (spec.id == LuminaBlueprintNodeLibrary.getComponent) {
      final name = node.literals['component'];
      var targetClass = node.literals['class'] as String?;
      if (targetClass == null || targetClass.isEmpty) {
        final inWire = graph.wireInto(node.id, 'target');
        if (inWire != null) {
          final fromPin = pin(inWire.fromNodeId, inWire.fromPinId, output: true);
          if (fromPin != null && fromPin.objectClass != null && fromPin.objectClass!.isNotEmpty) {
            targetClass = fromPin.objectClass;
          }
        }
      }
      final exists = (targetClass != null && targetClass.isNotEmpty)
          ? context.componentOf(targetClass, name as String?) != null
          : (name is String && context.component(name) != null);
      if (!exists) {
        out.add(BlueprintNodeProblem("Unknown component '${name ?? ''}'"));
      }
    }
    return out;
  }

  /// Nodes the last compile reported an error on.
  Set<String> get errorNodeIds => {
        for (final d in diagnosticsSource?.call() ?? const <LuminaBlueprintDiagnostic>[])
          if (d.isError && d.nodeId != null) d.nodeId!,
      };

  /// Why a wire from [fromNodeId].[fromPinId] (an output) to
  /// [toNodeId].[toPinId] (an input) cannot be made, or null when it can.
  String? whyNotConnect(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    if (fromNodeId == toNodeId) return 'A node cannot connect to itself';
    final from = pin(fromNodeId, fromPinId, output: true);
    final to = pin(toNodeId, toPinId, output: false);
    if (from == null || to == null) return 'No such pin';
    if (from.type != to.type && (from.type == LuminaPinType.exec || to.type == LuminaPinType.exec)) {
      return 'Exec pins connect only to exec pins';
    }
    // A delegate comes only from a Custom Event's red pin, or
    // through reroutes of one.
    if (to.type == LuminaPinType.delegate) {
      final source = node(fromNodeId);
      if (source != null && !BlueprintEditorNodes.isReroute(source) &&
          !(source.registryId == LuminaBlueprintNodeLibrary.customEvent && fromPinId == 'delegate')) {
        return 'Only a Custom Event delegate can be bound here';
      }
    }
    // Types, object classes and array element types.
    return LuminaBlueprintNodeLibrary.connectionError(from, to, context: context);
  }

  // ---------------------------------------------------------------------------
  // Presentation seams: the canvas asks the editor rather than the Blueprint
  // pin style, so a graph with its own pin types (the Material Editor's)
  // shares the canvas. The defaults are the Blueprint look.
  // ---------------------------------------------------------------------------

  /// The colour of [pin]'s anchor and of wires leaving it.
  Color pinColor(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) =>
      BlueprintPinStyle.color(pin.type);

  /// [pin]'s type as the context-sensitive palette names it.
  String pinTypeLabel(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) =>
      BlueprintPinStyle.pinLabel(pin);

  /// Whether an unconnected input edits its literal inline (when the type
  /// has an inline editor at all).
  bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) => true;

  /// [entries] narrowed to nodes that can take a wire from [from].
  List<BlueprintPaletteEntry> compatibleEntries(List<BlueprintPaletteEntry> entries, BlueprintPinRef from) =>
      BlueprintPalette.compatibleWith(entries, from, context);

  /// Whether [wire] is drawn as broken.
  bool wireHasProblem(LuminaBlueprintWire wire) =>
      whyNotConnect(wire.fromNodeId, wire.fromPinId, wire.toNodeId, wire.toPinId) != null;

  /// Height of the widget [nodeBody] draws under a node's header (0: none).
  double nodeBodyHeight(LuminaBlueprintNode node) => 0;

  /// A widget drawn between a node's header and its pins (the Material
  /// Editor's texture thumbnail on a Texture Sample node); null for none.
  Widget? nodeBody(BuildContext context, LuminaBlueprintNode node) => null;

  /// Node settings that are also pins (`class` of Cast To, `element` of Get
  /// Element, `component` of Get Component): editing them retitles and
  /// re-types the node, so [setLiteral] routes them to [setNodeSetting].
  static const Map<String, Set<String>> settingPins = {
    LuminaBlueprintNodeLibrary.castTo: {'class'},
    'get_component_by_class': {'class'},
    'add_component': {'class'},
    LuminaBlueprintNodeLibrary.getWidgetElement: {'element'},
    LuminaBlueprintNodeLibrary.getComponent: {'component'},
  };

  /// Nodes whose `Key` pin names an engine input key.
  static const Set<String> inputKeyNodes = {'is_input_key_down', 'get_input_key_time_down', 'was_input_key_just_pressed'};

  /// Dropdown options for a pin's literal value, or null if it uses a standard editor.
  List<String>? pinOptions(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) {
    if (settingPins[node.registryId]?.contains(pin.id) ?? false) {
      switch (pin.id) {
        case 'class':
          return BlueprintPalette.castTargets(context);
        case 'element':
          final cls = node.literals['class'];
          final classes = cls is String && context.widgetClass(cls) != null ? [context.widgetClass(cls)!] : context.widgetClasses;
          return [for (final w in classes) for (final e in w.elements) e.name];
        case 'component':
          return [for (final c in context.components) c.name];
      }
    }
    if (pin.type == LuminaPinType.enumeration) {
      final engine = LuminaBlueprintNodeLibrary.engineEnumValues(pin.enumName);
      if (engine != null) return engine;
      final values = context.enumeration(pin.enumName)?.values;
      if (values != null && values.isNotEmpty) return values;
    }
    // An input key pin (`Is Input Key Down`) picks from the
    // keys the engine names.
    if (inputKeyNodes.contains(node.registryId) && pin.id == 'key') {
      return [for (final k in LuminaKey.values) k.id];
    }
    final provided = pinOptionsProvider?.call(node, pin);
    if (provided != null) return provided;
    if (node.registryId == 'create_widget' && pin.id == 'class') {
      final widgets = host.availableWidgetClasses;
      final current = node.literals['class'] as String?;
      final set = <String>{
        ...widgets,
        if (current != null && current.isNotEmpty) current,
        if (widgets.isEmpty && (current == null || current.isEmpty)) 'WBP_HUD',
      };
      return set.toList();
    }
    return null;
  }

  /// The colour [wire] is drawn in: its source pin's.
  Color wireColor(LuminaBlueprintWire wire) {
    final n = node(wire.fromNodeId);
    final p = pin(wire.fromNodeId, wire.fromPinId, output: true);
    return n == null || p == null ? BlueprintPinStyle.color(null) : pinColor(n, p, output: true);
  }

  // ---------------------------------------------------------------------------
  // Selection and navigation
  // ---------------------------------------------------------------------------

  Set<String> get selectedNodeIds => {for (final id in _selected) if (node(id) != null) id};

  void select(String nodeId, {bool additive = false}) {
    if (!additive) _selected.clear();
    _selected.add(nodeId);
    notifyListeners();
  }

  void toggle(String nodeId) {
    if (!_selected.remove(nodeId)) _selected.add(nodeId);
    notifyListeners();
  }

  void selectMany(Set<String> ids) {
    _selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Selects [nodeId] and asks the canvas to centre it.
  void focusNode(String nodeId) {
    if (node(nodeId) == null) return;
    select(nodeId);
    focusRequest.value = (nodeId: nodeId, serial: ++_focusSerial);
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  /// Whether this graph takes library node [registryId]: the graph's own
  /// filter, and lumina's scope rule (level-only nodes only in
  /// a Level Blueprint, component nodes everywhere else).
  bool accepts(String registryId) {
    final spec = LuminaBlueprintNodeLibrary.spec(registryId);
    return spec != null && (nodeFilter == null || nodeFilter!(spec)) && LuminaBlueprintNodeLibrary.availableIn(spec, context);
  }

  LuminaBlueprintNode _place(String registryId, Offset position, Map<String, dynamic>? literals) =>
      LuminaBlueprintNodeLibrary.place(
        registryId,
        nodeId: newId('node'),
        x: position.dx,
        y: position.dy,
        literals: _seeded(registryId, literals),
        context: context,
      );

  /// A new Create Widget names a real widget class of the project from the
  /// start: the library's default when the project
  /// has it, else the project's first widget Blueprint. Its Return Value is
  /// typed `Widget:<class>` at once, so the next drag lists the elements.
  Map<String, dynamic>? _seeded(String registryId, Map<String, dynamic>? literals) {
    if (registryId != 'create_widget' || (literals?['class'] is String && (literals!['class'] as String).isNotEmpty)) {
      return literals;
    }
    final classes = context.widgetClasses.isNotEmpty
        ? [for (final w in context.widgetClasses) w.name]
        : host.availableWidgetClasses;
    if (classes.isEmpty) return literals;
    final spec = LuminaBlueprintNodeLibrary.spec(registryId);
    final preferred = spec?.inputs.where((p) => p.id == 'class').firstOrNull?.defaultValue?.toString();
    return {...?literals, 'class': classes.contains(preferred) ? preferred! : classes.first};
  }

  /// Places library node [registryId] at [position] (canvas coordinates).
  LuminaBlueprintNode? addNode(String registryId, Offset position, {Map<String, dynamic>? literals}) {
    if (!accepts(registryId)) return null;
    final title = LuminaBlueprintNodeLibrary.spec(registryId)!.title;
    return host.mutate('Add $title', () {
      final n = _place(registryId, position, literals);
      graph.nodes.add(n);
      return n;
    });
  }

  /// Places [entry] at [position] and, when the user dragged off [from],
  /// wires the new node's compatible pin to it, in one undo step.
  LuminaBlueprintNode? placeEntry(BlueprintPaletteEntry entry, Offset position, {BlueprintPinRef? from}) {
    if (entry.action == BlueprintPaletteAction.promoteToVariable) {
      return from == null ? null : promoteToVariable(from, position: position);
    }
    if (!accepts(entry.registryId)) return null;
    return host.mutate('Add ${entry.title}', () {
      final n = _place(entry.registryId, position, entry.literals);
      graph.nodes.add(n);
      if (from != null && !from.isSelf) {
        final pinId = BlueprintPalette.compatiblePin(entry, from, context);
        if (pinId != null) {
          if (from.isOutput) {
            _connect(from.nodeId, from.pinId, n.id, pinId);
          } else {
            _connect(n.id, pinId, from.nodeId, from.pinId);
          }
        }
      }
      return n;
    });
  }

  /// A Get or Set node for variable [name] (My Blueprint drag).
  LuminaBlueprintNode? placeVariable(String name, {required bool set, required Offset position}) => addNode(
        set ? LuminaBlueprintNodeLibrary.variableSet : LuminaBlueprintNodeLibrary.variableGet,
        position,
        literals: {'variable': name},
      );

  /// A reference to the level's placed actor [name] (`Get Door_01`): an
  /// outliner or Level Actors drag, or
  /// `Create a Reference to <Actor>`. Null outside a Level Blueprint or for an actor
  /// the level does not have.
  LuminaBlueprintNode? placeLevelActor(String name, {required Offset position}) {
    if (context.levelActor(name) == null) return null;
    return addNode(LuminaBlueprintNodeLibrary.getLevelActor, position, literals: {'actor': name});
  }

  /// A `Get <Component>` node for the Blueprint's component [name] (My
  /// Blueprint's Components section drag).
  LuminaBlueprintNode? placeComponent(String name, {required Offset position}) {
    if (context.component(name) == null) return null;
    return addNode(LuminaBlueprintNodeLibrary.getComponent, position, literals: {'component': name});
  }

  /// `Get <variable>` → `Get <element>` for widget variable [variable]'s
  /// element [element], wired, in one undo step (My Blueprint's element list).
  LuminaBlueprintNode? placeElementGet(String variable, String element, {required Offset position}) {
    final v = context.variable(variable);
    final cls = v?.objectClass;
    if (v == null || cls == null || !accepts(LuminaBlueprintNodeLibrary.getWidgetElement)) return null;
    final found = context.widgetElement(LuminaBlueprintObjectClass.name(cls), element);
    if (found == null) return null;
    return host.mutate('Add Get $element', () {
      final get = _place(LuminaBlueprintNodeLibrary.variableGet, position, {'variable': variable});
      final el = _place(LuminaBlueprintNodeLibrary.getWidgetElement, position + const Offset(200, 0),
          {'class': found.cls.name, 'element': found.element.name});
      graph.nodes
        ..add(get)
        ..add(el);
      _connect(get.id, 'value', el.id, 'target');
      return el;
    });
  }

  /// The variable type name a pin of [ref] promotes to (`Widget:WBP_HUD`,
  /// `Float`, `Array:Float`), or null when the pin cannot become a variable.
  String? variableTypeFor(BlueprintPinRef ref) {
    String? basic(LuminaPinType? t, String? cls) => switch (t) {
          LuminaPinType.boolean => 'Bool',
          LuminaPinType.integer => 'Int',
          LuminaPinType.float => 'Float',
          LuminaPinType.string => 'String',
          LuminaPinType.name => 'Name',
          LuminaPinType.vector => 'Vector',
          LuminaPinType.vector2D => 'Vector2D',
          LuminaPinType.rotator => 'Rotator',
          LuminaPinType.color => 'Color',
          LuminaPinType.transform => 'Transform',
          LuminaPinType.hitResult => 'HitResult',
          LuminaPinType.object => cls ?? LuminaBlueprintObjectClass.any,
          LuminaPinType.enumeration => ref.enumName == null ? null : 'Enum:${ref.enumName}',
          LuminaPinType.delegate => 'Delegate',
          LuminaPinType.timerHandle => 'TimerHandle',
          _ => null,
        };
    if (ref.type == LuminaPinType.array) {
      final inner = basic(ref.elementType, ref.objectClass);
      return inner == null ? null : 'Array:$inner';
    }
    return basic(ref.type, ref.objectClass);
  }

  /// Promote to Variable: declares a variable
  /// named after [from] (`HudWidget` for Create Widget WBP_HUD's Return
  /// Value), typed with the pin's class, places its Set node at [position]
  /// wired from the pin and spliced into the source node's exec chain, in one
  /// undo step. Returns the Set node; null for a pin that cannot be promoted.
  LuminaBlueprintNode? promoteToVariable(BlueprintPinRef from, {Offset? position}) {
    if (!from.isOutput || from.isSelf || !accepts(LuminaBlueprintNodeLibrary.variableSet)) return null;
    final source = node(from.nodeId);
    final pinSpec = pin(from.nodeId, from.pinId, output: true);
    if (source == null || pinSpec == null) return null;
    final typeName = variableTypeFor(BlueprintPinRef.of(from.nodeId, pinSpec, isOutput: true));
    if (typeName == null) return null;
    final base = BlueprintPalette.promotedName(pinSpec.name, objectClass: pinSpec.objectClass, nodeRegistryId: source.registryId);
    var name = base;
    for (var n = 2; context.variable(name) != null; n++) {
      name = '$base$n';
    }
    final at = position ?? Offset(source.x + 260, source.y);
    return host.mutate('Promote $name to variable', () {
      host.declareVariable(LuminaBlueprintVariable(
          name: name, typeName: typeName, defaultValue: BlueprintPinStyle.defaultValueFor(typeName)));
      final set = _place(LuminaBlueprintNodeLibrary.variableSet, at, {'variable': name});
      graph.nodes.add(set);
      // Splice into the exec chain: the source's first exec output now runs
      // the Set, and the Set continues where that output went.
      final execOut = pinsOf(source).outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
      if (execOut != null) {
        final next = wires.where((w) => w.fromNodeId == source.id && w.fromPinId == execOut.id).firstOrNull;
        if (next != null) _connect(set.id, 'exec_out', next.toNodeId, next.toPinId);
        _connect(source.id, execOut.id, set.id, 'exec_in');
      }
      _connect(source.id, from.pinId, set.id, 'value');
      return set;
    });
  }

  LuminaBlueprintWire _connect(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    final type = pin(fromNodeId, fromPinId, output: true)?.type;
    // An exec output drives one chain and a data input reads one value, so
    // those replace their old wire. An exec input may be reached from any
    // number of chains (e.g. two branches joining one Set node), so wires
    // into it are kept.
    if (type == LuminaPinType.exec) {
      graph.wires.removeWhere((w) => w.fromNodeId == fromNodeId && w.fromPinId == fromPinId);
    } else {
      graph.wires.removeWhere((w) => w.toNodeId == toNodeId && w.toPinId == toPinId);
    }
    final wire = LuminaBlueprintWire(
      id: newId('wire'),
      fromNodeId: fromNodeId,
      fromPinId: fromPinId,
      toNodeId: toNodeId,
      toPinId: toPinId,
    );
    graph.wires.add(wire);
    // Wildcard pins take the type of the first wire: For Each Loop
    // fed an array of hit results yields a Hit Result element, Array Get on
    // an actor array yields an actor, and so on.
    final fromPin = pin(fromNodeId, fromPinId, output: true);
    final toPin = pin(toNodeId, toPinId, output: false);
    if (fromPin != null && toPin != null) {
      _adoptWildcardType(toNodeId, toPin, fromPin);
      _adoptWildcardType(fromNodeId, fromPin, toPin);
    }
    return wire;
  }

  /// Types every still-untyped wildcard node from its existing wires — for
  /// graphs saved before wildcard nodes adopted a type when wired. Not an
  /// undo step: it only makes pins show what the wires already carry.
  void adoptWildcardTypesFromWires() {
    for (final w in List.of(graph.wires)) {
      final fromPin = pin(w.fromNodeId, w.fromPinId, output: true);
      final toPin = pin(w.toNodeId, w.toPinId, output: false);
      if (fromPin == null || toPin == null) continue;
      _adoptWildcardType(w.toNodeId, toPin, fromPin);
      _adoptWildcardType(w.fromNodeId, fromPin, toPin);
    }
  }

  /// Types wildcard node [nodeId] from [other], the pin wired to its [end]:
  /// a wildcard pin takes [other]'s type (and class), an element-less array
  /// pin takes [other]'s element type. Only an untyped node adopts a type;
  /// the node's `type`/`class` settings drive lumina's pin resolution.
  void _adoptWildcardType(String nodeId, LuminaBlueprintPinSpec end, LuminaBlueprintPinSpec other) {
    final n = node(nodeId);
    if (n == null || !LuminaBlueprintNodeLibrary.wildcardNodes.contains(n.registryId)) return;
    final current = LuminaPinType.parse(n.literals['type'] as String?);
    if (current != null && current != LuminaPinType.wildcard) return;
    LuminaPinType? type;
    String? cls;
    if (end.type == LuminaPinType.wildcard && other.type != LuminaPinType.wildcard) {
      type = other.type;
      cls = other.objectClass;
    } else if (end.type == LuminaPinType.array &&
        (end.elementType == null || end.elementType == LuminaPinType.wildcard) &&
        other.type == LuminaPinType.array &&
        other.elementType != null &&
        other.elementType != LuminaPinType.wildcard) {
      type = other.elementType;
      cls = other.objectClass;
    }
    if (type == null || type == LuminaPinType.exec) return;
    n.literals['type'] = type.jsonName;
    if (cls != null && cls.isNotEmpty) {
      n.literals['class'] = cls;
    } else {
      n.literals.remove('class');
    }
    syncPins(n);
  }

  /// Wires output [fromPinId] to input [toPinId]; null (nothing recorded)
  /// when the pins are incompatible.
  LuminaBlueprintWire? addWire({
    required String fromNodeId,
    required String fromPinId,
    required String toNodeId,
    required String toPinId,
  }) {
    if (whyNotConnect(fromNodeId, fromPinId, toNodeId, toPinId) != null) return null;
    return host.mutate('Connect pins', () => _connect(fromNodeId, fromPinId, toNodeId, toPinId));
  }

  /// Joins two pins in whichever direction they allow.
  LuminaBlueprintWire? connectPins(BlueprintPinRef a, BlueprintPinRef b) {
    if (a.isOutput == b.isOutput) return null;
    final out = a.isOutput ? a : b;
    final inp = a.isOutput ? b : a;
    return addWire(fromNodeId: out.nodeId, fromPinId: out.pinId, toNodeId: inp.nodeId, toPinId: inp.pinId);
  }

  bool removeWire(String wireId) => host.mutate('Delete wire', () {
        final before = graph.wires.length;
        graph.wires.removeWhere((w) => w.id == wireId);
        return graph.wires.length < before;
      });

  /// Break Link(s) on a pin.
  bool breakLinks(String nodeId, String pinId, {required bool output}) => host.mutate('Break links', () {
        final before = graph.wires.length;
        graph.wires.removeWhere((w) =>
            output ? (w.fromNodeId == nodeId && w.fromPinId == pinId) : (w.toNodeId == nodeId && w.toPinId == pinId));
        return graph.wires.length < before;
      });

  bool removeNode(String nodeId) => removeNodes({nodeId});

  bool removeNodes(Set<String> ids) {
    if (ids.isEmpty) return false;
    return host.mutate(ids.length == 1 ? 'Delete node' : 'Delete ${ids.length} nodes', () {
      final before = graph.nodes.length;
      graph.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
      graph.nodes.removeWhere((n) => ids.contains(n.id));
      _selected.removeAll(ids);
      return graph.nodes.length < before;
    });
  }

  bool removeSelected() => removeNodes(selectedNodeIds);

  /// Sets an unconnected input's literal; one undo step per committed edit.
  bool setLiteral(String nodeId, String pinId, Object? value) {
    final n = node(nodeId);
    if (n == null) return false;
    if (settingPins[n.registryId]?.contains(pinId) ?? false) return setNodeSetting(nodeId, pinId, value);
    if (jsonEncode(n.literals[pinId]) == jsonEncode(value)) return false;
    final pinName = pin(nodeId, pinId, output: false)?.name ?? pinId;
    return host.mutate('Edit $pinName', () {
      node(nodeId)!.literals[pinId] = value;
      return true;
    });
  }

  /// Points an EnhancedInputAction node at project action [action]: the title
  /// follows, the Action Value re-types to the action's value type, and wires
  /// the new type cannot carry are removed, all in one undo step.
  bool setNodeAction(String nodeId, String action) {
    final n = node(nodeId);
    if (n == null || n.registryId != LuminaBlueprintNodeLibrary.enhancedInputAction) return false;
    if (n.literals['action'] == action) return false;
    return host.mutate('Set input action $action', () {
      final target = node(nodeId)!;
      target.literals['action'] = action;
      target.title = action;
      syncPins(target);
      dropIncompatibleWires(target.id);
      return true;
    });
  }

  /// Sets node setting [key] (`class`, `element`, `component`, `cases`,
  /// `count`, `type`) on [nodeId]: the title and category follow the
  /// library, the pins re-resolve, and wires the new pins cannot carry are
  /// removed, all in one undo step.
  bool setNodeSetting(String nodeId, String key, Object? value) {
    final n = node(nodeId);
    if (n == null || jsonEncode(n.literals[key]) == jsonEncode(value)) return false;
    return host.mutate('Set $key of ${n.title}', () {
      final target = node(nodeId)!;
      if (value == null) {
        target.literals.remove(key);
      } else {
        target.literals[key] = value;
      }
      final probe = LuminaBlueprintNodeLibrary.place(target.registryId,
          nodeId: '_probe', literals: target.literals, context: context);
      target.title = probe.title;
      target.category = probe.category;
      syncPins(target);
      dropIncompatibleWires(target.id);
      return true;
    });
  }

  /// "Add pin" on a Sequence: one more `Then n` output.
  bool addSequencePin(String nodeId) {
    final n = node(nodeId);
    if (n == null || n.registryId != 'sequence') return false;
    return host.mutate('Add pin', () {
      final target = node(nodeId)!;
      final execs = target.outputs.where((p) => p.type == LuminaPinType.exec).length;
      target.outputs.add(LuminaBlueprintPin(id: 'then_$execs', name: 'Then $execs', type: LuminaPinType.exec, isOutput: true));
      return true;
    });
  }

  /// "Add pin" on a Make Array (and any `count` node: Multi Gate): one more
  /// item pin.
  bool addCountedPin(String nodeId) {
    final n = node(nodeId);
    if (n == null) return false;
    final current = (n.literals['count'] as num?)?.toInt() ?? pinsOf(n).inputs.where((p) => p.id.startsWith('item_')).length;
    return setNodeSetting(nodeId, 'count', current + 1);
  }

  /// Rewrites [node]'s stored pins from the library's resolution.
  void syncPins(LuminaBlueprintNode node) {
    final pins = pinsOf(node);
    node.inputs
      ..clear()
      ..addAll(pins.inputs.map((p) => p.toPin(isOutput: false)));
    node.outputs
      ..clear()
      ..addAll(pins.outputs.map((p) => p.toPin(isOutput: true)));
  }

  /// Removes wires into or out of [nodeId] whose ends no longer match.
  int dropIncompatibleWires(String nodeId) {
    final before = graph.wires.length;
    graph.wires.removeWhere((w) =>
        (w.fromNodeId == nodeId || w.toNodeId == nodeId) &&
        whyNotConnect(w.fromNodeId, w.fromPinId, w.toNodeId, w.toPinId) != null);
    return before - graph.wires.length;
  }

  /// Removes every wire in the graph whose ends no longer match (a variable
  /// retype touches every Get / Set of it and what they feed).
  int dropAllIncompatibleWires() {
    final before = graph.wires.length;
    graph.wires.removeWhere((w) => whyNotConnect(w.fromNodeId, w.fromPinId, w.toNodeId, w.toPinId) != null);
    return before - graph.wires.length;
  }

  /// Swaps a legacy OnInputAxis / OnInputAction node for an
  /// EnhancedInputAction at the same place, keeping its exec wires
  /// (lumina's deprecation diagnostic names the replacement).
  LuminaBlueprintNode? replaceLegacyInput(String nodeId) {
    final old = node(nodeId);
    if (old == null || (old.registryId != 'event_input_axis' && old.registryId != 'event_input_action')) return null;
    const pinMap = {'exec_out': 'triggered', 'pressed_out': 'started', 'released_out': 'completed'};
    return host.mutate('Replace with EnhancedInputAction', () {
      final replacement = _place(LuminaBlueprintNodeLibrary.enhancedInputAction, Offset(old.x, old.y), null);
      final moved = <LuminaBlueprintWire>[];
      for (final w in graph.wires.where((w) => w.fromNodeId == nodeId)) {
        final pinId = pinMap[w.fromPinId];
        if (pinId == null) continue;
        moved.add(LuminaBlueprintWire(
            id: newId('wire'), fromNodeId: replacement.id, fromPinId: pinId, toNodeId: w.toNodeId, toPinId: w.toPinId));
      }
      graph.wires.removeWhere((w) => w.fromNodeId == nodeId || w.toNodeId == nodeId);
      graph.nodes
        ..removeWhere((n) => n.id == nodeId)
        ..add(replacement);
      graph.wires.addAll(moved);
      _selected
        ..remove(nodeId)
        ..add(replacement.id);
      return replacement;
    });
  }

  // ---------------------------------------------------------------------------
  // Custom events, dispatchers, comments and reroutes
  // ---------------------------------------------------------------------------

  /// "Add Custom Event…": a named event with no parameters yet; the
  /// name is made unique among the graph's custom events.
  LuminaBlueprintNode? addCustomEvent(String name, Offset position) {
    if (!accepts(LuminaBlueprintNodeLibrary.customEvent)) return null;
    final base = name.trim().isEmpty ? 'CustomEvent' : name.trim();
    var unique = base;
    for (var n = 2; nodes.any((x) => x.registryId == LuminaBlueprintNodeLibrary.customEvent && x.literals['name'] == unique); n++) {
      unique = '$base$n';
    }
    return host.mutate('Add custom event $unique', () {
      final n = _place(LuminaBlueprintNodeLibrary.customEvent, position, {'name': unique, 'parameters': <Map<String, dynamic>>[]});
      graph.nodes.add(n);
      return n;
    });
  }

  /// Sets a custom event's parameters (name, type, default): its output pins
  /// follow, every `Call <Event>` re-resolves, and wires the new signature
  /// cannot carry are dropped — one undo step.
  bool setCustomEventParameters(String nodeId, List<LuminaBlueprintVariable> parameters) {
    final n = node(nodeId);
    if (n == null || n.registryId != LuminaBlueprintNodeLibrary.customEvent) return false;
    final json = [for (final p in parameters) p.toJson()];
    if (jsonEncode(n.literals['parameters']) == jsonEncode(json)) return false;
    return host.mutate('Edit parameters of ${n.title}', () {
      node(nodeId)!.literals['parameters'] = json;
      syncPins(node(nodeId)!);
      for (final call in nodes.where((x) => x.registryId == LuminaBlueprintNodeLibrary.callCustomEvent)) {
        syncPins(call);
      }
      dropAllIncompatibleWires();
      return true;
    });
  }

  /// Renames a custom event and every `Call <Event>` naming it.
  bool renameCustomEvent(String nodeId, String newName) {
    final n = node(nodeId);
    final trimmed = newName.trim();
    if (n == null || n.registryId != LuminaBlueprintNodeLibrary.customEvent || trimmed.isEmpty) return false;
    final old = n.literals['name'] as String?;
    if (old == trimmed) return false;
    if (nodes.any((x) => x.registryId == LuminaBlueprintNodeLibrary.customEvent && x.literals['name'] == trimmed)) return false;
    return host.mutate('Rename custom event $old', () {
      final target = node(nodeId)!;
      target.literals['name'] = trimmed;
      target.title = trimmed;
      for (final call in nodes.where((x) => x.registryId == LuminaBlueprintNodeLibrary.callCustomEvent && x.literals['event'] == old)) {
        call.literals['event'] = trimmed;
        call.title = trimmed;
      }
      return true;
    });
  }

  /// A comment box (`C`): around [around] when given (the selected
  /// nodes' bounds, padded), else a default box at [position].
  LuminaBlueprintNode? addComment({Offset? position, Rect? around, String title = 'Comment'}) {
    final rect = around == null
        ? Rect.fromLTWH(position?.dx ?? 0, position?.dy ?? 0, BlueprintEditorNodes.defaultCommentWidth, BlueprintEditorNodes.defaultCommentHeight)
        : Rect.fromLTRB(around.left - 20, around.top - 40, around.right + 20, around.bottom + 20);
    return host.mutate('Add comment', () {
      final n = BlueprintEditorNodes.newComment(
        id: newId('comment'),
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
        title: title,
      );
      graph.nodes.add(n);
      _selected
        ..clear()
        ..add(n.id);
      return n;
    });
  }

  /// Edits a comment's title, size or colour (one undo step each).
  bool setComment(String nodeId, {String? title, double? width, double? height, int? color}) {
    final n = node(nodeId);
    if (n == null || !BlueprintEditorNodes.isComment(n)) return false;
    return host.mutate('Edit comment', () {
      final target = node(nodeId)!;
      if (title != null) {
        target.title = title;
        target.literals['title'] = title;
      }
      if (width != null) target.literals['width'] = width.clamp(80.0, 4000.0);
      if (height != null) target.literals['height'] = height.clamp(40.0, 4000.0);
      if (color != null) target.literals['color'] = color;
      return true;
    });
  }

  /// Splits [wireId] with a reroute dot at [position] (double-clicking a
  /// wire): the source now feeds the dot and the dot feeds the old target.
  LuminaBlueprintNode? insertReroute(String wireId, Offset position) {
    final w = wires.where((x) => x.id == wireId).firstOrNull;
    if (w == null) return null;
    final type = pin(w.fromNodeId, w.fromPinId, output: true);
    if (type == null) return null;
    return host.mutate('Add reroute', () {
      final dot = BlueprintEditorNodes.newReroute(id: newId('reroute'), x: position.dx - 6, y: position.dy - 6, type: type);
      graph.nodes.add(dot);
      graph.wires.removeWhere((x) => x.id == wireId);
      graph.wires.add(LuminaBlueprintWire(
          id: newId('wire'), fromNodeId: w.fromNodeId, fromPinId: w.fromPinId, toNodeId: dot.id, toPinId: BlueprintEditorNodes.rerouteIn));
      graph.wires.add(LuminaBlueprintWire(
          id: wireId, fromNodeId: dot.id, fromPinId: BlueprintEditorNodes.rerouteOut, toNodeId: w.toNodeId, toPinId: w.toPinId));
      return dot;
    });
  }

  /// The far source of a wire chain through reroutes ending at output
  /// [pinId] of [nodeId]: the pin that really carries the value.
  ({String nodeId, String pinId})? sourceThroughReroutes(String nodeId, String pinId) {
    var current = (nodeId: nodeId, pinId: pinId);
    for (var i = 0; i < 64; i++) {
      final n = node(current.nodeId);
      if (n == null || !BlueprintEditorNodes.isReroute(n)) return current;
      final into = graph.wireInto(n.id, BlueprintEditorNodes.rerouteIn);
      if (into == null) return null;
      current = (nodeId: into.fromNodeId, pinId: into.fromPinId);
    }
    return null;
  }

  /// A Call / Bind / Unbind / Unbind All node for dispatcher [name]
  /// (My Blueprint drag).
  LuminaBlueprintNode? placeDispatcher(String name, {required String registryId, required Offset position}) {
    if (context.dispatcher(name) == null) return null;
    const allowed = {
      LuminaBlueprintNodeLibrary.callDispatcher,
      LuminaBlueprintNodeLibrary.bindEventToDispatcher,
      LuminaBlueprintNodeLibrary.unbindEventFromDispatcher,
      LuminaBlueprintNodeLibrary.unbindAllEvents,
    };
    if (!allowed.contains(registryId)) return null;
    return addNode(registryId, position, literals: {'dispatcher': name});
  }

  /// "Assign": a Bind node plus a new custom event named after the
  /// dispatcher, its delegate wired into the bind, in one undo step.
  LuminaBlueprintNode? assignDispatcher(String name, {required Offset position}) {
    final d = context.dispatcher(name);
    if (d == null || !accepts(LuminaBlueprintNodeLibrary.bindEventToDispatcher) || !accepts(LuminaBlueprintNodeLibrary.customEvent)) {
      return null;
    }
    var eventName = '${name}_Event';
    for (var n = 2; nodes.any((x) => x.registryId == LuminaBlueprintNodeLibrary.customEvent && x.literals['name'] == eventName); n++) {
      eventName = '${name}_Event$n';
    }
    return host.mutate('Assign $name', () {
      final bind = _place(LuminaBlueprintNodeLibrary.bindEventToDispatcher, position, {'dispatcher': name});
      final event = _place(LuminaBlueprintNodeLibrary.customEvent, position + const Offset(0, 140), {
        'name': eventName,
        'parameters': [for (final p in d.parameters) p.toJson()],
      });
      graph.nodes
        ..add(bind)
        ..add(event);
      _connect(event.id, 'delegate', bind.id, 'event');
      return bind;
    });
  }

  /// A local variable Get / Set of the function graph being edited.
  LuminaBlueprintNode? placeLocalVariable(String name, {required bool set, required Offset position}) {
    if (context.localVariable(name) == null) return null;
    return addNode(
      set ? LuminaBlueprintNodeLibrary.localVariableSet : LuminaBlueprintNodeLibrary.localVariableGet,
      position,
      literals: {'variable': name},
    );
  }

  /// Set Timeline tracks / Switch cases: `tracks` on a Timeline.
  bool setTimelineTracks(String nodeId, List<LuminaTimelineTrack> tracks) =>
      setNodeSetting(nodeId, 'tracks', [for (final t in tracks) t.toJson()]);

  /// The Timeline node's tracks as stored.
  static List<LuminaTimelineTrack> timelineTracks(LuminaBlueprintNode node) {
    final stored = node.literals['tracks'];
    if (stored is! List) return const [];
    return [for (final t in stored) if (t is Map) LuminaTimelineTrack.fromJson(t)];
  }

  // ---------------------------------------------------------------------------
  // Moving
  // ---------------------------------------------------------------------------

  void beginMove() => host.beginInteraction('Move nodes');

  void moveNodes(Iterable<String> ids, Offset delta) {
    for (final id in ids) {
      final n = node(id);
      if (n == null) continue;
      n.x += delta.dx;
      n.y += delta.dy;
    }
    notifyListeners();
  }

  void endMove() => host.endInteraction(layoutOnly: true);

  @override
  void dispose() {
    focusRequest.dispose();
    super.dispose();
  }
}
