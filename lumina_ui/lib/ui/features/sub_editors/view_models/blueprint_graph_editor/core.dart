part of '../blueprint_graph_editor.dart';

/// The graph editor's state (host, sources, selection, focus, debug trace)
/// and the read side: nodes, resolved pins and connection checks.
abstract class _BlueprintGraphEditorCore extends ChangeNotifier {
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

  _BlueprintGraphEditorCore({
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

  // --- Implemented by the domain mixins. ---

  Set<String> get selectedNodeIds;
  bool accepts(String registryId);
  LuminaBlueprintNode _place(String registryId, Offset position, Map<String, dynamic>? literals);
  LuminaBlueprintNode? addNode(String registryId, Offset position, {Map<String, dynamic>? literals});
  LuminaBlueprintWire _connect(String fromNodeId, String fromPinId, String toNodeId, String toPinId);
  bool setNodeSetting(String nodeId, String key, Object? value);
  void syncPins(LuminaBlueprintNode node);
  int dropAllIncompatibleWires();
}
