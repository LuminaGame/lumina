import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';

void main() {
  group('UmgRuntimeView', () {
    testWidgets('renders UmgDocument with buttons, text and layout', (tester) async {
      final doc = UmgDocument.createDefault();
      final btn = UmgNode.create(UmgWidgetType.button)..props['label'] = 'Start Game';
      final txt = UmgNode.create(UmgWidgetType.text)..props['text'] = 'Player HUD';
      doc.addChild(doc.root.id, btn);
      doc.addChild(doc.root.id, txt);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: UmgRuntimeView(
              document: doc,
              runtimeValues: const {'text': 'Player HUD 100%'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Game'), findsOneWidget);
      expect(find.text('Player HUD 100%'), findsOneWidget);
      expect(find.byType(Button), findsOneWidget);
    });
  });

  group('PieWidgetLayer', () {
    testWidgets('renders active widgets from LuminaWidgetSubsystem on viewport', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_pie_widget_test_');
      try {
        final widgetsDir = Directory('${tempDir.path}/contents/widgets')..createSync(recursive: true);

        // Create WBP_TestHUD.lmas
        final doc = UmgDocument.createDefault();
        final btn = UmgNode.create(UmgWidgetType.button)..props['label'] = 'Click Me';
        doc.addChild(doc.root.id, btn);

        final jsonStr = doc.toFormattedJson();
        final asset = LuminaAsset(
          assetId: 'wbp_test',
          name: 'WBP_TestHUD',
          type: AssetType.widget,
          rawPayload: Uint8List.fromList(utf8.encode(jsonStr)),
        );
        File('${widgetsDir.path}/WBP_TestHUD.lmas').writeAsBytesSync(asset.toProtoBufferBytes());

        final world = LuminaWorld(worldType: LuminaWorldType.game);
        final character = LuminaCharacter();
        world.persistentLevel.registerActor(character);

        final vm = EditorViewModel(projectDirPath: tempDir.path, autoInitAssets: false, enableTimers: false);
        final pie = PieController(vm);
        pie.startHeadlessForTest(world);

        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(
              child: SizedBox(
                width: 800,
                height: 600,
                child: PieWidgetLayer(
                  pieController: pie,
                  projectDirPath: tempDir.path,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no widgets added to viewport
        expect(find.text('Click Me'), findsNothing);

        // Add widget to viewport via BlueprintFunctionLibrary
        final widget = LuminaBlueprintFunctionLibrary.createWidget(character, 'WBP_TestHUD') as Map<String, Object?>;
        LuminaBlueprintFunctionLibrary.addToViewport(character, widget, 0);

        await tester.pumpAndSettle();

        // Now widget is visible on screen!
        expect(find.text('Click Me'), findsOneWidget);
        expect(find.byType(Button), findsOneWidget);

        // Remove from parent
        LuminaBlueprintFunctionLibrary.removeFromParent(character, widget);
        await tester.pumpAndSettle();

        expect(find.text('Click Me'), findsNothing);

        pie.stopHeadlessForTest();
        vm.dispose();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('renders through the shared LuminaWidgetLayer and updates one element\'s text on tick', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_pie_widget_elements_');
      try {
        final widgetsDir = Directory('${tempDir.path}/contents/widgets')..createSync(recursive: true);
        final doc = UmgDocument.createDefault();
        final fps = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'FPSCounter'), canvasPosition: const Offset(20, 20))!;
        fps.props['text'] = 'FPS: 0';
        final title = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'Title'), canvasPosition: const Offset(20, 60))!;
        title.props['text'] = 'Designer title';
        final health = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.progressBar, name: 'Health'), canvasPosition: const Offset(20, 100))!;
        health.props['percent'] = 0.75;
        final asset = LuminaAsset(
          assetId: 'wbp_hud',
          name: 'WBP_HUD',
          type: AssetType.widget,
          rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
        );
        File('${widgetsDir.path}/WBP_HUD.lmas').writeAsBytesSync(asset.toProtoBufferBytes());

        final world = LuminaWorld(worldType: LuminaWorldType.game);
        final character = _HudCharacter();
        world.persistentLevel.registerActor(character);
        final vm = EditorViewModel(projectDirPath: tempDir.path, autoInitAssets: false, enableTimers: false);
        final pie = PieController(vm);
        pie.startHeadlessForTest(world);
        LuminaWidgetClassRegistry.clear();

        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(
              child: SizedBox(
                width: 800,
                height: 600,
                child: PieWidgetLayer(pieController: pie, projectDirPath: tempDir.path),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LuminaWidgetLayer), findsOneWidget, reason: 'PIE renders through the engine layer');
        expect(LuminaWidgetClassRegistry.lookup('WBP_HUD')?.elements.map((e) => e.name), ['FPSCounter', 'Title', 'Health'],
            reason: 'the designer documents are registered so Create Widget seeds the elements');

        world.beginPlay();
        world.tick(1 / 60); // Create Widget + Add to Viewport
        await tester.pump();
        expect(find.text('FPS: 0'), findsOneWidget);
        expect(find.text('Designer title'), findsOneWidget);
        final elements = character.hud!['elements'] as Map<String, Object?>;
        expect(elements.keys, ['FPSCounter', 'Title', 'Health']);

        for (var i = 0; i < 5; i++) {
          world.tick(1 / 60); // Get FPSCounter → Set Text (Text)
          await tester.pump();
        }
        expect(find.text('FPS: 60'), findsOneWidget);
        expect(find.text('FPS: 0'), findsNothing);
        expect(find.text('Designer title'), findsOneWidget, reason: 'the other Text keeps its designer text');
        expect(tester.widget<Progress>(find.byType(Progress)).progress, 0.75);

        LuminaBlueprintFunctionLibrary.removeFromParent(character, character.hud);
        await tester.pump();
        expect(find.text('FPS: 60'), findsNothing);

        pie.stopHeadlessForTest();
        vm.dispose();
      } finally {
        LuminaWidgetClassRegistry.clear();
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

/// What the FPS HUD Blueprint's Tick does: Create Widget + Add to Viewport
/// once, then `Get FPSCounter → Set Text (Text)` with the frame rate.
class _HudCharacter extends LuminaCharacter {
  Map<String, Object?>? hud;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (hud == null) {
      hud = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_HUD') as Map<String, Object?>;
      LuminaBlueprintFunctionLibrary.addToViewport(this, hud, 0);
      return;
    }
    final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'FPSCounter');
    LuminaBlueprintFunctionLibrary.setElementText(this, fps, 'FPS: ${(1 / deltaTime).round()}');
  }
}
