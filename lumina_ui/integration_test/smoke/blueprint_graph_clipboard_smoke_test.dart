import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// A launcher Third Person project's character Blueprint: the user edits
/// Print String's text with Backspace and Delete (the node stays), copies
/// Print String → Delay with Ctrl+C, pastes it twice under the mouse with
/// Ctrl+V (the copies keep their wire), cuts a copy with Ctrl+X and brings
/// it back with Ctrl+Z.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blueprint editor: typing in a node field, copy, paste and cut nodes', (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bpclip_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_clip_smoke', widgetLibrary: 'flutter')))!;
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
    await rec.hold(const Duration(milliseconds: 1000));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;

    Future<void> key(LogicalKeyboardKey k, {bool control = false}) async {
      if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(k);
      if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await rec.hold(const Duration(milliseconds: 250));
    }

    // Print String → Delay below the template's graph.
    final bottom = vm.eventGraph.nodes.map((n) => BlueprintNodeLayout.of(vm.eventGraph, n).rect.bottom).reduce(math.max);
    final baseY = (bottom / 100).ceil() * 100.0 + 300;
    final print = vm.eventGraph.addNode('print_string', Offset(0, baseY), literals: {'in_string': 'Hello Lumina'})!;
    final delay = vm.eventGraph.addNode('delay', Offset(380, baseY))!;
    vm.eventGraph.addWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: delay.id, toPinId: 'exec_in');
    state().frameCanvasPoint(Offset(380, baseY + 220));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 600));

    // Backspace and Delete in the In String field edit the text; the node stays.
    vm.eventGraph.select(print.id);
    final field = find.descendant(of: find.byKey(ValueKey('literal_${print.id}_in_string_0')), matching: find.byType(EditableText));
    await tester.tap(field);
    await rec.hold(const Duration(milliseconds: 300));
    await key(LogicalKeyboardKey.end);
    for (var i = 0; i < 6; i++) {
      await key(LogicalKeyboardKey.backspace);
    }
    await key(LogicalKeyboardKey.home);
    await key(LogicalKeyboardKey.delete);
    expect(vm.eventGraph.node(print.id), isNotNull, reason: 'Backspace / Delete in the field deleted the node');
    expect(tester.widget<EditableText>(field).controller.text, 'ello ');
    await shot('blueprint_clipboard_text_field_backspace_keeps_node');

    // A click on the canvas commits the field (focus loss) and focuses the
    // canvas; select both nodes, Ctrl+C.
    await tester.tapAt(screen(150, baseY + 430));
    await settle(2);
    expect(vm.eventGraph.node(print.id)!.literals['in_string'], 'ello ');
    vm.eventGraph.selectMany({print.id, delay.id});
    await settle(2);
    await rec.hold(const Duration(milliseconds: 600));
    await key(LogicalKeyboardKey.keyC, control: true);
    final copied = await tester.runAsync(() => Clipboard.getData(Clipboard.kTextPlain));
    expect(copied?.text, contains('"format":"lumina.graph-nodes"'));

    // Ctrl+V twice, each under the mouse.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: screen(0, baseY + 260));
    addTearDown(mouse.removePointer);
    final pasted = <Set<String>>[];
    for (final at in [Offset(0, baseY + 260), Offset(120, baseY + 470)]) {
      final from = screen(at.dx - 200, at.dy - 80);
      final to = screen(at.dx, at.dy);
      for (var i = 1; i <= 20; i++) {
        await mouse.moveTo(Offset.lerp(from, to, i / 20)!);
        await rec.hold(const Duration(milliseconds: 33));
      }
      final before = vm.eventGraph.nodes.map((n) => n.id).toSet();
      await key(LogicalKeyboardKey.keyV, control: true);
      await settle(4);
      final added = vm.eventGraph.nodes.map((n) => n.id).toSet().difference(before);
      expect(added, hasLength(2));
      expect(vm.eventGraph.selectedNodeIds, added);
      expect(vm.eventGraph.wires.where((w) => added.contains(w.fromNodeId) && added.contains(w.toNodeId)), hasLength(1));
      pasted.add(added);
      await rec.hold(const Duration(milliseconds: 700));
    }
    await shot('blueprint_clipboard_pasted_twice_with_wires');

    // Ctrl+X the last copy, then Ctrl+Z brings it back.
    final count = vm.eventGraph.nodes.length;
    await key(LogicalKeyboardKey.keyX, control: true);
    await settle(4);
    expect(vm.eventGraph.nodes.length, count - 2);
    await rec.hold(const Duration(milliseconds: 900));
    await shot('blueprint_clipboard_cut');
    await key(LogicalKeyboardKey.keyZ, control: true);
    await settle(4);
    expect(vm.eventGraph.nodes.length, count);
    expect(pasted.last.every((id) => vm.eventGraph.node(id) != null), isTrue);
    await rec.hold(const Duration(milliseconds: 900));

    // Ctrl+D duplicates the first copy next to itself.
    vm.eventGraph.selectMany(pasted.first);
    await settle(2);
    await key(LogicalKeyboardKey.keyD, control: true);
    await settle(4);
    expect(vm.eventGraph.nodes.length, count + 2);
    state().frameCanvasPoint(Offset(380, baseY + 300));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_clipboard_cut_undone_and_duplicated');

    final video = rec.save('blueprint editor: typing in a node field, copy, paste and cut nodes');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
