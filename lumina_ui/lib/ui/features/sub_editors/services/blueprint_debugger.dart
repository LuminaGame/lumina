import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';

/// Live execution of one running Blueprint instance (the Blueprint
/// debugger): the nodes it ran and the exec wires it
/// took in the last [window], and the last value of every pin. Fed by the
/// instance's `trace`; read by the graph canvas.
class BlueprintTraceRecorder extends ChangeNotifier {
  final LuminaBlueprintGraph graph;
  static const Duration window = Duration(milliseconds: 500);

  final Map<String, DateTime> _nodes = {};
  final Map<String, DateTime> _wires = {};
  final Map<String, Map<String, Object?>> _values = {};
  Timer? _fade;
  bool _notifyQueued = false;
  bool _disposed = false;

  /// Every trace event received, for tests and the status line.
  int eventCount = 0;

  BlueprintTraceRecorder(this.graph);

  bool _isExecInput(LuminaBlueprintNode node, String pinId) {
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec != null) return spec.inputs.any((p) => p.id == pinId && p.type == LuminaPinType.exec);
    return node.inputs.any((p) => p.id == pinId && p.type == LuminaPinType.exec);
  }

  bool _recent(DateTime? t, DateTime now) => t != null && now.difference(t) <= const Duration(milliseconds: 100);

  /// Records one executed or evaluated node.
  void record(LuminaBlueprintTraceEvent event) {
    if (_disposed) return;
    final now = DateTime.now();
    eventCount++;
    _nodes[event.eventNodeId] = now;
    _nodes[event.nodeId] = now;
    _values[event.nodeId] = Map.of(event.values);
    final node = graph.node(event.nodeId);
    if (node != null) {
      for (final w in graph.wires) {
        if (w.toNodeId != event.nodeId || !_isExecInput(node, w.toPinId)) continue;
        if (w.fromNodeId == event.eventNodeId || _recent(_nodes[w.fromNodeId], now)) _wires[w.id] = now;
      }
    }
    _queueNotify();
  }

  void _queueNotify() {
    if (!_notifyQueued) {
      _notifyQueued = true;
      scheduleMicrotask(() {
        _notifyQueued = false;
        if (!_disposed) notifyListeners();
      });
    }
    // Keep repainting while anything is lit, so wires animate and fade.
    _fade ??= Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (_disposed) return t.cancel();
      notifyListeners();
      if (activeNodeIds.isEmpty && activeWireIds.isEmpty) {
        t.cancel();
        _fade = null;
      }
    });
  }

  Set<String> _active(Map<String, DateTime> m) {
    final now = DateTime.now();
    return {
      for (final e in m.entries)
        if (now.difference(e.value) <= window) e.key,
    };
  }

  /// Nodes run in the last [window].
  Set<String> get activeNodeIds => _active(_nodes);

  /// Exec wires taken in the last [window].
  Set<String> get activeWireIds => _active(_wires);

  /// 1 just after a node ran, fading to 0 over [window].
  double intensity(String nodeId, {bool wire = false}) {
    final t = (wire ? _wires : _nodes)[nodeId];
    if (t == null) return 0;
    final age = DateTime.now().difference(t).inMicroseconds / window.inMicroseconds;
    return (1 - age).clamp(0.0, 1.0).toDouble();
  }

  /// The last value [nodeId]'s pin [pinId] carried, or null.
  Object? lastValue(String nodeId, String pinId) => _values[nodeId]?[pinId];
  bool hasValue(String nodeId, String pinId) => _values[nodeId]?.containsKey(pinId) ?? false;

  @override
  void dispose() {
    _disposed = true;
    _fade?.cancel();
    super.dispose();
  }
}

/// The Blueprint instances a Play session debugs: the
/// possessed pawn's, and the selected placed Blueprint actor's, by the
/// project-relative path of their class. Blueprint editors showing one of
/// those classes light up its graph.
class BlueprintPieDebugger extends ChangeNotifier {
  BlueprintPieDebugger._();
  static final BlueprintPieDebugger instance = BlueprintPieDebugger._();

  final Map<String, LuminaBlueprintInstance> _targets = {};
  final Map<String, BlueprintTraceRecorder> _recorders = {};
  final Map<String, void Function(LuminaBlueprintTraceEvent event)?> _previous = {};

  bool get isRunning => _targets.isNotEmpty;
  Map<String, LuminaBlueprintInstance> get targets => Map.unmodifiable(_targets);

  /// The recorder for class [path], or null when no debugged instance plays it.
  BlueprintTraceRecorder? recorderFor(String path) => _recorders[path];

  /// Debugs [targets] (path → instance), replacing what was debugged.
  void setTargets(Map<String, LuminaBlueprintInstance> targets) {
    final same = targets.length == _targets.length && targets.entries.every((e) => identical(_targets[e.key], e.value));
    if (same) return;
    _release();
    for (final e in targets.entries) {
      final recorder = BlueprintTraceRecorder(e.value.blueprintClass.document.eventGraph);
      // Keep what already listens (PIE's project-code notices).
      final previous = e.value.trace;
      _previous[e.key] = previous;
      e.value.trace = previous == null
          ? recorder.record
          : (event) {
              previous(event);
              recorder.record(event);
            };
      _targets[e.key] = e.value;
      _recorders[e.key] = recorder;
    }
    notifyListeners();
  }

  void _release() {
    for (final e in _targets.entries) {
      e.value.trace = _previous[e.key];
    }
    _previous.clear();
    for (final r in _recorders.values) {
      r.dispose();
    }
    _targets.clear();
    _recorders.clear();
  }

  /// Play stopped.
  void clear() {
    if (_targets.isEmpty) return;
    _release();
    notifyListeners();
  }
}

/// A `breakpoint` node reached during Play: Play
/// pauses on it and the Blueprint editor frames the node. Cleared when Play resumes or stops.
class BlueprintBreakpointHit {
  final String blueprintPath;
  final String nodeId;
  final DateTime at;
  const BlueprintBreakpointHit({required this.blueprintPath, required this.nodeId, required this.at});

  String get blueprintName => blueprintPath.split('/').last.replaceAll('.lmas', '');

  @override
  String toString() => 'BlueprintBreakpointHit($blueprintName → $nodeId)';
}

/// The breakpoint Play is paused on, if any.
class BlueprintBreakpoints extends ChangeNotifier {
  BlueprintBreakpoints._();
  static final BlueprintBreakpoints instance = BlueprintBreakpoints._();

  BlueprintBreakpointHit? _current;
  int hitCount = 0;

  BlueprintBreakpointHit? get current => _current;

  /// Records a hit; returns false when Play is already stopped on one.
  bool hit(String blueprintPath, String nodeId) {
    if (_current != null) return false;
    _current = BlueprintBreakpointHit(blueprintPath: blueprintPath, nodeId: nodeId, at: DateTime.now());
    hitCount++;
    notifyListeners();
    return true;
  }

  void clear() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}

/// Requests to open a Blueprint at a node (Play's compile-errors dialog): a
/// Blueprint editor showing [path] selects and frames [nodeId].
class BlueprintNavigation extends ChangeNotifier {
  BlueprintNavigation._();
  static final BlueprintNavigation instance = BlueprintNavigation._();

  ({String path, String nodeId})? _pending;

  /// The newest request, until an editor for its Blueprint takes it.
  ({String path, String nodeId})? get pending => _pending;

  void request(String path, String nodeId) {
    _pending = (path: path, nodeId: nodeId);
    notifyListeners();
  }

  /// The pending node for [path], consumed; null when none.
  String? take(String path) {
    final p = _pending;
    if (p == null || p.path != path) return null;
    _pending = null;
    return p.nodeId;
  }
}
