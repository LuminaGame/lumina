import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';

SequencerChannel _channel(List<SequencerKey> keys, {String name = 'Location.X'}) =>
    SequencerChannel(name: name, keys: keys);

void main() {
  group('SequencerEvaluator channel sampling', () {
    test('linear: keys (0 -> 0.0) and (60 -> 10.0) sample exactly 5.0 at frame 30', () {
      final ch = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.linear),
      ]);
      expect(SequencerEvaluator.evaluateChannel(ch, 30), equals(5.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 15), closeTo(2.5, 1e-9));
    });

    test('constant: holds 0.0 until 59.999 and reads 10.0 at frame 60', () {
      final ch = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.constant),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.constant),
      ]);
      expect(SequencerEvaluator.evaluateChannel(ch, 30), equals(0.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 59.999), equals(0.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 60), equals(10.0));
    });

    test('cubic with flat tangents: 5.0 at midpoint and monotone in between', () {
      final ch = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.cubic),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.cubic),
      ]);
      expect(SequencerEvaluator.evaluateChannel(ch, 30), closeTo(5.0, 1e-9));
      double prev = SequencerEvaluator.evaluateChannel(ch, 0)!;
      for (int f = 1; f <= 60; f++) {
        final v = SequencerEvaluator.evaluateChannel(ch, f.toDouble())!;
        expect(v, greaterThanOrEqualTo(prev - 1e-12), reason: 'not monotone at frame $f');
        expect(v, inInclusiveRange(0.0, 10.0));
        prev = v;
      }
      // Ease-in/ease-out: flat tangents make the quarter sample sit below linear.
      expect(SequencerEvaluator.evaluateChannel(ch, 15), lessThan(2.5));
    });

    test('edge cases: before first key, after last key, single key', () {
      final ch = _channel([
        SequencerKey(frame: 10, value: 3.0),
        SequencerKey(frame: 50, value: 7.0),
      ]);
      expect(SequencerEvaluator.evaluateChannel(ch, -5), equals(3.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 0), equals(3.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 50), equals(7.0));
      expect(SequencerEvaluator.evaluateChannel(ch, 999), equals(7.0));

      final single = _channel([SequencerKey(frame: 20, value: 42.0)]);
      expect(SequencerEvaluator.evaluateChannel(single, 0), equals(42.0));
      expect(SequencerEvaluator.evaluateChannel(single, 20), equals(42.0));
      expect(SequencerEvaluator.evaluateChannel(single, 1000), equals(42.0));

      final empty = _channel([]);
      expect(SequencerEvaluator.evaluateChannel(empty, 10), isNull);
    });

    test('cubic tangent effect: raising outTangent of key 0 lifts the frame-15 sample', () {
      final flat = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.cubic),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.cubic),
      ]);
      final raised = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.cubic, outTangent: 0.5),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.cubic),
      ]);
      final baseline = SequencerEvaluator.evaluateChannel(flat, 15)!;
      final lifted = SequencerEvaluator.evaluateChannel(raised, 15)!;
      expect(lifted, greaterThan(baseline));
    });

    test('a tangent of exactly the linear slope reproduces the straight line', () {
      // slope = 10 / 60 per frame
      final ch = _channel([
        SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.cubic, outTangent: 10 / 60),
        SequencerKey(frame: 60, value: 10.0, interpolation: KeyInterpolation.cubic, inTangent: 10 / 60),
      ]);
      for (final f in [0.0, 12.0, 30.0, 45.0, 60.0]) {
        expect(SequencerEvaluator.evaluateChannel(ch, f), closeTo(f / 6.0, 1e-9));
      }
    });

    test('autoTangent returns the Catmull-Rom slope of the neighbours and 0 at the ends', () {
      final keys = [
        SequencerKey(frame: 0, value: 0.0),
        SequencerKey(frame: 10, value: 10.0),
        SequencerKey(frame: 30, value: 30.0),
      ];
      expect(SequencerEvaluator.autoTangent(keys, 1), closeTo(1.0, 1e-9));
      expect(SequencerEvaluator.autoTangent(keys, 0), equals(0.0));
      expect(SequencerEvaluator.autoTangent(keys, 2), equals(0.0));
    });
  });

  group('SequencerEvaluator track evaluation', () {
    test('evaluate() emits one TrackSample per track with every keyed channel', () {
      final data = SequencerData(
        fps: 30,
        lengthFrames: 120,
        tracks: [
          SequencerTrack(
            id: 't-transform',
            actorId: 'actor-a',
            actorName: 'A',
            kind: SequencerTrackKind.transform,
            channels: [
              _channel([SequencerKey(frame: 0, value: 0.0), SequencerKey(frame: 60, value: 12.0)]),
              _channel([], name: 'Location.Y'),
            ],
          ),
          SequencerTrack(
            id: 't-vis',
            actorId: 'actor-a',
            actorName: 'A',
            kind: SequencerTrackKind.visibility,
            channels: [
              _channel([
                SequencerKey(frame: 0, value: 1.0, interpolation: KeyInterpolation.linear),
                SequencerKey(frame: 30, value: 0.0, interpolation: KeyInterpolation.linear),
              ], name: 'visibility'),
            ],
          ),
        ],
      );

      final samples = const SequencerEvaluator().evaluate(data, 30);
      expect(samples.length, equals(2));
      final transform = samples.firstWhere((s) => s.trackId == 't-transform');
      expect(transform.values['Location.X'], equals(6.0));
      expect(transform.values.containsKey('Location.Y'), isFalse, reason: 'unkeyed channels are not sampled');

      // Visibility samples as a step regardless of key interpolation.
      final vis = samples.firstWhere((s) => s.trackId == 't-vis');
      expect(vis.values['visibility'], equals(0.0));
      final visAt15 = const SequencerEvaluator().evaluate(data, 15).firstWhere((s) => s.trackId == 't-vis');
      expect(visAt15.values['visibility'], equals(1.0));
    });

    test('mergedKeyFrames returns the sorted, de-duplicated key set across all tracks', () {
      final data = SequencerData(tracks: [
        SequencerTrack(id: 'a', actorId: 'x', actorName: 'X', kind: SequencerTrackKind.property, channels: [
          _channel([SequencerKey(frame: 40, value: 1), SequencerKey(frame: 10, value: 1)], name: 'intensity'),
        ]),
        SequencerTrack(id: 'b', actorId: 'y', actorName: 'Y', kind: SequencerTrackKind.transform, channels: [
          _channel([SequencerKey(frame: 25, value: 1), SequencerKey(frame: 10, value: 1)]),
        ]),
      ]);
      expect(SequencerEvaluator.mergedKeyFrames(data), equals([10, 25, 40]));
    });
  });
}
