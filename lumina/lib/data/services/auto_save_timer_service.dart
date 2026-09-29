import 'dart:async';
import '../../data/models/lumina_project.dart';
import 'engine_logger_service.dart';

typedef SaveCallback = Future<LuminaProject> Function(LuminaProject currentProject);

class AutoSaveTimerService {
  final SaveCallback onPerformSave;
  Timer? _timer;

  AutoSaveTimerService({required this.onPerformSave});

  void start(LuminaProject currentProject, {Duration interval = const Duration(minutes: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      await checkAndExecuteAutoSave(currentProject);
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
