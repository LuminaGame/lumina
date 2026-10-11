import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginTimelineTrack, PluginTimelineTrackKind;

/// One row of the track area: a group header ([track] null) or a track.
class TimelineRow {
  const TimelineRow({required this.top, required this.height, this.track, this.group});

  final double top;
  final double height;
  final PluginTimelineTrack? track;

  /// The group name of a group header row.
  final String? group;

  double get bottom => top + height;
  bool get isGroup => track == null;
}

/// The vertical layout of a timeline's tracks (group headers before the
/// first track of each group) and the frame ↔ x mapping of its view.
class TimelineLayout {
  TimelineLayout(List<PluginTimelineTrack> tracks, {required this.zoom, required this.scroll}) : rows = _rows(tracks);

  static const double rulerHeight = 22;
  static const double trackHeight = 24;
  static const double groupHeight = 20;
  static const double headerWidth = 168;
  static const double transportHeight = 26;

  /// Pixels per frame.
  final double zoom;

  /// The first visible frame (may be fractional).
  final double scroll;
  final List<TimelineRow> rows;

  static List<TimelineRow> _rows(List<PluginTimelineTrack> tracks) {
    final out = <TimelineRow>[];
    var y = 0.0;
    String? group;
    for (final t in tracks) {
      if (t.group != null && t.group != group) {
        out.add(TimelineRow(top: y, height: groupHeight, group: t.group));
        y += groupHeight;
      }
      group = t.group;
      final h = (t.height?.toDouble() ?? trackHeight).clamp(18.0, 96.0);
      out.add(TimelineRow(top: y, height: h, track: t));
      y += h;
    }
    return out;
  }

  double get contentHeight => rows.isEmpty ? 0 : rows.last.bottom;

  double xOf(num frame) => (frame - scroll) * zoom;

  double frameAt(double x) => scroll + x / zoom;

  /// The track row under [y] (track area coordinates), or null.
  TimelineRow? rowAt(double y) {
    for (final r in rows) {
      if (y >= r.top && y < r.bottom) return r;
    }
    return null;
  }

  TimelineRow? rowOf(String trackId) {
    for (final r in rows) {
      if (r.track?.id == trackId) return r;
    }
    return null;
  }

  static bool hasClips(PluginTimelineTrack t) => t.kind != PluginTimelineTrackKind.keys;
  static bool hasKeys(PluginTimelineTrack t) => t.kind != PluginTimelineTrackKind.clips;
}
