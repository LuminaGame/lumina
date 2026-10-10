// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_screen_resolution_and_apply.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpScreenResolutionAndApply extends LuminaActor with LuminaBlueprintRuntime {
  BpScreenResolutionAndApply({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_screen_resolution_and_apply';

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
    LuminaBlueprintFunctionLibrary.setScreenResolutionAndApply(this, 1600, 900);
    if (trace != null) blueprintTrace('begin', 'resolution', 'set_screen_resolution_and_apply', {'width': 1600, 'height': 900});
    final p0 = LuminaBlueprintFunctionLibrary.getScreenResolution(this);
    if (trace != null) blueprintTrace('begin', 'screen', 'get_screen_resolution', {'width': p0.width, 'height': p0.height});
    final p1 = LuminaBlueprintFunctionLibrary.intToString(p0.width);
    if (trace != null) blueprintTrace('begin', 'width_text', 'int_to_string', {'in_int': p0.width, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_width', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.getScreenResolution(this);
    if (trace != null) blueprintTrace('begin', 'screen', 'get_screen_resolution', {'width': p2.width, 'height': p2.height});
    final p3 = LuminaBlueprintFunctionLibrary.intToString(p2.height);
    if (trace != null) blueprintTrace('begin', 'height_text', 'int_to_string', {'in_int': p2.height, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_height', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
