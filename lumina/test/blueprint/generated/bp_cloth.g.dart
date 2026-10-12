// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_cloth.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpCloth extends LuminaActor with LuminaBlueprintRuntime {
  BpCloth({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_cloth';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root',
      name: 'DefaultSceneRoot',
      type: 'LuminaSceneComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'flag',
      name: 'Flag',
      type: 'LuminaClothComponent',
      parentId: 'root',
      properties: <String, dynamic>{'gridWidth': 120.0, 'gridHeight': 80.0, 'gridColumns': 12, 'gridRows': 8, 'pinning': 'topEdge', 'massKg': 0.5, 'stiffness': 0.95, 'bendStiffness': 0.2, 'wind': <dynamic>[0.0, 0.0, 0.0], 'color': <dynamic>[0.1, 0.3, 0.8], 'location': <dynamic>[0.0, 0.0, 300.0]},
      isSceneComponent: true,
    ),
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
    final p0 = LuminaBlueprintFunctionLibrary.isClothSimulating(this);
    if (trace != null) blueprintTrace('begin', 'before', 'is_cloth_simulating', {'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.boolToString(p0);
    if (trace != null) blueprintTrace('begin', 'before_text', 'bool_to_string', {'in_bool': p0, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_before', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    LuminaBlueprintFunctionLibrary.setClothWind(this, Vector3(600.0, 0.0, 0.0), 2.0);
    if (trace != null) blueprintTrace('begin', 'blow', 'set_cloth_wind', {'wind': Vector3(600.0, 0.0, 0.0), 'drag': 2.0});
    LuminaBlueprintFunctionLibrary.pinClothVertex(this, 100, true);
    if (trace != null) blueprintTrace('begin', 'pin', 'pin_cloth_vertex', {'vertex': 100, 'pinned': true});
    LuminaBlueprintFunctionLibrary.setClothSimulationEnabled(this, false);
    if (trace != null) blueprintTrace('begin', 'off', 'set_cloth_simulation_enabled', {'enabled': false});
    final p2 = LuminaBlueprintFunctionLibrary.isClothSimulating(this);
    if (trace != null) blueprintTrace('begin', 'during', 'is_cloth_simulating', {'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.boolToString(p2);
    if (trace != null) blueprintTrace('begin', 'during_text', 'bool_to_string', {'in_bool': p2, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_during', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
    LuminaBlueprintFunctionLibrary.setClothSimulationEnabled(this, true);
    if (trace != null) blueprintTrace('begin', 'on', 'set_cloth_simulation_enabled', {'enabled': true});
    LuminaBlueprintFunctionLibrary.resetCloth(this);
    if (trace != null) blueprintTrace('begin', 'reset', 'reset_cloth', {});
    final p4 = LuminaBlueprintFunctionLibrary.isClothSimulating(this);
    if (trace != null) blueprintTrace('begin', 'after', 'is_cloth_simulating', {'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.boolToString(p4);
    if (trace != null) blueprintTrace('begin', 'after_text', 'bool_to_string', {'in_bool': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_after', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
