import 'dart:math' as math;

import 'package:flutter_filament/filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [limiter] [seconds] of display refreshes at [hz] (with up to
/// [jitterUs] of timestamp jitter, as a real vsync callback has) and returns
/// the refreshes it rendered on.
List<int> _run(FilamentFrameLimiter limiter, {required double hz, double seconds = 10, int jitterUs = 400, int startUs = 0}) {
  final random = math.Random(7);
  final periodUs = 1e6 / hz;
  final rendered = <int>[];
  final count = (seconds * hz).round();
  for (var i = 0; i < count; i++) {
    final jitter = jitterUs == 0 ? 0 : random.nextInt(2 * jitterUs) - jitterUs;
    final t = startUs + (i * periodUs).round() + jitter;
    if (limiter.shouldRender(Duration(microseconds: t))) rendered.add(i);
  }
  return rendered;
}

/// The refreshes between consecutive rendered frames.
List<int> _gaps(List<int> rendered) => [for (var i = 1; i < rendered.length; i++) rendered[i] - rendered[i - 1]];

void main() {
  group('FilamentFrameLimiter on a 60 Hz display', () {
    for (final vsync in [true, false]) {
      test('unlimited renders every refresh (VSync $vsync)', () {
        final rendered = _run(FilamentFrameLimiter(targetFps: 0, vsync: vsync), hz: 60);
        expect(rendered, hasLength(600));
      });

      test('60 FPS renders every refresh despite timestamp jitter (VSync $vsync)', () {
        final rendered = _run(FilamentFrameLimiter(targetFps: 60, vsync: vsync), hz: 60);
        expect(rendered.length, greaterThanOrEqualTo(598));
      });

      test('120 FPS is capped by the refresh rate (VSync $vsync)', () {
        final rendered = _run(FilamentFrameLimiter(targetFps: 120, vsync: vsync), hz: 60);
        expect(rendered.length, greaterThanOrEqualTo(598));
      });

      test('30 FPS renders every other refresh (VSync $vsync)', () {
        final rendered = _run(FilamentFrameLimiter(targetFps: 30, vsync: vsync), hz: 60);
        expect(rendered.length, inInclusiveRange(299, 301));
        expect(_gaps(rendered).toSet(), {2});
      });
    }

    test('45 FPS with VSync holds every frame for the same number of refreshes (refresh / 2)', () {
      final rendered = _run(FilamentFrameLimiter(targetFps: 45, vsync: true), hz: 60);
      expect(rendered.length, inInclusiveRange(299, 301));
      expect(_gaps(rendered).toSet(), {2});
    });

    test('45 FPS without VSync averages the target, alternating one and two refreshes', () {
      final rendered = _run(FilamentFrameLimiter(targetFps: 45, vsync: false), hz: 60);
      expect(rendered.length, inInclusiveRange(447, 453));
      expect(_gaps(rendered).toSet(), {1, 2});
    });
  });

  group('FilamentFrameLimiter on a 144 Hz display', () {
    test('learns the refresh rate', () {
      final limiter = FilamentFrameLimiter(targetFps: 60, vsync: true);
      _run(limiter, hz: 144, seconds: 1);
      expect(limiter.refreshRate, closeTo(144, 1));
    });

    test('60 FPS with VSync is the largest refresh divisor not above it (48)', () {
      final rendered = _run(FilamentFrameLimiter(targetFps: 60, vsync: true), hz: 144);
      // The first frames run before the refresh rate is learned.
      expect(rendered.length, inInclusiveRange(478, 486));
      expect(_gaps(rendered.sublist(20)).toSet(), {3});
    });

    test('60 FPS without VSync averages 60', () {
      final rendered = _run(FilamentFrameLimiter(targetFps: 60, vsync: false), hz: 144);
      expect(rendered.length, inInclusiveRange(597, 603));
    });
  });

  group('FilamentFrameLimiter changes', () {
    test('a new target takes effect at once', () {
      final limiter = FilamentFrameLimiter(targetFps: 30, vsync: true);
      expect(_run(limiter, hz: 60, seconds: 2).length, inInclusiveRange(59, 61));
      limiter.configure(targetFps: 0, vsync: true);
      expect(_run(limiter, hz: 60, seconds: 2, startUs: 2000000).length, 120);
      limiter.configure(targetFps: 30, vsync: false);
      expect(_run(limiter, hz: 60, seconds: 2, startUs: 4000000).length, inInclusiveRange(59, 61));
    });

    test('a hitch renders on the next refresh and does not burst afterwards', () {
      final limiter = FilamentFrameLimiter(targetFps: 30, vsync: false);
      _run(limiter, hz: 60, seconds: 1, jitterUs: 0);
      // 250 ms without a refresh (the window was dragged).
      final after = _run(limiter, hz: 60, seconds: 1, jitterUs: 0, startUs: 1250000);
      expect(after.first, 0);
      expect(_gaps(after).toSet(), {2});
    });

    test('the same refresh asked twice gets the same answer (a shared limiter)', () {
      final limiter = FilamentFrameLimiter(targetFps: 30, vsync: true);
      final answers = <(bool, bool)>[];
      for (var i = 0; i < 60; i++) {
        final t = Duration(microseconds: (i * 16667).round());
        answers.add((limiter.shouldRender(t), limiter.shouldRender(t)));
      }
      expect(answers.every((a) => a.$1 == a.$2), isTrue);
      expect(answers.where((a) => a.$1), hasLength(30));
    });

    test('effectiveFrameRate is what the limiter aims for', () {
      final limiter = FilamentFrameLimiter(targetFps: 45, vsync: true);
      _run(limiter, hz: 60, seconds: 1);
      expect(limiter.effectiveFrameRate, closeTo(30, 0.5));
      limiter.configure(targetFps: 45, vsync: false);
      expect(limiter.effectiveFrameRate, closeTo(45, 1e-9));
      limiter.configure(targetFps: 0, vsync: false);
      expect(limiter.effectiveFrameRate, closeTo(60, 0.5));
      limiter.configure(targetFps: 120, vsync: true);
      expect(limiter.effectiveFrameRate, closeTo(60, 0.5));
    });
  });
}
