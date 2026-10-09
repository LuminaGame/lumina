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

/// A launcher Third Person project's character Blueprint: the user drops an
/// integer output on a float input and a float output on an integer input,
/// and the editor inserts To Float (Integer) and Truncate between them
/// (the drag tooltip says which, Truncate's toast says the fraction is
/// dropped); the chain Random Integer in Range → To Float → Absolute →
/// Truncate → To String → Print String compiles clean.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blueprint editor: wiring int to float inserts a conversion node', (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bpconv_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_conv_smoke', widgetLibrary: 'flutter')))!;
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
    Offset pin(LuminaBlueprintNode n, String pinId, {required bool output}) =>
        topLeft() + state().pinScreenPosition(n.id, pinId, output: output)!;

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

    /// Drags [from].[fromPin] onto [to].[toPin] at a hand's pace; with the
    /// pointer over the target, checks the tooltip and saves [screenshot].
    Future<String?> wire(LuminaBlueprintNode from, String fromPin, LuminaBlueprintNode to, String toPin, {String? screenshot}) async {
      state().frameCanvasPoint(Offset((from.x + to.x) / 2 + 100, (from.y + to.y) / 2 + 60));
      await settle(2);
      final a = pin(from, fromPin, output: true);
      final b = pin(to, toPin, output: false);
      final gesture = await tester.startGesture(a, kind: PointerDeviceKind.mouse);
      await rec.hold(const Duration(milliseconds: 100));
      for (var i = 1; i <= 30; i++) {
        await gesture.moveTo(Offset.lerp(a, b, i / 30)!);
        await rec.hold(const Duration(milliseconds: 33));
      }
      await rec.hold(const Duration(milliseconds: 900));
      final hint = tester.widgetList<Text>(find.byKey(const ValueKey('wire_drag_hint'))).firstOrNull?.data;
      expect(find.byKey(const ValueKey('wire_drag_refusal')), findsNothing, reason: 'a convertible pair is not refused');
      if (screenshot != null) await shot(screenshot);
      await gesture.up();
      await settle();
      await rec.hold(const Duration(milliseconds: 600));
      return hint;
    }

    // BeginPlay → Print String, then the value chain feeding it.
    final begin = await placeAt('beginplay', 'event_beginplay', 0, baseY);
    final print = await placeAt('print string', 'print_string', 420, baseY);
    expect(vm.eventGraph.addWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in'), isNotNull);
    final random = await placeAt('random integer', 'random_integer_in_range', 0, baseY + 260);
    final abs = await placeAt('absolute float', 'float_abs', 520, baseY + 260);
    final toText = await placeAt('int to string', 'int_to_string', 1040, baseY + 260);
    vm.setPinLiteral(random.id, 'min', -50);
    vm.setPinLiteral(random.id, 'max', 50);

    // integer → float: To Float (Integer) appears between them.
    final i2fHint = await wire(random, 'return_value', abs, 'a', screenshot: 'blueprint_conversion_int_to_float_drag');
    expect(i2fHint, contains('To Float (Integer)'));
    final i2f = vm.graphNodes.singleWhere((n) => n.registryId == 'int_to_float');
    expect(vm.graphWires.any((w) => w.fromNodeId == random.id && w.toNodeId == i2f.id), isTrue);
    expect(vm.graphWires.any((w) => w.fromNodeId == i2f.id && w.toNodeId == abs.id && w.toPinId == 'a'), isTrue);
    expect(vm.transactions.undoLabel, 'Undo Insert To Float (Integer)');

    // float → integer: Truncate, with the lossy hint while dragging and after.
    final f2iHint = await wire(abs, 'return_value', toText, 'in_int', screenshot: 'blueprint_conversion_float_to_int_drag');
    expect(f2iHint, allOf(contains('Truncate'), contains('fraction')));
    final truncate = vm.graphNodes.singleWhere((n) => n.registryId == 'truncate');
    expect(vm.graphWires.any((w) => w.fromNodeId == truncate.id && w.toNodeId == toText.id && w.toPinId == 'in_int'), isTrue);
    expect(find.byKey(const ValueKey('conversion_lossy_toast')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 800));
    await shot('blueprint_conversion_truncate_inserted');

    // To String → Print String (same type: a direct wire).
    state().frameCanvasPoint(Offset(900, baseY + 150));
    await settle(2);
    await rec.drag(pin(toText, 'return_value', output: true), pin(print, 'in_string', output: false), steps: 20);
    await settle();
    expect(vm.graphWires.any((w) => w.fromNodeId == toText.id && w.toNodeId == print.id && w.toPinId == 'in_string'), isTrue);

    // Undo and redo the insertion: one step each.
    final nodesBefore = vm.graphNodes.length;
    vm.undo(); // the direct wire
    vm.undo(); // Truncate + its two wires
    await settle();
    await rec.hold(const Duration(milliseconds: 700));
    expect(vm.graphNodes.where((n) => n.registryId == 'truncate'), isEmpty);
    expect(vm.graphNodes.length, nodesBefore - 1);
    vm.redo();
    vm.redo();
    await settle();
    await rec.hold(const Duration(milliseconds: 700));
    expect(vm.graphNodes.where((n) => n.registryId == 'truncate'), hasLength(1));

    // Compile: the converted chain is clean.
    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 100 && vm.compileStatus == BlueprintCompileStatus.dirty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle();
    expect(vm.diagnostics.where((d) => d.isError), isEmpty, reason: '${vm.diagnostics}');
    state().frameCanvasPoint(Offset(700, baseY + 200));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_conversion_chain_compiled');

    final video = rec.save('blueprint editor: wiring int to float inserts a conversion node');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
