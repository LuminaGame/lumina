import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/staged_setting_hint.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// Settings setters that only stage their value carry a "Needs Apply
/// Scalability Settings" footer on the graph node, with the node's
/// description on hover. Real temp project, real Blueprint `.lmas`.
void main() {
  late BlueprintTestProject project;
  late String assetPath;

  setUp(() {
    project = BlueprintTestProject.create();
    assetPath = project.createBlueprint('BP_SettingsMenu');
  });
  tearDown(() => project.dispose());

  Future<BlueprintEditorViewModel> pumpEditor(WidgetTester tester) async {
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: vm.fileBasename, assetPath: vm.assetPath, viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    return vm;
  }

  Finder canvas() => find.byType(BlueprintGraphCanvas);
  BlueprintGraphCanvasState canvasState(WidgetTester tester) => tester.state<BlueprintGraphCanvasState>(canvas());

  testWidgets('staged setters show the Apply hint; Apply and Set Screen Resolution And Apply do not', (tester) async {
    final vm = await pumpEditor(tester);
    final res = vm.eventGraph.addNode('set_screen_resolution', const Offset(0, 1200))!;
    final vsync = vm.eventGraph.addNode('set_vsync_enabled', const Offset(320, 1200))!;
    final apply = vm.eventGraph.addNode('apply_scalability_settings', const Offset(640, 1200))!;
    final now = vm.eventGraph.addNode('set_screen_resolution_and_apply', const Offset(0, 1400))!;
    canvasState(tester).frameCanvasPoint(const Offset(400, 1300));
    await tester.pumpAndSettle();

    for (final n in [res, vsync]) {
      final hint = find.byKey(ValueKey('node_staged_hint_${n.id}'));
      expect(hint, findsOneWidget, reason: n.registryId);
      expect(find.descendant(of: hint, matching: find.text('Needs Apply Scalability Settings')), findsOneWidget);
    }
    for (final n in [apply, now]) {
      expect(find.byKey(ValueKey('node_staged_hint_${n.id}')), findsNothing, reason: n.registryId);
    }

    // Hovering the footer shows the node's description.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('node_staged_hint_${vsync.id}'))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Turns vertical synchronization on or off. Staged: takes effect when Apply Scalability Settings runs.'),
        findsOneWidget);
  });

  testWidgets('the footer sits under the pins: pin centres keep their place and the node grows by its height',
      (tester) async {
    final vm = await pumpEditor(tester);
    final staged = vm.eventGraph.addNode('set_screen_resolution', const Offset(0, 1200))!;
    final plain = vm.eventGraph.addNode('set_screen_resolution_and_apply', const Offset(400, 1200))!;
    await tester.pumpAndSettle();
    final editor = canvasState(tester).widget.editor;
    final a = BlueprintNodeLayout.of(editor, staged);
    final b = BlueprintNodeLayout.of(editor, plain);
    expect(a.hasStagedHint, isTrue);
    expect(b.hasStagedHint, isFalse);
    expect(a.rows, b.rows);
    expect(a.height - b.height, BlueprintStagedSettingHint.height);
    expect(a.width, greaterThanOrEqualTo(BlueprintStagedSettingHint.minNodeWidth));
    for (final pin in ['exec_in', 'width', 'height']) {
      expect(a.pinCenter(pin, output: false)! - Offset(staged.x, staged.y),
          b.pinCenter(pin, output: false)! - Offset(plain.x, plain.y), reason: pin);
    }
  });
}
