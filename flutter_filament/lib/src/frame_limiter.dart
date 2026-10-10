/// Decides, once per display refresh, whether a frame is rendered: the
/// target frame rate of a render loop that runs on the display's vsync
/// callback (a Flutter ticker, the browser's `requestAnimationFrame`).
///
/// A loop driven by vsync cannot render more often than the display
/// refreshes, so every target is capped by the [refreshRate], which the
/// limiter learns from the timestamps it is given (the mean of the last
/// refresh intervals near their median, so a skipped vsync does not count;
/// 60 Hz until it has seen a few).
///
/// - [targetFps] `0` (or less): every refresh.
/// - [vsync] `true`: every frame is shown for the same whole number of
///   refreshes, the smallest one that keeps the rate at or under the target
///   (60 Hz display: 30 FPS = every other refresh, 45 FPS also 30; 144 Hz:
///   60 FPS = every third refresh, 48). Frame times are even.
/// - [vsync] `false`: the average rate is the target; frames alternate
///   between neighbouring refresh counts when the target is not a divisor
///   of the refresh rate (60 Hz, 45 FPS: one and two refreshes).
class FilamentFrameLimiter {
  FilamentFrameLimiter({int targetFps = 0, bool vsync = true}) {
    configure(targetFps: targetFps, vsync: vsync);
  }

  static const int _samples = 30;
  static const double _defaultPeriodUs = 1e6 / 60;

  int _targetFps = 0;
  bool _vsync = true;
  final List<int> _intervals = [];
  double _periodUs = _defaultPeriodUs;
  int? _lastTickUs;
  double? _dueUs;
  bool _lastDecision = true;

  /// Target frame rate; 0 is every refresh.
  int get targetFps => _targetFps;

  /// Whether frames are held for whole, equal numbers of refreshes.
  bool get vsync => _vsync;

  /// The display refresh rate the limiter has learned, in Hz.
  double get refreshRate => 1e6 / _periodUs;

  /// The rate the limiter renders at with the current settings and
  /// [refreshRate].
  double get effectiveFrameRate {
    final refresh = refreshRate;
    if (_targetFps <= 0) return refresh;
    if (_vsync) return refresh / _refreshesPerFrame;
    return _targetFps < refresh ? _targetFps.toDouble() : refresh;
  }

  /// Refreshes each frame is held for with [vsync].
  int get _refreshesPerFrame {
    if (_targetFps <= 0) return 1;
    final n = ((1e6 / _targetFps) / _periodUs - 0.05).ceil();
    return n < 1 ? 1 : n;
  }

  /// Changes the target; the new cadence starts with the next frame.
  void configure({required int targetFps, required bool vsync}) {
    final fps = targetFps < 0 ? 0 : targetFps;
    if (fps == _targetFps && vsync == _vsync) return;
    _targetFps = fps;
    _vsync = vsync;
    _dueUs = null;
  }

  /// Forgets the cadence (not the learned refresh rate): the next call
  /// renders.
  void reset() => _dueUs = null;

  /// Called on every display refresh with its vsync [timestamp]; whether
  /// this refresh renders a frame. Asking again for the same timestamp gives
  /// the same answer, so the loops of one frame (a game's world tick and
  /// its widget's render) can share one limiter and agree.
  bool shouldRender(Duration timestamp) {
    final now = timestamp.inMicroseconds;
    if (now == _lastTickUs) return _lastDecision;
    _learn(now);
    return _lastDecision = _decide(now);
  }

  bool _decide(int now) {
    if (_targetFps <= 0) return true;
    final tolerance = _periodUs / 2;
    final due = _dueUs;
    if (due != null && now < due - tolerance) return false;
    if (_vsync) {
      _dueUs = now + _refreshesPerFrame * _periodUs;
    } else {
      final interval = 1e6 / _targetFps;
      var next = (due ?? now.toDouble()) + interval;
      // Fell behind (a hitch, or a target above the refresh rate): restart
      // the cadence from this frame instead of rendering a burst.
      if (next < now - tolerance) next = now + interval;
      _dueUs = next;
    }
    return true;
  }

  void _learn(int nowUs) {
    final last = _lastTickUs;
    _lastTickUs = nowUs;
    if (last == null) return;
    final delta = nowUs - last;
    // Not a refresh interval: a stopped ticker, a clock reset.
    if (delta <= 1000 || delta > 100000) return;
    _intervals.add(delta);
    if (_intervals.length > _samples) _intervals.removeAt(0);
    if (_intervals.length < 3) return;
    final sorted = [..._intervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    var sum = 0;
    var count = 0;
    for (final d in _intervals) {
      if ((d - median).abs() * 4 <= median) {
        sum += d;
        count++;
      }
    }
    _periodUs = sum / count;
  }
}
