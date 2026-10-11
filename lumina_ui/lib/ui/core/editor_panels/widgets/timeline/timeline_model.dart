import 'dart:math' as math;

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorWidgetEvents;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_layout.dart';

/// What a pointer is over in the track area.
enum TimelineHitKind { none, key, clip, clipStart, clipEnd }

class TimelineHit {
  const TimelineHit(this.kind, {this.id, this.track, this.frame = 0});
  final TimelineHitKind kind;
  final String? id;
  final PluginTimelineTrack? track;
  final double frame;
}

enum _Drag { none, keys, clipMove, clipStart, clipEnd, box }

/// The local, per-frame state of one timeline: its clips, keys, playhead,
/// view and selection, edited at once by drags and keys and reported to
/// the owner only as the interaction contract's discrete events
/// ([EditorWidgetEvent]) and committed state ([EditorWidgetStateSink]).
class TimelineModel extends ChangeNotifier {
  TimelineModel({required this.onEvent, required this.onState});

  EditorWidgetEventSink onEvent;
  EditorWidgetStateSink onState;
  final EditorPreviewThrottle throttle = EditorPreviewThrottle();

  PluginTimelineState state = const PluginTimelineState();
  List<PluginTimelineClip> clips = const [];
  List<PluginTimelineKey> keys = const [];
  final Set<String> selectedClips = {};
  final Set<String> selectedKeys = {};
  double zoom = 4;
  double scroll = 0;
  bool loop = false;

  /// The playhead in frames (fractional while playing); repaints only the
  /// playhead layer.
  final ValueNotifier<double> playhead = ValueNotifier(0);
  final ValueNotifier<bool> playing = ValueNotifier(false);

  /// The box selection rectangle (track area coordinates) while dragging.
  Rect? box;

  _Drag _drag = _Drag.none;
  Offset _dragStart = Offset.zero;
  Map<String, int> _keyOrigin = const {};
  int _keyDelta = 0;
  String? _clipId;
  int _clipStart = 0;
  int _clipEnd = 0;

  bool get dragging => _drag != _Drag.none;

  /// Incoming state (the element state or the spec props): the [changed]
  /// keys replace the local values; a drag in progress keeps its own.
  void adopt(PluginTimelineState next, Set<String> changed, {bool first = false}) {
    state = next;
    if (first || changed.contains('clips')) clips = List.of(next.clips);
    if (first || changed.contains('keys')) {
      keys = List.of(next.keys);
      selectedKeys
        ..clear()
        ..addAll([for (final k in next.keys) if (k.selected) k.id]);
    }
    if (first || changed.contains('zoom')) zoom = next.zoom.toDouble().clamp(0.25, 64.0);
    if (first || changed.contains('scroll')) scroll = math.max(0, next.scroll.toDouble());
    if (first || changed.contains('loop')) loop = next.loop;
    if ((first || changed.contains('playhead')) && !playing.value && !dragging) {
      playhead.value = next.playhead.toDouble().clamp(0, math.max(0, next.length - 1)).toDouble();
    }
    if (first || changed.contains('playing')) playing.value = next.playing;
    notifyListeners();
  }

  TimelineLayout layout() => TimelineLayout(state.tracks, zoom: zoom, scroll: scroll);

  int get frameCount => math.max(1, state.length);
  int get rangeStart => (state.rangeStart ?? 0).clamp(0, frameCount - 1);
  int get rangeEnd => (state.rangeEnd ?? frameCount).clamp(rangeStart + 1, frameCount);

  PluginTimelineClip? clip(String id) => clips.where((c) => c.id == id).firstOrNull;

  /// What is under [p] (track area coordinates).
  TimelineHit hitAt(Offset p, TimelineLayout l) {
    final row = l.rowAt(p.dy);
    final track = row?.track;
    final frame = l.frameAt(p.dx);
    if (track == null) return TimelineHit(TimelineHitKind.none, frame: frame);
    if (TimelineLayout.hasKeys(track)) {
      for (final k in keys.reversed) {
        if (k.track == track.id && (l.xOf(k.frame) - p.dx).abs() <= 6) {
          return TimelineHit(TimelineHitKind.key, id: k.id, track: track, frame: frame);
        }
      }
    }
    if (TimelineLayout.hasClips(track)) {
      for (final c in clips.reversed) {
        if (c.track != track.id) continue;
        final x0 = l.xOf(c.start);
        final x1 = l.xOf(c.end);
        if (p.dx < x0 - 1 || p.dx > x1 + 1) continue;
        final edge = math.min(6.0, (x1 - x0) / 4);
        if (p.dx - x0 <= edge) return TimelineHit(TimelineHitKind.clipStart, id: c.id, track: track, frame: frame);
        if (x1 - p.dx <= edge) return TimelineHit(TimelineHitKind.clipEnd, id: c.id, track: track, frame: frame);
        return TimelineHit(TimelineHitKind.clip, id: c.id, track: track, frame: frame);
      }
    }
    return TimelineHit(TimelineHitKind.none, track: track, frame: frame);
  }

  // --- Selection ---------------------------------------------------------------

  void _emitSelection() {
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onSelectionChanged, PluginEditorWidgetEventKind.selectionChanged, {
      'clip_ids': selectedClips.toList(),
      'key_ids': selectedKeys.toList(),
    }));
  }

  /// A press on [hit] with Shift ([extend]) or not.
  void select(TimelineHit hit, {required bool extend}) {
    final before = ({...selectedClips}, {...selectedKeys});
    if (hit.kind == TimelineHitKind.key) {
      if (extend) {
        selectedKeys.contains(hit.id) ? selectedKeys.remove(hit.id) : selectedKeys.add(hit.id!);
      } else if (!selectedKeys.contains(hit.id)) {
        selectedKeys
          ..clear()
          ..add(hit.id!);
        selectedClips.clear();
      }
    } else if (hit.kind != TimelineHitKind.none) {
      if (!extend) {
        selectedKeys.clear();
        selectedClips.clear();
      }
      selectedClips.add(hit.id!);
    } else if (!extend) {
      selectedKeys.clear();
      selectedClips.clear();
    }
    if (!setEquals(before.$1, selectedClips) || !setEquals(before.$2, selectedKeys)) {
      notifyListeners();
      _emitSelection();
    }
  }

  // --- Drags -------------------------------------------------------------------

  void beginDrag(TimelineHit hit, Offset at) {
    _dragStart = at;
    switch (hit.kind) {
      case TimelineHitKind.key:
        if (hit.track?.locked == true) return;
        _drag = _Drag.keys;
        _keyDelta = 0;
        _keyOrigin = {for (final k in keys) if (selectedKeys.contains(k.id)) k.id: k.frame};
      case TimelineHitKind.clip || TimelineHitKind.clipStart || TimelineHitKind.clipEnd:
        if (hit.track?.locked == true) return;
        final c = clip(hit.id!)!;
        _drag = switch (hit.kind) {
          TimelineHitKind.clipStart => _Drag.clipStart,
          TimelineHitKind.clipEnd => _Drag.clipEnd,
          _ => _Drag.clipMove,
        };
        _clipId = c.id;
        _clipStart = c.start;
        _clipEnd = c.end;
      case TimelineHitKind.none:
        _drag = _Drag.box;
        box = Rect.fromPoints(at, at);
    }
  }

  void updateDrag(Offset at, TimelineLayout l) {
    final frames = (at.dx - _dragStart.dx) / l.zoom;
    switch (_drag) {
      case _Drag.keys:
        var delta = snapFrames(frames, state.snap);
        // Keys stay inside the timeline.
        for (final f in _keyOrigin.values) {
          delta = delta.clamp(-f, frameCount - 1 - f);
        }
        if (delta == _keyDelta) return;
        _keyDelta = delta;
        keys = [for (final k in keys) _keyOrigin.containsKey(k.id) ? k.copyWith(frame: _keyOrigin[k.id]! + delta) : k];
        notifyListeners();
        final ids = _keyOrigin.keys.toList();
        throttle.preview(() => onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onKeyPreview, PluginEditorWidgetEventKind.keysMoved,
            {'key_ids': ids, 'delta_frames': delta}, phase: PluginViewEventPhase.preview)));
      case _Drag.clipMove || _Drag.clipStart || _Drag.clipEnd:
        final c = clip(_clipId!);
        if (c == null) return;
        final d = snapFrames(frames, state.snap);
        var start = _clipStart;
        var end = _clipEnd;
        final minLen = math.max(1, c.minLength ?? 1);
        final maxLen = c.maxLength ?? frameCount;
        if (_drag == _Drag.clipMove) {
          final len = _clipEnd - _clipStart;
          start = (_clipStart + d).clamp(0, math.max(0, frameCount - len));
          end = start + len;
        } else if (_drag == _Drag.clipEnd) {
          end = (_clipEnd + d).clamp(_clipStart + minLen, math.min(frameCount, _clipStart + maxLen));
        } else {
          start = (_clipStart + d).clamp(math.max(0, _clipEnd - maxLen), _clipEnd - minLen);
        }
        if (start == c.start && end == c.end) return;
        _setClip(c.copyWith(start: start, end: end));
        throttle.preview(() => onEvent(_clipEvent(LuminaEditorWidgetEvents.onClipPreview, PluginViewEventPhase.preview, c.id, start, end)));
      case _Drag.box:
        box = Rect.fromPoints(_dragStart, at);
        _boxSelect(l);
        notifyListeners();
      case _Drag.none:
        return;
    }
  }

  void _boxSelect(TimelineLayout l) {
    final b = box;
    if (b == null) return;
    selectedKeys
      ..clear()
      ..addAll([
        for (final k in keys)
          if (l.rowOf(k.track) case final r? when b.contains(Offset(l.xOf(k.frame), r.top + r.height / 2))) k.id,
      ]);
  }

  EditorWidgetEvent _clipEvent(String event, String phase, String id, int start, int end) =>
      EditorWidgetEvent(event, PluginEditorWidgetEventKind.clipChanged, {'clip_id': id, 'start': start, 'end': end}, phase: phase);

  void _setClip(PluginTimelineClip c) {
    clips = [for (final x in clips) x.id == c.id ? c : x];
    notifyListeners();
  }

  /// Release: one commit (nothing when the drag moved nothing).
  void endDrag() {
    throttle.end();
    final drag = _drag;
    _drag = _Drag.none;
    switch (drag) {
      case _Drag.keys:
        if (_keyDelta == 0) return;
        onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onKeyCommit, PluginEditorWidgetEventKind.keysMoved,
            {'key_ids': _keyOrigin.keys.toList(), 'delta_frames': _keyDelta}));
        onState({'keys': [for (final k in keys) k.toJson()]}, edit: true);
      case _Drag.clipMove || _Drag.clipStart || _Drag.clipEnd:
        final c = clip(_clipId!);
        if (c == null || (c.start == _clipStart && c.end == _clipEnd)) return;
        onEvent(_clipEvent(LuminaEditorWidgetEvents.onClipCommit, PluginViewEventPhase.commit, c.id, c.start, c.end));
        onState({'clips': [for (final x in clips) x.toJson()]}, edit: true);
      case _Drag.box:
        box = null;
        notifyListeners();
        _emitSelection();
      case _Drag.none:
        return;
    }
  }

  /// Escape: the drag's values snap back and one cancel is sent.
  bool cancelDrag() {
    throttle.end();
    final drag = _drag;
    _drag = _Drag.none;
    switch (drag) {
      case _Drag.keys:
        keys = [for (final k in keys) _keyOrigin.containsKey(k.id) ? k.copyWith(frame: _keyOrigin[k.id]) : k];
        notifyListeners();
        onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onKeyCancel, PluginEditorWidgetEventKind.keysMoved,
            {'key_ids': _keyOrigin.keys.toList(), 'delta_frames': 0}, phase: PluginViewEventPhase.cancel));
        return true;
      case _Drag.clipMove || _Drag.clipStart || _Drag.clipEnd:
        final c = clip(_clipId!);
        if (c != null) _setClip(c.copyWith(start: _clipStart, end: _clipEnd));
        onEvent(_clipEvent(LuminaEditorWidgetEvents.onClipCancel, PluginViewEventPhase.cancel, _clipId!, _clipStart, _clipEnd));
        return true;
      case _Drag.box:
        box = null;
        notifyListeners();
        return true;
      case _Drag.none:
        return false;
    }
  }

  // --- Edits -------------------------------------------------------------------

  void commitClipText(String id, String text) {
    final c = clip(id);
    if (c == null || c.text == text) return;
    _setClip(c.copyWith(text: text));
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onClipTextCommitted, PluginEditorWidgetEventKind.clipTextCommitted,
        {'clip_id': id, 'text': text}));
    onState({'clips': [for (final x in clips) x.toJson()]}, edit: true);
  }

  /// Double-click on a keys track: a key at [frame] (snapped), reported as
  /// On Key Added; the owner gives it its id (the widget shows it at once
  /// under a local id).
  void addKey(PluginTimelineTrack track, double frame) {
    if (track.locked || !TimelineLayout.hasKeys(track)) return;
    final f = snapFrames(frame, state.snap).clamp(0, frameCount - 1);
    var n = keys.length;
    while (keys.any((k) => k.id == 'key_$n')) {
      n++;
    }
    keys = [...keys, PluginTimelineKey(id: 'key_$n', track: track.id, frame: f)];
    notifyListeners();
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onKeyAdded, PluginEditorWidgetEventKind.keyAdded, {'track': track.id, 'frame': f}));
    onState({'keys': [for (final k in keys) k.toJson()]}, edit: true);
  }

  void deleteSelectedKeys() {
    final ids = [for (final k in keys) if (selectedKeys.contains(k.id)) k.id];
    if (ids.isEmpty) return;
    keys = [for (final k in keys) if (!selectedKeys.contains(k.id)) k];
    selectedKeys.clear();
    notifyListeners();
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onKeysDeleted, PluginEditorWidgetEventKind.keysDeleted, {'key_ids': ids}));
    onState({'keys': [for (final k in keys) k.toJson()]}, edit: true);
  }

  // --- Playhead and transport --------------------------------------------------

  /// The playhead moved by the user (scrub, step) or stopped: reported once.
  void commitPlayhead() {
    final f = playhead.value.floor();
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onPlayheadChanged, PluginEditorWidgetEventKind.playheadChanged, {'frame': f}));
    onState({'playhead': f}, edit: false);
  }

  void setPlayhead(double frame) => playhead.value = frame.clamp(0, frameCount - 1).toDouble();

  void step(int frames) {
    setPlayhead((playhead.value.floor() + frames).toDouble());
    commitPlayhead();
  }

  void setPlaying(bool on) {
    if (playing.value == on) return;
    playing.value = on;
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onPlayStateChanged, PluginEditorWidgetEventKind.playStateChanged,
        {'playing': on, 'loop': loop}));
    onState({'playing': on, if (!on) 'playhead': playhead.value.floor()}, edit: false);
    if (!on) commitPlayhead();
  }

  void toggleLoop() {
    loop = !loop;
    notifyListeners();
    onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onPlayStateChanged, PluginEditorWidgetEventKind.playStateChanged,
        {'playing': playing.value, 'loop': loop}));
    onState({'loop': loop}, edit: false);
  }

  /// Ctrl + wheel: zoom keeping the frame under [x] in place.
  void zoomAround(double x, double factor) {
    final frame = scroll + x / zoom;
    zoom = (zoom * factor).clamp(0.25, 64.0);
    scroll = math.max(0, frame - x / zoom);
    notifyListeners();
  }

  void pan(double dx) {
    scroll = math.max(0, scroll - dx / zoom);
    notifyListeners();
  }

  /// The view (zoom, scroll) is kept in the state after a gesture.
  void commitView() => onState({'zoom': double.parse(zoom.toStringAsFixed(3)), 'scroll': double.parse(scroll.toStringAsFixed(3))}, edit: false);

  @override
  void dispose() {
    throttle.dispose();
    playhead.dispose();
    playing.dispose();
    super.dispose();
  }
}
