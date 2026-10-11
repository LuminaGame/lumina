import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_template.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/editor_panel_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/palette.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';

/// Authoring editor panels: New ▸ Editor Panel Widget writes a working
/// panel (its button shows a toast), the designer offers the Editor palette
/// section and the editor-scope graph palette only for an editor panel,
/// Class Settings ▸ Editor Panel writes the block, and Run as Editor Panel
/// docks it.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;

  setUp(() async {
    project = await EditorPanelProject.create('DesignPanels');
    vm = await project.open();
    await EditorPanelProject.startPanels(vm);
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  test('New ▸ Editor Panel Widget writes a working panel whose button shows a toast', () async {
    final path = await vm.createEditorPanelWidget();
    expect(path, '$kEditorPanelFolder/EPW_NewEditorPanel.lmas');
    const id = 'project/$kEditorPanelFolder/EPW_NewEditorPanel.lmas';
    await until(() => vm.editorPanels.panel(id) != null, reason: 'the new panel');
    final rt = vm.editorPanels.panel(id)!;
    expect(rt.errors, isEmpty);
    expect(rt.info.dock, LuminaEditorPanelDock.right);
    expect([for (final e in rt.widgetClass.elements) e.typeName], containsAll(['editorSection', 'propertyRow', 'button']));
    expect(await vm.runAsEditorPanel(project.projectPath(path)), isTrue, reason: 'Run as Editor Panel docks it (trusted by its author)');
    final panel = vm.editorPanels.instancesOf(id).single;
    vm.editorPanels.fire(panel, 'HelloButton', 'OnClicked');
    expect(vm.logger.logs.map((l) => l.message), contains(startsWith('Hello from EPW_NewEditorPanel')));
    expect(vm.panelsController.isVisible('editorPanel:$id'), isTrue);
    // A second one takes a free name.
    expect(await vm.createEditorPanelWidget(), '$kEditorPanelFolder/EPW_NewEditorPanel_1.lmas');
  });

  test('the designer graph of an editor panel is in the editor scope; a game widget\'s is not', () async {
    final path = project.projectPath(await vm.createEditorPanelWidget());
    final designer = UmgEditorViewModel(assetPath: path, projectDirPathOverride: project.projectDir.path);
    await designer.load();
    expect(designer.document.isEditorPanel, isTrue);
    final context = designer.graphEditor.buildTypeContext();
    expect(context.isEditorScope, isTrue);
    expect(LuminaBlueprintNodeLibrary.availableIn(LuminaBlueprintNodeLibrary.spec('editor_show_toast')!, context), isTrue);
    expect(LuminaBlueprintNodeLibrary.availableIn(LuminaBlueprintNodeLibrary.spec('get_player_character')!, context), isFalse);
    // Class Settings ▸ Editor Panel off: a game widget again.
    designer.setEditorPanel(null);
    expect(designer.graphEditor.buildTypeContext().isEditorScope, isFalse);
    designer.setEditorPanel(LuminaEditorPanelInfo(
        title: 'Tools', dock: LuminaEditorPanelDock.tab, capabilities: {LuminaEditorPanelCapability.level}));
    expect(await designer.save(), isTrue);
    final saved = jsonDecode(utf8.decode(LuminaAsset.fromBytes(File(path).readAsBytesSync()).rawPayload!)) as Map<String, dynamic>;
    expect(saved['editorPanel'], {'title': 'Tools', 'dock': 'tab', 'capabilities': ['level']});
    expect(designer.graphEditor.buildTypeContext().editorCapabilities, {'level'});
    designer.dispose();
  });

  test('a project plugin\'s panels stay editable in the designer', () {
    final plugin = project.writePlugin('my_tools');
    expect(vm.isReadOnlyPluginContent(p.join(plugin.path, 'content', 'EPW_X.lmas')), isFalse);
    expect(vm.isReadOnlyPluginContent(project.projectPath('contents/editor/EPW_X.lmas')), isFalse);
  });

  testWidgets('the Editor palette section and Class Settings show only for an editor panel', (tester) async {
    final path = project.projectPath(
        (await tester.runAsync(() => createEditorPanelAsset(projectDirPath: project.projectDir.path, name: 'EPW_Palette')))!);
    final designer = UmgEditorViewModel(assetPath: path, projectDirPathOverride: project.projectDir.path);
    await tester.runAsync(designer.load);
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> show(Widget w) async {
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: SizedBox(width: 300, child: w))));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await show(UmgPalette(vm: designer));
    expect(find.byKey(const ValueKey('umg_palette_category_editor')), findsOneWidget);
    for (final t in ['treeView', 'listView', 'assetPicker', 'resizableSplit', 'editorToolbar', 'statusLine', 'editorSection', 'propertyRow']) {
      expect(find.byKey(ValueKey('umg_palette_$t')), findsOneWidget, reason: t);
    }
    await show(UmgEditorPanelSettings(vm: designer));
    expect(find.byKey(const ValueKey('umg_editor_panel_enabled')), findsOneWidget);
    expect(find.byKey(const ValueKey('umg_editor_panel_cap_level')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('umg_editor_panel_cap_assets')));
    await tester.pump();
    expect(designer.document.editorPanel!.allows(LuminaEditorPanelCapability.assets), isTrue);
    await tester.tap(find.byKey(const ValueKey('umg_editor_panel_enabled')));
    await tester.pump();
    expect(designer.document.isEditorPanel, isFalse);
    await show(UmgPalette(vm: designer));
    expect(find.byKey(const ValueKey('umg_palette_category_editor')), findsNothing, reason: 'never in a game widget');
    // The designer's theme reads finish before the project is deleted.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    designer.dispose();
  });
}
