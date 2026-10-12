// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_cursor_state.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpCursorState extends LuminaPawn with LuminaBlueprintRuntime {
  BpCursorState({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_cursor_state';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    final p0 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.getShowMouseCursor(this, p0);
    if (trace != null) blueprintTrace('begin', 'cursor_found', 'get_show_mouse_cursor', {'target': p0, 'return_value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.boolToString(p1);
    if (trace != null) blueprintTrace('begin', 'cursor_text_found', 'bool_to_string', {'in_bool': p1, 'return_value': p2});
    LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_cursor_found', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    final p3 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.getInputMode(this, p3);
    if (trace != null) blueprintTrace('begin', 'mode_found', 'get_input_mode', {'target': p3, 'return_value': p4});
    LuminaBlueprintFunctionLibrary.printString(this, p4, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_mode_found', 'print_string', {'in_string': p4, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p4);
    final p5 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.setShowMouseCursor(this, p5, true);
    if (trace != null) blueprintTrace('begin', 'show_cursor', 'set_show_mouse_cursor', {'target': p5, 'show_mouse_cursor': true});
    final p6 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p6});
    LuminaBlueprintFunctionLibrary.setInputModeUIOnly(this, p6, null, false);
    if (trace != null) blueprintTrace('begin', 'ui_only', 'set_input_mode_ui_only', {'target': p6, 'in_widget_to_focus': null, 'lock_mouse_to_viewport': false});
    final p7 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.getShowMouseCursor(this, p7);
    if (trace != null) blueprintTrace('begin', 'cursor_menu', 'get_show_mouse_cursor', {'target': p7, 'return_value': p8});
    final p9 = LuminaBlueprintFunctionLibrary.boolToString(p8);
    if (trace != null) blueprintTrace('begin', 'cursor_text_menu', 'bool_to_string', {'in_bool': p8, 'return_value': p9});
    LuminaBlueprintFunctionLibrary.printString(this, p9, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_cursor_menu', 'print_string', {'in_string': p9, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9);
    final p10 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p10});
    final p11 = LuminaBlueprintFunctionLibrary.getInputMode(this, p10);
    if (trace != null) blueprintTrace('begin', 'mode_menu', 'get_input_mode', {'target': p10, 'return_value': p11});
    LuminaBlueprintFunctionLibrary.printString(this, p11, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_mode_menu', 'print_string', {'in_string': p11, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p11);
    final p12 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p12});
    LuminaBlueprintFunctionLibrary.setShowMouseCursor(this, p12, false);
    if (trace != null) blueprintTrace('begin', 'hide_cursor', 'set_show_mouse_cursor', {'target': p12, 'show_mouse_cursor': false});
    final p13 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p13});
    LuminaBlueprintFunctionLibrary.setInputModeGameOnly(this, p13);
    if (trace != null) blueprintTrace('begin', 'game_only', 'set_input_mode_game_only', {'target': p13});
    final p14 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p14});
    final p15 = LuminaBlueprintFunctionLibrary.getShowMouseCursor(this, p14);
    if (trace != null) blueprintTrace('begin', 'cursor_restored', 'get_show_mouse_cursor', {'target': p14, 'return_value': p15});
    final p16 = LuminaBlueprintFunctionLibrary.boolToString(p15);
    if (trace != null) blueprintTrace('begin', 'cursor_text_restored', 'bool_to_string', {'in_bool': p15, 'return_value': p16});
    LuminaBlueprintFunctionLibrary.printString(this, p16, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_cursor_restored', 'print_string', {'in_string': p16, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p16);
    final p17 = LuminaBlueprintFunctionLibrary.getPlayerController(this, 0);
    if (trace != null) blueprintTrace('begin', 'pc', 'get_player_controller', {'player_index': 0, 'return_value': p17});
    final p18 = LuminaBlueprintFunctionLibrary.getInputMode(this, p17);
    if (trace != null) blueprintTrace('begin', 'mode_restored', 'get_input_mode', {'target': p17, 'return_value': p18});
    LuminaBlueprintFunctionLibrary.printString(this, p18, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_mode_restored', 'print_string', {'in_string': p18, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p18);
    final p19 = LuminaBlueprintFunctionLibrary.getGpuMemoryUsage(this);
    if (trace != null) blueprintTrace('begin', 'gpu', 'get_gpu_memory_usage', {'used_mb': p19.usedMb, 'budget_mb': p19.budgetMb, 'available': p19.available});
    final p20 = LuminaBlueprintFunctionLibrary.boolToString(p19.available);
    if (trace != null) blueprintTrace('begin', 'gpu_text', 'bool_to_string', {'in_bool': p19.available, 'return_value': p20});
    LuminaBlueprintFunctionLibrary.printString(this, p20, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_gpu', 'print_string', {'in_string': p20, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p20);
    final p21 = LuminaBlueprintFunctionLibrary.getRenderResolution(this);
    if (trace != null) blueprintTrace('begin', 'render', 'get_render_resolution', {'width': p21.width, 'height': p21.height});
    final p22 = LuminaBlueprintFunctionLibrary.intToString(p21.width);
    if (trace != null) blueprintTrace('begin', 'render_width_text', 'int_to_string', {'in_int': p21.width, 'return_value': p22});
    LuminaBlueprintFunctionLibrary.printString(this, p22, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_render_width', 'print_string', {'in_string': p22, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p22);
    final p23 = LuminaBlueprintFunctionLibrary.getRenderResolution(this);
    if (trace != null) blueprintTrace('begin', 'render', 'get_render_resolution', {'width': p23.width, 'height': p23.height});
    final p24 = LuminaBlueprintFunctionLibrary.intToString(p23.height);
    if (trace != null) blueprintTrace('begin', 'render_height_text', 'int_to_string', {'in_int': p23.height, 'return_value': p24});
    LuminaBlueprintFunctionLibrary.printString(this, p24, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_render_height', 'print_string', {'in_string': p24, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p24);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
