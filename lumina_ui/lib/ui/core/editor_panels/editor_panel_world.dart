import 'dart:async';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaWorld, LuminaWorldType;

/// The private, headless world editor panel scripts live in: they are hidden
/// actors and need `self.world` for Delay, timers, timelines and Event Tick.
/// It has no scene, is never rendered or saved, holds no level actor (panels
/// reach those through the editor library's level proxy), and ticks only
/// while at least one editor panel is shown.
class EditorPanelWorld {
  EditorPanelWorld({this.interval = const Duration(milliseconds: 16)});

  final Duration interval;
  LuminaWorld? _world;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int ticks = 0;

  /// The world, created and begun on first use.
  LuminaWorld get world => _world ??= LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();

  bool get isTicking => _timer != null;

  /// Ticks the world while [active] is true (at least one panel shown).
  void setActive(bool active) {
    if (active == isTicking) return;
    if (!active) {
      _timer?.cancel();
      _timer = null;
      _clock.stop();
      return;
    }
    world;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  /// One tick with the time since the last one (capped so a stall never
  /// fires a burst of Delays at once).
  void tick() {
    final dt = (_clock.elapsedMicroseconds / 1e6).clamp(0.0, 0.1);
    _clock
      ..reset()
      ..start();
    ticks++;
    world.tick(dt == 0 ? interval.inMicroseconds / 1e6 : dt);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _world = null;
  }
}
