import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginPanelStateOp, PluginPanelStatePatch;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_template.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_validator.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/editor_panel_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/palette.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panels/editor_panel_fixture.dart';

/// The native Timeline, Table and Canvas in the UMG designer: in the
/// Editor palette of editor panels only, their static Details editable, a
/// game widget holding one refused by the validator, and a plugin
/// process's `host.panelState` patch reaching a running Timeline.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;

  setUp(() async {
    project = await EditorPanelProject.create('NativeWidgets', plugins: ['motion_tools']);
    vm = await project.open();
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  Future<UmgEditorViewModel> designer(WidgetTester tester) async {
    final path = project.projectPath(
        (await tester.runAsync(() => createEditorPanelAsset(projectDirPath: project.projectDir.path, name: 'EPW_Native')))!);
    final d = UmgEditorViewModel(assetPath: path, projectDirPathOverride: project.projectDir.path);
    await tester.runAsync(d.load);
    return d;
  }

  Future<void> show(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: SizedBox(width: 320, child: w))));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  testWidgets('Timeline, Table and Canvas are in the Editor palette only for editor panel assets', (tester) async {
    final d = await designer(tester);
    await show(tester, UmgPalette(vm: d));
    for (final t in ['editorTimeline', 'editorTable', 'editorCanvas']) {
      expect(find.byKey(ValueKey('umg_palette_$t')), findsOneWidget, reason: t);
    }
    d.setEditorPanel(null);
    await show(tester, UmgPalette(vm: d));
    for (final t in ['editorTimeline', 'editorTable', 'editorCanvas']) {
      expect(find.byKey(ValueKey('umg_palette_$t')), findsNothing, reason: '$t never in a game widget');
    }
    await settle(tester);
    d.dispose();
  });

  testWidgets('their Details edit tracks, columns and space', (tester) async {
    final d = await designer(tester);
    final root = d.document.root.id;
    final timeline = d.addWidget(UmgWidgetType.editorTimeline, parentId: root)!;
    final table = d.addWidget(UmgWidgetType.editorTable, parentId: root)!;
    final canvas = d.addWidget(UmgWidgetType.editorCanvas, parentId: root)!;
    Future<void> edit(UmgNode node, String key, String text) async {
      await show(tester, UmgEditorElementSettings(vm: d, node: d.document.findNode(node.id)!));
      final field = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('umg_editor_prop_${key}_${node.id}_'));
      expect(field, findsOneWidget, reason: '$key of ${node.type.displayName}');
      await tester.enterText(field, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    await edit(timeline, 'tracks', '[{"id":"body","label":"Full Body","icon":"person-standing","kind":"keys"}]');
    expect(d.document.findNode(timeline.id)!.props['tracks'], [
      {'id': 'body', 'label': 'Full Body', 'icon': 'person-standing', 'kind': 'keys'},
    ]);
    await edit(table, 'columns', '[{"id":"bone","label":"Bone"},{"id":"mesh","label":"Mesh","kind":"assetRef","editable":true}]');
    expect((d.document.findNode(table.id)!.props['columns'] as List).length, 2);
    await edit(canvas, 'space', 'normalized');
    expect(d.document.findNode(canvas.id)!.props['space'], 'normalized');
    expect(d.validationErrors, isEmpty, reason: 'fine in an editor panel');
    await settle(tester);
    d.dispose();
  });

  test('a game Widget Blueprint containing a Timeline is a validator error', () {
    final doc = UmgDocument(root: UmgNode.create(UmgWidgetType.canvasPanel, name: 'Root', id: 'root'));
    doc.addChild('root', UmgNode.create(UmgWidgetType.editorTimeline, name: 'Motion', id: 'tl'));
    final errors = UmgWidgetValidator.errors(doc, kUmgWidgetLibraryShadcn);
    expect(errors, hasLength(1));
    expect(errors.single, allOf(contains('"Motion"'), contains('Timeline'), contains('editor panel')));
    doc.editorPanel = LuminaEditorPanelInfo(title: 'Motion');
    expect(UmgWidgetValidator.errors(doc, kUmgWidgetLibraryShadcn), isEmpty);
  });

  testWidgets("host.panelState setting the Timeline's clips updates the widget", (tester) async {
    const panelPath = 'content/EPW_Motion.lmas';
    await tester.runAsync(() async {
      final plugin = project.writePlugin('motion_tools', friendlyName: 'Motion Tools');
      final b = EpwBuilder('EPW_Motion', LuminaEditorPanelInfo(title: 'Motion', dock: LuminaEditorPanelDock.tab));
      b.element(UmgWidgetType.editorTimeline, 'Timeline', props: UmgWidgetType.editorTimeline.defaultProps()).slot
        ..fill = true
        ..flex = 1;
      await b.writeTo(p.join(plugin.path, panelPath));
      await vm.rescanPlugins();
      await EditorPanelProject.startPanels(vm);
      await until(() => vm.editorPanels.panels.isNotEmpty, reason: 'the plugin panel');
    });
    final id = vm.editorPanels.panels.keys.single;
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: EditorPanelView(host: vm.editorPanels, panelId: id))));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final timeline = tester.state<EditorTimelineState>(find.byType(EditorTimeline));
    expect(timeline.model.clips, isEmpty);
    // What a process's patchPanel sends: one op with the whole clip list.
    vm.editorPanels.links.patch('motion_tools', const PluginPanelStatePatch(panelPath, [
      PluginPanelStateOp('Timeline', {
        'clips': [
          {'id': 'c1', 'track': 'clips', 'start': 0, 'end': 60, 'text': 'walk forward'},
          {'id': 'c2', 'track': 'clips', 'start': 60, 'end': 150, 'text': 'turn left'},
        ],
      }),
    ]));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(timeline.model.clips.map((c) => c.text), ['walk forward', 'turn left']);
    vm.editorPanelDocking.close(id);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  });
}
