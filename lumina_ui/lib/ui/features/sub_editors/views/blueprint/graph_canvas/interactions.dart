part of '../graph_canvas.dart';

/// Wire dragging, node/pin hit testing, the node context menu and the
/// drag-and-drop handlers that spawn nodes.
mixin _BlueprintGraphCanvasInteractions on _BlueprintGraphCanvasStateBase {

  // ---------------------------------------------------------------------------
  // Wire dragging
  // ---------------------------------------------------------------------------

  @override
  void _startWire(BlueprintPinRef from, Offset global) {
    setState(() {
      _dragFrom = from;
      _dragPointer = _toCanvas(_localFromGlobal(global));
      _dragRefusal = null;
    });
  }

  @override
  void _updateWire(Offset global) {
    final from = _dragFrom;
    if (from == null) return;
    final pointer = _toCanvas(_localFromGlobal(global));
    final target = _pinAt(pointer, from);
    setState(() {
      _dragPointer = pointer;
      _dragRefusal = target == null ? null : _refusal(from, target);
    });
  }

  @override
  void _endWire() {
    final from = _dragFrom;
    final pointer = _dragPointer;
    setState(() {
      _dragFrom = null;
      _dragPointer = null;
      _dragRefusal = null;
    });
    if (from == null || pointer == null) return;
    final target = _pinAt(pointer, from);
    if (target != null) {
      editor.connectPins(from, target);
      return;
    }
    if (_nodeAt(pointer) != null) return;
    // Released on empty canvas: the context-sensitive palette.
    openNodePalette(toScreen(pointer), from: from);
  }

  String? _refusal(BlueprintPinRef from, BlueprintPinRef to) {
    if (from.isOutput == to.isOutput) return 'Both pins are ${from.isOutput ? 'outputs' : 'inputs'}';
    final out = from.isOutput ? from : to;
    final inp = from.isOutput ? to : from;
    return editor.whyNotConnect(out.nodeId, out.pinId, inp.nodeId, inp.pinId);
  }

  LuminaBlueprintNode? _nodeAt(Offset canvas) {
    for (final n in editor.nodes.reversed) {
      if (BlueprintNodeLayout.of(editor, n).rect.contains(canvas)) return n;
    }
    return null;
  }

  /// The pin a drag released at [canvas] joins: the nearest pin within reach,
  /// else the first compatible pin of the node under the pointer.
  BlueprintPinRef? _pinAt(Offset canvas, BlueprintPinRef from) {
    BlueprintPinRef? best;
    var bestDistance = 16.0;
    for (final n in editor.nodes) {
      if (n.id == from.nodeId) continue;
      final layout = BlueprintNodeLayout.of(editor, n);
      for (final output in [false, true]) {
        for (final p in output ? layout.pins.outputs : layout.pins.inputs) {
          final c = layout.pinCenter(p.id, output: output)!;
          final d = (c - canvas).distance;
          if (d < bestDistance) {
            bestDistance = d;
            best = BlueprintPinRef.of(n.id, p, isOutput: output);
          }
        }
      }
    }
    if (best != null) return best;
    final n = _nodeAt(canvas);
    if (n == null || n.id == from.nodeId) return null;
    final layout = BlueprintNodeLayout.of(editor, n);
    for (final p in from.isOutput ? layout.pins.inputs : layout.pins.outputs) {
      if (p.type == from.type) return BlueprintPinRef.of(n.id, p, isOutput: !from.isOutput);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Menus
  // ---------------------------------------------------------------------------

  @override
  void _showNodeMenu(LuminaBlueprintNode node, Offset global) {
    if (!editor.selectedNodeIds.contains(node.id)) editor.select(node.id);
    final legacy = node.registryId == 'event_input_axis' || node.registryId == 'event_input_action';
    final isCall = node.registryId == LuminaBlueprintNodeLibrary.callFunction ||
        node.registryId == LuminaBlueprintNodeLibrary.callFunctionPure ||
        node.registryId == LuminaBlueprintNodeLibrary.callMacro;
    final isTimeline = node.registryId == LuminaBlueprintNodeLibrary.timeline;
    final actions = widget.actions;
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          if (isTimeline && actions.onOpenTimeline != null)
            MenuButton(
              key: const ValueKey('node_menu_open_timeline'),
              leading: const Icon(LucideIcons.chartLine, size: 12),
              child: const Text('Open Timeline', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onOpenTimeline!(node.id),
            ),
          if (isCall && actions.onOpenGraph != null)
            MenuButton(
              key: const ValueKey('node_menu_open_graph'),
              leading: const Icon(LucideIcons.externalLink, size: 12),
              child: Text(node.registryId == LuminaBlueprintNodeLibrary.callMacro ? 'Open Macro Graph' : 'Open Function Graph',
                  style: const TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onOpenGraph!(
                  (node.literals[node.registryId == LuminaBlueprintNodeLibrary.callMacro ? 'macro' : 'function'] ?? '').toString(),
                  isMacro: node.registryId == LuminaBlueprintNodeLibrary.callMacro),
            ),
          if (isCall && actions.onExpand != null)
            MenuButton(
              key: const ValueKey('node_menu_expand'),
              leading: const Icon(LucideIcons.ungroup, size: 12),
              child: const Text('Expand Node', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onExpand!(node.id),
            ),
          if (actions.onCollapse != null) ...[
            MenuButton(
              key: const ValueKey('node_menu_collapse_nodes'),
              leading: const Icon(LucideIcons.group, size: 12),
              child: const Text('Collapse Nodes', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onCollapse!(toMacro: true, named: false),
            ),
            MenuButton(
              key: const ValueKey('node_menu_collapse_function'),
              leading: const Icon(LucideIcons.squareFunction, size: 12),
              child: const Text('Collapse to Function', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onCollapse!(toMacro: false, named: true),
            ),
            MenuButton(
              key: const ValueKey('node_menu_collapse_macro'),
              leading: const Icon(LucideIcons.boxes, size: 12),
              child: const Text('Collapse to Macro', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => actions.onCollapse!(toMacro: true, named: true),
            ),
          ],
          MenuButton(
            key: const ValueKey('node_menu_comment'),
            leading: const Icon(LucideIcons.messageSquare, size: 12),
            child: const Text('Add Comment to Selection', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => addCommentAroundSelection(),
          ),
          if (legacy)
            MenuButton(
              key: const ValueKey('node_menu_replace_legacy'),
              leading: const Icon(LucideIcons.replace, size: 12),
              child: const Text('Replace with EnhancedInputAction', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) => editor.replaceLegacyInput(node.id),
            ),
          MenuButton(
            key: const ValueKey('node_menu_break_links'),
            leading: const Icon(LucideIcons.unlink, size: 12),
            child: const Text('Break Node Links', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) {
              final pins = editor.pinsOf(node);
              editor.host.mutate('Break node links', () {
                final before = editor.wires.length;
                editor.wires.removeWhere((w) => w.fromNodeId == node.id || w.toNodeId == node.id);
                return pins.inputs.isNotEmpty || pins.outputs.isNotEmpty ? editor.wires.length < before : false;
              });
            },
          ),
          MenuButton(
            key: const ValueKey('node_menu_delete'),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Delete', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => editor.removeSelected(),
          ),
        ],
      ),
    );
  }

  void _dropDispatcher(String name, Offset global) {
    final canvas = _toCanvas(_localFromGlobal(global));
    MenuButton item(String key, String label, VoidCallback run) => MenuButton(
          key: ValueKey(key),
          child: Text(label, style: const TextStyle(fontSize: 10)),
          onPressed: (ctx) => run(),
        );
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          item('dispatcher_drop_call', 'Call', () => editor.placeDispatcher(name, registryId: LuminaBlueprintNodeLibrary.callDispatcher, position: canvas)),
          item('dispatcher_drop_bind', 'Bind', () => editor.placeDispatcher(name, registryId: LuminaBlueprintNodeLibrary.bindEventToDispatcher, position: canvas)),
          item('dispatcher_drop_unbind', 'Unbind', () => editor.placeDispatcher(name, registryId: LuminaBlueprintNodeLibrary.unbindEventFromDispatcher, position: canvas)),
          item('dispatcher_drop_unbind_all', 'Unbind All', () => editor.placeDispatcher(name, registryId: LuminaBlueprintNodeLibrary.unbindAllEvents, position: canvas)),
          item('dispatcher_drop_assign', 'Assign', () => editor.assignDispatcher(name, position: canvas)),
        ],
      ),
    );
  }

  void _dropLocalVariable(String name, Offset global) {
    final canvas = _toCanvas(_localFromGlobal(global));
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed) {
      editor.placeLocalVariable(name, set: false, position: canvas);
      return;
    }
    if (keys.isAltPressed) {
      editor.placeLocalVariable(name, set: true, position: canvas);
      return;
    }
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('local_drop_get'),
            child: Text('Get $name', style: const TextStyle(fontSize: 10)),
            onPressed: (ctx) => editor.placeLocalVariable(name, set: false, position: canvas),
          ),
          MenuButton(
            key: const ValueKey('local_drop_set'),
            child: Text('Set $name', style: const TextStyle(fontSize: 10)),
            onPressed: (ctx) => editor.placeLocalVariable(name, set: true, position: canvas),
          ),
        ],
      ),
    );
  }

  void _dropGraphCall(BlueprintGraphCallDrag drag, Offset global) {
    final canvas = _toCanvas(_localFromGlobal(global));
    final entries = editor.paletteEntries().where((e) => e.literals[drag.isMacro ? 'macro' : 'function'] == drag.name);
    if (entries.isEmpty) return;
    final placed = editor.placeEntry(entries.first, canvas);
    if (placed != null) editor.select(placed.id);
  }

  /// The wire nearest [canvas] within reach, by sampling its curve.
  LuminaBlueprintWire? wireAt(Offset canvas, Map<String, BlueprintNodeLayout> layouts) {
    LuminaBlueprintWire? best;
    var bestDistance = 8.0 / _zoom;
    for (final w in editor.wires) {
      final a = layouts[w.fromNodeId]?.pinCenter(w.fromPinId, output: true);
      final b = layouts[w.toNodeId]?.pinCenter(w.toPinId, output: false);
      if (a == null || b == null) continue;
      final control = math.max((b.dx - a.dx).abs() * 0.5, 40.0);
      final c1 = Offset(a.dx + control, a.dy);
      final c2 = Offset(b.dx - control, b.dy);
      for (var i = 0; i <= 24; i++) {
        final t = i / 24;
        final u = 1 - t;
        final p = a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + b * (t * t * t);
        final d = (p - canvas).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = w;
        }
      }
    }
    return best;
  }

  void _dropVariable(String name, Offset global) {
    final canvas = _toCanvas(_localFromGlobal(global));
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed) {
      editor.placeVariable(name, set: false, position: canvas);
      return;
    }
    if (keys.isAltPressed) {
      editor.placeVariable(name, set: true, position: canvas);
      return;
    }
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('variable_drop_get'),
            child: Text('Get $name', style: const TextStyle(fontSize: 10)),
            onPressed: (ctx) => editor.placeVariable(name, set: false, position: canvas),
          ),
          MenuButton(
            key: const ValueKey('variable_drop_set'),
            child: Text('Set $name', style: const TextStyle(fontSize: 10)),
            onPressed: (ctx) => editor.placeVariable(name, set: true, position: canvas),
          ),
        ],
      ),
    );
  }
}
