import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Container panel, styled like Flutter's `Container`,
/// authored in the inspector, rendered on the canvas and in PIE, emitted by
/// the codegen and set by Blueprints.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_container_test_');
    projectDir = '${tempDir.path}/HudProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'HudProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Panel.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Panel.lmas';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A real TEXTURE `.lmas` (a PNG payload) under the project.
  String writeTexture() {
    final png = img.Image(width: 8, height: 8);
    img.fill(png, color: img.ColorRgba8(250, 124, 1, 255));
    Directory('$projectDir/contents/textures').createSync(recursive: true);
    const rel = 'contents/textures/T_Panel.lmas';
    File('$projectDir/$rel').writeAsBytesSync(LuminaAsset(
      assetId: 't_panel',
      name: 'T_Panel',
      type: AssetType.texture,
      rawPayload: Uint8List.fromList(img.encodePng(png)),
    ).toProtoBufferBytes());
    return rel;
  }

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Panel', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return vm;
  }

  /// The Flutter `Container` the canvas draws for a Container element.
  Container canvasContainer(WidgetTester tester, UmgNode node) => tester.widget<Container>(find
      .descendant(
        of: find.descendant(of: find.byKey(ValueKey('umg_rt_${node.id}')), matching: find.byType(LuminaUmgContainer)).first,
        matching: find.byType(Container),
      )
      .first);

  BoxDecoration canvasDecoration(WidgetTester tester, UmgNode node) => canvasContainer(tester, node).decoration! as BoxDecoration;

  Future<void> typeColor(WidgetTester tester, String key, String hex) async {
    final field = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.enterText(field, hex);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('a Container styled #1E1E2A, radius 12, 2 px #FB7C01 border, padding 16 and a (0, 4, 12) shadow saves those props, the canvas Container paints exactly them, and undo restores', (tester) async {
    final vm = await pumpEditor(tester);
    final panel = vm.addWidget(UmgWidgetType.container, parentId: vm.document.root.id, canvasPosition: const Offset(100, 100))!;
    vm.select(panel.id);
    await tester.pump(const Duration(milliseconds: 150));
    for (final group in ['background', 'border', 'corners', 'spacing', 'box_shadow', 'size']) {
      expect(find.byKey(ValueKey('umg_group_${group}_${panel.id}')), findsOneWidget, reason: '$group group');
    }

    await typeColor(tester, 'umg_prop_backgroundColor_${panel.id}', '#1E1E2A');
    tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_cornerRadius_${panel.id}'))).onCommit(12);
    await typeColor(tester, 'umg_prop_borderColor_${panel.id}', '#FB7C01');
    tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_borderWidth_${panel.id}'))).onCommit(2);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      tester.widget<ScrubNumericField>(find.byKey(ValueKey('umg_prop_padding_${i}_${panel.id}'))).onCommit(16);
      await tester.pump();
    }
    final shadowSwitch = find.byKey(ValueKey('umg_box_shadow_enabled_${panel.id}'));
    await tester.ensureVisible(shadowSwitch);
    await tester.tap(shadowSwitch);
    await tester.pump();
    tester.widget<ScrubNumericField>(find.byKey(ValueKey('umg_prop_box_shadow_offsetY_${panel.id}'))).onCommit(4);
    await tester.pump();
    tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_box_shadow_blur_${panel.id}'))).onCommit(12);
    await tester.pump();

    final d = canvasDecoration(tester, panel);
    expect(d.color, const Color(0xFF1E1E2A));
    expect(d.borderRadius, BorderRadius.circular(12));
    expect(d.border, Border.all(color: const Color(0xFFFB7C01), width: 2));
    expect(d.boxShadow, [const BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 12)]);
    expect(canvasContainer(tester, panel).padding, const EdgeInsets.all(16));

    expect(await tester.runAsync(() => vm.save()), isTrue);
    final asset = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    final saved = UmgDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(asset.rawPayload!)) as Map)).findNode(panel.id)!.props;
    expect(saved['backgroundColor'], '#1E1E2AFF');
    expect(saved['cornerRadius'], 12.0);
    expect(saved['borderColor'], '#FB7C01FF');
    expect(saved['borderWidth'], 2.0);
    expect(saved['padding'], [16.0, 16.0, 16.0, 16.0]);
    expect((saved['shadows'] as List).single, {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0});

    // 9 edits (colour, radius, colour, width, 4 × padding, shadow on — its
    // default is already (0, 4, 12), so those two commits change nothing), 9 steps.
    final labels = <String>[];
    for (var i = 0; i < 9; i++) {
      labels.add(vm.transactions.undoLabel);
      vm.undo();
    }
    await tester.pump();
    expect(vm.document.findNode(panel.id), isNotNull, reason: 'undone: $labels');
    final restored = vm.document.findNode(panel.id)!.props;
    expect(restored['backgroundColor'], '#1B1B22FF');
    expect(restored['cornerRadius'], 0.0);
    expect(restored['padding'], [0.0, 0.0, 0.0, 0.0]);
    expect(restored['shadows'], isEmpty);
    expect(vm.document.findNode(panel.id), isNotNull);
    vm.undo();
    expect(vm.document.findNode(panel.id), isNull, reason: 'the tenth undo removes the Container: each edit was one step');
  });

  testWidgets('a linear gradient and a background texture render on the canvas; a Border converts to a Container in one step', (tester) async {
    final rel = writeTexture();
    final vm = await pumpEditor(tester);
    await tester.runAsync(() async => vm.refreshTextures());
    final panel = vm.addWidget(UmgWidgetType.container, parentId: vm.document.root.id, canvasPosition: const Offset(100, 100))!;
    vm.setProp(panel.id, 'gradient', {'type': 'linear', 'colors': ['#FB7C01FF', '#1B1B22FF'], 'begin': 'topLeft', 'end': 'bottomRight'});
    vm.bindTexture(panel.id, vm.textureAssets.firstWhere((t) => t.relativePath == rel));
    await tester.pump();
    final d = canvasDecoration(tester, panel);
    expect(d.gradient, const LinearGradient(colors: [Color(0xFFFB7C01), Color(0xFF1B1B22)], begin: Alignment.topLeft, end: Alignment.bottomRight));
    expect(d.image, isNotNull, reason: 'the TEXTURE .lmas is the background image');
    expect(d.image!.fit, BoxFit.cover);

    final border = vm.addWidget(UmgWidgetType.border, parentId: vm.document.root.id, canvasPosition: const Offset(600, 100))!;
    final child = vm.addWidget(UmgWidgetType.text, parentId: border.id)!;
    vm.select(border.id);
    await tester.pump(const Duration(milliseconds: 150));
    final convert = find.byKey(ValueKey('umg_convert_to_container_${border.id}'));
    await tester.ensureVisible(convert);
    await tester.tap(convert);
    await tester.pump();
    final converted = vm.document.findNode(border.id)!;
    expect(converted.type, UmgWidgetType.container);
    expect(converted.props['backgroundColor'], '#1B1B22FF');
    expect(converted.props['padding'], [8.0, 8.0, 8.0, 8.0]);
    expect(converted.children.single.id, child.id, reason: 'the child stays');
    vm.undo();
    expect(vm.document.findNode(border.id)!.type, UmgWidgetType.border);
  });

  testWidgets('PIE: the gradient and texture render, and a Blueprint Set Background Color repaints the Container', (tester) async {
    final rel = writeTexture();
    final doc = UmgDocument.createDefault();
    final panel = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.container, name: 'Panel'), canvasPosition: const Offset(20, 20))!;
    panel.props
      ..['gradient'] = {'type': 'linear', 'colors': ['#FB7C01FF', '#1B1B22FF']}
      ..['backgroundImage'] = rel
      ..['cornerRadius'] = 12.0;
    File('$projectDir/contents/widgets/WBP_Panel.lmas').writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_panel',
      name: 'WBP_Panel',
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
    ).toProtoBufferBytes());

    // BP: BeginPlay → Create Widget → Add to Viewport; Tick → Get Panel → Set Background Color.
    const variables = [LuminaBlueprintVariable(name: 'Hud', typeName: 'Widget:WBP_Panel')];
    const cls = LuminaBlueprintWidgetClass(name: 'WBP_Panel', elements: [LuminaBlueprintWidgetElement(name: 'Panel', typeName: 'container')]);
    final context = LuminaBlueprintTypeContext(variables: variables, widgetClasses: const [cls]);
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String a, String ap, String b, String bp) => LuminaBlueprintWire(id: 'w${n++}', fromNodeId: a, fromPinId: ap, toNodeId: b, toPinId: bp);
    final bp = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_Panel'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'Hud'}),
      place('add_to_viewport', 'show'),
      place('event_tick', 'tick'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'Hud'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'panel', {'element': 'Panel'}),
      place('set_element_background_color', 'bg', {'in_color': [0.0, 0.5, 1.0, 1.0]}),
    ], wires: [
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set', 'exec_in'),
      wire('create', 'return_value', 'set', 'value'),
      wire('set', 'exec_out', 'show', 'exec_in'),
      wire('set', 'value', 'show', 'target'),
      wire('tick', 'exec_tick_out', 'bg', 'exec_in'),
      wire('get', 'value', 'panel', 'target'),
      wire('panel', 'return_value', 'bg', 'target'),
    ]));
    // The editor registers the project's widget classes before Play compiles Blueprints.
    LuminaWidgetClassRegistry.register(cls);
    final bpClass = LuminaBlueprintClass.fromDocument(bp, name: 'BP_PanelOwner');
    expect(bpClass.diagnostics, isEmpty, reason: '${bpClass.diagnostics}');

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final editor = EditorViewModel(projectDirPath: projectDir, autoInitAssets: false, enableTimers: false);
    final pie = PieController(editor);
    pie.startHeadlessForTest(world);
    LuminaWidgetClassRegistry.clear();
    addTearDown(() {
      pie.stopHeadlessForTest();
      editor.dispose();
      LuminaWidgetClassRegistry.clear();
    });
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 800, height: 600, child: PieWidgetLayer(pieController: pie, projectDirPath: projectDir))),
    ));
    await tester.pumpAndSettle();
    world.spawnActorImmediately(bpClass.instantiate());
    await tester.pump();
    BoxDecoration decoration() => tester.widget<Container>(find.descendant(of: find.byType(LuminaUmgContainer), matching: find.byType(Container)).first).decoration! as BoxDecoration;
    expect(decoration().gradient, isA<LinearGradient>());
    expect(decoration().image, isNotNull, reason: 'PIE loads the bound texture');
    expect(decoration().color, const Color(0xFF1B1B22), reason: 'the designer colour');

    world.tick(1 / 60);
    await tester.pump();
    expect(decoration().color, const Color(0xFF0080FF), reason: 'Set Background Color at run time');
    expect(decoration().borderRadius, BorderRadius.circular(12));
  });

  test('codegen: the Container is Flutter\'s in both libraries, with the designer style, gradient and texture', () {
    final doc = UmgDocument.createDefault();
    final panel = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.container, name: 'Panel'), canvasPosition: Offset.zero)!;
    panel.props
      ..['backgroundColor'] = '#1E1E2AFF'
      ..['cornerRadius'] = 12.0
      ..['borderColor'] = '#FB7C01FF'
      ..['borderWidth'] = 2.0
      ..['padding'] = [16.0, 16.0, 16.0, 16.0]
      ..['shadows'] = [
        {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0},
      ]
      ..['gradient'] = {'type': 'linear', 'colors': ['#FB7C01FF', '#1B1B22FF'], 'begin': 'topLeft', 'end': 'bottomRight'}
      ..['backgroundImage'] = 'contents/textures/T_Panel.lmas';
    doc.addChild(panel.id, UmgNode.create(UmgWidgetType.text, name: 'Label'));
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Panel', library: library);
      expect(src, contains('LuminaUmgContainer('));
      expect(src, contains("LuminaUmgElementBinding.containerStyle(e, const LuminaUmgContainerStyle(backgroundColor: Color(0xFF1E1E2A), "));
      expect(src, contains('borderColor: Color(0xFFFB7C01), borderWidth: 2.0'));
      expect(src, contains('topLeft: Radius.circular(12.0)'));
      expect(src, contains('padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0)'));
      expect(src, contains('shadows: [BoxShadow(color: Color(0x66000000), offset: Offset(0.0, 4.0), blurRadius: 12.0, spreadRadius: 0.0)]'));
      expect(src, contains("gradient: LuminaUmgGradient(type: 'linear', colors: [Color(0xFFFB7C01), Color(0xFF1B1B22)]"));
      expect(src, contains("_umgLoadTexture(LuminaUmgElementBinding.value<String>(e, 'backgroundImage', 'contents/textures/T_Panel.lmas'))"));
      expect(src, contains('image: snapshot.data == null ? null : MemoryImage(snapshot.data!)'));
      expect(src.contains('shadcn_flutter'), library == kUmgWidgetLibraryShadcn);
    }
  });
}
