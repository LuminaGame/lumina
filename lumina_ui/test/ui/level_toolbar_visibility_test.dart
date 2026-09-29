import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The level viewport toolbar belongs to the level tab; document tabs
/// (the Plugin Manager, sub-editors) bring their own tools.
void main() {
  late Directory projectDir;
  late EditorViewModel vm;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_toolbar_');
    File('${projectDir.path}/toolbar_project.lmproject').writeAsStringSync('{}');
    vm = EditorViewModel(projectLocation: projectDir.path, enableTimers: false, autoInitAssets: false);
  });

  tearDown(() {
    vm.dispose();
    try {
      projectDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle for a moment; the temp dir is left.
    }
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: MainEditorView(viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the level tab shows the level viewport toolbar', (tester) async {
    await pumpEditor(tester);
    expect(vm.currentTab.id, EditorViewModel.kLevelTabId);
    expect(find.byType(ToolbarWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('toolbar_play')), findsOneWidget);
  });

  testWidgets('the Plugins tab shows no level viewport toolbar', (tester) async {
    await pumpEditor(tester);
    vm.openSubEditorTab('plugins', title: 'Plugins');
    await tester.pump(const Duration(milliseconds: 500));

    expect(vm.currentTab.category, 'plugins');
    expect(find.byType(ToolbarWidget), findsNothing);
    expect(find.byKey(const ValueKey('toolbar_play')), findsNothing);
    expect(find.byKey(const ValueKey('toolbar_blueprints')), findsNothing);

    vm.selectTab(0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ToolbarWidget), findsOneWidget, reason: 'back on the level tab');
  });

  testWidgets('a sub-editor tab shows no level viewport toolbar', (tester) async {
    await pumpEditor(tester);
    vm.openSubEditorTab('Material Editor');
    await tester.pump(const Duration(milliseconds: 500));

    expect(vm.currentTab.category, 'Material Editor');
    expect(find.byType(ToolbarWidget), findsNothing);

    vm.selectTab(0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ToolbarWidget), findsOneWidget);
  });
}
