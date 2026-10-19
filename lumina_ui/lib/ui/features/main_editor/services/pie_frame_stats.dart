import 'package:flutter/scheduler.dart';

/// Where a Play-In-Editor frame's time goes, averaged over the last
/// [window] frames: the game tick on the UI thread, and the editor's Flutter
/// frames (build on the UI thread, raster on the raster thread, and the span
/// from vsync to raster end). `pie_status` reports it.
class PieFrameStats {
  PieFrameStats({this.window = 60});

  final int window;
  final List<int> _tickUs = [];
  final List<int> _buildUs = [];
  final List<int> _rasterUs = [];
  final List<int> _totalUs = [];
  final List<int> _intervalUs = [];
  int _lastTickStartUs = 0;
  bool _listening = false;

  /// Starts collecting (Play started).
  void start() {
    reset();
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Stops collecting (Play stopped); the last averages stay readable.
  void stop() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void reset() {
    for (final l in [_tickUs, _buildUs, _rasterUs, _totalUs, _intervalUs]) {
      l.clear();
    }
    _lastTickStartUs = 0;
  }

  /// One game tick that started at [startUs] (microseconds, any monotonic
  /// clock) and took [us].
  void addTick(int startUs, int us) {
    if (_lastTickStartUs > 0) _push(_intervalUs, startUs - _lastTickStartUs);
    _lastTickStartUs = startUs;
    _push(_tickUs, us);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _push(_buildUs, t.buildDuration.inMicroseconds);
      _push(_rasterUs, t.rasterDuration.inMicroseconds);
      _push(_totalUs, t.totalSpan.inMicroseconds);
    }
  }

  void _push(List<int> l, int v) {
    l.add(v);
    if (l.length > window) l.removeAt(0);
  }

  static double? _avgMs(List<int> l) => l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length / 1000.0;
  static double? _maxMs(List<int> l) => l.isEmpty ? null : l.reduce((a, b) => a > b ? a : b) / 1000.0;

  double? get gameTickMs => _avgMs(_tickUs);
  double? get tickIntervalMs => _avgMs(_intervalUs);

  Map<String, Object?> toJson() {
    double? r(double? v) => v == null ? null : double.parse(v.toStringAsFixed(2));
    final interval = tickIntervalMs;
    return {
      'game_fps': interval == null || interval <= 0 ? null : r(1000.0 / interval),
      'tick_interval_ms': r(interval),
      'tick_interval_max_ms': r(_maxMs(_intervalUs)),
      'game_tick_ms': r(gameTickMs),
      'game_tick_max_ms': r(_maxMs(_tickUs)),
      'flutter_build_ms': r(_avgMs(_buildUs)),
      'flutter_raster_ms': r(_avgMs(_rasterUs)),
      'flutter_frame_span_ms': r(_avgMs(_totalUs)),
      'frames': _tickUs.length,
    };
  }
}
