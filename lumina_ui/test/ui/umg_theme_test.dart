import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/slot_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UmgThemeHelper', () {
    test('themeDataFromLuminaDoc maps colors and radius accurately', () {
      final doc = LuminaThemeDocument(
        name: 'CyanTheme',
        colors: {
          'background': 0xFF001122,
          'foreground': 0xFFEEEEEE,
          'primary': 0xFF00FFFF,
          'secondary': 0xFF223344,
          'destructive': 0xFFFF0055,
        },
        radius: 12.0,
      );

      final themeData = UmgThemeHelper.themeDataFromLuminaDoc(doc);
      expect(themeData.colorScheme.background, const Color(0xFF001122));
      expect(themeData.colorScheme.foreground, const Color(0xFFEEEEEE));
      expect(themeData.colorScheme.primary, const Color(0xFF00FFFF));
      expect(themeData.colorScheme.secondary, const Color(0xFF223344));
      expect(themeData.colorScheme.destructive, const Color(0xFFFF0055));
      expect(themeData.radius, 12.0);
    });

    test('resolveThemeForNode falls back to documentTheme when no override', () {
      final docTheme = LuminaThemeDocument(name: 'DocTheme');
      final node = UmgNode.create(UmgWidgetType.button, name: 'MyButton');

      final resolved = UmgThemeHelper.resolveThemeForNode(
        node: node,
        documentTheme: docTheme,
        loadedThemes: {},
      );

      expect(resolved.name, 'DocTheme');
    });

    test('resolveThemeForNode resolves node override from loadedThemes', () {
      final docTheme = LuminaThemeDocument(name: 'DocTheme');
      final customTheme = LuminaThemeDocument(name: 'CustomRedTheme', colors: {'primary': 0xFFFF0000});
      final node = UmgNode.create(UmgWidgetType.button, name: 'MyButton');
      node.props['theme'] = 'contents/themes/CustomRedTheme.lmas';

      final resolved = UmgThemeHelper.resolveThemeForNode(
        node: node,
        documentTheme: docTheme,
        loadedThemes: {'contents/themes/CustomRedTheme.lmas': customTheme},
      );

      expect(resolved.name, 'CustomRedTheme');
      expect(resolved.colorOf('primary'), const Color(0xFFFF0000));
    });

    testWidgets('buildThemedButton renders with theme primary color and custom styles', (tester) async {
      final theme = LuminaThemeDocument(
        name: 'TestTheme',
        colors: {
          'primary': 0xFF3B82F6,
          'primaryForeground': 0xFFFFFFFF,
        },
        customStyles: {
          'HeroGold': const LuminaCustomStyle(
            name: 'HeroGold',
            targetComponent: 'button',
            style: LuminaComponentStyle(
              backgroundColor: 0xFFF59E0B,
              foregroundColor: 0xFF000000,
              borderRadius: 16.0,
            ),
          ),
        },
      );

      final buttonNode = UmgNode.create(UmgWidgetType.button, name: 'TestBtn');
      buttonNode.props['style'] = 'HeroGold';
      buttonNode.props['label'] = 'Golden Action';

      var pressed = false;
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: UmgThemeHelper.buildThemedButton(
              node: buttonNode,
              theme: theme,
              onPressed: () => pressed = true,
              child: const Text('Golden Action'),
            ),
          ),
        ),
      );

      expect(find.text('Golden Action'), findsOneWidget);
      await tester.tap(find.text('Golden Action'));
      expect(pressed, isTrue);

      // Verify the Theme surrounding the button has the custom primary color
      final themeWidget = tester.widget<Theme>(find.byType(Theme).last);
      expect(themeWidget.data.colorScheme.primary, const Color(0xFFF59E0B));
      expect(themeWidget.data.radius, 16.0);
    });
  });

  group('UmgDocument Theme Serialization', () {
    test('serializes and deserializes themePath property', () {
      final doc = UmgDocument.createDefault(themePath: 'contents/themes/Cyberpunk.lmas');
      expect(doc.themePath, 'contents/themes/Cyberpunk.lmas');

      final json = doc.toJson();
      expect(json['theme'], 'contents/themes/Cyberpunk.lmas');

      final deserialized = UmgDocument.fromJson(json);
      expect(deserialized.themePath, 'contents/themes/Cyberpunk.lmas');
    });
  });

  group('UmgEditorViewModel Theme Integration', () {
    test('discovers themes and handles document/node theme overrides', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_umg_theme_vm_test_');
      UmgEditorViewModel? vm;
      try {
        final prjPath = tempDir.path.replaceAll('\\', '/');
        // Ensure default theme
        await LuminaThemeService.ensureDefaultTheme(prjPath);

        // Author a second theme
        final customTheme = LuminaThemeDocument(
          name: 'EmeraldTheme',
          colors: {'primary': 0xFF10B981},
        );
        await LuminaThemeService.saveTheme('$prjPath/contents/themes/EmeraldTheme.lmas', customTheme);

        final widgetFile = File('$prjPath/contents/ui/TestWidget.lmas');
        widgetFile.parent.createSync(recursive: true);
        final defaultDoc = UmgDocument.createDefault();
        final btn = UmgNode.create(UmgWidgetType.button, name: 'ActionButton');
        defaultDoc.root.children.add(btn);
        await widgetFile.writeAsBytes(LuminaAsset(
          assetId: 'TestWidget',
          name: 'TestWidget.lmas',
          type: AssetType.widget,
          rawPayload: utf8.encode(defaultDoc.toFormattedJson()),
        ).toProtoBufferBytes());

        vm = UmgEditorViewModel(
          assetPath: widgetFile.path,
          projectDirPathOverride: prjPath,
        );
        await vm.load();

        expect(vm.availableThemePaths.length, greaterThanOrEqualTo(2));
        expect(vm.activeTheme.colorOf('primary'), const Color(0xFF3B82F6)); // DefaultTheme is blue

        // Switch document theme
        final emeraldPath = vm.availableThemePaths.firstWhere((p) => p.contains('EmeraldTheme'));
        await vm.setDocumentTheme(emeraldPath);
        expect(vm.activeThemePath, emeraldPath);
        expect(vm.activeTheme.colorOf('primary'), const Color(0xFF10B981));
        expect(vm.activeThemeData.colorScheme.primary, const Color(0xFF10B981));

        // Node theme override
        final btnInDoc = vm.document.findNode(btn.id)!;
        expect(vm.themeForNode(btnInDoc).name, 'EmeraldTheme');
        final defaultThemePath = vm.availableThemePaths.firstWhere((p) => p.contains('DefaultTheme'));
        await vm.setNodeTheme(btn.id, defaultThemePath);
        expect(vm.themeForNode(btnInDoc).name, 'DefaultTheme');
        expect(vm.themeForNode(btnInDoc).colorOf('primary'), const Color(0xFF3B82F6));

        // Clear node theme override
        await vm.setNodeTheme(btn.id, null);
        expect(vm.themeForNode(btnInDoc).name, 'EmeraldTheme');
      } finally {
        vm?.dispose();
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } on FileSystemException catch (_) {}
      }
    });
  });

  group('UmgSlotInspector & Toolbar Theme Pickers', () {
    testWidgets('displays Theme Pickers in inspector and toolbar', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_umg_ui_test_');
      UmgEditorViewModel? vm;
      try {
        final prjPath = tempDir.path.replaceAll('\\', '/');

        await tester.runAsync(() async {
          await LuminaThemeService.ensureDefaultTheme(prjPath);
        });

        final doc = UmgDocument.createDefault();
        final btn = UmgNode.create(UmgWidgetType.button, name: 'SubmitBtn');
        doc.root.children.add(btn);

        vm = UmgEditorViewModel(
          assetPath: '$prjPath/test.lmas',
          initialAsset: LuminaAsset(
            assetId: 'test',
            name: 'test.lmas',
            type: AssetType.widget,
            rawPayload: utf8.encode(doc.toFormattedJson()),
          ),
          projectDirPathOverride: prjPath,
        );
        await tester.runAsync(() => vm!.load());

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        vm.select(doc.root.id);
        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(
              child: SizedBox(
                width: 300,
                child: ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => UmgSlotInspector(vm: vm!),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }

        // When root is selected, Widget Theme picker is displayed
        expect(find.text('Widget Theme'), findsOneWidget);
        expect(find.byKey(const ValueKey('umg_document_theme_picker')), findsOneWidget);

        // When button is selected, Theme Override and Button Style pickers are displayed
        vm.select(btn.id);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(find.text('Component Theme Override'), findsOneWidget);
        expect(find.byKey(ValueKey('umg_node_theme_picker_${btn.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('umg_button_style_picker_${btn.id}')), findsOneWidget);
      } finally {
        vm?.dispose();
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } on FileSystemException catch (_) {}
      }
    });
  });
}

