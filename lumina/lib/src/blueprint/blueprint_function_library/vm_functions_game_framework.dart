part of '../blueprint_function_library.dart';

/// Game framework, save game, input, audio, animation,
/// effects, material, light, debug.
final Map<String, LuminaBlueprintFunction> _gameFrameworkFunctions = <String, LuminaBlueprintFunction>{
  // --- game framework, save game, input, audio, animation, fx, material, light, debug --
  'get_game_instance': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGameInstance(c.self)),
  'get_game_mode': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGameMode(c.self)),
  'get_game_state': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGameState(c.self)),
  'get_player_state': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPlayerState(c.self, LuminaBlueprintFunctionLibrary._n(i['player_index'], 0))),
  'set_game_paused': (c, i) {
    LuminaBlueprintFunctionLibrary.setGamePaused(c.self, i['paused'] as bool? ?? true);
    return const {};
  },
  'is_game_paused': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isGamePaused(c.self)),
  'execute_console_command': (c, i) {
    LuminaBlueprintFunctionLibrary.executeConsoleCommand(c.self, i['command'] as String? ?? '');
    return const {};
  },
  'get_current_level_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCurrentLevelName(c.self)),
  'open_level': (c, i) {
    LuminaBlueprintFunctionLibrary.openLevel(c.self, i['level_name'] as String? ?? '', i['options'] as String? ?? '');
    return const {};
  },
  'unload_stream_level': (c, i) {
    LuminaBlueprintFunctionLibrary.unloadStreamLevel(c.self, i['level_name'] as String? ?? '');
    return const {};
  },
  'is_stream_level_loaded': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isStreamLevelLoaded(c.self, i['level_name'] as String? ?? '')),
  'cancel_level_load': (c, i) {
    LuminaBlueprintFunctionLibrary.cancelLevelLoad(c.self, i['level_name'] as String? ?? '');
    return const {};
  },
  'is_level_loaded': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isLevelLoaded(c.self, i['level_name'] as String? ?? '')),
  'get_game_time_since_creation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGameTimeSinceCreation(c.self)),
  'create_save_game_object': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.createSaveGameObject(c.self, i['class'] as String? ?? '')),
  'set_save_field': (c, i) {
    LuminaBlueprintFunctionLibrary.setSaveField(c.self, i['target'], i['class'] as String? ?? '', i['field'] as String? ?? '', i['value']);
    return const {};
  },
  'get_save_field': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSaveField(i['target'], i['field'] as String? ?? '', i['class'] as String? ?? '')),
  'save_game_to_slot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.saveGameToSlot(c.self, i['save_game_object'], i['slot_name'] as String? ?? 'Slot1', LuminaBlueprintFunctionLibrary._n(i['user_index'], 0))),
  'load_game_from_slot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.loadGameFromSlot(c.self, i['slot_name'] as String? ?? 'Slot1', LuminaBlueprintFunctionLibrary._n(i['user_index'], 0))),
  'does_save_game_exist': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.doesSaveGameExist(c.self, i['slot_name'] as String? ?? 'Slot1', LuminaBlueprintFunctionLibrary._n(i['user_index'], 0))),
  'delete_game_in_slot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.deleteGameInSlot(c.self, i['slot_name'] as String? ?? 'Slot1', LuminaBlueprintFunctionLibrary._n(i['user_index'], 0))),
  'is_input_key_down': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isInputKeyDown(c.self, i['key'] as String? ?? '')),
  'get_input_key_time_down': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getInputKeyTimeDown(c.self, i['key'] as String? ?? '')),
  'was_input_key_just_pressed': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.wasInputKeyJustPressed(c.self, i['key'] as String? ?? '')),
  'get_input_axis_value': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getInputAxisValue(c.self, i['axis_name'] as String? ?? '')),
  'get_mouse_position': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getMousePosition(c.self)),
  'set_mouse_position': (c, i) {
    LuminaBlueprintFunctionLibrary.setMousePosition(c.self, i['position'] as Vector2? ?? Vector2.zero());
    return const {};
  },
  'get_viewport_size': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getViewportSize(c.self)),
  'project_world_to_screen': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.projectWorldToScreen(c.self, _vec3(i['world_location']));
    return {'screen_position': r.screenPosition, 'return_value': r.returnValue};
  },
  'deproject_screen_to_world': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.deprojectScreenToWorld(c.self, i['screen_position'] as Vector2? ?? Vector2.zero());
    return {'world_location': r.worldLocation, 'world_direction': r.worldDirection};
  },
  'enable_input': (c, i) {
    LuminaBlueprintFunctionLibrary.enableInput(c.self, i['player_controller']);
    return const {};
  },
  'disable_input': (c, i) {
    LuminaBlueprintFunctionLibrary.disableInput(c.self, i['player_controller']);
    return const {};
  },
  'get_last_input_device': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getLastInputDevice(c.self)),

  // --- Settings & Scalability -----------------------------------------
  'set_overall_scalability_level': (c, i) {
    LuminaBlueprintFunctionLibrary.setOverallScalabilityLevel(c.self, i['preset'] as String? ?? 'Epic');
    return const {};
  },
  'get_overall_scalability_level': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getOverallScalabilityLevel(c.self)),
  'set_view_distance_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setViewDistanceQuality(c.self, i['quality'] as String? ?? 'Epic');
    return const {};
  },
  'get_view_distance_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getViewDistanceQuality(c.self)),
  'set_view_distance': (c, i) {
    LuminaBlueprintFunctionLibrary.setViewDistance(c.self, LuminaBlueprintFunctionLibrary._d(i['distance'], 100000.0));
    return const {};
  },
  'get_view_distance': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getViewDistance(c.self)),
  'set_shadow_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setShadowQuality(c.self, i['quality'] as String? ?? 'High');
    return const {};
  },
  'get_shadow_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getShadowQuality(c.self)),
  'set_anti_aliasing_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setAntiAliasingQuality(c.self, i['quality'] as String? ?? 'FXAA');
    return const {};
  },
  'get_anti_aliasing_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAntiAliasingQuality(c.self)),
  'set_post_processing_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setPostProcessingQuality(c.self, i['quality'] as String? ?? 'Epic');
    return const {};
  },
  'get_post_processing_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPostProcessingQuality(c.self)),
  'set_texture_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setTextureQuality(c.self, i['quality'] as String? ?? 'High');
    return const {};
  },
  'get_texture_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTextureQuality(c.self)),
  'set_shading_quality': (c, i) {
    LuminaBlueprintFunctionLibrary.setShadingQuality(c.self, i['quality'] as String? ?? 'Epic');
    return const {};
  },
  'get_shading_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getShadingQuality(c.self)),
  'set_resolution_scale': (c, i) {
    LuminaBlueprintFunctionLibrary.setResolutionScale(c.self, LuminaBlueprintFunctionLibrary._d(i['percent'], 100.0));
    return const {};
  },
  'get_resolution_scale': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getResolutionScale(c.self)),
  'set_target_fps': (c, i) {
    LuminaBlueprintFunctionLibrary.setTargetFps(c.self, LuminaBlueprintFunctionLibrary._n(i['fps'], 60));
    return const {};
  },
  'get_target_fps': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTargetFps(c.self)),
  'set_vsync_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setVsyncEnabled(c.self, i['enabled'] as bool? ?? false);
    return const {};
  },
  'get_vsync_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getVsyncEnabled(c.self)),
  'apply_scalability_settings': (c, i) {
    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(c.self);
    return const {};
  },

  'play_sound_2d': (c, i) {
    LuminaBlueprintFunctionLibrary.playSound2D(c.self, i['sound'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0), LuminaBlueprintFunctionLibrary._d(i['pitch'], 1.0), LuminaBlueprintFunctionLibrary._d(i['start_time'], 0.0));
    return const {};
  },
  'play_sound_at_location': (c, i) {
    LuminaBlueprintFunctionLibrary.playSoundAtLocation(c.self, i['sound'] as String? ?? '', _vec3(i['location']), LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0), LuminaBlueprintFunctionLibrary._d(i['pitch'], 1.0), LuminaBlueprintFunctionLibrary._d(i['start_time'], 0.0));
    return const {};
  },
  'spawn_sound_2d': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnSound2D(
      c.self, i['sound'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0), LuminaBlueprintFunctionLibrary._d(i['pitch'], 1.0), LuminaBlueprintFunctionLibrary._d(i['start_time'], 0.0), i['auto_destroy'] as bool? ?? false)),
  'spawn_sound_attached': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnSoundAttached(
      c.self, i['sound'] as String? ?? '', i['attach_to_component'], i['socket_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0), LuminaBlueprintFunctionLibrary._d(i['pitch'], 1.0))),
  'stop_sound': (c, i) {
    LuminaBlueprintFunctionLibrary.stopSound(c.self, i['target']);
    return const {};
  },
  'fade_out_sound': (c, i) {
    LuminaBlueprintFunctionLibrary.fadeOutSound(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['fade_out_duration'], 1.0));
    return const {};
  },
  'set_sound_volume': (c, i) {
    LuminaBlueprintFunctionLibrary.setSoundVolume(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0));
    return const {};
  },
  'set_sound_pitch': (c, i) {
    LuminaBlueprintFunctionLibrary.setSoundPitch(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['pitch'], 1.0));
    return const {};
  },
  'is_sound_playing': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isSoundPlaying(c.self, i['target'])),
  'set_sound_class_volume': (c, i) {
    LuminaBlueprintFunctionLibrary.setSoundClassVolume(c.self, i['sound_class'] as String? ?? 'Master', LuminaBlueprintFunctionLibrary._d(i['volume'], 1.0));
    return const {};
  },
  'play_anim_montage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.playAnimMontage(c.self, i['montage'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['play_rate'], 1.0), i['start_section'] as String? ?? '')),
  'stop_anim_montage': (c, i) {
    LuminaBlueprintFunctionLibrary.stopAnimMontage(c.self, LuminaBlueprintFunctionLibrary._d(i['blend_out_time'], 0.25));
    return const {};
  },
  'montage_jump_to_section': (c, i) {
    LuminaBlueprintFunctionLibrary.montageJumpToSection(c.self, i['section_name'] as String? ?? '');
    return const {};
  },
  'montage_set_next_section': (c, i) {
    LuminaBlueprintFunctionLibrary.montageSetNextSection(c.self, i['section_name'] as String? ?? '', i['next_section'] as String? ?? '');
    return const {};
  },
  'is_playing_montage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isPlayingMontage(c.self)),
  'get_current_montage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCurrentMontage(c.self)),
  'get_anim_instance': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAnimInstance(c.self)),
  'set_anim_variable': (c, i) {
    LuminaBlueprintFunctionLibrary.setAnimVariable(c.self, i['name'] as String? ?? '', i['value']);
    return const {};
  },
  'get_anim_variable': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAnimVariable(c.self, i['name'] as String? ?? '')),
  'spawn_emitter_at_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnEmitterAtLocation(c.self, i['emitter_template'] as String? ?? '', _vec3(i['location']),
      _rot3(i['rotation']), _vec3(i['scale'], Vector3(1, 1, 1)), i['auto_destroy'] as bool? ?? true)),
  'spawn_emitter_attached': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnEmitterAttached(
      c.self, i['emitter_template'] as String? ?? '', i['attach_to_component'], i['socket_name'] as String? ?? '', i['auto_destroy'] as bool? ?? true)),
  'spawn_decal_at_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnDecalAtLocation(
      c.self, i['decal_material'] as String? ?? '', _vec3(i['decal_size']), _vec3(i['location']), _rot3(i['rotation']), LuminaBlueprintFunctionLibrary._d(i['life_span'], 0.0))),
  'activate_particle_system': (c, i) {
    LuminaBlueprintFunctionLibrary.activateParticleSystem(c.self, i['target'], i['reset'] as bool? ?? false);
    return const {};
  },
  'deactivate_particle_system': (c, i) {
    LuminaBlueprintFunctionLibrary.deactivateParticleSystem(c.self, i['target']);
    return const {};
  },
  'set_particle_parameter': (c, i) {
    LuminaBlueprintFunctionLibrary.setParticleParameter(c.self, i['target'], i['parameter_name'] as String? ?? '', i['value']);
    return const {};
  },
  'create_dynamic_material_instance': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.createDynamicMaterialInstance(c.self, i['target'], LuminaBlueprintFunctionLibrary._n(i['element_index'], 0))),
  'set_scalar_parameter_value': (c, i) {
    LuminaBlueprintFunctionLibrary.setScalarParameterValue(c.self, i['target'], i['parameter_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['value'], 0.0));
    return const {};
  },
  'set_vector_parameter_value': (c, i) {
    LuminaBlueprintFunctionLibrary.setVectorParameterValue(c.self, i['target'], i['parameter_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._c(i['value']));
    return const {};
  },
  'set_texture_parameter_value': (c, i) {
    LuminaBlueprintFunctionLibrary.setTextureParameterValue(c.self, i['target'], i['parameter_name'] as String? ?? '', i['value'] as String? ?? '');
    return const {};
  },
  'get_scalar_parameter_value': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getScalarParameterValue(c.self, i['target'], i['parameter_name'] as String? ?? '')),
  'set_material_scalar_parameter_on_actor': (c, i) {
    LuminaBlueprintFunctionLibrary.setMaterialScalarParameterOnActor(c.self, i['target'], i['parameter_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['value'], 0.0));
    return const {};
  },
  'set_light_intensity': (c, i) {
    LuminaBlueprintFunctionLibrary.setLightIntensity(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['new_intensity'], 1000.0));
    return const {};
  },
  'get_light_intensity': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getLightIntensity(c.self, i['target'])),
  'set_light_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setLightColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['new_light_color']));
    return const {};
  },
  'set_light_visibility': (c, i) {
    LuminaBlueprintFunctionLibrary.setLightVisibility(c.self, i['target'], i['new_visibility'] as bool? ?? true);
    return const {};
  },
  'toggle_light_visibility': (c, i) {
    LuminaBlueprintFunctionLibrary.toggleLightVisibility(c.self, i['target']);
    return const {};
  },
  'set_light_radius': (c, i) {
    LuminaBlueprintFunctionLibrary.setLightRadius(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['new_radius'], 1000.0));
    return const {};
  },
  'set_spot_light_angles': (c, i) {
    LuminaBlueprintFunctionLibrary.setSpotLightAngles(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['inner_cone_angle'], 0.0), LuminaBlueprintFunctionLibrary._d(i['outer_cone_angle'], 44.0));
    return const {};
  },
  'print_text': (c, i) {
    LuminaBlueprintFunctionLibrary.printText(c.self, i['in_text'] as String? ?? '', i['print_to_screen'] as bool? ?? true, i['print_to_log'] as bool? ?? true,
        i['text_color'] is List ? LuminaBlueprintFunctionLibrary._c(i['text_color']) : null, LuminaBlueprintFunctionLibrary._d(i['duration'], 2.0), i['key'] as String? ?? '');
    return const {};
  },
  'draw_debug_line': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugLine(c.self, _vec3(i['line_start']), _vec3(i['line_end']), LuminaBlueprintFunctionLibrary._c(i['line_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0), LuminaBlueprintFunctionLibrary._d(i['thickness'], 0.0));
    return const {};
  },
  'draw_debug_sphere': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugSphere(c.self, _vec3(i['center']), LuminaBlueprintFunctionLibrary._d(i['radius'], 100.0), LuminaBlueprintFunctionLibrary._n(i['segments'], 12), LuminaBlueprintFunctionLibrary._c(i['line_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0), LuminaBlueprintFunctionLibrary._d(i['thickness'], 0.0));
    return const {};
  },
  'draw_debug_box': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugBox(c.self, _vec3(i['center']), _vec3(i['extent'], Vector3(50, 50, 50)), _rot3(i['rotation']), LuminaBlueprintFunctionLibrary._c(i['line_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0), LuminaBlueprintFunctionLibrary._d(i['thickness'], 0.0));
    return const {};
  },
  'draw_debug_point': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugPoint(c.self, _vec3(i['position']), LuminaBlueprintFunctionLibrary._d(i['size'], 4.0), LuminaBlueprintFunctionLibrary._c(i['point_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0));
    return const {};
  },
  'draw_debug_arrow': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugArrow(c.self, _vec3(i['line_start']), _vec3(i['line_end']), LuminaBlueprintFunctionLibrary._d(i['arrow_size'], 10.0), LuminaBlueprintFunctionLibrary._c(i['line_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0), LuminaBlueprintFunctionLibrary._d(i['thickness'], 0.0));
    return const {};
  },
  'draw_debug_string': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugString(c.self, _vec3(i['text_location']), i['text'] as String? ?? '', LuminaBlueprintFunctionLibrary._c(i['text_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0));
    return const {};
  },
  'draw_debug_capsule': (c, i) {
    LuminaBlueprintFunctionLibrary.drawDebugCapsule(c.self, _vec3(i['center']), LuminaBlueprintFunctionLibrary._d(i['half_height'], 80.0), LuminaBlueprintFunctionLibrary._d(i['radius'], 40.0), _rot3(i['rotation']), LuminaBlueprintFunctionLibrary._c(i['line_color']), LuminaBlueprintFunctionLibrary._d(i['duration'], 0.0), LuminaBlueprintFunctionLibrary._d(i['thickness'], 0.0));
    return const {};
  },
  'flush_debug_shapes': (c, i) {
    LuminaBlueprintFunctionLibrary.flushDebugShapes(c.self);
    return const {};
  },
  'breakpoint': (c, i) {
    LuminaBlueprintFunctionLibrary.breakpoint(c.self);
    return const {};
  },
  'log_warning': (c, i) {
    LuminaBlueprintFunctionLibrary.logWarning(c.self, i['in_string'] as String? ?? '');
    return const {};
  },
  'log_error': (c, i) {
    LuminaBlueprintFunctionLibrary.logError(c.self, i['in_string'] as String? ?? '');
    return const {};
  },
};
