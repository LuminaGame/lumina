import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/services/auto_save_timer_service.dart';

void main() {
  group('AutoSaveTimerService Tests', () {
    test('Should trigger save & code generation callback when project isDirty', () async {
      var triggered = false;
      LuminaProject? updatedProject;

      final project = LuminaProject(
        projectName: 'test_game',
        isDirty: true,
        lastModifiedTimestamp: '2026-08-07T16:10:00Z',
        lastCodeGeneratedTimestamp: '2026-08-07T16:00:00Z',
      );

      final service = AutoSaveTimerService(
        onPerformSave: (proj) async {
          triggered = true;
          updatedProject = proj.copyWith(
            isDirty: false,
            lastCodeGeneratedTimestamp: '2026-08-07T16:10:00Z',
          );
          return updatedProject!;
        },
      );

      final result = await service.checkAndExecuteAutoSave(project);

      expect(triggered, isTrue);
      expect(result.isDirty, isFalse);
      expect(result.lastCodeGeneratedTimestamp, equals('2026-08-07T16:10:00Z'));
    });

    test('Should skip save when project is NOT dirty', () async {
      var triggered = false;

      final project = LuminaProject(
        projectName: 'test_game',
        isDirty: false,
        lastModifiedTimestamp: '2026-08-07T16:10:00Z',
        lastCodeGeneratedTimestamp: '2026-08-07T16:10:00Z',
      );

      final service = AutoSaveTimerService(
        onPerformSave: (proj) async {
          triggered = true;
          return proj;
        },
      );

      final result = await service.checkAndExecuteAutoSave(project);

      expect(triggered, isFalse);
      expect(result.isDirty, isFalse);
    });
  });
}
