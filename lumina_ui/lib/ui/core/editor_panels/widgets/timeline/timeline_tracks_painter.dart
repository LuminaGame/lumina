import 'dart:math' as math;

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginTimelineClip, PluginTimelineKey, PluginTimelineKeyStyle;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_layout.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The track area: row bands (group rows darker, locked tracks hatched),
/// second grid lines, clip blocks with their text, keyframe glyphs, the
/// selection highlight and the box selection.
class TimelineTracksPainter extends CustomPainter {
  TimelineTracksPainter({
    required this.layout,
    required this.clips,
    required this.keys,
    required this.selectedClips,
    required this.selectedKeys,
    required this.fps,
    required this.length,
    this.box,
    this.editingClip,
  });

  final TimelineLayout layout;
  final List<PluginTimelineClip> clips;
  final List<PluginTimelineKey> keys;
  final Set<String> selectedClips;
  final Set<String> selectedKeys;
  final int fps;
  final int length;
  final Rect? box;

  /// The clip whose text an inline field edits (its text is not painted).
  final String? editingClip;

  /// How often any timeline's track area painted (tests check that
  /// playback repaints only the playhead layer).
  static int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    final l = layout;
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.sidebar);
    final line = Paint()..color = EditorColors.border;
    for (final r in l.rows) {
      final band = Rect.fromLTWH(0, r.top, size.width, r.height);
      if (r.isGroup) {
        canvas.drawRect(band, Paint()..color = EditorColors.cardHeader);
      } else if (r.track!.locked) {
        canvas.drawRect(band, Paint()..color = const Color(0x0DFFFFFF));
      }
      canvas.drawLine(Offset(0, r.bottom - 0.5), Offset(size.width, r.bottom - 0.5), line);
    }
    // A line per second.
    if (fps > 0 && fps * l.zoom >= 24) {
      final grid = Paint()..color = const Color(0x10FFFFFF);
      for (var f = (l.scroll / fps).floor() * fps; f <= length; f += fps) {
        final x = l.xOf(f);
        if (x > size.width) break;
        if (x >= 0) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
    }
    final endX = l.xOf(length);
    if (endX < size.width) canvas.drawRect(Rect.fromLTRB(math.max(0, endX), 0, size.width, size.height), Paint()..color = const Color(0x44000000));
    for (final c in clips) {
      _clip(canvas, size, c);
    }
    for (final k in keys) {
      _key(canvas, size, k);
    }
    final b = box;
    if (b != null) {
      final r = Rect.fromPoints(b.topLeft, b.bottomRight);
      canvas.drawRect(r, Paint()..color = EditorColors.primary.withValues(alpha: 0.12));
      canvas.drawRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..color = EditorColors.primary);
    }
  }

  void _clip(Canvas canvas, Size size, PluginTimelineClip c) {
    final row = layout.rowOf(c.track);
    if (row == null) return;
    final x0 = layout.xOf(c.start);
    final x1 = layout.xOf(c.end);
    if (x1 < 0 || x0 > size.width) return;
    final rect = Rect.fromLTRB(x0, row.top + 2, x1, row.bottom - 2);
    final selected = selectedClips.contains(c.id);
    final color = editorWidgetColor(c.color, EditorColors.chart2);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: selected ? 0.55 : 0.35));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.5 : 1
          ..color = selected ? EditorColors.primary : color);
    // Resize handles.
    final handle = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, 2, rect.height), handle);
    canvas.drawRect(Rect.fromLTWH(rect.right - 2, rect.top, 2, rect.height), handle);
    final text = c.text;
    if (text != null && text.isNotEmpty && c.id != editingClip && rect.width > 12) {
      canvas.save();
      canvas.clipRect(rect.deflate(3));
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, rect.width - 8));
      tp.paint(canvas, Offset(rect.left + 5, rect.center.dy - tp.height / 2));
      canvas.restore();
    }
  }

  void _key(Canvas canvas, Size size, PluginTimelineKey k) {
    final row = layout.rowOf(k.track);
    if (row == null) return;
    final x = layout.xOf(k.frame);
    if (x < -8 || x > size.width + 8) return;
    final cy = row.top + row.height / 2;
    final selected = selectedKeys.contains(k.id);
    final fill = Paint()..color = selected ? EditorColors.primary : editorWidgetColor(k.color, EditorColors.foreground);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = selected ? EditorColors.accentForeground : const Color(0xFF111111);
    const s = 5.0;
    switch (k.style) {
      case PluginTimelineKeyStyle.circle:
        canvas.drawCircle(Offset(x, cy), s - 0.5, fill);
        canvas.drawCircle(Offset(x, cy), s - 0.5, stroke);
      case PluginTimelineKeyStyle.square:
        final r = Rect.fromCenter(center: Offset(x, cy), width: s * 1.7, height: s * 1.7);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, stroke);
      default:
        final p = Path()
          ..moveTo(x, cy - s)
          ..lineTo(x + s, cy)
          ..lineTo(x, cy + s)
          ..lineTo(x - s, cy)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
    }
  }

  @override
  bool shouldRepaint(TimelineTracksPainter old) =>
      old.layout.zoom != layout.zoom ||
      old.layout.scroll != layout.scroll ||
      old.layout.rows.length != layout.rows.length ||
      !identical(old.clips, clips) ||
      !identical(old.keys, keys) ||
      !setEquals(old.selectedClips, selectedClips) ||
      !setEquals(old.selectedKeys, selectedKeys) ||
      old.box != box ||
      old.editingClip != editingClip ||
      old.length != length ||
      old.fps != fps;
}
