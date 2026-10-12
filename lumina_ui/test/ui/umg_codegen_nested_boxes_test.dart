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

import '../helpers/temp_project.dart';

/// Box panels nested in each other or in a Scroll Box: a Horizontal Box in a
/// Vertical Box or a vertical Scroll Box is as tall as its content, a
/// Vertical Box in a Horizontal Box or a horizontal Scroll Box as wide as its
/// content, in the designer, in the runtime preview and in generated code.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_boxes_test_');
    projectDir = '${tempDir.path}/MenuProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/MenuProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'MenuProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Settings.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Settings.lmas';
  });

  tearDown(() => deleteTempProject(tempDir));

  Future<UmgEditorViewModel> loadVm(WidgetTester tester) async => (await tester.runAsync(() async {
        final vm = UmgEditorViewModel(assetPath: lmasPath);
        await vm.load();
        await vm.themesLoaded;
        return vm;
      }))!;

  /// Authors the settings rows the way a menu does and saves the real `.lmas`:
  /// a Vertical Box of label + combo rows, a vertical Scroll Box of rows, and
  /// a Horizontal Box holding a Vertical Box of buttons.
  Future<void> authorAndSave(WidgetTester tester) async {
    final vm = await loadVm(tester);
    final root = vm.document.root.id;
    final list = vm.addWidget(UmgWidgetType.verticalBox, parentId: root, canvasPosition: const Offset(40, 40))!;
    final scroll = vm.addWidget(UmgWidgetType.scrollBox, parentId: root, canvasPosition: const Offset(400, 40))!;
    final bar = vm.addWidget(UmgWidgetType.horizontalBox, parentId: root, canvasPosition: const Offset(40, 400))!;
    for (final parent in [list.id, scroll.id]) {
      final row = vm.addWidget(UmgWidgetType.horizontalBox, parentId: parent)!;
      vm.setProp(vm.addWidget(UmgWidgetType.text, parentId: row.id)!.id, 'text', 'Quality');
      vm.setProp(vm.addWidget(UmgWidgetType.comboBox, parentId: row.id)!.id, 'options', ['Low', 'High']);
    }
    final buttons = vm.addWidget(UmgWidgetType.verticalBox, parentId: bar.id)!;
    vm.setProp(vm.addWidget(UmgWidgetType.button, parentId: buttons.id)!.id, 'label', 'Apply');
    vm.setProp(vm.addWidget(UmgWidgetType.button, parentId: buttons.id)!.id, 'label', 'Close');
    expect(await tester.runAsync(() => vm.save()), isTrue);
    vm.dispose();
  }

  testWidgets('the designer canvas lays out nested boxes without an unbounded-height error', (tester) async {
    await authorAndSave(tester);
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = await loadVm(tester);
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Settings', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Quality'), findsNWidgets(2));
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('the runtime preview lays out the saved document: rows as tall as their content', (tester) async {
    await authorAndSave(tester);
    final vm = await loadVm(tester);
    addTearDown(vm.dispose);
    for (final plain in [false, true]) {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: SizedBox(width: 1280, height: 720, child: UmgRuntimeView(document: vm.document, plainLibrary: plain)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: plain ? 'plain Flutter' : 'shadcn');
      expect(find.text('Quality'), findsNWidgets(2));
      for (final rowHeight in tester.widgetList<LuminaUmgBox>(find.byType(LuminaUmgBox)).map((w) => tester.getSize(find.byWidget(w)).height)) {
        expect(rowHeight.isFinite, isTrue);
      }
    }
  });

  test('generated code builds box panels with LuminaUmgBox, never a bare stretching Row or Column', () {
    final doc = UmgDocument.createDefault();
    final list = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.verticalBox, name: 'List'), canvasPosition: const Offset(40, 40))!;
    final row = doc.addChild(list.id, UmgNode.create(UmgWidgetType.horizontalBox, name: 'Row'))!;
    doc.addChild(row.id, UmgNode.create(UmgWidgetType.text, name: 'Label'));
    doc.addChild(row.id, UmgNode.create(UmgWidgetType.comboBox, name: 'Quality'));
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Settings', library: library);
      expect('LuminaUmgBox('.allMatches(src).length, 2, reason: library);
      expect(src, contains('direction: Axis.horizontal'));
      expect(src, contains('direction: Axis.vertical'));
      expect(src, isNot(contains('crossAxisAlignment: CrossAxisAlignment.stretch')), reason: library);
    }
  });

  test("a Fill slot of a box is Flutter's Expanded in both libraries (shadcn's Expanded does not fit a Flutter Flex)", () {
    final doc = UmgDocument.createDefault();
    final row = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.horizontalBox, name: 'Row'), canvasPosition: const Offset(40, 40))!;
    doc.addChild(row.id, UmgNode.create(UmgWidgetType.text, name: 'Label')..slot.fill = true);
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Fill', library: library);
      expect(src, contains('widgets.Expanded(flex: 100'), reason: library);
      expect(src, isNot(contains(RegExp(r'[^.]Expanded\('))), reason: library);
      expect(src, contains("import 'package:flutter/widgets.dart' as widgets show Expanded"), reason: library);
    }
  });
}
