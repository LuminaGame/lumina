import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/designer_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Designer canvas + palette + hierarchy + inspector over one persisted
/// document (real temp project, real WIDGET `.lmas`).
void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_canvas_test_');
    final projectDir = '${tempDir.path}/HudProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'HudProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_PlayerHUD.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_PlayerHUD.lmas';
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    addTearDown(() => vm.dispose());
    // Real disk read: must run outside the FakeAsync zone.
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: UMGWidgetSubEditor(assetName: 'WBP_PlayerHUD', assetPath: lmasPath, viewModel: vm),
        ),
      ),
    );
    // Let the Accordion open animations and the first canvas measurement settle.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return vm;
  }

  testWidgets('Drop: dragging Text from the palette onto the root Canvas Panel creates a slot at the drop point and renders a real Text', (tester) async {
    final vm = await pumpEditor(tester);
    vm.snapToGrid = false;
    expect(find.text('UMG WIDGET'), findsOneWidget);
    expect(find.text('UMG Visual Designer Canvas'), findsNothing, reason: 'placeholder canvas is gone');

    final paletteItem = find.byKey(const ValueKey('umg_palette_text'));
    expect(paletteItem, findsOneWidget);
    final surface = find.byKey(const ValueKey('umg_canvas_surface'));
    expect(surface, findsOneWidget);

    // Drop at a point inside the canvas frame.
    final surfaceRect = tester.getRect(surface);
    final dropPoint = surfaceRect.topLeft + Offset(surfaceRect.width * 0.3, surfaceRect.height * 0.4);
    final gesture = await tester.startGesture(tester.getCenter(paletteItem));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(dropPoint);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(dropPoint + const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(vm.document.root.children.length, 1);
    final node = vm.document.root.children.single;
    expect(node.type, UmgWidgetType.text);
    // Slot position equals the drop point mapped into canvas (logical) coordinates.
    final canvasBox = tester.renderObject<RenderBox>(surface);
    final expected = canvasBox.globalToLocal(dropPoint + const Offset(1, 0));
    expect((node.slot.position - expected).distance, lessThan(0.5));

    // The canvas renders the real shadcn Text (widget predicate, not a screenshot).
    final runtimeText = find.descendant(
      of: find.byKey(ValueKey('umg_rt_${node.id}')),
      matching: find.byWidgetPredicate((w) => w is Text && w.data == 'Text Block'),
    );
    expect(runtimeText, findsOneWidget);
    // Hierarchy and inspector follow the selection.
    expect(vm.selectedId, node.id);
    await tester.tap(find.byKey(const ValueKey('umg_left_tab_hierarchy')));
    await tester.pump();
    expect(find.byKey(ValueKey('umg_tree_${node.id}')), findsOneWidget);
    expect(find.text('field: ${node.fieldName}'), findsOneWidget, reason: 'inspector shows the selected element');
  });

  testWidgets('clicking a Button on the canvas selects it instead of pressing it', (tester) async {
    final vm = await pumpEditor(tester);
    final button = vm.addWidget(UmgWidgetType.button, parentId: vm.document.root.id, canvasPosition: const Offset(200, 200))!;
    vm.select(null);
    await tester.pump();
    await tester.pump();

    final runtimeButton = find.descendant(of: find.byKey(ValueKey('umg_rt_${button.id}')), matching: find.byType(Button));
    expect(runtimeButton, findsOneWidget);
    await tester.tap(runtimeButton, warnIfMissed: false);
    await tester.pump();

    final canvasState = tester.state<UmgDesignerCanvasState>(find.byType(UmgDesignerCanvas));
    expect(canvasState.runtimeInteractionCount, 0, reason: 'design-time widgets never swallow clicks');
    expect(vm.selectedId, button.id);
  });

  testWidgets('inspector write-through: Color and Tint recolors the Progress Bar; Z-Order reorders canvas paint order', (tester) async {
    final vm = await pumpEditor(tester);
    final root = vm.document.root.id;
    final bar = vm.addWidget(UmgWidgetType.progressBar, parentId: root, canvasPosition: const Offset(16, 16))!;
    final text = vm.addWidget(UmgWidgetType.text, parentId: root, canvasPosition: const Offset(16, 80))!;
    await tester.pump();

    Progress progressWidget() => tester.widget<Progress>(
          find.descendant(of: find.byKey(ValueKey('umg_rt_${bar.id}')), matching: find.byType(Progress)),
        );
    // The runtime view passes Progress's own colour argument (deprecated for
    // theme: in shadcn_flutter 0.0.55, still honoured).
    // ignore: deprecated_member_use
    expect(progressWidget().color, isNot(const Color(0xFFFF0000)));
    vm.setProp(bar.id, 'color', '#FF0000');
    await tester.pump();
    // ignore: deprecated_member_use
    expect(progressWidget().color, const Color(0xFFFF0000));
    expect(vm.document.findNode(bar.id)!.props['color'], '#FF0000');

    // Paint order follows Z-Order: the Stack under the root lists children ascending by zOrder.
    List<String> paintOrder() {
      final stack = tester.widget<Stack>(find.byKey(ValueKey('umg_canvas_stack_$root')));
      return stack.children.map((c) => (c.key as ValueKey<String>).value).toList();
    }

    expect(paintOrder(), ['umg_canvas_child_${bar.id}', 'umg_canvas_child_${text.id}']);
    vm.setZOrder(bar.id, 10);
    await tester.pump();
    expect(paintOrder(), ['umg_canvas_child_${text.id}', 'umg_canvas_child_${bar.id}']);
  });

  testWidgets('resolution simulator: a bottom-right anchored element stays in the corner at 1920x1080 and 393x852', (tester) async {
    final vm = await pumpEditor(tester);
    vm.snapToGrid = false;
    final node = vm.addWidget(UmgWidgetType.text, parentId: vm.document.root.id, canvasPosition: const Offset(1700, 1020))!;
    vm.setCanvasSize(node.id, const Size(200, 40));
    vm.applyAnchorPreset(node.id, UmgAnchorPreset.bottomRight);
    await tester.pump();
    await tester.pump();

    final canvasState = tester.state<UmgDesignerCanvasState>(find.byType(UmgDesignerCanvas));
    var rect = canvasState.rectFor(node.id)!;
    expect(rect.right, closeTo(1900, 0.5));
    expect(rect.bottom, closeTo(1060, 0.5));

    vm.setResolution(UmgResolution.presets.firstWhere((p) => p.width == 393));
    await tester.pump();
    await tester.pump();
    rect = canvasState.rectFor(node.id)!;
    expect(rect.right, closeTo(373, 0.5));
    expect(rect.bottom, closeTo(832, 0.5));
    expect(find.textContaining('393'), findsWidgets);
  });

  testWidgets('hierarchy is the document, not a hardcoded list; Graph mode shows the event graph, View Generated Code the source', (tester) async {
    final vm = await pumpEditor(tester);
    expect(find.text('CanvasPanel_Root'), findsNothing);
    expect(find.text('HealthBar_ProgressBar'), findsNothing);
    final bar = vm.addWidget(UmgWidgetType.progressBar, parentId: vm.document.root.id, canvasPosition: Offset.zero)!;
    vm.rename(bar.id, 'HealthBar Progress');
    await tester.pump();
    // Switch the left panel to the Hierarchy tab.
    await tester.tap(find.byKey(const ValueKey('umg_left_tab_hierarchy')));
    await tester.pump();
    expect(find.text('HealthBar Progress'), findsWidgets);
    expect(find.byKey(ValueKey('umg_tree_${bar.id}')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('umg_mode_graph')));
    await tester.pump();
    // Graph is the widget's own event graph; the generated
    // source is one toggle away.
    expect(find.byKey(const ValueKey('blueprint_event_graph_canvas')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('umg_view_generated_code')));
    await tester.pump();
    expect(find.textContaining('class WbpPlayerHUD'), findsOneWidget);
  });

  testWidgets('a plain-Flutter project previews with the runtime LuminaUmg* widgets, a shadcn one with shadcn', (tester) async {
    final projectDir = File(lmasPath).parent.parent.parent.path;
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(
      projectName: 'HudProject',
      activeLevel: 'contents/levels/L_Main.lmas',
      ui: ProjectUiSettings(widgetLibrary: kUmgWidgetLibraryFlutter),
    ).toMap()));
    final vm = await pumpEditor(tester);
    expect(vm.widgetLibrary, kUmgWidgetLibraryFlutter);
    final button = vm.addWidget(UmgWidgetType.button, parentId: vm.document.root.id, canvasPosition: const Offset(200, 200))!;
    final slider = vm.addWidget(UmgWidgetType.slider, parentId: vm.document.root.id, canvasPosition: const Offset(200, 300))!;
    await tester.pump(const Duration(milliseconds: 150));
    Finder inNode(UmgNode n, Type t) => find.descendant(of: find.byKey(ValueKey('umg_rt_${n.id}')), matching: find.byType(t));
    expect(inNode(button, LuminaUmgButton), findsOneWidget);
    expect(inNode(button, Button), findsNothing);
    expect(inNode(slider, LuminaUmgSlider), findsOneWidget);
    expect(vm.generatedSource, isNot(contains('shadcn_flutter')), reason: 'the Graph tab shows what compile will write');

    // Project Settings switches the project back: the open designer follows on its next build.
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(
      projectName: 'HudProject',
      activeLevel: 'contents/levels/L_Main.lmas',
      ui: ProjectUiSettings(widgetLibrary: kUmgWidgetLibraryShadcn),
    ).toMap()));
    vm.select(button.id);
    await tester.pump(const Duration(milliseconds: 150));
    expect(vm.widgetLibrary, kUmgWidgetLibraryShadcn);
    expect(inNode(button, Button), findsOneWidget);
    expect(inNode(button, LuminaUmgButton), findsNothing);
  });
}
