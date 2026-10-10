part of '../audio_sub_editor.dart';

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Draws the min/max peak envelope per channel (L/R stacked), a time ruler and
/// the playhead needle. Peaks are always re-binned from the decoded samples.
class AudioWaveformPainter extends CustomPainter {
  final DecodedAudio audio;
  final int startFrame;
  final int endFrame;
  final double playheadSeconds;
  final int binCount;

  AudioWaveformPainter({
    required this.audio,
    required this.startFrame,
    required this.endFrame,
    required this.playheadSeconds,
    required this.binCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const rulerHeight = 16.0;
    final bg = Paint()..color = EditorColors.background;
    canvas.drawRect(Offset.zero & size, bg);

    final channelHeight = math.max(1.0, (size.height - rulerHeight) / audio.channels);
    final envelopes = audio.peakEnvelope(math.max(1, binCount), startFrame: startFrame, endFrame: endFrame);
    final binWidth = size.width / math.max(1, binCount);

    final wavePaint = Paint()
      ..color = EditorColors.chart3
      ..strokeWidth = math.max(1.0, binWidth);
    final axisPaint = Paint()
      ..color = EditorColors.border
      ..strokeWidth = 1.0;

    for (var c = 0; c < audio.channels; c++) {
      final top = rulerHeight + c * channelHeight;
      final mid = top + channelHeight / 2;
      canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axisPaint);
      final env = envelopes[c];
      for (var b = 0; b < env.binCount; b++) {
        final x = b * binWidth + binWidth / 2;
        final yMax = mid - env.maxs[b] * (channelHeight / 2 - 2);
        final yMin = mid - env.mins[b] * (channelHeight / 2 - 2);
        canvas.drawLine(Offset(x, yMin), Offset(x, yMax), wavePaint);
      }
    }

    // Time ruler over the visible window.
    final startSeconds = startFrame / audio.sampleRate;
    final endSeconds = endFrame / audio.sampleRate;
    final tickPaint = Paint()
      ..color = EditorColors.mutedForeground
      ..strokeWidth = 1.0;
    const tickCount = 8;
    for (var i = 0; i <= tickCount; i++) {
      final x = size.width * i / tickCount;
      canvas.drawLine(Offset(x, 0), Offset(x, rulerHeight - 6), tickPaint);
      final t = startSeconds + (endSeconds - startSeconds) * i / tickCount;
      final tp = TextPainter(
        text: TextSpan(
          text: AudioEditorViewModel.formatTime(t),
          style: const TextStyle(fontSize: 7, color: EditorColors.mutedForeground),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(math.min(x + 2, size.width - tp.width), 1));
    }

    // Playhead needle.
    if (endSeconds > startSeconds) {
      final f = (playheadSeconds - startSeconds) / (endSeconds - startSeconds);
      if (f >= 0 && f <= 1) {
        final x = size.width * f;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = EditorColors.primary
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter old) =>
      old.audio != audio ||
      old.startFrame != startFrame ||
      old.endFrame != endFrame ||
      old.playheadSeconds != playheadSeconds ||
      old.binCount != binCount;
}

/// Plots gain (0–1) against distance for the selected attenuation model, with
/// the inner-radius and falloff handles and the distance probe.
class AudioAttenuationPainter extends CustomPainter {
  final double Function(double distance) gainAt;
  final double maxDistance;
  final double innerRadius;
  final double outerDistance;
  final double probeDistance;
  final double probeGain;
  final bool enabled;

  AudioAttenuationPainter({
    required this.gainAt,
    required this.maxDistance,
    required this.innerRadius,
    required this.outerDistance,
    required this.probeDistance,
    required this.probeGain,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.background);

    final grid = Paint()
      ..color = EditorColors.border
      ..strokeWidth = 1.0;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final curve = Path();
    final steps = math.max(16, size.width.round());
    for (var i = 0; i <= steps; i++) {
      final d = maxDistance * i / steps;
      final g = gainAt(d).clamp(0.0, 1.0);
      final p = Offset(size.width * i / steps, size.height * (1.0 - g));
      if (i == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = enabled ? EditorColors.accent : EditorColors.mutedForeground,
    );

    void handle(double distance, Color color, String label) {
      final x = size.width * (distance / maxDistance).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 8, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(math.min(x + 3, size.width - tp.width), 3));
    }

    handle(innerRadius, EditorColors.logSuccess, 'Inner ${innerRadius.toStringAsFixed(0)}');
    handle(outerDistance, EditorColors.logWarning, 'Falloff ${outerDistance.toStringAsFixed(0)}');

    // Distance probe.
    final px = size.width * (probeDistance / maxDistance).clamp(0.0, 1.0);
    final py = size.height * (1.0 - probeGain.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(px, py), 4.0, Paint()..color = EditorColors.primary);
  }

  @override
  bool shouldRepaint(covariant AudioAttenuationPainter old) =>
      old.maxDistance != maxDistance ||
      old.innerRadius != innerRadius ||
      old.outerDistance != outerDistance ||
      old.probeDistance != probeDistance ||
      old.probeGain != probeGain ||
      old.enabled != enabled ||
      old.gainAt != gainAt;
}
