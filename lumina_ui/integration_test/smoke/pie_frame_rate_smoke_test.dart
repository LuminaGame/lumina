import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The level viewport's texture path used to wait for the GPU and for the
/// image decode inside every frame, so Play ran at every other vsync or
/// worse. This opens the Game Animation Sample example project in the real
/// editor on GPU 1, presses Play, runs forward with W + Shift, and lets
/// frames come from the display's vsync (not from the test) while it
/// measures the viewport's frame rate and render CPU time, with OpenDLSS-NR
/// off and, where its weights are on this machine, on.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final dir = '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';
  final projectFile = File('$dir/game_animation_sample.lmproject');
  final skip = projectFile.existsSync() ? null : 'the Game Animation Sample project is not on this machine';

  Map<String, dynamic> projectMap() => jsonDecode(projectFile.readAsStringSync()) as Map<String, dynamic>;
  final settings = skip == null ? projectMap()['neural_rendering'] as Map? : null;
  final weights = settings?['weights_path'] as String?;
  final nrAvailable = weights != null && Directory(weights).existsSync();

  for (final nr in [false, true]) {
    final label = nr ? 'OpenDLSS-NR on' : 'OpenDLSS-NR off';
    testWidgets('PIE frame rate: the Game Animation Sample runs at the display rate in the editor ($label)', (tester) async {
      final map = projectMap();
      (map['neural_rendering'] as Map<String, dynamic>)['enabled'] = nr;
      final project = LuminaProject.fromMap(map);
      final vm = EditorViewModel(initialProject: project, projectLocation: '${LuminaWorkspace.home}/Lumina Projects');
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      Future<void> settle(int frames) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(120);
      await tester.tap(find.byKey(const ValueKey('toolbar_play')));
      await settle(120);
      final pie = vm.pieController;
      expect(pie.isPlaying, isTrue, reason: 'PIE error: ${pie.lastError}');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);

      // Frames from the display's vsync, as in the running editor.
      final policy = binding.framePolicy;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      final stats = pie.frameStats..reset();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
      final fps = vm.fps;
      final cpu = vm.cpuMs;
      final frame = stats.toJson();
      binding.framePolicy = policy;
      // ignore: avoid_print
      print('[pie_frame_rate] $label: viewport ${fps.toStringAsFixed(1)} FPS, render CPU ${cpu.toStringAsFixed(2)} ms, '
          'game ${jsonEncode(frame)}');

      // The render no longer waits for the GPU inside the frame: its CPU time
      // was 3.7 ms with NR off and 25 ms with it on, the GPU wait included.
      expect(cpu, lessThan(2.0), reason: '$label: the frame waited for the GPU');
      // A debug build spends 40-50 ms per frame building widgets, so the frame
      // rate is only meaningful in a profile or release build (before: 33 FPS
      // with NR off, 17 with it on: two and three vsyncs).
      if (kProfileMode || kReleaseMode) {
        expect(fps, greaterThanOrEqualTo(nr ? 25.0 : 45.0), reason: '$label: the viewport kept every other vsync or worse');
      }

      // The same session on video (frames from the test, for the recorder).
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      final name = 'PIE frame rate: the Game Animation Sample runs at the display rate in the editor ($label)';
      SmokeArtifacts.saveScreenshot(
          name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await rec.hold(const Duration(seconds: 11));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final video = rec.save(name);
      expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
      vm.stopSimulation();
      await settle(20);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, skip: skip != null || (nr && !nrAvailable), timeout: const Timeout(Duration(minutes: 20)));
  }
}
