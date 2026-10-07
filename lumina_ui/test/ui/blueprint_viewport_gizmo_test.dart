import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/gizmo_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/scaffold_game_project.dart';

/// Component transform gizmos in the Blueprint 3D
/// Viewport, on the shared [TransformGizmoModel] the level viewport uses.
void main() {
  // ---------------------------------------------------------------------------
  // The shared model: hit-testing and the ray-based drag solvers, with a
  // perspective camera (the sub-editor's Y-up orbit camera at 45°).
  // ---------------------------------------------------------------------------
  const size = Size(800, 600);
  const yaw = 30.0;
  const pitch = 20.0;
  const distance = 500.0;
  final target = Vector3.zero();

  Offset? project(Vector3 p) => projectWorldToViewport(
      worldPos: p, size: size, yawDeg: yaw, pitchDeg: pitch, distance: distance, target: target);

  Ray rayAt(Offset local) {
    final r = viewportRay(local: local, size: size, yawDeg: yaw, pitchDeg: pitch, distance: distance, target: target)!;
    return Ray.originDirection(r.origin, r.direction);
  }

  TransformGizmoModel model(GizmoMode mode, {GizmoSpace space = GizmoSpace.world, Quaternion? rotation}) =>
      TransformGizmoModel(
        mode: mode,
        space: space,
        pivot: Vector3.zero(),
        rotation: rotation ?? Quaternion.identity(),
        axisLength: 60.0,
        planeOffset: 20.0,
        project: project,
      );

  group('TransformGizmoModel translate', () {
    test('a hit along the X arrow returns X; dragging it moves the pivot along X by the ray solve', () {
      final m = model(GizmoMode.translate);
      final handles = m.handleScreenPositions()!;
      final centre = handles['CENTER']!;
      final tipX = handles['X']!;
      final along = (tipX - centre) / (tipX - centre).distance;
      final grab = centre + along * 60.0;
      expect(m.hitTest(grab), 'X');
      expect(m.hitTest(centre + const Offset(3, 2)), 'CENTER');
      expect(m.hitTest(const Offset(5, 5)), isNull);

      final drag = m.beginDrag('X', rayAt(grab));
      final to = grab + along * 100.0;
      final delta = drag.translation(rayAt(to));
      expect(delta.y, closeTo(0.0, 1e-6));
      expect(delta.z, closeTo(0.0, 1e-6));
      expect(delta.x, greaterThan(0.0));
      // Ray-based: the grab point, carried along with the pivot, projects
      // back under the pointer, not at a screen-scaled guess.
      final grabParam = GizmoController.solveAxisTranslation(ray: rayAt(grab), axisOrigin: Vector3.zero(), axisDirection: Vector3(1, 0, 0));
      final carried = project(Vector3(grabParam, 0, 0) + delta)!;
      expect((carried - to).distance, lessThan(1.5));
      expect(delta.x, closeTo(GizmoController.solveAxisTranslation(ray: rayAt(to), axisOrigin: Vector3.zero(), axisDirection: Vector3(1, 0, 0)) - grabParam, 1e-9));
    });

    test('a plane XY drag moves X and Y and keeps Z', () {
      final m = model(GizmoMode.translate);
      final handles = m.handleScreenPositions()!;
      final grab = handles['XY']!;
      expect(m.hitTest(grab), 'XY');
      final drag = m.beginDrag('XY', rayAt(grab));
      final delta = drag.translation(rayAt(grab + const Offset(30, 20)));
      expect(delta.z, closeTo(0.0, 1e-6));
      expect(delta.x.abs() + delta.y.abs(), greaterThan(1.0));
      final grabHit = GizmoController.solvePlaneTranslation(ray: rayAt(grab), planeOrigin: Vector3.zero(), planeNormal: Vector3(0, 0, 1));
      expect((project(grabHit + delta)! - (grab + const Offset(30, 20))).distance, lessThan(1.5));
    });
  });

  group('TransformGizmoModel rotate', () {
    test('a hit on the Z ring returns Z; a quarter turn sweeps 90°, snapped to 10° when enabled', () {
      final m = model(GizmoMode.rotate);
      final ring = m.ringPoints('Z', segments: 8);
      final grab = ring[1]!; // 45°: only the Z ring passes here
      expect(m.hitTest(grab), 'Z');
      final drag = m.beginDrag('Z', rayAt(grab));
      final angle = drag.rotationAngle(rayAt(ring[3]!)); // 135°: a quarter turn
      expect(angle.abs(), closeTo(90.0, 0.5));
      expect(drag.rotationAxis, Vector3(0, 0, 1));

      final partial = drag.rotationAngle(rayAt(ring[2]!)); // 90°: 45° swept
      const snap = TransformGizmoSnap(rotateEnabled: true, rotateStep: 10.0);
      final snapped = snap.angle(partial);
      expect((snapped / 10.0).roundToDouble() * 10.0, closeTo(snapped, 1e-9));
      expect(snapped.abs(), anyOf(closeTo(40.0, 1e-9), closeTo(50.0, 1e-9)));
    });

    test('turning an authoring rotation about a world axis changes that axis only', () {
      // A right-handed turn about +Z (counter-clockwise seen from above) is a
      // turn to the left: negative yaw. Pitch is right-handed about +X; roll,
      // like yaw, is positive the other way round (LuminaAxes.rotation).
      expect(AuthoringRotation.rotatedAboutWorldAxis([0, 0, 0], Vector3(0, 0, 1), 90), [0.0, 0.0, -90.0]);
      expect(AuthoringRotation.rotatedAboutWorldAxis([0, 0, 0], Vector3(0, 0, -1), 90), [0.0, 0.0, 90.0]);
      expect(AuthoringRotation.rotatedAboutWorldAxis([0, 0, 0], Vector3(1, 0, 0), 30).map((v) => v.round()), [30, 0, 0]);
      expect(AuthoringRotation.rotatedAboutWorldAxis([0, 0, 0], Vector3(0, 1, 0), 30).map((v) => v.round()), [0, -30, 0]);
      expect(AuthoringRotation.rotatedAboutWorldAxis([0, 0, 45], Vector3(0, 0, -1), 15).map((v) => v.round()), [0, 0, 60]);
      // The inverse of LuminaAxes.rotation, nearest to what the user sees.
      for (final e in [
        [10.0, -20.0, 30.0],
        [0.0, -90.0, 0.0],
        [45.0, 0.0, 170.0],
        [-30.0, 60.0, -100.0]
      ]) {
        final back = AuthoringRotation.eulerFromRuntime(LuminaAxes.rotation(e), near: e);
        for (var i = 0; i < 3; i++) {
          expect(back[i], closeTo(e[i], 1e-6), reason: '$e → $back');
        }
      }
    });
  });

  group('TransformGizmoModel scale', () {
    test('the centre handle scales uniformly, the X stem X only, clamped to 0.01…100', () {
      final m = model(GizmoMode.scale);
      final handles = m.handleScreenPositions()!;
      final centre = handles['CENTER']!;
      expect(m.hitTest(centre + const Offset(2, -3)), 'UNIFORM');
      final tipX = handles['X']!;
      final along = (tipX - centre) / (tipX - centre).distance;
      final grab = centre + along * 40.0;
      expect(m.hitTest(grab), 'X');

      final drag = m.beginDrag('X', rayAt(grab));
      final travel = drag.scaleTravel(rayAt(grab + along * 30.0));
      expect(travel, greaterThan(0.0));
      expect(drag.scaleTravel(rayAt(grab - along * 30.0)), lessThan(0.0));

      final uniform = m.beginDrag('UNIFORM', rayAt(centre));
      expect(uniform.scaleTravel(rayAt(centre)), closeTo(0.0, 1e-6));

      expect(TransformGizmoModel.clampScale(Vector3(0.0, 500.0, 1.0)), Vector3(0.01, 100.0, 1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // The Blueprint editor on a real scaffolded Third Person project.
  // ---------------------------------------------------------------------------
  late Directory root;
  late String dir;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp_gizmo_');
    dir = await scaffoldGameProject(root, name: 'bp_gizmo', widgetLibrary: 'flutter');
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  Future<BlueprintSubEditorState> openViewport(WidgetTester tester, String component) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: LuminaThirdPersonContent.characterBlueprintName,
          assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}',
        ),
      ),
    ));
    final state = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor));
    // load() replaces the constructor's default document with the asset's
    // (the template's own component ids): wait until they are on screen.
    final asset = LuminaAsset.fromBytes(File('$dir/${LuminaThirdPersonContent.characterBlueprintPath}').readAsBytesSync());
    final fileIds = {
      for (final c in (jsonDecode(utf8.decode(asset.rawPayload!)) as Map)['components'] as List) (c as Map)['id'] as String,
    };
    Set<String> docIds() => {for (final c in state.viewModel.document.components) c.id};
    for (var i = 0; i < 300 && !docIds().containsAll(fileIds); i++) {
      await frames(tester, 1);
    }
    expect(docIds(), containsAll(fileIds), reason: 'the Blueprint loaded from its .lmas');
    expect(state.viewModel.document.components.map((c) => c.name), contains(component));
    await tester.tap(find.descendant(of: find.byType(BlueprintComponentTree), matching: find.text(component)).first);
    await frames(tester, 2);
    await tester.tap(find.text('3D Viewport'));
    await frames(tester, 10);
    for (var i = 0; i < 100 && !state.viewModel.preview.isAttached; i++) {
      await frames(tester, 1);
    }
    return state;
  }

  String idOf(dynamic vm, String name) => (vm.document.components as List).firstWhere((c) => c.name == name).id as String;

  List<double> vec(dynamic v) => v is List ? v.map((e) => (e as num).toDouble()).toList() : [0.0, 0.0, 0.0];

  testWidgets('W shows the translate gizmo on CameraBoom; an X-arrow drag edits Location X live, one undo; Esc cancels',
      (tester) async {
    final state = await openViewport(tester, 'CameraBoom');
    final vm = state.viewModel;
    final boom = idOf(vm, 'CameraBoom');
    expect(vm.selectedComponentId, boom);
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));

    // E then W: the keys pick the tool.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await frames(tester, 2);
    expect(state.transformGizmo.mode, GizmoMode.rotate);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await frames(tester, 2);
    expect(state.transformGizmo.mode, GizmoMode.translate);
    expect(find.byKey(const ValueKey('sub_editor_transform_gizmo')), findsOneWidget, reason: 'the gizmo is drawn');

    final handles = viewport().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>?;
    expect(handles, isNotNull);
    final centre = handles!['CENTER']!;
    final tipX = handles['X']!;
    final along = (tipX - centre) / (tipX - centre).distance;
    final grab = rect.topLeft + centre + along * ((tipX - centre).distance * 0.6);

    // Hover lights the handle up.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: grab);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(grab);
    await frames(tester, 2);
    expect(viewport().hoveredGizmoHandleForTest, 'X');

    final before = vec(vm.getComponent(boom)!.properties['location']);
    expect(before, [0.0, 0.0, LuminaTemplateCharacterTuning.boomHeight]);
    expect(vm.transactions.canUndo, isFalse);

    // Drag along the arrow: Location X follows, live.
    await mouse.down(grab);
    await frames(tester, 1);
    for (var i = 1; i <= 8; i++) {
      await mouse.moveTo(grab + along * (10.0 * i));
      await frames(tester, 1);
    }
    final mid = vec(vm.getComponent(boom)!.properties['location']);
    expect(mid[0], isNot(closeTo(before[0], 0.5)), reason: 'Location X moves during the drag');
    expect(mid[1], closeTo(before[1], 1e-6));
    expect(mid[2], closeTo(before[2], 1e-6));
    expect(vm.transactions.canUndo, isFalse, reason: 'no undo step before the button comes up');
    expect(find.byKey(const ValueKey('sub_editor_gizmo_banner')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(ValueKey('$boom.location.0.${vm.componentTransformRevision}')));
    expect(field.initialValue, mid[0].toStringAsFixed(1), reason: 'the Details field shows the live value');
    await mouse.up();
    await frames(tester, 2);

    final after = vec(vm.getComponent(boom)!.properties['location']);
    expect(after[0], mid[0]);
    expect(vm.isDirty, isTrue);
    expect(vm.transactions.canUndo, isTrue);
    expect(vm.transactions.undoLabel, 'Undo Transform CameraBoom');
    vm.undo();
    await frames(tester, 2);
    expect(vec(vm.getComponent(boom)!.properties['location']), before, reason: 'one undo restores the drag');
    expect(vm.transactions.canUndo, isFalse, reason: 'the whole drag was one step');

    // Esc mid-drag: back to the start, no undo entry.
    final handles2 = viewport().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    final grab2 = rect.topLeft + handles2['CENTER']! + along * ((handles2['X']! - handles2['CENTER']!).distance * 0.6);
    await mouse.moveTo(grab2);
    await frames(tester, 1);
    await mouse.down(grab2);
    await frames(tester, 1);
    for (var i = 1; i <= 5; i++) {
      await mouse.moveTo(grab2 + along * (10.0 * i));
      await frames(tester, 1);
    }
    expect(vec(vm.getComponent(boom)!.properties['location'])[0], isNot(closeTo(before[0], 0.5)));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 2);
    await mouse.up();
    await frames(tester, 2);
    expect(vec(vm.getComponent(boom)!.properties['location']), before);
    expect(vm.transactions.canUndo, isFalse);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('E and a yaw-ring drag change Rotation Z only; Local mode turns the handles with the component',
      (tester) async {
    final state = await openViewport(tester, 'CameraBoom');
    final vm = state.viewModel;
    final boom = idOf(vm, 'CameraBoom');
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    expect(state.transformGizmo.target?.id, boom, reason: 'the gizmo sits on the selected boom (${vm.preview.sceneTransformFor(boom)})');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await frames(tester, 2);
    expect(state.transformGizmo.mode, GizmoMode.rotate);
    final model = viewport().transformGizmoModelForTest(rect.size) as TransformGizmoModel?;
    expect(model, isNotNull);
    final ring = model!.ringPoints('Z', segments: 8);
    final grab = rect.topLeft + ring[1]!;
    final to = rect.topLeft + ring[3]!;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: grab);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(grab);
    await frames(tester, 2);
    expect(viewport().hoveredGizmoHandleForTest, 'Z');
    await mouse.down(grab);
    await frames(tester, 1);
    for (var i = 1; i <= 8; i++) {
      await mouse.moveTo(Offset.lerp(grab, to, i / 8)!);
      await frames(tester, 1);
    }
    await mouse.up();
    await frames(tester, 2);
    final rot = vec(vm.getComponent(boom)!.properties['rotation']);
    expect(rot[0], closeTo(0.0, 1e-6), reason: 'roll unchanged');
    expect(rot[1], closeTo(0.0, 1e-6), reason: 'pitch unchanged');
    expect(rot[2].abs(), closeTo(90.0, 1.5), reason: 'a quarter turn of yaw: $rot');

    // Local space: the handles follow the boom's rotation.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await frames(tester, 2);
    final world = viewport().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    await tester.tap(find.byKey(const ValueKey('sub_gizmo_space')));
    await frames(tester, 2);
    expect(state.transformGizmo.space, GizmoSpace.local);
    final local = viewport().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    expect(local['CENTER'], world['CENTER']);
    expect((local['X']! - world['X']!).distance, greaterThan(10.0), reason: 'a 90° yaw turns the X handle');

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('the root CapsuleComponent shows a dimmed gizmo; a drag leaves it and shows the hint', (tester) async {
    final state = await openViewport(tester, 'CapsuleComponent');
    final vm = state.viewModel;
    final capsule = idOf(vm, 'CapsuleComponent');
    expect(vm.selectedComponentId, capsule);
    expect(state.transformGizmo.target?.locked, isTrue);
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    final handles = viewport().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
    final centre = handles['CENTER']!;
    final along = (handles['X']! - centre) / (handles['X']! - centre).distance;
    final grab = rect.topLeft + centre + along * ((handles['X']! - centre).distance * 0.6);

    final before = vm.getComponent(capsule)!.properties['location'];
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: grab);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(grab);
    await frames(tester, 1);
    await mouse.down(grab);
    await frames(tester, 1);
    for (var i = 1; i <= 5; i++) {
      await mouse.moveTo(grab + along * (10.0 * i));
      await frames(tester, 1);
    }
    expect(find.text('Root component transform is fixed'), findsOneWidget);
    await mouse.up();
    await frames(tester, 2);
    expect(vm.getComponent(capsule)!.properties['location'], before);
    expect(vm.transactions.canUndo, isFalse);
    expect(vm.isDirty, isFalse);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('clicking the FollowCamera frustum in the viewport selects it in the tree', (tester) async {
    final state = await openViewport(tester, 'Mesh');
    final vm = state.viewModel;
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));

    // Orbit a quarter turn so the camera behind the mannequin is off to the
    // side, clear of the capsule.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    addTearDown(mouse.removePointer);
    await mouse.down(rect.center + const Offset(-200, 150));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(rect.center + Offset(-200 + 18.0 * i, 150));
      await frames(tester, 1);
    }
    await mouse.up();
    await frames(tester, 2);

    final cameraId = idOf(vm, 'FollowCamera');
    final camera = vm.preview.sceneTransformFor(cameraId)!;
    final at = projectWorldToViewport(
      worldPos: camera.worldLocation,
      size: rect.size,
      yawDeg: viewport().cameraYawForTest as double,
      pitchDeg: viewport().cameraPitchForTest as double,
      distance: viewport().cameraDistanceForTest as double,
      target: viewport().cameraTargetForTest as Vector3,
    );
    expect(at, isNotNull);
    expect(vm.preview.pick(viewportRay(
      local: at!,
      size: rect.size,
      yawDeg: viewport().cameraYawForTest as double,
      pitchDeg: viewport().cameraPitchForTest as double,
      distance: viewport().cameraDistanceForTest as double,
      target: viewport().cameraTargetForTest as Vector3,
    )!), cameraId);

    await mouse.moveTo(rect.topLeft + at);
    await frames(tester, 1);
    await mouse.down(rect.topLeft + at);
    await frames(tester, 1);
    await mouse.up();
    await frames(tester, 3);
    expect(vm.selectedComponentId, cameraId);
    expect({for (final s in vm.preview.overlays) if (s.selected) s.id}, {cameraId});

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('updating gizmoDefaults on BlueprintSubEditor syncs mode, space, snap to transformGizmo', (tester) async {
    final state = await openViewport(tester, 'CameraBoom');
    expect(state.transformGizmo.mode, GizmoMode.translate);

    // Rebuild BlueprintSubEditor with new gizmoDefaults: rotate, local, snap
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: LuminaThirdPersonContent.characterBlueprintName,
          assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}',
          viewModel: state.viewModel,
          gizmoDefaults: const BlueprintGizmoDefaults(
            mode: GizmoMode.rotate,
            space: GizmoSpace.local,
            snap: TransformGizmoSnap(rotateEnabled: true, rotateStep: 15.0),
          ),
        ),
      ),
    ));
    await frames(tester, 2);
    expect(state.transformGizmo.mode, GizmoMode.rotate);
    expect(state.transformGizmo.space, GizmoSpace.local);
    expect(state.transformGizmo.snap.rotateEnabled, isTrue);
    expect(state.transformGizmo.snap.rotateStep, 15.0);

    // Update again to scale
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: LuminaThirdPersonContent.characterBlueprintName,
          assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}',
          viewModel: state.viewModel,
          gizmoDefaults: const BlueprintGizmoDefaults(
            mode: GizmoMode.scale,
            space: GizmoSpace.world,
          ),
        ),
      ),
    ));
    await frames(tester, 2);
    expect(state.transformGizmo.mode, GizmoMode.scale);
    expect(state.transformGizmo.space, GizmoSpace.world);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('picking in preview scene finds scene components via their pick box', (tester) async {
    final state = await openViewport(tester, 'FollowCamera');
    final vm = state.viewModel;
    final cameraId = idOf(vm, 'FollowCamera');
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    final camera = vm.preview.sceneTransformFor(cameraId)!;
    final at = projectWorldToViewport(
      worldPos: camera.worldLocation,
      size: rect.size,
      yawDeg: viewport().cameraYawForTest as double,
      pitchDeg: viewport().cameraPitchForTest as double,
      distance: viewport().cameraDistanceForTest as double,
      target: viewport().cameraTargetForTest as Vector3,
    );
    expect(at, isNotNull);
    final ray = viewportRay(
      local: at!,
      size: rect.size,
      yawDeg: viewport().cameraYawForTest as double,
      pitchDeg: viewport().cameraPitchForTest as double,
      distance: viewport().cameraDistanceForTest as double,
      target: viewport().cameraTargetForTest as Vector3,
    )!;
    expect(vm.preview.pick(ray), cameraId);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('SCENE LIGHTS toggle appears when scene has lights and updates renderSceneLights', (tester) async {
    final state = await openViewport(tester, 'CameraBoom');
    final vm = state.viewModel;

    // Initially no scene lights toggle button
    expect(find.byKey(const ValueKey('sub_viewport_toggle_scene_lights')), findsNothing);

    // Add a light component to the Blueprint
    vm.addComponent('SpotLightComponent');
    await frames(tester, 5);

    // Now hasSceneLights is true, SCENE LIGHTS toggle button appears
    expect(vm.hasSceneLights, isTrue);
    final toggleFinder = find.byKey(const ValueKey('sub_viewport_toggle_scene_lights'));
    expect(toggleFinder, findsOneWidget);
    expect(vm.renderSceneLights, isFalse);

    // Tap toggle button -> toggles renderSceneLights
    await tester.tap(toggleFinder);
    await frames(tester, 2);
    expect(vm.renderSceneLights, isTrue);

    // Tap again -> toggles off
    await tester.tap(toggleFinder);
    await frames(tester, 2);
    expect(vm.renderSceneLights, isFalse);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });

  testWidgets('TransformGizmoToolbar renders tool buttons and snap toggles in the 3D viewport', (tester) async {
    await openViewport(tester, 'CameraBoom');
    expect(find.byType(TransformGizmoToolbar), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_gizmo_tool_translate')), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_gizmo_tool_rotate')), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_gizmo_tool_scale')), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_gizmo_space')), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_gizmo_snap_translate')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });
}
