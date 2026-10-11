import 'dart:developer' as developer;
import 'dart:math' as math;

/// Where a Viewport runs, which sets how many may render at once.
enum LuminaViewportScope {
  /// A game (Play-In-Editor or a built game): 4 by default.
  game,

  /// An editor panel or the widget designer: 8.
  editor,

  /// A web build: 2 (each Viewport is a WebGL2 context of its own).
  web,
}

/// The render budget of the Viewport widget: the render size of one
/// Viewport, how many render at once, and their frame rate.
///
/// A Viewport that is Collapsed, Hidden, scrolled off screen, zero-sized or
/// in an inactive editor tab never asks for a slot; one that asks past the
/// limit is refused, shows a "Viewport limit reached" placeholder and the
/// refusal is logged once per limit.
class LuminaViewportBudget {
  LuminaViewportBudget({this.scope = LuminaViewportScope.game, int? maxViewports}) : _max = maxViewports;

  /// The budget Viewports of a running game or editor share.
  static LuminaViewportBudget shared = LuminaViewportBudget();

  /// The longest side a Viewport renders at, in pixels.
  static const int maxRenderSide = 2048;

  /// The render scale range (fraction of the layout size × device pixel
  /// ratio).
  static const double minRenderScale = 0.25;
  static const double maxRenderScale = 1.0;

  /// The project setting that sets the count limit (1–8).
  static const String maxViewportsSetting = 'umg.maxViewports';

  /// The project's `umg.maxViewports` (1–8), set by the generated game's
  /// `main()`, Play and the editor when a project opens; null keeps the
  /// scope's default. A budget with its own [maxViewports] ignores it.
  static int? projectMaxViewports;

  /// How long a Viewport keeps rendering after its last input, in seconds.
  static const double idleAfterSeconds = 1.0;

  /// The frame rate an editor panel Viewport renders at by default.
  static const int editorMaxFps = 60;

  final LuminaViewportScope scope;
  int? _max;

  /// The default limit of [scope]: 4 in a game, 8 in the editor, 2 on the web.
  static int defaultLimit(LuminaViewportScope scope) => switch (scope) {
        LuminaViewportScope.game => 4,
        LuminaViewportScope.editor => 8,
        LuminaViewportScope.web => 2,
      };

  /// How many Viewports may render at once: the project setting when set
  /// (1–8), never more than the web's 2 on the web.
  int get maxViewports {
    final project = projectMaxViewports;
    final limit = (_max ?? (project != null && project > 0 ? project : defaultLimit(scope))).clamp(1, 8);
    return scope == LuminaViewportScope.web ? math.min(limit, defaultLimit(LuminaViewportScope.web)) : limit;
  }

  set maxViewports(int? value) => _max = value;

  final List<Object> _holders = [];
  bool _logged = false;

  /// Lines the budget logged (the refusal), for tests and the Output Log.
  final List<String> log = [];

  /// The Viewports rendering now.
  int get activeCount => _holders.length;

  /// Whether [owner] holds a slot.
  bool holds(Object owner) => _holders.contains(owner);

  /// Asks a render slot for [owner]: true when it holds one (already, or
  /// now), false when the limit is reached (logged once until a slot frees).
  bool acquire(Object owner) {
    if (_holders.contains(owner)) return true;
    if (_holders.length >= maxViewports) {
      if (!_logged) {
        _logged = true;
        final line = 'Viewport limit reached: $maxViewports Viewports already render (${scope.name}); '
            'the others show a placeholder until one is hidden or removed.';
        log.add(line);
        developer.log(line, name: 'UMG', level: 900);
      }
      return false;
    }
    _holders.add(owner);
    return true;
  }

  /// Gives [owner]'s slot back (it was hidden, collapsed, scrolled away,
  /// zero-sized or removed).
  void release(Object owner) {
    if (_holders.remove(owner)) _logged = false;
  }

  /// Forgets every holder (a test, or the game ending).
  void reset() {
    _holders.clear();
    _logged = false;
    log.clear();
  }

  /// The render size of a Viewport laid out at [width] × [height] logical
  /// pixels: × [devicePixelRatio] × [renderScale] (clamped to 0.25–1), the
  /// long side clamped to [maxRenderSide] keeping the aspect; (0, 0) for an
  /// empty layout.
  static (int, int) renderSize(double width, double height, {double devicePixelRatio = 1.0, double renderScale = 1.0}) {
    if (!(width > 0) || !(height > 0)) return (0, 0);
    final scale = renderScale.clamp(minRenderScale, maxRenderScale) * devicePixelRatio;
    var w = width * scale;
    var h = height * scale;
    final long = math.max(w, h);
    if (long > maxRenderSide) {
      final k = maxRenderSide / long;
      w *= k;
      h *= k;
    }
    return (math.max(1, w.round()), math.max(1, h.round()));
  }

  /// Whether a Viewport with this state counts against the limit (and
  /// renders at all).
  static bool counts({required String visibility, required double width, required double height, bool onScreen = true, bool tabActive = true}) =>
      visibility != 'Collapsed' && visibility != 'Hidden' && width > 0 && height > 0 && onScreen && tabActive;
}

/// When an idle Viewport renders: a frame when something changed (the
/// description, the size, input), every frame while something moves on its
/// own (an animation plays, the camera auto-rotates) or input arrived in the
/// last second, and nothing otherwise.
class LuminaViewportFrameClock {
  LuminaViewportFrameClock({this.maxFps = 60});

  /// The frame rate cap (0: no cap).
  int maxFps;

  double _now = 0.0;
  double? _lastInput;
  double? _lastFrame;
  bool _dirty = true;

  /// Frames rendered so far.
  int framesRendered = 0;

  /// Something changed: render one frame.
  void markDirty() => _dirty = true;

  /// The player touched the Viewport: render for [LuminaViewportBudget.idleAfterSeconds].
  void input() {
    _lastInput = _now;
    _dirty = true;
  }

  /// Advances the clock by [dt] seconds; returns whether a frame renders
  /// now ([animating]: an animation plays or the camera auto-rotates).
  bool tick(double dt, {bool animating = false}) {
    _now += dt;
    final recentInput = _lastInput != null && _now - _lastInput! < LuminaViewportBudget.idleAfterSeconds;
    if (!_dirty && !animating && !recentInput) return false;
    if (maxFps > 0 && _lastFrame != null && _now - _lastFrame! < 1.0 / maxFps - 1e-6 && !_dirty) return false;
    _dirty = false;
    _lastFrame = _now;
    framesRendered++;
    return true;
  }

  /// Whether the Viewport is idle (renders nothing until something changes).
  bool idle({bool animating = false}) =>
      !_dirty && !animating && !(_lastInput != null && _now - _lastInput! < LuminaViewportBudget.idleAfterSeconds);
}
