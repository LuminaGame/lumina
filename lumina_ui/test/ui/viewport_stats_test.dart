import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  test('reportFrameTime averages FPS', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp');
    
    // Send 30 frames of 16.6 ms (16600 microseconds)
    for (int i = 0; i < 30; i++) {
      vm.reportFrameTime(const Duration(milliseconds: 1), const Duration(microseconds: 16600));
    }
    
    // FPS should be around 60
    expect(vm.fps, closeTo(60.2, 0.5));
    expect(vm.cpuMs, 1.0);
  });

  test('fps never changes without reportFrameTime calls', () async {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp', enableTimers: false, autoInitAssets: false);
    vm.reportFrameTime(const Duration(milliseconds: 2), const Duration(microseconds: 20000));
    final before = vm.fps;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(vm.fps, equals(before));
  });

  test('viewportStatsLabel reports measured values and never a fabricated literal', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp', enableTimers: false, autoInitAssets: false);
    expect(vm.viewportStatsLabel, equals('Tris: 0  FPS: --  CPU: --'));
    for (int i = 0; i < 10; i++) {
      vm.reportFrameTime(const Duration(microseconds: 1500), const Duration(microseconds: 16667));
    }
    expect(vm.viewportStatsLabel, equals('Tris: 0  FPS: 60  CPU: 1.5ms'));
    expect(vm.viewportStatsLabel, isNot(contains('14.2M')));
    expect(EditorViewModel.formatTriangleCount(999), '999');
    expect(EditorViewModel.formatTriangleCount(14200000), '14.2M');
    expect(EditorViewModel.formatTriangleCount(12500), '12.5K');
  });

  // Publishing a new FPS number used to rebuild the whole editor on
  // every rendered frame, which is what capped the viewport at ~15 FPS.
  test('reportFrameTime notifies only the frame-stats listenable, never the editor', () {
    final vm = EditorViewModel(initialProject: LuminaProject(projectName: 'T'), projectLocation: '/tmp', enableTimers: false, autoInitAssets: false);
    var editorNotifies = 0;
    var statsNotifies = 0;
    vm.addListener(() => editorNotifies++);
    vm.frameStats.addListener(() => statsNotifies++);

    for (int i = 0; i < 10; i++) {
      vm.reportFrameTime(const Duration(microseconds: 1500), const Duration(microseconds: 16667));
    }

    expect(editorNotifies, 0, reason: 'a frame must not rebuild the editor');
    expect(statsNotifies, 10);
    expect(vm.fps, closeTo(60.0, 0.1));
    expect(vm.viewportStatsLabel, equals('Tris: 0  FPS: 60  CPU: 1.5ms'));
  });
}
