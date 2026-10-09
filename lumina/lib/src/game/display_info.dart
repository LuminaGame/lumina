/// What a game knows about the displays it runs on: the monitors, the modes
/// each one offers and the window's client area, all in physical pixels.
/// The generated runner's `lumina/game_window` channel reports them
/// (`getDisplays`); [LuminaDisplayInfo.fromMap] reads that answer.
library;

/// A rectangle in physical pixels on the virtual desktop.
typedef LuminaScreenRect = ({int left, int top, int right, int bottom});

/// One display mode: a resolution in physical pixels and a refresh rate in
/// hertz (0 when the platform does not say).
class LuminaDisplayMode {
  const LuminaDisplayMode(this.width, this.height, [this.refreshRate = 0]);

  final int width;
  final int height;
  final int refreshRate;

  /// `[width, height, refreshRate]`, the wire format.
  List<int> toList() => [width, height, refreshRate];

  /// A `[width, height]` or `[width, height, refreshRate]` list; null for
  /// anything else.
  static LuminaDisplayMode? fromList(Object? value) {
    if (value is! List || value.length < 2) return null;
    final w = value[0], h = value[1];
    if (w is! num || h is! num || w <= 0 || h <= 0) return null;
    final hz = value.length > 2 && value[2] is num ? (value[2] as num).round() : 0;
    return LuminaDisplayMode(w.round(), h.round(), hz < 0 ? 0 : hz);
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaDisplayMode && other.width == width && other.height == height && other.refreshRate == refreshRate;

  @override
  int get hashCode => Object.hash(width, height, refreshRate);

  @override
  String toString() => '${width}x$height@$refreshRate';
}

/// One monitor.
class LuminaMonitor {
  const LuminaMonitor({
    required this.index,
    required this.name,
    this.device = '',
    this.primary = false,
    required this.bounds,
    LuminaScreenRect? workArea,
    required this.current,
    this.modes = const [],
    this.scale = 1.0,
  }) : workArea = workArea ?? bounds;

  /// Position in [LuminaDisplayInfo.monitors].
  final int index;

  /// What the player sees in a menu (the monitor's model, e.g. `DELL U3419W`).
  final String name;

  /// The platform's id for it (`\\.\DISPLAY1` on Windows, the connector on
  /// Linux), used to find the same monitor again after a restart.
  final String device;

  final bool primary;

  /// The whole monitor on the virtual desktop.
  final LuminaScreenRect bounds;

  /// The part windows may use (without the taskbar or panels).
  final LuminaScreenRect workArea;

  /// The mode the desktop runs at.
  final LuminaDisplayMode current;

  /// Every mode the monitor offers (the current one when the platform cannot
  /// list them).
  final List<LuminaDisplayMode> modes;

  /// The desktop scale (device pixels per logical pixel).
  final double scale;

  int get width => bounds.right - bounds.left;
  int get height => bounds.bottom - bounds.top;

  /// The distinct resolutions of [modes] (the current one included), by
  /// width then height, ascending.
  List<(int, int)> get resolutions {
    final seen = <(int, int)>{(current.width, current.height)};
    for (final m in modes) {
      seen.add((m.width, m.height));
    }
    return seen.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  }

  /// The refresh rates [modes] offer at [width]×[height], ascending; empty
  /// for a resolution the monitor does not have.
  List<int> refreshRatesFor(int width, int height) {
    final rates = <int>{
      if (current.width == width && current.height == height && current.refreshRate > 0) current.refreshRate,
      for (final m in modes)
        if (m.width == width && m.height == height && m.refreshRate > 0) m.refreshRate,
    };
    return rates.toList()..sort();
  }

  static LuminaScreenRect? _rect(Object? value) {
    if (value is! List || value.length < 4 || value.any((v) => v is! num)) return null;
    final v = [for (final n in value) (n as num).round()];
    return (left: v[0], top: v[1], right: v[2], bottom: v[3]);
  }

  static List<int> _rectList(LuminaScreenRect r) => [r.left, r.top, r.right, r.bottom];

  /// The runner's description of monitor [index]; null when it has no
  /// usable bounds or current mode.
  static LuminaMonitor? fromMap(int index, Map<Object?, Object?> map) {
    final bounds = _rect(map['bounds']);
    if (bounds == null) return null;
    final current = LuminaDisplayMode.fromList(map['current']) ??
        LuminaDisplayMode(bounds.right - bounds.left, bounds.bottom - bounds.top);
    final modes = <LuminaDisplayMode>[
      for (final m in (map['modes'] is List ? map['modes'] as List : const []))
        ?LuminaDisplayMode.fromList(m),
    ];
    final name = map['name'];
    final device = map['device'];
    final scale = map['scale'];
    return LuminaMonitor(
      index: index,
      name: name is String && name.isNotEmpty ? name : 'Monitor ${index + 1}',
      device: device is String ? device : '',
      primary: map['primary'] == true,
      bounds: bounds,
      workArea: _rect(map['work']),
      current: current,
      modes: modes,
      scale: scale is num && scale > 0 ? scale.toDouble() : 1.0,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'device': device,
        'primary': primary,
        'bounds': _rectList(bounds),
        'work': _rectList(workArea),
        'current': current.toList(),
        'modes': [for (final m in modes) m.toList()],
        'scale': scale,
      };
}

/// The monitors, the one the game window is on, and the window's client
/// area.
class LuminaDisplayInfo {
  const LuminaDisplayInfo({required this.monitors, this.currentMonitor = 0, this.clientSize});

  final List<LuminaMonitor> monitors;

  /// Index into [monitors] of the monitor the game window is on.
  final int currentMonitor;

  /// The window's client area in physical pixels; null when unknown.
  final (int, int)? clientSize;

  /// The monitor the game is on; null without monitors.
  LuminaMonitor? get current =>
      monitors.isEmpty ? null : monitors[currentMonitor.clamp(0, monitors.length - 1)];

  /// The runner's `getDisplays` answer: `monitors` (see
  /// [LuminaMonitor.fromMap]), `current` and `client` `[w, h]`. Null when it
  /// lists no usable monitor.
  static LuminaDisplayInfo? fromMap(Map<Object?, Object?> map) {
    final raw = map['monitors'];
    final monitors = <LuminaMonitor>[];
    if (raw is List) {
      for (final m in raw) {
        if (m is Map) {
          final monitor = LuminaMonitor.fromMap(monitors.length, m);
          if (monitor != null) monitors.add(monitor);
        }
      }
    }
    if (monitors.isEmpty) return null;
    final current = map['current'];
    final client = LuminaDisplayMode.fromList(map['client']);
    return LuminaDisplayInfo(
      monitors: monitors,
      currentMonitor: current is num ? current.round().clamp(0, monitors.length - 1) : 0,
      clientSize: client == null ? null : (client.width, client.height),
    );
  }

  Map<String, Object?> toMap() => {
        'monitors': [for (final m in monitors) m.toMap()],
        'current': currentMonitor,
        if (clientSize case final c?) 'client': [c.$1, c.$2],
      };
}
