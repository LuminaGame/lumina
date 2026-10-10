part of '../curve_editor_widget.dart';

/// The visible window of the curve canvas in data space (frames × values).
class CurveView {
  final double minFrame;
  final double maxFrame;
  final double minValue;
  final double maxValue;

  const CurveView({
    required this.minFrame,
    required this.maxFrame,
    required this.minValue,
    required this.maxValue,
  });

  double get frameSpan => math.max(maxFrame - minFrame, 1e-6);
  double get valueSpan => math.max(maxValue - minValue, 1e-6);

  double frameToX(double frame, Size size) => (frame - minFrame) / frameSpan * size.width;
  double valueToY(double value, Size size) => size.height - (value - minValue) / valueSpan * size.height;
  double xToFrame(double x, Size size) => minFrame + x / math.max(size.width, 1e-6) * frameSpan;
  double yToValue(double y, Size size) => minValue + (size.height - y) / math.max(size.height, 1e-6) * valueSpan;

  CurveView copyWith({double? minFrame, double? maxFrame, double? minValue, double? maxValue}) => CurveView(
        minFrame: minFrame ?? this.minFrame,
        maxFrame: maxFrame ?? this.maxFrame,
        minValue: minValue ?? this.minValue,
        maxValue: maxValue ?? this.maxValue,
      );

  /// Frames every key of [channels] with a 10% margin (or the whole
  /// sequence and a unit value band when nothing is keyed).
  static CurveView fit(Iterable<SequencerChannel> channels, {required int lengthFrames}) {
    double? fMin, fMax, vMin, vMax;
    for (final ch in channels) {
      for (final k in ch.keys) {
        fMin = fMin == null ? k.frame.toDouble() : math.min(fMin, k.frame.toDouble());
        fMax = fMax == null ? k.frame.toDouble() : math.max(fMax, k.frame.toDouble());
        vMin = vMin == null ? k.value : math.min(vMin, k.value);
        vMax = vMax == null ? k.value : math.max(vMax, k.value);
      }
    }
    if (fMin == null || fMax == null || vMin == null || vMax == null) {
      return CurveView(minFrame: 0, maxFrame: math.max(lengthFrames, 1).toDouble(), minValue: -1, maxValue: 1);
    }
    if (fMax - fMin < 1) fMax = fMin + 1;
    if (vMax - vMin < 1e-6) {
      vMin -= 1;
      vMax += 1;
    }
    final fPad = (fMax - fMin) * 0.1;
    final vPad = (vMax - vMin) * 0.15;
    return CurveView(minFrame: fMin - fPad, maxFrame: fMax + fPad, minValue: vMin - vPad, maxValue: vMax + vPad);
  }

  @override
  String toString() => 'CurveView(f $minFrame..$maxFrame, v $minValue..$maxValue)';
}

/// A channel shown on the canvas together with the track that owns it.
class CurveChannelRef {
  final SequencerTrack track;
  final SequencerChannel channel;
  const CurveChannelRef(this.track, this.channel);
  String get id => '${track.id}|${channel.name}';
}

class SequencerCurvePainter extends CustomPainter {
  final List<CurveChannelRef> channels;
  final CurveView view;
  final Set<SequencerKeyRef> selectedKeys;
  final SequencerKeyRef? primaryKey;
  final double playheadFrame;
  final Rect? boxSelect;
  final int lengthFrames;

  SequencerCurvePainter({
    required this.channels,
    required this.view,
    required this.selectedKeys,
    required this.primaryKey,
    required this.playheadFrame,
    required this.lengthFrames,
    this.boxSelect,
  });

  static const double handleLengthPx = 48.0;
  static const double keyHalfSize = 4.5;
  static const double hitRadius = 8.0;

  /// X → red, Y → green, Z → blue; other channels cycle a distinct palette.
  static Color channelColor(String name) {
    final upper = name.toUpperCase();
    if (upper.endsWith('.X')) return EditorColors.axisX;
    if (upper.endsWith('.Y')) return EditorColors.axisY;
    if (upper.endsWith('.Z')) return EditorColors.axisZ;
    if (upper == 'VISIBILITY') return EditorColors.logSuccess;
    const palette = [Colors.cyan, Colors.purple, Colors.orange, Colors.pink, Colors.teal, Colors.yellow];
    return palette[name.hashCode.abs() % palette.length];
  }

  static Offset keyScreenPosition(SequencerKey key, CurveView view, Size size) =>
      Offset(view.frameToX(key.frame.toDouble(), size), view.valueToY(key.value, size));

  /// Polyline sampling of the channel's curve in screen space: every segment
  /// is sampled [samplesPerSegment] times so cubic bends and constant steps
  /// draw faithfully; the extrapolated flat ends span the visible window.
  static List<Offset> buildChannelPoints(SequencerChannel channel, CurveView view, Size size, {int samplesPerSegment = 24}) {
    final keys = List<SequencerKey>.from(channel.keys)..sort((a, b) => a.frame.compareTo(b.frame));
    if (keys.isEmpty) return const [];
    final points = <Offset>[];
    points.add(Offset(view.frameToX(math.min(view.minFrame, keys.first.frame.toDouble()), size), view.valueToY(keys.first.value, size)));
    for (int i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      final span = (b.frame - a.frame).toDouble();
      for (int s = 0; s <= samplesPerSegment; s++) {
        final t = s / samplesPerSegment;
        final frame = a.frame + span * t;
        double value;
        if (a.interpolation == KeyInterpolation.constant) {
          value = t < 1.0 ? a.value : b.value;
          if (s == samplesPerSegment) {
            // Draw the vertical step explicitly.
            points.add(Offset(view.frameToX(frame, size), view.valueToY(a.value, size)));
          }
        } else {
          value = SequencerEvaluator.evaluateSegment(a, b, frame);
        }
        points.add(Offset(view.frameToX(frame, size), view.valueToY(value, size)));
      }
    }
    points.add(Offset(view.frameToX(math.max(view.maxFrame, keys.last.frame.toDouble()), size), view.valueToY(keys.last.value, size)));
    return points;
  }

  /// Screen positions of a key's in/out tangent handles. The handle points
  /// along the tangent direction with a fixed on-screen length, shortened so
  /// its frame component never crosses the neighbouring key.
  static ({Offset inHandle, Offset outHandle}) tangentHandlePositions(SequencerChannel channel, int keyIndex, CurveView view, Size size) {
    final key = channel.keys[keyIndex];
    final pos = keyScreenPosition(key, view, size);
    final pxPerFrame = size.width / view.frameSpan;
    final pxPerValue = size.height / view.valueSpan;

    Offset handle(double slope, int direction) {
      final dir = Offset(pxPerFrame, -slope * pxPerValue);
      final len = dir.distance;
      if (len < 1e-9) return pos + Offset(handleLengthPx * direction, 0);
      var scaled = dir / len * handleLengthPx;
      // Clamp the frame component to the gap towards the neighbour key.
      final neighbourIndex = keyIndex + direction;
      if (neighbourIndex >= 0 && neighbourIndex < channel.keys.length) {
        final gapPx = ((channel.keys[neighbourIndex].frame - key.frame).abs()) * pxPerFrame;
        if (gapPx > 0 && scaled.dx.abs() > gapPx) {
          scaled = scaled * (gapPx / scaled.dx.abs());
        }
      }
      return pos + scaled * direction.toDouble();
    }

    return (inHandle: handle(key.inTangent, -1), outHandle: handle(key.outTangent, 1));
  }

  /// Converts a dragged handle position back into a tangent slope
  /// (value units per frame); [direction] is +1 for the out handle, -1 for in.
  static double slopeFromHandle(Offset keyPos, Offset handlePos, int direction, CurveView view, Size size) {
    final pxPerFrame = size.width / view.frameSpan;
    final pxPerValue = size.height / view.valueSpan;
    var dx = handlePos.dx - keyPos.dx;
    dx = direction > 0 ? math.max(dx, 1.0) : math.min(dx, -1.0);
    final dy = handlePos.dy - keyPos.dy;
    final frames = dx / pxPerFrame;
    final values = -dy / pxPerValue;
    return values / frames;
  }

  static double niceStep(double span, int targetDivisions) {
    final raw = span / math.max(targetDivisions, 1);
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    double nice;
    if (norm < 1.5) {
      nice = 1;
    } else if (norm < 3.5) {
      nice = 2;
    } else if (norm < 7.5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * mag;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.background);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final zeroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    // Vertical frame grid
    final fStep = niceStep(view.frameSpan, (size.width / 90).clamp(2, 16).round());
    for (double f = (view.minFrame / fStep).floor() * fStep; f <= view.maxFrame; f += fStep) {
      final x = view.frameToX(f, size);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), f == 0 ? zeroPaint : gridPaint);
      textPainter.text = TextSpan(text: f.toStringAsFixed(fStep < 1 ? 1 : 0), style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, size.height - textPainter.height - 2));
    }
    // Horizontal value grid
    final vStep = niceStep(view.valueSpan, (size.height / 50).clamp(2, 12).round());
    for (double v = (view.minValue / vStep).floor() * vStep; v <= view.maxValue; v += vStep) {
      final y = view.valueToY(v, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), v == 0 ? zeroPaint : gridPaint);
      textPainter.text = TextSpan(text: _fmt(v, vStep), style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground));
      textPainter.layout();
      textPainter.paint(canvas, Offset(3, y - textPainter.height - 1));
    }

    // Sequence bounds shading
    final boundsPaint = Paint()..color = Colors.black.withValues(alpha: 0.28);
    final x0 = view.frameToX(0, size);
    final xEnd = view.frameToX(lengthFrames.toDouble(), size);
    if (x0 > 0) canvas.drawRect(Rect.fromLTRB(0, 0, x0.clamp(0, size.width), size.height), boundsPaint);
    if (xEnd < size.width) canvas.drawRect(Rect.fromLTRB(xEnd.clamp(0, size.width), 0, size.width, size.height), boundsPaint);

    // Curves
    for (final ref in channels) {
      final color = channelColor(ref.channel.name);
      final pts = buildChannelPoints(ref.channel, view, size);
      if (pts.length >= 2) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      // Keys
      for (int k = 0; k < ref.channel.keys.length; k++) {
        final key = ref.channel.keys[k];
        final p = keyScreenPosition(key, view, size);
        final selected = selectedKeys.contains((ref.track.id, ref.channel.name, k));
        final rect = Rect.fromCenter(center: p, width: keyHalfSize * 2, height: keyHalfSize * 2);
        canvas.drawRect(rect, Paint()..color = selected ? Colors.amber : color);
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Tangent handles of the primary key
    final primary = primaryKey;
    if (primary != null) {
      for (final ref in channels) {
        if (ref.track.id != primary.$1 || ref.channel.name != primary.$2) continue;
        if (primary.$3 < 0 || primary.$3 >= ref.channel.keys.length) continue;
        final key = ref.channel.keys[primary.$3];
        if (key.interpolation != KeyInterpolation.cubic) continue;
        final p = keyScreenPosition(key, view, size);
        final handles = tangentHandlePositions(ref.channel, primary.$3, view, size);
        final stem = Paint()
          ..color = Colors.amber.withValues(alpha: 0.85)
          ..strokeWidth = 1.2;
        final dot = Paint()..color = Colors.amber;
        canvas.drawLine(p, handles.inHandle, stem);
        canvas.drawLine(p, handles.outHandle, stem);
        canvas.drawCircle(handles.inHandle, 4, dot);
        canvas.drawCircle(handles.outHandle, 4, dot);
      }
    }

    // Playhead
    final px = view.frameToX(playheadFrame, size);
    if (px >= 0 && px <= size.width) {
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = Colors.red
          ..strokeWidth = 1.5,
      );
    }

    // Box select
    final box = boxSelect;
    if (box != null) {
      canvas.drawRect(box, Paint()..color = Colors.indigo.withValues(alpha: 0.18));
      canvas.drawRect(
        box,
        Paint()
          ..color = Colors.indigo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  String _fmt(double v, double step) {
    if (step >= 1) return v.toStringAsFixed(0);
    if (step >= 0.1) return v.toStringAsFixed(1);
    if (step >= 0.01) return v.toStringAsFixed(2);
    return v.toStringAsFixed(3);
  }

  @override
  bool shouldRepaint(covariant SequencerCurvePainter oldDelegate) => true;
}
