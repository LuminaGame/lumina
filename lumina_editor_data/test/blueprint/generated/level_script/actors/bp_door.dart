// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/BP_Door.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpDoor extends LuminaActor with LuminaBlueprintRuntime {
  BpDoor({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'BP_Door';

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
  ];

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'Open':
        _onOpen(); return const {};
      default:
        return super.callBlueprint(name, args);
    }
  }

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
    LuminaBlueprintFunctionLibrary.printString(this, 'Door ready', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'ready', 'print_string', {'in_string': 'Door ready', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'Door ready');
  }

  /// Open (node open).
  void _onOpen() {
    LuminaBlueprintFunctionLibrary.printString(this, 'Door opened', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('open', 'opened', 'print_string', {'in_string': 'Door opened', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'Door opened');
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
