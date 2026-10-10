import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// A launcher Third Person project's character Blueprint: the user chains
/// BeginPlay → Set Screen Resolution → Set VSync Enabled; both nodes show
/// "Needs Apply Scalability Settings" under their pins (hover: the node's
/// description) and the compiler warns that nothing applies them. Adding
/// Apply Scalability Settings clears the warning; Set Screen Resolution And
/// Apply has no footer.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blueprint editor: staged settings setters show the Apply hint', (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bpstaged_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_staged_smoke', widgetLibrary: 'flutter')))!;
    final assetPath = '$projectDir/${LuminaThirdPersonContent.characterBlueprintPath}';
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);

    tester.view.physicalSize = const Size(1600, 1000);
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
        home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonCharacter', assetPath: assetPath, viewModel: vm)),
      ),
    ));
    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(milliseconds: 1200));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;

    final bottom = vm.eventGraph.nodes.map((n) => BlueprintNodeLayout.of(vm.eventGraph, n).rect.bottom).reduce(math.max);
    final baseY = (bottom / 100).ceil() * 100.0 + 300;

    Future<LuminaBlueprintNode> placeAt(String query, String key, double x, double y) async {
      state().frameCanvasPoint(Offset(x + 300, y + 100));
      await settle(2);
      await tester.tapAt(screen(x, y), buttons: kSecondaryButton);
      await settle();
      await rec.typeText(find.byKey(const ValueKey('palette_search')), query, perCharacter: const Duration(milliseconds: 30));
      await settle();
      await rec.capture();
      final before = vm.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      return vm.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    void chain(LuminaBlueprintNode a, LuminaBlueprintNode b) =>
        expect(vm.eventGraph.addWire(fromNodeId: a.id, fromPinId: 'exec_out', toNodeId: b.id, toPinId: 'exec_in'), isNotNull);

    Future<void> compile() async {
      await tester.tap(find.byKey(const ValueKey('bp_compile')));
      for (var i = 0; i < 100 && vm.compileStatus == BlueprintCompileStatus.dirty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle();
    }

    List<String> stagedWarnings() => [
          for (final d in vm.diagnostics)
            if (!d.isError && d.message.contains('only stages its value')) d.message,
        ];

    // BeginPlay → Set Screen Resolution → Set VSync Enabled.
    final begin = await placeAt('beginplay', 'event_beginplay', 0, baseY);
    final res = await placeAt('screen resolution', 'set_screen_resolution', 360, baseY);
    final vsync = await placeAt('vsync', 'set_vsync_enabled', 760, baseY);
    chain(begin, res);
    chain(res, vsync);
    vm.setPinLiteral(res.id, 'width', 1600);
    vm.setPinLiteral(res.id, 'height', 900);
    vm.setPinLiteral(vsync.id, 'enabled', true);
    state().frameCanvasPoint(Offset(560, baseY + 60));
    await settle(4);
    for (final n in [res, vsync]) {
      expect(find.byKey(ValueKey('node_staged_hint_${n.id}')), findsOneWidget, reason: n.registryId);
    }
    await rec.hold(const Duration(milliseconds: 1200));

    // Hover the footer: the node's description.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(canvas));
    final hintCenter = tester.getCenter(find.byKey(ValueKey('node_staged_hint_${res.id}')));
    for (var i = 1; i <= 20; i++) {
      await mouse.moveTo(Offset.lerp(tester.getCenter(canvas), hintCenter, i / 20)!);
      await rec.hold(const Duration(milliseconds: 33));
    }
    await rec.hold(const Duration(milliseconds: 1500));
    expect(find.textContaining('Set Screen Resolution And Apply applies it at once'), findsOneWidget);
    await shot('blueprint_staged_setting_hint_tooltip');
    await mouse.moveTo(tester.getCenter(canvas));
    await mouse.removePointer();
    await settle();

    // Compile without Apply: the compiler says nothing applies them.
    await compile();
    expect(stagedWarnings(), hasLength(1), reason: '${vm.diagnostics}');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_staged_setting_hint_compiler_warning');

    // Apply Scalability Settings, and the one-node alternative.
    final apply = await placeAt('apply scalability', 'apply_scalability_settings', 1160, baseY);
    chain(vsync, apply);
    final now = await placeAt('resolution and apply', 'set_screen_resolution_and_apply', 360, baseY + 260);
    expect(find.byKey(ValueKey('node_staged_hint_${apply.id}')), findsNothing);
    expect(find.byKey(ValueKey('node_staged_hint_${now.id}')), findsNothing);
    await compile();
    expect(stagedWarnings(), isEmpty, reason: '${vm.diagnostics}');
    expect(vm.diagnostics.where((d) => d.isError), isEmpty, reason: '${vm.diagnostics}');
    state().frameCanvasPoint(Offset(760, baseY + 140));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 2000));
    await shot('blueprint_staged_setting_hint_nodes');

    final video = rec.save('blueprint editor: staged settings setters show the Apply hint');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
