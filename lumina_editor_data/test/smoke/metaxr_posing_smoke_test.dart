import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

/// The built MetaXR posing project (local: a MetaHuman, never shipped).
String get _projectDir =>
    Platform.environment['LUMINA_METAXR_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/metaxr_posing';

/// A controller played from a script: its grip pose and squeeze.
class _ScriptedController implements LuminaGrabber {
  _ScriptedController(this.id);

  @override
  final String id;
  final Vector3 position = Vector3.zero();
  double squeeze = 0;
  int pulses = 0;

  @override
  Matrix4 get worldTransform => Matrix4.translation(position);

  @override
  double get grip => squeeze;

  @override
  bool get isTracked => true;

  @override
  LuminaGrabRay? get ray => null;

  @override
  void pulse(double amplitude, double seconds) => pulses++;

  @override
  void grabbedAt(Vector3 point) {}
}

/// The posing example's `L_Room` on the GPU, as the game builds it on a
/// desktop: the game mode's `BP_XRPlayer`, `BP_PosedCharacter` with the
/// MetaHuman, both lights; a scripted controller grabs the hand, the elbow,
/// the head, the foot and the pelvis, then the pose is saved to slot 1,
/// reset, and loaded again. The room is a neutral backdrop here (the
/// passthrough layer is the headset's). Skips without the built project.
void main() {
  final level = File('$_projectDir/${MetaXrPosingLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the MetaXR posing project is not built here ($_projectDir)';

  test('metaxr posing: grab and pose the MetaHuman, save slot 1, reset, load slot 1', () async {
    const name = 'metaxr posing: grab and pose the MetaHuman, save slot 1, reset, load slot 1';
    final dir = _projectDir;
    final project = LuminaProject.fromMap(jsonDecode(File('$dir/metaxr_posing.lmproject').readAsStringSync()) as Map<String, dynamic>);
    final previousProvider = LuminaAssets.defaultProvider;
    final previousSaves = LuminaSaveGameSubsystem.defaultSaveDirectoryPath;
    final saves = Directory.systemTemp.createTempSync('metaxr_posing_saves_');
    bool absolute(String p) => p.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(p);
    LuminaAssets.defaultProvider = (path) => File(absolute(path) ? path : '$dir/$path').readAsBytes();
    LuminaSaveGameSubsystem.defaultSaveDirectoryPath = saves.path;
    addTearDown(() {
      LuminaAssets.defaultProvider = previousProvider;
      LuminaSaveGameSubsystem.defaultSaveDirectoryPath = previousSaves;
      saves.deleteSync(recursive: true);
    });
    MetaXrPosingContent.declarePluginNodes();

    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(_w, _h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, _w, _h);
    camera.setProjection(fovDegrees: 50, aspect: _w / _h, near: 5, far: 20000, direction: FovDirection.vertical);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    final pixels = calloc<ffi.Uint8>(_w * _h * 4);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.30, 0.31, 0.33, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.5, 0.5, 0.52]), intensity: 20000));

    // L_Room: its lights and placed Blueprints, as the generated level does.
    final registry = LuminaBlueprintClassRegistry(dir);
    final actors = (jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List;
    LuminaActor? character;
    for (final a in actors.cast<Map>()) {
      final loc = ((a['location'] as List?) ?? const [0, 0, 0]).cast<num>();
      final rot = ((a['rotation'] as List?) ?? const [0, 0, 0]).cast<num>();
      if (a['type'] == 'DirectionalLight') {
        world.persistentLevel.registerActor(LuminaActor(
            root: LuminaDirectionalLightComponent(
                rotation: LuminaAxes.rotation(rot), intensity: (a['lightIntensity'] as num).toDouble(), castShadows: a['castShadows'] == true)));
      } else if (a['type'] == 'PlayerStart') {
        world.persistentLevel.registerActor(LuminaPlayerStart(location: LuminaAxes.location(loc)));
      } else if (a['blueprintClass'] == MetaXrPosingContent.characterPath) {
        final cls = registry.classFor(MetaXrPosingContent.characterPath)!;
        expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
        character = cls.instantiate(location: LuminaAxes.location(loc), rotation: LuminaAxes.rotation(rot));
        world.persistentLevel.registerActor(character);
      }
    }
    final mode = registry.createGameMode(project.mapsAndModes);
    expect(mode, isNotNull, reason: '${registry.diagnostics}');
    final bound = ProjectInputBinder.bind(project.input);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    for (final ctx in bound.contexts) {
      input.addMappingContext(ctx.context, priority: ctx.priority);
    }
    world.gameMode = mode;
    world.beginPlay();
    final pc = mode!.login();
    world.tick(1 / 60);
    final player = pc.pawn!;
    final mesh = character!.getComponent<LuminaAnimatedMeshComponent>()!;
    final loadWatch = Stopwatch()..start();
    await mesh.loaded.timeout(const Duration(minutes: 3));
    final meshLoadMs = loadWatch.elapsedMilliseconds;
    final poser = character.getComponent<LuminaPoseAuthoringComponent>()!;
    for (var i = 0; i < 60 && poser.rig == null; i++) {
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      engine.flushAndWait();
      await Future<void>.delayed(Duration.zero);
    }
    expect(poser.rig, isNotNull, reason: 'the MetaHuman rig is detected');
    final interactor = player.getComponent<LuminaPoseGrabInteractor>()!;
    final hand = _ScriptedController('right');
    interactor.registerGrabber(hand);

    // The view: from 2.3 m in front of the character, at chest height.
    final at = character.actorLocation;
    camera.lookAt(eyeX: at.x + 60, eyeY: 120, eyeZ: at.z + 260, centerX: at.x, centerY: 95, centerZ: at.z);

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final solveMs = <double>[];
    final frameMs = <double>[];
    Uint8List capture() {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 1) {
            c.filament_renderer_read_pixels(
                renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      frameMs.add(sw.elapsedMicroseconds / 1000);
      return Uint8List.fromList(pixels.asTypedList(_w * _h * 4));
    }

    Uint8List? last;
    void step() {
      final sw = Stopwatch()..start();
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      solveMs.add(sw.elapsedMicroseconds / 1000);
      last = capture();
      video.addFrame(last!);
    }

    void hold(double seconds) {
      for (var i = 0; i < (seconds * 30).round(); i++) {
        step();
      }
    }

    final usedAssets = [mesh.meshAssetPath];
    final reports = <String, Object>{};
    void shot(String label) => SmokeArtifacts.saveScreenshot('$name — $label', SmokeArtifacts.encodePng(_w, _h, last!),
        usedAssets: usedAssets);

    /// Grabs [handle], drags it by [offset] (runtime cm) over [seconds], releases.
    void drag(String label, String handle, Vector3 offset, {double seconds = 1.5}) {
      final start = poser.handleWorldLocation(handle)!.clone();
      hand.position.setFrom(start);
      hold(0.2);
      hand.squeeze = 1;
      hold(0.2);
      expect(interactor.heldBy(hand)?.handle, handle, reason: label);
      final frames = (seconds * 30).round();
      for (var i = 1; i <= frames; i++) {
        hand.position.setFrom(start + offset * (i / frames));
        step();
      }
      hand.squeeze = 0;
      hold(0.3);
      final reached = poser.handleWorldLocation(handle)!;
      reports[label] = {'handle': handle, 'error_cm': reached.distanceTo(start + offset), 'moved_cm': reached.distanceTo(start)};
      shot(label);
    }

    void press(LuminaKey key, double seconds) {
      input.injectKeyDown(key);
      hold(seconds);
      input.injectKeyUp(key);
      hold(0.2);
    }

    hold(1.0);
    shot('01 the MetaHuman in the room');
    final restHand = poser.handleWorldLocation('hand_r')!.clone();
    drag('02 right hand up', 'hand_r', Vector3(-10, 45, 10));
    drag('03 left elbow out', 'elbow_l', Vector3(25, 5, 0));
    drag('04 head turned', 'head', Vector3(8, 0, 4));
    drag('05 right foot forward', 'foot_r', Vector3(0, 8, 30));
    drag('06 pelvis down', 'pelvis', Vector3(0, -15, 0));
    final posedHand = poser.handleWorldLocation('hand_r')!.clone();
    press(LuminaKey.xrRightA, MetaXrPosingContent.saveHoldSeconds + 0.3);
    shot('07 saved to slot 1');
    press(LuminaKey.xrLeftMenu, MetaXrPosingContent.resetHoldSeconds + 0.3);
    hold(0.5);
    shot('08 reset to the rest pose');
    expect(poser.handleWorldLocation('hand_r')!.distanceTo(restHand), lessThan(5.0), reason: 'reset to the rest pose');
    // X steps back to slot 4 (empty), A forward to slot 1, which loads.
    press(LuminaKey.xrLeftX, 0.1);
    press(LuminaKey.xrRightA, 0.1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    hold(1.5);
    shot('09 slot 1 loaded');
    expect(poser.handleWorldLocation('hand_r')!.distanceTo(posedHand), lessThan(8.0), reason: 'slot 1 brings the pose back');

    for (final r in reports.values.cast<Map>()) {
      // Every grab moved its part; the hand, the foot and the pelvis reach
      // the controller (the elbow swings the arm, the head turns on the neck).
      expect(r['moved_cm'] as double, greaterThan(3.0), reason: '$r');
      if (const {'hand_r', 'foot_r', 'pelvis'}.contains(r['handle'])) expect(r['error_cm'] as double, lessThan(12.0), reason: '$r');
    }
    expect(hand.pulses, greaterThanOrEqualTo(5), reason: 'a haptic tick per grab');
    solveMs.sort();
    frameMs.sort();
    final metrics = {
      'meshLoadMs': meshLoadMs,
      'solveMsMedian': solveMs[solveMs.length ~/ 2],
      'solveMsP95': solveMs[(solveMs.length * 0.95).floor()],
      'frameMsMedian': frameMs[frameMs.length ~/ 2],
      'frameMsP95': frameMs[(frameMs.length * 0.95).floor()],
      'grabs': reports,
    };
    final out = File('${SmokeArtifacts.dir.path}/metaxr_posing_metrics.json')..createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metrics));
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: usedAssets);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}
