import 'package:vector_math/vector_math_64.dart';

/// How a timeline key reaches the next one.
enum LuminaTimelineInterp { linear, cubic, constant }

/// One key of a timeline track: a time and a float, vector `[x, y, z]` or
/// colour `[r, g, b, a]` value.
class LuminaTimelineKey {
  final double time;
  final List<double> value;
  final LuminaTimelineInterp interp;

  const LuminaTimelineKey(this.time, this.value, [this.interp = LuminaTimelineInterp.linear]);

  Map<String, dynamic> toJson() => {
        'time': time,
        'value': value.length == 1 ? value.single : value,
        'interp': interp.name,
      };

  factory LuminaTimelineKey.fromJson(Map<String, dynamic> map) {
    final v = map['value'];
    return LuminaTimelineKey(
      (map['time'] as num?)?.toDouble() ?? 0.0,
      v is List ? [for (final n in v) (n as num).toDouble()] : [(v as num?)?.toDouble() ?? 0.0],
      LuminaTimelineInterp.values.firstWhere((i) => i.name == map['interp'], orElse: () => LuminaTimelineInterp.linear),
    );
  }
}

/// A named curve of a timeline: `float`, `vector` or `color` keys evaluated
/// with linear, cubic (Catmull-Rom) or constant interpolation; held at the
/// first / last key outside the range.
class LuminaTimelineTrack {
  final String name;
  final String type;
  final List<LuminaTimelineKey> keys;

  LuminaTimelineTrack({required this.name, this.type = 'float', List<LuminaTimelineKey> keys = const []})
      : keys = List.of(keys)..sort((a, b) => a.time.compareTo(b.time));

  int get _width => switch (type) { 'vector' => 3, 'color' => 4, _ => 1 };

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'keys': keys.map((k) => k.toJson()).toList()};

  factory LuminaTimelineTrack.fromJson(Map<dynamic, dynamic> map) => LuminaTimelineTrack(
        name: '${map['name'] ?? ''}',
        type: '${map['type'] ?? 'float'}',
        keys: [for (final k in map['keys'] as List? ?? const []) LuminaTimelineKey.fromJson(Map<String, dynamic>.from(k as Map))],
      );

  /// The value at [t] as the pin carries it: a `double`, a `Vector3` or a
  /// colour `[r, g, b, a]`.
  Object evaluate(double t) {
    final v = evaluateComponents(t);
    switch (type) {
      case 'vector':
        return Vector3(_at(v, 0), _at(v, 1), _at(v, 2));
      case 'color':
        return <double>[_at(v, 0), _at(v, 1), _at(v, 2), v.length > 3 ? v[3] : 1.0];
      default:
        return _at(v, 0);
    }
  }

  static double _at(List<double> v, int i) => i < v.length ? v[i] : 0.0;

  /// The raw components at [t].
  List<double> evaluateComponents(double t) {
    final w = _width;
    if (keys.isEmpty) return List<double>.filled(w, 0.0);
    if (t <= keys.first.time || keys.length == 1) return _pad(keys.first.value, w);
    if (t >= keys.last.time) return _pad(keys.last.value, w);
    var i = 0;
    while (i < keys.length - 1 && keys[i + 1].time <= t) {
      i++;
    }
    final a = keys[i], b = keys[i + 1];
    final span = b.time - a.time;
    final alpha = span <= 0 ? 1.0 : (t - a.time) / span;
    switch (a.interp) {
      case LuminaTimelineInterp.constant:
        return _pad(a.value, w);
      case LuminaTimelineInterp.linear:
        return [for (var c = 0; c < w; c++) _at(a.value, c) + (_at(b.value, c) - _at(a.value, c)) * alpha];
      case LuminaTimelineInterp.cubic:
        final p0 = i > 0 ? keys[i - 1] : a;
        final p3 = i + 2 < keys.length ? keys[i + 2] : b;
        return [for (var c = 0; c < w; c++) _catmullRom(_at(p0.value, c), _at(a.value, c), _at(b.value, c), _at(p3.value, c), alpha)];
    }
  }

  static List<double> _pad(List<double> v, int w) => [for (var c = 0; c < w; c++) _at(v, c)];

  static double _catmullRom(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t, t3 = t2 * t;
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}

/// A running Timeline node: a position between 0 and
/// [length] advanced forward or backward while playing, the tracks it
/// evaluates, and the Update / Finished callbacks the owner re-enters its
/// graph through. Shared by the VM and generated code.
class LuminaTimeline {
  final String name;
  double length;
  bool loop;
  final List<LuminaTimelineTrack> tracks;

  double _position = 0.0;
  bool _playing = false;
  bool _reverse = false;

  /// Runs after every advance while playing, with the track values.
  void Function()? onUpdate;

  /// Runs when the position reaches the end (or the start, in reverse).
  void Function()? onFinished;

  LuminaTimeline({required this.name, this.length = 1.0, this.loop = false, List<LuminaTimelineTrack>? tracks, bool autoPlay = false})
      : tracks = tracks ?? [] {
    if (autoPlay) play();
  }

  /// Builds one from a Timeline node's literals (`name`, `length`, `loop`,
  /// `auto_play`, `tracks`).
  factory LuminaTimeline.fromLiterals(Map<String, dynamic> literals, {String? name}) => LuminaTimeline(
        name: name ?? literals['name'] as String? ?? 'Timeline',
        length: (literals['length'] as num?)?.toDouble() ?? 1.0,
        loop: literals['loop'] == true,
        autoPlay: literals['auto_play'] == true || literals['autoPlay'] == true,
        tracks: [for (final t in literals['tracks'] as List? ?? const []) if (t is Map) LuminaTimelineTrack.fromJson(t)],
      );

  double get position => _position;
  bool get isPlaying => _playing;
  bool get isReversing => _reverse;

  /// `Forward` or `Backward`: the Direction output.
  String get direction => _reverse ? 'Backward' : 'Forward';

  void play() {
    _reverse = false;
    _playing = true;
  }

  void playFromStart() {
    _position = 0.0;
    play();
  }

  void stop() => _playing = false;

  void reverse() {
    _reverse = true;
    _playing = true;
  }

  void reverseFromStart() {
    _position = length;
    reverse();
  }

  void setNewTime(double t) => _position = t.clamp(0.0, length < 0 ? 0.0 : length);

  /// The track values at the current position, by track name.
  Map<String, Object?> values() => {for (final t in tracks) t.name: t.evaluate(_position)};

  /// Advances [dt] seconds when playing; runs [onUpdate] once and
  /// [onFinished] when the end is reached (a looping timeline wraps and
  /// keeps playing).
  void advance(double dt) {
    if (!_playing || dt <= 0.0) return;
    var finished = false;
    if (_reverse) {
      _position -= dt;
      if (_position <= 1e-9) {
        finished = true;
        _position = loop && length > 0 ? (_position + length).clamp(0.0, length) : 0.0;
      }
    } else {
      _position += dt;
      if (_position >= length - 1e-9) {
        finished = true;
        _position = loop && length > 0 ? (_position - length).clamp(0.0, length) : length;
      }
    }
    if (finished && !loop) _playing = false;
    onUpdate?.call();
    if (finished) onFinished?.call();
  }
}
