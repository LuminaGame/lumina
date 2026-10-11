import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../../support/viewport_project.dart';

/// The Viewport budget: render size cap, count cap, hidden Viewports not
/// counting, and idle Viewports rendering nothing until something changes.
void main() {
  test('a 3000×1500 layout at render scale 1 renders at 2048×1024', () {
    expect(LuminaViewportBudget.renderSize(3000, 1500), (2048, 1024));
    expect(LuminaViewportBudget.renderSize(512, 512, devicePixelRatio: 2), (1024, 1024));
    expect(LuminaViewportBudget.renderSize(800, 600, renderScale: 0.1), (200, 150), reason: 'render scale clamps to 0.25');
    expect(LuminaViewportBudget.renderSize(0, 600), (0, 0));
  });

  test('a fifth game Viewport gets a placeholder and one log line', () {
    final budget = LuminaViewportBudget();
    final owners = [for (var i = 0; i < 6; i++) Object()];
    for (final o in owners.take(4)) {
      expect(budget.acquire(o), isTrue);
    }
    expect(budget.acquire(owners[4]), isFalse);
    expect(budget.acquire(owners[5]), isFalse);
    expect(budget.acquire(owners[4]), isFalse);
    expect(budget.log, hasLength(1), reason: 'logged once');
    expect(budget.log.single, contains('Viewport limit reached'));
    budget.release(owners[0]);
    expect(budget.acquire(owners[4]), isTrue, reason: 'a freed slot is taken');
    expect(budget.activeCount, 4);
  });

  test('limits: 4 in a game, 8 in the editor, 2 on the web, the project setting lowers them', () {
    expect(LuminaViewportBudget().maxViewports, 4);
    expect(LuminaViewportBudget(scope: LuminaViewportScope.editor).maxViewports, 8);
    expect(LuminaViewportBudget(scope: LuminaViewportScope.web).maxViewports, 2);
    expect(LuminaViewportBudget(maxViewports: 6).maxViewports, 6);
    expect(LuminaViewportBudget(maxViewports: 20).maxViewports, 8);
    expect(LuminaViewportBudget(scope: LuminaViewportScope.web, maxViewports: 8).maxViewports, 2);
  });

  test('a Collapsed, Hidden, zero-sized, off-screen or inactive-tab Viewport does not count', () {
    expect(LuminaViewportBudget.counts(visibility: 'Visible', width: 200, height: 200), isTrue);
    expect(LuminaViewportBudget.counts(visibility: 'Collapsed', width: 200, height: 200), isFalse);
    expect(LuminaViewportBudget.counts(visibility: 'Hidden', width: 200, height: 200), isFalse);
    expect(LuminaViewportBudget.counts(visibility: 'Visible', width: 0, height: 200), isFalse);
    expect(LuminaViewportBudget.counts(visibility: 'Visible', width: 200, height: 200, onScreen: false), isFalse);
    expect(LuminaViewportBudget.counts(visibility: 'Visible', width: 200, height: 200, tabActive: false), isFalse);
  });

  test('an idle frame clock renders one frame, then none over 2 s, then one after a change', () {
    final clock = LuminaViewportFrameClock();
    var frames = 0;
    if (clock.tick(1 / 60)) frames++;
    expect(frames, 1, reason: 'the first frame shows the scene');
    frames = 0;
    for (var i = 0; i < 120; i++) {
      if (clock.tick(1 / 60)) frames++;
    }
    expect(frames, 0);
    clock.markDirty();
    for (var i = 0; i < 60; i++) {
      if (clock.tick(1 / 60)) frames++;
    }
    expect(frames, 1);
    // Input keeps it rendering for one second, then it idles again.
    clock.input();
    frames = 0;
    for (var i = 0; i < 120; i++) {
      if (clock.tick(1 / 60)) frames++;
    }
    expect(frames, inInclusiveRange(59, 62));
    // A playing animation renders every frame, capped at maxFps.
    clock.maxFps = 30;
    frames = 0;
    for (var i = 0; i < 60; i++) {
      if (clock.tick(1 / 60, animating: true)) frames++;
    }
    expect(frames, inInclusiveRange(29, 31));
  });

  test('an idle Viewport renders 0 frames over 2 s, then 1 frame after Set Node Transform', () async {
    if (!ViewportTestProject.available) return markTestSkipped('test-assets models missing');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    if (engine == null) return markTestSkipped('no native assets');
    final project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
    final controller = LuminaViewportController(runtime: LuminaViewportSceneRuntime(engine: engine), fire: (_, _) {});
    addTearDown(() {
      controller.dispose();
      engine.dispose();
      LuminaAssets.projectDir = null;
      project.delete();
    });
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final self = world.spawnActorImmediately(LuminaActor());
    final element = <String, Object?>{'type': 'viewport', 'name': 'Preview'};
    final prop = LuminaViewportNodes.addStaticMesh(self, element, ViewportTestProject.barrel, null);
    controller.resize(320, 240);
    controller.sync(LuminaViewportScene.of(element));
    await controller.runtime.whenReady;
    var frames = 0;
    for (var i = 0; i < 30; i++) {
      if (controller.frame(1 / 60)) frames++;
    }
    expect(frames, greaterThan(0), reason: 'the loaded scene is shown');
    frames = 0;
    for (var i = 0; i < 120; i++) {
      controller.sync(LuminaViewportScene.of(element));
      if (controller.frame(1 / 60)) frames++;
    }
    expect(frames, 0, reason: 'idle: no animation, no auto-rotate, no input');
    LuminaViewportNodes.setNodeTransform(self, element, prop, {
      'location': [0.0, 0.0, 50.0],
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
    });
    for (var i = 0; i < 60; i++) {
      controller.sync(LuminaViewportScene.of(element));
      if (controller.frame(1 / 60)) frames++;
    }
    expect(frames, 1);
    expect(controller.clock.idle(), isTrue);
  });
}
