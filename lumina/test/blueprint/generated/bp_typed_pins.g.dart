// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_typed_pins.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpTypedPins extends LuminaCharacter with LuminaBlueprintRuntime {
  BpTypedPins({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_typed_pins';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'capsule',
      name: 'CapsuleComponent',
      type: 'LuminaCapsuleComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'boom',
      name: 'CameraBoom',
      type: 'LuminaSpringArmComponent',
      parentId: 'capsule',
      properties: <String, dynamic>{'targetArmLength': 400.0},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'camera',
      name: 'FollowCamera',
      type: 'LuminaCameraComponent',
      parentId: 'boom',
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
  ];

  Object? hudWidget;
  double armLength = 0.0;
  int ticks = 0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    Object? ocreate_return_value;
    Object? oset_hud_value;
    Object? ocast_as_class;
    Object? ocast_door_as_class;
    double? oset_len_value;
    final r0 = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_HUD', null);
    ocreate_return_value = r0;
    if (trace != null) blueprintTrace('begin', 'create', 'create_widget', {'class': 'WBP_HUD', 'owning_player': null, 'return_value': r0});
    hudWidget = ocreate_return_value;
    oset_hud_value = ocreate_return_value;
    if (trace != null) blueprintTrace('begin', 'set_hud', 'variable_set', {'value': ocreate_return_value});
    LuminaBlueprintFunctionLibrary.addToViewport(this, oset_hud_value, 0);
    if (trace != null) blueprintTrace('begin', 'show', 'add_to_viewport', {'target': oset_hud_value, 'z_order': 0});
    final p1 = LuminaBlueprintFunctionLibrary.getPlayerCharacter(this, 0);
    if (trace != null) blueprintTrace('begin', 'me', 'get_player_character', {'player_index': 0, 'return_value': p1});
    final r2 = LuminaBlueprintFunctionLibrary.castTo(p1, 'Actor:LuminaCharacter');
    ocast_as_class = r2;
    if (trace != null) blueprintTrace('begin', 'cast', 'cast_to', {'object': p1, 'class': 'Actor:LuminaCharacter', 'as_class': r2});
    if (r2 != null) {
      final p3 = LuminaBlueprintFunctionLibrary.getClassName(ocast_as_class);
      if (trace != null) blueprintTrace('begin', 'class_name', 'get_class_name', {'object': ocast_as_class, 'return_value': p3});
      LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'is_character', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
      final p4 = LuminaBlueprintFunctionLibrary.getPlayerCharacter(this, 0);
      if (trace != null) blueprintTrace('begin', 'me', 'get_player_character', {'player_index': 0, 'return_value': p4});
      final r5 = LuminaBlueprintFunctionLibrary.castTo(p4, 'Actor:BP_Door');
      ocast_door_as_class = r5;
      if (trace != null) blueprintTrace('begin', 'cast_door', 'cast_to', {'object': p4, 'class': 'Actor:BP_Door', 'as_class': r5});
      if (r5 != null) {
        LuminaBlueprintFunctionLibrary.printString(this, 'a door', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'is_door', 'print_string', {'in_string': 'a door', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'a door');
      } else {
        LuminaBlueprintFunctionLibrary.printString(this, 'not a door', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'not_door', 'print_string', {'in_string': 'not a door', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'not a door');
        final p6 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p6});
        LuminaBlueprintFunctionLibrary.setTargetArmLength(p6, 500.0);
        if (trace != null) blueprintTrace('begin', 'arm', 'set_target_arm_length', {'target': p6, 'target_arm_length': 500.0});
        final p7 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p7});
        final p8 = LuminaBlueprintFunctionLibrary.getTargetArmLength(p7);
        if (trace != null) blueprintTrace('begin', 'arm_len', 'get_target_arm_length', {'target': p7, 'return_value': p8});
        armLength = p8;
        oset_len_value = p8;
        if (trace != null) blueprintTrace('begin', 'set_len', 'variable_set', {'value': p8});
        final p9 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p9});
        final p10 = LuminaBlueprintFunctionLibrary.getDisplayName(p9);
        if (trace != null) blueprintTrace('begin', 'boom_name', 'get_display_name', {'object': p9, 'return_value': p10});
        LuminaBlueprintFunctionLibrary.printString(this, p10, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'say_boom', 'print_string', {'in_string': p10, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p10);
      }
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'not a character', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'not_character', 'print_string', {'in_string': 'not a character', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'not a character');
      final p11 = LuminaBlueprintFunctionLibrary.getPlayerCharacter(this, 0);
      if (trace != null) blueprintTrace('begin', 'me', 'get_player_character', {'player_index': 0, 'return_value': p11});
      final r12 = LuminaBlueprintFunctionLibrary.castTo(p11, 'Actor:BP_Door');
      ocast_door_as_class = r12;
      if (trace != null) blueprintTrace('begin', 'cast_door', 'cast_to', {'object': p11, 'class': 'Actor:BP_Door', 'as_class': r12});
      if (r12 != null) {
        LuminaBlueprintFunctionLibrary.printString(this, 'a door', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'is_door', 'print_string', {'in_string': 'a door', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'a door');
      } else {
        LuminaBlueprintFunctionLibrary.printString(this, 'not a door', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'not_door', 'print_string', {'in_string': 'not a door', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'not a door');
        final p13 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p13});
        LuminaBlueprintFunctionLibrary.setTargetArmLength(p13, 500.0);
        if (trace != null) blueprintTrace('begin', 'arm', 'set_target_arm_length', {'target': p13, 'target_arm_length': 500.0});
        final p14 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p14});
        final p15 = LuminaBlueprintFunctionLibrary.getTargetArmLength(p14);
        if (trace != null) blueprintTrace('begin', 'arm_len', 'get_target_arm_length', {'target': p14, 'return_value': p15});
        armLength = p15;
        oset_len_value = p15;
        if (trace != null) blueprintTrace('begin', 'set_len', 'variable_set', {'value': p15});
        final p16 = LuminaBlueprintFunctionLibrary.getComponent(this, 'CameraBoom');
        if (trace != null) blueprintTrace('begin', 'boom', 'get_component', {'component': 'CameraBoom', 'return_value': p16});
        final p17 = LuminaBlueprintFunctionLibrary.getDisplayName(p16);
        if (trace != null) blueprintTrace('begin', 'boom_name', 'get_display_name', {'object': p16, 'return_value': p17});
        LuminaBlueprintFunctionLibrary.printString(this, p17, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'say_boom', 'print_string', {'in_string': p17, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p17);
      }
    }
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    final p18 = hudWidget;
    if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p18});
    if (trace != null) blueprintTrace('tick', 'valid', 'is_valid_branch', {'input_object': p18});
    if (LuminaBlueprintFunctionLibrary.isValid(p18)) {
      final p19 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p19});
      final p20 = LuminaBlueprintFunctionLibrary.getWidgetElement(p19, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p19, 'element': 'FPSCounter', 'return_value': p20});
      LuminaBlueprintFunctionLibrary.setElementText(this, p20, 'FPS: 60');
      if (trace != null) blueprintTrace('tick', 'set_text', 'set_element_text', {'target': p20, 'in_text': 'FPS: 60'});
      final p21 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p21});
      final p22 = LuminaBlueprintFunctionLibrary.getWidgetElement(p21, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p21, 'element': 'FPSCounter', 'return_value': p22});
      LuminaBlueprintFunctionLibrary.setElementShadowEnabled(this, p22, true);
      if (trace != null) blueprintTrace('tick', 'shadow_on', 'set_element_shadow_enabled', {'target': p22, 'in_enabled': true});
      final p23 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p23});
      final p24 = LuminaBlueprintFunctionLibrary.getWidgetElement(p23, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p23, 'element': 'FPSCounter', 'return_value': p24});
      LuminaBlueprintFunctionLibrary.setElementShadowColor(this, p24, <double>[1.0, 0.0, 0.0, 0.5]);
      if (trace != null) blueprintTrace('tick', 'shadow_color', 'set_element_shadow_color', {'target': p24, 'in_color': <double>[1.0, 0.0, 0.0, 0.5]});
      final p25 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p25});
      final p26 = LuminaBlueprintFunctionLibrary.getWidgetElement(p25, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p25, 'element': 'FPSCounter', 'return_value': p26});
      LuminaBlueprintFunctionLibrary.setElementShadowOffset(this, p26, Vector2(3.0, 4.0));
      if (trace != null) blueprintTrace('tick', 'shadow_offset', 'set_element_shadow_offset', {'target': p26, 'in_offset': Vector2(3.0, 4.0)});
      final p27 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p27});
      final p28 = LuminaBlueprintFunctionLibrary.getWidgetElement(p27, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p27, 'element': 'FPSCounter', 'return_value': p28});
      LuminaBlueprintFunctionLibrary.setElementOutline(this, p28, 2.0, <double>[0.0, 0.0, 0.0, 1.0]);
      if (trace != null) blueprintTrace('tick', 'outline', 'set_element_outline', {'target': p28, 'in_size': 2.0, 'in_color': <double>[0.0, 0.0, 0.0, 1.0]});
      final p29 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p29});
      final p30 = LuminaBlueprintFunctionLibrary.getWidgetElement(p29, 'Panel');
      if (trace != null) blueprintTrace('tick', 'panel', 'get_widget_element', {'target': p29, 'element': 'Panel', 'return_value': p30});
      LuminaBlueprintFunctionLibrary.setElementBackgroundColor(this, p30, <double>[0.2, 0.4, 0.6, 1.0]);
      if (trace != null) blueprintTrace('tick', 'panel_bg', 'set_element_background_color', {'target': p30, 'in_color': <double>[0.2, 0.4, 0.6, 1.0]});
      final p31 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p31});
      final p32 = LuminaBlueprintFunctionLibrary.getWidgetElement(p31, 'Panel');
      if (trace != null) blueprintTrace('tick', 'panel', 'get_widget_element', {'target': p31, 'element': 'Panel', 'return_value': p32});
      LuminaBlueprintFunctionLibrary.setElementBorderColor(this, p32, <double>[1.0, 0.5, 0.0, 1.0]);
      if (trace != null) blueprintTrace('tick', 'panel_border', 'set_element_border_color', {'target': p32, 'in_color': <double>[1.0, 0.5, 0.0, 1.0]});
      final p33 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p33});
      final p34 = LuminaBlueprintFunctionLibrary.getWidgetElement(p33, 'Panel');
      if (trace != null) blueprintTrace('tick', 'panel', 'get_widget_element', {'target': p33, 'element': 'Panel', 'return_value': p34});
      LuminaBlueprintFunctionLibrary.setElementCornerRadius(this, p34, 12.0);
      if (trace != null) blueprintTrace('tick', 'panel_radius', 'set_element_corner_radius', {'target': p34, 'in_radius': 12.0});
      final p35 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p35});
      final p36 = LuminaBlueprintFunctionLibrary.getWidgetElement(p35, 'Panel');
      if (trace != null) blueprintTrace('tick', 'panel', 'get_widget_element', {'target': p35, 'element': 'Panel', 'return_value': p36});
      LuminaBlueprintFunctionLibrary.setElementPadding(this, p36, 4.0, 8.0, 4.0, 8.0);
      if (trace != null) blueprintTrace('tick', 'panel_padding', 'set_element_padding', {'target': p36, 'left': 4.0, 'top': 8.0, 'right': 4.0, 'bottom': 8.0});
      final p37 = hudWidget;
      if (trace != null) blueprintTrace('tick', 'hud', 'variable_get', {'value': p37});
      final p38 = LuminaBlueprintFunctionLibrary.getWidgetElement(p37, 'FPSCounter');
      if (trace != null) blueprintTrace('tick', 'fps', 'get_widget_element', {'target': p37, 'element': 'FPSCounter', 'return_value': p38});
      final p39 = LuminaBlueprintFunctionLibrary.getElementText(p38);
      if (trace != null) blueprintTrace('tick', 'read_text', 'get_element_text', {'target': p38, 'return_value': p39});
      LuminaBlueprintFunctionLibrary.printString(this, p39, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('tick', 'echo', 'print_string', {'in_string': p39, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p39);
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'no hud', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('tick', 'no_hud', 'print_string', {'in_string': 'no hud', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'no hud');
    }
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
