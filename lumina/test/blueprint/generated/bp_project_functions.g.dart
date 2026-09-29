// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/BP_ProjectFunctions.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import '../fixtures/project_functions/health.dart' as fn_fixture_health;
import '../fixtures/project_functions/markers.dart' as fn_fixture_markers;
import '../fixtures/project_functions/types.dart' as fn_fixture_types;

class BpProjectFunctions extends LuminaActor with LuminaBlueprintRuntime {
  BpProjectFunctions({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'BP_ProjectFunctions';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  int calls = 0;

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
    int? ocount_return_value;
    int? oset_calls_value;
    bool? omove_return_value;
    fn_fixture_health.applyDamage(this, 25.0);
    if (trace != null) blueprintTrace('begin', 'damage', 'fn:package:fixture/health.dart#applyDamage', {'amount': 25.0, 'lethal': false});
    final r0 = fn_fixture_types.countCalls(this, 2);
    ocount_return_value = r0;
    if (trace != null) blueprintTrace('begin', 'count', 'fn:package:fixture/types.dart#countCalls', {'times': 2, 'return_value': r0});
    final p1 = fn_fixture_types.FixtureMath.twice((ocount_return_value ?? 0));
    if (trace != null) blueprintTrace('begin', 'twice', 'fn:package:fixture/types.dart#FixtureMath.twice', {'value': (ocount_return_value ?? 0), 'return_value': p1});
    calls = p1;
    oset_calls_value = p1;
    if (trace != null) blueprintTrace('begin', 'set_calls', 'variable_set', {'value': p1});
    final p2 = fn_fixture_markers.markerRing(1);
    if (trace != null) blueprintTrace('begin', 'ring', 'fn:package:fixture/markers.dart#markerRing', {'index': 1, 'radius': 250.0, 'count': 3, 'return_value': p2});
    final r3 = LuminaBlueprintFunctionLibrary.setActorLocation(this, p2, false);
    omove_return_value = r3;
    if (trace != null) blueprintTrace('begin', 'move', 'set_actor_location', {'new_location': p2, 'sweep': false, 'return_value': r3});
    LuminaBlueprintFunctionLibrary.printString(this, 'damaged', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'print', 'print_string', {'in_string': 'damaged', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'damaged');
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
