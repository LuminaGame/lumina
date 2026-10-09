import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2, Vector3;

import '../helpers/pie_pointer_fixture.dart';

/// The mouse in Play-In-Editor, on the whole editor with a real First Person
/// project: hovering the game view moves Get Mouse Position in the view's
/// pixels (the space of Get Viewport Size and the screen projections), a left
/// click reaches the game as LeftMouseButton and a Blueprint's
/// Deproject → Line Trace hits what is under the cursor; clicks never select
/// editor actors while the game takes input. The capture backend records;
/// nothing touches the pointer of the person at this machine.
void main() {
  late PiePointerProject project;
  tearDown(() {
    LuminaBlueprintActorClasses.clear();
    LuminaWidgetClassRegistry.clear();
    project.dispose();
  });

  // The viewport's tickers never let pumpAndSettle settle; real time passes
  // so the engine and the world tick.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester, {bool simulateLock = false, bool withMenu = false}) async {
    project = PiePointerProject.create(withMenu: withMenu);
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend(simulateLock: simulateLock);
    addTearDown(() => LuminaMouseCapture.backend = RecordingMouseCaptureBackend());
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
        initialProject: project.manifest(), projectLocation: project.root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    addTearDown(vm.dispose);
    expect(vm.actors.any((a) => a.name == 'Clicker'), isTrue, reason: 'the level on disk carries BP_Clicker');
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    final size = tester.getSize(find.byType(ViewportWidget));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    for (var i = 0; i < 60 && viewport().nativeProjectForTest(0.0, 0.0, 0.0, size) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, frames: 5);
    return vm;
  }

  /// Plays and returns the trace of the running BP_Clicker.
  Future<List<LuminaBlueprintTraceEvent>> play(WidgetTester tester, EditorViewModel vm) async {
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    await settle(tester, frames: 30);
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'PIE error: ${pie.lastError}');
    final clicker = pie.game!.world!.persistentLevel.actors
        .whereType<LuminaBlueprintInstance>()
        .firstWhere((a) => a.blueprintClass.name == 'BP_Clicker');
    final trace = <LuminaBlueprintTraceEvent>[];
    (clicker as LuminaBlueprintRuntime).trace = trace.add;
    return trace;
  }

  Future<void> stop(WidgetTester tester, EditorViewModel vm) async {
    vm.stopSimulation();
    await settle(tester, frames: 5);
    // The restored editor camera is saved after a short delay.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 2);
  }

  Object? last(List<LuminaBlueprintTraceEvent> trace, String node, String pin) =>
      trace.lastWhere((t) => t.nodeId == node, orElse: () => throw StateError('$node never ran')).values[pin];

  Vector2 v2(Object? v) => v is Vector2 ? v : Vector2((v as List)[0] as double, v[1] as double);
  Vector3 v3(Object? v) => v is Vector3 ? v : Vector3((v as List)[0] as double, v[1] as double, v[2] as double);

  /// Hovers [local] (in the game view) and clicks there; returns the hit the
  /// Blueprint's trace reported.
  Future<Map<String, Object?>> hoverAndClick(WidgetTester tester, TestGesture mouse, Offset local,
      List<LuminaBlueprintTraceEvent> trace) async {
    final origin = tester.getTopLeft(find.byType(FilamentWidget));
    await mouse.moveTo(origin + local - const Offset(12, 8));
    await settle(tester, frames: 3);
    await mouse.moveTo(origin + local);
    await settle(tester, frames: 6);
    final mousePos = v2(last(trace, 'mouse', 'return_value'));
    expect(mousePos.x, closeTo(local.dx, 0.6), reason: 'Get Mouse Position follows the cursor in view pixels ($mousePos vs $local)');
    expect(mousePos.y, closeTo(local.dy, 0.6));

    trace.removeWhere((t) => t.nodeId == 'trace' || t.nodeId == 'hit');
    await mouse.down(origin + local);
    await settle(tester, frames: 4);
    await mouse.up();
    await settle(tester, frames: 4);
    expect(trace.where((t) => t.nodeId == 'trace'), isNotEmpty, reason: 'the left click reached the game as LeftMouseButton');
    return trace.lastWhere((t) => t.nodeId == 'hit').values;
  }

  /// The trace hit what is under the cursor: Location is the Impact Point, and
  /// the Impact Point projects back onto the clicked pixel.
  void expectHitUnderCursor(EditorViewModel vm, Map<String, Object?> hit, Offset local) {
    expect(hit['blocking_hit'], isTrue, reason: 'the floor of the test room is under the cursor');
    expect(hit['hit_actor'], isNot(same(vm.pieController.possessedPawn)), reason: 'the trace ignores the player');
    final impact = v3(hit['impact_point']);
    expect((v3(hit['location']) - impact).length, lessThan(1e-3), reason: 'a line trace stops at its impact point');
    final clicker = vm.pieController.game!.world!.persistentLevel.actors
        .whereType<LuminaBlueprintInstance>()
        .firstWhere((a) => a.blueprintClass.name == 'BP_Clicker');
    final back = LuminaBlueprintFunctionLibrary.projectWorldToScreen(clicker, impact);
    expect(back.returnValue, isTrue);
    expect((back.screenPosition - Vector2(local.dx, local.dy)).length, lessThan(2.0),
        reason: 'the impact point ${back.screenPosition} projects back under the cursor $local');
  }

  testWidgets('captured: hovering moves Get Mouse Position, Get Viewport Size is the view, a click traces under the cursor',
      (tester) async {
    final vm = await pumpEditor(tester);
    final trace = await play(tester, vm);
    expect(vm.pieController.mouseCapture.isCaptured, isTrue);

    final view = tester.getSize(find.byType(FilamentWidget));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await mouse.addPointer(location: tester.getCenter(find.byType(FilamentWidget)));
    addTearDown(mouse.removePointer);

    final local = Offset((view.width * 0.62).roundToDouble(), (view.height * 0.8).roundToDouble());
    final hit = await hoverAndClick(tester, mouse, local, trace);
    final size = v2(last(trace, 'size', 'return_value'));
    expect(size.x, closeTo(view.width.roundToDouble(), 0.5), reason: 'Get Viewport Size is the PIE view ($size vs $view)');
    expect(size.y, closeTo(view.height.roundToDouble(), 0.5));
    expectHitUnderCursor(vm, hit, local);
    expect(vm.selectedActorId, isNull, reason: 'a click in the playing viewport is the game\'s, not an editor selection');

    await stop(tester, vm);
  });

  testWidgets('pointer lock: clicks through the window shield still reach the game at the cursor', (tester) async {
    final vm = await pumpEditor(tester, simulateLock: true);
    final trace = await play(tester, vm);
    expect(vm.pieController.mouseCapture.holdsPointer, isTrue);
    expect(find.byKey(const ValueKey('pie_mouse_shield')), findsOneWidget);

    final view = tester.getSize(find.byType(FilamentWidget));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await mouse.addPointer(location: tester.getCenter(find.byType(FilamentWidget)));
    addTearDown(mouse.removePointer);
    final local = Offset((view.width * 0.4).roundToDouble(), (view.height * 0.78).roundToDouble());
    final hit = await hoverAndClick(tester, mouse, local, trace);
    expectHitUnderCursor(vm, hit, local);

    await stop(tester, vm);
  });

  testWidgets('a free cursor (Set Show Mouse Cursor) clicks into the game; UI Only sends no clicks; F4\'s recapturing click is not the game\'s',
      (tester) async {
    final vm = await pumpEditor(tester);
    final trace = await play(tester, vm);
    final pc = vm.pieController.game!.playerController!;
    pc.setShowMouseCursor(true);
    await settle(tester, frames: 3);
    expect(vm.pieController.mouseCapture.isCaptured, isFalse, reason: 'the game asked for a free cursor');

    final view = tester.getSize(find.byType(FilamentWidget));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await mouse.addPointer(location: tester.getCenter(find.byType(FilamentWidget)));
    addTearDown(mouse.removePointer);
    final local = Offset((view.width * 0.55).roundToDouble(), (view.height * 0.82).roundToDouble());
    expectHitUnderCursor(vm, await hoverAndClick(tester, mouse, local, trace), local);
    expect(vm.selectedActorId, isNull);

    // UI Only: the position still follows, but no button reaches the game.
    pc.setInputModeUIOnly();
    await settle(tester, frames: 3);
    trace.removeWhere((t) => t.nodeId == 'trace');
    final origin = tester.getTopLeft(find.byType(FilamentWidget));
    await mouse.down(origin + local);
    await settle(tester, frames: 4);
    await mouse.up();
    await settle(tester, frames: 4);
    expect(trace.where((t) => t.nodeId == 'trace'), isEmpty, reason: 'UI Only: clicks are the UI\'s');

    // Back to the game, then F4: the click that takes the mouse again is not a game click.
    pc.setInputModeGameOnly();
    pc.setShowMouseCursor(false);
    await settle(tester, frames: 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester, frames: 3);
    expect(vm.pieController.mouseCapture.isReleased, isTrue);
    trace.removeWhere((t) => t.nodeId == 'trace');
    await mouse.down(origin + local);
    await settle(tester, frames: 4);
    await mouse.up();
    await settle(tester, frames: 4);
    expect(vm.pieController.mouseCapture.isCaptured, isTrue, reason: 'the click took the mouse again');
    expect(trace.where((t) => t.nodeId == 'trace'), isEmpty, reason: 'the capturing click is not the game\'s');
    expect(vm.selectedActorId, isNull);

    await stop(tester, vm);
  });

  testWidgets('a click on a UMG button in Play belongs to the widget, a click beside it to the game', (tester) async {
    final vm = await pumpEditor(tester, withMenu: true);
    final trace = await play(tester, vm);
    vm.pieController.game!.playerController!.setShowMouseCursor(true);
    await settle(tester, frames: 5);
    final menu = find.descendant(of: find.byType(PieWidgetLayer), matching: find.byType(UmgRuntimeView));
    expect(menu, findsOneWidget, reason: 'BeginPlay added WBP_Menu to the viewport');
    final button = find.descendant(of: menu, matching: find.text('Button')).first;
    final onButton = tester.getCenter(button);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await mouse.addPointer(location: onButton);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(onButton + const Offset(1, 1));
    await settle(tester, frames: 3);
    trace.removeWhere((t) => t.nodeId == 'trace');
    await mouse.down(onButton);
    await settle(tester, frames: 4);
    await mouse.up();
    await settle(tester, frames: 4);
    expect(trace.where((t) => t.nodeId == 'trace'), isEmpty, reason: 'the widget took the click');
    expect(vm.pieController.pointer.pressedForTest, isEmpty);

    final view = tester.getSize(find.byType(FilamentWidget));
    final local = Offset((view.width * 0.6).roundToDouble(), (view.height * 0.8).roundToDouble());
    expectHitUnderCursor(vm, await hoverAndClick(tester, mouse, local, trace), local);

    await stop(tester, vm);
  });
}
