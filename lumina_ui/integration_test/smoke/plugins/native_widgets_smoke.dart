import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginPanelStateOp, PluginPanelStatePatch;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/editor_canvas.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../test/ui/editor_panels/editor_panel_fixture.dart' show EpwBuilder, UmgWidgetType;

const String _scenario = 'native timeline, table and canvas in an editor panel';

/// The Motion Studio panel: a Viewport showing the mannequin turning under
/// a Canvas overlay of markers, a Table of the level's actors (labels
/// editable), a Timeline bound to the Viewport's mannequin and a status
/// line. Its graph adds the mannequin on Construct, renames an actor when
/// a label cell is committed (one undoable step), and writes what the user
/// did (keys moved, a marker clicked) into the status line.
EpwBuilder motionStudioPanel({required String mesh, required String animation}) {
  final b = EpwBuilder('EPW_MotionStudio',
      LuminaEditorPanelInfo(title: 'Motion Studio', icon: 'film', dock: LuminaEditorPanelDock.tab, capabilities: {LuminaEditorPanelCapability.level}));
  final top = b.element(UmgWidgetType.horizontalBox, 'Top');
  top.slot
    ..fill = true
    ..flex = 3;
  final stage = b.element(UmgWidgetType.overlay, 'Stage', parent: top.id);
  stage.slot
    ..fill = true
    ..flex = 2;
  b.element(UmgWidgetType.viewport, 'Preview', props: {...UmgWidgetType.viewport.defaultProps(), 'background': 'sky'}, parent: stage.id);
  b.element(UmgWidgetType.editorCanvas, 'Marks', parent: stage.id, props: {
    'space': 'normalized',
    'background': '#00000000',
    'items': [
      {'id': 'frame', 'kind': 'rect', 'rect': [0.02, 0.03, 0.96, 0.94], 'stroke': '#FB7C0166', 'width': 1},
      {'id': 'pelvis', 'kind': 'circle', 'center': [0.5, 0.55], 'radius': 0.018, 'fill': '#F59E0B', 'stroke': '#111111', 'hit': true, 'cursor': 'pointer'},
      {'id': 'head', 'kind': 'circle', 'center': [0.5, 0.2], 'radius': 0.018, 'fill': '#4ADE80', 'stroke': '#111111', 'hit': true, 'cursor': 'pointer'},
      {'id': 'path', 'kind': 'path', 'path': 'M 0.1 0.9 Q 0.5 0.75 0.9 0.9', 'stroke': '#60A5FA', 'width': 2},
      {'id': 'caption', 'kind': 'text', 'rect': [0.04, 0.05, 0.6, 0.05], 'text': 'Motion Studio · markers', 'fontSize': 11, 'fill': '#D6D6D6'},
    ],
  });
  final table = b.element(UmgWidgetType.editorTable, 'Actors', parent: top.id, props: {
    'columns': [
      {'id': 'label', 'label': 'Label', 'kind': 'text', 'editable': true, 'width': 170},
      {'id': 'type', 'label': 'Type', 'kind': 'text', 'width': 110},
      {'id': 'x', 'label': 'X (cm)', 'kind': 'number', 'width': 80},
      {'id': 'mesh', 'label': 'Mesh', 'kind': 'assetRef', 'typeFilter': 'StaticMesh,SkeletalMesh', 'width': 220},
    ],
    'rows': <Object?>[],
    'selection': 'multi',
    'filter': true,
  });
  table.slot
    ..fill = true
    ..flex = 1;
  final timeline = b.element(UmgWidgetType.editorTimeline, 'Motion', props: {
    'fps': 30,
    'length': 240,
    'zoom': 4,
    'snap': 1,
    'loop': true,
    'tracks': [
      {'id': 'prompts', 'label': 'Text prompts', 'icon': 'text', 'group': 'Prompts', 'kind': 'clips'},
      {'id': 'body', 'label': 'Full Body', 'icon': 'person-standing', 'group': 'Constraints', 'kind': 'keys'},
      {'id': 'root', 'label': '2D Root', 'icon': 'move', 'group': 'Constraints', 'kind': 'keys'},
      {'id': 'lhand', 'label': 'Left Hand', 'icon': 'hand', 'group': 'Constraints', 'kind': 'keys'},
      {'id': 'rfoot', 'label': 'Right Foot', 'icon': 'footprints', 'group': 'Constraints', 'kind': 'keys'},
    ],
    'clips': [
      {'id': 'p1', 'track': 'prompts', 'start': 0, 'end': 90, 'text': 'turn left in place', 'minLength': 60, 'maxLength': 300, 'editableText': true},
      {'id': 'p2', 'track': 'prompts', 'start': 90, 'end': 180, 'text': 'stand idle', 'minLength': 60, 'maxLength': 300, 'editableText': true},
    ],
    'keys': [
      {'id': 'k1', 'track': 'body', 'frame': 30},
      {'id': 'k2', 'track': 'root', 'frame': 60, 'style': 'circle'},
      {'id': 'k3', 'track': 'lhand', 'frame': 120},
      {'id': 'k4', 'track': 'rfoot', 'frame': 150, 'style': 'square'},
    ],
    'boundViewport': {'element': 'Preview', 'node': 'skeletal_1'},
  });
  timeline.slot
    ..fill = true
    ..flex = 2;
  b.element(UmgWidgetType.statusLine, 'Status', props: {'text': 'Ready', 'tone': 'info'});

  // Construct: the mannequin turning in place, framed.
  b.node(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct');
  b.node(LuminaBlueprintNodeLibrary.getWidgetVariable, 'preview', {'element': 'Preview'});
  b.node('viewport_add_skeletal_mesh', 'add', {'skeletal_mesh': mesh});
  b.node('viewport_play_animation', 'play', {'animation': animation});
  b.node('viewport_frame_node', 'frame');
  b.chain(['construct', 'add', 'play', 'frame']);
  for (final n in ['add', 'play', 'frame']) {
    b.wire('preview', 'return_value', n, 'target');
  }
  b.wire('add', 'return_value', 'play', 'node_id');
  b.wire('add', 'return_value', 'frame', 'node_id');
  // A label cell committed: rename the actor (one undo step).
  b.onElement('cell', 'Actors', LuminaEditorWidgetEvents.onCellCommitted);
  b.node('editor_set_actor_label', 'rename');
  b.node('editor_set_element_state', 'renamed', {'element': 'Status', 'key': 'text', 'value': 'Actor renamed'});
  b.chain(['cell', 'rename', 'renamed']);
  b.wire('cell', 'row_id', 'rename', 'actor_id');
  b.wire('cell', 'text', 'rename', 'label');
  // Keys moved / a marker clicked: the status line says so.
  b.onElement('keys', 'Motion', LuminaEditorWidgetEvents.onKeyCommit);
  b.node('editor_set_element_state', 'moved', {'element': 'Status', 'key': 'text', 'value': 'Keys moved'});
  b.wire('keys', 'exec_out', 'moved');
  b.onElement('mark', 'Marks', LuminaEditorWidgetEvents.onItemClicked);
  b.node('editor_set_element_state', 'marked', {'element': 'Status', 'key': 'text'});
  b.wire('mark', 'exec_out', 'marked');
  b.wire('mark', 'item_id', 'marked', 'value');
  return b;
}

/// The native widgets smoke: a real project and level (props from
/// `test-assets/Props/`, the UEFN mannequin and its turn in place from
/// `test-assets/FBX/GameAnimationSample/` through the real importer), a user
/// plugin whose editor panel (`dock: "tab"`) holds a Viewport bound to a
/// Timeline, a Table of the level's actors and a Canvas overlay. Scrub and
/// play the timeline (the mannequin animates), drag a key, edit an actor's
/// label in the table and undo it, click a canvas marker.
void nativeWidgetsSmoke(IntegrationTestWidgetsFlutterBinding binding, Future<void> Function(WidgetTester, {int frames}) settle) {
  testWidgets(_scenario, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final meshFbx = File('$assets/FBX/GameAnimationSample/SKM_UEFN_Mannequin.fbx');
    final turnFbx = File('$assets/FBX/GameAnimationSample/M_Neutral_Stand_Turn_090_L.fbx');
    if (!meshFbx.existsSync() || !turnFbx.existsSync()) return markTestSkipped('test-assets/FBX/GameAnimationSample missing');
    const props = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'Props/Barrels/fuel_barrel_red.glb'];
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('native_widgets_smoke_');
    final previousUserDir = UserPluginDir.override;
    final previousDataDir = LuminaDataDir.override;
    UserPluginDir.override = Directory(p.join(temp.path, 'user_plugins'))..createSync();
    LuminaDataDir.override = Directory(p.join(temp.path, 'data'))..createSync();
    try {
      // A real project; the mannequin and its turn in place through the FBX importer.
      final projectsDir = Directory(p.join(temp.path, 'projects'))..createSync();
      final pDir = Directory(p.join(projectsDir.path, 'MotionSmoke'))..createSync();
      const project = LuminaProject(projectName: 'MotionSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File(p.join(pDir.path, 'MotionSmoke.lmproject')).writeAsStringSync(jsonEncode(project.toMap()));
      final mesh = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: pDir.path, sourceFilePath: meshFbx.path)))!;
      expect(mesh.isSuccess, isTrue, reason: mesh.error);
      final turn = (await tester.runAsync(
          () => ImportAssetUseCase()(projectDir: pDir.path, sourceFilePath: turnFbx.path, targetSkeletonPath: mesh.asset!.relativePath)))!;
      expect(turn.isSuccess, isTrue, reason: turn.error);

      // The user plugin: content only, its one editor panel.
      final plugin = Directory(p.join(UserPluginDir.override!.path, 'motion_studio'))..createSync(recursive: true);
      File(p.join(plugin.path, 'motion_studio.lmplugin')).writeAsStringSync(jsonEncode({
        'name': 'motion_studio',
        'friendly_name': 'Motion Studio',
        'version': '1.0.0',
        'description': 'Timeline, table and canvas in an editor panel',
        'category': 'Editor',
        'can_contain_content': true,
      }));
      await motionStudioPanel(mesh: mesh.asset!.relativePath, animation: turn.asset!.relativePath)
          .writeTo(p.join(plugin.path, 'content', 'EPW_MotionStudio.lmas'));

      final vm = EditorViewModel(initialProject: project, projectDirPath: projectsDir.path);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final prop in props.toSet()) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '$assets/$prop'));
      }
      vm.refreshAssets();
      final barrel = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName == 'fuel_barrel_red.lmas');
      final ac = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName == 'ac_unit_a_300x300.lmas');
      final spawn = [(barrel, [-260.0, 120.0, 0.0]), (ac, [40.0, -200.0, 0.0]), (barrel, [240.0, 140.0, 0.0])];
      for (final (asset, at) in spawn) {
        await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: at));
      }
      expect(vm.actors.length, greaterThanOrEqualTo(3));
      await tester.runAsync(() => vm.pluginsScanned);
      await tester.runAsync(vm.rescanPlugins);
      final enabled = (await tester.runAsync(() => vm.enablePlugin('motion_studio', true)))!;
      expect(enabled.restartRequired, isFalse);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      final used = [...props.toSet(), 'FBX/GameAnimationSample/SKM_UEFN_Mannequin.fbx', 'FBX/GameAnimationSample/M_Neutral_Stand_Turn_090_L.fbx'];
      Future<void> shot(String label) async {
        SmokeArtifacts.saveScreenshot('$_scenario: $label',
            await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)), usedAssets: used);
        await rec.hold(const Duration(milliseconds: 600));
      }

      Future<void> until(bool Function() condition, String what, {int tries = 200}) async {
        for (var i = 0; i < tries && !condition(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await settle(tester, frames: 2);
          await rec.capture();
        }
        expect(condition(), isTrue, reason: what);
      }

      vm.frameLevelBounds();
      await rec.hold(const Duration(milliseconds: 800));

      // Window ▸ Editor Panels ▸ Motion Studio: a tab.
      const panelId = 'motion_studio/content/EPW_MotionStudio.lmas';
      await until(() => vm.editorPanels.panel(panelId) != null, 'the panel discovered');
      expect(vm.editorPanels.panel(panelId)!.errors, isEmpty);
      vm.commands.execute(EditorPanelDocking.commandId(panelId));
      await until(() => find.byKey(const ValueKey('editor_panel_view_$panelId')).evaluate().isNotEmpty, 'the panel tab');
      final panel = vm.editorPanels.instancesOf(panelId).single;
      expect(panel.script, isNotNull, reason: 'trusted with its plugin');

      // The level's actors pushed into the Table in one patch (what a
      // plugin process sends with host.panelState).
      void pushRows() => vm.editorPanels.links.patch('motion_studio', PluginPanelStatePatch('content/EPW_MotionStudio.lmas', [
            PluginPanelStateOp('Actors', {
              'rows': [
                for (final a in vm.actors)
                  {
                    'id': a.id,
                    'cells': {'label': a.name, 'type': a.type, 'x': a.location[0], 'mesh': a.meshAssetPath},
                    'tone': a.meshAssetPath == null ? 'warning' : 'normal',
                  },
              ],
            }),
          ]));
      pushRows();
      // The mannequin loads and turns in the panel's Viewport.
      await until(() {
        final c = panel.viewports['Preview'];
        return c != null && c.runtime.isReady && c.runtime.componentOf('skeletal_1') is LuminaAnimatedMeshComponent;
      }, 'the mannequin in the panel Viewport', tries: 400);
      await until(() => find.byKey(ValueKey('editor_table_Actors_row_${vm.actors.first.id}')).evaluate().isNotEmpty, 'the actor rows');
      await rec.hold(const Duration(seconds: 2));
      await shot('the Motion Studio panel: viewport, canvas overlay, actor table and timeline');

      final timeline = tester.state<EditorTimelineState>(find.byType(EditorTimeline));
      final controller = panel.viewports['Preview']!;
      final skeleton = controller.runtime.componentOf('skeletal_1')! as LuminaAnimatedMeshComponent;
      Offset rulerAt(int frame) =>
          tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_Motion_ruler'))) + Offset(timeline.model.layout().xOf(frame), 11);

      // Scrub the playhead across the turn: the mannequin follows.
      await rec.drag(rulerAt(0), rulerAt(45), steps: 45);
      expect(timeline.model.playhead.value, 45);
      final clip = skeleton.clipDuration(skeleton.currentClip!);
      expect(skeleton.currentTime, anyOf(closeTo(1.5, 1e-3), closeTo(1.5 % clip, 1e-3)), reason: 'frame 45 at 30 fps drives the Viewport');
      await rec.hold(const Duration(seconds: 1));
      await shot('scrubbed to frame 45: the mannequin pose follows the playhead');

      // Play: the playhead runs and the mannequin follows it.
      await tester.tap(find.byKey(const ValueKey('editor_timeline_Motion_play')));
      final poses = <double>{};
      final heads = <double>[];
      for (var i = 0; i < 5; i++) {
        await rec.hold(const Duration(milliseconds: 500));
        heads.add(timeline.model.playhead.value);
        poses.add(double.parse(skeleton.currentTime.toStringAsFixed(3)));
      }
      debugPrint('[native_widgets_smoke] playhead $heads, animation times $poses');
      expect(timeline.model.playing.value, isTrue);
      expect(heads.toSet().length, greaterThan(3), reason: 'the playhead advances while playing');
      expect(poses.length, greaterThan(3), reason: 'the mannequin pose follows the playhead');
      await shot('playing: the mannequin turns with the playhead');
      await tester.tap(find.byKey(const ValueKey('editor_timeline_Motion_play')));
      await rec.hold(const Duration(milliseconds: 500));
      expect(timeline.model.playing.value, isFalse);

      // Drag the 2D Root key from frame 60 to 75.
      final l = timeline.model.layout();
      final row = l.rowOf('root')!;
      final tracks = tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_Motion_tracks')));
      Offset keyAt(int f) => tracks + Offset(l.xOf(f), row.top + row.height / 2);
      await rec.drag(keyAt(60), keyAt(75), steps: 30);
      expect(timeline.model.keys.firstWhere((k) => k.id == 'k2').frame, 75);
      expect(panel.element('Status')!['text'], 'Keys moved', reason: 'On Key Commit ran the graph once');
      await shot('the 2D Root key dragged to frame 75');

      // Rename the barrel in the table, then undo.
      final target = vm.actors.firstWhere((a) => a.meshAssetPath?.endsWith('fuel_barrel_red.lmas') ?? false);
      final oldName = target.name;
      final cell = find.byKey(ValueKey('editor_table_Actors_cell_${target.id}_label'));
      final at = tester.getCenter(cell);
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.down(at, timeStamp: const Duration(seconds: 100));
      await g.up(timeStamp: const Duration(seconds: 100, milliseconds: 60));
      await rec.hold(const Duration(milliseconds: 150));
      await g.down(at, timeStamp: const Duration(seconds: 100, milliseconds: 200));
      await g.up(timeStamp: const Duration(seconds: 100, milliseconds: 260));
      await g.removePointer();
      await rec.hold(const Duration(milliseconds: 300));
      await rec.typeText(find.byKey(const ValueKey('editor_table_cell_field')), 'Barrel_Hero');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await rec.hold(const Duration(milliseconds: 500));
      expect(vm.actors.firstWhere((a) => a.id == target.id).name, 'Barrel_Hero');
      expect(panel.element('Status')!['text'], 'Actor renamed');
      await shot('the barrel renamed from its table cell');
      vm.commands.execute('edit.undo');
      pushRows();
      await rec.hold(const Duration(seconds: 1));
      expect(vm.actors.firstWhere((a) => a.id == target.id).name, oldName, reason: 'Edit ▸ Undo restores the label');
      expect(find.descendant(of: cell, matching: find.text(oldName)), findsOneWidget);
      await shot('Edit ▸ Undo restores the label');

      // Click the head marker on the canvas overlay.
      final canvas = tester.getRect(find.byType(EditorCanvas));
      await tester.tapAt(Offset(canvas.left + canvas.width * 0.5, canvas.top + canvas.height * 0.2), kind: PointerDeviceKind.mouse);
      await rec.hold(const Duration(milliseconds: 600));
      expect(panel.element('Status')!['text'], 'head');
      await shot('the head marker clicked on the canvas overlay');

      // Play again for the closing frames.
      await tester.tap(find.byKey(const ValueKey('editor_timeline_Motion_play')));
      await rec.hold(const Duration(seconds: 2));
      await tester.tap(find.byKey(const ValueKey('editor_timeline_Motion_play')));
      await rec.hold(const Duration(milliseconds: 500));
      rec.save(_scenario, usedAssets: used);
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
