import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  group('ContentBrowser Multi-Select & Bulk Deletion Tests', () {
    late Directory tempDir;
    late String projPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cb_multiselect_');
      projPath = '${tempDir.path}/TestProj';
      final meshesDir = Directory('$projPath/contents/meshes');
      meshesDir.createSync(recursive: true);

      for (int i = 1; i <= 5; i++) {
        final asset = LuminaAsset(
          assetId: 'SM_Item_0$i',
          name: 'SM_Item_0$i.lmas',
          type: AssetType.filamesh,
        );
        File('$projPath/contents/meshes/SM_Item_0$i.lmas').writeAsStringSync(jsonEncode(asset.toMap()));
      }
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('EditorViewModel should delete multiple assets in cascade and clean scene', () async {
      final project = const LuminaProject(
        projectName: 'TestProj',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L_OpenWorld_Main.lmas',
      );
      final viewModel = EditorViewModel(
        initialProject: project,
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

      viewModel.refreshAssets();

      expect(viewModel.realAssets.length, equals(5));

      final itemsToDelete = viewModel.realAssets.take(2).toList();
      expect(itemsToDelete.length, equals(2));

      await viewModel.deleteMultipleAssetsCascadeAndCleanScene(itemsToDelete);

      expect(viewModel.realAssets.length, equals(3));
      viewModel.dispose();
    });

    testWidgets('Shift forward and backward range selection and bulk delete dialog flow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));

      final project = const LuminaProject(
        projectName: 'TestProj',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/L_OpenWorld_Main.lmas',
      );
      final viewModel = EditorViewModel(
        initialProject: project,
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
      viewModel.refreshAssets();

      await tester.pumpWidget(
        shad.ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 400,
              child: ContentBrowserWidget(viewModel: viewModel),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.realAssets.length, equals(5));

      final firstKey = const ValueKey('asset_item_contents/meshes/SM_Item_01.lmas');
      final thirdKey = const ValueKey('asset_item_contents/meshes/SM_Item_03.lmas');
      final fifthKey = const ValueKey('asset_item_contents/meshes/SM_Item_05.lmas');

      expect(find.byKey(firstKey), findsOneWidget);
      expect(find.byKey(thirdKey), findsOneWidget);
      expect(find.byKey(fifthKey), findsOneWidget);

      // 1. Forward Shift Selection (Select Item 1, Shift+Click Item 3 -> 3 selected)
      await tester.tap(find.byKey(firstKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('1 Selected'), findsWidgets);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byKey(thirdKey));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('3 Selected'), findsWidgets);
      expect(find.textContaining('Delete (3)'), findsWidgets);

      // 2. Backward Shift Selection (Select Item 5, Shift+Click Item 3 -> 3 selected: 3, 4, 5)
      await tester.tap(find.byKey(fifthKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('1 Selected'), findsWidgets);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byKey(thirdKey));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('3 Selected'), findsWidgets);
      expect(find.textContaining('Delete (3)'), findsWidgets);

      // 3. Trigger Delete Modal Dialog via Toolbar Button
      await tester.tap(find.textContaining('Delete (3)'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Delete Confirmation Dialog opens with list of selected assets
      expect(find.textContaining('Delete 3 Assets'), findsWidgets);
      // The dialog says where the assets go.
      expect(find.textContaining('Move these 3 selected assets to the project trash'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);

      // 4. Confirm Deletion in Modal Dialog
      final confirmDeleteBtn = find.widgetWithText(shad.PrimaryButton, 'Delete (3) Assets');
      expect(confirmDeleteBtn, findsOneWidget);
      final historyBefore = viewModel.transactions.history(limit: 200).length;

      await tester.tap(confirmDeleteBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // The three assets left contents/ for one trash entry, as one undo step.
      expect(viewModel.realAssets.length, equals(2));
      expect(find.textContaining('Selected'), findsNothing);
      final trash = viewModel.projectTrash.list();
      expect(trash, hasLength(1));
      expect(trash.single.files, hasLength(3));
      expect(viewModel.transactions.history(limit: 200).length, historyBefore + 1);
      expect(viewModel.commands.execute('edit.undo'), isTrue);
      await tester.pump();
      expect(viewModel.realAssets.length, equals(5), reason: 'undo restores all three');

      await tester.pump(const Duration(seconds: 10)); // the toast times out
      viewModel.dispose();
    });
  });
}
