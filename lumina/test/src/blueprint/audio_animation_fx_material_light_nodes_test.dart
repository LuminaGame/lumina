import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/testing.dart';

import '../../blueprint/anim_blueprints.dart';
import '../dynamic_material_test.dart' show buildDynamicTestFilamatPackage;

/// Sounds, montages and anim variables, particle emitters,
/// dynamic materials and lights driven from Blueprint nodes on the real
/// subsystems (the test audio backend, the noop Filament backend).
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  tearDown(() {
    LuminaBlueprintMontages.clear();
    LuminaBlueprintParticleTemplates.clear();
  });

  test('Play Sound 2D registers a voice on the backend; Stop ends it; Fade Out reaches 0; class volumes', () async {
    final backend = NullAudioBackend();
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaAudioSubsystem(backend: backend));
    final doc = LuminaBlueprintDocument(variables: [const LuminaBlueprintVariable(name: 'Voice', typeName: 'Component:LuminaAudioComponent')]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Sound');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final spawn = p('spawn_sound_2d', 'spawn', {'sound': 'contents/audio/music.wav', 'volume': 0.5});
    expect(spawn.pin('return_value')!.objectClass, 'Component:LuminaAudioComponent');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('play_sound_2d', 'oneshot', {'sound': 'contents/audio/click.wav', 'volume': 0.8, 'pitch': 1.2}),
      spawn,
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_voice', {'variable': 'Voice'}),
      p('play_sound_at_location', 'located', {'sound': 'contents/audio/thump.wav', 'location': [100.0, 0.0, 0.0]}),
      p('set_sound_class_volume', 'music_vol', {'sound_class': 'Music', 'volume': 0.25}),
      p('is_sound_playing', 'playing'),
      p('bool_to_string', 'playing_text'),
      p('print_string', 'say_playing'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'oneshot', 'exec_in'),
      wire('oneshot', 'exec_out', 'spawn', 'exec_in'),
      wire('spawn', 'exec_out', 'set_voice', 'exec_in'),
      wire('spawn', 'return_value', 'set_voice', 'value'),
      wire('set_voice', 'exec_out', 'located', 'exec_in'),
      wire('located', 'exec_out', 'music_vol', 'exec_in'),
      wire('music_vol', 'exec_out', 'say_playing', 'exec_in'),
      wire('set_voice', 'value', 'playing', 'target'),
      wire('playing', 'return_value', 'playing_text', 'in_bool'),
      wire('playing_text', 'return_value', 'say_playing', 'in_string'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Sound');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    await Future<void>.delayed(Duration.zero);
    expect(printed(trace), ['true']);
    expect(backend.playCalls.length, 3);
    expect(backend.playCalls[0].volume, closeTo(0.8, 1e-9));
    expect(backend.playCalls[0].pitch, closeTo(1.2, 1e-9));
    expect(backend.playCalls[1].volume, closeTo(0.5, 1e-9));
    final voice = actor.variables['Voice'] as LuminaAudioComponent;
    expect(voice.isPlaying, isTrue);
    expect(voice.owner, same(actor));
    final audio = w.getSubsystem<LuminaAudioSubsystem>()!;
    expect(audio.classVolume('Music'), 0.25);
    expect(audio.classVolume('Master'), 1.0);
    // Fade out over 1 s: the pushed volume reaches 0 and the voice stops.
    LuminaBlueprintFunctionLibrary.fadeOutSound(actor, voice, 1.0);
    for (var i = 0; i < 11; i++) {
      w.tick(0.1);
      await Future<void>.delayed(Duration.zero);
    }
    expect(voice.isPlaying, isFalse);
    expect(backend.stopCalls, isNotEmpty);
    // A second voice through the library: volume / pitch setters and Stop.
    final again = LuminaBlueprintFunctionLibrary.spawnSound2D(actor, 'contents/audio/loop.wav') as LuminaAudioComponent;
    LuminaBlueprintFunctionLibrary.setSoundVolume(actor, again, 0.3);
    LuminaBlueprintFunctionLibrary.setSoundPitch(actor, again, 0.9);
    await Future<void>.delayed(Duration.zero);
    w.tick(0.1);
    expect(again.volumeMultiplier, 0.3);
    expect(again.pitchMultiplier, 0.9);
    expect(LuminaBlueprintFunctionLibrary.isSoundPlaying(actor, again), isTrue);
    LuminaBlueprintFunctionLibrary.stopSound(actor, again);
    expect(LuminaBlueprintFunctionLibrary.isSoundPlaying(actor, again), isFalse);
  });

  test('Play Anim Montage returns the length; Montage Ended fires on finish and when stopped; anim variables reach the ABP', () {
    LuminaBlueprintMontages.register(const LuminaBlueprintMontageDocument(
      name: 'AM_Wave',
      clip: 'Wave',
      length: 1.0,
      sections: [LuminaBlueprintMontageSection(name: 'Start', startTime: 0.0), LuminaBlueprintMontageSection(name: 'Loop', startTime: 0.5)],
      notifies: [LuminaBlueprintMontageNotify(name: 'Hand', time: 0.25)],
    ));
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final anim = templateAnimClass();
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final doc = templateCharacterBlueprint(inputActions: actions);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Waver');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('play_anim_montage', 'wave', {'montage': 'AM_Wave', 'play_rate': 1.0}),
      p('float_to_string', 'len_text', {'decimals': 1}),
      p('print_string', 'say_len'),
      p('set_anim_variable', 'falling', {'name': 'IsFalling', 'value': true}),
      p('get_anim_variable', 'read_falling', {'name': 'IsFalling', 'type': 'boolean'}),
      p('bool_to_string', 'falling_text'),
      p('print_string', 'say_falling'),
      p('get_anim_instance', 'abp'),
      p('is_valid', 'abp_valid'),
      p('bool_to_string', 'abp_text'),
      p('print_string', 'say_abp'),
      p('event_montage_ended', 'ended'),
      p('bool_to_string', 'interrupted_text'),
      p('append_3', 'ended_line', {'b': ' ended, interrupted '}),
      p('print_string', 'say_ended'),
      p('event_anim_notify', 'notify'),
      p('append', 'notify_line', {'a': 'notify '}),
      p('print_string', 'say_notify'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'wave', 'exec_in'),
      wire('wave', 'exec_out', 'say_len', 'exec_in'),
      wire('wave', 'return_value', 'len_text', 'in_float'),
      wire('len_text', 'return_value', 'say_len', 'in_string'),
      wire('say_len', 'exec_out', 'falling', 'exec_in'),
      wire('falling', 'exec_out', 'say_falling', 'exec_in'),
      wire('read_falling', 'return_value', 'falling_text', 'in_bool'),
      wire('falling_text', 'return_value', 'say_falling', 'in_string'),
      wire('say_falling', 'exec_out', 'say_abp', 'exec_in'),
      wire('abp', 'return_value', 'abp_valid', 'input_object'),
      wire('abp_valid', 'return_value', 'abp_text', 'in_bool'),
      wire('abp_text', 'return_value', 'say_abp', 'in_string'),
      wire('ended', 'exec_out', 'say_ended', 'exec_in'),
      wire('ended', 'montage', 'ended_line', 'a'),
      wire('ended', 'interrupted', 'interrupted_text', 'in_bool'),
      wire('interrupted_text', 'return_value', 'ended_line', 'c'),
      wire('ended_line', 'return_value', 'say_ended', 'in_string'),
      wire('notify', 'exec_out', 'say_notify', 'exec_in'),
      wire('notify', 'notify_name', 'notify_line', 'b'),
      wire('notify_line', 'return_value', 'say_notify', 'in_string'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_Waver', inputActions: actions, animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final me = cls.instantiate() as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    me.trace = trace.add;
    final pc = LuminaPlayerController();
    w.persistentLevel.registerActor(me);
    pc.possess(me);
    w.beginPlay();
    expect(printed(trace), ['1.0', 'true', 'true']);
    expect(LuminaBlueprintFunctionLibrary.isPlayingMontage(me), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getCurrentMontage(me), 'AM_Wave');
    final abp = me.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    expect(abp.variables['IsFalling'], isTrue, reason: 'Set Anim Variable reaches the Anim Blueprint instance');
    expect(LuminaBlueprintFunctionLibrary.getAnimInstance(me), same(abp));
    for (var i = 0; i < 6; i++) {
      pc.onTick(0.1);
      w.tick(0.1);
    }
    expect(printed(trace), contains('notify Hand'));
    expect(LuminaBlueprintFunctionLibrary.isPlayingMontage(me), isTrue);
    for (var i = 0; i < 6; i++) {
      pc.onTick(0.1);
      w.tick(0.1);
    }
    expect(printed(trace).last, 'AM_Wave ended, interrupted false');
    expect(LuminaBlueprintFunctionLibrary.isPlayingMontage(me), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getCurrentMontage(me), '');
    // Stop interrupts; Jump To Section and Set Next Section steer the playback.
    LuminaBlueprintFunctionLibrary.playAnimMontage(me, 'AM_Wave', 1.0, 'Start');
    LuminaBlueprintFunctionLibrary.montageJumpToSection(me, 'Loop');
    expect(me.blueprintMontage!.position, 0.5);
    LuminaBlueprintFunctionLibrary.montageSetNextSection(me, 'Loop', 'Start');
    expect(me.blueprintMontage!.nextSections['Loop'], 'Start');
    LuminaBlueprintFunctionLibrary.stopAnimMontage(me);
    expect(printed(trace).last, 'AM_Wave ended, interrupted true');
    expect(LuminaBlueprintFunctionLibrary.playAnimMontage(me, 'AM_Missing'), 0.0);
  });

  test('Spawn Emitter at Location adds an active particle component; Deactivate stops it; a parameter changes the spawn rate', () {
    LuminaBlueprintParticleTemplates.register('contents/fx/P_Sparks.lmas', LuminaParticleEmitterConfig(spawnRate: 50.0, looping: true));
    final w = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final me = LuminaActor();
    w.persistentLevel.registerActor(me);
    me.onInitialize();
    me.onBeginPlay();
    final before = w.actors.length;
    final emitter = LuminaBlueprintFunctionLibrary.spawnEmitterAtLocation(me, 'contents/fx/P_Sparks.lmas', Vector3(100, 0, 0)) as LuminaParticleSystemComponent;
    expect(w.actors.length, before + 1);
    expect(emitter.isActive, isTrue);
    expect(emitter.owner!.actorLocation, Vector3(100, 0, -0.0));
    expect(emitter.spawnRate, 50.0);
    LuminaBlueprintFunctionLibrary.setParticleParameter(me, emitter, 'SpawnRate', 0.0);
    expect(emitter.spawnRate, 0.0);
    expect(emitter.parameters['SpawnRate'], 0.0);
    LuminaBlueprintFunctionLibrary.deactivateParticleSystem(me, emitter);
    expect(emitter.isActive, isFalse);
    LuminaBlueprintFunctionLibrary.activateParticleSystem(me, emitter, true);
    expect(emitter.isActive, isTrue);
    final attached = LuminaBlueprintFunctionLibrary.spawnEmitterAttached(me, 'contents/fx/P_Sparks.lmas', me.rootComponent) as LuminaParticleSystemComponent;
    expect(attached.owner, same(me));
    expect(attached.parentComponent, same(me.rootComponent));
    final unknown = LuminaBlueprintFunctionLibrary.spawnEmitterAtLocation(me, 'contents/fx/P_Nope.lmas', Vector3.zero());
    expect(unknown, isNotNull, reason: 'an unknown template spawns the default emitter with a log');
    // Auto Destroy: a one-shot emitter's actor is destroyed when it finishes.
    LuminaBlueprintParticleTemplates.register('contents/fx/P_Puff.lmas',
        LuminaParticleEmitterConfig(spawnRate: 0.0, looping: false, duration: 0.2, bursts: const [], lifetimeMin: 0.1, lifetimeMax: 0.1));
    final puff = LuminaBlueprintFunctionLibrary.spawnEmitterAtLocation(me, 'contents/fx/P_Puff.lmas', Vector3.zero(), null, null, true) as LuminaParticleSystemComponent;
    final puffActor = puff.owner!;
    for (var i = 0; i < 10; i++) {
      w.tick(0.1);
    }
    expect(puffActor.isDestroyed, isTrue);
    expect(w.actors, isNot(contains(puffActor)));
  });

  test('Create Dynamic Material Instance + Set Scalar Parameter update the instance; Set Material swaps the asset', () async {
    final bytes = buildDynamicTestFilamatPackage();
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final w = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      w.cleanup();
      scene.dispose();
      engine.dispose();
    });
    final material = await LuminaMaterial.load(w, 'contents/materials/M_Dynamic_Test.filamat', assetProvider: (_) async => bytes);
    final mesh = LuminaStaticMeshComponent(meshAssetPath: '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb');
    final me = LuminaActor(root: mesh);
    w.persistentLevel.registerActor(me);
    w.beginPlay();
    mesh.setMaterialOverride(material.createInstance());
    final dyn = LuminaBlueprintFunctionLibrary.createDynamicMaterialInstance(me, mesh, 0) as LuminaDynamicMaterialInstance;
    expect(mesh.dynamicMaterialInstance(0), same(dyn));
    LuminaBlueprintFunctionLibrary.setScalarParameterValue(me, dyn, 'metallic', 0.2);
    expect(dyn.getFloat('metallic'), closeTo(0.2, 1e-6));
    expect(LuminaBlueprintFunctionLibrary.getScalarParameterValue(me, dyn, 'metallic'), closeTo(0.2, 1e-6));
    LuminaBlueprintFunctionLibrary.setVectorParameterValue(me, dyn, 'baseColorFactor', [1.0, 0.5, 0.0, 1.0]);
    expect(dyn.getFloat4('baseColorFactor').y, closeTo(0.5, 1e-6));
    expect(dyn.parameterValues['baseColorFactor'], [1.0, 0.5, 0.0, 1.0]);
    // An unknown parameter is logged, not thrown.
    LuminaBlueprintFunctionLibrary.setScalarParameterValue(me, dyn, 'nope', 1.0);
    LuminaBlueprintFunctionLibrary.setMaterialScalarParameterOnActor(me, me, 'metallic', 0.9);
    expect(dyn.getFloat('metallic'), closeTo(0.9, 1e-6));
    // Set Material loads the asset through the world's cache.
    LuminaAssets.defaultProvider = (path) async => bytes;
    addTearDown(() => LuminaAssets.defaultProvider = null);
    LuminaBlueprintFunctionLibrary.setMaterial(me, mesh, 0, 'contents/materials/M_Other.filamat');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(mesh.materialOverride(0)?.material.assetPath, 'contents/materials/M_Other.filamat');
  });

  test('Set Light Intensity 5000 changes the point light; Toggle Light Visibility flips it; colour, radius and cone', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final lamp = LuminaActor(root: LuminaPointLightComponent(intensity: 800.0));
    final spot = LuminaActor(root: LuminaSpotLightComponent(intensity: 800.0));
    w.persistentLevel.registerActor(lamp);
    w.persistentLevel.registerActor(spot);
    w.beginPlay();
    final light = lamp.rootComponent as LuminaPointLightComponent;
    final me = LuminaActor();
    w.persistentLevel.registerActor(me);
    expect(LuminaBlueprintFunctionLibrary.classOf(light), 'Component:LuminaPointLightComponent');
    expect(LuminaBlueprintFunctionLibrary.isA(light, 'Component:LuminaLightComponent'), isTrue);
    LuminaBlueprintFunctionLibrary.setLightIntensity(me, light, 5000.0);
    expect(light.intensity, 5000.0);
    expect(LuminaBlueprintFunctionLibrary.getLightIntensity(me, light), 5000.0);
    LuminaBlueprintFunctionLibrary.toggleLightVisibility(me, light);
    expect(light.visible, isFalse);
    LuminaBlueprintFunctionLibrary.toggleLightVisibility(me, light);
    expect(light.visible, isTrue);
    LuminaBlueprintFunctionLibrary.setLightVisibility(me, light, false);
    expect(light.visible, isFalse);
    LuminaBlueprintFunctionLibrary.setLightColor(me, light, [1.0, 0.5, 0.25, 1.0]);
    expect(light.color, Vector3(1.0, 0.5, 0.25));
    LuminaBlueprintFunctionLibrary.setLightRadius(me, light, 1234.0);
    expect(light.falloffRadius, 1234.0);
    final cone = spot.rootComponent as LuminaSpotLightComponent;
    LuminaBlueprintFunctionLibrary.setSpotLightAngles(me, cone, 20.0, 40.0);
    expect(cone.innerConeAngleDegrees, 20.0);
    expect(cone.outerConeAngleDegrees, 40.0);
    for (final id in const ['set_light_intensity', 'get_light_intensity', 'set_light_color', 'set_light_visibility', 'toggle_light_visibility', 'set_light_radius', 'set_spot_light_angles']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
  });
}
