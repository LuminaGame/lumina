import 'dart:io';
import 'package:flutter/material.dart' hide Scaffold, Row;
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
      
      viewModel.layoutState.outlinerWidth = 300.0;
      viewModel.saveLayoutState();
      
      final file = File('${tempProjectDir.path}/MyFirstLuminaGame/.lumina/editor_layout.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('"outlinerWidth":300.0'));
      final restoredViewModel = EditorViewModel(projectLocation: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
      expect(restoredViewModel.layoutState.outlinerWidth, 300.0);
    });

    testWidgets('Corrupt editor_layout.json falls back to defaults without crash', (tester) async {
      final file = File('${tempProjectDir.path}/MyFirstLuminaGame/.lumina/editor_layout.json');
      file.createSync(recursive: true);
      file.writeAsStringSync('garbage{');

      final corruptViewModel = EditorViewModel(projectLocation: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
      expect(corruptViewModel.layoutState.outlinerWidth, 220.0);
      expect(corruptViewModel.layoutState.outlinerVisible, isTrue);
    });

    testWidgets('Reset Layout to Default restores sizes', (tester) async {
      viewModel.layoutState.outlinerWidth = 500;
      viewModel.layoutState.outlinerVisible = false;
      
      viewModel.layoutState.resetToDefault();
      
      expect(viewModel.layoutState.outlinerWidth, 220.0);
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
      expect(find.text('Material Editor Editor'), findsWidgets);
      
      // Make it dirty
      viewModel.openTabs[1].isDirty = true;
      await tester.pump(const Duration(seconds: 1));
      
      expect(find.text('Material Editor Editor*'), findsWidgets);
      
      // Tap the X inside the dirty tab's header row (not any other close icon)
      final tabRow = find.ancestor(
        of: find.text('Material Editor Editor*').first,
        matching: find.byType(Row),
      ).first;
      await tester.tap(find.descendant(of: tabRow, matching: find.byIcon(LucideIcons.x)).first);
      await tester.pump(const Duration(seconds: 1));
      
      expect(find.text('Save Changes?'), findsWidgets);
      
      // Discard
      await tester.tap(find.text('Discard'));
      await tester.pump(const Duration(seconds: 1));
      
      expect(viewModel.openTabs.length, 1);
      
      // Open another
      viewModel.openSubEditorTab('Blueprint Editor');
      await tester.pump(const Duration(seconds: 1));
      
      // Middle click to close
      // The title also appears inside the sub-editor body; the 9px bold text is the tab header.
      final tabFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Blueprint Editor Editor' && w.style?.fontSize == 9,
      );
      await tester.tap(tabFinder, buttons: 4);
      await tester.pump(const Duration(seconds: 1));
      
      expect(viewModel.openTabs.length, 1);
    });
  });
}
