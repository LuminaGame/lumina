import 'package:lumina/lumina.dart';

import 'anim_blueprints.dart';

/// Gameplay nodes parity fixtures: the montage, save class and particle
/// template BP_GameplayNodes uses, and the Blueprint itself — the Third
/// Person character (with ABP_Character on its mesh and a point light) whose
/// BeginPlay reads the game framework, saves and loads a slot, queries the
/// input and the screen, plays a sound and a montage, drives an anim
/// variable, spawns an emitter, sets a material scalar on itself, switches
/// its lamp, prints to the screen and draws debug shapes; Load Stream Level
/// completes on a later tick; the montage events answer.
const LuminaBlueprintMontageDocument gameplayMontage = LuminaBlueprintMontageDocument(
  name: 'AM_Parity',
  clip: 'Parity_Wave',
  length: 0.4,
  sections: [LuminaBlueprintMontageSection(name: 'Default', startTime: 0.0)],
  notifies: [LuminaBlueprintMontageNotify(name: 'Beat', time: 0.2)],
);

const LuminaBlueprintSaveGameDocument gameplaySaveClass = LuminaBlueprintSaveGameDocument(name: 'SG_Parity', fields: [
  LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0),
  LuminaBlueprintVariable(name: 'Where', typeName: 'Vector', defaultValue: [0.0, 0.0, 0.0]),
]);

/// Registers what the fixture refers to (the tests call it in `setUp`).
void registerGameplayAssets() {
  LuminaBlueprintMontages.register(gameplayMontage);
  LuminaBlueprintSaveGameClasses.register(gameplaySaveClass);
  LuminaBlueprintParticleTemplates.register('contents/fx/P_Parity.lmas', LuminaParticleEmitterConfig(spawnRate: 20.0));
}

void clearGameplayAssets() {
  LuminaBlueprintMontages.clear();
  LuminaBlueprintSaveGameClasses.clear();
  LuminaBlueprintParticleTemplates.clear();
}

int _wires = 0;
LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: 'w${_wires++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

LuminaBlueprintDocument gameplayNodesBlueprint({required List<LuminaInputAction> inputActions}) {
  _wires = 0;
  final doc = templateCharacterBlueprint(inputActions: inputActions);
  doc.components.add(LuminaBlueprintComponent(
      id: 'lamp', name: 'Lamp', type: 'LuminaPointLightComponent', parentId: 'capsule', properties: {'intensity': 800.0, 'location': [0.0, 0.0, 200.0]}));
  doc.variables.addAll(const [
    LuminaBlueprintVariable(name: 'Save', typeName: 'SaveGame:SG_Parity'),
    LuminaBlueprintVariable(name: 'Voice', typeName: 'Component:LuminaAudioComponent'),
  ]);
  final context = LuminaBlueprintTypeContext.forDocument(doc,
      inputActions: inputActions, className: 'bp_gameplay_nodes', saveGameClasses: const [gameplaySaveClass], gameModeClass: 'BP_ParityGameMode');
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);

  /// A pure node whose output feeds a conversion then a Print String.
  void printed(String node, String outPin, String convert, String inPin, {Map<String, dynamic>? convertLiterals}) {
    doc.eventGraph.nodes.addAll([p(convert, '${node}_text', convertLiterals), p('print_string', 'say_$node', {'print_to_screen': false})]);
    doc.eventGraph.wires.addAll([_w(node, outPin, '${node}_text', inPin), _w('${node}_text', 'return_value', 'say_$node', 'in_string')]);
  }

  doc.eventGraph.nodes.addAll([
    p('event_beginplay', 'begin'),
    p('sequence', 'seq')
      ..outputs.addAll(const [
        LuminaBlueprintPin(id: 'then_2', name: 'Then 2', type: LuminaPinType.exec, isOutput: true),
        LuminaBlueprintPin(id: 'then_3', name: 'Then 3', type: LuminaPinType.exec, isOutput: true),
        LuminaBlueprintPin(id: 'then_4', name: 'Then 4', type: LuminaPinType.exec, isOutput: true),
      ]),
    // then_0: game framework.
    p('get_game_mode', 'mode'),
    p('is_valid', 'mode_valid'),
    p('get_current_level_name', 'level'),
    p('print_string', 'say_level', {'print_to_screen': false}),
    p('get_game_instance', 'gi'),
    p('is_valid', 'gi_valid'),
    p('is_game_paused', 'paused'),
    p('execute_console_command', 'slomo', {'command': 'slomo 1'}),
    p('get_game_time_since_creation', 'age'),
    p('float_to_string', 'age_text', {'decimals': 1}),
    p('print_string', 'say_age', {'print_to_screen': false}),
    // then_1: save game.
    p('create_save_game_object', 'create', {'class': 'SG_Parity'}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_save', {'variable': 'Save'}),
    p('set_save_field', 'set_score', {'class': 'SG_Parity', 'field': 'Score', 'value': 5}),
    p('set_save_field', 'set_where', {'class': 'SG_Parity', 'field': 'Where', 'value': [1.0, 2.0, 3.0]}),
    p('get_save_field', 'get_score', {'class': 'SG_Parity', 'field': 'Score'}),
    p('save_game_to_slot', 'save', {'slot_name': 'parity', 'user_index': 0}),
    p('load_game_from_slot', 'load', {'slot_name': 'parity', 'user_index': 0, 'class': 'SG_Parity'}),
    p('get_save_field', 'loaded_where', {'class': 'SG_Parity', 'field': 'Where'}),
    p('does_save_game_exist', 'exists', {'slot_name': 'parity', 'user_index': 0}),
    p('delete_game_in_slot', 'delete', {'slot_name': 'parity', 'user_index': 0}),
    p('load_stream_level', 'stream', {'level_name': 'L_Nowhere'}),
    p('print_string', 'say_streamed', {'in_string': 'stream completed', 'print_to_screen': false}),
    p('is_stream_level_loaded', 'streamed', {'level_name': 'L_Nowhere'}),
    // then_2: input, screen, audio.
    p('is_input_key_down', 'w_down', {'key': 'W'}),
    p('get_viewport_size', 'viewport'),
    p('break_vector2d', 'viewport_parts'),
    p('project_world_to_screen', 'project', {'world_location': [0.0, 500.0, 100.0]}),
    p('get_last_input_device', 'device'),
    p('print_string', 'say_device', {'print_to_screen': false}),
    p('play_sound_2d', 'click', {'sound': 'contents/audio/click.wav', 'volume': 0.5}),
    p('spawn_sound_2d', 'music', {'sound': 'contents/audio/music.wav'}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_voice', {'variable': 'Voice'}),
    p('is_sound_playing', 'playing'),
    p('set_sound_volume', 'quiet', {'volume': 0.2}),
    p('set_sound_class_volume', 'mix', {'sound_class': 'Music', 'volume': 0.5}),
    // then_3: animation, effects, material, light.
    p('play_anim_montage', 'wave', {'montage': 'AM_Parity'}),
    p('is_playing_montage', 'waving'),
    p('get_current_montage', 'montage_name'),
    p('print_string', 'say_montage', {'print_to_screen': false}),
    p('set_anim_variable', 'set_falling', {'name': 'IsFalling', 'value': true}),
    p('get_anim_variable', 'get_falling', {'name': 'IsFalling', 'type': 'boolean'}),
    p('get_anim_instance', 'abp'),
    p('is_valid', 'abp_valid'),
    p('spawn_emitter_at_location', 'sparks', {'emitter_template': 'contents/fx/P_Parity.lmas', 'location': [0.0, 100.0, 0.0]}),
    p('is_valid', 'sparks_valid'),
    p('set_particle_parameter', 'sparks_rate', {'parameter_name': 'SpawnRate', 'type': 'float', 'value': 0.0}),
    p('deactivate_particle_system', 'sparks_off'),
    p('set_material_scalar_parameter_on_actor', 'shine', {'parameter_name': 'metallic', 'value': 0.5}),
    p(LuminaBlueprintNodeLibrary.getComponent, 'lamp', {'component': 'Lamp'}),
    p('set_light_intensity', 'bright', {'new_intensity': 5000.0}),
    p('get_light_intensity', 'lumens'),
    p('toggle_light_visibility', 'flip'),
    p('set_light_color', 'tint', {'new_light_color': [1.0, 0.5, 0.0, 1.0]}),
    p('set_light_radius', 'reach', {'new_radius': 1500.0}),
    // then_4: debug.
    p('print_string', 'screen', {'in_string': 'on screen', 'key': 'parity', 'duration': 5.0}),
    p('print_text', 'text', {'in_text': 'text too', 'print_to_screen': false}),
    p('draw_debug_line', 'line', {'line_start': [0.0, 0.0, 0.0], 'line_end': [0.0, 100.0, 0.0], 'duration': 1.0}),
    p('draw_debug_sphere', 'sphere', {'center': [0.0, 0.0, 100.0], 'radius': 30.0}),
    p('draw_debug_string', 'label', {'text_location': [0.0, 0.0, 200.0], 'text': 'hi'}),
    p('log_warning', 'warn', {'in_string': 'careful'}),
    p('breakpoint', 'bp'),
    p('flush_debug_shapes', 'flush'),
    // Events.
    p('event_montage_ended', 'ended'),
    p('bool_to_string', 'interrupted_text'),
    p('append_3', 'ended_line', {'b': ' ended '}),
    p('print_string', 'say_ended', {'print_to_screen': false}),
    p('event_anim_notify', 'notify'),
    p('append', 'notify_line', {'a': 'notify '}),
    p('print_string', 'say_notify', {'print_to_screen': false}),
  ]);
  printed('mode_valid', 'return_value', 'bool_to_string', 'in_bool');
  printed('gi_valid', 'return_value', 'bool_to_string', 'in_bool');
  printed('paused', 'return_value', 'bool_to_string', 'in_bool');
  printed('get_score', 'return_value', 'int_to_string', 'in_int');
  printed('save', 'return_value', 'bool_to_string', 'in_bool');
  printed('loaded_where', 'return_value', 'vector_to_string', 'in_vec');
  printed('exists', 'return_value', 'bool_to_string', 'in_bool');
  printed('delete', 'return_value', 'bool_to_string', 'in_bool');
  doc.eventGraph.nodes.add(p('bool_to_string', 'streamed_text'));
  doc.eventGraph.wires.add(_w('streamed', 'return_value', 'streamed_text', 'in_bool'));
  printed('w_down', 'return_value', 'bool_to_string', 'in_bool');
  printed('viewport_parts', 'x', 'float_to_string', 'in_float', convertLiterals: {'decimals': 0});
  printed('project', 'return_value', 'bool_to_string', 'in_bool');
  printed('playing', 'return_value', 'bool_to_string', 'in_bool');
  printed('wave', 'return_value', 'float_to_string', 'in_float', convertLiterals: {'decimals': 1});
  printed('waving', 'return_value', 'bool_to_string', 'in_bool');
  printed('get_falling', 'return_value', 'bool_to_string', 'in_bool');
  printed('abp_valid', 'return_value', 'bool_to_string', 'in_bool');
  printed('sparks_valid', 'return_value', 'bool_to_string', 'in_bool');
  printed('lumens', 'return_value', 'float_to_string', 'in_float', convertLiterals: {'decimals': 0});
  doc.eventGraph.wires.addAll([
    _w('begin', 'exec_out', 'seq', 'exec_in'),
    // then_0
    _w('seq', 'then_0', 'say_mode_valid', 'exec_in'),
    _w('mode', 'return_value', 'mode_valid', 'input_object'),
    _w('say_mode_valid', 'exec_out', 'say_level', 'exec_in'),
    _w('level', 'return_value', 'say_level', 'in_string'),
    _w('say_level', 'exec_out', 'say_gi_valid', 'exec_in'),
    _w('gi', 'return_value', 'gi_valid', 'input_object'),
    _w('say_gi_valid', 'exec_out', 'slomo', 'exec_in'),
    _w('slomo', 'exec_out', 'say_paused', 'exec_in'),
    _w('say_paused', 'exec_out', 'say_age', 'exec_in'),
    _w('age', 'return_value', 'age_text', 'in_float'),
    _w('age_text', 'return_value', 'say_age', 'in_string'),
    // then_1
    _w('seq', 'then_1', 'create', 'exec_in'),
    _w('create', 'exec_out', 'set_save', 'exec_in'),
    _w('create', 'return_value', 'set_save', 'value'),
    _w('set_save', 'exec_out', 'set_score', 'exec_in'),
    _w('set_save', 'value', 'set_score', 'target'),
    _w('set_score', 'exec_out', 'set_where', 'exec_in'),
    _w('set_save', 'value', 'set_where', 'target'),
    _w('set_where', 'exec_out', 'say_get_score', 'exec_in'),
    _w('set_save', 'value', 'get_score', 'target'),
    _w('say_get_score', 'exec_out', 'save', 'exec_in'),
    _w('set_save', 'value', 'save', 'save_game_object'),
    _w('save', 'exec_out', 'say_save', 'exec_in'),
    _w('say_save', 'exec_out', 'load', 'exec_in'),
    _w('load', 'exec_out', 'say_loaded_where', 'exec_in'),
    _w('load', 'return_value', 'loaded_where', 'target'),
    _w('say_loaded_where', 'exec_out', 'say_exists', 'exec_in'),
    _w('say_exists', 'exec_out', 'delete', 'exec_in'),
    _w('delete', 'exec_out', 'say_delete', 'exec_in'),
    // (Async Save Game completes off the tick, so its timing is not parity
    // material; the unit test covers it. Load Stream Level of an unknown
    // level completes on the next latent advance, deterministically.)
    _w('say_delete', 'exec_out', 'stream', 'exec_in'),
    _w('stream', 'completed', 'say_streamed', 'exec_in'),
    _w('say_streamed', 'exec_out', 'say_streamed_flag', 'exec_in'),
    // then_2
    _w('seq', 'then_2', 'say_w_down', 'exec_in'),
    _w('say_w_down', 'exec_out', 'say_viewport_parts', 'exec_in'),
    _w('viewport', 'return_value', 'viewport_parts', 'in_vec'),
    _w('say_viewport_parts', 'exec_out', 'say_project', 'exec_in'),
    _w('say_project', 'exec_out', 'say_device', 'exec_in'),
    _w('device', 'return_value', 'say_device', 'in_string'),
    _w('say_device', 'exec_out', 'click', 'exec_in'),
    _w('click', 'exec_out', 'music', 'exec_in'),
    _w('music', 'exec_out', 'set_voice', 'exec_in'),
    _w('music', 'return_value', 'set_voice', 'value'),
    _w('set_voice', 'exec_out', 'say_playing', 'exec_in'),
    _w('set_voice', 'value', 'playing', 'target'),
    _w('say_playing', 'exec_out', 'quiet', 'exec_in'),
    _w('set_voice', 'value', 'quiet', 'target'),
    _w('quiet', 'exec_out', 'mix', 'exec_in'),
    // then_3
    _w('seq', 'then_3', 'wave', 'exec_in'),
    _w('wave', 'exec_out', 'say_wave', 'exec_in'),
    _w('say_wave', 'exec_out', 'say_waving', 'exec_in'),
    _w('say_waving', 'exec_out', 'say_montage', 'exec_in'),
    _w('montage_name', 'return_value', 'say_montage', 'in_string'),
    _w('say_montage', 'exec_out', 'set_falling', 'exec_in'),
    _w('set_falling', 'exec_out', 'say_get_falling', 'exec_in'),
    _w('say_get_falling', 'exec_out', 'say_abp_valid', 'exec_in'),
    _w('abp', 'return_value', 'abp_valid', 'input_object'),
    _w('say_abp_valid', 'exec_out', 'sparks', 'exec_in'),
    _w('sparks', 'exec_out', 'say_sparks_valid', 'exec_in'),
    _w('sparks', 'return_value', 'sparks_valid', 'input_object'),
    _w('say_sparks_valid', 'exec_out', 'sparks_rate', 'exec_in'),
    _w('sparks', 'return_value', 'sparks_rate', 'target'),
    _w('sparks_rate', 'exec_out', 'sparks_off', 'exec_in'),
    _w('sparks', 'return_value', 'sparks_off', 'target'),
    _w('sparks_off', 'exec_out', 'shine', 'exec_in'),
    _w('shine', 'exec_out', 'bright', 'exec_in'),
    _w('lamp', 'return_value', 'bright', 'target'),
    _w('bright', 'exec_out', 'say_lumens', 'exec_in'),
    _w('lamp', 'return_value', 'lumens', 'target'),
    _w('say_lumens', 'exec_out', 'flip', 'exec_in'),
    _w('lamp', 'return_value', 'flip', 'target'),
    _w('flip', 'exec_out', 'tint', 'exec_in'),
    _w('lamp', 'return_value', 'tint', 'target'),
    _w('tint', 'exec_out', 'reach', 'exec_in'),
    _w('lamp', 'return_value', 'reach', 'target'),
    // then_4
    _w('seq', 'then_4', 'screen', 'exec_in'),
    _w('screen', 'exec_out', 'text', 'exec_in'),
    _w('text', 'exec_out', 'line', 'exec_in'),
    _w('line', 'exec_out', 'sphere', 'exec_in'),
    _w('sphere', 'exec_out', 'label', 'exec_in'),
    _w('label', 'exec_out', 'warn', 'exec_in'),
    _w('warn', 'exec_out', 'bp', 'exec_in'),
    _w('bp', 'exec_out', 'flush', 'exec_in'),
    // events
    _w('ended', 'exec_out', 'say_ended', 'exec_in'),
    _w('ended', 'montage', 'ended_line', 'a'),
    _w('ended', 'interrupted', 'interrupted_text', 'in_bool'),
    _w('interrupted_text', 'return_value', 'ended_line', 'c'),
    _w('ended_line', 'return_value', 'say_ended', 'in_string'),
    _w('notify', 'exec_out', 'say_notify', 'exec_in'),
    _w('notify', 'notify_name', 'notify_line', 'b'),
    _w('notify_line', 'return_value', 'say_notify', 'in_string'),
  ]);
  // The streamed flag is printed after the latent Completed.
  doc.eventGraph.nodes.add(p('print_string', 'say_streamed_flag', {'print_to_screen': false}));
  doc.eventGraph.wires.add(_w('streamed_text', 'return_value', 'say_streamed_flag', 'in_string'));
  return doc;
}
