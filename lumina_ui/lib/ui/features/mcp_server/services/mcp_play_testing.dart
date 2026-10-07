import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The MCP layer's side of play-testing: the keys agents
/// hold down in the running game, the frames they advanced, and the release
/// of every held key when Play stops, the player is ejected, or the agent's
/// MCP session ends — so an agent that forgets an `up` never leaves W stuck.
class McpPlayTesting {
  McpPlayTesting(this.vm) {
    vm.addListener(_onEditorChanged);
  }

  final EditorViewModel vm;

  /// Held key → the MCP session that pressed it.
  final Map<LuminaKey, String?> _held = {};

  /// Frames `pie_advance` / `pie_action` / `pie_key tap` stepped this Play.
  int framesAdvanced = 0;

  PieController get pie => vm.pieController;

  /// The keys agents hold, by id (`KeyW`).
  List<String> get heldKeys => [for (final k in _held.keys) k.id];

  bool isHeld(LuminaKey key) => _held.containsKey(key);

  /// Presses [key] in the running game (while paused too; the next frame
  /// sees it) and remembers it. False when the game refuses input (ejected).
  bool press(LuminaKey key) {
    if (!pie.acceptsScriptedInput) return false;
    pie.injectKeyDown(key, scripted: true);
    _held[key] = TransactionManager.currentOrigin?.sessionId;
    return true;
  }

  /// Releases [key]; always forwarded, even when ejected.
  void release(LuminaKey key) {
    pie.injectKeyUp(key);
    _held.remove(key);
  }

  /// Releases every held key (only [sessionId]'s when given); returns them.
  List<String> releaseAll({String? sessionId}) {
    final keys = [
      for (final e in _held.entries)
        if (sessionId == null || e.value == sessionId) e.key,
    ];
    for (final k in keys) {
      release(k);
    }
    return [for (final k in keys) k.id];
  }

  /// Pauses a running game (frame stepping needs it). Returns whether it
  /// was running before.
  bool pauseForStepping() {
    final wasRunning = !vm.isPaused && !pie.isPaused;
    if (!pie.isPaused) {
      if (vm.isPlaying) {
        vm.togglePauseSimulation();
      } else {
        pie.pause();
      }
    }
    return wasRunning;
  }

  /// Resumes the game [pauseForStepping] paused.
  void resumeAfterStepping(bool wasRunning) {
    if (!wasRunning || !pie.isPaused) return;
    if (vm.isPlaying) {
      vm.togglePauseSimulation();
    } else {
      pie.resume();
    }
  }

  /// Steps the paused game [frames] times by [dt], without a log line per
  /// frame. [beforeFrame] runs before each step (analog values are consumed
  /// per tick, so a held stick is injected every frame).
  void step(int frames, double dt, {void Function()? beforeFrame}) {
    for (var i = 0; i < frames && pie.isPlaying; i++) {
      beforeFrame?.call();
      pie.step(dt, false);
      framesAdvanced++;
    }
  }

  /// A running Play ended (Stop, a level error): its world took the keys
  /// with it.
  void _onEditorChanged() {
    if (!pie.isPlaying && !vm.isPlaying) {
      _held.clear();
      framesAdvanced = 0;
    }
  }

  void dispose() => vm.removeListener(_onEditorChanged);
}
