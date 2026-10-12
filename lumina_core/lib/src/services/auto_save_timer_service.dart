import 'dart:async';
import 'package:lumina_core/src/formats/lumina_project.dart';
import 'package:lumina_core/src/services/engine_logger_service.dart';

typedef SaveCallback = Future<LuminaProject> Function(LuminaProject currentProject);

/// Saves the editor's project every [start] interval while it has unsaved
/// changes.
class AutoSaveTimerService {
  final SaveCallback onPerformSave;
  Timer? _timer;
  bool _saving = false;

  AutoSaveTimerService({required this.onPerformSave});

  /// Checks [currentProject] every [interval]. It is called on each tick, so
  /// the save sees the project the editor holds then (settings applied since
  /// the editor opened included), never a copy taken when the timer started.
  void start(LuminaProject Function() currentProject, {Duration interval = const Duration(minutes: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      // A slow save is not started again by the next tick.
      if (_saving) return;
      _saving = true;
      try {
        await checkAndExecuteAutoSave(currentProject());
      } finally {
        _saving = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<LuminaProject> checkAndExecuteAutoSave(LuminaProject project) async {
    try {
      if (project.isDirty ||
          _isModifiedSinceLastGeneration(project.lastModifiedTimestamp, project.lastCodeGeneratedTimestamp)) {
        return await onPerformSave(project);
      }
    } catch (e, st) {
      EngineLoggerService().log('AutoSave exception: $e\n$st', level: 'error', source: 'AutoSaveTimerService');
    }
    return project;
  }

  bool _isModifiedSinceLastGeneration(String modified, String generated) {
    if (modified.isEmpty) return false;
    if (generated.isEmpty) return true;
    try {
      final modTime = DateTime.parse(modified);
      final genTime = DateTime.parse(generated);
      return modTime.isAfter(genTime);
    } catch (e) {
      EngineLoggerService().log('Timestamp parsing notice: $e', level: 'warning', source: 'AutoSaveTimerService');
      return true;
    }
  }
}
