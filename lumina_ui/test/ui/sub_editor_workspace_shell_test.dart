import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_workspace_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorTabDescriptor & EditorAssetTypeHandler API', () {
    test('carries contentDroppable and contentBrowserOpened options', () {
      final tabDescDefault = EditorTabDescriptor(
        id: 'test_tab',
        title: 'Test Tab',
        builder: (ctx) => const SizedBox(),
      );
      expect(tabDescDefault.contentDroppable, isFalse);
      expect(tabDescDefault.contentBrowserOpened, isFalse);

      final tabDescCustom = EditorTabDescriptor(
        id: 'custom_tab',
        title: 'Custom Tab',
        builder: (ctx) => const SizedBox(),
        contentDroppable: true,
        contentBrowserOpened: true,
      );
      expect(tabDescCustom.contentDroppable, isTrue);
      expect(tabDescCustom.contentBrowserOpened, isTrue);

      final assetHandler = EditorAssetTypeHandler(
        customTypeId: 'my_asset',
        displayName: 'My Asset',
        icon: LucideIcons.box,
        thumbnailBuilder: (_) async => null,
        contentDroppable: true,
        contentBrowserOpened: true,
      );
      expect(assetHandler.contentDroppable, isTrue);
      expect(assetHandler.contentBrowserOpened, isTrue);
    });
  });

  group('SubEditorWorkspaceShell Widget', () {
    late Directory temp;
    late EditorViewModel vm;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('lumina_sub_editor_shell_test_');
      final prjDir = Directory('${temp.path}/TestPrj')..createSync(recursive: true);
      File('${prjDir.path}/TestPrj.lmproject').writeAsStringSync('{"project_name": "TestPrj"}');
      Directory('${prjDir.path}/contents').createSync(recursive: true);

      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'TestPrj', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: temp.path,
        enableTimers: false,
        autoInitAssets: false,
      );
    });

    tearDown(() {
      vm.close();
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('unpinned by default: displays drawer toggle icon at bottom-left and toggles drawer', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SubEditorWorkspaceShell(
              assetType: 'CustomPluginTab',
              assetName: 'Plugin Workspace',
              editorViewModel: vm,
              contentBrowserOpened: false,
              contentDroppable: false,
              child: const Center(child: Text('Plugin Canvas Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Canvas content is rendered
      expect(find.text('Plugin Canvas Content'), findsOneWidget);

      // Bottom panel is not docked initially
      expect(find.byKey(const ValueKey('sub_editor_bottom_pane')), findsNothing);

      // Bottom-left Content Drawer button is present
      expect(find.byKey(const ValueKey('sub_editor_content_drawer_btn')), findsOneWidget);

      // Tap drawer button to open drawer
      await tester.tap(find.byKey(const ValueKey('sub_editor_content_drawer_btn')));
      await tester.pumpAndSettle();

      // Content Browser is now visible in the drawer
      expect(find.text('Content Browser'), findsOneWidget);
      expect(find.byKey(const ValueKey('sub_editor_bottom_panel_pin')), findsOneWidget);
      expect(find.byKey(const ValueKey('sub_editor_bottom_drawer_close')), findsOneWidget);

      // Close drawer
      await tester.tap(find.byKey(const ValueKey('sub_editor_bottom_drawer_close')));
      await tester.pumpAndSettle();

      // Drawer is closed, button reappears
      expect(find.byKey(const ValueKey('sub_editor_content_drawer_btn')), findsOneWidget);
    });

    testWidgets('pin button docks Content Browser into vertical ResizablePanel', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SubEditorWorkspaceShell(
              assetType: 'CustomPluginTab',
              assetName: 'Plugin Workspace',
              editorViewModel: vm,
              contentBrowserOpened: false,
              child: const Center(child: Text('Editor Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byKey(const ValueKey('sub_editor_content_drawer_btn')));
      await tester.pumpAndSettle();

      // Pin the drawer to dock it
      await tester.tap(find.byKey(const ValueKey('sub_editor_bottom_panel_pin')));
      await tester.pumpAndSettle();

      // Now docked in a resizable pane
      expect(find.byWidgetPredicate((w) => w is ResizablePane && w.key == const ValueKey('sub_editor_bottom_pane')), findsOneWidget);
      expect(find.byKey(const ValueKey('sub_editor_content_drawer_btn')), findsNothing);
    });

    testWidgets('contentBrowserOpened: true starts docked at the bottom', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SubEditorWorkspaceShell(
              assetType: 'CustomPluginTab',
              assetName: 'Plugin Workspace',
              editorViewModel: vm,
              contentBrowserOpened: true,
              child: const Center(child: Text('Editor Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts docked in a resizable pane
      expect(find.byWidgetPredicate((w) => w is ResizablePane && w.key == const ValueKey('sub_editor_bottom_pane')), findsOneWidget);
      expect(find.byKey(const ValueKey('sub_editor_content_drawer_btn')), findsNothing);
      expect(find.text('Content Browser'), findsOneWidget);
    });

    testWidgets('contentDroppable: true accepts asset drops', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      RealAssetInfo? droppedAsset;

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SubEditorWorkspaceShell(
              assetType: 'Material',
              assetName: 'M_Test',
              editorViewModel: vm,
              contentDroppable: true,
              onAssetDropped: (a) => droppedAsset = a,
              child: const Center(child: Text('Drop Target Viewport')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DragTarget<RealAssetInfo>), findsWidgets);
      expect(droppedAsset, isNull);
    });
  });
}
