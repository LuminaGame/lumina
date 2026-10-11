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
  });
}
