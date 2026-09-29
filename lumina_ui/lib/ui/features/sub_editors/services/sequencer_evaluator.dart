import 'package:lumina/lumina.dart';

/// The sampled state of one [SequencerTrack] at a given frame.
///
/// [values] holds one entry per channel that has at least one key; channels
/// without keys are omitted so the caller never overwrites an actor property
/// the cinematic does not actually animate.
class TrackSample {
  final String trackId;
  final String actorId;
  final SequencerTrackKind kind;
  final String? propertyName;
  final Map<String, double> values;

  const TrackSample({
    required this.trackId,
    required this.actorId,
    required this.kind,
    required this.propertyName,
    required this.values,
  });
}

/// Pure-Dart sampler for [SequencerData].
///
/// Deliberately free of Flutter imports so the generated game runtime can
/// reuse it later to play cinematics in shipped games (the task spec places
/// it in package:lumina; it lives here until that package gains the file).
///
/// Interpolation semantics:
/// * the **left** key of a segment decides how the segment is interpolated;
/// * `constant` holds the left value until the right key's frame;
/// * `linear` lerps between the two key values;
/// * `cubic` evaluates a 1-D cubic Hermite spline built from the key values
///   and their tangents (`outTangent` of the left key, `inTangent` of the
///   right key, in value units per frame), computed with de Casteljau on the
///   equivalent bezier whose time axis is linear in the frame — so the curve
///   is always single-valued over time;
/// * before the first key the first value holds, after the last key the last
///   value holds; a single key is constant everywhere;
/// * visibility tracks always sample as a step, whatever the key says.
class SequencerEvaluator {
  const SequencerEvaluator();

  List<TrackSample> evaluate(SequencerData data, double frame) {
    final samples = <TrackSample>[];
    for (final track in data.tracks) {
      final values = <String, double>{};
      for (final channel in track.channels) {
        final v = track.kind == SequencerTrackKind.visibility
            ? evaluateStep(channel, frame)
            : evaluateChannel(channel, frame);
        if (v != null) values[channel.name] = v;
      }
      samples.add(TrackSample(
        trackId: track.id,
        actorId: track.actorId,
        kind: track.kind,
        propertyName: track.propertyName,
        values: values,
      ));
    }
    return samples;
  }

  /// Samples [channel] at [frame]; `null` when the channel has no keys.
  static double? evaluateChannel(SequencerChannel channel, double frame) {
    final keys = _sorted(channel.keys);
    if (keys.isEmpty) return null;
    if (frame <= keys.first.frame) return keys.first.value;
    if (frame >= keys.last.frame) return keys.last.value;

    for (int i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (frame >= a.frame && frame < b.frame) {
        return evaluateSegment(a, b, frame);
      }
    }
    return keys.last.value;
  }

  /// Step sampling: holds the value of the latest key at or before [frame].
  static double? evaluateStep(SequencerChannel channel, double frame) {
    final keys = _sorted(channel.keys);
    if (keys.isEmpty) return null;
    double value = keys.first.value;
    for (final k in keys) {
      if (k.frame <= frame) {
        value = k.value;
      } else {
        break;
      }
    }
    return value;
  }

  /// Evaluates the segment `[a, b]` at [frame] using [a]'s interpolation.
  static double evaluateSegment(SequencerKey a, SequencerKey b, double frame) {
    final duration = (b.frame - a.frame).toDouble();
    if (duration <= 0) return b.value;
    final t = ((frame - a.frame) / duration).clamp(0.0, 1.0);
    switch (a.interpolation) {
      case KeyInterpolation.constant:
        return a.value;
      case KeyInterpolation.linear:
        return a.value + (b.value - a.value) * t;
      case KeyInterpolation.cubic:
        // Hermite -> bezier: control values sit a third of the way along the
        // tangent, scaled by the segment duration (tangents are per frame).
        final p0 = a.value;
        final p1 = a.value + a.outTangent * duration / 3.0;
        final p2 = b.value - b.inTangent * duration / 3.0;
        final p3 = b.value;
        return cubicBezier1D(p0, p1, p2, p3, t);
    }
  }

  /// De Casteljau evaluation of a 1-D cubic bezier at parameter [t] in [0,1].
  static double cubicBezier1D(double p0, double p1, double p2, double p3, double t) {
    final q0 = p0 + (p1 - p0) * t;
    final q1 = p1 + (p2 - p1) * t;
    final q2 = p2 + (p3 - p2) * t;
    final r0 = q0 + (q1 - q0) * t;
    final r1 = q1 + (q2 - q1) * t;
    return r0 + (r1 - r0) * t;
  }

  /// Catmull-Rom style automatic tangent for `keys[index]`: the slope between
  /// its two neighbours (value units per frame). End keys get a flat tangent.
  static double autoTangent(List<SequencerKey> keys, int index) {
    final sorted = _sorted(keys);
    if (index <= 0 || index >= sorted.length - 1) return 0.0;
    final prev = sorted[index - 1];
    final next = sorted[index + 1];
    final dFrames = (next.frame - prev.frame).toDouble();
    if (dFrames <= 0) return 0.0;
    return (next.value - prev.value) / dFrames;
  }

  /// Sorted, de-duplicated frames of every key on every channel of [data].
  static List<int> mergedKeyFrames(SequencerData data) {
    final frames = <int>{};
    for (final track in data.tracks) {
      for (final channel in track.channels) {
        for (final key in channel.keys) {
          frames.add(key.frame);
        }
      }
    }
    final list = frames.toList()..sort();
    return list;
  }

  static List<SequencerKey> _sorted(List<SequencerKey> keys) {
    if (keys.length < 2) return keys;
    bool sorted = true;
    for (int i = 1; i < keys.length; i++) {
      if (keys[i].frame < keys[i - 1].frame) {
        sorted = false;
        break;
      }
    }
    if (sorted) return keys;
    final copy = List<SequencerKey>.from(keys)..sort((a, b) => a.frame.compareTo(b.frame));
    return copy;
  }
}
