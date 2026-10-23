import 'dart:async';

/// One section of UI-isolate work that took longer than the audit's threshold.
class FilamentStall {
  const FilamentStall(this.name, this.duration, this.at);

  /// The section's name (`sub-editor scene setup`, `level grid rebuild`, …).
  final String name;

  /// Wall time the section held the calling isolate.
  final Duration duration;

  /// When the section ended.
  final DateTime at;

  @override
  String toString() => '$name took ${duration.inMicroseconds / 1000.0} ms';
}

/// Measures named sections of engine work on the calling isolate and reports
/// the ones longer than [threshold], so an editor can show where a frame
/// went. A section is any synchronous or asynchronous body: a scene setup, a
/// GPU wait a caller still needs, a readback. The last [capacity] stalls stay
/// in [recent]; every stall is also sent to [stalls].
abstract final class FilamentStallAudit {
  /// A section longer than this is a stall (half a frame at 60 Hz).
  static Duration threshold = const Duration(milliseconds: 8);

  /// How many stalls [recent] keeps.
  static const int capacity = 64;

  static final List<FilamentStall> _recent = [];
  static final StreamController<FilamentStall> _controller = StreamController<FilamentStall>.broadcast();

  /// The most recent stalls, oldest first.
  static List<FilamentStall> get recent => List.unmodifiable(_recent);

  /// Every stall as it is recorded.
  static Stream<FilamentStall> get stalls => _controller.stream;

  /// Runs [body] as the section [name], recording it when it exceeds [threshold].
  static T section<T>(String name, T Function() body) {
    final clock = Stopwatch()..start();
    try {
      return body();
    } finally {
      _record(name, clock.elapsed);
    }
  }

  /// [section] for an asynchronous body: the time measured is the body's
  /// own isolate time plus whatever it awaited, so a section that awaits a
  /// slow upload is reported as a stall of that length even though the
  /// isolate was free meanwhile; name such sections after what they wait for.
  static Future<T> sectionAsync<T>(String name, Future<T> Function() body) async {
    final clock = Stopwatch()..start();
    try {
      return await body();
    } finally {
      _record(name, clock.elapsed);
    }
  }

  /// Records a section measured by the caller.
  static void record(String name, Duration duration) => _record(name, duration);

  /// Forgets the recorded stalls (tests).
  static void clear() => _recent.clear();

  static void _record(String name, Duration duration) {
    if (duration < threshold) return;
    final stall = FilamentStall(name, duration, DateTime.now());
    _recent.add(stall);
    if (_recent.length > capacity) _recent.removeAt(0);
    if (_controller.hasListener) _controller.add(stall);
  }
}
