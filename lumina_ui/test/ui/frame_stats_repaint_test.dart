import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The FPS readouts change on every rendered frame. Sharing a paint
/// layer with the editor, each change repainted the whole window.
void main() {
  testWidgets('the per-frame telemetry readouts repaint in layers of their own', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_frame_stats_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'StatsGame'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 300));

    vm.reportFrameTime(const Duration(microseconds: 1500), const Duration(microseconds: 16667));
    await tester.pump();

    final readouts = [
      find.textContaining(RegExp(r'ms  \d+ FPS$')), // toolbar counter
      find.textContaining('FPS: '), // viewport stats strip
    ];
    for (final finder in readouts) {
      expect(finder, findsWidgets);
      RenderObject? node = tester.renderObject(finder.first);
      RenderObject? boundary;
      while (node != null) {
        if (node.isRepaintBoundary) {
          boundary = node;
          break;
        }
        node = node.parent;
      }
      final size = (boundary! as RenderBox).size;
      expect(size.height, lessThan(60), reason: '$finder repaints a ${size.width}x${size.height} layer');
    }
    vm.dispose();
  });
}
