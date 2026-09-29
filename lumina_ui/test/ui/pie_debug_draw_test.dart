import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Directionality, Offset, Size, TextDirection, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/main_editor/services/pie_debug_projection.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_debug_draw_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../helpers/scaffold_game_project.dart';

/// Play draws `LuminaWorld.debugShapes`, shows
/// `screenMessages` on the HUD and pauses on `breakpoint` nodes — on a real
/// Third Person project played headless through the editor's PieController.
void main() {
  late Directory root;
  late String dir;
  const characterPath = LuminaThirdPersonContent.characterBlueprintPath;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp09_pie_');
    dir = await scaffoldGameProject(root, name: 'bp_debug', widgetLibrary: 'flutter');
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/bp_debug.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> editorFor(WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  test('the game camera projection puts a point ahead of the camera inside the viewport and rejects one behind it', () {
    final projection = PieCameraProjection(
      eye: Vector3(0, 100, 0),
      forward: Vector3(0, 0, -1),
      up: Vector3(0, 1, 0),
      fovDegrees: 90,
      size: const Size(800, 600),
    );
    final centre = projection.project(Vector3(0, 100, -500))!;
    expect(centre.dx, closeTo(400, 0.01));
    expect(centre.dy, closeTo(300, 0.01));
    final right = projection.project(Vector3(300, 100, -300))!;
    expect(right.dx, closeTo(700, 0.01), reason: 'at 90° a point as far right as it is deep hits the edge');
    final above = projection.project(Vector3(0, 400, -300))!;
    expect(above.dy, closeTo(0, 0.01));
    expect(projection.project(Vector3(0, 100, 500)), isNull);
    expect(projection.scaleAt(Vector3(0, 100, -300)), closeTo(1.0, 0.01));
  });

  test('the shape painter draws every shape kind through the projection', () {
    final projection = PieCameraProjection(
      eye: Vector3(0, 100, 0),
      forward: Vector3(0, 0, -1),
      up: Vector3(0, 1, 0),
      fovDegrees: 60,
      size: const Size(640, 480),
    );
    final shapes = [
      LuminaDebugShape(kind: LuminaDebugShapeKind.line, points: [Vector3(-100, 100, -300), Vector3(100, 100, -300)], color: const [1, 0, 0, 1], expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.sphere, points: [Vector3(0, 100, -400)], color: const [0, 1, 0, 1], radius: 50, expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.box, points: [Vector3(0, 100, -400)], color: const [0, 0, 1, 1], extent: Vector3(20, 20, 20), rotation: Quaternion.identity(), expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.point, points: [Vector3(0, 100, -400)], color: const [1, 1, 0, 1], radius: 4, expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.arrow, points: [Vector3(0, 100, -300), Vector3(50, 100, -300)], color: const [1, 0, 1, 1], radius: 10, expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.capsule, points: [Vector3(0, 100, -400)], color: const [0, 1, 1, 1], radius: 30, extent: Vector3(0, 90, 0), expiresAt: 1),
      LuminaDebugShape(kind: LuminaDebugShapeKind.string, points: [Vector3(0, 150, -300)], color: const [1, 1, 1, 1], text: 'Hello', expiresAt: 1),
    ];
    final painter = PieDebugShapePainter(shapes: shapes, projection: projection);
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const Size(640, 480));
    recorder.endRecording();
    expect(painter.drawn, 7);
    expect(PieDebugShapePainter.colorOf(const [1, 0, 0, 1]), const ui.Color(0xFFFF0000));
  });

  testWidgets('draw_debug_line on Tick records a line the overlay draws; print_string with a key replaces its HUD line', (tester) async {
    final bp = BlueprintEditorViewModel(assetPath: '$dir/$characterPath');
    await tester.runAsync(bp.load);
    // The template character already ticks: splice the debug chain in front
    // of whatever Tick ran.
    final tick = bp.graphNodes.firstWhere((n) => n.registryId == 'event_tick', orElse: () => bp.addGraphNode('event_tick', const Offset(0, 2000))!);
    final tickOut = bp.graphWires.where((w) => w.fromNodeId == tick.id && w.fromPinId == 'exec_tick_out').firstOrNull;
    final line = bp.addGraphNode('draw_debug_line', const Offset(300, 2000), literals: {
      'line_start': [0.0, 0.0, 0.0],
      'line_end': [0.0, 0.0, 200.0],
      'line_color': [1.0, 0.0, 0.0, 1.0],
      'duration': 0.5,
      'thickness': 2.0,
    })!;
    final print = bp.addGraphNode('print_string', const Offset(600, 2000), literals: {
      'in_string': 'FPS: 60',
      'print_to_screen': true,
      'print_to_log': false,
      'key': 'fps',
      'duration': 0.0,
    })!;
    if (tickOut != null) bp.addGraphWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: tickOut.toNodeId, toPinId: tickOut.toPinId);
    expect(bp.addGraphWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: line.id, toPinId: 'exec_in'), isNotNull);
    expect(bp.addGraphWire(fromNodeId: line.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in'), isNotNull);
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');
    expect(await tester.runAsync(bp.save), isTrue);
    bp.dispose();

    final vm = await editorFor(tester);
    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    expect(vm.pieController.possessedPawn, isNotNull);
    for (var i = 0; i < 3; i++) {
      world.tick(1 / 60);
    }
    final shapes = world.debugShapes.where((s) => s.kind == LuminaDebugShapeKind.line).toList();
    expect(shapes, isNotEmpty, reason: 'Tick drew a line');
    expect(shapes.last.color, [1.0, 0.0, 0.0, 1.0]);
    expect(shapes.last.expiresAt, greaterThan(world.realTimeSeconds));
    expect(world.screenMessages.keys, contains('fps'));
    expect(world.screenMessages['fps']!.text, 'FPS: 60');
    expect(world.screenMessages.length, 1, reason: 'the keyed line is replaced, not repeated, over three ticks');

    // The overlay projects it through the possessed pawn's camera.
    final cam = vm.pieController.playerCamera!;
    final projection = PieCameraProjection(
      eye: cam.worldLocation,
      forward: cam.forwardVector,
      up: cam.upVector,
      fovDegrees: cam.fieldOfViewInDegrees,
      size: const Size(1280, 720),
    );
    final painter = PieDebugShapePainter(shapes: List.of(world.debugShapes), projection: projection);
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const Size(1280, 720));
    recorder.endRecording();
    expect(painter.drawn, world.debugShapes.length);

    // The layer widget shows the HUD line.
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: PieDebugDrawLayer(world: () => world, projection: () => projection)));
    await tester.pump();
    expect(find.byKey(const ValueKey('pie_screen_messages')), findsOneWidget);
    expect(find.text('FPS: 60'), findsOneWidget);
    expect(find.byKey(const ValueKey('pie_debug_shapes')), findsOneWidget);

    // Expiry: after the line's duration the world drops it.
    for (var i = 0; i < 40; i++) {
      world.tick(1 / 60);
    }
    vm.pieController.stopHeadlessForTest();
    expect(world.debugShapes.where((s) => s.expiresAt < world.realTimeSeconds), isEmpty);
    vm.dispose();
  });

  testWidgets('a breakpoint node pauses Play and asks the Blueprint editor to frame it', (tester) async {
    final bp = BlueprintEditorViewModel(assetPath: '$dir/$characterPath');
    await tester.runAsync(bp.load);
    final begin = bp.graphNodes.firstWhere((n) => n.registryId == 'event_beginplay', orElse: () => bp.addGraphNode('event_beginplay', const Offset(0, 3000))!);
    final breakpoint = bp.addGraphNode('breakpoint', const Offset(300, 3000))!;
    // Splice the breakpoint in front of whatever BeginPlay ran.
    final next = bp.graphWires.where((w) => w.fromNodeId == begin.id && w.fromPinId == 'exec_out').firstOrNull;
    if (next != null) bp.addGraphWire(fromNodeId: breakpoint.id, fromPinId: 'exec_out', toNodeId: next.toNodeId, toPinId: next.toPinId);
    expect(bp.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: breakpoint.id, toPinId: 'exec_in'), isNotNull);
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');
    expect(await tester.runAsync(bp.save), isTrue);
    bp.dispose();

    final vm = await editorFor(tester);
    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    // The spawned pawn's BeginPlay runs on the first frame.
    world.tick(1 / 60);
    expect(vm.pieController.isPaused, isTrue, reason: 'BeginPlay reached the breakpoint');
    final hit = vm.pieController.breakpointHit;
    expect(hit, isNotNull);
    expect(hit!.blueprintPath, characterPath);
    expect(hit.nodeId, breakpoint.id);
    expect(BlueprintNavigation.instance.pending, (path: characterPath, nodeId: breakpoint.id), reason: 'the editor frames the node');
    expect(BlueprintNavigation.instance.take(characterPath), breakpoint.id);
    vm.pieController.resume();
    expect(vm.pieController.isPaused, isFalse);
    expect(vm.pieController.breakpointHit, isNull);
    vm.pieController.stopHeadlessForTest();
    vm.dispose();
  });
}
