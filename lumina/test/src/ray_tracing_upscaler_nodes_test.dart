import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../blueprint/rendering_features_blueprint.dart';

const _ids = [
  'set_ray_tracing_enabled',
  'get_ray_tracing_enabled',
  'set_ray_traced_shadows_enabled',
  'get_ray_traced_shadows_enabled',
  'set_restir_enabled',
  'get_restir_enabled',
  'set_restir_candidates',
  'get_restir_candidates',
  'set_restir_spatial_samples',
  'get_restir_spatial_samples',
  'set_upscaler',
  'get_upscaler',
  'set_upscaler_quality',
  'get_upscaler_quality',
  'set_upscaler_sharpness',
  'get_upscaler_sharpness',
  'set_frame_generation_enabled',
  'get_frame_generation_enabled',
  'is_ray_tracing_supported',
  'is_dlss_supported',
  'is_fsr3_supported',
  'is_frame_generation_supported',
  'get_supported_upscalers',
  'get_active_upscaler',
  'is_ray_tracing_active',
  'save_game_user_settings',
  'load_game_user_settings',
];

void main() {
  test('every ray tracing / upscaler node has a spec, a VM function and a call shape, and is findable', () {
    for (final id in _ids) {
      final spec = LuminaBlueprintNodeLibrary.spec(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.category, 'Settings|Ray Tracing & Upscaling', reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    Set<String> found(String word) =>
        {for (final s in LuminaBlueprintNodeLibrary.builtIns) if (s.keywords.contains(word)) s.id};
    expect(found('rtx'), containsAll(['set_ray_tracing_enabled', 'is_ray_tracing_supported', 'set_restir_enabled']));
    expect(found('raytracing'), contains('set_ray_tracing_enabled'));
    expect(found('dlss'), containsAll(['set_upscaler', 'is_dlss_supported', 'get_supported_upscalers']));
    expect(found('fsr'), containsAll(['set_upscaler', 'is_fsr3_supported']));
    expect(found('upscaling'), contains('set_upscaler_quality'));
    expect(found('frame generation'), containsAll(['set_frame_generation_enabled', 'is_frame_generation_supported']));
  });

  test('the VM functions stage, read back, query support and report the fallback', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    final ctx = LuminaBlueprintCallContext(actor);
    final fns = LuminaBlueprintFunctionLibrary.functions;
    Object? get(String id) => fns[id]!(ctx, const {})['return_value'];

    fns['set_ray_tracing_enabled']!(ctx, {'enabled': true});
    fns['set_ray_traced_shadows_enabled']!(ctx, {'enabled': false});
    fns['set_restir_enabled']!(ctx, {'enabled': true});
    fns['set_restir_candidates']!(ctx, {'candidates': 99});
    fns['set_restir_spatial_samples']!(ctx, {'samples': 5});
    fns['set_upscaler']!(ctx, {'upscaler': 'fsr3'});
    fns['set_upscaler_quality']!(ctx, {'quality': 'Ultra Performance'});
    fns['set_upscaler_sharpness']!(ctx, {'sharpness': 0.3});
    fns['set_frame_generation_enabled']!(ctx, {'enabled': true});
    expect(get('get_ray_tracing_enabled'), isTrue);
    expect(get('get_ray_traced_shadows_enabled'), isFalse);
    expect(get('get_restir_enabled'), isTrue);
    expect(get('get_restir_candidates'), 64, reason: 'clamped');
    expect(get('get_restir_spatial_samples'), 5);
    expect(get('get_upscaler'), 'FSR3');
    expect(get('get_upscaler_quality'), 'Ultra Performance');
    expect(get('get_upscaler_sharpness'), closeTo(0.3, 1e-9));
    expect(get('get_frame_generation_enabled'), isTrue);
    expect(get('get_active_upscaler'), 'None', reason: 'staged until Apply Scalability Settings');

    fns['apply_scalability_settings']!(ctx, const {});
    // A world without a renderer supports none of it.
    expect(get('is_ray_tracing_supported'), isFalse);
    expect(get('is_dlss_supported'), isFalse);
    expect(get('is_fsr3_supported'), isFalse);
    expect(get('is_frame_generation_supported'), isFalse);
    expect(get('get_supported_upscalers'), ['None']);
    expect(get('get_active_upscaler'), 'None');
    expect(get('is_ray_tracing_active'), isFalse);
    expect(world.userSettings.renderingFallbacks, hasLength(3));
  });

  test('Save and Load Game User Settings write and read the settings file', () async {
    final dir = await Directory.systemTemp.createTemp('lumina_settings_nodes_');
    final previous = LuminaSaveGameSubsystem.defaultSaveDirectoryPath;
    LuminaSaveGameSubsystem.defaultSaveDirectoryPath = dir.path;
    addTearDown(() async {
      LuminaSaveGameSubsystem.defaultSaveDirectoryPath = previous;
      await dir.delete(recursive: true);
    });
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    final ctx = LuminaBlueprintCallContext(actor);
    final fns = LuminaBlueprintFunctionLibrary.functions;
    fns['set_upscaler']!(ctx, {'upscaler': 'DLSS'});
    fns['set_ray_tracing_enabled']!(ctx, {'enabled': true});
    fns['save_game_user_settings']!(ctx, const {});
    final file = File('${dir.path}/GameUserSettings.json');
    for (var i = 0; i < 100 && !await file.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await file.exists(), isTrue);

    final other = LuminaWorld(worldType: LuminaWorldType.game);
    final reader = LuminaActor();
    other.persistentLevel.registerActor(reader);
    final readCtx = LuminaBlueprintCallContext(reader);
    fns['load_game_user_settings']!(readCtx, const {});
    for (var i = 0; i < 100 && other.userSettings.upscaler != 'DLSS'; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(fns['get_upscaler']!(readCtx, const {})['return_value'], 'DLSS');
    expect(fns['get_ray_tracing_enabled']!(readCtx, const {})['return_value'], isTrue);
  });

  test('a game settings Blueprint chooses DLSS and ray tracing; without a renderer it reports the fallback (VM)', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(renderingFeaturesBlueprint(), name: 'bp_graphics_settings').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    final printed = [for (final t in trace) if (t.printed != null) t.printed!];
    expect(printed, ['DLSS', 'None', 'false', 'false']);
    final s = world.userSettings;
    expect(s.rayTracingEnabled, isTrue);
    expect(s.rayTracedShadowsEnabled, isFalse);
    expect(s.restirEnabled, isTrue);
    expect(s.restirCandidates, 16);
    expect(s.restirSpatialSamples, 4);
    expect(s.upscalerQuality, 'Performance');
    expect(s.upscalerSharpness, closeTo(0.7, 1e-9));
    expect(s.frameGenerationEnabled, isTrue);
  });
}
