import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipEncoder;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../test/ui/editor_panels/editor_panel_fixture.dart' show EpwBuilder, UmgWidgetType;

/// The Prop Tools editor panel: a toolbar with "Line up selected", the
/// level's actors in a Tree View, a mesh Asset Picker and a status line.
/// Its graph fills the tree on Construct and on every level edit, selects
/// what the tree selects, and lines the selected actors up 150 cm apart in
/// one "Line up" transaction.
EpwBuilder propToolsPanel({String buttonLabel = 'Line up selected'}) {
  final b = EpwBuilder(
      'EPW_PropTools',
      LuminaEditorPanelInfo(
          title: 'Prop Tools', icon: 'box', dock: LuminaEditorPanelDock.right, minWidth: 300, capabilities: {LuminaEditorPanelCapability.level}));
  final toolbar = b.element(UmgWidgetType.editorToolbar, 'Toolbar');
  b.element(UmgWidgetType.button, 'LineUpButton', props: {'label': buttonLabel}, parent: toolbar.id);
  final section = b.element(UmgWidgetType.editorSection, 'LevelSection', props: {'title': 'Level actors'});
  final box = b.element(UmgWidgetType.sizeBox, 'TreeBox', props: {'width': 300.0, 'height': 260.0}, parent: section.id);
  b.element(UmgWidgetType.treeView, 'ActorTree', parent: box.id);
  final row = b.element(UmgWidgetType.propertyRow, 'MeshRow', props: {'label': 'Preview mesh'});
  b.element(UmgWidgetType.assetPicker, 'MeshPicker', props: {'typeFilter': 'StaticMesh', 'placeholder': 'Pick a mesh'}, parent: row.id);
  final preview = b.element(UmgWidgetType.sizeBox, 'PreviewBox', props: {'width': 300.0, 'height': 200.0});
  b.element(UmgWidgetType.viewport, 'PreviewViewport', parent: preview.id);
  b.element(UmgWidgetType.statusLine, 'Status', props: {'text': 'Ready', 'tone': 'info'});

  // Construct and On Level Changed → the tree's items.
  for (final (event, id) in [(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'), (LuminaEditorEventNodes.levelChanged, 'level')]) {
    b.node(event, id);
    b.node('editor_get_level_actor_tree', '${id}_tree');
    b.node('editor_set_element_state', '${id}_items', {'element': 'ActorTree', 'key': 'items'});
    b.wire(id, 'exec_out', '${id}_items');
    b.wire('${id}_tree', 'return_value', '${id}_items', 'value');
  }
  // The tree's selection is the level selection.
  b.onElement('picked_rows', 'ActorTree', LuminaEditorWidgetEvents.onItemSelected);
  b.node('editor_select_actors', 'select');
  b.wire('picked_rows', 'exec_out', 'select');
  b.wire('picked_rows', 'selected_ids', 'select', 'actor_ids');
  // A picked mesh → the Viewport preview and the status line.
  b.onElement('mesh', 'MeshPicker', LuminaEditorWidgetEvents.onAssetPicked);
  b.node(LuminaBlueprintNodeLibrary.getWidgetVariable, 'viewport', {'element': 'PreviewViewport'});
  b.node('viewport_clear', 'preview_clear');
  b.node('viewport_add_static_mesh', 'preview_mesh');
  b.node('editor_set_element_state', 'mesh_status', {'element': 'Status', 'key': 'text'});
  b.chain(['mesh', 'preview_clear', 'preview_mesh', 'mesh_status']);
  b.wire('viewport', 'return_value', 'preview_clear', 'target');
  b.wire('viewport', 'return_value', 'preview_mesh', 'target');
  b.wire('mesh', 'asset_path', 'preview_mesh', 'mesh');
  b.wire('mesh', 'asset_path', 'mesh_status', 'value');
  // Line up selected: one transaction over the selection.
  b.onElement('line_up', 'LineUpButton', 'OnClicked');
  b.node('editor_begin_transaction', 'begin', {'label': 'Line up'});
  b.node('editor_get_selected_actors', 'selected');
  b.node('for_each_loop', 'each', {'type': 'string'});
  b.node('int_to_float', 'index_f');
  b.node('float_multiply', 'spacing', {'b': 150.0});
  b.node('make_vector', 'at');
  b.node('make_transform', 'xf');
  b.node('editor_set_actor_transform', 'move');
  b.node('editor_end_transaction', 'end');
  b.node('editor_set_element_state', 'done', {'element': 'Status', 'key': 'text', 'value': 'Lined up'});
  b.wire('line_up', 'exec_out', 'begin');
  b.wire('begin', 'exec_out', 'each');
  b.wire('selected', 'return_value', 'each', 'array');
  b.wire('each', 'loop_body', 'move');
  b.wire('each', 'array_element', 'move', 'actor_id');
  b.wire('each', 'array_index', 'index_f', 'a');
  b.wire('index_f', 'return_value', 'spacing', 'a');
  b.wire('spacing', 'return_value', 'at', 'x');
  b.wire('at', 'return_value', 'xf', 'location');
  b.wire('xf', 'return_value', 'move', 'transform');
  b.wire('each', 'completed', 'end');
  b.wire('begin', 'return_value', 'end', 'transaction');
  b.wire('end', 'exec_out', 'done');
  return b;
}

/// The editor panel smoke: a content-only plugin imported from a zip and
/// enabled with no build, its panel docked right, a mesh picked, three
/// actors selected in its tree and lined up in one undoable step, and the
/// panel live-reloaded after a designer edit.
void editorPanelSmoke(IntegrationTestWidgetsFlutterBinding binding, Future<void> Function(WidgetTester, {int frames}) settle) {
  testWidgets('editor panel widget blueprint docked and live-reloaded without a build', (tester) async {
    const name = 'editor panel widget blueprint docked and live-reloaded without a build';
    const props = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/aircon_small.glb', 'Props/Access_cards/access_card_blue.glb'];
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('epw_smoke_');
    final previousUserDir = UserPluginDir.override;
    final previousDataDir = LuminaDataDir.override;
    UserPluginDir.override = Directory(p.join(temp.path, 'user_plugins'))..createSync();
    LuminaDataDir.override = Directory(p.join(temp.path, 'data'))..createSync();
    try {
      // The user plugin: content only (a .lmplugin and the panel), zipped.
      final source = Directory(p.join(temp.path, 'src', 'prop_tools'))..createSync(recursive: true);
      final manifest = jsonEncode({
        'name': 'prop_tools',
        'friendly_name': 'Prop Tools',
        'version': '1.0.0',
        'description': 'Line up props from an editor panel',
        'category': 'Editor',
        'can_contain_content': true,
      });
      final panelBytes = propToolsPanel().bytes();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('prop_tools/prop_tools.lmplugin', utf8.encode(manifest)))
        ..addFile(ArchiveFile.bytes('prop_tools/content/EPW_PropTools.lmas', panelBytes));
      final zip = File(p.join(source.parent.path, 'prop_tools-1.0.0.zip'))..writeAsBytesSync(ZipEncoder().encode(archive));

      // A real project and level of real props.
      final projectsDir = Directory(p.join(temp.path, 'projects'))..createSync();
      final pDir = Directory(p.join(projectsDir.path, 'PanelSmoke'))..createSync();
      const project = LuminaProject(projectName: 'PanelSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File(p.join(pDir.path, 'PanelSmoke.lmproject')).writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: projectsDir.path);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final prop in props) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$prop'));
      }
      vm.refreshAssets();
      final meshes = [
        for (final prop in props) vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName == '${p.basenameWithoutExtension(prop)}.lmas'),
      ];
      final spots = [
        [-220.0, 140.0, 0.0],
        [60.0, -180.0, 0.0],
        [260.0, 90.0, 0.0],
      ];
      for (var i = 0; i < meshes.length; i++) {
        await tester.runAsync(() => vm.spawnActorFromAsset(meshes[i], location: spots[i]));
      }
      final propIds = [for (final a in vm.actors) if (meshes.any((m) => a.meshAssetPath?.endsWith(m.fileName) ?? false)) a.id];
      expect(propIds, hasLength(3));
      await tester.runAsync(() => vm.pluginsScanned);
      vm.pluginZipPicker = () async => zip.path;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      Future<void> shot(String label) async {
        SmokeArtifacts.saveScreenshot('$name: $label',
            await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)), usedAssets: props);
        await rec.hold(const Duration(milliseconds: 800));
      }

      Future<void> until(bool Function() condition, String what) async {
        for (var i = 0; i < 150 && !condition(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await settle(tester, frames: 3);
        }
        expect(condition(), isTrue, reason: what);
        await settle(tester, frames: 6);
      }

      // Plugins ▸ Plugin Manager ▸ Import from Zip: the confirmation lists the panel.
      await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Plugins')));
      await settle(tester);
      await tester.tap(find.text('Plugin Manager...'));
      await settle(tester, frames: 30);
      await tester.tap(find.byKey(const ValueKey('plugin_import_zip')));
      await until(() => find.byKey(const ValueKey('plugin_import_done_dialog')).evaluate().isNotEmpty, 'the import confirmation');
      expect(find.byKey(const ValueKey('editor_panel_summary_list')), findsOneWidget);
      expect(find.textContaining('Prop Tools · right'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await shot('the zip imported; its editor panel is listed with its capabilities');
      await tester.tap(find.byKey(const ValueKey('plugin_import_ok')));
      await settle(tester, frames: 20);

      // Enabled in the Plugin Manager: content only, no build, no restart.
      final pluginSwitch = find.descendant(
        of: find.ancestor(of: find.text('Prop Tools').first, matching: find.byType(Card)),
        matching: find.byType(Switch),
      );
      await tester.tap(pluginSwitch);
      await until(() => vm.pluginRegistry.entries.any((e) => e.descriptor.name == 'prop_tools' && e.enabled), 'the plugin enabled');
      const panelId = 'prop_tools/content/EPW_PropTools.lmas';
      await until(() => vm.editorPanels.panel(panelId) != null, 'the panel discovered');
      expect(find.byType(EditorBuildSplash), findsNothing, reason: 'no project editor build');
      expect(vm.pluginRestartRequired, isFalse);
      expect(find.text('Restart required'), findsNothing);
      await rec.hold(const Duration(seconds: 1));
      await shot('the content plugin enabled with no build');

      // Back to the level: the panel docked right (Window ▸ Editor Panels ▸ Prop Tools).
      vm.selectTab(0);
      await settle(tester, frames: 10);
      vm.commands.execute(EditorPanelDocking.commandId(panelId));
      await until(() => find.byKey(const ValueKey('editor_panel_view_$panelId')).evaluate().isNotEmpty, 'the docked panel');
      final panel = vm.editorPanels.instancesOf(panelId).single;
      expect(panel.script, isNotNull);
      expect(find.ancestor(of: find.byKey(const ValueKey('editor_panel_view_$panelId')), matching: find.byKey(const ValueKey('right_dock'))),
          findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await shot('Prop Tools docked right');
      // The panel Viewport's central half, read from the captured frame.
      Future<img.Image> viewportCentre() async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        final rect = tester.getRect(find.byType(LuminaUmgViewport));
        final frame = img.decodePng(png)!;
        return img.copyCrop(frame,
            x: (rect.left + rect.width / 4).round(), y: (rect.top + rect.height / 4).round(), width: (rect.width / 2).round(), height: (rect.height / 2).round());
      }

      // The share of [now]'s pixels that differ clearly from [before].
      double changed(img.Image before, img.Image now) {
        var n = 0;
        for (final px in now) {
          final b = before.getPixel(px.x, px.y);
          if ((px.r - b.r).abs() + (px.g - b.g).abs() + (px.b - b.b).abs() > 90) n++;
        }
        return n / (now.width * now.height);
      }

      final emptyViewport = await viewportCentre();

      // Pick the barrel mesh in the panel's asset picker.
      await tester.tap(find.byKey(const ValueKey('asset_picker_value')));
      await settle(tester, frames: 10);
      await tester.enterText(find.byKey(const ValueKey('asset_picker_search')), 'fuel_barrel');
      await settle(tester, frames: 5);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, frames: 10);
      expect(panel.element('Status')!['text'], meshes.first.relativePath);
      // The Viewport element previews the picked mesh.
      final scene = LuminaViewportScene.of(panel.element('PreviewViewport')!);
      expect(scene.nodes.map((n) => n['asset']), [meshes.first.relativePath]);
      // The barrel loads, the untouched camera frames it: it fills the
      // Viewport's centre (the grid alone changes a few thin lines).
      var meshShare = 0.0;
      for (var i = 0; i < 60 && meshShare < 0.25; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await settle(tester, frames: 3);
        meshShare = changed(emptyViewport, await viewportCentre());
      }
      expect(meshShare, greaterThan(0.25), reason: 'the picked barrel is drawn and framed in the panel Viewport');
      await rec.hold(const Duration(seconds: 1));
      await shot('the barrel mesh picked in the panel');

      // Select the three props in the panel's tree.
      final folderChevron = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('editor_tree_chevron_ActorTree_type:'));
      final folderKeys = [for (final e in folderChevron.evaluate()) e.widget.key!];
      expect(folderKeys, isNotEmpty);
      for (final key in folderKeys) {
        await tester.tap(find.byKey(key));
        await settle(tester, frames: 6);
      }
      Finder rowOf(String id) => find.byKey(ValueKey('editor_tree_row_ActorTree_$id'));
      await tester.tap(rowOf(propIds[0]));
      await settle(tester, frames: 6);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(rowOf(propIds[1]));
      await settle(tester, frames: 6);
      await tester.tap(rowOf(propIds[2]));
      await settle(tester, frames: 6);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester, frames: 10);
      expect(vm.selectedActorIds, unorderedEquals(propIds));
      await rec.hold(const Duration(seconds: 1));
      await shot('three props selected in the panel tree');

      // Line up selected: one transaction; undo; redo.
      List<List<double>> spotsNow() => [for (final id in propIds) List<double>.of(vm.actors.firstWhere((a) => a.id == id).location)];
      final before = spotsNow();
      await tester.tap(find.text('Line up selected'));
      await settle(tester, frames: 20);
      expect(spotsNow().map((l) => l[1]).toSet(), {0.0}, reason: 'lined up on one row');
      expect(vm.transactions.undoLabel, 'Undo Line up');
      expect(panel.element('Status')!['text'], 'Lined up');
      await rec.hold(const Duration(seconds: 2));
      await shot('the three props lined up in one step');
      vm.commands.execute('edit.undo');
      await settle(tester, frames: 20);
      expect(spotsNow(), before);
      await rec.hold(const Duration(seconds: 2));
      await shot('Edit ▸ Undo restores all three');
      vm.commands.execute('edit.redo');
      await settle(tester, frames: 20);
      expect(spotsNow().map((l) => l[1]).toSet(), {0.0});
      await rec.hold(const Duration(seconds: 2));
      await shot('Edit ▸ Redo lines them up again');

      // The designer: a new button label, saved → the docked panel reloads in place.
      final file = vm.editorPanels.panel(panelId)!.entry.filePath;
      final runtime = vm.editorPanels.panel(panelId);
      vm.openAssetEditorByPath(file);
      await until(() => vm.openWidgetEditors.any((d) => d.isLoaded), 'the designer');
      final designer = vm.openWidgetEditors.firstWhere((d) => d.isLoaded);
      expect(designer.document.isEditorPanel, isTrue);
      expect(designer.readOnly, isFalse, reason: 'a user plugin is editable');
      await rec.hold(const Duration(seconds: 1));
      designer.setProp('n_LineUpButton', 'label', 'Line up (150 cm)');
      await settle(tester, frames: 10);
      await shot('the button label edited in the designer');
      final saved = await tester.runAsync(designer.save);
      expect(saved, isTrue);
      vm.selectTab(0);
      await until(() => !identical(vm.editorPanels.panel(panelId), runtime), 'the live reload');
      await settle(tester, frames: 20);
      expect(find.text('Line up (150 cm)'), findsOneWidget);
      expect(identical(vm.editorPanels.instancesOf(panelId).single, panel), isTrue, reason: 'reloaded in place');
      expect(panel.element('Status')!['text'], 'Lined up', reason: 'its state kept');
      await rec.hold(const Duration(seconds: 2));
      await shot('the saved label reloaded in the docked panel');
      await rec.hold(const Duration(seconds: 1));
      rec.save(name, usedAssets: props);
      vm.editorPanelDocking.close(panelId);
      await settle(tester, frames: 10);
    } finally {
      UserPluginDir.override = previousUserDir;
      LuminaDataDir.override = previousDataDir;
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
