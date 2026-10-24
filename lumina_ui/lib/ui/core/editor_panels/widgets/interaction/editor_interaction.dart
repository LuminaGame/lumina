import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginViewEventPhase;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// One event a native editor widget (timeline, table, canvas) sends.
///
/// [event] is the element event an editor panel graph binds
/// (`OnKeyCommit`); [kind] and [phase] are what a JSON spec's
/// `PluginViewEvent` carries (`keysMoved`, `commit`); [args] are keyed by
/// the event node's output pin ids (`key_ids`, `delta_frames`) in both.
class EditorWidgetEvent {
  const EditorWidgetEvent(this.event, this.kind, this.args, {this.phase = PluginViewEventPhase.commit});

  final String event;
  final String kind;
  final String phase;
  final Map<String, Object?> args;

  @override
  String toString() => '$event($args)';
}

typedef EditorWidgetEventSink = void Function(EditorWidgetEvent event);

/// Where a native widget's committed state goes: an editor panel writes
/// [changes] into the element state, a JSON spec control keeps them until
/// the plugin process answers. [edit] is true for a change the owner is
/// expected to answer (clips, keys, rows, items), false for view state
/// (playhead, zoom, scroll, sort, selection).
typedef EditorWidgetStateSink = void Function(Map<String, Object?> changes, {required bool edit});

/// The preview / commit / cancel contract of a drag: [preview] sends at
/// most once per [interval] (30 a second), keeping the latest value and
/// sending it when the interval ends; [commit] and [cancel] drop a pending
/// preview, so a commit is always the last word.
class EditorPreviewThrottle {
  EditorPreviewThrottle({this.interval = const Duration(microseconds: 1000000 ~/ 30 + 1)});

  final Duration interval;
  Timer? _timer;
  VoidCallback? _pending;

  /// How many previews were sent (diagnostics, tests).
  int sent = 0;

  /// Sends [send] now when the last preview is older than [interval],
  /// otherwise when the interval ends (only the latest one).
  void preview(VoidCallback send) {
    if (_timer == null) {
      sent++;
      send();
      _timer = Timer(interval, _flush);
    } else {
      _pending = send;
    }
  }

  void _flush() {
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) preview(pending);
  }

  /// Ends the drag: a pending preview is dropped.
  void end() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void dispose() => end();
}

/// Snaps [frames] to a multiple of [snap] (1 or less: whole frames).
int snapFrames(num frames, int snap) {
  if (snap <= 1) return frames.round();
  return (frames / snap).round() * snap;
}

/// A `#RRGGBB` / `#RRGGBBAA` colour, or [fallback].
Color editorWidgetColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = '${h}FF';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  // RRGGBBAA → AARRGGBB.
  return Color(((v & 0xFF) << 24) | (v >> 8));
}

/// Whether two JSON-plain values are equal (deep).
bool editorJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !editorJsonEquals(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!editorJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Tracks which state keys of a widget's input map changed between builds:
/// values are compared by identity (a graph, a process patch and the
/// widget's own commits all write new lists), scalars by value.
class EditorStateSnapshot {
  Map<String, Object?> _last = const {};

  /// The keys of [state] that differ from the previous call's.
  Set<String> changedKeys(Map<String, Object?> state, Iterable<String> keys) {
    final out = <String>{};
    for (final k in keys) {
      final a = _last[k];
      final b = state[k];
      if (identical(a, b)) continue;
      if ((a is List || a is Map || b is List || b is Map) || a != b) out.add(k);
    }
    _last = Map<String, Object?>.of(state);
    return out;
  }
}

/// The editor's message when a native widget's state cannot be read.
class EditorWidgetStateError extends StatelessWidget {
  const EditorWidgetStateError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        color: EditorColors.destructive.withValues(alpha: 0.13),
        padding: const EdgeInsets.all(6),
        child: Text(message, style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
      );
}
