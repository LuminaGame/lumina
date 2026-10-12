part of '../pie_controller.dart';

/// Play's keyboard and mouse input: the hardware key handler and the
/// injected key, mouse, axis and pointer events the running world receives.
mixin _PieGameInput {
  // Provided by PieController.
  EditorViewModel get viewModel;
  EditorPieGame? get _game;
  bool get isPlaying;
  bool get isPaused;
  bool get isEjected;
  PieMouseCapture get mouseCapture;

  bool _keyboardHandlerInstalled = false;

  /// Takes the keyboard for the running game.
  ///
  /// This is deliberately not routed through the viewport's focus node: the
  /// editor's focus can sit on any panel when the user presses Play, and a
  /// running game that ignores W because a tree view has focus is not playing.
  /// Every keyboard key reaches the game through the engine's one key table
  /// (`LuminaKey.fromKeyId`) — the same the project input
  /// binder and a shipped game's `main.dart` use. Only the keys the project's
  /// mapping contexts bind are swallowed, and only while the session accepts
  /// input, so editor shortcuts (Alt+P) and Stop keep working.
  bool _onHardwareKey(KeyEvent event) {
    // While the game has the mouse, F4 gives the cursor back and
    // Esc stops Play, wherever keyboard focus sits. Once released, Esc still
    // stops Play through the editor shell's `shell.cancel`. A game whose
    // input binds Escape (a pause or options menu) gets Esc instead, captured
    // or not, and Shift+Esc stops Play.
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      if (event is! KeyDownEvent || !mouseCapture.isCaptured) return false;
      mouseCapture.release();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (gameBindsEscape) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          if (event is! KeyDownEvent) return false;
          viewModel.stopSimulation();
          return true;
        }
        // Falls through: the game's Escape, like any bound key.
      } else {
        if (event is! KeyDownEvent || !isPlaying || !mouseCapture.isCaptured) return false;
        viewModel.stopSimulation();
        return true;
      }
    }
    final key = LuminaKey.fromKeyId(event.logicalKey.keyId);
    if (key == null) return false;
    if (event is KeyDownEvent) {
      if (!acceptsGameInput) return false;
      injectKeyDown(key);
    } else if (event is KeyUpEvent) {
      injectKeyUp(key);
    } else if (event is! KeyRepeatEvent) {
      return false;
    }
    return acceptsGameInput && (_game?.bindsKey(key) ?? false);
  }

  /// Whether the running game's mapping contexts bind Escape: Esc is then the
  /// game's key and Shift+Esc stops Play.
  bool get gameBindsEscape => isPlaying && (_game?.bindsKey(LuminaKey.keyEscape) ?? false);

  /// Feeds [event] to the keyboard handler Play installs (widget tests).
  bool handleKeyEventForTest(KeyEvent event) => _onHardwareKey(event);

  void _installKeyboardHandler() {
    if (_keyboardHandlerInstalled) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _keyboardHandlerInstalled = true;
  }

  void _removeKeyboardHandler() {
    if (!_keyboardHandlerInstalled) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _keyboardHandlerInstalled = false;
  }

  /// Whether the running world should receive keyboard and mouse events.
  /// An ejected user drives the editor flycam instead of the pawn.
  bool get acceptsGameInput => isPlaying && !isPaused && !isEjected;

  /// Whether scripted input (an agent's play-test) reaches
  /// the world: as [acceptsGameInput], but a paused world takes it too, and
  /// the next [step] sees it — frame-exact testing presses keys while paused.
  bool get acceptsScriptedInput => isPlaying && !isEjected;

  /// A key press; [scripted] input also lands while paused
  /// ([acceptsScriptedInput]).
  void injectKeyDown(LuminaKey key, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectKeyDown(key);
  }

  void injectKeyUp(LuminaKey key) {
    // A release is always forwarded, even after an eject, so a key held at the
    // moment of ejecting does not stay stuck down in the world.
    _game?.injectKeyUp(key);
  }

  void injectMouseDelta(double dx, double dy, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectMouseDelta(dx, dy);
  }

  /// An analog axis value (`MouseX`, `GamepadLeftStickX`, …) for the next
  /// tick, beside [injectMouseDelta] (the MCP server's `pie_axis`).
  void injectAnalog(LuminaKey key, double value, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectAnalog(key, value);
  }

  /// A delta from Flutter's own pointer events (the viewport's hover/move,
  /// the window shield): the game's mouse look only while the game has the
  /// mouse, and only when the capture backend does not report relative
  /// motion itself.
  void injectPointerDelta(double dx, double dy) {
    if (!mouseCapture.acceptsPointerDeltas) return;
    injectMouseDelta(dx, dy);
  }
}
