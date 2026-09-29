import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';

/// Play-In-Editor's hold on the mouse: Play gives
/// the game the mouse (hidden and captured), F4 gives the cursor back, a
/// click on the game view takes it again.
///
/// Two things decide whether the pointer is captured:
/// - the user's intent, [wantsCapture]: set by Play and by a click, cleared by
///   F4 and by a [MouseCaptureLost] (focus went elsewhere);
/// - whether the game takes input at all: a paused or ejected session gives
///   the pointer back, and takes it again on resume or possess unless the
///   user pressed F4.
///
/// Every change of the result is sent to [LuminaMouseCapture.backend], which
/// is a recording backend under tests, smokes and `LUMINA_MOUSE_CAPTURE=off`.
class PieMouseCapture extends ChangeNotifier {
  PieMouseCapture({
    required this._gameAcceptsInput,
    required this._onMotion,
    bool Function()? gameWantsFreeCursor,
    MouseCaptureBackend Function()? backend,
  })  : _gameWantsFreeCursor = gameWantsFreeCursor ?? (() => false),
        _backendOf = backend ?? (() => LuminaMouseCapture.backend);

  final bool Function() _gameAcceptsInput;

  /// The game itself asked for a free, visible pointer: Set Show Mouse
  /// Cursor, or a UI input mode on the possessed controller.
  /// It keeps taking keyboard input; only the pointer is given back.
  final bool Function() _gameWantsFreeCursor;
  final void Function(double dx, double dy) _onMotion;
  final MouseCaptureBackend Function() _backendOf;

  MouseCaptureBackend? _backend;
  StreamSubscription<MouseCaptureEvent>? _events;
  MouseCaptureSupport _support = MouseCaptureSupport.none;

  bool _session = false;
  bool _wants = false;
  bool _applied = false;
  bool _locked = false;
  int _hintEpoch = 0;

  /// The game view's centre in the Flutter view's coordinates, supplied by
  /// the viewport: where X11 parks the pointer, and where Wayland shows it
  /// again on release.
  Offset? Function()? centreProvider;

  /// Whether a Play session is running.
  bool get isSessionActive => _session;

  /// The user's intent: the game should have the mouse.
  bool get wantsCapture => _session && _wants;

  /// Whether the game has the mouse right now.
  bool get isCaptured => _session && _wants && _gameAcceptsInput() && !_gameWantsFreeCursor();

  /// F4 (or a lost capture) gave the cursor back while the game takes input:
  /// a click on the game view takes it again.
  bool get isReleased => _session && !_wants && _gameAcceptsInput();

  /// The cursor is hidden: over the game view, and window-wide when the
  /// backend really holds the pointer ([holdsPointer]).
  bool get hidesCursor => isCaptured;

  /// The backend holds the pointer in place, so clicks land wherever it was
  /// held: the editor shields its whole window while this is true.
  bool get holdsPointer => isCaptured && _support.pointerLock;

  /// Flutter's own pointer deltas turn the game's camera only while captured,
  /// and only when the backend does not report relative motion itself.
  bool get acceptsPointerDeltas => isCaptured && !_support.relativeMotion;

  /// The compositor confirmed the current capture.
  bool get isLocked => _locked && isCaptured;

  /// What the backend can do (unsupported until the first Play asked).
  MouseCaptureSupport get support => _support;

  /// Bumped at every Play: the viewport shows the F4 hint once per epoch.
  int get hintEpoch => _hintEpoch;

  /// Play started: the game takes the mouse.
  Future<void> begin() async {
    final backend = _backend ??= _backendOf();
    _events ??= backend.events.listen(_onEvent);
    _session = true;
    _wants = true;
    _hintEpoch++;
    _apply();
    notifyListeners();
    final support = await backend.support();
    if (!identical(backend, _backend)) return;
    _support = support;
    notifyListeners();
  }

  /// Play stopped: the pointer is always given back.
  void end() {
    if (!_session && !_applied) return;
    _session = false;
    _wants = false;
    _apply();
    unawaited(_events?.cancel());
    _events = null;
    _backend = null;
    notifyListeners();
  }

  /// F4: the cursor comes back and the editor can be used; the session keeps
  /// running.
  void release() {
    if (!_session || !_wants) return;
    _wants = false;
    _apply();
    notifyListeners();
  }

  /// A click on the game view: the game takes the mouse again.
  void recapture() {
    if (!_session || _wants) return;
    _wants = true;
    _apply();
    notifyListeners();
  }

  /// Re-reads whether the game takes input (pause, resume, eject, possess).
  void sync() {
    if (_apply()) notifyListeners();
  }

  /// Sends a change of [isCaptured] to the backend. Returns whether it
  /// changed.
  bool _apply() {
    final want = isCaptured;
    if (want == _applied) return false;
    _applied = want;
    _locked = false;
    final backend = _backend;
    if (backend == null) return true;
    if (want) {
      unawaited(backend.capture(centre: centreProvider?.call()));
    } else {
      unawaited(backend.release());
    }
    return true;
  }

  void _onEvent(MouseCaptureEvent event) {
    switch (event) {
      case MouseCaptureMotion(:final dx, :final dy):
        if (isCaptured) _onMotion(dx, dy);
      case MouseCaptureLocked():
        if (!_applied) return;
        _locked = true;
        notifyListeners();
      case MouseCaptureLost():
        // The platform already let go (Alt+Tab, another window): the cursor
        // is back, and a click takes it again.
        if (!_applied) return;
        _applied = false;
        _locked = false;
        _wants = false;
        notifyListeners();
    }
  }

  @override
  void dispose() {
    end();
    super.dispose();
  }
}
