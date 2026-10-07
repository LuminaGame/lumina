import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// A new Third Person project's BP_ThirdPersonCharacter opens
/// in the Blueprint editor with its Event Graph in titled comment boxes (Move,
/// Look, Jump, Sprint, Dash, Free Look, Wall Trace). The boxes are stacked at
/// one left x, not the old diagonal staircase. The graph is framed whole,
/// then each box in turn.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'blueprint editor: Third Person template Event Graph in comment boxes';
  testWidgets(scenario, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_layout_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'bp_template_layout', widgetLibrary: 'flutter')))!;
    final assetPath = '$projectDir/${LuminaThirdPersonContent.characterBlueprintPath}';
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);

    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
            child: BlueprintSubEditor(
                assetName: LuminaThirdPersonContent.characterBlueprintName, assetPath: assetPath, viewModel: vm)),
      ),
    ));
    await settle();
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    // Named after the scenario, so the report attaches the PNGs to it.
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(milliseconds: 1000));

    final editor = vm.eventGraph;
    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Rect rect(LuminaBlueprintNode n) => BlueprintNodeLayout.of(editor, n).rect;
    final comments = [for (final n in editor.nodes) if (BlueprintEditorNodes.isComment(n)) n];
    expect([for (final c in comments) c.title], ['Move', 'Look', 'Jump', 'Sprint', 'Dash', 'Free Look', 'Wall Trace']);
    final bounds = editor.nodes.map(rect).reduce((a, b) => a.expandToInclude(b));

    // Frame all: zoom out on the wheel until the whole graph fits, centred.
    final size = tester.getSize(canvas);
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(tester.getCenter(canvas)));
    final fit = math.min(size.width * 0.94 / bounds.width, size.height * 0.94 / bounds.height);
    while (state().zoom > fit + 1e-6 && state().zoom > 0.25 + 1e-6) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 120));
    }
    state().frameCanvasPoint(bounds.center);
    await settle();
    await rec.hold(const Duration(milliseconds: 2500));
    // Every box is on screen, stacked at one left x.
    final topLeft = tester.getTopLeft(canvas);
    for (final c in comments) {
      final r = rect(c);
      final a = topLeft + state().toScreen(r.topLeft);
      final b = topLeft + state().toScreen(r.bottomRight);
      expect(Rect.fromPoints(a, b).intersect(topLeft & size).width, closeTo(Rect.fromPoints(a, b).width, 1.0),
          reason: '${c.title} is framed');
    }
    expect(comments.map((c) => c.x).toSet(), hasLength(1));
    await shot('$scenario 01 framed');

    // Then each box close up, top to bottom.
    await tester.sendEventToBinding(wheel.hover(tester.getCenter(canvas)));
    while (state().zoom < 0.7 - 1e-6) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
      await rec.hold(const Duration(milliseconds: 80));
    }
    await tester.sendEventToBinding(wheel.removePointer());
    for (final c in comments) {
      final r = rect(c);
      // The box's left end (a Move row is wider than the view).
      state().frameCanvasPoint(Offset(r.left + math.min(r.width / 2, size.width / state().zoom / 2 - 40), r.center.dy));
      await settle(4);
      await rec.hold(const Duration(milliseconds: 1100));
      if (c.title == 'Move') await shot('$scenario 02 move box');
    }

    // Back to the whole graph.
    await tester.sendEventToBinding(wheel.hover(tester.getCenter(canvas)));
    while (state().zoom > fit + 1e-6 && state().zoom > 0.25 + 1e-6) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 80));
    }
    await tester.sendEventToBinding(wheel.removePointer());
    state().frameCanvasPoint(bounds.center);
    await settle();
    await rec.hold(const Duration(milliseconds: 1500));

    final video = rec.save(scenario);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
