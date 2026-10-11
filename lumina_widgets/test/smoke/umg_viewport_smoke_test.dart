import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart' hide BlendMode, GizmoMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_smoke/flutter.dart' show SmokeCapture, SmokeRecorder;
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../../lumina/test/blueprint/generated/widget_script/wbp_customizer.g.dart';
import '../../../lumina/test/blueprint/umg_viewport_customizer_fixture.dart';
import '../../../lumina/test/support/viewport_project.dart';

/// UMG Viewport smoke — a character customisation screen in a game: a real
/// level of `test-assets/` props, the generated `WBP_Customizer` on the HUD
/// whose Viewport shows the mannequin playing its idle with a hat at its
/// head and an access card at its right hand. The player orbits the
/// Viewport, clicks Next Hat and Colour, and picks the mannequin; the
/// widget's graph (the compiled `WbpCustomizerGraph`) builds and changes the
/// preview. Run once on the Flutter path (the Viewport's own FilamentWidget
/// in the game host) and once on the Direct path (an extra view in the
/// game's frame under the captured UI, composed as the direct presenter
/// does, into a headless swap chain).
const _name = 'umg: viewport widget character customisation in a headless game host';

const _w = 1024;
const _h = 768;

/// Where the Viewport sits on the HUD.
const _viewportRect = Rect.fromLTWH(480, 128, 512, 512);

const _cardAt = 'contents/meshes/static/SM_AccessCard.lmas';

/// The level's props (test-assets paths) and where they stand (cm, Y up).
const _props = [
  'Props/Barrels/fuel_barrel_red.glb',
  'Props/Barrels/dented_barrel.glb',
  'Props/AC_units/ac_unit_a_300x300.glb',
  'Props/AC_units/roof_aircon_unit_150x150_a.glb',
  'Props/Barrels/fuel_barrel_yellow.glb',
];
final _spots = [Vector3(-380, 0, -200), Vector3(-260, 0, 120), Vector3(320, 0, -420), Vector3(60, 0, -520), Vector3(420, 0, 60)];

/// The test-assets models this smoke draws.
List<String> get _used => [
      ..._props,
      ...ViewportTestProject.sources.values,
      'Props/Access_cards/access_card_green.glb',
      'Props/Ash Trays/ashtrayred_a.glb',
      'Props/Ash Trays/ashtrayyellow_b.glb',
    ];

/// The widget class umg_widget_codegen emits for WBP_Customizer: the
/// Viewport `Preview` (a LuminaUmgViewport bound to its element), the
/// buttons and the Status text.
class _WbpCustomizer extends StatelessWidget {
  const _WbpCustomizer({required this.instance});

  final Map<String, Object?> instance;

  @override
  Widget build(BuildContext context) {
    Widget button(String name, String label) => LuminaUmgElement(
          instance: instance,
          name: name,
          builder: (context, e) => LuminaUmgButton(
            key: ValueKey(name),
            onPressed: () => LuminaUserWidgets.fire(instance, name, LuminaWidgetEvents.onClicked),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(label, style: const TextStyle(fontFamily: 'Roboto', fontSize: 20)),
            ),
          ),
        );
    return Stack(children: [
      Positioned(
        left: 40,
        top: 140,
        width: 380,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xC0141820), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Customise', style: TextStyle(fontFamily: 'Roboto', fontSize: 30, color: Color(0xFFFFFFFF))),
            const SizedBox(height: 16),
            button('NextHat', 'Next Hat'),
            const SizedBox(height: 10),
            button('Colour', 'Colour'),
            const SizedBox(height: 16),
            LuminaUmgElement(
              instance: instance,
              name: 'Status',
              builder: (context, e) => Text('Yaw ${LuminaUmgElementBinding.value<String>(e, 'text', '–')}',
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 18, color: Color(0xFF9BE7FF))),
            ),
          ]),
        ),
      ),
      Positioned.fromRect(
        rect: _viewportRect,
        child: LuminaUmgElement(
          instance: instance,
          name: 'Preview',
          builder: (context, e) => LuminaUmgViewport(instance: instance, name: 'Preview', background: LuminaViewportEnvironmentMode.sky),
        ),
      ),
    ]);
  }
}

/// A character whose BeginPlay creates WBP_Customizer and adds it to the
/// viewport, as a game's Blueprint does.
class _CustomizerCharacter extends LuminaCharacter {
  Map<String, Object?>? widget;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    widget = LuminaBlueprintFunctionLibrary.createWidget(this, customizerClass) as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(this, widget, 0);
  }
}

/// The level: ground, sun, fill, sky, props and a camera over them.
List<LuminaActor> _level(String assets, List<LuminaStaticMeshComponent> meshes) {
  LuminaStaticMeshComponent mesh(String a) => LuminaStaticMeshComponent(meshAssetPath: '$assets/$a')..also(meshes.add);
  return [
    LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(1800, 1, 1400), color: Vector3(0.30, 0.33, 0.31)),
    LuminaActor(
      root: LuminaDirectionalLightComponent(
        rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.6) * Quaternion.axisAngle(Vector3(1, 0, 0), -0.95),
        intensity: 110000,
        castShadows: true,
      ),
    ),
    LuminaActor(root: LuminaSkyComponent.color(color: Vector4(0.36, 0.48, 0.70, 1), skyIntensity: 30000, iblIntensity: 22000)),
    for (var i = 0; i < _props.length; i++) LuminaActor(root: mesh(_props[i]), location: _spots[i]),
  ];
}

extension<T> on T {
  void also(void Function(T) f) => f(this);
}

class _SmokeGame extends LuminaGame {
  _SmokeGame(this.assets);
  final String assets;
  final meshes = <LuminaStaticMeshComponent>[];
  final character = _CustomizerCharacter();

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final camera = LuminaCameraComponent(rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.atan2(420, 1100)), fieldOfViewInDegrees: 60)
      ..isActive = true;
    return LuminaNodeGroup(children: [
      ..._level(assets, meshes),
      LuminaActor(root: camera, location: Vector3(0, 420, 1000)),
      character,
    ]);
  }
}

Future<void> _loadRoboto() async {
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final root = Platform.environment['FLUTTER_ROOT'] ?? (exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/')) : null);
  if (root == null) return;
  final font = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!font.existsSync()) return;
  final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

/// The project the graph's asset paths point into, plus the access card.
ViewportTestProject _project() => ViewportTestProject.create(
      mannequinAt: customizerMannequin,
      idleAt: customizerIdle,
      extra: const {
        customizerHatA: 'Props/Ash Trays/ashtrayred_a.glb',
        customizerHatB: 'Props/Ash Trays/ashtrayyellow_b.glb',
        _cardAt: 'Props/Access_cards/access_card_green.glb',
      },
    );

/// After Construct: the access card at the right hand, a little tilt, the
/// skeleton hidden for the shot (what a graph would add).
void _dressUp(LuminaActor self, Map<String, Object?> preview) {
  final scene = LuminaViewportScene.of(preview);
  final hero = scene.nodes.firstWhere((n) => n['kind'] == LuminaViewportNodeKind.skeletalMesh)['id']! as String;
  final card = LuminaViewportNodes.addStaticMesh(self, preview, _cardAt, {
    'location': [0.0, 0.0, 0.0],
    'rotation': [0.0, 0.0, 0.0],
    'scale': [1.0, 1.0, 1.0],
  });
  LuminaViewportNodes.attachToSocket(self, preview, card, hero, 'hand_r');
  LuminaViewportNodes.hideSkeleton(self, preview, hero);
  LuminaViewportNodes.addLight(self, preview, 'directional', [1.0, 0.96, 0.9, 1.0], 90000.0, {
    'location': [0.0, 0.0, 300.0],
    'rotation': [-50.0, 0.0, 35.0],
    'scale': [1.0, 1.0, 1.0],
  });
}

/// Lifts the hat 17 cm above the head joint (world up, in the bone's own
/// frame) and makes the card at the hand easier to see.
void _fitParts(LuminaActor self, Map<String, Object?> preview, LuminaViewportController c) {
  final scene = LuminaViewportScene.of(preview);
  final hero = scene.nodes.firstWhere((n) => n['kind'] == LuminaViewportNodeKind.skeletalMesh)['id']! as String;
  final mesh = c.runtime.componentOf(hero)! as LuminaAnimatedMeshComponent;
  final head = mesh.jointWorldTransform('head')!.getRotation();
  final axes = [for (var i = 0; i < 3; i++) head.getColumn(i)..normalize()];
  final rotation = Matrix3.columns(axes[0], axes[1], axes[2])..transpose();
  final up = rotation.transformed(Vector3(0, 1, 0)) * 17.0;
  final lift = LuminaAxes.toAuthoringLocation(up);
  for (final n in scene.nodes) {
    if (n['parent'] != hero) continue;
    final onHead = n['socket'] == 'head';
    LuminaViewportNodes.setNodeTransform(self, preview, n['id']! as String, {
      'location': onHead ? lift : [0.0, 0.0, 0.0],
      'rotation': [0.0, 0.0, 0.0],
      'scale': onHead ? [1.6, 1.6, 1.6] : [2.0, 2.0, 2.0],
    });
  }
}

void main() {
  late ViewportTestProject project;

  setUpAll(() {
    if (!ViewportTestProject.available) return;
    project = _project();
    LuminaAssets.projectDir = project.dir.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    if (ViewportTestProject.available) project.delete();
  });

  void register() {
    LuminaWidgetClassRegistry.register(customizerWidgetClass);
    LuminaWidgetBuilderRegistry.register(customizerClass, customizerWidgetClass, (context, instance) => _WbpCustomizer(instance: instance));
    LuminaUserWidgets.register(customizerClass, WbpCustomizerGraph.new);
    addTearDown(() {
      LuminaUserWidgets.clear();
      LuminaWidgetBuilderRegistry.clear();
      LuminaWidgetClassRegistry.clear();
      LuminaViewportBudget.shared.reset();
    });
  }

  Map<String, Object?> previewOf(Map<String, Object?> widget) => (widget['elements']! as Map)['Preview'] as Map<String, Object?>;

  Future<void> wait(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  /// The pointer steps of the scenario: an orbit drag over the Viewport.
  Future<void> orbit(WidgetTester tester, Future<void> Function(Duration) hold, double dx) async {
    final centre = _viewportRect.center;
    final g = await tester.startGesture(centre + const Offset(0, 140), buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 30; i++) {
      await g.moveBy(Offset(dx / 30, 0));
      await hold(const Duration(milliseconds: 33));
    }
    await g.up();
  }

  testWidgets('$_name (Flutter path)', (tester) async {
    if (!ViewportTestProject.available) return markTestSkipped('test-assets models missing');
    await tester.runAsync(_loadRoboto);
    tester.view.physicalSize = const Size(_w * 1.0, _h * 1.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    register();
    LuminaLevelPreloader.instance.manifestResolver = (_) => const <LuminaAssetRef>[];
    addTearDown(LuminaLevelPreloader.instance.reset);
    final events = <String>[];

    _SmokeGame? game;
    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: boundary,
        child: LuminaGameHost(initialLevel: 'L_Customize', captureMouse: false, createGame: (_) => game = _SmokeGame(SmokeArtifacts.testAssetsDir.path)),
      ),
    ));
    await wait(tester, () => game?.character.widget != null, max: 200);
    final g = game!;
    final widget = g.character.widget!;
    final preview = previewOf(widget);
    await wait(tester, () => g.meshes.every((m) => m.isLoaded) && find.byType(LuminaUmgViewport).evaluate().isNotEmpty);
    final state = tester.state<LuminaUmgViewportState>(find.byType(LuminaUmgViewport));
    await wait(tester, () => state.controller != null);
    final controller = state.controller!;
    final origFire = controller.fire;
    controller.fire = (e, a) {
      events.add(e);
      origFire(e, a);
    };
    _dressUp(g.character, preview);
    await wait(tester, () => controller.runtime.isReady && controller.runtime.nodeIds.length >= 4);
    expect(state.path, LuminaUmgViewportPath.flutter);
    expect(controller.runtime.failures, isEmpty);
    _fitParts(g.character, preview, controller);

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await rec.hold(const Duration(milliseconds: 1500));
    await orbit(tester, rec.hold, -260);
    await rec.hold(const Duration(milliseconds: 600));
    expect(events, contains(LuminaWidgetEvents.onCameraChanged));
    expect(find.textContaining('Yaw '), findsOneWidget);
    final heroId = controller.scene!.nodes.first['id']! as String;
    final hatId = controller.scene!.nodes[1]['id']! as String;
    await tester.tap(find.byKey(const ValueKey('NextHat')));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(controller.scene!.node(hatId)!['asset'], customizerHatB, reason: 'Next Hat swapped the hat');
    await tester.tap(find.byKey(const ValueKey('Colour')));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(((controller.scene!.node(heroId)!['materialParams']! as Map)['0'] as Map)['baseColorFactor'], [0.9, 0.2, 0.1, 1.0]);
    final head = controller.runtime.jointsOf(heroId).firstWhere((j) => j.name == 'head');
    final (hx, hy) = controller.runtime.project(head.position)!;
    await tester.tapAt(_viewportRect.topLeft + Offset(hx, hy), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await rec.hold(const Duration(milliseconds: 1200));
    expect(events, contains(LuminaWidgetEvents.onPicked));
    await orbit(tester, rec.hold, 200);
    await rec.hold(const Duration(milliseconds: 2500));

    final png = await SmokeCapture.captureWidgetPng(tester, find.byKey(boundary));
    SmokeArtifacts.saveScreenshot('$_name (Flutter path)', png, usedAssets: _used);
    rec.save('$_name (Flutter path)', usedAssets: _used);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('$_name (Direct path)', (tester) async {
    if (!ViewportTestProject.available) return markTestSkipped('test-assets models missing');
    await tester.runAsync(_loadRoboto);
    tester.view.physicalSize = const Size(_w * 1.0, _h * 1.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    register();
    final lease = FilamentEngineHost.acquire(owner: 'umg viewport smoke game', backend: FilamentBackend.vulkan);
    if (lease == null) return markTestSkipped('needs a Vulkan device');
    final engine = lease.engine;
    final scene = engine.createScene();
    final gameView = engine.createView();
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(_w, _h);
    final overlay = FilamentUiOverlay.create(engine)!..setViewport(0, 0, _w, _h);
    gameView
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, _w, _h);
    camera.setProjectionFov(fovDegrees: 60, aspect: _w / _h, near: 10, far: 100000);
    camera.lookAt(eyeX: 0, eyeY: 420, eyeZ: 1000, centerX: 0, centerY: 60, centerZ: -150);
    camera.setExposure(aperture: 16.0, shutterSpeed: 1.0 / 125.0, sensitivity: 100.0);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: gameView);
    final meshes = <LuminaStaticMeshComponent>[];
    for (final a in _level(SmokeArtifacts.testAssetsDir.path, meshes)) {
      world.persistentLevel.registerActor(a);
    }
    final character = _CustomizerCharacter();
    world.persistentLevel.registerActor(character);
    final host = LuminaViewportHost()
      ..engine = engine
      ..presentingDirectly = true;
    addTearDown(() {
      host.dispose();
      world.cleanup();
      overlay.dispose();
      renderer.dispose();
      swapChain.dispose();
      gameView.dispose();
      camera.dispose();
      engine.destroyEntity(cameraEntity);
      scene.dispose();
      lease.release();
    });
    final events = <String>[];

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LuminaViewportHostScope(
        host: host,
        child: LuminaUiCapture(overlay: overlay, child: SizedBox(width: _w * 1.0, height: _h * 1.0, child: LuminaWidgetLayer(world: world))),
      ),
    ));
    world.beginPlay();
    await wait(tester, () => character.widget != null && find.byType(LuminaUmgViewport).evaluate().isNotEmpty, max: 200);
    final state = tester.state<LuminaUmgViewportState>(find.byType(LuminaUmgViewport));
    await wait(tester, () => state.controller != null);
    final controller = state.controller!;
    final origFire = controller.fire;
    controller.fire = (e, a) {
      events.add(e);
      origFire(e, a);
    };
    _dressUp(character, previewOf(character.widget!));
    await wait(tester, () => meshes.every((m) => m.isLoaded) && controller.runtime.isReady && controller.runtime.nodeIds.length >= 4);
    expect(state.path, LuminaUmgViewportPath.direct);
    expect(find.byType(FilamentWidget), findsNothing);
    _fitParts(character, previewOf(character.widget!), controller);

    // One game frame the way the direct presenter draws it: the game's
    // view, the Viewport views at their rectangles, then the UI overlay.
    final pixels = Uint8List(_w * _h * 4);
    final gameMs = <double>[];
    Uint8List frame() {
      world.tick(1 / 30);
      final sw = Stopwatch()..start();
      if (renderer.beginFrame(swapChain)) {
        for (final v in host.frameViews(gameView, _w, _h)) {
          renderer.render(v);
        }
        overlay.render(renderer);
        renderer.readPixels(x: 0, y: 0, width: _w, height: _h, outPixels: pixels);
        renderer.endFrame();
      }
      engine.flushAndWait();
      gameMs.add(sw.elapsedMicroseconds / 1000);
      return Uint8List.fromList(pixels);
    }

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: '$_name (Direct path)');
    addTearDown(video.discard);
    Future<void> hold(Duration d) async {
      final n = (d.inMicroseconds / 33333).ceil();
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 4)));
        video.addFrame(frame());
      }
    }

    await hold(const Duration(milliseconds: 1500));
    final capturesBefore = LuminaUiCapture.stats.value.captures;
    await hold(const Duration(milliseconds: 1500));
    expect(LuminaUiCapture.stats.value.captures, capturesBefore, reason: 'the playing idle never re-captures the UI');
    await orbit(tester, hold, -260);
    await hold(const Duration(milliseconds: 600));
    final heroId = controller.scene!.nodes.first['id']! as String;
    final hatId = controller.scene!.nodes[1]['id']! as String;
    await tester.tap(find.byKey(const ValueKey('NextHat')));
    await hold(const Duration(milliseconds: 1500));
    expect(controller.scene!.node(hatId)!['asset'], customizerHatB);
    await tester.tap(find.byKey(const ValueKey('Colour')));
    await hold(const Duration(milliseconds: 1500));
    final head = controller.runtime.jointsOf(heroId).firstWhere((j) => j.name == 'head');
    final (hx, hy) = controller.runtime.project(head.position)!;
    await tester.tapAt(_viewportRect.topLeft + Offset(hx, hy), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await hold(const Duration(milliseconds: 1200));
    await orbit(tester, hold, 200);
    await hold(const Duration(milliseconds: 1800));
    expect(events, containsAll([LuminaWidgetEvents.onCameraChanged, LuminaWidgetEvents.onPicked]));

    // Cost on GPU 1: 120 frames of the game alone, with the Viewport in its
    // frame (Direct), and with the Viewport's own 512×512 frame and
    // readback (the Flutter path's FilamentWidget).
    final viewportView = controller.runtime.view;
    final ownRenderer = engine.createRenderer();
    final ownChain = engine.createHeadlessSwapChain(512, 512);
    final ownPixels = Uint8List(512 * 512 * 4);
    ({double wall, double gpu}) measure(String mode) {
      final wall = <double>[];
      for (var i = 0; i < 150; i++) {
        world.tick(1 / 60);
        controller.frame(1 / 60);
        final sw = Stopwatch()..start();
        if (renderer.beginFrame(swapChain)) {
          renderer.render(gameView);
          if (mode == 'direct') {
            viewportView.setViewport(_viewportRect.left.round(), (_h - _viewportRect.bottom).round(), 512, 512);
            renderer.render(viewportView);
          }
          renderer.endFrame();
        }
        if (mode == 'flutter') {
          viewportView.setViewport(0, 0, 512, 512);
          if (ownRenderer.beginFrame(ownChain)) {
            ownRenderer.render(viewportView);
            ownRenderer.readPixels(x: 0, y: 0, width: 512, height: 512, outPixels: ownPixels);
            ownRenderer.endFrame();
          }
        }
        engine.flushAndWait();
        if (i >= 30) wall.add(sw.elapsedMicroseconds / 1000);
      }
      final gpu = [
        for (final f in renderer.getFrameInfoHistory(100)) if (f.gpuFrameDuration > 0) f.gpuFrameDuration / 1e6,
        if (mode == 'flutter')
          for (final f in ownRenderer.getFrameInfoHistory(100)) if (f.gpuFrameDuration > 0) f.gpuFrameDuration / 1e6,
      ];
      double mean(List<double> v) => v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
      final perFrameGpu = mode == 'flutter' ? mean(gpu) * 2 : mean(gpu);
      return (wall: mean(wall), gpu: perFrameGpu);
    }

    final alone = measure('game');
    final direct = measure('direct');
    final flutter = measure('flutter');
    ownRenderer.dispose();
    ownChain.dispose();
    final metrics = <String, Object?>{
      'game frame ms (scenario, mean)': double.parse((gameMs.reduce((a, b) => a + b) / gameMs.length).toStringAsFixed(2)),
      'game alone ms': double.parse(alone.wall.toStringAsFixed(2)),
      'game + Viewport (Direct) ms': double.parse(direct.wall.toStringAsFixed(2)),
      'game + Viewport (Flutter, own frame + readback) ms': double.parse(flutter.wall.toStringAsFixed(2)),
      'game alone GPU ms': alone.gpu.isNaN ? 'n/a' : double.parse(alone.gpu.toStringAsFixed(3)),
      'Viewport added GPU ms (Direct)': direct.gpu.isNaN ? 'n/a' : double.parse((direct.gpu - alone.gpu).toStringAsFixed(3)),
      'game + Viewport fps (Direct)': double.parse((1000 / direct.wall).toStringAsFixed(1)),
      'game + Viewport fps (Flutter)': double.parse((1000 / flutter.wall).toStringAsFixed(1)),
    };
    debugPrint('[umg viewport smoke] $metrics');
    SmokeArtifacts.saveScreenshot('$_name (Direct path)', SmokeArtifacts.encodePng(_w, _h, frame()), usedAssets: _used, metrics: metrics);
    SmokeArtifacts.saveVideo('$_name (Direct path)', video.finish(), usedAssets: _used);
    expect(1000 / direct.wall, greaterThanOrEqualTo(60), reason: 'Direct: 60 fps with the Viewport');
    expect(1000 / flutter.wall, greaterThanOrEqualTo(60), reason: 'Flutter path: 60 fps with the Viewport');
    if (!direct.gpu.isNaN && !alone.gpu.isNaN) {
      expect(direct.gpu - alone.gpu, lessThanOrEqualTo(1.5), reason: 'one 512×512 animated Viewport adds at most 1.5 ms of GPU time');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }, timeout: const Timeout(Duration(minutes: 8)));
}
