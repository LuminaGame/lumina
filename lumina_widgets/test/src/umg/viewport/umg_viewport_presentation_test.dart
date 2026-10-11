import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart' hide BlendMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

import '../../../../../lumina/test/support/viewport_project.dart';

/// The Viewport's two presentation paths and the web's limit: on a game
/// presenting directly it is an extra view in the game's frame at its
/// physical rectangle under a clear hole in the captured UI (a playing
/// animation never re-captures the UI); otherwise it owns a FilamentWidget
/// on the shared engine; the web renders at most two.
void main() {
  late ViewportTestProject project;

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = ViewportTestProject.create();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    }
  }

  Map<String, Object?> instanceWithMannequin({bool animate = false, bool skeleton = false}) {
    final preview = <String, Object?>{'type': 'viewport', 'name': 'Preview', 'visibility': 'Visible'};
    final scene = LuminaViewportScene.of(preview);
    final hero = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: ViewportTestProject.mannequin);
    if (animate) scene.playAnimation(hero, ViewportTestProject.idle);
    if (skeleton) scene.showSkeleton(hero, [1.0, 0.85, 0.2, 1.0]);
    return {
      'class': 'WBP_Test',
      'elements': <String, Object?>{'Preview': preview},
    };
  }

  testWidgets('Direct path: an extra view at the physical rect, a clear hole, no re-capture while it animates', (tester) async {
    if (!ViewportTestProject.available) return markTestSkipped('test-assets models missing');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    if (engine == null) return markTestSkipped('no native assets');
    final overlay = FilamentUiOverlay.create(engine)!;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final host = LuminaViewportHost()
      ..engine = engine
      ..presentingDirectly = true;
    final gameView = engine.createView();
    LuminaUiCapture.stats.value = const LuminaUiCaptureStats();
    final instance = instanceWithMannequin(animate: true, skeleton: true);
    final key = GlobalKey<LuminaUmgViewportState>();
    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaViewportHostScope(
        host: host,
        child: LuminaUiCapture(
          overlay: overlay,
          child: RepaintBoundary(
            key: boundary,
            child: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFCC2222))),
              Positioned(
                left: 100,
                top: 50,
                width: 320,
                height: 240,
                child: LuminaUmgViewport(key: key, instance: instance, name: 'Preview', budget: LuminaViewportBudget()),
              ),
            ]),
          ),
        ),
      ),
    ));
    await frames(tester, 4);
    final state = key.currentState!;
    expect(state.path, LuminaUmgViewportPath.direct);
    expect(find.byType(FilamentWidget), findsNothing);
    expect(host.directViews, hasLength(1));
    for (var i = 0; i < 200 && !state.controller!.runtime.isReady; i++) {
      await frames(tester, 1);
    }
    host.frameViews(gameView, 800, 600);
    await frames(tester, 6);
    final captures = LuminaUiCapture.stats.value.captures;
    expect(captures, greaterThan(0));

    final views = host.frameViews(gameView, 800, 600);
    expect(views, hasLength(2), reason: 'the game view, the Viewport (its overlay lines are in its scene)');
    expect(identical(views.first, gameView), isTrue, reason: 'the game view first, the Viewport after it');
    expect(views[1].viewport, (100, 600 - 50 - 240, 320, 240), reason: 'bottom-left origin, physical pixels');
    expect(state.controller!.overlayLineCount, greaterThan(50), reason: 'the skeleton as Filament lines');

    // The idle plays: the preview advances inside the game's frames, the UI
    // capture does not see it.
    final mesh = state.controller!.runtime.componentOf(state.controller!.scene!.nodes.first['id']! as String)! as LuminaAnimatedMeshComponent;
    final t0 = mesh.currentTime;
    for (var i = 0; i < 30; i++) {
      host.frameViews(gameView, 800, 600);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 17)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(mesh.currentTime, isNot(t0), reason: 'the animation plays');
    await frames(tester, 3);
    expect(LuminaUiCapture.stats.value.captures, captures, reason: 'a moving 3D image and its moving skeleton never re-capture the UI');

    // The element's rectangle is a hole in the UI picture.
    final image = await tester.runAsync(() async {
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await ro.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (img.width, data!);
    });
    int alphaAt(int x, int y) => image!.$2.getUint8((y * image.$1 + x) * 4 + 3);
    expect(alphaAt(260, 170), 0, reason: 'inside the Viewport');
    expect(alphaAt(20, 20), 255, reason: 'the HUD background outside it');

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
    expect(host.directViews, isEmpty, reason: 'removed with the widget');
    gameView.dispose();
    overlay.dispose();
    host.dispose();
    engine.dispose();
  });

  testWidgets('Flutter path: its own FilamentWidget on the shared engine', (tester) async {
    if (!ViewportTestProject.available) return markTestSkipped('test-assets models missing');
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey<LuminaUmgViewportState>();
    LuminaViewportController? controller;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: LuminaUmgViewport(
            key: key,
            instance: instanceWithMannequin(),
            name: 'Preview',
            backend: FilamentBackend.noop,
            budget: LuminaViewportBudget(scope: LuminaViewportScope.editor),
            onController: (c) => controller = c,
          ),
        ),
      ),
    ));
    for (var i = 0; i < 40 && controller == null; i++) {
      await frames(tester, 1);
    }
    if (controller == null) return markTestSkipped('no native assets');
    expect(key.currentState!.path, LuminaUmgViewportPath.flutter);
    expect(find.byType(FilamentWidget), findsOneWidget);
    final engine = controller!.runtime.engine;
    expect(FilamentEngineHost.owns(engine), isTrue, reason: 'the shared engine, not one of its own');
    expect(FilamentEngineHost.leaseOwners(engine), contains('UMG Viewport Preview'));
    expect(key.currentState!.renderSize, (800, 600), reason: 'layout × device pixel ratio');
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
    expect(controller, isNull, reason: 'disposed with the widget');
  });

  testWidgets('the web renders at most two Viewports: a third shows the placeholder', (tester) async {
    final budget = LuminaViewportBudget(scope: LuminaViewportScope.web);
    final keys = [for (var i = 0; i < 3; i++) GlobalKey<LuminaUmgViewportState>()];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        for (final k in keys)
          SizedBox(
            width: 200,
            height: 150,
            child: LuminaUmgViewport(key: k, name: 'Preview', backend: FilamentBackend.noop, budget: budget),
          ),
      ]),
    ));
    await frames(tester, 3);
    expect(keys.map((k) => k.currentState!.showsLimitPlaceholder), [false, false, true]);
    expect(find.textContaining('Viewport limit reached'), findsOneWidget);
    expect(budget.log, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
    expect(budget.activeCount, 0);
  });

  test('the Viewport is in the game library and needs no dart:ffi (web builds)', () {
    final widgets = File('lib/lumina_widgets.dart').readAsStringSync();
    expect(widgets, contains("export 'package:lumina_widgets/src/umg/viewport/umg_viewport.dart';"));
    for (final path in [
      'lib/src/umg/viewport/umg_viewport.dart',
      'lib/src/umg/viewport/umg_viewport_input.dart',
      'lib/src/umg/viewport/viewport_host.dart',
      '../lumina/lib/src/umg/viewport/viewport_runtime.dart',
      '../lumina/lib/src/umg/viewport/viewport_controller.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("'dart:ffi'")), reason: path);
      expect(source, isNot(contains("'dart:io'")), reason: path);
    }
  });
}
