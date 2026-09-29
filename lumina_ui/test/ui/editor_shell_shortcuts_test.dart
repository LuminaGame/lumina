import 'package:lumina/data/models/lumina_asset.dart';
import 'dart:io';
import 'package:flutter/widgets.dart' hide Column;
import 'package:flutter/material.dart' hide Column, TextField;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/shortcuts/editor_shortcuts_scope.dart';
import 'package:lumina_ui/ui/features/main_editor/utils/fuzzy_match.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('Editor Shortcuts & Quick Open', () {
    late EditorViewModel viewModel;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('shortcuts_test');
      viewModel = EditorViewModel(
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
    });

    tearDown(() {
      viewModel.dispose();
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('Shortcuts toggle active tool', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: EditorShortcutsScope(
          viewModel: viewModel,
          child: Focus(
            autofocus: true,
            child: ToolbarWidget(viewModel: viewModel),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final vm = viewModel;

      expect(vm.activeTool, 'select');
      
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(vm.activeTool, 'translate');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(vm.activeTool, 'rotate');
    });
    
    test('Fuzzy matcher returns exact order', () {
      final assets = [
        RealAssetInfo(relativePath: 'contents/meshes/StaticMesh_Rock.lmas', fileName: 'StaticMesh_Rock.lmas', type: AssetType.filamesh, bytes: 1024),
        RealAssetInfo(relativePath: 'contents/materials/M_Rock.lmas', fileName: 'M_Rock.lmas', type: AssetType.filamat, bytes: 1024),
      ];
      
      final matches = fuzzyMatchAssets('rck', assets);
      expect(matches.length, 2);
      expect(matches[0].asset.fileName, 'M_Rock.lmas'); // Shorter name wins
      expect(matches[1].asset.fileName, 'StaticMesh_Rock.lmas');
    });
    testWidgets('Focus scoping: typing in TextField does not trigger tools', (tester) async {
      final textController = TextEditingController();
      
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: EditorShortcutsScope(
          viewModel: viewModel,
          child: Column(
            children: [
              TextField(controller: textController),
              ToolbarWidget(viewModel: viewModel),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(viewModel.activeTool, 'select');
      
      // Tap the text field to focus it
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      
      // Send W
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      
      // Active tool should remain 'select'
      expect(viewModel.activeTool, 'select');
    });

    testWidgets('Fly-mode precedence blocks single-key shortcuts', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: EditorShortcutsScope(
          viewModel: viewModel,
          child: Focus(
            autofocus: true,
            child: ToolbarWidget(viewModel: viewModel),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      viewModel.isFlyNavigating = true;
      
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(viewModel.activeTool, 'select'); // Unchanged
      
      viewModel.isFlyNavigating = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(viewModel.activeTool, 'translate'); // Changed
    });
    
    testWidgets('Ctrl+P opens Quick Open Palette and Esc closes it', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: EditorShortcutsScope(
          viewModel: viewModel,
          child: Focus(
            autofocus: true,
            child: ToolbarWidget(viewModel: viewModel),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      // Press Ctrl+P
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      
      // The QuickOpenPaletteWidget should be visible
      expect(find.text('Search assets...'), findsOneWidget);
      
      // Press Esc
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      
      expect(find.text('Search assets...'), findsNothing);
    });
  });
}
