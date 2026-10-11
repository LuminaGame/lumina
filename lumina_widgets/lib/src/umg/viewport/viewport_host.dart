import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina_runtime.dart' show LuminaViewportBudget, LuminaViewportScope;

/// A Viewport drawn into the game's own frame (the Direct path): its view,
/// where it sits in the window (physical pixels, top-left origin) and the
/// per-frame step that advances its preview.
class LuminaViewportDirectView {
  LuminaViewportDirectView({required this.view, required this.rect, required this.frame, this.overlay});

  final FilamentView view;

  /// The Viewport's overlay view (its overlay lines), drawn right after
  /// [view] at the same rectangle; null while it shows none.
  FilamentView? Function()? overlay;

  /// The Viewport's rectangle in the window, physical pixels, top-left
  /// origin; null while it has no layout.
  Rect? Function() rect;

  /// Advances the preview by `dt` seconds (it renders with the game's frame).
  void Function(double dt) frame;
}

/// What a game publishes to the UMG Viewports in its HUD: the engine they
/// share, whether the game presents directly, the views drawn into its frame
/// on that path, and the game's Viewport budget.
///
/// [LuminaGameWidget] owns one and passes [frameViews] to its
/// `FilamentWidget`, so every Viewport view registered here renders after
/// the game's view, before the UI overlay, within the same GPU frame.
class LuminaViewportHost extends ChangeNotifier {
  LuminaViewportHost({LuminaViewportBudget? budget})
      : budget = budget ?? LuminaViewportBudget(scope: kIsWeb ? LuminaViewportScope.web : LuminaViewportScope.game);

  /// The game's Viewport budget (4 in a game, 2 on the web).
  final LuminaViewportBudget budget;

  FilamentEngine? _engine;
  bool _direct = false;

  /// The engine the game renders with, once its scene exists.
  FilamentEngine? get engine => _engine;
  set engine(FilamentEngine? value) {
    if (identical(value, _engine)) return;
    _engine = value;
    notifyListeners();
  }

  /// Whether the game presents through Filament (the Direct path) now.
  bool get presentingDirectly => _direct;
  set presentingDirectly(bool value) {
    if (value == _direct) return;
    _direct = value;
    notifyListeners();
  }

  final List<LuminaViewportDirectView> _views = [];

  /// The Viewport views drawn into the game's frame.
  List<LuminaViewportDirectView> get directViews => List.unmodifiable(_views);

  void register(LuminaViewportDirectView view) {
    if (!_views.contains(view)) _views.add(view);
  }

  void unregister(LuminaViewportDirectView view) => _views.remove(view);

  /// The window's height in physical pixels (the Direct swap chain's).
  double windowHeight = 0.0;

  int _lastMicros = -1;

  /// The views of one game frame: the game's own [defaultView] (and the
  /// extra views of [inner]) first, then every registered Viewport at its
  /// window rectangle, converted to Filament's bottom-left origin.
  List<FilamentView> frameViews(FilamentView defaultView, int width, int height, [FilamentFrameViewsCallback? inner]) {
    final base = inner?.call(defaultView, width, height);
    final views = <FilamentView>[if (base == null || base.isEmpty) defaultView else ...base];
    if (_views.isEmpty) return views;
    final now = DateTime.now().microsecondsSinceEpoch;
    final dt = _lastMicros < 0 ? 1 / 60 : math.min(0.25, (now - _lastMicros) / 1e6);
    _lastMicros = now;
    final surfaceHeight = windowHeight > 0 ? windowHeight : height.toDouble();
    for (final v in _views) {
      final r = v.rect();
      if (r == null || r.width < 1 || r.height < 1) continue;
      v.frame(dt);
      final left = r.left.round();
      final top = r.top.round();
      final w = r.width.round();
      final h = r.height.round();
      v.view.setViewport(left, (surfaceHeight - top - h).round(), w, h);
      views.add(v.view);
      final overlay = v.overlay?.call();
      if (overlay != null) {
        overlay.setViewport(left, (surfaceHeight - top - h).round(), w, h);
        views.add(overlay);
      }
    }
    return views;
  }
}

/// Makes the game's [LuminaViewportHost] available to the Viewports in its
/// HUD.
class LuminaViewportHostScope extends InheritedNotifier<LuminaViewportHost> {
  const LuminaViewportHostScope({super.key, required LuminaViewportHost host, required super.child}) : super(notifier: host);

  /// The host of the game above [context], or null (the editor, a designer
  /// preview).
  static LuminaViewportHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LuminaViewportHostScope>()?.notifier;
}
