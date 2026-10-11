import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';

/// The editor library's asset nodes on a real project with three real
/// imported meshes: listing a folder by type, a reference-safe rename that
/// re-points the level actor using the mesh, the host asset picker, and a
/// dismissed confirm dialog.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late String panelId;

  EpwBuilder assetTools() {
    final b = EpwBuilder('EPW_AssetTools',
        LuminaEditorPanelInfo(title: 'Asset Tools', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.assets}));
    b.element(UmgWidgetType.button, 'PickButton', props: {'label': 'Pick'});
    b.element(UmgWidgetType.button, 'ConfirmButton', props: {'label': 'Confirm'});
    for (final v in ['Renamed', 'Picked', 'Answer', 'Error']) {
      b.variable(v, 'String', '');
    }
    b.variable('Listed', 'Array:String', <Object?>[]);
    // ListProps → Listed = List Assets (contents/Props, StaticMesh).
    b.customEvent('list', 'ListProps');
    b.node('editor_list_assets', 'assets', {'folder': 'contents/Props', 'type_filter': 'StaticMesh'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_listed', {'variable': 'Listed'});
    b.wire('list', 'exec_out', 'set_listed');
    b.wire('assets', 'return_value', 'set_listed', 'value');
    // RenameIt (Path, Name) → Rename Asset → Completed: Renamed / Failed: Error.
    b.customEvent('rename', 'RenameIt', ['Path', 'Name']);
    b.node('editor_rename_asset', 'do_rename');
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_renamed', {'variable': 'Renamed'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_error', {'variable': 'Error'});
    b.wire('rename', 'exec_out', 'do_rename');
    b.wire('rename', 'Path', 'do_rename', 'asset_path');
    b.wire('rename', 'Name', 'do_rename', 'new_name');
    b.wire('do_rename', 'completed', 'set_renamed');
    b.wire('do_rename', 'new_path', 'set_renamed', 'value');
    b.wire('do_rename', 'failed', 'set_error');
    b.wire('do_rename', 'error', 'set_error', 'value');
    // Pick → Pick Asset (StaticMesh) → Picked / "cancelled".
    b.onElement('pick', 'PickButton', 'OnClicked');
    b.node('editor_pick_asset', 'do_pick', {'type_filter': 'StaticMesh'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_picked', {'variable': 'Picked'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_cancelled', {'variable': 'Picked', 'value': 'cancelled'});
    b.wire('pick', 'exec_out', 'do_pick');
    b.wire('do_pick', 'picked', 'set_picked');
    b.wire('do_pick', 'asset_path', 'set_picked', 'value');
    b.wire('do_pick', 'cancelled', 'set_cancelled');
    // Confirm → Show Confirm Dialog → yes / no.
    b.onElement('confirm', 'ConfirmButton', 'OnClicked');
    b.node('editor_show_confirm_dialog', 'ask', {'title': 'Delete?', 'message': 'Really?', 'confirm_label': 'Delete'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'yes', {'variable': 'Answer', 'value': 'yes'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'no', {'variable': 'Answer', 'value': 'no'});
    b.wire('confirm', 'exec_out', 'ask');
    b.wire('ask', 'confirmed', 'yes');
    b.wire('ask', 'cancelled', 'no');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('AssetPanels');
    await assetTools().writeTo(project.projectPath('contents/editor/EPW_AssetTools.lmas'));
    vm = await project.open();
    await vm.ensureDefaultLevelAssets();
    for (final glb in ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/aircon_small.glb', 'Props/Access_cards/access_card_blue.glb']) {
      await vm.processImportPipeline(sourceFilePath: testAsset(glb));
    }
    // The three meshes move into contents/Props (a real, reference-safe move).
    for (final a in vm.realAssets.where((a) => a.type == AssetType.filamesh).toList()) {
      vm.moveAsset(a.lmasPath!, project.projectPath('contents/Props'));
    }
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panels.isNotEmpty, reason: 'the panel to be found');
    panelId = vm.editorPanels.panels.keys.single;
    await vm.editorPanels.trustProjectPanels();
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  EditorPanelInstance openPanel() {
    vm.editorPanelDocking.open(panelId);
    return vm.editorPanels.instancesOf(panelId).single;
  }

  test('List Assets (contents/Props, StaticMesh) lists the three meshes', () async {
    final panel = openPanel();
    panel.script!.callBlueprint('ListProps', const {});
    final listed = (panel.script!.variables['Listed'] as List).cast<String>();
    expect(listed, hasLength(3));
    expect(listed.every((p) => p.startsWith('contents/Props/') && p.endsWith('.lmas')), isTrue);
  });

  test('Rename Asset is reference-safe: the level actor using the mesh follows', () async {
    final panel = openPanel();
    final barrel = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
    final before = {for (final a in vm.actors) a.id};
    await vm.spawnActorFromAsset(barrel, location: [0, 0, 0]);
    final actor = vm.actors.firstWhere((a) => !before.contains(a.id));
    panel.script!.callBlueprint('RenameIt', {'Path': barrel.relativePath, 'Name': 'SM_RedBarrel'});
    await until(() => '${panel.script!.variables['Renamed']}'.isNotEmpty || '${panel.script!.variables['Error']}'.isNotEmpty);
    expect(panel.script!.variables['Error'], '');
    expect(panel.script!.variables['Renamed'], 'contents/Props/SM_RedBarrel.lmas');
    expect(actor.meshAssetPath, endsWith('SM_RedBarrel.lmas'));
    expect(vm.realAssets.any((a) => a.relativePath == 'contents/Props/SM_RedBarrel.lmas'), isTrue);
  });

  Future<EditorPanelInstance> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 340, height: 600, child: EditorPanelView(host: vm.editorPanels, panelId: panelId))),
    ));
    await tester.pump();
    await tester.pump();
    return vm.editorPanels.instancesOf(panelId).single;
  }

  testWidgets('Pick Asset opens the host asset picker and Picked delivers the chosen path', (tester) async {
    final panel = await pumpPanel(tester);
    await tester.tap(find.text('Pick'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('editor_panel_pick_asset')), findsOneWidget);
    final item = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('asset_picker_item_aircon_small'));
    expect(item, findsOneWidget);
    await tester.tap(item);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(panel.script!.variables['Picked'], 'contents/Props/aircon_small.lmas');
    expect(find.byKey(const ValueKey('editor_panel_pick_asset')), findsNothing);
  });

  testWidgets('Show Confirm Dialog answers Cancelled when dismissed', (tester) async {
    final panel = await pumpPanel(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('editor_panel_confirm_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_panel_confirm_cancel')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(panel.script!.variables['Answer'], 'no');
  });
}
