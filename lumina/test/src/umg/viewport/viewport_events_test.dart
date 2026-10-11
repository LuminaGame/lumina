import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../support/viewport_project.dart';

/// The Viewport's input handled inside the widget, reaching the graph only
/// as discrete events: a pick per tap, throttled gizmo previews, one commit
/// or cancel per drag, one camera change per released orbit.
void main() {
  late ViewportTestProject project;
  FilamentEngine? engine;

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  setUp(() => engine = FilamentEngine.create(backend: FilamentBackend.noop));
  tearDown(() {
    engine?.dispose();
    engine = null;
  });

  /// A 640×480 Viewport showing the mannequin framed from the front.
  Future<(LuminaViewportController, List<(String, Map<String, Object?>)>, String)?> mannequinViewport() async {
    if (!ViewportTestProject.available || engine == null) {
      markTestSkipped(engine == null ? 'no native assets' : 'test-assets models missing');
      return null;
    }
    final events = <(String, Map<String, Object?>)>[];
    final controller = LuminaViewportController(
      runtime: LuminaViewportSceneRuntime(engine: engine!),
      fire: (e, args) => events.add((e, args)),
    );
    addTearDown(controller.dispose);
    final scene = LuminaViewportScene();
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    controller.resize(640, 480);
    controller.sync(scene);
    await controller.runtime.whenReady;
    scene
      ..setCameraPreset(LuminaViewportCameraPreset.front, fit: false)
      ..frameNode(hero);
    controller.sync(scene);
    controller.frame(1 / 60);
    events.clear();
    return (controller, events, hero);
  }

  test('a mesh added to a camera the description never placed is framed once it loads', () async {
    if (!ViewportTestProject.available || engine == null) return markTestSkipped('no native assets or test-assets');
    final controller = LuminaViewportController(runtime: LuminaViewportSceneRuntime(engine: engine!), fire: (_, _) {});
    addTearDown(controller.dispose);
    final runtime = controller.runtime;
    final scene = LuminaViewportScene();
    controller.resize(300, 200);
    controller.sync(scene);
    controller.frame(1 / 60);
    Future<String> show(String asset) async {
      scene.clear();
      final id = scene.addNode(LuminaViewportNodeKind.staticMesh, asset: asset);
      controller.sync(scene);
      await runtime.whenReady;
      controller.frame(1 / 60);
      return id;
    }

    void expectInView(String id) {
      final box = runtime.boundsOf(id)!;
      for (final corner in [box.min, box.max, box.center]) {
        final (x, y) = runtime.project(corner)!;
        expect(x, inInclusiveRange(-1, 301));
        expect(y, inInclusiveRange(-1, 201));
      }
      expect(LuminaAxes.location(runtime.orbit.target).distanceTo(box.center), lessThan(1.0), reason: 'centred');
    }

    final barrel = await show(ViewportTestProject.barrel);
    expect(runtime.failures, isEmpty);
    final size = runtime.boundsOf(barrel)!.max - runtime.boundsOf(barrel)!.min;
    expect(size.y, inInclusiveRange(50, 200), reason: 'a fuel barrel is about a metre tall (cm), its unit scale applied once');
    expectInView(barrel);
    final ac = await show(ViewportTestProject.acUnit);
    expectInView(ac);
    // The player moved the camera: a new mesh keeps that view.
    runtime.orbit.orbit(25, 0);
    final moved = runtime.orbit.target.toList();
    await show(ViewportTestProject.hatA);
    expect(runtime.orbit.target, moved);
    // A description that places its camera is never re-framed.
    final placed = LuminaViewportController(runtime: LuminaViewportSceneRuntime(engine: engine!), fire: (_, _) {});
    addTearDown(placed.dispose);
    final s2 = LuminaViewportScene()..setOrbit(10, 10, 900);
    s2.addNode(LuminaViewportNodeKind.staticMesh, asset: ViewportTestProject.barrel);
    placed
      ..resize(300, 200)
      ..sync(s2);
    await placed.runtime.whenReady;
    placed.frame(1 / 60);
    expect(placed.runtime.orbit.distance, 900);
  });

  test('a tap on the mannequin head picks its node and the head bone', () async {
    final setup = await mannequinViewport();
    if (setup == null) return;
    final (controller, events, hero) = setup;
    final head = controller.runtime.jointsOf(hero).firstWhere((j) => j.name == 'head');
    final (x, y) = controller.runtime.project(head.position)!;
    expect(x, inInclusiveRange(0, 640));
    expect(y, inInclusiveRange(0, 480));
    final hit = controller.tap(x, y);
    expect(hit?.nodeId, hero);
    expect(hit?.bone, 'head');
    expect(events.single.$1, LuminaWidgetEvents.onPicked);
    expect(events.single.$2['node_id'], hero);
    expect(events.single.$2['bone'], 'head');
    final location = events.single.$2['hit_location']! as Vector3;
    expect(location.z, greaterThan(120), reason: 'the head is high up (cm, Z up)');
    // A tap on the background picks nothing.
    events.clear();
    expect(controller.tap(2, 2), isNull);
    expect(events, isEmpty);
  });

  test('a 2 s gizmo drag yields at most 61 previews and one commit with the final transform', () async {
    final setup = await mannequinViewport();
    if (setup == null) return;
    final (controller, events, hero) = setup;
    final scene = controller.scene!..setGizmo(hero);
    controller.sync(scene);
    expect(controller.beginGizmoDrag(), isTrue);
    Map<String, Object?> at(double x) => {
          'location': [x, 0.0, 0.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [1.0, 1.0, 1.0],
        };
    for (var i = 1; i <= 240; i++) {
      controller.frame(1 / 120);
      controller.updateGizmoDrag(at(i * 0.5));
      if (i == 120) {
        expect(controller.runtime.componentOf(hero)!.relativeLocation.x, closeTo(60, 1e-6), reason: 'the node moves at once');
        expect((scene.node(hero)!['transform']! as Map)['location'], [0.0, 0.0, 0.0], reason: 'the description waits for the commit');
      }
    }
    controller.commitGizmoDrag();
    final previews = events.where((e) => e.$1 == LuminaWidgetEvents.onGizmoPreview).length;
    expect(previews, inInclusiveRange(55, 61));
    final commits = events.where((e) => e.$1 == LuminaWidgetEvents.onGizmoCommit).toList();
    expect(commits, hasLength(1));
    expect((commits.single.$2['transform']! as Map)['location'], [120.0, 0.0, 0.0]);
    expect(commits.single.$2['node_id'], hero);
    expect((scene.node(hero)!['transform']! as Map)['location'], [120.0, 0.0, 0.0]);
  });

  test('Escape during a drag cancels it and puts the node back', () async {
    final setup = await mannequinViewport();
    if (setup == null) return;
    final (controller, events, hero) = setup;
    controller.sync(controller.scene!..setGizmo(hero));
    expect(controller.beginGizmoDrag(), isTrue);
    controller.frame(1 / 60);
    controller.updateGizmoDrag({
      'location': [0.0, 40.0, 0.0],
    });
    expect(controller.runtime.componentOf(hero)!.relativeLocation, LuminaAxes.location([0, 40, 0]));
    controller.cancelGizmoDrag();
    expect(events.last.$1, LuminaWidgetEvents.onGizmoCancel);
    expect(events.where((e) => e.$1 == LuminaWidgetEvents.onGizmoCommit), isEmpty);
    expect(controller.runtime.componentOf(hero)!.relativeLocation, Vector3.zero());
  });

  test('an orbit drag yields one On Camera Changed, on release', () async {
    final setup = await mannequinViewport();
    if (setup == null) return;
    final (controller, events, _) = setup;
    final yaw = controller.runtime.orbit.yaw;
    for (var i = 0; i < 60; i++) {
      controller.orbitDrag(-2, 0.5);
      controller.frame(1 / 60);
    }
    expect(events, isEmpty, reason: 'nothing per frame');
    controller.endCameraGesture();
    expect(events.map((e) => e.$1), [LuminaWidgetEvents.onCameraChanged]);
    expect(events.single.$2['yaw'], closeTo(yaw + 48, 1e-6));
    expect(controller.scene!.yaw, closeTo(yaw + 48, 1e-6), reason: 'Get Camera reads the released orbit');
    controller.endCameraGesture();
    expect(events, hasLength(1));
  });

  test('Viewport nodes refuse an element that is not a Viewport', () {
    const cls = LuminaBlueprintWidgetClass(name: 'WBP_Mixed', elements: [
      LuminaBlueprintWidgetElement(name: 'Label', fieldName: 'label', typeName: 'text'),
      LuminaBlueprintWidgetElement(name: 'Preview', fieldName: 'preview', typeName: 'viewport'),
    ]);
    final widget = LuminaWidgetBlueprintDocument(widgetClass: 'WBP_Mixed', variables: cls.elements);
    final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [cls]);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final g = widget.blueprint.eventGraph;
    g.nodes.addAll([
      p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
      p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'label', {'element': 'Label'}),
      p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'preview', {'element': 'Preview'}),
      p('viewport_clear', 'clear'),
      p('viewport_set_grid_visible', 'grid'),
    ]);
    g.wires.addAll(const [
      LuminaBlueprintWire(id: 'w0', fromNodeId: 'construct', fromPinId: 'exec_out', toNodeId: 'clear', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w1', fromNodeId: 'label', fromPinId: 'return_value', toNodeId: 'clear', toPinId: 'target'),
      LuminaBlueprintWire(id: 'w2', fromNodeId: 'clear', fromPinId: 'exec_out', toNodeId: 'grid', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w3', fromNodeId: 'preview', fromPinId: 'return_value', toNodeId: 'grid', toPinId: 'target'),
    ]);
    final errors = validateBlueprint(widget.blueprint, typeContext: context).where((d) => d.isError).toList();
    expect(errors, hasLength(1));
    expect(errors.single.nodeId, 'clear');
    expect(LuminaWidgetEvents.forType('viewport'), containsAll([LuminaWidgetEvents.onPicked, LuminaWidgetEvents.onCameraChanged]));
    expect(LuminaWidgetEvents.forType('text'), isNot(contains(LuminaWidgetEvents.onPicked)));
    // Play Animation File reads a plugin's file: editor panels only.
    final file = LuminaBlueprintNodeLibrary.builtIns.firstWhere((n) => n.id == 'viewport_play_animation_file');
    expect(LuminaBlueprintNodeLibrary.availableIn(file, context), isFalse, reason: 'not in a game widget');
  });
}
