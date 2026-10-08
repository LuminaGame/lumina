import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Game Animation Sample example project played on the GPU: its
/// `L_Sandbox`, its game mode spawning the MetaHuman character, and the
/// project input driving idle → walk → run → sprint → stop → crouch walk →
/// jump. The project is built locally from the sample's export and a
/// MetaHuman (neither can be shipped): the scenario skips without it.
const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

void main() {
  final level = File('$_projectDir/${GaspSandboxLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the Game Animation Sample project is not built here ($_projectDir)';

  test('game animation sample: the MetaHuman walks, runs, sprints, stops, crouches and jumps in L_Sandbox', () async {
    const name = 'game animation sample: the MetaHuman walks, runs, sprints, stops, crouches and jumps in L_Sandbox';
    final dir = _projectDir;
    final manifest = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.lmproject'));
    final project = LuminaProject.fromMap(jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>);
    final previousProvider = LuminaAssets.defaultProvider;
    final previousDir = LuminaAssets.projectDir;
    bool absolute(String p) => p.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(p);
    LuminaAssets.defaultProvider = (path) => File(absolute(path) ? path : '$dir/$path').readAsBytes();
    LuminaAssets.projectDir = dir;
    LuminaPoseSearchDatabaseRuntime.clearShared();
    addTearDown(() {
      LuminaAssets.defaultProvider = previousProvider;
      LuminaAssets.projectDir = previousDir;
      LuminaPoseSearchDatabaseRuntime.clearShared();
    });

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
    camera.setProjection(fovDegrees: 60, aspect: _w / _h, near: 10, far: 200000, direction: FovDirection.vertical);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.bindView(view);
    final pixels = calloc<ffi.Uint8>(_w * _h * 4);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });

    // L_Sandbox as the generated level builds it.
    final actors = (jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List;
    var start = Vector3.zero();
    final usedAssets = <String>{GaspSandboxLevel.levelPath};
    for (final a in actors.cast<Map>()) {
      final loc = ((a['location'] as List?) ?? const [0, 0, 0]).cast<num>();
      final rot = ((a['rotation'] as List?) ?? const [0, 0, 0]).cast<num>();
      final scl = ((a['scale'] as List?) ?? const [1, 1, 1]).cast<num>();
      switch (a['type']) {
        case 'PlayerStart':
          start = LuminaAxes.location(loc);
        case 'DirectionalLight':
          world.persistentLevel.registerActor(LuminaActor(
              root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation(rot), intensity: 100000, castShadows: true)));
        case 'Primitive':
          final props = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
          world.persistentLevel.registerActor(LuminaPrimitiveActor.fromComponentProperties(props,
              location: LuminaAxes.location(loc),
              rotation: LuminaAxes.rotation(rot),
              materialOverrideAsset: a['materialPath'] as String?));
          if (a['materialPath'] is String) usedAssets.add(a['materialPath'] as String);
        case 'StaticMesh':
          final mesh = a['meshAssetPath'] as String;
          world.persistentLevel.registerActor(LuminaActor(
              root: LuminaStaticMeshComponent(
                  meshAssetPath: mesh,
                  location: LuminaAxes.location(loc),
                  rotation: LuminaAxes.rotation(rot),
                  scale: LuminaAxes.scale(scl))));
          usedAssets.add(mesh.replaceAll(r'\', '/').split('/contents/').last);
      }
    }
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.56, 0.78, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.72]),
      intensity: 30000,
    ));

    // The project's game mode, character and input.
    final registry = LuminaBlueprintClassRegistry(dir);
    final mode = registry.createGameMode(project.mapsAndModes);
    expect(mode, isNotNull, reason: '${registry.diagnostics}');
    final bound = ProjectInputBinder.bind(project.input);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    for (final ctx in bound.contexts) {
      input.addMappingContext(ctx.context, priority: ctx.priority);
    }
    world.persistentLevel.registerActor(LuminaPlayerStart(location: start.clone()));
    world.gameMode = mode;
    world.beginPlay();
    final pc = mode!.login();
    world.tick(1 / 60);
    final character = pc.pawn as LuminaBlueprintCharacter;
    expect(character.blueprintClass.name, GaspCharacterContent.characterName);
    final mesh = character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent;
    final anim = character.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    final loadWatch = Stopwatch()..start();
    await mesh.loaded.timeout(const Duration(minutes: 3));
    final meshLoad = loadWatch.elapsed;
    // The databases load on background isolates from begin play; hold until
    // they have.
    final databases = [
      for (final f in Directory('$dir/contents/animations').listSync(recursive: true).whereType<File>())
        if (RegExp(r'/PSD_[^/]+\.lmas$').hasMatch(f.path.replaceAll(r'\', '/')))
          'contents/animations/${f.path.replaceAll(r'\', '/').split('/contents/animations/').last}',
    ];
    expect(databases.length, GaspDatabases.plans.length, reason: '$databases');
    for (var i = 0; i < 2400 && !databases.every(anim.motionMatching.isLoaded); i++) {
      // ignore: avoid_print
      if (i % 20 == 0) print('waiting for ${[for (final d in databases) if (!anim.motionMatching.isLoaded(d)) d.split('/').last]}');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      // Ticks without frames still queue skinning and morph updates: let
      // Filament run them, or its command buffer fills up.
      engine.flushAndWait();
    }
    final databasesLoad = loadWatch.elapsed;
    expect(databases.every(anim.motionMatching.isLoaded), isTrue, reason: anim.motionMatching.lastError);
    expect(anim.motionMatching.player, isNotNull, reason: anim.motionMatching.lastError);

    Uint8List capture() {
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
      return Uint8List.fromList(pixels.asTypedList(_w * _h * 4));
    }

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final tickMicros = <int>[];
    final renderMicros = <int>[];
    final phaseClips = <String, Set<String>>{};
    final phaseStates = <String, Set<String>>{};
    final phaseSpeeds = <String, double>{};

    double speed() {
      final v = character.characterMovement.velocity;
      return math.sqrt(v.x * v.x + v.z * v.z);
    }

    Future<void> phase(String label, double seconds,
        {List<LuminaKey> hold = const [], List<LuminaKey> tap = const [], double mouseX = 0.0}) async {
      for (final k in tap) {
        input.injectKeyDown(k);
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        input.injectKeyUp(k);
      }
      for (final k in hold) {
        input.injectKeyDown(k);
      }
      final frames = (seconds * 60).round();
      var peak = 0.0;
      for (var f = 0; f < frames; f++) {
        if (mouseX != 0) input.injectAnalog(LuminaKey.mouseX, mouseX);
        final w = Stopwatch()..start();
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        tickMicros.add(w.elapsedMicroseconds);
        final clip = anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable];
        if (clip is String && clip.isNotEmpty) (phaseClips[label] ??= {}).add(clip);
        (phaseStates[label] ??= {}).add(anim.currentState ?? '');
        peak = math.max(peak, speed());
        if (f.isEven) {
          final r = Stopwatch()..start();
          final frame = capture();
          renderMicros.add(r.elapsedMicroseconds);
          video.addFrame(frame);
          if (f == frames - 2) {
            SmokeArtifacts.saveScreenshot('$name — $label', SmokeArtifacts.encodePng(_w, _h, frame),
                usedAssets: usedAssets.toList(),
                metrics: {
                  'phase': label,
                  'speed_cm_s': speed().toStringAsFixed(0),
                  'state': anim.currentState ?? '',
                  'matched_clip': '${anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable] ?? ''}',
                });
          }
        }
      }
      for (final k in hold) {
        input.injectKeyUp(k);
      }
      phaseSpeeds[label] = peak;
    }

    await phase('idle', 1.5);
    await phase('walk', 3.0, tap: const [LuminaKey.keyLeftControl], hold: const [LuminaKey.keyW]);
    await phase('run', 3.0, tap: const [LuminaKey.keyLeftControl], hold: const [LuminaKey.keyW], mouseX: 1.5);
    await phase('sprint', 3.0, hold: const [LuminaKey.keyW, LuminaKey.keyLeftShift]);
    await phase('stop', 2.0);
    await phase('crouch walk', 3.0, tap: const [LuminaKey.keyC], hold: const [LuminaKey.keyW]);
    await phase('stand up', 1.0, tap: const [LuminaKey.keyC]);
    await phase('jump', 1.5, tap: const [LuminaKey.keySpace]);
    await phase('running jump', 3.0, tap: const [LuminaKey.keySpace], hold: const [LuminaKey.keyW]);

    final player = anim.motionMatching.player!;
    String median(List<int> v) {
      final s = [...v]..sort();
      return (s[s.length ~/ 2] / 1000).toStringAsFixed(2);
    }

    final metrics = {
      'mesh_load_s': (meshLoad.inMilliseconds / 1000).toStringAsFixed(1),
      'mesh_and_databases_load_s': (databasesLoad.inMilliseconds / 1000).toStringAsFixed(1),
      'tick_ms_median': median(tickMicros),
      'tick_ms_max': (tickMicros.reduce(math.max) / 1000).toStringAsFixed(2),
      'render_readback_ms_median': median(renderMicros),
      'mm_update_us_mean': player.meanUpdateMicroseconds.toStringAsFixed(0),
      'mm_search_us_mean': player.meanSearchMicroseconds.toStringAsFixed(0),
      'mm_search_us_max': '${player.maxSearchMicroseconds}',
      'mm_rows': '${player.database.index.rowCount}',
      for (final e in phaseSpeeds.entries) 'speed_${e.key.replaceAll(' ', '_')}': e.value.toStringAsFixed(0),
      for (final e in phaseClips.entries) 'clips_${e.key.replaceAll(' ', '_')}': e.value.take(6).join(' '),
    };
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert({'metrics': metrics, 'states': phaseStates.map((k, v) => MapEntry(k, v.toList()))}));

    bool played(String phaseName, String part) => (phaseClips[phaseName] ?? const {}).any((c) => c.contains(part));
    expect(played('walk', 'Walk'), isTrue, reason: '${phaseClips['walk']}');
    expect(played('run', 'Run'), isTrue, reason: '${phaseClips['run']}');
    expect(played('sprint', 'Sprint'), isTrue, reason: '${phaseClips['sprint']}');
    expect(played('crouch walk', 'Crouch'), isTrue, reason: '${phaseClips['crouch walk']}');
    expect(phaseStates['jump'], contains('Air'));
    expect(phaseSpeeds['walk'], closeTo(GaspCharacterContent.walkSpeed, 10));
    expect(phaseSpeeds['run'], closeTo(GaspCharacterContent.runSpeed, 10));
    expect(phaseSpeeds['sprint'], closeTo(GaspCharacterContent.sprintSpeed, 10));
    expect(phaseSpeeds['crouch walk'], closeTo(GaspCharacterContent.crouchSpeed, 10));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: usedAssets.toList());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}
