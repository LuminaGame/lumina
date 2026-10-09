import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

/// A Combo Box's options in the designer: label + typed value rows in the
/// Details panel, saved in the widget `.lmas` (old comma-separated
/// documents open migrated), compiled into the widget and picked in the
/// runtime view with both events.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_combo_options_');
    projectDir = '${tempDir.path}/MenuProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/MenuProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'MenuProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Video.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Video.lmas';
  });

  tearDown(() {
    LuminaUserWidgets.clear();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Video', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return vm;
  }

  Map<String, dynamic> savedProps(String nodeId) {
    final asset = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    final doc = jsonDecode(utf8.decode(asset.rawPayload!)) as Map;
    Map? find(Map node) {
      if (node['id'] == nodeId) return node;
      for (final c in node['children'] as List? ?? const []) {
        final hit = find(c as Map);
        if (hit != null) return hit;
      }
      return null;
    }

    return Map<String, dynamic>.from(find(doc['root'] as Map)!['props'] as Map);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> submit(WidgetTester tester, Key key, String text) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.enterText(find.byKey(key), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('an old comma-separated combo opens as rows; a Vector 2D option is typed in, saved and reloaded', (tester) async {
    var vm = await pumpEditor(tester);
    final combo = vm.addWidget(UmgWidgetType.comboBox, parentId: vm.document.root.id, canvasPosition: const Offset(80, 80))!;
    // As an older Lumina Studio saved it.
    vm.setProp(combo.id, 'options', 'Low,High');
    vm.setProp(combo.id, 'selected', 'Low');
    expect(await tester.runAsync(() => vm.save()), isTrue);
    expect(savedProps(combo.id)['options'], 'Low,High');

    // Reopen: a fresh editor on the saved file.
    await tester.pumpWidget(const SizedBox());
    vm = await pumpEditor(tester);
    expect(vm.document.findNode(combo.id)!.props['options'], [
      {'label': 'Low'},
      {'label': 'High'},
    ], reason: 'the document opens migrated');
    vm.select(combo.id);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(ValueKey('umg_combo_option_row_${combo.id}_0')), findsOneWidget);
    expect(find.byKey(ValueKey('umg_combo_option_row_${combo.id}_1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(ValueKey('umg_combo_option_add_${combo.id}')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('umg_combo_option_add_${combo.id}')));
    await settle(tester);
    expect(vm.document.findNode(combo.id)!.props['options'], hasLength(3));

    await submit(tester, ValueKey('umg_combo_option_label_${combo.id}_2_Option 3'), '1920×1080');
    await tester.ensureVisible(find.byKey(ValueKey('umg_combo_option_type_${combo.id}_2')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('umg_combo_option_type_${combo.id}_2')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('umg_combo_option_type_item_${combo.id}_2_vector2D')));
    await settle(tester);
    await submit(tester, ValueKey('umg_combo_option_value_${combo.id}_2_0_0.0'), '1920');
    await submit(tester, ValueKey('umg_combo_option_value_${combo.id}_2_1_0.0'), '1080');
    expect(vm.document.findNode(combo.id)!.props['options'], [
      {'label': 'Low'},
      {'label': 'High'},
      {'label': '1920×1080', 'value': [1920.0, 1080.0], 'type': 'vector2D'},
    ]);

    // Move it up, remove High.
    await tester.tap(find.byKey(ValueKey('umg_combo_option_up_${combo.id}_2')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byKey(ValueKey('umg_combo_option_remove_${combo.id}_2')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(LuminaComboBoxOptions.labels(vm.document.findNode(combo.id)!.props['options']), ['Low', '1920×1080']);

    expect(await tester.runAsync(() => vm.save()), isTrue);
    final saved = savedProps(combo.id);
    expect(saved['options'], [
      {'label': 'Low'},
      {'label': '1920×1080', 'value': [1920.0, 1080.0], 'type': 'vector2D'},
    ]);
    final runtime = LuminaComboBoxOptions.parse(saved['options']);
    expect(runtime.last.value, Vector2(1920, 1080), reason: 'the runtime reads the literal as a Vector 2D');
    // Let the editor's background file work finish before the temp project goes.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  });

  test('widget codegen: labels from the list form, a pick through selectComboOption and a typed On Selection Changed handler', () {
    final doc = UmgDocument.createDefault();
    final combo = UmgNode.create(UmgWidgetType.comboBox, name: 'Resolution', id: 'c1');
    combo.props
      ..['options'] = [
        {'label': '1280×720', 'value': [1280.0, 720.0], 'type': 'vector2D'},
        {'label': 'Native'},
      ]
      ..['selected'] = 'Native';
    combo.events.add(const UmgEvent(name: 'OnSelectionChanged', handler: 'onSelectionChangedResolution'));
    doc.root.children.add(combo);
    for (final library in [kUmgWidgetLibraryFlutter, kUmgWidgetLibraryShadcn]) {
      final code = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Video', library: library);
      expect(code, contains("LuminaUmgElementBinding.options(e, const ['1280×720', 'Native'])"), reason: library);
      expect(code, contains("LuminaUmgElementBinding.selectComboOption(widget.instance, 'Resolution', "), reason: library);
      expect(code, contains('void _onSelectionChangedResolution(LuminaComboBoxSelection selection) {'), reason: library);
      expect(code, contains('_onSelectionChangedResolution(selection);'), reason: library);
    }
    expect(UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Video', library: kUmgWidgetLibraryFlutter), contains('onSelected: (i) {'));
  });

  testWidgets('PIE runtime view: a pick writes selectedIndex and fires On Value Changed then On Selection Changed with the value',
      (tester) async {
    final doc = UmgDocument.createDefault();
    final combo = UmgNode.create(UmgWidgetType.comboBox, name: 'Resolution', id: 'c1');
    combo.props
      ..['options'] = [
        {'label': '1280×720', 'value': [1280.0, 720.0], 'type': 'vector2D'},
        {'label': '1920×1080', 'value': [1920.0, 1080.0], 'type': 'vector2D'},
      ]
      ..['selected'] = '1280×720';
    doc.root.children.add(combo);
    final widgetClass = UmgWidgetCodegen.widgetClassFor(doc, 'WBP_Video');
    LuminaWidgetClassRegistry.register(widgetClass);
    addTearDown(LuminaWidgetClassRegistry.clear);
    final calls = <String>[];
    LuminaUserWidgets.register('WBP_Video', () => _Recorder(calls));
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final owner = LuminaActor();
    world.persistentLevel.registerActor(owner);
    final instance = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Video') as Map<String, Object?>;

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UmgRuntimeView(document: doc, runtimeValues: instance)),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byType(Select<String>));
    await settle(tester);
    await tester.tap(find.widgetWithText(SelectItemButton<String>, '1920×1080').last);
    await settle(tester);

    final res = LuminaBlueprintFunctionLibrary.getWidgetElement(instance, 'Resolution')! as Map<String, Object?>;
    expect(res['selectedIndex'], 1);
    expect(LuminaBlueprintFunctionLibrary.getElementSelection(res), (returnValue: '1920×1080', value: Vector2(1920, 1080), index: 1));
    expect(calls, [
      'OnValueChanged{value: 1920×1080}',
      'OnSelectionChanged{selected_item: 1920×1080, value: [1920.0,1080.0], index: 1, select_type: OnMouseClick}',
    ]);
    world.cleanup();
  });
}

class _Recorder extends LuminaUserWidget {
  _Recorder(this.calls);

  final List<String> calls;

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) => calls.add('$event$args');
}
