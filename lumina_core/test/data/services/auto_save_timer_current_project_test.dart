import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// The auto-save timer saves the project the editor holds when it fires,
/// never a copy taken when the editor opened, and only while something is
/// unsaved: a setting applied after the editor opened is not reverted.
void main() {
  test('a tick saves the current project once, then nothing until it changes again', () async {
    var current = const LuminaProject(
      projectName: 'starting',
      isDirty: true,
      lastModifiedTimestamp: '2026-10-12T13:04:06Z',
      lastCodeGeneratedTimestamp: '2026-10-12T13:00:00Z',
    );
    final saved = <LuminaProject>[];
    final service = AutoSaveTimerService(onPerformSave: (project) async {
      saved.add(project);
      // What the editor does: the saved project, stamped with the time of
      // its code generation, becomes its project.
      current = project.copyWith(isDirty: false, lastCodeGeneratedTimestamp: '2026-10-12T14:0${saved.length}:00Z');
      return current;
    });
    service.start(() => current, interval: const Duration(milliseconds: 20));
    addTearDown(service.stop);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(saved, hasLength(1), reason: 'saved once; the saved project is not modified since its code generation');

    // Project Settings applies a change after the editor opened.
    current = current.copyWith(
      description: 'applied after the editor opened',
      isDirty: true,
      lastModifiedTimestamp: '2026-10-12T13:31:00Z',
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(saved, hasLength(2));
    expect(saved.last.description, 'applied after the editor opened', reason: 'the project held at the tick, not the first one');
  });
}
