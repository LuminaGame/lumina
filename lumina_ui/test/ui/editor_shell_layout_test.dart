import 'dart:io';
import 'package:flutter/gestures.dart' show kMiddleMouseButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('Editor Shell Layout & Workspace Tabs', () {
    late Directory tempProjectDir;
    late EditorViewModel viewModel;

    setUp(() {
      tempProjectDir = Directory.systemTemp.createTempSync('lumina_test_');
      File('${tempProjectDir.path}/my_project.lmproject').writeAsStringSync('{}');
      viewModel = EditorViewModel(projectLocation: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
    });

    tearDown(() {
      viewModel.dispose();
      if (tempProjectDir.existsSync()) {
        tempProjectDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Layout round-trip on real disk', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MainEditorView(viewModel: viewModel)),
      ));
      
      viewModel.layoutState.outlinerWidth = 360.0;
      viewModel.saveLayoutState();
      
      final file = File('${tempProjectDir.path}/MyFirstLuminaGame/.lumina/editor_layout.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('"outlinerWidth":360.0'));
      final restoredViewModel = EditorViewModel(projectLocation: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
      expect(restoredViewModel.layoutState.outlinerWidth, 360.0);
    });

    testWidgets('Corrupt editor_layout.json falls back to defaults without crash', (tester) async {
      final file = File('${tempProjectDir.path}/MyFirstLuminaGame/.lumina/editor_layout.json');
      file.createSync(recursive: true);
      file.writeAsStringSync('garbage{');

      final corruptViewModel = EditorViewModel(projectLocation: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
      expect(corruptViewModel.layoutState.outlinerWidth, EditorLayoutState.defaultOutlinerWidth);
      expect(corruptViewModel.layoutState.outlinerVisible, isTrue);
    });

    testWidgets('Reset Layout to Default restores sizes', (tester) async {
      viewModel.layoutState.outlinerWidth = 500;
      viewModel.layoutState.outlinerVisible = false;
      
      viewModel.layoutState.resetToDefault();
      
      expect(viewModel.layoutState.outlinerWidth, EditorLayoutState.defaultOutlinerWidth);
      expect(viewModel.layoutState.outlinerVisible, isTrue);
    });

    testWidgets('Dirty dot, save discard dialog, middle click close', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MainEditorView(viewModel: viewModel)),
      ));
      await tester.pump(const Duration(seconds: 1));

      viewModel.openSubEditorTab('Material Editor');
      await tester.pump(const Duration(seconds: 1));
      
      expect(viewModel.openTabs.length, 2);
      expect(find.descendant(of: find.byKey(const ValueKey('workspace_tab_1')), matching: find.text('Material Editor Editor')),
          findsOneWidget);

      // Make it dirty: the typed tab shows the unsaved dot.
      viewModel.openTabs[1].isDirty = true;
      viewModel.notifyListeners();
      await tester.pump(const Duration(seconds: 1));
      expect(find.descendant(of: find.byKey(const ValueKey('workspace_tab_1')), matching: find.byKey(const ValueKey('workspace_tab_unsaved_dot'))),
          findsOneWidget);

      // Under the pointer the dot turns into the cross; it asks to save.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('workspace_tab_1'))));
      await tester.pump();
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('workspace_tab_1')), matching: find.byKey(const ValueKey('workspace_tab_close'))));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Save Changes?'), findsWidgets);

      // Discard
      await tester.tap(find.text('Discard'));
      await tester.pump(const Duration(seconds: 1));

      expect(viewModel.openTabs.length, 1);

      // Open another; a middle click on its tab closes it.
      viewModel.openSubEditorTab('Blueprint Editor');
      await tester.pump(const Duration(seconds: 1));
      final middle = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('workspace_tab_1'))),
          kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
      await middle.up();
      await tester.pump(const Duration(seconds: 1));

      expect(viewModel.openTabs.length, 1);
    });
  });
}
