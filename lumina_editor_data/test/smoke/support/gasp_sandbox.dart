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

/// The built Game Animation Sample project's `L_Sandbox` on the GPU, as the
/// generated game builds it: its game mode's character spawned and every
/// motion matching database loaded. Tears itself down with the test.
class GaspSandbox {
  GaspSandbox._({
    required this.engine,
    required this.world,
    required this.pc,
    required this.input,
    required this.character,
    required this.mesh,
    required this.anim,
    required this.usedAssets,
    required this.blocks,
    required this.meshLoad,
    required this.databasesLoad,
    required this.capture,
  });

  final FilamentEngine engine;
  final LuminaWorld world;
  final LuminaPlayerController pc;
  final LuminaInputSubsystem input;
  final LuminaBlueprintCharacter character;
  final LuminaAnimatedMeshComponent mesh;
  final LuminaAnimBlueprintInstance anim;
  final Set<String> usedAssets;

  /// The level's box primitives: authoring centre and size (cm, Z up) and
  /// whether it is rotated.
  final List<({List<double> center, List<double> size, bool rotated})> blocks;
  final Duration meshLoad;
  final Duration databasesLoad;

  /// Renders one frame and reads it back (RGBA, [_w] × [_h]).
  final Uint8List Function() capture;

  static Future<GaspSandbox> open(String dir) async {
    final level = File('$dir/${GaspSandboxLevel.levelPath}');
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
    final blocks = <({List<double> center, List<double> size, bool rotated})>[];
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
          blocks.add((
            center: [for (final v in loc) v.toDouble()],
            size: [for (final k in ['sizeX', 'sizeY', 'sizeZ']) (props[k] as num?)?.toDouble() ?? 100.0],
            rotated: rot.any((v) => v.abs() > 0.01),
          ));
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
    return GaspSandbox._(
      engine: engine,
      world: world,
      pc: pc,
      input: input,
      character: character,
      mesh: mesh,
      anim: anim,
      usedAssets: usedAssets,
      blocks: blocks,
      meshLoad: meshLoad,
      databasesLoad: databasesLoad,
      capture: capture,
    );
  }
}
