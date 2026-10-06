import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/theme_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/theme/theme.dart';

void main() {
  group('ThemeEditorViewModel', () {
    test('initializes and manages color tokens, components and custom styles', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_theme_vm_test_');
      try {
        final filePath = '${tempDir.path}/DefaultTheme.lmas';
        final vm = ThemeEditorViewModel(
          assetPath: filePath,
          initialAsset: LuminaAsset(
            assetId: 'DefaultTheme',
            name: 'DefaultTheme.lmas',
            type: AssetType.theme,
            rawPayload: utf8.encode(LuminaThemeDocument.defaultShadcnDark().toJson()),
          ),
        );

        expect(vm.doc.name, 'DefaultTheme');
        expect(vm.doc.colorOf('primary'), const Color(0xFF3B82F6));
        expect(vm.isDirty, isFalse);

        // Update token
        vm.setColor('primary', 0xFF38BDF8);
        expect(vm.isDirty, isTrue);
        expect(vm.doc.colorOf('primary'), const Color(0xFF38BDF8));

        // Create component style override for card
        expect(vm.hasComponentStyle('card'), isFalse);
        vm.createComponentStyle('card');
        expect(vm.hasComponentStyle('card'), isTrue);
        expect(vm.componentStyleOf('card'), isNotNull);

        // Custom style authoring
        expect(vm.doc.customStyles.containsKey('GoldButton'), isFalse);
        vm.createCustomStyle('GoldButton', 'button');
        expect(vm.doc.customStyles.containsKey('GoldButton'), isTrue);
        expect(vm.doc.customStyles['GoldButton']!.targetComponent, 'button');

        // Save
        final ok = await vm.save();
        expect(ok, isTrue);
        expect(vm.isDirty, isFalse);
        expect(File(filePath).existsSync(), isTrue);

        // Load back from file
        final loadedDoc = await LuminaThemeService.loadTheme(filePath);
        expect(loadedDoc.colorOf('primary'), const Color(0xFF38BDF8));
        expect(loadedDoc.componentStyles.containsKey('card'), isTrue);
        expect(loadedDoc.customStyles.containsKey('GoldButton'), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('ThemeSubEditor Widget', () {
    testWidgets('mounts properly and displays tree panel and preview showcase', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doc = LuminaThemeDocument.defaultShadcnDark(name: 'DefaultTheme');
      final vm = ThemeEditorViewModel(
        assetPath: 'contents/themes/DefaultTheme.lmas',
        initialAsset: LuminaAsset(
          assetId: 'DefaultTheme',
          name: 'DefaultTheme.lmas',
          type: AssetType.theme,
          rawPayload: utf8.encode(doc.toJson()),
        ),
      );

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: ThemeSubEditor(
              assetName: 'DefaultTheme.lmas',
              viewModel: vm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top toolbar elements
      expect(find.text('DefaultTheme.lmas'), findsOneWidget);
      expect(find.text('UI Theme'), findsOneWidget);
      expect(find.text('New Custom Style'), findsWidgets);

      // Left Tree Panel items
      expect(find.text('Color Palette'), findsOneWidget);
      expect(find.text('Geometry & Radius'), findsOneWidget);
      expect(find.text('Typography'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);

      // Right Showcase elements
      expect(find.textContaining('Styled Widget Showcase'), findsOneWidget);
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Cards & Containers'), findsOneWidget);
      expect(find.text('Primary Action'), findsOneWidget);
      expect(find.text('Outline Button'), findsOneWidget);
      expect(find.text('Destructive'), findsOneWidget);

      // Verify "Create Style" button exists for card before custom style is created
      final createCardBtnFinder = find.byKey(const ValueKey('create_style_btn_card'));
      expect(createCardBtnFinder, findsOneWidget);

      // Tap "Create Style" on card
      await tester.tap(createCardBtnFinder);
      await tester.pumpAndSettle();

      // Card component style is now present
      expect(vm.hasComponentStyle('card'), isTrue);
      expect(vm.isDirty, isTrue);

      // Now "Create Style" button for card should be replaced with "Edit Style"
      expect(find.byKey(const ValueKey('create_style_btn_card')), findsNothing);
      expect(find.text('Edit Style'), findsWidgets);
    });
  });
}
