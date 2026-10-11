import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

import '../../../../../lumina/test/support/viewport_project.dart';

/// The Viewport widget maps the player's gestures onto its preview (orbit,
/// pan, zoom, pick, gizmo, F to frame) and reaches the graph only through
/// the element's events; a refresh for another element touches nothing.
void main() {
  late ViewportTestProject project;
  final events = <(String, Map<String, Object?>)>[];

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  setUp(events.clear);

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    }
  }

  /// A 640×480 Viewport `Preview` beside a Text `Label`, showing the
  /// mannequin from the front; returns its state, the instance, its binding
  /// and the mannequin's node id.
  Future<(LuminaUmgViewportState, Map<String, Object?>, LuminaUmgInstanceBinding, String)?> mount(WidgetTester tester) async {
    if (!ViewportTestProject.available) {
      markTestSkipped('test-assets models missing');
      return null;
    }
    final preview = <String, Object?>{'type': 'viewport', 'name': 'Preview', 'visibility': 'Visible'};
    final instance = <String, Object?>{
      'class': 'WBP_Test',
      'elements': <String, Object?>{
        'Preview': preview,
        'Label': <String, Object?>{'type': 'text', 'name': 'Label', 'visibility': 'Visible', 'text': 'a'},
      },
    };
    final scene = LuminaViewportScene.of(preview)..gridVisible = false;
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    scene
      ..setCameraPreset(LuminaViewportCameraPreset.front, fit: false)
      ..frameNode(hero);
    final binding = LuminaUmgInstanceBinding(instance);
    final key = GlobalKey<LuminaUmgViewportState>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaUmgInstanceScope(
        binding: binding,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            height: 480,
            child: LuminaUmgViewport(
              key: key,
              instance: instance,
              name: 'Preview',
              backend: FilamentBackend.noop,
              budget: LuminaViewportBudget(scope: LuminaViewportScope.editor),
              onEvent: (e, a) => events.add((e, a)),
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 40 && key.currentState?.controller == null; i++) {
      await frames(tester, 1);
    }
    final state = key.currentState!;
    if (state.controller == null) {
      markTestSkipped('no native assets');
      return null;
    }
    for (var i = 0; i < 200 && !state.controller!.runtime.isReady; i++) {
      await frames(tester, 1);
    }
    await frames(tester, 4);
    events.clear();
    return (state, instance, binding, hero);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  }

  testWidgets('drags, the wheel and a tap orbit, pan, zoom and pick', (tester) async {
    final mounted = await mount(tester);
    if (mounted == null) return;
    final (state, _, _, hero) = mounted;
    final c = state.controller!;
    final yaw = c.runtime.orbit.yaw;
    final target = List<double>.of(c.runtime.orbit.target);
    final distance = c.runtime.orbit.distance;

    // Left drag: orbit, one On Camera Changed on release.
    final orbit = await tester.startGesture(const Offset(100, 400), buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 10; i++) {
      await orbit.moveBy(const Offset(-10, 0));
      await frames(tester, 1);
    }
    await orbit.up();
    await frames(tester, 1);
    expect(c.runtime.orbit.yaw, isNot(closeTo(yaw, 1)));
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onCameraChanged]);
    events.clear();

    // Right drag: pan.
    final pan = await tester.startGesture(const Offset(100, 400), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await pan.moveBy(const Offset(40, 20));
    await pan.up();
    await frames(tester, 1);
    expect(c.runtime.orbit.target, isNot(target));
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onCameraChanged]);
    events.clear();

    // Wheel: zoom in, the change reported when the wheel rests.
    tester.binding.handlePointerEvent(const PointerScrollEvent(position: Offset(320, 240), scrollDelta: Offset(0, -200), kind: PointerDeviceKind.mouse));
    await frames(tester, 1);
    expect(c.runtime.orbit.distance, lessThan(distance));
    expect(events, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onCameraChanged]);
    events.clear();

    // Tap on the head: On Picked with the node and the bone.
    c.runtime.orbit.readFrom(c.scene!);
    c.runtime.frameNode(hero);
    c.frame(1 / 60);
    final head = c.runtime.jointsOf(hero).firstWhere((j) => j.name == 'head');
    final (x, y) = c.runtime.project(head.position)!;
    await tester.tapAt(Offset(x, y), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await frames(tester, 1);
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onPicked]);
    expect(events.single.$2['node_id'], hero);
    expect(events.single.$2['bone'], 'head');
    await unmount(tester);
  });

  testWidgets('a drag on the gizmo X arrow previews, then commits the moved node', (tester) async {
    final mounted = await mount(tester);
    if (mounted == null) return;
    final (state, instance, binding, hero) = mounted;
    final c = state.controller!;
    LuminaViewportScene.of((instance['elements']! as Map)['Preview'] as Map<String, Object?>).setGizmo(hero);
    binding.refresh();
    await frames(tester, 2);
    final model = luminaViewportGizmoModel(c)!;
    final handles = model.handleScreenPositions()!;
    final centre = handles['CENTER']!;
    final tip = handles['X']!;
    final grab = Offset.lerp(centre, tip, 0.7)!;
    expect(model.hitTest(grab), 'X');
    final drag = await tester.startGesture(grab, buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    final step = (tip - centre) / (tip - centre).distance * 6;
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(step);
      await frames(tester, 1);
    }
    await drag.up();
    await frames(tester, 1);
    final kinds = events.map((e) => e.$1).toList();
    expect(kinds.where((k) => k == LuminaWidgetEvents.onGizmoPreview), isNotEmpty);
    expect(kinds.where((k) => k == LuminaWidgetEvents.onGizmoCommit), hasLength(1));
    expect(kinds.where((k) => k == LuminaWidgetEvents.onCameraChanged), isEmpty, reason: 'a gizmo drag does not orbit');
    final committed = events.lastWhere((e) => e.$1 == LuminaWidgetEvents.onGizmoCommit).$2['transform']! as Map;
    final x = (committed['location']! as List)[0] as double;
    expect(x.abs(), greaterThan(1), reason: 'moved along X');
    expect((committed['location']! as List)[1], 0.0);
    expect((c.scene!.node(hero)!['transform']! as Map)['location'], committed['location']);
    await unmount(tester);
  });

  testWidgets('a click whose pointer slips a few pixels still picks at the press point and leaves the camera', (tester) async {
    final mounted = await mount(tester);
    if (mounted == null) return;
    final (state, _, _, hero) = mounted;
    final c = state.controller!;
    c.frame(1 / 60);
    final head = c.runtime.jointsOf(hero).firstWhere((j) => j.name == 'head');
    final (x, y) = c.runtime.project(head.position)!;
    final yaw = c.runtime.orbit.yaw;
    final pitch = c.runtime.orbit.pitch;
    // A hand on the mouse: 1 px steps, 7 px away at the release (11 px of path), as a window run recorded it.
    final press = await tester.startGesture(Offset(x, y), buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    for (final step in const [Offset(3, 0), Offset(-2, 0), Offset(1, 0), Offset(1, 0), Offset(1, 0), Offset(1, 0), Offset(1, 1), Offset(1, -1)]) {
      await press.moveBy(step);
    }
    await press.up();
    await frames(tester, 1);
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onPicked]);
    expect(events.single.$2['node_id'], hero);
    expect(events.single.$2['bone'], 'head');
    expect(c.runtime.orbit.yaw, yaw);
    expect(c.runtime.orbit.pitch, pitch);
    events.clear();

    // Past the slop it is a drag: the camera turns, nothing is picked.
    final drag = await tester.startGesture(Offset(x, y), buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(4, 0));
    }
    await drag.up();
    await frames(tester, 1);
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onCameraChanged]);
    expect(c.runtime.orbit.yaw, isNot(yaw));
    await unmount(tester);
  });

  testWidgets('F frames the picked node', (tester) async {
    final mounted = await mount(tester);
    if (mounted == null) return;
    final (state, _, _, hero) = mounted;
    final c = state.controller!;
    c.runtime.orbit
      ..target = [500.0, 500.0, 0.0]
      ..distance = 5000.0;
    c.selectedNode = hero;
    await tester.tapAt(const Offset(5, 5), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await frames(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await frames(tester, 1);
    final box = c.runtime.boundsOf(hero)!;
    final centre = LuminaAxes.toAuthoringLocation(box.center);
    for (var i = 0; i < 3; i++) {
      expect(c.runtime.orbit.target[i], closeTo(centre[i], 1e-6));
    }
    expect(c.runtime.orbit.distance, lessThan(1000));
    expect(events.last.$1, LuminaWidgetEvents.onCameraChanged);
    await unmount(tester);
  });

  testWidgets('a refresh for a sibling element does not touch the preview scene', (tester) async {
    final mounted = await mount(tester);
    if (mounted == null) return;
    final (state, instance, binding, _) = mounted;
    final before = state.controller!.runtime.opsApplied;
    final refreshOps = state.refreshOps;
    ((instance['elements']! as Map)['Label'] as Map)['text'] = 'Set Text';
    binding.refresh();
    await frames(tester, 2);
    expect(state.refreshOps, refreshOps);
    expect(state.controller!.runtime.opsApplied, before);
    await unmount(tester);
  });
}
