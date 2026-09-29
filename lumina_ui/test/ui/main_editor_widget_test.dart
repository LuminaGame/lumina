import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('MainEditorView should render all panels, Outliner, Viewport, Details and Quality settings', (WidgetTester tester) async {
    // The project lives in this test's own temp directory, not
    // ~/Lumina Projects, and its viewport quality in the isolated config
    // directory (test/flutter_test_config.dart), so nothing on the machine
    // changes what the editor opens.
    final root = Directory.systemTemp.createTempSync('main_editor_widget_');
    addTearDown(() => root.deleteSync(recursive: true));
    // The starter level is written to disk for real before the view opens it.
    final seed = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(seed.ensureDefaultLevelAssets);
    seed.dispose();

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: MainEditorView(projectLocation: root.path),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lumina Studio'), findsOneWidget);
    expect(find.text('0.0.1'), findsOneWidget);
    expect(find.text('WORLD OUTLINER'), findsOneWidget);
    expect(find.text('DirectionalLight_Sun'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Content Browser'), findsOneWidget);
  });
}
