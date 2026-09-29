// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_flow.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpFlow extends LuminaActor with LuminaBlueprintRuntime {
  BpFlow({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_flow';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  double x = 7.0;
  double total = 0.0;
  String label = 'it\'s \$ok';

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
    if (trace != null) blueprintTrace('begin', 'seq', 'sequence', {});
    LuminaBlueprintFunctionLibrary.printString(this, 'first', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'first', 'print_string', {'in_string': 'first', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'first');
    final p0 = x;
    if (trace != null) blueprintTrace('begin', 'x', 'variable_get', {'value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.floatGreater(p0, 5.0);
    if (trace != null) blueprintTrace('begin', 'gt', 'float_greater', {'a': p0, 'b': 5.0, 'return_value': p1});
    if (trace != null) blueprintTrace('begin', 'if', 'branch', {'condition': p1});
    if (p1) {
      final p2 = label;
      if (trace != null) blueprintTrace('begin', 'label', 'variable_get', {'value': p2});
      LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'yes', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'no', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'no', 'print_string', {'in_string': 'no', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'no');
    }
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    double? oset_total_value;
    final p3 = total;
    if (trace != null) blueprintTrace('tick', 'total', 'variable_get', {'value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.floatAdd(p3, deltaSeconds);
    if (trace != null) blueprintTrace('tick', 'add', 'float_add', {'a': p3, 'b': deltaSeconds, 'return_value': p4});
    total = p4;
    oset_total_value = p4;
    if (trace != null) blueprintTrace('tick', 'set_total', 'variable_set', {'value': p4});
    if (trace != null) blueprintTrace('tick', 'wait', 'delay', {'duration': 0.25});
    blueprintDelay('wait', 0.25, () => _resumeWaitFromTick(deltaSeconds));
  }

  /// After Delay (node wait).
  void _resumeWaitFromTick(double deltaSeconds) {
    bool? omove_return_value;
    final p5 = total;
    if (trace != null) blueprintTrace('tick', 'total', 'variable_get', {'value': p5});
    final p6 = LuminaBlueprintFunctionLibrary.floatMultiply(p5, 100.0);
    if (trace != null) blueprintTrace('tick', 'scaled', 'float_multiply', {'a': p5, 'b': 100.0, 'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.makeVector(p6, 0.0, 0.0);
    if (trace != null) blueprintTrace('tick', 'where', 'make_vector', {'x': p6, 'y': 0.0, 'z': 0.0, 'return_value': p7});
    final r8 = LuminaBlueprintFunctionLibrary.setActorLocation(this, p7, false);
    omove_return_value = r8;
    if (trace != null) blueprintTrace('tick', 'move', 'set_actor_location', {'new_location': p7, 'sweep': false, 'return_value': r8});
    if (trace != null) blueprintTrace('tick', 'moved', 'branch', {'condition': (omove_return_value ?? false)});
    if ((omove_return_value ?? false)) {
      LuminaBlueprintFunctionLibrary.printString(this, 'late', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('tick', 'late', 'print_string', {'in_string': 'late', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'late');
    }
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
