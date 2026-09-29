import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The math, conversion, string, transform and colour nodes.
void main() {
  final ctx = LuminaBlueprintCallContext(LuminaActor());
  Object? call(String id, Map<String, Object?> inputs) => LuminaBlueprintFunctionLibrary.functions[id]!(ctx, inputs)['return_value'];

  test('1 / DeltaSeconds → Round → Int To String → Format yields "FPS: 60"', () {
    final fps = call('float_divide', {'a': 1.0, 'b': 0.016667}) as double;
    final rounded = call('round', {'a': fps}) as int;
    final text = call('int_to_string', {'in_int': rounded}) as String;
    expect(call('format_string', {'format': 'FPS: {0}', 'arg_0': text, 'arg_1': '', 'arg_2': '', 'arg_3': ''}), 'FPS: 60');
    expect(call('append', {'a': 'FPS: ', 'b': text}), 'FPS: 60');
    expect(call('append_3', {'a': 'FPS', 'b': ': ', 'c': text}), 'FPS: 60');
  });

  test('float ↔ string conversions and the format placeholders', () {
    expect(call('float_to_string', {'in_float': 3.14159, 'decimals': 2}), '3.14');
    expect(call('float_to_string', {'in_float': 2.0, 'decimals': 0}), '2');
    expect(call('string_to_float', {'in_string': 'abc'}), 0.0);
    expect(call('string_to_float', {'in_string': ' 2.5 '}), 2.5);
    expect(call('string_to_int', {'in_string': '42'}), 42);
    expect(call('string_to_int', {'in_string': 'x'}), 0);
    expect(call('format_string', {'format': '{0} of {1} ({2})', 'arg_0': '1', 'arg_1': '3', 'arg_2': '', 'arg_3': ''}),
        '1 of 3 ({2})', reason: 'a missing {2} leaves the placeholder');
    expect(call('bool_to_string', {'in_bool': true}), 'true');
    expect(call('vector_to_string', {'in_vec': Vector3(1, 2, 3)}), 'X=1.000 Y=2.000 Z=3.000');
    expect(call('rotator_to_string', {'in_rot': const LuminaRotator(10, 20, 30)}), 'P=10.000 Y=30.000 R=20.000');
    expect(call('string_length', {'s': 'lumina'}), 6);
    expect(call('string_equal', {'a': 'Lumina', 'b': 'lumina', 'case_sensitive': false}), isTrue);
    expect(call('string_equal', {'a': 'Lumina', 'b': 'lumina', 'case_sensitive': true}), isFalse);
    expect(call('string_contains', {'search_in': 'Hello World', 'substring': 'world', 'use_case': false}), isTrue);
    expect(call('string_replace', {'source_string': 'a-b-c', 'from': '-', 'to': '+'}), 'a+b+c');
    expect(call('string_to_upper', {'s': 'abc'}), 'ABC');
    expect(call('string_to_lower', {'s': 'ABC'}), 'abc');
    expect(call('string_substring', {'s': 'lumina', 'start_index': 2, 'length': 3}), 'min');
    expect(call('string_substring', {'s': 'lumina', 'start_index': 4, 'length': 10}), 'na');
    expect(call('string_split', {'s': 'a b c', 'separator': ' '}), ['a', 'b', 'c']);
    expect(call('string_split', {'s': '', 'separator': ','}), isEmpty);
    expect(call('string_is_empty', {'s': ''}), isTrue);
    expect(call('string_trim', {'s': '  x '}), 'x');
    expect(call('select_string', {'a': 'A', 'b': 'B', 'pick_a': false}), 'B');
  });

  test('interpolation, map range, clamp angle, int division by zero', () {
    expect(call('float_interp_to', {'current': 0.0, 'target': 100.0, 'delta_time': 0.1, 'interp_speed': 5.0}), 50.0);
    expect(call('float_interp_to', {'current': 99.99999, 'target': 100.0, 'delta_time': 1.0, 'interp_speed': 1.0}), 100.0);
    expect(call('float_map_range_clamped', {'value': 5.0, 'in_range_a': 0.0, 'in_range_b': 10.0, 'out_range_a': 0.0, 'out_range_b': 1.0}), 0.5);
    expect(call('float_map_range_clamped', {'value': 50.0, 'in_range_a': 0.0, 'in_range_b': 10.0, 'out_range_a': 0.0, 'out_range_b': 1.0}), 1.0);
    expect(call('clamp_angle', {'angle_degrees': 370.0, 'min_angle': -180.0, 'max_angle': 180.0}), 10.0);
    expect(call('clamp_angle', {'angle_degrees': 200.0, 'min_angle': -90.0, 'max_angle': 90.0}), -90.0);
    expect(call('normalize_axis', {'angle': -190.0}), 170.0);
    expect(call('int_divide', {'a': 7, 'b': 0}), 0);
    expect(call('int_divide', {'a': 7, 'b': 2}), 3);
    expect(call('int_modulo', {'a': 7, 'b': 3}), 1);
    expect(call('float_modulo', {'a': 7.5, 'b': 2.0}), 1.5);
    expect(call('float_divide', {'a': 1.0, 'b': 0.0}), 0.0);
    expect(call('float_lerp', {'a': 0.0, 'b': 10.0, 'alpha': 0.25}), 2.5);
    expect(call('float_abs', {'a': -3.0}), 3.0);
    expect(call('float_min', {'a': 1.0, 'b': 2.0}), 1.0);
    expect(call('float_max', {'a': 1.0, 'b': 2.0}), 2.0);
    expect(call('float_sqrt', {'a': 16.0}), 4.0);
    expect(call('float_power', {'a': 2.0, 'b': 10.0}), 1024.0);
    expect(call('float_sign', {'a': -0.5}), -1.0);
    expect(call('float_nearly_equal', {'a': 1.0, 'b': 1.0000001, 'error_tolerance': 1e-6}), isTrue);
    expect(call('float_sin', {'a': 90.0}), closeTo(1.0, 1e-12));
    expect(call('float_cos', {'a': 180.0}), closeTo(-1.0, 1e-12));
    expect(call('float_tan', {'a': 45.0}), closeTo(1.0, 1e-12));
    expect(call('float_asin', {'a': 1.0}), closeTo(90.0, 1e-9));
    expect(call('float_acos', {'a': -1.0}), closeTo(180.0, 1e-9));
    expect(call('float_atan', {'a': 1.0}), closeTo(45.0, 1e-9));
    expect(call('float_atan2', {'y': 1.0, 'x': 0.0}), closeTo(90.0, 1e-9));
    expect(call('degrees_to_radians', {'a': 180.0}), closeTo(3.14159265, 1e-6));
    expect(call('radians_to_degrees', {'a': 3.14159265358979}), closeTo(180.0, 1e-6));
    expect(call('float_greater_equal', {'a': 2.0, 'b': 2.0}), isTrue);
    expect(call('float_less_equal', {'a': 3.0, 'b': 2.0}), isFalse);
    expect(call('float_not_equal', {'a': 3.0, 'b': 2.0}), isTrue);
    expect(call('select_float', {'a': 1.0, 'b': 2.0, 'pick_a': true}), 1.0);
    expect(call('truncate', {'a': -2.7}), -2);
    expect(call('ceil', {'a': 2.1}), 3);
    expect(call('floor', {'a': -2.1}), -3);
    expect(call('round', {'a': 2.5}), 3);
    expect(call('int_to_float', {'a': 3}), 3.0);
    expect(call('int_clamp', {'value': 15, 'min': 0, 'max': 10}), 10);
    expect(call('int_abs', {'a': -4}), 4);
    expect(call('int_min', {'a': 4, 'b': 2}), 2);
    expect(call('int_max', {'a': 4, 'b': 2}), 4);
    expect(call('int_increment', {'a': 4}), 5);
    expect(call('int_add', {'a': 4, 'b': 2}), 6);
    expect(call('int_subtract', {'a': 4, 'b': 2}), 2);
    expect(call('int_multiply', {'a': 4, 'b': 2}), 8);
    expect(call('int_greater', {'a': 4, 'b': 2}), isTrue);
    expect(call('int_less', {'a': 4, 'b': 2}), isFalse);
    expect(call('int_equal', {'a': 2, 'b': 2}), isTrue);
    expect(call('int_not_equal', {'a': 2, 'b': 2}), isFalse);
    expect(call('int_greater_equal', {'a': 2, 'b': 2}), isTrue);
    expect(call('int_less_equal', {'a': 1, 'b': 2}), isTrue);
    expect(call('select_int', {'a': 1, 'b': 2, 'pick_a': false}), 2);
    LuminaBlueprintFunctionLibrary.random = math.Random(7);
    for (var i = 0; i < 20; i++) {
      final f = call('random_float_in_range', {'min': 2.0, 'max': 3.0}) as double;
      expect(f, inInclusiveRange(2.0, 3.0));
      expect(call('random_integer_in_range', {'min': 1, 'max': 6}), inInclusiveRange(1, 6));
      expect(call('random_bool_with_weight', {'weight': 1.0}), isTrue);
      expect((call('random_unit_vector', {}) as Vector3).length, closeTo(1.0, 1e-9));
    }
  });

  test('vectors: normalize, dot, cross, distance, lerp, interp, project, rotate around axis', () {
    final unit = call('vector_normalize', {'a': Vector3(0, 3, 4)}) as Vector3;
    expect(unit.y, closeTo(0.6, 1e-12));
    expect(unit.z, closeTo(0.8, 1e-12));
    expect(call('vector_normalize', {'a': Vector3.zero()}), Vector3.zero());
    expect(call('vector_dot', {'a': Vector3(1, 2, 3), 'b': Vector3(4, 5, 6)}), 32.0);
    expect(call('vector_cross', {'a': Vector3(1, 0, 0), 'b': Vector3(0, 1, 0)}), Vector3(0, 0, 1));
    expect(call('vector_distance', {'a': Vector3(0, 0, 0), 'b': Vector3(3, 4, 0)}), 5.0);
    expect(call('vector_distance_2d', {'a': Vector3(0, 0, 10), 'b': Vector3(3, 4, 0)}), 5.0);
    expect(call('vector_lerp', {'a': Vector3.zero(), 'b': Vector3(10, 0, 0), 'alpha': 0.5}), Vector3(5, 0, 0));
    expect(call('vector_interp_to', {'current': Vector3.zero(), 'target': Vector3(100, 0, 0), 'delta_time': 0.1, 'interp_speed': 5.0}),
        Vector3(50, 0, 0));
    expect(call('vector_subtract', {'a': Vector3(3, 3, 3), 'b': Vector3(1, 2, 3)}), Vector3(2, 1, 0));
    expect(call('vector_divide_float', {'a': Vector3(2, 4, 6), 'b': 2.0}), Vector3(1, 2, 3));
    expect(call('vector_divide_float', {'a': Vector3(2, 4, 6), 'b': 0.0}), Vector3.zero());
    expect(call('vector_negate', {'a': Vector3(1, -2, 3)}), Vector3(-1, 2, -3));
    expect(call('vector_equal', {'a': Vector3(1, 1, 1), 'b': Vector3(1, 1, 1.00001), 'error_tolerance': 1e-4}), isTrue);
    expect(call('vector_project_on_to', {'a': Vector3(2, 3, 0), 'b': Vector3(1, 0, 0)}), Vector3(2, 0, 0));
    final rotated = call('rotate_vector_around_axis', {'in_vect': Vector3(1, 0, 0), 'angle_deg': 90.0, 'axis': Vector3(0, 0, 1)}) as Vector3;
    expect(rotated.x, closeTo(0, 1e-12));
    expect(rotated.y, closeTo(1, 1e-12));
    expect(call('vector_is_zero', {'a': Vector3.zero()}), isTrue);
    expect(call('select_vector', {'a': Vector3(1, 0, 0), 'b': Vector3(0, 1, 0), 'pick_a': false}), Vector3(0, 1, 0));
    final up = call('get_up_vector', {'in_rot': const LuminaRotator.zero()}) as Vector3;
    expect(up.z, closeTo(1, 1e-9), reason: 'authoring up is +Z');
  });

  test('rotators follow the library forward convention: yaw 0 faces +Y, yaw 90 faces +X', () {
    // The task text writes (100,0,0) → yaw 0; the engine's authoring forward
    // is +Y (LuminaRotator, getForwardVector), so +X is yaw 90 here and a
    // Set Actor Rotation from this node really faces the target (the property
    // asserted below for every direction, pitch included).
    LuminaRotator look(Vector3 to) => call('find_look_at_rotation', {'start': Vector3.zero(), 'target': to}) as LuminaRotator;
    expect(look(Vector3(0, 100, 0)).yaw, closeTo(0, 1e-9));
    expect(look(Vector3(100, 0, 0)).yaw, closeTo(90, 1e-9));
    expect(look(Vector3(-100, 0, 0)).yaw, closeTo(-90, 1e-9));
    for (final target in [Vector3(100, 0, 0), Vector3(0, 100, 0), Vector3(30, -40, 50), Vector3(-10, 20, -5)]) {
      final rot = look(target);
      final forward = LuminaBlueprintFunctionLibrary.getForwardVector(rot);
      final expected = target.normalized();
      for (var i = 0; i < 3; i++) {
        expect(forward[i], closeTo(expected[i], 1e-9), reason: 'forward of look-at $target, axis $i');
      }
      expect(call('rotator_to_vector', {'in_rot': rot}), forward);
      expect((call('make_rot_from_x', {'x': target}) as LuminaRotator), rot);
    }
    final combined = call('combine_rotators', {'a': const LuminaRotator(0, 0, 30), 'b': const LuminaRotator(0, 0, 40)}) as LuminaRotator;
    expect(combined.yaw, closeTo(70, 1e-9));
    expect(combined.pitch, closeTo(0, 1e-9));
    final delta = call('delta_rotator', {'a': const LuminaRotator(0, 0, 170), 'b': const LuminaRotator(0, 0, -170)}) as LuminaRotator;
    expect(delta.yaw, closeTo(-20, 1e-9), reason: 'shortest way round');
    final lerp = call('rotator_lerp', {'a': const LuminaRotator(0, 0, 170), 'b': const LuminaRotator(0, 0, -170), 'alpha': 0.5}) as LuminaRotator;
    expect(lerp.yaw, closeTo(180, 1e-9));
    final interp = call('rotator_interp_to', {'current': const LuminaRotator.zero(), 'target': const LuminaRotator(0, 0, 90), 'delta_time': 0.1, 'interp_speed': 5.0}) as LuminaRotator;
    expect(interp.yaw, closeTo(45, 1e-9));
    expect(call('rotator_equal', {'a': const LuminaRotator(0, 0, 180), 'b': const LuminaRotator(0, 0, -180), 'error_tolerance': 1e-4}), isTrue);
  });

  test('transforms round-trip, compose and move points; colours make, break, lerp and hex', () {
    final t = call('make_transform', {'location': Vector3(10, 20, 30), 'rotation': const LuminaRotator(0, 0, 90), 'scale': Vector3(1, 2, 3)});
    final parts = LuminaBlueprintFunctionLibrary.functions['break_transform']!(ctx, {'in_transform': t});
    expect(parts['location'], Vector3(10, 20, 30));
    expect(parts['rotation'], const LuminaRotator(0, 0, 90));
    expect(parts['scale'], Vector3(1, 2, 3));
    expect(t, {'location': [10.0, 20.0, 30.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 2.0, 3.0]}, reason: 'JSON-plain');

    // Yaw 90 turns forward (+Y) to +X, so it turns +X to -Y (the same hand
    // as getForwardVector; the task text's (0,1,0) assumes the other hand).
    final rot90 = call('make_transform', {'location': Vector3.zero(), 'rotation': const LuminaRotator(0, 0, 90), 'scale': Vector3(1, 1, 1)});
    final moved = call('transform_location', {'t': rot90, 'location': Vector3(1, 0, 0)}) as Vector3;
    expect(moved.x, closeTo(0, 1e-9));
    expect(moved.y, closeTo(-1, 1e-9));
    expect(moved.z, closeTo(0, 1e-9));
    final fwd = call('transform_location', {'t': rot90, 'location': Vector3(0, 1, 0)}) as Vector3;
    expect(fwd.x, closeTo(1, 1e-9));
    final back = call('inverse_transform_location', {'t': rot90, 'location': moved}) as Vector3;
    expect(back.x, closeTo(1, 1e-9));
    expect(back.y, closeTo(0, 1e-9));
    final dir = call('transform_direction', {'t': t, 'direction': Vector3(0, 1, 0)}) as Vector3;
    expect(dir.x, closeTo(1, 1e-9), reason: 'directions ignore location and scale');
    final world = call('transform_location', {'t': t, 'location': Vector3(1, 1, 1)}) as Vector3;
    expect(world.z, closeTo(33, 1e-9), reason: 'scaled by 3 then moved by 30');
    final composed = call('compose_transforms', {
      'a': call('make_transform', {'location': Vector3(1, 0, 0), 'rotation': const LuminaRotator.zero(), 'scale': Vector3(1, 1, 1)}),
      'b': call('make_transform', {'location': Vector3(0, 0, 5), 'rotation': const LuminaRotator(0, 0, 90), 'scale': Vector3(2, 2, 2)}),
    }) as Map;
    expect((composed['location'] as List)[1], closeTo(-2, 1e-9), reason: 'A\'s location turned and scaled into B');
    expect((composed['location'] as List)[2], closeTo(5, 1e-9));
    expect((composed['rotation'] as List)[2], closeTo(90, 1e-9));
    expect(composed['scale'], [2.0, 2.0, 2.0]);

    expect(call('make_color', {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0}), [1.0, 0.0, 0.0, 1.0]);
    expect(call('color_to_hex', {'in_color': [1.0, 0.0, 0.0, 1.0]}), '#FF0000FF');
    expect(call('hex_to_color', {'hex': '#FF0000FF'}), [1.0, 0.0, 0.0, 1.0]);
    expect(call('hex_to_color', {'hex': '00FF00'}), [0.0, 1.0, 0.0, 1.0]);
    expect(call('hex_to_color', {'hex': 'nope'}), [1.0, 1.0, 1.0, 1.0]);
    expect(call('color_lerp', {'a': [0.0, 0.0, 0.0, 1.0], 'b': [1.0, 1.0, 1.0, 1.0], 'alpha': 0.5}), [0.5, 0.5, 0.5, 1.0]);
    final rgba = LuminaBlueprintFunctionLibrary.functions['break_color']!(ctx, {'in_color': [0.1, 0.2, 0.3, 0.4]});
    expect(rgba, {'r': 0.1, 'g': 0.2, 'b': 0.3, 'a': 0.4});
  });

  test('every math / string node has display metadata and a call shape', () {
    for (final id in const [
      'float_lerp', 'float_interp_to', 'round', 'int_add', 'vector_dot', 'find_look_at_rotation', 'make_transform',
      'make_color', 'float_to_string', 'format_string', 'append', 'string_split', 'array_length', 'array_get',
      'make_array', 'array_add', 'array_filter_by_class', 'break_hit_result', 'make_hit_result', 'select_object',
    ]) {
      final spec = LuminaBlueprintNodeLibrary.spec(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.keywords, isNotEmpty, reason: '$id keywords');
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: '$id call shape');
      expect(LuminaBlueprintFunctionLibrary.functions.containsKey(id), isTrue, reason: '$id function');
    }
    expect(LuminaBlueprintNodeLibrary.spec('float_add')!.keywords, containsAll(['plus', 'add']));
    expect(LuminaBlueprintNodeLibrary.spec('append')!.keywords, contains('fps'));
    expect(LuminaBlueprintNodeLibrary.spec('float_divide')!.keywords, contains('divide'));
    expect(LuminaBlueprintNodeLibrary.spec('float_interp_to')!.title, 'FInterp To');
    expect(LuminaBlueprintNodeLibrary.spec('string_split')!.outputs.single.elementType, LuminaPinType.string);
    for (final id in LuminaBlueprintNodeLibrary.flowIntrinsics) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintNodeLibrary.intrinsics, contains(id));
    }
  });
}
