import 'dart:ui' show Offset, Size;

import 'package:flutter/gestures.dart'
    show kBackMouseButton, kForwardMouseButton, kMiddleMouseButton, kPrimaryMouseButton, kSecondaryMouseButton;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaKey, LuminaRenderSpace;

/// The mouse of a Play-In-Editor session as the running game sees it, with
/// the rules a built game's `LuminaGameHost` follows:
/// - the pointer position (`Get Mouse Position`) in the PIE view's pixels,
///   the space of `Get Viewport Size` and the screen projections
///   ([LuminaRenderSpace] over the game view's box; the view renders the
///   viewport's logical size, so the display's pixel ratio does not scale
///   it), clamped to the view's edge;
/// - mouse buttons as `LeftMouseButton` / `RightMouseButton` / … keys:
///   while the game holds the hidden, captured cursor, every click (also the
///   ones the window shield catches); with a free cursor (Set Show Mouse
///   Cursor, Game and UI) only clicks on the game view that the game's UMG
///   widgets do not take, none in Input Mode UI Only; after F4 the click that
///   takes the mouse again is not the game's;
/// - a release always reaches the game, and a session that stops taking
///   input (pause, eject, stop) releases what it pressed.
///
/// [PieController] owns one; the viewport supplies [viewSize] and
/// [devicePixelRatio], and forwards its pointer events.
class PiePointerInput {
  PiePointerInput({
    required this.acceptsGameInput,
    required this.gameHoldsCursor,
    required this.cursorReleased,
    required this.uiOnly,
    required this.injectPosition,
    required this.injectKeyDown,
    required this.injectKeyUp,
    required this.setViewportSize,
  });

  /// The session takes game input (playing, not paused, not ejected).
  final bool Function() acceptsGameInput;

  /// The game holds the hidden, captured cursor.
  final bool Function() gameHoldsCursor;

  /// F4 (or a lost capture) gave the cursor back: the next click on the game
  /// view takes the mouse again.
  final bool Function() cursorReleased;

  /// The possessed controller's input mode is UI Only.
  final bool Function() uiOnly;

  final void Function(double x, double y) injectPosition;
  final void Function(LuminaKey key) injectKeyDown;
  final void Function(LuminaKey key) injectKeyUp;

  /// Sets the running world's view size in pixels (`Get Viewport Size`).
  final void Function(int width, int height) setViewportSize;

  /// The game view's logical size, or null before it is laid out.
  Size? Function()? viewSize;

  /// The display's pixel ratio around the game view.
  double Function()? devicePixelRatio;

  static const Map<int, LuminaKey> _buttonKeys = {
    kPrimaryMouseButton: LuminaKey.mouseLeft,
    kSecondaryMouseButton: LuminaKey.mouseRight,
    kMiddleMouseButton: LuminaKey.mouseMiddle,
    kBackMouseButton: LuminaKey.mouseThumb1,
    kForwardMouseButton: LuminaKey.mouseThumb2,
  };

  // The mouse buttons this session pressed in the game, by Flutter button bit.
  final Map<int, LuminaKey> _pressed = {};

  /// The keys pressed in the game right now (tests).
  Iterable<LuminaKey> get pressedForTest => _pressed.values;

  /// The game's render space: the game view, rendering its logical size.
  LuminaRenderSpace? get renderSpace {
    final size = viewSize?.call();
    if (size == null || size.isEmpty) return null;
    return LuminaRenderSpace(space: size, devicePixelRatio: devicePixelRatio?.call() ?? 1.0, physicalPixels: false);
  }

  /// Keeps the world's view size on the PIE view (every tick: the
  /// viewport can be resized while playing).
  void syncViewportSize() {
    final space = renderSpace;
    if (space == null) return;
    final px = space.viewportPixels;
    setViewportSize(px.width.round(), px.height.round());
  }

  /// The pointer is at [local] in the game view.
  void hover(Offset local) {
    if (!acceptsGameInput()) return;
    final space = renderSpace;
    if (space == null) return;
    final p = space.clampToViewport(local);
    injectPosition(p.dx, p.dy);
  }

  /// A button change at [local] over the game view, a place the game's UI
  /// left to it ([buttons] is the event's button set).
  void viewButtons(Offset local, int buttons) {
    hover(local);
    final press = acceptsGameInput() && !cursorReleased() && (gameHoldsCursor() || !uiOnly());
    _sync(buttons, press: press);
  }

  /// A button change caught by the window shield while the game holds the
  /// cursor: the game's wherever it lands; [local] is in the game view.
  void heldButtons(Offset local, int buttons) {
    hover(local);
    _sync(buttons, press: acceptsGameInput() && gameHoldsCursor());
  }

  /// Releases every button this session pressed.
  void releaseAll() => _sync(0, press: false);

  void _sync(int buttons, {required bool press}) {
    for (final entry in _buttonKeys.entries) {
      final down = buttons & entry.key != 0;
      if (down && press && !_pressed.containsKey(entry.key)) {
        _pressed[entry.key] = entry.value;
        injectKeyDown(entry.value);
      } else if (!down && _pressed.containsKey(entry.key)) {
        injectKeyUp(_pressed.remove(entry.key)!);
      }
    }
  }
}
