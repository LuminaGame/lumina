// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_conversions.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpConversions extends LuminaActor with LuminaBlueprintRuntime {
  BpConversions({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_conversions';

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
    final p0 = LuminaBlueprintFunctionLibrary.intToFloat(7);
    if (trace != null) blueprintTrace('begin', 'i2f', 'int_to_float', {'a': 7, 'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.floatToString(p0, 1);
    if (trace != null) blueprintTrace('begin', 'i2f_text', 'float_to_string', {'in_float': p0, 'decimals': 1, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_i2f', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.round(2.5);
    if (trace != null) blueprintTrace('begin', 'round', 'round', {'a': 2.5, 'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.intToString(p2);
    if (trace != null) blueprintTrace('begin', 'round_text', 'int_to_string', {'in_int': p2, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_round', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
    final p4 = LuminaBlueprintFunctionLibrary.truncate(-2.7);
    if (trace != null) blueprintTrace('begin', 'truncate', 'truncate', {'a': -2.7, 'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.intToString(p4);
    if (trace != null) blueprintTrace('begin', 'truncate_text', 'int_to_string', {'in_int': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_truncate', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    final p6 = LuminaBlueprintFunctionLibrary.floor(-2.1);
    if (trace != null) blueprintTrace('begin', 'floor', 'floor', {'a': -2.1, 'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.intToString(p6);
    if (trace != null) blueprintTrace('begin', 'floor_text', 'int_to_string', {'in_int': p6, 'return_value': p7});
    LuminaBlueprintFunctionLibrary.printString(this, p7, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_floor', 'print_string', {'in_string': p7, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p7);
    final p8 = LuminaBlueprintFunctionLibrary.ceil(2.1);
    if (trace != null) blueprintTrace('begin', 'ceil', 'ceil', {'a': 2.1, 'return_value': p8});
    final p9 = LuminaBlueprintFunctionLibrary.intToString(p8);
    if (trace != null) blueprintTrace('begin', 'ceil_text', 'int_to_string', {'in_int': p8, 'return_value': p9});
    LuminaBlueprintFunctionLibrary.printString(this, p9, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ceil', 'print_string', {'in_string': p9, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9);
    final p10 = LuminaBlueprintFunctionLibrary.boolToInt(true);
    if (trace != null) blueprintTrace('begin', 'b2i', 'bool_to_int', {'in_bool': true, 'return_value': p10});
    final p11 = LuminaBlueprintFunctionLibrary.intToString(p10);
    if (trace != null) blueprintTrace('begin', 'b2i_text', 'int_to_string', {'in_int': p10, 'return_value': p11});
    LuminaBlueprintFunctionLibrary.printString(this, p11, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_b2i', 'print_string', {'in_string': p11, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p11);
    final p12 = LuminaBlueprintFunctionLibrary.intToBool(0);
    if (trace != null) blueprintTrace('begin', 'i2b', 'int_to_bool', {'in_int': 0, 'return_value': p12});
    final p13 = LuminaBlueprintFunctionLibrary.boolToString(p12);
    if (trace != null) blueprintTrace('begin', 'i2b_text', 'bool_to_string', {'in_bool': p12, 'return_value': p13});
    LuminaBlueprintFunctionLibrary.printString(this, p13, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_i2b', 'print_string', {'in_string': p13, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p13);
    final p14 = LuminaBlueprintFunctionLibrary.boolToFloat(true);
    if (trace != null) blueprintTrace('begin', 'b2f', 'bool_to_float', {'in_bool': true, 'return_value': p14});
    final p15 = LuminaBlueprintFunctionLibrary.floatToString(p14, 1);
    if (trace != null) blueprintTrace('begin', 'b2f_text', 'float_to_string', {'in_float': p14, 'decimals': 1, 'return_value': p15});
    LuminaBlueprintFunctionLibrary.printString(this, p15, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_b2f', 'print_string', {'in_string': p15, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p15);
    final p16 = LuminaBlueprintFunctionLibrary.stringToIntChecked(' 42 ');
    if (trace != null) blueprintTrace('begin', 's2i', 'string_to_int', {'in_string': ' 42 ', 'return_value': p16.returnValue, 'success': p16.success});
    final p17 = LuminaBlueprintFunctionLibrary.intToString(p16.returnValue);
    if (trace != null) blueprintTrace('begin', 's2i_text', 'int_to_string', {'in_int': p16.returnValue, 'return_value': p17});
    LuminaBlueprintFunctionLibrary.printString(this, p17, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_s2i', 'print_string', {'in_string': p17, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p17);
    final p18 = LuminaBlueprintFunctionLibrary.stringToIntChecked(' 42 ');
    if (trace != null) blueprintTrace('begin', 's2i', 'string_to_int', {'in_string': ' 42 ', 'return_value': p18.returnValue, 'success': p18.success});
    final p19 = LuminaBlueprintFunctionLibrary.boolToString(p18.success);
    if (trace != null) blueprintTrace('begin', 's2i_ok_text', 'bool_to_string', {'in_bool': p18.success, 'return_value': p19});
    LuminaBlueprintFunctionLibrary.printString(this, p19, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_s2i_ok', 'print_string', {'in_string': p19, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p19);
    final p20 = LuminaBlueprintFunctionLibrary.stringToFloatChecked('abc');
    if (trace != null) blueprintTrace('begin', 's2f', 'string_to_float', {'in_string': 'abc', 'return_value': p20.returnValue, 'success': p20.success});
    final p21 = LuminaBlueprintFunctionLibrary.boolToString(p20.success);
    if (trace != null) blueprintTrace('begin', 's2f_ok_text', 'bool_to_string', {'in_bool': p20.success, 'return_value': p21});
    LuminaBlueprintFunctionLibrary.printString(this, p21, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_s2f_ok', 'print_string', {'in_string': p21, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p21);
    final p22 = LuminaBlueprintFunctionLibrary.stringToFloatChecked('abc');
    if (trace != null) blueprintTrace('begin', 's2f', 'string_to_float', {'in_string': 'abc', 'return_value': p22.returnValue, 'success': p22.success});
    if (trace != null) blueprintTrace('begin', 'parsed', 'branch', {'condition': p22.success});
    if (p22.success) {
      LuminaBlueprintFunctionLibrary.printString(this, 'parsed', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_parsed', 'print_string', {'in_string': 'parsed', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'parsed');
      final p23 = LuminaBlueprintFunctionLibrary.stringToIntChecked('12.7');
      if (trace != null) blueprintTrace('begin', 's2i_frac', 'string_to_int', {'in_string': '12.7', 'return_value': p23.returnValue, 'success': p23.success});
      final p24 = LuminaBlueprintFunctionLibrary.intToString(p23.returnValue);
      if (trace != null) blueprintTrace('begin', 's2i_frac_text', 'int_to_string', {'in_int': p23.returnValue, 'return_value': p24});
      LuminaBlueprintFunctionLibrary.printString(this, p24, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_s2i_frac', 'print_string', {'in_string': p24, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p24);
      final p25 = LuminaBlueprintFunctionLibrary.stringToName('Door_01');
      if (trace != null) blueprintTrace('begin', 's2n', 'string_to_name', {'in_string': 'Door_01', 'return_value': p25});
      final p26 = LuminaBlueprintFunctionLibrary.nameToString(p25);
      if (trace != null) blueprintTrace('begin', 'n2s', 'name_to_string', {'in_name': p25, 'return_value': p26});
      LuminaBlueprintFunctionLibrary.printString(this, p26, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_name', 'print_string', {'in_string': p26, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p26);
      final p27 = LuminaBlueprintFunctionLibrary.floatToVector(2.5);
      if (trace != null) blueprintTrace('begin', 'f2v', 'float_to_vector', {'in_float': 2.5, 'return_value': p27});
      final p28 = LuminaBlueprintFunctionLibrary.vectorToString(p27);
      if (trace != null) blueprintTrace('begin', 'f2v_text', 'vector_to_string', {'in_vec': p27, 'return_value': p28});
      LuminaBlueprintFunctionLibrary.printString(this, p28, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_f2v', 'print_string', {'in_string': p28, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p28);
      final p29 = LuminaBlueprintFunctionLibrary.floatToVector2D(-1.0);
      if (trace != null) blueprintTrace('begin', 'f2v2', 'float_to_vector2d', {'in_float': -1.0, 'return_value': p29});
      final p30 = LuminaBlueprintFunctionLibrary.breakVector2D(p29);
      if (trace != null) blueprintTrace('begin', 'f2v2_break', 'break_vector2d', {'in_vec': p29, 'x': p30.x, 'y': p30.y});
      final p31 = LuminaBlueprintFunctionLibrary.floatToString(p30.y, 2);
      if (trace != null) blueprintTrace('begin', 'f2v2_text', 'float_to_string', {'in_float': p30.y, 'decimals': 2, 'return_value': p31});
      LuminaBlueprintFunctionLibrary.printString(this, p31, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_f2v2', 'print_string', {'in_string': p31, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p31);
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'not a number', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_not_parsed', 'print_string', {'in_string': 'not a number', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'not a number');
      final p32 = LuminaBlueprintFunctionLibrary.stringToIntChecked('12.7');
      if (trace != null) blueprintTrace('begin', 's2i_frac', 'string_to_int', {'in_string': '12.7', 'return_value': p32.returnValue, 'success': p32.success});
      final p33 = LuminaBlueprintFunctionLibrary.intToString(p32.returnValue);
      if (trace != null) blueprintTrace('begin', 's2i_frac_text', 'int_to_string', {'in_int': p32.returnValue, 'return_value': p33});
      LuminaBlueprintFunctionLibrary.printString(this, p33, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_s2i_frac', 'print_string', {'in_string': p33, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p33);
      final p34 = LuminaBlueprintFunctionLibrary.stringToName('Door_01');
      if (trace != null) blueprintTrace('begin', 's2n', 'string_to_name', {'in_string': 'Door_01', 'return_value': p34});
      final p35 = LuminaBlueprintFunctionLibrary.nameToString(p34);
      if (trace != null) blueprintTrace('begin', 'n2s', 'name_to_string', {'in_name': p34, 'return_value': p35});
      LuminaBlueprintFunctionLibrary.printString(this, p35, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_name', 'print_string', {'in_string': p35, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p35);
      final p36 = LuminaBlueprintFunctionLibrary.floatToVector(2.5);
      if (trace != null) blueprintTrace('begin', 'f2v', 'float_to_vector', {'in_float': 2.5, 'return_value': p36});
      final p37 = LuminaBlueprintFunctionLibrary.vectorToString(p36);
      if (trace != null) blueprintTrace('begin', 'f2v_text', 'vector_to_string', {'in_vec': p36, 'return_value': p37});
      LuminaBlueprintFunctionLibrary.printString(this, p37, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_f2v', 'print_string', {'in_string': p37, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p37);
      final p38 = LuminaBlueprintFunctionLibrary.floatToVector2D(-1.0);
      if (trace != null) blueprintTrace('begin', 'f2v2', 'float_to_vector2d', {'in_float': -1.0, 'return_value': p38});
      final p39 = LuminaBlueprintFunctionLibrary.breakVector2D(p38);
      if (trace != null) blueprintTrace('begin', 'f2v2_break', 'break_vector2d', {'in_vec': p38, 'x': p39.x, 'y': p39.y});
      final p40 = LuminaBlueprintFunctionLibrary.floatToString(p39.y, 2);
      if (trace != null) blueprintTrace('begin', 'f2v2_text', 'float_to_string', {'in_float': p39.y, 'decimals': 2, 'return_value': p40});
      LuminaBlueprintFunctionLibrary.printString(this, p40, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_f2v2', 'print_string', {'in_string': p40, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p40);
    }
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
