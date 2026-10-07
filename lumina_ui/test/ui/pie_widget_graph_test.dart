import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/widget_graph_fixture.dart';

/// Play-In-Editor runs a widget's graph in the VM: a
/// character's BeginPlay creates WBP_Clicker and adds it to the viewport
/// (Construct shows Title), and a click on its button in the PIE widget
/// layer sets Title to "Clicked!".
class _ClickerCharacter extends LuminaCharacter {
  Map<String, Object?>? widget;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    widget = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_Clicker') as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(this, widget, 0);
  }
}

void main() {
  testWidgets('a click on the button in Play runs On Clicked (StartButton) through the VM', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_pie_widget_graph_');
    addTearDown(() {
      LuminaUserWidgets.clear();
      LuminaWidgetClassRegistry.clear();
      tempDir.deleteSync(recursive: true);
    });
    final vm = EditorViewModel(projectDirPath: tempDir.path, autoInitAssets: false, enableTimers: false);
    final widgetsDir = Directory('${vm.projectDirPath}/contents/widgets')..createSync(recursive: true);
    final doc = clickerDocument();
    File('${widgetsDir.path}/WBP_Clicker.lmas').writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_clicker',
      name: 'WBP_Clicker',
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
    ).toProtoBufferBytes());

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final character = _ClickerCharacter();
    world.persistentLevel.registerActor(character);
    final pie = PieController(vm);
    pie.startHeadlessForTest(world);
    // What Play's createGame does before the world begins.
    pie.registerWidgetClasses();
    pie.registerWidgetScripts();
    expect(LuminaUserWidgets.has('WBP_Clicker'), isTrue);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 800, height: 600, child: PieWidgetLayer(pieController: pie, projectDirPath: vm.projectDirPath))),
    ));
    await tester.pumpAndSettle();

    world.beginPlay();
    await tester.pump();
    final script = LuminaUserWidgets.of(character.widget);
    expect(script, isA<LuminaBlueprintUserWidget>(), reason: 'the VM runs the saved graph');
    expect(find.text('Waiting'), findsOneWidget, reason: 'Construct made Title visible');

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Clicked!'), findsOneWidget);
    expect(find.text('Waiting'), findsNothing);

    pie.stopHeadlessForTest();
    vm.dispose();
  });
}
