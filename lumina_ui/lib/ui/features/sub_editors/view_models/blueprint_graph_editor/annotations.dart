part of '../blueprint_graph_editor.dart';

/// Custom events, dispatchers, comments and reroutes.
mixin _BlueprintGraphAnnotations on _BlueprintGraphEditorCore {

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
        id: BlueprintGraphEditor.newId('comment'),
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
      final dot = BlueprintEditorNodes.newReroute(id: BlueprintGraphEditor.newId('reroute'), x: position.dx - 6, y: position.dy - 6, type: type);
      graph.nodes.add(dot);
      graph.wires.removeWhere((x) => x.id == wireId);
      graph.wires.add(LuminaBlueprintWire(
          id: BlueprintGraphEditor.newId('wire'), fromNodeId: w.fromNodeId, fromPinId: w.fromPinId, toNodeId: dot.id, toPinId: BlueprintEditorNodes.rerouteIn));
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
}
