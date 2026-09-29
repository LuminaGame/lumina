// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_no_begin_play.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpNoBeginPlay extends LuminaActor with LuminaBlueprintRuntime {
  BpNoBeginPlay({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_no_begin_play';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'Ping':
        _onPing(); return const {};
      default:
        return super.callBlueprint(name, args);
    }
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
  }

  /// Ping (node ping).
  void _onPing() {
    if (trace != null) blueprintTrace('ping', 'wait', 'delay', {'duration': 0.25});
    blueprintDelay('wait', 0.25, () => _resumeWaitFromPing());
  }

  /// After Delay (node wait).
  void _resumeWaitFromPing() {
    LuminaBlueprintFunctionLibrary.printString(this, 'pong', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('ping', 'pong', 'print_string', {'in_string': 'pong', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'pong');
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
