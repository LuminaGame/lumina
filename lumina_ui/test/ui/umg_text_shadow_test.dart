import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Text shadow and outline on every text-bearing element,
/// authored in the inspector, previewed on the designer canvas, persisted in
/// the WIDGET `.lmas`, rendered by the runtime view and set by Blueprints.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_text_shadow_test_');
    projectDir = '${tempDir.path}/HudProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'HudProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_PlayerHUD.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_PlayerHUD.lmas';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_PlayerHUD', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return vm;
  }

  /// The Text widgets the canvas draws for [node] (two when outlined).
  List<Text> canvasTexts(WidgetTester tester, UmgNode node, [String? data]) => tester
      .widgetList<Text>(find.descendant(
        of: find.byKey(ValueKey('umg_rt_${node.id}')),
        matching: find.byWidgetPredicate((w) => w is Text && (data == null || w.data == data)),
      ))
      .toList();

  Map<String, dynamic> savedProps(String nodeId) {
    final asset = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    final doc = UmgDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(asset.rawPayload!)) as Map));
    return doc.findNode(nodeId)!.props;
  }

  testWidgets('a Text shows Shadow and Outline; enabling #FF000080 at (3, 4) blur 2 saves the props, the canvas draws exactly that Shadow, and undo restores', (tester) async {
    final vm = await pumpEditor(tester);
    final text = vm.addWidget(UmgWidgetType.text, parentId: vm.document.root.id, canvasPosition: const Offset(100, 100))!;
    vm.select(text.id);
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(ValueKey('umg_group_shadow_${text.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('umg_group_outline_${text.id}')), findsOneWidget);
    expect(canvasTexts(tester, text).single.style!.shadows, isEmpty, reason: 'a new Text has no shadow');

    // Shadow Enabled switch.
    final enabled = find.byKey(ValueKey('umg_shadow_enabled_${text.id}'));
    await tester.ensureVisible(enabled);
    await tester.tap(enabled);
    await tester.pump();
    // Shadow colour typed with its alpha into the swatch's hex field.
    final colorField = find.descendant(of: find.byKey(ValueKey('umg_prop_shadowColor_${text.id}')), matching: find.byType(TextField));
    await tester.ensureVisible(colorField);
    await tester.tap(colorField);
    await tester.enterText(colorField, '#FF000080');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(vm.document.findNode(text.id)!.props['shadowColor'], '#FF000080');
    // Offsets through the drag number fields, blur through the slider field.
    tester.widget<ScrubNumericField>(find.byKey(ValueKey('umg_prop_shadowOffsetX_${text.id}'))).onCommit(3);
    tester.widget<ScrubNumericField>(find.byKey(ValueKey('umg_prop_shadowOffsetY_${text.id}'))).onCommit(4);
    tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_shadowBlur_${text.id}'))).onCommit(2);
    await tester.pump();

    const expected = Shadow(color: Color(0x80FF0000), offset: Offset(3, 4), blurRadius: 2);
    expect(canvasTexts(tester, text).single.style!.shadows, [expected]);

    expect(await tester.runAsync(() => vm.save()), isTrue);
    final props = savedProps(text.id);
    expect(props['shadowEnabled'], isTrue);
    expect(props['shadowColor'], '#FF000080');
    expect(props['shadowOffsetX'], 3.0);
    expect(props['shadowOffsetY'], 4.0);
    expect(props['shadowBlur'], 2.0);

    // Five edits, five undo steps.
    for (var i = 0; i < 5; i++) {
      vm.undo();
    }
    await tester.pump();
    final restored = vm.document.findNode(text.id)!.props;
    expect(restored['shadowEnabled'], isFalse);
    expect(restored['shadowColor'], '#000000B3');
    expect(restored['shadowOffsetX'], 1.0);
    expect(restored['shadowBlur'], 0.0);
    expect(canvasTexts(tester, text).single.style!.shadows, isEmpty);
    vm.undo();
    await tester.pump();
    expect(vm.document.findNode(text.id), isNull, reason: 'the sixth undo removes the Text: each edit was exactly one step');
  });

  testWidgets('outline size 2 #000000 draws a stroked layer under the fill on the canvas and in UmgRuntimeView', (tester) async {
    final vm = await pumpEditor(tester);
    final text = vm.addWidget(UmgWidgetType.text, parentId: vm.document.root.id, canvasPosition: const Offset(100, 100))!;
    vm.select(text.id);
    await tester.pump(const Duration(milliseconds: 150));
    tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_outlineSize_${text.id}'))).onCommit(2);
    tester.widget<ColorField>(find.byKey(ValueKey('umg_prop_outlineColor_${text.id}'))).onCommit('#000000FF');
    await tester.pump();

    void expectOutlined(List<Text> layers, String where) {
      expect(layers, hasLength(2), reason: '$where: stroke layer + fill layer');
      final stroke = layers.first.style!.foreground!;
      expect(stroke.style, PaintingStyle.stroke, reason: where);
      expect(stroke.strokeWidth, 4.0, reason: '$where: 2 px outside the glyph');
      expect(stroke.color, const Color(0xFF000000), reason: where);
      expect(layers.last.style!.color, const Color(0xFFFFFFFF), reason: '$where: the fill keeps the text colour');
      expect(layers.last.style!.foreground, isNull, reason: where);
    }

    expectOutlined(canvasTexts(tester, text), 'canvas');
    expect(vm.document.findNode(text.id)!.props['outlineSize'], 2.0);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1920, height: 1080, child: UmgRuntimeView(document: vm.document))),
    ));
    await tester.pump();
    expectOutlined(tester.widgetList<Text>(find.text('Text Block')).toList(), 'UmgRuntimeView');
  });

  testWidgets('a document saved before text shadows (no shadow keys) opens with shadow off and renders unchanged', (tester) async {
    final doc = UmgDocument.createDefault();
    final text = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'Title'), canvasPosition: const Offset(40, 40))!;
    final json = doc.toJson();
    // Strip what this task added: the JSON the editor wrote before it.
    final rootChildren = (json['root'] as Map)['children'] as List;
    final props = (rootChildren.single as Map)['props'] as Map;
    props.removeWhere((k, _) => UmgWidgetType.textEffectDefaults.containsKey(k));
    expect(props.keys.toSet(), {'color', 'fontSize', 'text'});
    final old = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    File(lmasPath).writeAsBytesSync(LuminaAsset(
      assetId: old.assetId,
      name: old.name,
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(json))),
    ).toProtoBufferBytes());

    final vm = await pumpEditor(tester);
    final loaded = vm.document.findNode(text.id)!;
    expect(loaded.props['shadowEnabled'], isFalse, reason: 'backfilled with the defaults');
    expect(loaded.props['outlineSize'], 0.0);
    final layers = canvasTexts(tester, loaded, 'Text Block');
    expect(layers, hasLength(1), reason: 'no outline layer');
    expect(layers.single.style!.shadows, isEmpty);
    expect(layers.single.style!.fontSize, 16.0);
    expect(layers.single.style!.color, const Color(0xFFFFFFFF));
  });

  testWidgets('Button, CheckBox, Editable Text and Combo Box labels expose the same groups and render the shadow', (tester) async {
    final vm = await pumpEditor(tester);
    final root = vm.document.root.id;
    final button = vm.addWidget(UmgWidgetType.button, parentId: root, canvasPosition: const Offset(40, 40))!;
    final check = vm.addWidget(UmgWidgetType.checkBox, parentId: root, canvasPosition: const Offset(40, 120))!;
    final field = vm.addWidget(UmgWidgetType.editableText, parentId: root, canvasPosition: const Offset(40, 200))!;
    final combo = vm.addWidget(UmgWidgetType.comboBox, parentId: root, canvasPosition: const Offset(40, 280))!;
    const shadow = Shadow(color: Color(0xFF00FF00), offset: Offset(2, 2), blurRadius: 1);
    for (final n in [button, check, field, combo]) {
      vm.select(n.id);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(ValueKey('umg_group_shadow_${n.id}')), findsOneWidget, reason: '${n.type.displayName} has the Shadow group');
      expect(find.byKey(ValueKey('umg_group_outline_${n.id}')), findsOneWidget, reason: '${n.type.displayName} has the Outline group');
      vm.setProp(n.id, 'shadowEnabled', true);
      vm.setProp(n.id, 'shadowColor', '#00FF00FF');
      vm.setProp(n.id, 'shadowOffsetX', 2.0);
      vm.setProp(n.id, 'shadowOffsetY', 2.0);
      vm.setProp(n.id, 'shadowBlur', 1.0);
    }
    await tester.pump();
    expect(canvasTexts(tester, button, 'Button').single.style!.shadows, [shadow]);
    expect(canvasTexts(tester, check, 'CheckBox').single.style!.shadows, [shadow]);
    expect(canvasTexts(tester, combo, 'Option A').single.style!.shadows, [shadow]);
    // An editable field has no second layer: its style carries the shadow.
    final fieldStyle = tester.widget<TextField>(find.descendant(of: find.byKey(ValueKey('umg_rt_${field.id}')), matching: find.byType(TextField))).style!;
    expect(fieldStyle.shadows, [shadow]);
    // ...and its outline joins as a ring of shadows.
    vm.setProp(field.id, 'outlineSize', 1.0);
    await tester.pump();
    final ringed = tester.widget<TextField>(find.descendant(of: find.byKey(ValueKey('umg_rt_${field.id}')), matching: find.byType(TextField))).style!;
    expect(ringed.shadows, hasLength(9));

    // An Image has no text: no groups.
    final image = vm.addWidget(UmgWidgetType.image, parentId: root, canvasPosition: const Offset(400, 40))!;
    vm.select(image.id);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(ValueKey('umg_group_shadow_${image.id}')), findsNothing);
    expect(image.props.containsKey('shadowEnabled'), isFalse);
  });

  testWidgets('PIE: a Blueprint Set Shadow Color and Opacity on FPSCounter changes the rendered shadow', (tester) async {
    final widgetsDir = Directory('$projectDir/contents/widgets');
    final doc = UmgDocument.createDefault();
    final fps = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'FPSCounter'), canvasPosition: const Offset(20, 20))!;
    fps.props['text'] = 'FPS: 0';
    fps.props['shadowEnabled'] = true;
    File('${widgetsDir.path}/WBP_HUD.lmas').writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_hud',
      name: 'WBP_HUD',
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
    ).toProtoBufferBytes());

    // BP: BeginPlay → Create Widget → Add to Viewport; Tick → Get FPSCounter → Set Shadow Color and Opacity.
    const variables = [LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD')];
    const hudClass = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [LuminaBlueprintWidgetElement(name: 'FPSCounter', typeName: 'text')]);
    final context = LuminaBlueprintTypeContext(variables: variables, widgetClasses: const [hudClass]);
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String a, String ap, String b, String bp) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: a, fromPinId: ap, toNodeId: b, toPinId: bp);
    final bp = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_HUD'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'HudWidget'}),
      place('add_to_viewport', 'show'),
      place('event_tick', 'tick'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'HudWidget'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
      place('set_element_shadow_color', 'shadow', {'in_color': [1.0, 0.0, 0.0, 0.5]}),
    ], wires: [
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set', 'exec_in'),
      wire('create', 'return_value', 'set', 'value'),
      wire('set', 'exec_out', 'show', 'exec_in'),
      wire('set', 'value', 'show', 'target'),
      wire('tick', 'exec_tick_out', 'shadow', 'exec_in'),
      wire('get', 'value', 'fps', 'target'),
      wire('fps', 'return_value', 'shadow', 'target'),
    ]));
    final cls = LuminaBlueprintClass.fromDocument(bp, name: 'BP_HudOwner');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final vm = EditorViewModel(projectDirPath: projectDir, autoInitAssets: false, enableTimers: false);
    final pie = PieController(vm);
    pie.startHeadlessForTest(world);
    LuminaWidgetClassRegistry.clear();
    addTearDown(() {
      pie.stopHeadlessForTest();
      vm.dispose();
      LuminaWidgetClassRegistry.clear();
    });

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 800, height: 600, child: PieWidgetLayer(pieController: pie, projectDirPath: projectDir))),
    ));
    await tester.pumpAndSettle();
    // The layer registered the project's widget classes; now the Blueprint
    // actor plays (Create Widget seeds FPSCounter's state from its class).
    world.spawnActorImmediately(cls.instantiate());
    await tester.pump();
    Text fpsText() => tester.widget<Text>(find.text('FPS: 0'));
    expect(fpsText().style!.shadows, [const Shadow(color: Color(0xB3000000), offset: Offset(1, 1))], reason: 'the designer shadow');

    for (var i = 0; i < 3; i++) {
      world.tick(1 / 60); // Tick → Get FPSCounter → Set Shadow Color and Opacity
      await tester.pump();
    }
    final hud = world.getSubsystem<LuminaWidgetSubsystem>()!.widgets.single;
    expect(((hud['elements'] as Map)['FPSCounter'] as Map)['shadowColor'], [1.0, 0.0, 0.0, 0.5], reason: 'the Blueprint wrote the element state');
    expect(fpsText().style!.shadows, [const Shadow(color: Color(0x80FF0000), offset: Offset(1, 1))]);
  });
}
