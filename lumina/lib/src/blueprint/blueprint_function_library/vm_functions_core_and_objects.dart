part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: pawn, transform, UI
/// and gameplay nodes.
final Map<String, LuminaBlueprintFunction> _coreFunctions = <String, LuminaBlueprintFunction>{
  'print_string': (c, i) {
    LuminaBlueprintFunctionLibrary.printString(c.self, i['in_string'] as String? ?? '', i['print_to_screen'] as bool? ?? true, i['print_to_log'] as bool? ?? true,
        i['text_color'] is List ? LuminaBlueprintFunctionLibrary._c(i['text_color']) : null, LuminaBlueprintFunctionLibrary._d(i['duration'], 2.0), i['key'] as String? ?? '');
    return const {};
  },
  'add_movement_input': (c, i) {
    LuminaBlueprintFunctionLibrary.addMovementInput(
      c.self,
      i['world_dir'] as Vector3,
      i['scale_val'] as double,
      i['force'] as bool? ?? false,
    );
    return const {};
  },
  'add_controller_yaw_input': (c, i) {
    LuminaBlueprintFunctionLibrary.addControllerYawInput(c.self, i['val'] as double);
    return const {};
  },
  'add_controller_pitch_input': (c, i) {
    LuminaBlueprintFunctionLibrary.addControllerPitchInput(c.self, i['val'] as double);
    return const {};
  },
  'jump': (c, i) {
    LuminaBlueprintFunctionLibrary.jump(c.self);
    return const {};
  },
  'stop_jumping': (c, i) {
    LuminaBlueprintFunctionLibrary.stopJumping(c.self);
    return const {};
  },
  'set_free_look': (c, i) {
    LuminaBlueprintFunctionLibrary.setFreeLook(c.self, i['enabled'] as bool? ?? true);
    return const {};
  },
  'is_free_looking': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isFreeLooking(c.self)),
  'set_actor_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.setActorLocation(
      c.self,
      i['new_location'] as Vector3,
      i['sweep'] as bool? ?? false,
    ),
  ),
  'get_control_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getControlRotation(c.self)),
  'get_velocity': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getVelocity(c.self)),
  'is_falling': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isFalling(c.self)),
  'get_actor_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorLocation(c.self)),
  'get_actor_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorRotation(c.self)),
  'make_vector2d': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeVector2D(i['x'] as double, i['y'] as double)),
  'break_vector2d': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakVector2D(i['in_vec'] as Vector2);
    return {'x': r.x, 'y': r.y};
  },
  'make_vector': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeVector(i['x'] as double, i['y'] as double, i['z'] as double)),
  'break_vector': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakVector(i['in_vec'] as Vector3);
    return {'x': r.x, 'y': r.y, 'z': r.z};
  },
  'make_rotator': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeRotator(i['x'] as double, i['y'] as double, i['z'] as double)),
  'break_rotator': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakRotator(i['in_rot'] as LuminaRotator);
    return {'x': r.x, 'y': r.y, 'z': r.z};
  },
  'get_forward_vector': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getForwardVector(i['in_rot'] as LuminaRotator)),
  'get_right_vector': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getRightVector(i['in_rot'] as LuminaRotator)),
  'calculate_direction': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.calculateDirection(
      i['velocity'] as Vector3,
      i['base_rotation'] as LuminaRotator,
    ),
  ),
  'vector_length': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorLength(i['in_vec'] as Vector3)),
  'vector_length_xy': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorLengthXY(i['in_vec'] as Vector3)),
  'vector_scale': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorScale(i['a'] as Vector3, i['b'] as double)),
  'vector_add': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorAdd(i['a'] as Vector3, i['b'] as Vector3)),
  'float_add': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAdd(i['a'] as double, i['b'] as double)),
  'float_subtract': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatSubtract(i['a'] as double, i['b'] as double)),
  'float_multiply': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatMultiply(i['a'] as double, i['b'] as double)),
  'float_divide': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatDivide(i['a'] as double, i['b'] as double)),
  'float_clamp': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.floatClamp(i['value'] as double, i['min'] as double, i['max'] as double),
  ),
  'float_greater': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatGreater(i['a'] as double, i['b'] as double)),
  'float_less': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatLess(i['a'] as double, i['b'] as double)),
  'float_equal': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatEqual(i['a'] as double, i['b'] as double)),
  'bool_and': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.boolAnd(i['a'] as bool, i['b'] as bool)),
  'bool_or': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.boolOr(i['a'] as bool, i['b'] as bool)),
  'bool_not': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.boolNot(i['a'] as bool)),
  'create_widget': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.createWidget(
      c.self,
      i['class'] as String? ?? 'WBP_HUD',
      i['owning_player'],
    ),
  ),
  'add_to_viewport': (c, i) {
    LuminaBlueprintFunctionLibrary.addToViewport(c.self, i['target'], (i['z_order'] as num?)?.toInt() ?? 0);
    return const {};
  },
  'remove_from_parent': (c, i) {
    LuminaBlueprintFunctionLibrary.removeFromParent(c.self, i['target']);
    return const {};
  },
  'set_widget_visibility': (c, i) {
    LuminaBlueprintFunctionLibrary.setWidgetVisibility(
      c.self,
      i['target'],
      i['in_visibility'] as String? ?? 'Visible',
    );
    return const {};
  },
  'is_in_viewport': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isInViewport(i['target'])),
  'get_owning_player': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getOwningPlayer(i['target'])),
  'set_widget_text': (c, i) {
    LuminaBlueprintFunctionLibrary.setWidgetText(c.self, i['target'], i['in_text'] as String? ?? '');
    return const {};
  },
  'set_widget_percent': (c, i) {
    LuminaBlueprintFunctionLibrary.setWidgetPercent(
      c.self,
      i['target'],
      (i['in_percent'] as num?)?.toDouble() ?? 1.0,
    );
    return const {};
  },
  'get_player_controller': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.getPlayerController(c.self, (i['player_index'] as num?)?.toInt() ?? 0),
  ),
  'get_player_pawn': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPlayerPawn(c.self, (i['player_index'] as num?)?.toInt() ?? 0)),
  'get_player_character': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.getPlayerCharacter(c.self, (i['player_index'] as num?)?.toInt() ?? 0),
  ),
  'set_show_mouse_cursor': (c, i) {
    LuminaBlueprintFunctionLibrary.setShowMouseCursor(
      c.self,
      i['target'],
      i['show_mouse_cursor'] as bool? ?? true,
    );
    return const {};
  },
  'set_input_mode_game_and_ui': (c, i) {
    LuminaBlueprintFunctionLibrary.setInputModeGameAndUI(
      c.self,
      i['target'],
      i['in_widget_to_focus'],
      i['lock_mouse_to_viewport'] as bool? ?? false,
    );
    return const {};
  },
  'set_input_mode_game_only': (c, i) {
    LuminaBlueprintFunctionLibrary.setInputModeGameOnly(c.self, i['target']);
    return const {};
  },
  'set_input_mode_ui_only': (c, i) {
    LuminaBlueprintFunctionLibrary.setInputModeUIOnly(
      c.self,
      i['target'],
      i['in_widget_to_focus'],
      i['lock_mouse_to_viewport'] as bool? ?? false,
    );
    return const {};
  },
};

/// Objects, widget elements, components, physics.
final Map<String, LuminaBlueprintFunction> _objectFunctions = <String, LuminaBlueprintFunction>{
  // --- objects, widget elements, components ---------------------------------
  'is_valid': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isValid(i['input_object'])),
  'get_class_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getClassName(i['object'])),
  'is_a': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isA(i['object'], i['class'] as String? ?? '')),
  'get_display_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getDisplayName(i['object'])),
  'get_widget_element': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWidgetElement(i['target'], i['element'] as String? ?? '')),
  'set_element_visibility': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementVisibility(c.self, i['target'], i['in_visibility'] as String? ?? 'Visible');
    return const {};
  },
  'get_element_visibility': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementVisibility(i['target'])),
  'is_element_visible': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isElementVisible(i['target'])),
  'set_element_is_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementIsEnabled(c.self, i['target'], i['in_is_enabled'] as bool? ?? true);
    return const {};
  },
  'get_element_is_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementIsEnabled(i['target'])),
  'set_element_render_opacity': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementRenderOpacity(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_opacity'], 1.0));
    return const {};
  },
  'set_element_text': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementText(c.self, i['target'], i['in_text'] as String? ?? '');
    return const {};
  },
  'get_element_text': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementText(i['target'])),
  'set_element_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_font_size': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementFontSize(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_size'], 24.0));
    return const {};
  },
  'set_element_shadow_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementShadowEnabled(c.self, i['target'], i['in_enabled'] as bool? ?? true);
    return const {};
  },
  'set_element_shadow_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementShadowColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_shadow_offset': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementShadowOffset(c.self, i['target'], i['in_offset'] as Vector2? ?? Vector2(1.0, 1.0));
    return const {};
  },
  'set_element_outline': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementOutline(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_size'], 1.0), LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_percent': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementPercent(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_percent'], 1.0));
    return const {};
  },
  'get_element_percent': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementPercent(i['target'])),
  'set_element_fill_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementFillColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_brush_from_texture': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementBrushFromTexture(c.self, i['target'], i['texture'] as String? ?? '');
    return const {};
  },
  'set_element_image_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementImageColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_label': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementLabel(c.self, i['target'], i['in_label'] as String? ?? '');
    return const {};
  },
  'set_element_slider_value': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementSliderValue(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_value'], 0.0));
    return const {};
  },
  'get_element_slider_value': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementSliderValue(i['target'])),
  'set_element_is_checked': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementIsChecked(c.self, i['target'], i['in_is_checked'] as bool? ?? false);
    return const {};
  },
  'get_element_is_checked': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementIsChecked(i['target'])),
  'set_element_editable_text': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementEditableText(c.self, i['target'], i['in_text'] as String? ?? '');
    return const {};
  },
  'get_element_editable_text': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementEditableText(i['target'])),
  'set_element_hint_text': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementHintText(c.self, i['target'], i['in_hint_text'] as String? ?? '');
    return const {};
  },
  'set_element_selected_option': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementSelectedOption(c.self, i['target'], i['option'] as String? ?? '');
    return const {};
  },
  'get_element_selected_option': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementSelectedOption(i['target'])),
  'add_element_option': (c, i) {
    LuminaBlueprintFunctionLibrary.addElementOption(c.self, i['target'], i['option'] as String? ?? '');
    return const {};
  },
  'clear_element_options': (c, i) {
    LuminaBlueprintFunctionLibrary.clearElementOptions(c.self, i['target']);
    return const {};
  },
  'set_element_active_index': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementActiveIndex(c.self, i['target'], LuminaBlueprintFunctionLibrary._n(i['index'], 0));
    return const {};
  },
  'get_element_active_index': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getElementActiveIndex(i['target'])),
  'set_element_background_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementBackgroundColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_border_color': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementBorderColor(c.self, i['target'], LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return const {};
  },
  'set_element_corner_radius': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementCornerRadius(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_radius'], 8.0));
    return const {};
  },
  'set_element_padding': (c, i) {
    LuminaBlueprintFunctionLibrary.setElementPadding(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['left'], 0.0), LuminaBlueprintFunctionLibrary._d(i['top'], 0.0), LuminaBlueprintFunctionLibrary._d(i['right'], 0.0), LuminaBlueprintFunctionLibrary._d(i['bottom'], 0.0));
    return const {};
  },
  'get_component': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getComponent(c.self, i['component'] as String? ?? '')),
  'get_component_by_class': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getComponentByClass(c.self, i['class'] as String? ?? '')),
  'add_component': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.addComponent(c.self, i['class'] as String? ?? '', i['name'] as String? ?? '')),
  'set_relative_location': (c, i) {
    LuminaBlueprintFunctionLibrary.setRelativeLocation(i['target'], i['new_location'] as Vector3);
    return const {};
  },
  'set_relative_rotation': (c, i) {
    LuminaBlueprintFunctionLibrary.setRelativeRotation(i['target'], i['new_rotation'] as LuminaRotator);
    return const {};
  },
  'set_relative_scale': (c, i) {
    LuminaBlueprintFunctionLibrary.setRelativeScale(i['target'], i['new_scale'] as Vector3);
    return const {};
  },
  'get_relative_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getRelativeLocation(i['target'])),
  'get_relative_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getRelativeRotation(i['target'])),
  'get_relative_scale': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getRelativeScale(i['target'])),
  'set_world_location': (c, i) {
    LuminaBlueprintFunctionLibrary.setWorldLocation(i['target'], i['new_location'] as Vector3);
    return const {};
  },
  'set_world_rotation': (c, i) {
    LuminaBlueprintFunctionLibrary.setWorldRotation(i['target'], i['new_rotation'] as LuminaRotator);
    return const {};
  },
  'get_world_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWorldLocation(i['target'])),
  'get_world_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWorldRotation(i['target'])),
  'attach_to_component': (c, i) {
    LuminaBlueprintFunctionLibrary.attachToComponent(i['target'], i['parent'], i['socket_name'] as String? ?? '');
    return const {};
  },
  'set_component_visibility': (c, i) {
    LuminaBlueprintFunctionLibrary.setComponentVisibility(i['target'], i['new_visibility'] as bool? ?? true);
    return const {};
  },
  'set_hidden_in_game': (c, i) {
    LuminaBlueprintFunctionLibrary.setHiddenInGame(i['target'], i['new_hidden'] as bool? ?? false);
    return const {};
  },
  'get_socket_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSocketLocation(i['target'], i['in_socket_name'] as String? ?? '')),
  'set_target_arm_length': (c, i) {
    LuminaBlueprintFunctionLibrary.setTargetArmLength(i['target'], LuminaBlueprintFunctionLibrary._d(i['target_arm_length'], 300.0));
    return const {};
  },
  'get_target_arm_length': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTargetArmLength(i['target'])),
  'set_camera_lag_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setCameraLagEnabled(i['target'], i['enabled'] as bool? ?? true);
    return const {};
  },
  'set_camera_lag_speed': (c, i) {
    LuminaBlueprintFunctionLibrary.setCameraLagSpeed(i['target'], LuminaBlueprintFunctionLibrary._d(i['speed'], 10.0));
    return const {};
  },
  'set_socket_offset': (c, i) {
    LuminaBlueprintFunctionLibrary.setSocketOffset(i['target'], i['offset'] as Vector3);
    return const {};
  },
  'set_field_of_view': (c, i) {
    LuminaBlueprintFunctionLibrary.setFieldOfView(i['target'], LuminaBlueprintFunctionLibrary._d(i['in_field_of_view'], 90.0));
    return const {};
  },
  'get_field_of_view': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getFieldOfView(i['target'])),
  'set_camera_active': (c, i) {
    LuminaBlueprintFunctionLibrary.setCameraActive(i['target'], i['active'] as bool? ?? true);
    return const {};
  },
  'is_camera_active': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isCameraActive(i['target'])),
  'play_animation': (c, i) {
    LuminaBlueprintFunctionLibrary.playAnimation(i['target'], i['clip'] as String? ?? '', i['loop'] as bool? ?? true);
    return const {};
  },
  'stop_animation': (c, i) {
    LuminaBlueprintFunctionLibrary.stopAnimation(i['target']);
    return const {};
  },
  'set_anim_class': (c, i) {
    LuminaBlueprintFunctionLibrary.setAnimClass(c.self, i['target'], i['anim_class'] as String? ?? '');
    return const {};
  },
  'set_play_rate': (c, i) {
    LuminaBlueprintFunctionLibrary.setPlayRate(i['target'], LuminaBlueprintFunctionLibrary._d(i['rate'], 1.0));
    return const {};
  },
  'get_current_clip': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCurrentClip(i['target'])),
  'set_static_mesh': (c, i) {
    LuminaBlueprintFunctionLibrary.setStaticMesh(c.self, i['target'], i['new_mesh'] as String? ?? '');
    return const {};
  },
  'set_material': (c, i) {
    LuminaBlueprintFunctionLibrary.setMaterial(c.self, i['target'], LuminaBlueprintFunctionLibrary._n(i['element_index'], 0), i['material'] as String? ?? '');
    return const {};
  },
  'set_collision_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionEnabled(i['target'], i['new_type'] ?? 'QueryAndPhysics');
    return const {};
  },
  'set_collision_preset': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionPreset(i['target'], i['preset'] as String? ?? 'BlockAllDynamic');
    return const {};
  },
  'get_collision_preset': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCollisionPreset(i['target'])),
  'set_collision_response_to_channel': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionResponseToChannel(i['target'], i['channel'] as String? ?? 'Pawn', i['response'] as String? ?? 'Block');
    return const {};
  },
  'set_collision_response_to_all_channels': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionResponseToAllChannels(i['target'], i['response'] as String? ?? 'Block');
    return const {};
  },
  'get_collision_response_to_channel': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCollisionResponseToChannel(i['target'], i['channel'] as String? ?? 'Pawn')),
  'set_collision_object_type': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionObjectType(i['target'], i['object_type'] as String? ?? 'WorldDynamic');
    return const {};
  },
  'get_collision_object_type': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCollisionObjectType(i['target'])),
  'set_generate_overlap_events': (c, i) {
    LuminaBlueprintFunctionLibrary.setGenerateOverlapEvents(i['target'], i['generate'] as bool? ?? true);
    return const {};
  },
  'set_box_extent': (c, i) {
    LuminaBlueprintFunctionLibrary.setBoxExtent(i['target'], _vec3(i['box_extent']));
    return const {};
  },
  'get_box_extent': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getBoxExtent(i['target'])),
  'set_sphere_radius': (c, i) {
    LuminaBlueprintFunctionLibrary.setSphereRadius(i['target'], LuminaBlueprintFunctionLibrary._d(i['radius'], 50.0));
    return const {};
  },
  'get_sphere_radius': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSphereRadius(i['target'])),
  'set_capsule_size': (c, i) {
    LuminaBlueprintFunctionLibrary.setCapsuleSize(i['target'], LuminaBlueprintFunctionLibrary._d(i['radius'], 40.0), LuminaBlueprintFunctionLibrary._d(i['half_height'], 80.0));
    return const {};
  },
  'get_scaled_capsule_radius': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getScaledCapsuleRadius(i['target'])),
  'get_scaled_capsule_half_height': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getScaledCapsuleHalfHeight(i['target'])),
  'get_overlapping_actors': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getOverlappingActors(i['target'], i['class'] as String? ?? '')),
  'get_overlapping_components': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getOverlappingComponents(i['target'])),
  'is_overlapping_actor': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isOverlappingActor(i['target'], i['other'])),
  // physics
  'set_simulate_physics': (c, i) {
    LuminaBlueprintFunctionLibrary.setSimulatePhysics(i['target'], i['simulate'] as bool? ?? true);
    return const {};
  },
  'is_simulating_physics': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isSimulatingPhysics(i['target'])),
  'add_impulse': (c, i) {
    LuminaBlueprintFunctionLibrary.addImpulse(i['target'], _vec3(i['impulse']), i['bone_name'] as String? ?? '', i['vel_change'] as bool? ?? false);
    return const {};
  },
  'add_impulse_at_location': (c, i) {
    LuminaBlueprintFunctionLibrary.addImpulseAtLocation(i['target'], _vec3(i['impulse']), _vec3(i['location']), i['bone_name'] as String? ?? '');
    return const {};
  },
  'add_force': (c, i) {
    LuminaBlueprintFunctionLibrary.addForce(i['target'], _vec3(i['force']), i['bone_name'] as String? ?? '', i['accel_change'] as bool? ?? false);
    return const {};
  },
  'add_force_at_location': (c, i) {
    LuminaBlueprintFunctionLibrary.addForceAtLocation(i['target'], _vec3(i['force']), _vec3(i['location']), i['bone_name'] as String? ?? '');
    return const {};
  },
  'add_torque': (c, i) {
    LuminaBlueprintFunctionLibrary.addTorqueInRadians(i['target'], _vec3(i['torque']), i['bone_name'] as String? ?? '', i['accel_change'] as bool? ?? false);
    return const {};
  },
  'add_angular_impulse': (c, i) {
    LuminaBlueprintFunctionLibrary.addAngularImpulseInRadians(
        i['target'], _vec3(i['impulse']), i['bone_name'] as String? ?? '', i['vel_change'] as bool? ?? false);
    return const {};
  },
  'set_physics_linear_velocity': (c, i) {
    LuminaBlueprintFunctionLibrary.setPhysicsLinearVelocity(
        i['target'], _vec3(i['new_vel']), i['add_to_current'] as bool? ?? false, i['bone_name'] as String? ?? '');
    return const {};
  },
  'get_physics_linear_velocity': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPhysicsLinearVelocity(i['target'], i['bone_name'] as String? ?? '')),
  'set_physics_angular_velocity': (c, i) {
    LuminaBlueprintFunctionLibrary.setPhysicsAngularVelocityInDegrees(
        i['target'], _vec3(i['new_ang_vel']), i['add_to_current'] as bool? ?? false, i['bone_name'] as String? ?? '');
    return const {};
  },
  'get_physics_angular_velocity': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPhysicsAngularVelocityInDegrees(i['target'], i['bone_name'] as String? ?? '')),
  'get_mass': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getMass(i['target'])),
  'set_mass_override_in_kg': (c, i) {
    LuminaBlueprintFunctionLibrary.setMassOverrideInKg(i['target'], i['bone_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['mass_in_kg'], 1.0), i['override_mass'] as bool? ?? true);
    return const {};
  },
  'set_enable_gravity': (c, i) {
    LuminaBlueprintFunctionLibrary.setEnableGravity(i['target'], i['gravity_enabled'] as bool? ?? true);
    return const {};
  },
  'set_linear_damping': (c, i) {
    LuminaBlueprintFunctionLibrary.setLinearDamping(i['target'], LuminaBlueprintFunctionLibrary._d(i['in_damping'], 0.01));
    return const {};
  },
  'set_angular_damping': (c, i) {
    LuminaBlueprintFunctionLibrary.setAngularDamping(i['target'], LuminaBlueprintFunctionLibrary._d(i['in_damping'], 0.0));
    return const {};
  },
  'wake_rigid_body': (c, i) {
    LuminaBlueprintFunctionLibrary.wakeRigidBody(i['target'], i['bone_name'] as String? ?? '');
    return const {};
  },
  'put_rigid_body_to_sleep': (c, i) {
    LuminaBlueprintFunctionLibrary.putRigidBodyToSleep(i['target'], i['bone_name'] as String? ?? '');
    return const {};
  },
  'is_any_rigid_body_awake': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isAnyRigidBodyAwake(i['target'])),
  'set_collision_layer': (c, i) {
    LuminaBlueprintFunctionLibrary.setCollisionLayer(i['target'], LuminaBlueprintFunctionLibrary._n(i['layer'], 1));
    return const {};
  },
  'set_max_walk_speed': (c, i) {
    LuminaBlueprintFunctionLibrary.setMaxWalkSpeed(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['max_walk_speed'], 600.0));
    return const {};
  },
  'get_max_walk_speed': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getMaxWalkSpeed(c.self, i['target'])),
  'set_jump_z_velocity': (c, i) {
    LuminaBlueprintFunctionLibrary.setJumpZVelocity(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['jump_z_velocity'], 500.0));
    return const {};
  },
  'get_jump_z_velocity': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getJumpZVelocity(c.self, i['target'])),
  'set_gravity_scale': (c, i) {
    LuminaBlueprintFunctionLibrary.setGravityScale(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['gravity_scale'], 1.0));
    return const {};
  },
  'get_gravity_scale': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGravityScale(c.self, i['target'])),
  'set_air_control': (c, i) {
    LuminaBlueprintFunctionLibrary.setAirControl(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['air_control'], 0.35));
    return const {};
  },
  'get_air_control': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAirControl(c.self, i['target'])),
  'set_movement_mode': (c, i) {
    LuminaBlueprintFunctionLibrary.setMovementMode(c.self, i['target'], i['new_movement_mode'] as String? ?? 'Walking');
    return const {};
  },
  'get_movement_mode': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getMovementMode(c.self, i['target'])),
  'crouch': (c, i) {
    LuminaBlueprintFunctionLibrary.crouch(c.self, i['target']);
    return const {};
  },
  'un_crouch': (c, i) {
    LuminaBlueprintFunctionLibrary.unCrouch(c.self, i['target']);
    return const {};
  },
  'is_crouched': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isCrouched(c.self, i['target'])),
  'launch_character': (c, i) {
    LuminaBlueprintFunctionLibrary.launchCharacter(c.self, i['target'], i['launch_velocity'] as Vector3, i['xy_override'] as bool? ?? false,
        i['z_override'] as bool? ?? false);
    return const {};
  },
  'stop_movement_immediately': (c, i) {
    LuminaBlueprintFunctionLibrary.stopMovementImmediately(c.self, i['target']);
    return const {};
  },
};
