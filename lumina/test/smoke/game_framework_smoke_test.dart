import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;

class SmokeGameInstance extends LuminaGameInstance {
  int openLevelCount = 0;
  
  @override
  Future<void> openLevel(LuminaLevel Function() levelBuilder) async {
    await super.openLevel(levelBuilder);
    openLevelCount++;
  }
}

class SmokeGame extends LuminaGame {
  SmokeGame() : super(gameInstanceFactory: () => SmokeGameInstance());
}

/// Barrel that spins around Y every tick so play / pause / step are visible in the captures.
class SpinningBarrelActor extends LuminaActor {
  final LuminaStaticMeshComponent mesh;
  int tickCount = 0;
  double angle = 0.0;

  SpinningBarrelActor._(this.mesh) : super(root: mesh);

  factory SpinningBarrelActor({required String assetPath, required Vector3 location}) =>
      SpinningBarrelActor._(LuminaStaticMeshComponent(meshAssetPath: assetPath, location: location));

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    angle += deltaTime * math.pi; // half a turn per second
    mesh.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), angle);
  }
}

/// Game whose declarative tree places two real barrels from test-assets into the persistent level.
class PieControlGame extends LuminaGame {
  final String assetsRoot;
  SpinningBarrelActor? spinner;
  LuminaStaticMeshComponent? staticBarrel;

  PieControlGame(this.assetsRoot);

  @override
  LuminaObject? build(LuminaBuildContext context) {
    spinner = SpinningBarrelActor(
      assetPath: '$assetsRoot/Props/Barrels/fuel_barrel_black.glb',
      location: Vector3(-80.0, 0.0, 0.0), // cm, like the world
    );
    staticBarrel = LuminaStaticMeshComponent(
      meshAssetPath: '$assetsRoot/Props/Barrels/fuel_barrel_red.glb',
      location: Vector3(80.0, 0.0, 0.0),
    );
    return LuminaNodeGroup(children: [
      spinner!,
      LuminaActor(root: staticBarrel),
    ]);
  }
}

void main() {
  test('PIE control Smoke Test: play, pause, step, restart with real barrels on GPU 1', () async {
    final assetsDir = SmokeArtifacts.testAssetsDir;
    const usedAssets = [
      'Props/Barrels/fuel_barrel_black.glb',
      'Props/Barrels/fuel_barrel_red.glb',
    ];
    for (final a in usedAssets) {
      expect(File('${assetsDir.path}/$a').existsSync(), isTrue, reason: 'missing test asset $a');
    }

    const width = SmokeVideo.defaultWidth;
    const height = SmokeVideo.defaultHeight;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(width, height);
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);

    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    camera.setProjection(
      fovDegrees: 45.0,
      aspect: width / height,
      near: 10.0,
      far: 10000.0,
      direction: FovDirection.vertical,
    );
    camera.lookAt(eyeX: 0.0, eyeY: 160.0, eyeZ: 400.0, centerX: 0.0, centerY: 50.0, centerZ: 0.0);

    final skybox = FilamentSkybox.build(engine, color: Vector4(0.12, 0.14, 0.18, 1.0), intensity: 30000.0);
    scene.setSkybox(skybox);
    final sunEntity = engine.createEntity();
    LightBuilder(LightType.directional)
        .color(1.0, 0.98, 0.95)
        .intensity(100000.0)
        .direction(-0.4, -0.8, -0.6)
        .castShadows(true)
        .build(engine, sunEntity);
    scene.addEntity(sunEntity);
    final indirectLight = FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 35000.0,
    );
    scene.setIndirectLight(indirectLight);

    final pixelBuf = calloc<ffi.Uint8>(width * height * 4);
    // Every 2nd vsync (30 fps of the 60 Hz driver) goes into the video, so it
    // shows play, pause, step and restart in real time.
    final video = SmokeVideoRecorder(
      width: width,
      height: height,
      fps: 30,
      testName: 'game_framework_smoke_test: PIE control',
    );
    addTearDown(video.discard);
    // Renders and reads back the current state. The driver's own frame is
    // still in flight, and Filament skips a frame whose predecessor's fence has
    // not signalled — so wait for the GPU first, and never hand back a stale
    // read-back as a new frame.
    Uint8List captureFrame() {
      for (var attempt = 0; attempt < 10; attempt++) {
        engine.flushAndWait();
        if (!renderer.beginFrame(swapChain)) continue;
        renderer.render(view);
        c.filament_renderer_read_pixels(
          renderer.nativePointer,
          engine.nativePointer,
          0,
          0,
          width,
          height,
          pixelBuf.cast(),
          ffi.nullptr,
          ffi.nullptr,
        );
        renderer.endFrame();
        engine.flushAndWait();
        return Uint8List.fromList(pixelBuf.asTypedList(width * height * 4));
      }
      throw StateError('Filament skipped every attempt to render a capture frame');
    }

    var vsync = 0;
    var vsyncCount = 0;
    void pump(LuminaFrameDriver driver, int count) {
      for (var i = 0; i < count; i++) {
        driver.onVsync(vsync);
        vsync += 16666667;
        if (vsyncCount++ % 2 == 0) video.addFrame(captureFrame());
      }
    }

    final states = <LuminaPlayState>[];
    final game = PieControlGame(assetsDir.path);
    final sub = game.playStateStream.listen(states.add);

    // 1. Mount + begin play; wait for both real GLBs to land in the scene.
    game.mountGame(engine, scene);
    final world1 = game.world!;
    world1.beginPlay();
    await game.spinner!.mesh.loaded;
    await game.staticBarrel!.loaded;
    expect(game.spinner!.mesh.isLoaded, isTrue);
    expect(game.staticBarrel!.isLoaded, isTrue);
    expect(world1.actors.length, 2);

    final driver = LuminaFrameDriver(
      world1,
      renderer: renderer,
      swapChain: swapChain,
      view: view,
      useFramePacer: false,
    );

    // 2. Play 4 s (240 ticks at 60 Hz): the black barrel spins two turns.
    vsync = engine.steadyClockTimeNano;
    pump(driver, 240);
    expect(world1.tickCount, 240);
    expect(game.spinner!.tickCount, 240);
    SmokeArtifacts.saveScreenshot(
      'game_framework_smoke_test: PIE control 01 playing',
      SmokeArtifacts.encodePng(width, height, captureFrame()),
      usedAssets: usedAssets,
    );

    // 3. Pause for 1.5 s: the driver keeps presenting, the world does not tick
    // (the held picture stays under the smoke videos' 2 s per frame limit).
    game.pause();
    expect(game.isPaused, isTrue);
    expect(world1.isPaused, isTrue);
    pump(driver, 90);
    expect(world1.tickCount, 240);
    expect(game.spinner!.tickCount, 240);

    // 4. Step exactly one tick while paused, and stay paused a moment.
    game.step(1.0 / 60.0);
    expect(world1.tickCount, 241);
    expect(game.spinner!.tickCount, 241);
    expect(game.isPaused, isTrue);
    pump(driver, 24);
    expect(world1.tickCount, 241);
    SmokeArtifacts.saveScreenshot(
      'game_framework_smoke_test: PIE control 02 paused after step',
      SmokeArtifacts.encodePng(width, height, captureFrame()),
      usedAssets: usedAssets,
    );

    // 5. Restart: fresh world, same engine/scene, tree re-mounted, playing again.
    final oldSpinner = game.spinner!;
    game.restart();
    final world2 = game.world!;
    expect(world1.isCleanedUp, isTrue);
    expect(world2, isNot(same(world1)));
    expect(world2.filamentEngine, same(engine));
    expect(world2.filamentScene, same(scene));
    expect(world2.hasBegunPlay, isTrue);
    expect(world2.tickCount, 0);
    expect(game.playState, LuminaPlayState.playing);
    expect(game.spinner, isNot(same(oldSpinner)));
    await game.spinner!.mesh.loaded;
    await game.staticBarrel!.loaded;
    expect(world2.actors.length, 2);

    driver.dispose();
    final driver2 = LuminaFrameDriver(
      world2,
      renderer: renderer,
      swapChain: swapChain,
      view: view,
      useFramePacer: false,
    );
    // Play the fresh world for 5 s.
    pump(driver2, 300);
    expect(world2.tickCount, 300);
    expect(game.spinner!.tickCount, 300);
    expect(oldSpinner.tickCount, 241);
    SmokeArtifacts.saveScreenshot(
      'game_framework_smoke_test: PIE control 03 restarted',
      SmokeArtifacts.encodePng(width, height, captureFrame()),
      usedAssets: usedAssets,
    );

    // 6. The video: 654 vsyncs, 327 frames at 30 fps, ~11 s.
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(
      'game_framework_smoke_test: PIE control 01 playing',
      video.finish(),
      usedAssets: usedAssets,
    );

    // 7. Teardown.
    driver2.dispose();
    game.disposeGame();
    await Future<void>.delayed(Duration.zero); // let the broadcast stream flush
    await sub.cancel();
    expect(states, [
      LuminaPlayState.playing,
      LuminaPlayState.paused,
      LuminaPlayState.playing,
      LuminaPlayState.stopped,
    ]);

    calloc.free(pixelBuf);
    skybox.dispose();
    indirectLight.dispose();
    engine.destroyEntity(sunEntity);
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    view.dispose();
    renderer.dispose();
    swapChain.dispose();
    scene.dispose();
    engine.dispose();
  });

  testWidgets('LuminaGameInstance Smoke Test: Rendering Lifecycle', (tester) async {
    // 1. Initialize Filament headless
    final engine = FilamentEngine.create()!;
    final swapChain = engine.createHeadlessSwapChain(256, 256);
    final scene = engine.createScene();
    
    // 2. Initialize Game
    final game = SmokeGame();
    game.mountGame(engine, scene);
    
    final instance = game.gameInstance as SmokeGameInstance;
    
    // 3. Tick initial world
    instance.world!.beginPlay();
    game.tickGame(0.016);
    expect(instance.world, isNotNull);
    
    // 4. Open Level
    await instance.openLevel(() => LuminaLevel(children: []));
    expect(instance.openLevelCount, 1);
    
    // 5. Tick new world
    instance.world!.beginPlay();
    game.tickGame(0.016);
    game.tickGame(0.016);
    game.tickGame(0.016);
    
    // 6. Camera Blend and Shake Smoke Test
    final pc = instance.primaryPlayerController;
    if (pc != null) {
      final cameraManager = pc.cameraManager;
      final tempActor = LuminaActor(location: Vector3(10, 20, 30));
      instance.world!.spawnActor(tempActor);
      cameraManager.setViewTargetWithBlend(tempActor, blendTime: 0.5);
      
      final shake = LuminaCameraShake(
        locationAmplitude: Vector3(0, 1, 0),
        locationFrequency: Vector3(0, 10, 0),
        duration: 0.5,
      );
      cameraManager.startCameraShake(shake);
      
      for (int i = 0; i < 40; i++) {
        game.tickGame(0.016);
      }
      
      expect(cameraManager.viewTarget, equals(tempActor));
      expect(cameraManager.cameraCachePov.location.x, closeTo(10.0, 1e-4));
    }
    
    // 7. Verify native context continuity
    expect(instance.world!.filamentEngine, engine);
    expect(instance.world!.filamentScene, scene);
    
    // 7. Cleanup
    game.disposeGame();
    
    swapChain.dispose();
    scene.dispose();
    engine.dispose();
  });
}
