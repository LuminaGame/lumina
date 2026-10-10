part of '../blueprint_graph_editor.dart';

/// Adding, placing, wiring, replacing and removing nodes.
mixin _BlueprintGraphEditing on _BlueprintGraphEditorCore {

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  /// Whether this graph takes library node [registryId]: the graph's own
  /// filter, and lumina's scope rule (level-only nodes only in
  /// a Level Blueprint, component nodes everywhere else).
  @override
  bool accepts(String registryId) {
    final spec = LuminaBlueprintNodeLibrary.spec(registryId);
    return spec != null && (nodeFilter == null || nodeFilter!(spec)) && LuminaBlueprintNodeLibrary.availableIn(spec, context);
  }

  @override
  LuminaBlueprintNode _place(String registryId, Offset position, Map<String, dynamic>? literals) =>
      LuminaBlueprintNodeLibrary.place(
        registryId,
        nodeId: BlueprintGraphEditor.newId('node'),
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
  @override
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

  @override
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
      id: BlueprintGraphEditor.newId('wire'),
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
    if (n == null || !LuminaBlueprintNodeLibrary.adoptsWildcardType(n)) return;
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

  /// Joins two pins in whichever direction they allow; two different types
  /// go through the conversion node lumina names for them, if any.
  LuminaBlueprintWire? connectPins(BlueprintPinRef a, BlueprintPinRef b) {
    if (a.isOutput == b.isOutput) return null;
    final out = a.isOutput ? a : b;
    final inp = a.isOutput ? b : a;
    return addWire(fromNodeId: out.nodeId, fromPinId: out.pinId, toNodeId: inp.nodeId, toPinId: inp.pinId) ??
        (this as BlueprintGraphEditor)._connectThroughConversion(out, inp);
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
    if (BlueprintGraphEditor.settingPins[n.registryId]?.contains(pinId) ?? false) return setNodeSetting(nodeId, pinId, value);
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
  @override
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
  @override
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
  @override
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
            id: BlueprintGraphEditor.newId('wire'), fromNodeId: replacement.id, fromPinId: pinId, toNodeId: w.toNodeId, toPinId: w.toPinId));
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
}
