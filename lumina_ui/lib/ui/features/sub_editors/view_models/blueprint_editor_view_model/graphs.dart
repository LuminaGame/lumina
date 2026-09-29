part of '../blueprint_editor_view_model.dart';

/// Graph tabs and editors, asset pin options and timeline editing.
mixin _BlueprintEditorGraphs on _BlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Graphs and tabs
  // ---------------------------------------------------------------------------

  /// The graph the centre tab shows.
  BlueprintGraphRef get activeGraph => _activeGraph;

  /// Every graph of the document, in My Blueprint's Graphs order.
  @override
  List<BlueprintGraphRef> get graphs => [
        BlueprintGraphRef.eventGraph,
        BlueprintGraphRef.constructionScript,
        for (final f in _document.functions) BlueprintGraphRef.function(f.name),
        for (final m in _document.macros) BlueprintGraphRef.macro(m.name),
      ];

  bool _refExists(BlueprintGraphRef ref) => switch (ref.kind) {
        BlueprintGraphKind.eventGraph || BlueprintGraphKind.constructionScript => true,
        BlueprintGraphKind.function => _document.function(ref.name) != null,
        BlueprintGraphKind.macro => _document.macro(ref.name) != null,
        BlueprintGraphKind.timeline => findNode(ref.name ?? '')?.node.registryId == LuminaBlueprintNodeLibrary.timeline,
      };

  /// Shows [ref]'s tab (a missing graph falls back to the event graph).
  void showGraph(BlueprintGraphRef ref) {
    final next = _refExists(ref) ? ref : BlueprintGraphRef.eventGraph;
    if (next == _activeGraph) return;
    _activeGraph = next;
    notifyListeners();
  }

  /// The editor of [ref]'s node graph; the event graph's for refs without one.
  @override
  BlueprintGraphEditor graphEditor(BlueprintGraphRef ref) {
    if (!ref.hasGraph || ref.kind == BlueprintGraphKind.eventGraph) return eventGraph;
    return _graphEditors.putIfAbsent(ref.key, () {
      final name = ref.name!;
      if (ref.isFunction) {
        return BlueprintGraphEditor(
          host: this,
          graphSource: () => _document.function(name)?.graph,
          contextSource: () => _contextFor(function: _document.function(name)),
          nodeFilter: BlueprintEditorViewModel.functionGraphAccepts,
          diagnosticsSource: () => _diagnostics,
          pinOptionsProvider: assetPinOptions,
          pinnedEntriesSource: pinnedPaletteEntries,
        );
      }
      return BlueprintGraphEditor(
        host: this,
        graphSource: () => _document.macro(name)?.graph,
        contextSource: () => _contextFor(macro: _document.macro(name)),
        nodeFilter: BlueprintEditorViewModel.macroGraphAccepts,
        diagnosticsSource: () => _diagnostics,
        pinOptionsProvider: assetPinOptions,
        pinnedEntriesSource: pinnedPaletteEntries,
      );
    });
  }

  /// The editor of the graph the centre tab shows.
  BlueprintGraphEditor get activeGraphEditor => graphEditor(_activeGraph);

  /// Dropdown choices of an asset pin (sounds, montages,
  /// materials, particles, levels, save classes), from the project's assets.
  @override
  List<String>? assetPinOptions(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) {
    final assets = _assets;
    if (assets == null || pin.type != LuminaPinType.string && pin.type != LuminaPinType.name) return null;
    final kind = BlueprintEditorViewModel.assetKindOfPin(node.registryId, pin.id);
    if (kind == null) return null;
    final paths = assets.assetPaths(kind);
    final current = node.literals[pin.id];
    return [...paths, if (current is String && current.isNotEmpty && !paths.contains(current)) current];
  }

  // ---------------------------------------------------------------------------
  // Timelines
  // ---------------------------------------------------------------------------

  /// The Timeline node [nodeId] wherever it is, or null.
  LuminaBlueprintNode? timelineNode(String nodeId) {
    final found = findNode(nodeId);
    return found != null && found.node.registryId == LuminaBlueprintNodeLibrary.timeline ? found.node : null;
  }

  /// The graph editor that owns Timeline [nodeId].
  BlueprintGraphEditor? timelineEditor(String nodeId) {
    final found = findNode(nodeId);
    return found == null ? null : graphEditor(found.graph);
  }

  /// Opens the Timeline's curve tab.
  void openTimeline(String nodeId) {
    if (timelineNode(nodeId) == null) return;
    showGraph(BlueprintGraphRef.timeline(nodeId));
  }

  double timelineLength(String nodeId) => (timelineNode(nodeId)?.literals['length'] as num?)?.toDouble() ?? 1.0;
  bool timelineLoop(String nodeId) => timelineNode(nodeId)?.literals['loop'] == true;
  bool timelineAutoPlay(String nodeId) => timelineNode(nodeId)?.literals['autoPlay'] == true;
  List<LuminaTimelineTrack> timelineTracks(String nodeId) {
    final n = timelineNode(nodeId);
    return n == null ? const [] : BlueprintGraphEditor.timelineTracks(n);
  }

  bool setTimelineLength(String nodeId, double length) =>
      timelineEditor(nodeId)?.setNodeSetting(nodeId, 'length', length <= 0 ? 0.01 : length) ?? false;
  bool setTimelineLoop(String nodeId, bool loop) => timelineEditor(nodeId)?.setNodeSetting(nodeId, 'loop', loop) ?? false;
  bool setTimelineAutoPlay(String nodeId, bool autoPlay) => timelineEditor(nodeId)?.setNodeSetting(nodeId, 'autoPlay', autoPlay) ?? false;

  /// Sets every track at once (the curve editor's edits); the node's track
  /// outputs follow.
  bool setTimelineTracks(String nodeId, List<LuminaTimelineTrack> tracks) => timelineEditor(nodeId)?.setTimelineTracks(nodeId, tracks) ?? false;

  /// Adds a track of [type] (`float`, `vector`, `color`) named [name]
  /// (made unique) with a key at 0 and at the length; returns its name.
  String addTimelineTrack(String nodeId, String name, {String type = 'float'}) {
    final tracks = timelineTracks(nodeId);
    final unique = _uniqueName(name, (n) => tracks.any((t) => t.name == n));
    final width = switch (type) { 'vector' => 3, 'color' => 4, _ => 1 };
    final zero = List<double>.filled(width, type == 'color' ? 1.0 : 0.0);
    setTimelineTracks(nodeId, [
      ...tracks,
      LuminaTimelineTrack(name: unique, type: type, keys: [
        LuminaTimelineKey(0.0, zero, LuminaTimelineInterp.linear),
        LuminaTimelineKey(timelineLength(nodeId), zero, LuminaTimelineInterp.linear),
      ]),
    ]);
    return unique;
  }

  bool removeTimelineTrack(String nodeId, String name) {
    final tracks = timelineTracks(nodeId);
    if (!tracks.any((t) => t.name == name)) return false;
    return setTimelineTracks(nodeId, [for (final t in tracks) if (t.name != name) t]);
  }

  bool renameTimelineTrack(String nodeId, String oldName, String newName) {
    final trimmed = newName.trim();
    final tracks = timelineTracks(nodeId);
    final editor = timelineEditor(nodeId);
    if (editor == null || trimmed.isEmpty || trimmed == oldName || tracks.any((t) => t.name == trimmed) || !tracks.any((t) => t.name == oldName)) {
      return false;
    }
    return mutate('Rename track $oldName', () {
      final node = editor.node(nodeId)!;
      // The track's output pin is its name: wires from it follow.
      final g = editor.graph;
      for (var i = 0; i < g.wires.length; i++) {
        final w = g.wires[i];
        if (w.fromNodeId == nodeId && w.fromPinId == oldName) {
          g.wires[i] = LuminaBlueprintWire(id: w.id, fromNodeId: nodeId, fromPinId: trimmed, toNodeId: w.toNodeId, toPinId: w.toPinId);
        }
      }
      node.literals['tracks'] = [
        for (final t in tracks) (t.name == oldName ? LuminaTimelineTrack(name: trimmed, type: t.type, keys: t.keys) : t).toJson(),
      ];
      editor.syncPins(node);
      editor.dropIncompatibleWires(nodeId);
      return true;
    });
  }

  /// Replaces track [track]'s keys (sorted by time, clamped to the length).
  bool setTimelineKeys(String nodeId, String track, List<LuminaTimelineKey> keys) {
    final tracks = timelineTracks(nodeId);
    if (!tracks.any((t) => t.name == track)) return false;
    final length = timelineLength(nodeId);
    final sorted = [
      for (final k in keys) LuminaTimelineKey(k.time.clamp(0.0, length).toDouble(), k.value, k.interp),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return setTimelineTracks(nodeId, [
      for (final t in tracks) t.name == track ? LuminaTimelineTrack(name: t.name, type: t.type, keys: sorted) : t,
    ]);
  }
}

BlueprintGraphRef _refFromKey(String key) {
  final i = key.indexOf(':');
  final kind = BlueprintGraphKind.values.firstWhere((k) => k.name == key.substring(0, i));
  final name = key.substring(i + 1);
  return switch (kind) {
    BlueprintGraphKind.eventGraph => BlueprintGraphRef.eventGraph,
    BlueprintGraphKind.constructionScript => BlueprintGraphRef.constructionScript,
    BlueprintGraphKind.function => BlueprintGraphRef.function(name),
    BlueprintGraphKind.macro => BlueprintGraphRef.macro(name),
    BlueprintGraphKind.timeline => BlueprintGraphRef.timeline(name),
  };
}
