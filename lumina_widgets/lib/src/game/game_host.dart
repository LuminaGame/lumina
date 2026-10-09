import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';

import 'package:lumina_widgets/src/game/lumina_widget.dart';
import 'package:lumina_widgets/src/umg/widget_layer.dart';

/// Creates the game that plays [levelName] (a generated game's
/// `MyGame(levelName: …)`).
typedef LuminaGameFactory = LuminaGame Function(String levelName);

/// A whole game screen: the [LuminaGameWidget] with the widgets its
/// Blueprints add to the viewport ([LuminaWidgetLayer]) on top, and the
/// Flutter input bridged into the running world's [LuminaInputSubsystem]:
/// - every keyboard key, through the engine's key table
///   ([LuminaKey.fromKeyId]);
/// - pointer motion as `MouseX` / `MouseY`, from the captured mouse's
///   relative motion ([LuminaMouseCapture]) or, uncaptured, from the
///   pointer's own deltas;
/// - mouse capture: taken at start and on a click, released while player 0's
///   controller wants a free cursor (Set Show Mouse Cursor, a UI input mode);
/// - Open Level / Change Level: a new game from [createGame] on that level,
///   after [LuminaLevelPreloader] preloaded it.
///
/// A generated game's `main()` shows one; its keys reach the pawn the
/// project's `Gameplay` mapping context binds.
class LuminaGameHost extends StatefulWidget {
  const LuminaGameHost({
    super.key,
    required this.createGame,
    required this.initialLevel,
    this.levelNames,
    this.targetFps = 0,
    this.vsyncEnabled = false,
    this.captureMouse = true,
  });

  /// Creates the game for a level name.
  final LuminaGameFactory createGame;

  /// The level the first game plays.
  final String initialLevel;

  /// The levels Change Level / Open Level accept; null accepts any name
  /// [createGame] takes.
  final Set<String>? levelNames;

  /// Forwarded to [LuminaGameWidget.targetFps].
  final int targetFps;

  /// Forwarded to [LuminaGameWidget.vsyncEnabled].
  final bool vsyncEnabled;

  /// Whether the host takes the mouse (pointer lock, hidden cursor). Off, the
  /// pointer's own deltas still turn the view.
  final bool captureMouse;

  @override
  State<LuminaGameHost> createState() => LuminaGameHostState();
}

/// The state of a [LuminaGameHost]: [game] is the running game.
class LuminaGameHostState extends State<LuminaGameHost> {
  late LuminaGame _game;
  final FocusNode _focusNode = FocusNode(debugLabel: 'LuminaGameHost');
  StreamSubscription<MouseCaptureEvent>? _mouseEvents;
  MouseCaptureSupport? _captureSupport;
  bool _isCaptured = false;
  bool _captureInFlight = false;
  // Whether a capture ever succeeded: until then the pointer arriving over
  // the game retries it.
  bool _hadLock = false;
  // Player 0's controller and whether it wants a free, visible pointer.
  LuminaPlayerController? _followedController;
  bool _freeCursor = false;

  /// The running game (a new one after each Change Level).
  LuminaGame get game => _game;

  /// Whether the pointer is free and visible (the game showed the cursor or
  /// gives input to its UI).
  bool get freeCursor => _freeCursor;

  LuminaInputSubsystem? get _input => _game.world?.getSubsystem<LuminaInputSubsystem>();

  @override
  void initState() {
    super.initState();
    _game = widget.createGame(widget.initialLevel);
    // Change Level swaps the game for a new one on that level, after the
    // tick that asked for it and after preloading it; Open Level (a Blueprint
    // node, or the console's `open`) is a Change Level nobody waits for.
    LuminaGame.onChangeLevelRequested = changeLevel;
    LuminaGame.onOpenLevelRequested = (levelName, options) => scheduleMicrotask(() => _openLevel(levelName));
    _initMouseCapture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _capture(_centre());
    });
    WidgetsBinding.instance.addPostFrameCallback(_followController);
  }

  /// After every frame: follow player 0's controller of the running game
  /// (it appears after BeginPlay, and Open Level brings a new one).
  void _followController(Duration _) {
    if (!mounted) return;
    final world = _game.world;
    final controller = world == null ? null : LuminaGameplayStatics.getPlayerController(world, playerIndex: 0);
    if (!identical(controller, _followedController)) {
      _followedController?.cursorState.removeListener(_onCursorState);
      _followedController = controller;
      controller?.cursorState.addListener(_onCursorState);
      _onCursorState();
    }
    WidgetsBinding.instance.addPostFrameCallback(_followController);
  }

  /// The game shows the cursor or gives input to its UI: the pointer is free
  /// and visible; when it hides the cursor again, the game takes it back.
  void _onCursorState() {
    final free = _followedController?.wantsFreeCursor ?? false;
    if (free == _freeCursor || !mounted) return;
    setState(() => _freeCursor = free);
    if (free) {
      _isCaptured = false;
      if (widget.captureMouse) LuminaMouseCapture.backend.release();
    } else {
      _capture(_centre());
    }
  }

  Future<void> _initMouseCapture() async {
    if (!widget.captureMouse) return;
    final backend = LuminaMouseCapture.backend;
    _mouseEvents = backend.events.listen((event) {
      if (event is MouseCaptureMotion) {
        final input = _input;
        if (input != null) {
          input.injectAnalog(LuminaKey.mouseX, event.dx);
          input.injectAnalog(LuminaKey.mouseY, event.dy);
        }
      } else if (event is MouseCaptureLocked) {
        _isCaptured = true;
        _hadLock = true;
      } else if (event is MouseCaptureLost) {
        _isCaptured = false;
      }
    });
    final support = await backend.support();
    if (mounted) _captureSupport = support;
  }

  void _openLevel(String levelName) {
    changeLevel(levelName).catchError((Object e) => debugPrint('Open Level: $e'));
  }

  /// Switches to [levelName] once it is preloaded (at once when Load Level
  /// preloaded it already); completes after the new level's BeginPlay.
  Future<void> changeLevel(String levelName) async {
    final names = widget.levelNames;
    if (names != null && !names.contains(levelName)) {
      throw StateError("Change Level: no level named '$levelName' in this game.");
    }
    await LuminaLevelPreloader.instance.changeLevel(levelName, () async {
      if (!mounted) throw StateError('Change Level: the game is closing.');
      final game = widget.createGame(levelName);
      setState(() => _game = game);
      while (mounted && !(game.world?.hasBegunPlay ?? false)) {
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  Offset? _centre() {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    return size != null ? Offset(size.width / 2, size.height / 2) : null;
  }

  /// Captures the pointer; a capture the platform refuses (on Wayland the
  /// window has no pointer until the pointer enters it) leaves the game
  /// uncaptured, so hover keeps turning the view and the next try can run.
  Future<void> _capture([Offset? centre]) async {
    if (!widget.captureMouse || _captureInFlight) return;
    _captureInFlight = true;
    try {
      final ok = await LuminaMouseCapture.backend.capture(centre: centre);
      if (!mounted) return;
      _isCaptured = ok;
      if (ok) _hadLock = true;
    } finally {
      _captureInFlight = false;
    }
  }

  /// Until one capture has succeeded, the pointer entering or moving over
  /// the game tries again; after a loss (focus went elsewhere) a click takes
  /// the pointer back.
  void _captureUntilFirstLock() {
    if (_hadLock || _captureInFlight || _freeCursor) return;
    _capture(_centre());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Every keyboard key, through the engine's one key table.
    final key = LuminaKey.fromKeyId(event.logicalKey.keyId);
    final input = _input;
    if (key == null || input == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      input.injectKeyDown(key);
    } else if (event is KeyUpEvent) {
      input.injectKeyUp(key);
    }
    return KeyEventResult.handled;
  }

  void _onPointerDelta(PointerEvent event) {
    _captureUntilFirstLock();
    // Captured with relative motion, the backend's deltas turn the view;
    // otherwise the pointer's own deltas do.
    if (_isCaptured && _captureSupport?.relativeMotion == true) return;
    final input = _input;
    if (input == null) return;
    input.injectAnalog(LuminaKey.mouseX, event.delta.dx);
    input.injectAnalog(LuminaKey.mouseY, event.delta.dy);
  }

  @override
  void dispose() {
    LuminaGame.onOpenLevelRequested = null;
    _followedController?.cursorState.removeListener(_onCursorState);
    LuminaGame.onChangeLevelRequested = null;
    _mouseEvents?.cancel();
    if (widget.captureMouse) LuminaMouseCapture.backend.release();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: MouseRegion(
        // The game owns the mouse: pointer lock and relative motion keep it
        // from escaping the window while turning.
        cursor: _freeCursor || !widget.captureMouse ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onEnter: (_) => _captureUntilFirstLock(),
        onHover: _onPointerDelta,
        child: Listener(
          onPointerDown: (event) {
            _focusNode.requestFocus();
            if (!_isCaptured && !_freeCursor) _capture(_centre());
          },
          onPointerMove: _onPointerDelta,
          // The widgets the game's Blueprints add to the viewport (Create
          // Widget → Add to Viewport) render above the 3D view. A new game
          // (Open Level) mounts a fresh 3D view and widget layer.
          child: KeyedSubtree(
            key: ObjectKey(_game),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LuminaGameWidget(
                  game: _game,
                  targetFps: widget.targetFps,
                  vsyncEnabled: widget.vsyncEnabled,
                  // A game screen: edge to edge, at the display's native
                  // resolution (fullscreen included).
                  decorated: false,
                  physicalResolution: true,
                  // The player's screen resolution (Set Screen Resolution).
                  followScreenResolution: true,
                ),
                LuminaWidgetLayer.forGame(game: _game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
