import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// The selected tab joins the content under it — tinted top and side outline, no bottom edge, and the same fill as
/// the content below; inactive tabs stay flat.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// The tab's own box: the keyed Container itself, or the first decorated
  /// Container under the keyed tap target.
  BoxDecoration decorationOf(WidgetTester tester, Finder tab) {
    final Widget keyed = tester.widget(tab);
    if (keyed is Container && keyed.decoration is BoxDecoration) return keyed.decoration! as BoxDecoration;
    final Container box = tester
        .widgetList<Container>(find.descendant(of: tab, matching: find.byType(Container)))
        .firstWhere((c) => c.decoration is BoxDecoration);
    return box.decoration! as BoxDecoration;
  }

  void expectAttached(BoxDecoration d, Color content, String what) {
    expect(d.color, content, reason: '$what: the fill equals the content below');
    final Border border = d.border! as Border;
    expect(border.bottom, BorderSide.none, reason: '$what: no bottom edge');
    expect(border.top.style, BorderStyle.solid, reason: '$what: tinted top outline');
    expect(border.top.color.toARGB32() & 0xFFFFFF, EditorColors.primary.toARGB32() & 0xFFFFFF);
    expect(border.left.style, BorderStyle.solid, reason: '$what: side outline');
    expect(border.right.style, BorderStyle.solid, reason: '$what: side outline');
  }

  void expectFlat(BoxDecoration d, String what) {
    expect(d.color, const Color(0x00000000), reason: '$what: inactive tabs stay transparent');
    expect(d.border, isNull, reason: '$what: inactive tabs have no outline');
  }

  test('EditorTabStyle: active has no bottom side and the content fill; inactive is flat', () {
    expectAttached(EditorTabStyle.decoration(active: true, content: EditorColors.cardHeader), EditorColors.cardHeader, 'helper');
    expectFlat(EditorTabStyle.decoration(active: false, content: EditorColors.cardHeader), 'helper');
  });

  testWidgets('workspace tabs and the bottom panel tabs attach to their content', (tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_tab_style_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'TabStyleGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);

    // The level tab is the only (and active) workspace tab; the toolbar
    // under the strip is cardHeader.
    expectAttached(decorationOf(tester, find.byKey(const ValueKey('workspace_tab_0'))), EditorColors.cardHeader, 'level tab');

    // Bottom panel: Content Browser active (its toolbar is the rail), the
    // other two flat.
    expectAttached(decorationOf(tester, find.byKey(const ValueKey('bottom_tab_0'))), EditorColors.rail, 'Content Browser tab');
    expectFlat(decorationOf(tester, find.byKey(const ValueKey('bottom_tab_1'))), 'Output Log tab');
    expectFlat(decorationOf(tester, find.byKey(const ValueKey('bottom_tab_2'))), 'Blueprint tab');

    await tester.tap(find.byKey(const ValueKey('bottom_tab_1')));
    await settle(tester, frames: 3);
    expectFlat(decorationOf(tester, find.byKey(const ValueKey('bottom_tab_0'))), 'Content Browser tab');
    expectAttached(decorationOf(tester, find.byKey(const ValueKey('bottom_tab_1'))), EditorColors.cardHeader, 'Output Log tab');
  });

  group('Blueprint editor graph tabs', () {
    late BlueprintTestProject project;
    setUpAll(() => project = BlueprintTestProject.create());
    tearDownAll(() => project.dispose());

    testWidgets('Event Graph / 3D Viewport / Construction Script follow the same rule', (tester) async {
      final path = project.createBlueprint('BP_TabStyle', parentClass: 'LuminaActor');
      final vm = BlueprintEditorViewModel(assetPath: path);
      await tester.runAsync(vm.load);
      addTearDown(vm.dispose);
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_TabStyle', assetPath: path, viewModel: vm, showPreviewViewport: false)),
      ));
      await tester.pump();

      final Finder eventGraph = find.byKey(ValueKey('graph_tab_${BlueprintGraphRef.eventGraph.key}'));
      final Finder construction = find.byKey(ValueKey('graph_tab_${BlueprintGraphRef.constructionScript.key}'));
      expect(eventGraph, findsOneWidget);
      expectAttached(decorationOf(tester, eventGraph), EditorColors.graphCanvas, 'Event Graph tab');
      expectFlat(decorationOf(tester, construction), 'Construction Script tab');

      await tester.tap(construction);
      await tester.pump();
      expectFlat(decorationOf(tester, eventGraph), 'Event Graph tab');
      expectAttached(decorationOf(tester, construction), EditorColors.graphCanvas, 'Construction Script tab');
    });
  });
}
