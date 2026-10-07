import 'package:flutter/foundation.dart';

import 'package:lumina/src/controller/controller.dart';
import 'package:lumina/src/controller/player_state.dart';
import 'package:lumina/src/game/player_camera_manager.dart';

/// Player controller that handles human player input and state.
class LuminaPlayerController extends LuminaController {
  final LuminaPlayerState playerState;
  late final LuminaPlayerCameraManager cameraManager;

  bool bShowMouseCursor = false;
  String inputMode = 'GameOnly';

  final _CursorStateNotifier _cursorState = _CursorStateNotifier();

  /// Notified whenever [bShowMouseCursor] or [inputMode] changes through the
  /// setters: Play-In-Editor and the built game follow it to
  /// capture or free the pointer.
  Listenable get cursorState => _cursorState;

  /// The game wants a free, visible pointer: the cursor is shown, or input
  /// goes to the UI (UI Only / Game and UI).
  bool get wantsFreeCursor => bShowMouseCursor || inputMode != 'GameOnly';

  void _setCursorState({bool? show, String? mode}) {
    final changed = (show != null && show != bShowMouseCursor) || (mode != null && mode != inputMode);
    if (show != null) bShowMouseCursor = show;
    if (mode != null) inputMode = mode;
    if (changed) _cursorState.changed();
  }

  LuminaPlayerController({
    String playerName = 'Player',
    int? playerId,
    double score = 0.0,
    int teamId = 0,
    double health = 100.0,
    LuminaPlayerState? playerState,
  }) : playerState = playerState ??
            LuminaPlayerState(
              playerName: playerName,
              playerId: playerId,
              score: score,
              teamId: teamId,
              health: health,
            ) {
    cameraManager = LuminaPlayerCameraManager(this);
  }

  void setShowMouseCursor(bool show) {
    _setCursorState(show: show);
  }

  void setInputModeGameOnly() {
    _setCursorState(mode: 'GameOnly');
  }

  void setInputModeUIOnly({Object? widgetToFocus, bool lockMouseToViewport = false}) {
    _setCursorState(mode: 'UIOnly');
  }

  void setInputModeGameAndUI({Object? widgetToFocus, bool lockMouseToViewport = false}) {
    _setCursorState(mode: 'GameAndUI');
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (pawn != null) {
      // Clamp pitch to [-89.9, 89.9] degrees
      controlRotation.x = controlRotation.x.clamp(-89.9, 89.9);
      pawn!.faceRotation(controlRotation, deltaTime);
    }
    cameraManager.updateCamera(deltaTime);
  }
}

class _CursorStateNotifier extends ChangeNotifier {
  void changed() => notifyListeners();
}
