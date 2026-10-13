import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart' show TransformGizmoModel;
import 'package:lumina_ui/ui/features/sub_editors/view_models/garment_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/garment/garment.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Garment editor's gizmo driven by mouse events on its handles (the
/// way a user drags it): it moves and turns the garment in every state the
/// editor can be in — after a landmark was placed by a click, after W / E
/// chose the tool, with the preview on the reference body itself, and after
/// the garment moved under a still pointer; a new garment starts on the
/// body, not at the origin under its feet.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
  final tshirt = File('$assets/Props/Clothes Line/tshirt.glb');
  final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
  // Skipped when the T-shirt or the mannequin is missing from test-assets.
  final skip = !(tshirt.existsSync() && manny.existsSync());

  late Directory project;
  late String garmentPath;
  const shirt = 'contents/meshes/static/tshirt.glb';
  const body = 'contents/meshes/skeletal/SKM_Manny_Simple.glb';

  setUp(() async {
    project = await Directory.systemTemp.createTemp('garment_gizmo_');
    await Directory('${project.path}/contents/characters').create(recursive: true);
    await Directory('${project.path}/contents/meshes/static').create(recursive: true);
    await Directory('${project.path}/contents/meshes/skeletal').create(recursive: true);
    if (!skip) {
      await tshirt.copy('${project.path}/$shirt');
      await manny.copy('${project.path}/$body');
    }
    await File('${project.path}/GarmentGizmo.lmproject').writeAsString('{"projectName":"GarmentGizmo"}');
    garmentPath = '${project.path}/contents/characters/G_Shirt.lmas';
    await File(garmentPath).writeAsBytes(const LuminaGarmentDocument().toAsset(name: 'G_Shirt').toProtoBufferBytes());
  });

  tearDown(() async {
    try {
      await project.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> frames(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  Future<GarmentEditorViewModel> open(WidgetTester tester) async {
    final vm = GarmentEditorViewModel(assetPath: garmentPath);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.load);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: GarmentSubEditor(assetName: 'G_Shirt', assetPath: garmentPath, viewModel: vm)),
    ));
    await frames(tester, 10);
    await tester.runAsync(() async {
      await vm.setReferenceBody(body);
      await vm.setSourceMesh(shirt);
      await vm.meshesReady;
    });
    await frames(tester, 10);
    return vm;
  }

  dynamic viewport(WidgetTester tester) => tester.state(find.byType(SubEditor3DViewport));

  /// Drags handle [handle] of the gizmo as drawn now by [pixels] along its
  /// arrow (translate) or a quarter of its ring (rotate) with mouse events.
  Future<void> drag(WidgetTester tester, TestGesture mouse, String handle, {required bool rotate}) async {
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    final Offset from;
    final List<Offset> path;
    if (rotate) {
      final model = viewport(tester).transformGizmoModelForTest(rect.size) as TransformGizmoModel;
      final ring = model.ringPoints(handle, segments: 16);
      from = rect.topLeft + ring[1]!;
      path = [for (var i = 2; i <= 5; i++) rect.topLeft + ring[i]!];
    } else {
      final handles = viewport(tester).gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
      final centre = handles['CENTER']!, tip = handles[handle]!;
      final along = (tip - centre) / (tip - centre).distance;
      from = rect.topLeft + centre + along * ((tip - centre).distance * 0.6);
      path = [for (var i = 1; i <= 6; i++) from + along * (8.0 * i)];
    }
    await mouse.moveTo(from);
    await frames(tester, 1);
    await mouse.down(from);
    await frames(tester, 1);
    for (final p in path) {
      await mouse.moveTo(p);
      await frames(tester, 1);
    }
    await mouse.up();
    await frames(tester, 2);
  }

  testWidgets('a new garment starts on the reference body; the gizmo moves and turns it in every editor state', (tester) async {
    final vm = await open(tester);
    expect(vm.sourceMesh, isNotNull, reason: vm.error);
    expect(vm.bodyMesh, isNotNull, reason: vm.error);
    // Placed on the body by bounds (a Torso garment over the chest), not at
    // the origin under its feet.
    expect(vm.doc.location[1], greaterThan(60), reason: 'the new garment sits on the body: ${vm.doc.location}');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getRect(find.byType(SubEditor3DViewport)).center);
    addTearDown(mouse.removePointer);

    // 1. Plain move along X.
    var before = [...vm.doc.location];
    await drag(tester, mouse, 'X', rotate: false);
    expect(vm.doc.location[0], isNot(closeTo(before[0], 0.5)), reason: 'an X-arrow drag moves the garment');

    // 2. A landmark placed on the body by a click leaves the body pick mode
    //    on; W (the viewport's own tool key) must bring the gizmo back.
    vm.addLandmark('Neck');
    await tester.tap(find.byKey(const ValueKey('garment_pick_body')));
    await frames(tester, 2);
    expect(vm.pickMode, GarmentPickMode.body);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await frames(tester, 2);
    expect(vm.pickMode, GarmentPickMode.none, reason: 'choosing a gizmo tool ends landmark picking');
    before = [...vm.doc.location];
    await drag(tester, mouse, 'X', rotate: false);
    expect(vm.doc.location[0], isNot(closeTo(before[0], 0.5)), reason: 'the gizmo works after landmark picking');

    // 3. E turns it.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await frames(tester, 2);
    final turned = [...vm.doc.rotation];
    await drag(tester, mouse, 'Z', rotate: true);
    expect(vm.doc.rotation, isNot(equals(turned)), reason: 'a ring drag turns the garment');

    // 4. Preview On the reference body itself (a picked path spelled
    //    differently): still the placement, still the gizmo.
    await tester.runAsync(() => vm.setPreviewBody(body.replaceAll('/', r'\')));
    await frames(tester, 6);
    expect(vm.previewsAnotherBody, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await frames(tester, 2);
    before = [...vm.doc.location];
    await drag(tester, mouse, 'X', rotate: false);
    expect(vm.doc.location[0], isNot(closeTo(before[0], 0.5)), reason: 'the gizmo works with Preview On the reference body');

    // 5. The garment moves under a still pointer (a Details edit): a press
    //    on the handle where it is now drags it, not a stale hover.
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    var handles = viewport(tester).gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    final oldTip = rect.topLeft + handles['CENTER']! + (handles['X']! - handles['CENTER']!) * 0.6;
    await mouse.moveTo(oldTip);
    await frames(tester, 2);
    vm.setPlacement(location: [vm.doc.location[0], vm.doc.location[1] + 40, vm.doc.location[2]]);
    await frames(tester, 2);
    handles = viewport(tester).gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    final moved = [...vm.doc.location];
    // A press where the handle was (nothing there any more) orbits the
    // camera instead of dragging the garment.
    await mouse.down(oldTip);
    await frames(tester, 1);
    await mouse.moveTo(oldTip + const Offset(30, 0));
    await frames(tester, 1);
    await mouse.up();
    await frames(tester, 2);
    expect(vm.doc.location, moved, reason: 'a press off the handle does not drag a stale hover');
    expect(handles, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
  }, skip: skip);

  testWidgets('a pick mode says what a click does, Esc leaves it, and a placed point goes on to the other one', (tester) async {
    final vm = await open(tester);
    vm.addLandmark('Neck');
    await tester.tap(find.byKey(const ValueKey('garment_pick_garment')));
    await frames(tester, 2);
    expect(find.text('Click on the garment to place "Neck" — Esc to exit'), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_editor_transform_gizmo')), findsNothing, reason: 'clicks pick, the gizmo waits');
    // Esc (the viewport has focus after a click) leaves the pick mode.
    await tester.tap(find.byType(SubEditor3DViewport), buttons: kSecondaryButton);
    await frames(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 2);
    expect(vm.pickMode, GarmentPickMode.none);
    expect(find.byKey(const ValueKey('garment_viewport_pick_hint')), findsNothing);
    expect(find.byKey(const ValueKey('sub_editor_transform_gizmo')), findsOneWidget);

    // Garment point, then the body point, then the gizmo again.
    final placed = vm.placedSourcePositions();
    var top = 0;
    for (var i = 0; i < placed.length ~/ 3; i++) {
      if (placed[i * 3 + 1] > placed[top * 3 + 1]) top = i;
    }
    final x = placed[top * 3], y = placed[top * 3 + 1] - 3;
    vm.setPickMode(GarmentPickMode.garment);
    expect(vm.pick(x, y, 300, 0, 0, -1), isTrue);
    expect(vm.pickMode, GarmentPickMode.body, reason: 'the landmark still needs its body point');
    await frames(tester, 2);
    expect(find.text('Click on the body to place "Neck" — Esc to exit'), findsOneWidget);
    expect(vm.pick(0, 150, 300, 0, 0, -1), isTrue);
    expect(vm.pickMode, GarmentPickMode.none, reason: 'both points placed: back to the gizmo');
    await tester.pumpWidget(const SizedBox());
  }, skip: skip);

  testWidgets('the Landmarks panel stays on screen in a narrow editor', (tester) async {
    for (final width in [1600.0, 1100.0, 900.0, 760.0, 640.0]) {
      final vm = GarmentEditorViewModel(assetPath: garmentPath);
      await tester.runAsync(vm.load);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: GarmentSubEditor(assetName: 'G_Shirt', assetPath: garmentPath, viewModel: vm, showViewport: false)),
      ));
      await frames(tester, 4);
      final panel = tester.getRect(find.text('LANDMARKS'));
      expect(panel.right, lessThanOrEqualTo(width), reason: 'the Landmarks header is visible at $width px');
      expect(panel.left, greaterThan(width / 2), reason: 'on the right at $width px');
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
