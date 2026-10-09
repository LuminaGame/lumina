part of '../blueprint_function_library.dart';

/// Math, string, array, struct.
final Map<String, LuminaBlueprintFunction> _mathFunctions = <String, LuminaBlueprintFunction>{
  // --- math, string, array, struct -------------------------------------------
  'float_abs': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAbs(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_min': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatMin(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'float_max': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatMax(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'float_lerp': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatLerp(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0), LuminaBlueprintFunctionLibrary._d(i['alpha'], 0))),
  'float_interp_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatInterpTo(LuminaBlueprintFunctionLibrary._d(i['current'], 0), LuminaBlueprintFunctionLibrary._d(i['target'], 0), LuminaBlueprintFunctionLibrary._d(i['delta_time'], 0), LuminaBlueprintFunctionLibrary._d(i['interp_speed'], 1))),
  'float_sqrt': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatSqrt(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_power': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatPower(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'float_modulo': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatModulo(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 1))),
  'float_sign': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatSign(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_map_range_clamped': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatMapRangeClamped(
      LuminaBlueprintFunctionLibrary._d(i['value'], 0), LuminaBlueprintFunctionLibrary._d(i['in_range_a'], 0), LuminaBlueprintFunctionLibrary._d(i['in_range_b'], 1), LuminaBlueprintFunctionLibrary._d(i['out_range_a'], 0), LuminaBlueprintFunctionLibrary._d(i['out_range_b'], 1))),
  'float_nearly_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatNearlyEqual(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0), LuminaBlueprintFunctionLibrary._d(i['error_tolerance'], 1e-6))),
  'float_sin': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatSin(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_cos': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatCos(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_tan': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatTan(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_asin': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAsin(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_acos': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAcos(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_atan': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAtan(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_atan2': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatAtan2(LuminaBlueprintFunctionLibrary._d(i['y'], 0), LuminaBlueprintFunctionLibrary._d(i['x'], 0))),
  'degrees_to_radians': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.degreesToRadians(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'radians_to_degrees': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.radiansToDegrees(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'float_greater_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatGreaterEqual(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'float_less_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatLessEqual(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'float_not_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatNotEqual(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0))),
  'random_float_in_range': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.randomFloatInRange(LuminaBlueprintFunctionLibrary._d(i['min'], 0), LuminaBlueprintFunctionLibrary._d(i['max'], 1))),
  'random_bool_with_weight': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.randomBoolWithWeight(LuminaBlueprintFunctionLibrary._d(i['weight'], 0.5))),
  'select_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectFloat(LuminaBlueprintFunctionLibrary._d(i['a'], 0), LuminaBlueprintFunctionLibrary._d(i['b'], 0), i['pick_a'] as bool? ?? false)),
  'round': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.round(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'truncate': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.truncate(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'ceil': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.ceil(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'floor': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floor(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'int_to_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intToFloat(LuminaBlueprintFunctionLibrary._n(i['a'], 0))),
  'int_add': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intAdd(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_subtract': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intSubtract(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_multiply': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intMultiply(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 1))),
  'int_divide': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intDivide(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 1))),
  'int_modulo': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intModulo(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 1))),
  'int_clamp': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intClamp(LuminaBlueprintFunctionLibrary._n(i['value'], 0), LuminaBlueprintFunctionLibrary._n(i['min'], 0), LuminaBlueprintFunctionLibrary._n(i['max'], 100))),
  'int_abs': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intAbs(LuminaBlueprintFunctionLibrary._n(i['a'], 0))),
  'int_min': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intMin(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_max': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intMax(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_greater': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intGreater(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_less': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intLess(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intEqual(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_not_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intNotEqual(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_greater_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intGreaterEqual(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'int_less_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intLessEqual(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0))),
  'random_integer_in_range': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.randomIntegerInRange(LuminaBlueprintFunctionLibrary._n(i['min'], 0), LuminaBlueprintFunctionLibrary._n(i['max'], 10))),
  'int_increment': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intIncrement(LuminaBlueprintFunctionLibrary._n(i['a'], 0))),
  'select_int': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectInt(LuminaBlueprintFunctionLibrary._n(i['a'], 0), LuminaBlueprintFunctionLibrary._n(i['b'], 0), i['pick_a'] as bool? ?? false)),
  'vector_normalize': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorNormalize(_vec3(i['a']))),
  'vector_dot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorDot(_vec3(i['a']), _vec3(i['b']))),
  'vector_cross': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorCross(_vec3(i['a']), _vec3(i['b']))),
  'vector_distance': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorDistance(_vec3(i['a']), _vec3(i['b']))),
  'vector_distance_2d': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorDistance2D(_vec3(i['a']), _vec3(i['b']))),
  'vector_lerp': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorLerp(_vec3(i['a']), _vec3(i['b']), LuminaBlueprintFunctionLibrary._d(i['alpha'], 0))),
  'vector_interp_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorInterpTo(_vec3(i['current']), _vec3(i['target']), LuminaBlueprintFunctionLibrary._d(i['delta_time'], 0), LuminaBlueprintFunctionLibrary._d(i['interp_speed'], 1))),
  'vector_subtract': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorSubtract(_vec3(i['a']), _vec3(i['b']))),
  'vector_divide_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorDivideFloat(_vec3(i['a']), LuminaBlueprintFunctionLibrary._d(i['b'], 1))),
  'vector_negate': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorNegate(_vec3(i['a']))),
  'vector_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorEqual(_vec3(i['a']), _vec3(i['b']), LuminaBlueprintFunctionLibrary._d(i['error_tolerance'], 1e-4))),
  'vector_project_on_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorProjectOnTo(_vec3(i['a']), _vec3(i['b']))),
  'rotate_vector_around_axis': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotateVectorAroundAxis(_vec3(i['in_vect']), LuminaBlueprintFunctionLibrary._d(i['angle_deg'], 0), _vec3(i['axis']))),
  'get_up_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getUpVector(_rot3(i['in_rot']))),
  'random_unit_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.randomUnitVector()),
  'vector_is_zero': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorIsZero(_vec3(i['a']))),
  'select_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectVector(_vec3(i['a']), _vec3(i['b']), i['pick_a'] as bool? ?? false)),
  'combine_rotators': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.combineRotators(_rot3(i['a']), _rot3(i['b']))),
  'delta_rotator': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.deltaRotator(_rot3(i['a']), _rot3(i['b']))),
  'rotator_lerp': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotatorLerp(_rot3(i['a']), _rot3(i['b']), LuminaBlueprintFunctionLibrary._d(i['alpha'], 0))),
  'rotator_interp_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotatorInterpTo(_rot3(i['current']), _rot3(i['target']), LuminaBlueprintFunctionLibrary._d(i['delta_time'], 0), LuminaBlueprintFunctionLibrary._d(i['interp_speed'], 1))),
  'find_look_at_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.findLookAtRotation(_vec3(i['start']), _vec3(i['target']))),
  'rotator_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotatorEqual(_rot3(i['a']), _rot3(i['b']), LuminaBlueprintFunctionLibrary._d(i['error_tolerance'], 1e-4))),
  'clamp_angle': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.clampAngle(LuminaBlueprintFunctionLibrary._d(i['angle_degrees'], 0), LuminaBlueprintFunctionLibrary._d(i['min_angle'], -180), LuminaBlueprintFunctionLibrary._d(i['max_angle'], 180))),
  'normalize_axis': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.normalizeAxis(LuminaBlueprintFunctionLibrary._d(i['angle'], 0))),
  'rotator_to_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotatorToVector(_rot3(i['in_rot']))),
  'make_rot_from_x': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeRotFromX(_vec3(i['x']))),
  'make_transform': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeTransform(_vec3(i['location']), _rot3(i['rotation']), _vec3(i['scale'], Vector3(1, 1, 1)))),
  'break_transform': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakTransform(i['in_transform']);
    return {'location': r.location, 'rotation': r.rotation, 'scale': r.scale};
  },
  'compose_transforms': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.composeTransforms(i['a'], i['b'])),
  'transform_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.transformLocation(i['t'], _vec3(i['location']))),
  'inverse_transform_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.inverseTransformLocation(i['t'], _vec3(i['location']))),
  'transform_direction': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.transformDirection(i['t'], _vec3(i['direction']))),
  'make_color': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeColor(LuminaBlueprintFunctionLibrary._d(i['r'], 1), LuminaBlueprintFunctionLibrary._d(i['g'], 1), LuminaBlueprintFunctionLibrary._d(i['b'], 1), LuminaBlueprintFunctionLibrary._d(i['a'], 1))),
  'break_color': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakColor(LuminaBlueprintFunctionLibrary._c(i['in_color']));
    return {'r': r.r, 'g': r.g, 'b': r.b, 'a': r.a};
  },
  'color_lerp': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.colorLerp(LuminaBlueprintFunctionLibrary._c(i['a']), LuminaBlueprintFunctionLibrary._c(i['b']), LuminaBlueprintFunctionLibrary._d(i['alpha'], 0))),
  'hex_to_color': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.hexToColor(i['hex'] as String? ?? '')),
  'color_to_hex': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.colorToHex(LuminaBlueprintFunctionLibrary._c(i['in_color']))),
  'float_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.floatToString(LuminaBlueprintFunctionLibrary._d(i['in_float'], 0), LuminaBlueprintFunctionLibrary._n(i['decimals'], 2))),
  'int_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intToString(LuminaBlueprintFunctionLibrary._n(i['in_int'], 0))),
  'bool_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.boolToString(i['in_bool'] as bool? ?? false)),
  'vector_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.vectorToString(_vec3(i['in_vec']))),
  'rotator_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.rotatorToString(_rot3(i['in_rot']))),
  'string_to_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringToFloat(i['in_string'] as String? ?? '')),
  'string_to_int': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringToInt(i['in_string'] as String? ?? '')),
  'append': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.append(i['a'] as String? ?? '', i['b'] as String? ?? '')),
  'append_3': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.append3(i['a'] as String? ?? '', i['b'] as String? ?? '', i['c'] as String? ?? '')),
  'format_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.formatString(i['format'] as String? ?? '', i['arg_0'] as String? ?? '', i['arg_1'] as String? ?? '',
      i['arg_2'] as String? ?? '', i['arg_3'] as String? ?? '')),
  'string_length': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringLength(i['s'] as String? ?? '')),
  'string_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringEqual(i['a'] as String? ?? '', i['b'] as String? ?? '', i['case_sensitive'] as bool? ?? true)),
  'string_contains': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringContains(i['search_in'] as String? ?? '', i['substring'] as String? ?? '', i['use_case'] as bool? ?? true)),
  'string_replace': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringReplace(i['source_string'] as String? ?? '', i['from'] as String? ?? '', i['to'] as String? ?? '')),
  'string_to_upper': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringToUpper(i['s'] as String? ?? '')),
  'string_to_lower': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringToLower(i['s'] as String? ?? '')),
  'string_substring': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringSubstring(i['s'] as String? ?? '', LuminaBlueprintFunctionLibrary._n(i['start_index'], 0), LuminaBlueprintFunctionLibrary._n(i['length'], 1))),
  'string_split': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringSplit(i['s'] as String? ?? '', i['separator'] as String? ?? ' ')),
  'string_is_empty': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringIsEmpty(i['s'] as String? ?? '')),
  'string_trim': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.stringTrim(i['s'] as String? ?? '')),
  'select_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectString(i['a'] as String? ?? '', i['b'] as String? ?? '', i['pick_a'] as bool? ?? false)),
  'select_bool': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectBool(i['a'] as bool? ?? false, i['b'] as bool? ?? false, i['pick_a'] as bool? ?? false)),
  'select_object': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.selectObject(i['a'], i['b'], i['pick_a'] as bool? ?? false)),
  'array_length': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayLength(i['target_array'])),
  'array_get': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayGet(i['target_array'], LuminaBlueprintFunctionLibrary._n(i['index'], 0))),
  'array_last_index': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayLastIndex(i['target_array'])),
  'array_is_empty': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayIsEmpty(i['target_array'])),
  'array_contains': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayContains(i['target_array'], i['item_to_find'])),
  'array_find': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayFind(i['target_array'], i['item_to_find'])),
  'array_first': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayFirst(i['target_array'])),
  'array_last': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayLast(i['target_array'])),
  'make_array': (c, i) {
    final items = <Object?>[];
    for (var n = 0; i.containsKey('item_$n'); n++) {
      items.add(i['item_$n']);
    }
    return LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeArray(items));
  },
  'array_add': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayAdd(i['target_array'], i['new_item'])),
  'array_remove_index': (c, i) {
    LuminaBlueprintFunctionLibrary.arrayRemoveIndex(i['target_array'], LuminaBlueprintFunctionLibrary._n(i['index'], 0));
    return const {};
  },
  'array_clear': (c, i) {
    LuminaBlueprintFunctionLibrary.arrayClear(i['target_array']);
    return const {};
  },
  'array_set': (c, i) {
    LuminaBlueprintFunctionLibrary.arraySet(i['target_array'], LuminaBlueprintFunctionLibrary._n(i['index'], 0), i['item'], i['size_to_fit'] as bool? ?? false);
    return const {};
  },
  'array_filter_by_class': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.arrayFilterByClass(i['target_array'], i['class'] as String? ?? '')),
  'array_shuffle': (c, i) {
    LuminaBlueprintFunctionLibrary.arrayShuffle(i['target_array']);
    return const {};
  },
  'make_hit_result': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.makeHitResult(i['blocking_hit'] as bool? ?? false, _vec3(i['location']), _vec3(i['impact_point']),
      _vec3(i['impact_normal'], Vector3(0, 0, 1)), LuminaBlueprintFunctionLibrary._d(i['distance'], 0), i['hit_actor'], i['hit_component'])),
  'break_hit_result': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.breakHitResult(i['hit']);
    return {
      'blocking_hit': r.blockingHit,
      'location': r.location,
      'impact_point': r.impactPoint,
      'normal': r.normal,
      'impact_normal': r.impactNormal,
      'time': r.time,
      'distance': r.distance,
      'trace_start': r.traceStart,
      'trace_end': r.traceEnd,
      'hit_actor': r.hitActor,
      'hit_component': r.hitComponent,
    };
  },
};

/// Engine, traces, view, camera, actor.
final Map<String, LuminaBlueprintFunction> _engineFunctions = <String, LuminaBlueprintFunction>{
  // --- engine, traces, view, camera, actor ------------------
  'get_frame_rate': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getFrameRate(c.self)),
  'get_frame_time_ms': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getFrameTimeMs(c.self)),
  'get_frame_number': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getFrameNumber(c.self)),
  'get_world_delta_seconds': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWorldDeltaSeconds(c.self)),
  'get_game_time_in_seconds': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getGameTimeInSeconds(c.self)),
  'get_real_time_seconds': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getRealTimeSeconds(c.self)),
  'get_actor_count': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorCount(c.self)),
  'get_time_dilation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTimeDilation(c.self)),
  'set_time_dilation': (c, i) {
    LuminaBlueprintFunctionLibrary.setTimeDilation(c.self, LuminaBlueprintFunctionLibrary._d(i['time_dilation'], 1.0));
    return const {};
  },
  'get_platform_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPlatformName()),
  'is_editor': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isEditor()),
  'quit_game': (c, i) {
    LuminaBlueprintFunctionLibrary.quitGame(c.self);
    return const {};
  },
  'line_trace_by_channel': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.lineTraceByChannel(c.self, _vec3(i['start']), _vec3(i['end']), i['channel'] as String? ?? 'Visibility', i['actors_to_ignore'],
        i['draw_debug'] as bool? ?? false);
    return {'out_hit': r.outHit, 'return_value': r.returnValue};
  },
  'line_trace_forward': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.lineTraceForward(c.self, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0), i['channel'] as String? ?? 'Visibility', i['draw_debug'] as bool? ?? false);
    return {'out_hit': r.outHit, 'return_value': r.returnValue};
  },
  'multi_line_trace_by_channel': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.multiLineTraceByChannel(c.self, _vec3(i['start']), _vec3(i['end']), i['channel'] as String? ?? 'Visibility',
        i['actors_to_ignore'], i['draw_debug'] as bool? ?? false);
    return {'out_hits': r.outHits, 'return_value': r.returnValue};
  },
  'multi_line_trace_forward': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.multiLineTraceForward(c.self, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0), i['channel'] as String? ?? 'Visibility', i['draw_debug'] as bool? ?? false);
    return {'out_hits': r.outHits, 'return_value': r.returnValue};
  },
  'sphere_trace_by_channel': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.sphereTraceByChannel(c.self, _vec3(i['start']), _vec3(i['end']), LuminaBlueprintFunctionLibrary._d(i['radius'], 50.0), i['channel'] as String? ?? 'Visibility',
        i['actors_to_ignore'], i['draw_debug'] as bool? ?? false);
    return {'out_hit': r.outHit, 'return_value': r.returnValue};
  },
  'sphere_trace_forward': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.sphereTraceForward(c.self, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0), LuminaBlueprintFunctionLibrary._d(i['radius'], 50.0), i['channel'] as String? ?? 'Visibility',
        i['draw_debug'] as bool? ?? false);
    return {'out_hit': r.outHit, 'return_value': r.returnValue};
  },
  'sphere_overlap_actors': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.sphereOverlapActors(c.self, _vec3(i['location']), LuminaBlueprintFunctionLibrary._d(i['radius'], 100.0), i['class'] as String? ?? '', i['actors_to_ignore'])),
  'get_look_forward_direction': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getLookForwardDirection(c.self)),
  'get_actor_eyes_view_point': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(c.self);
    return {'location': r.location, 'rotation': r.rotation};
  },
  'find_look_at_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.findLookAtLocation(c.self, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0))),
  'get_all_actors_of_class': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAllActorsOfClass(c.self, i['class'] as String? ?? LuminaBlueprintObjectClass.anyActor)),
  'get_level_actor': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getLevelActor(c.self, i['actor'] as String? ?? '')),
  'get_level_actors_of_class': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getLevelActorsOfClass(c.self, i['class'] as String? ?? LuminaBlueprintObjectClass.anyActor)),
  'get_all_actors_with_tag': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAllActorsWithTag(c.self, i['tag'] as String? ?? '')),
  'get_actors_within_radius': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorsWithinRadius(
      c.self, _vec3(i['location']), LuminaBlueprintFunctionLibrary._d(i['radius'], 500.0), i['class'] as String? ?? LuminaBlueprintObjectClass.anyActor)),
  'get_actors_in_view_cone': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorsInViewCone(
      c.self, i['class'] as String? ?? LuminaBlueprintObjectClass.anyActor, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0), LuminaBlueprintFunctionLibrary._d(i['cone_angle'], 45.0))),
  'get_closest_actor_of_class_in_direction': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getClosestActorOfClassInDirection(
      c.self, i['class'] as String? ?? LuminaBlueprintObjectClass.anyActor, LuminaBlueprintFunctionLibrary._d(i['distance'], 1000.0), LuminaBlueprintFunctionLibrary._d(i['cone_angle'], 45.0))),
  'set_view_target': (c, i) {
    LuminaBlueprintFunctionLibrary.setViewTarget(c.self, i['target']);
    return const {};
  },
  'set_view_target_with_blend': (c, i) {
    LuminaBlueprintFunctionLibrary.setViewTargetWithBlend(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['blend_time'], 0.0), i['blend_func'] as String? ?? 'Linear', LuminaBlueprintFunctionLibrary._d(i['blend_exp'], 2.0));
    return const {};
  },
  'get_view_target': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getViewTarget(c.self)),
  'get_player_camera_manager': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getPlayerCameraManager(c.self)),
  'get_active_camera': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActiveCamera(c.self)),
  'set_active_camera': (c, i) {
    LuminaBlueprintFunctionLibrary.setCameraActive(i['target'], i['active'] as bool? ?? true);
    return const {};
  },
  'get_camera_location': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCameraLocation(c.self)),
  'get_camera_rotation': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getCameraRotation(c.self)),
  'spawn_actor_from_class': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.spawnActorFromClass(c.self, i['class'] as String? ?? '', i['spawn_transform'], i['collision_handling'] as String? ?? 'Default')),
  'destroy_actor': (c, i) {
    LuminaBlueprintFunctionLibrary.destroyActor(c.self, i['target']);
    return const {};
  },
  'set_life_span': (c, i) {
    LuminaBlueprintFunctionLibrary.setLifeSpan(c.self, i['target'], LuminaBlueprintFunctionLibrary._d(i['in_life_span'], 0.0));
    return const {};
  },
  'get_actor_transform': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorTransform(c.self, i['target'])),
  'set_actor_transform': (c, i) {
    LuminaBlueprintFunctionLibrary.setActorTransform(c.self, i['target'], i['new_transform']);
    return const {};
  },
  'set_actor_rotation': (c, i) {
    LuminaBlueprintFunctionLibrary.setActorRotation(c.self, i['target'], _rot3(i['new_rotation']));
    return const {};
  },
  'set_actor_scale_3d': (c, i) {
    LuminaBlueprintFunctionLibrary.setActorScale3D(c.self, i['target'], _vec3(i['new_scale_3d'], Vector3(1, 1, 1)));
    return const {};
  },
  'get_actor_scale_3d': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorScale3D(c.self, i['target'])),
  'set_actor_hidden_in_game': (c, i) {
    LuminaBlueprintFunctionLibrary.setActorHiddenInGame(c.self, i['target'], i['new_hidden'] as bool? ?? true);
    return const {};
  },
  'is_hidden': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isHidden(c.self, i['target'])),
  'set_actor_enable_collision': (c, i) {
    LuminaBlueprintFunctionLibrary.setActorEnableCollision(c.self, i['target'], i['new_actor_enable_collision'] as bool? ?? true);
    return const {};
  },
  'get_actor_enable_collision': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorEnableCollision(c.self, i['target'])),
  'teleport': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.teleport(c.self, i['target'], _vec3(i['dest_location']), _rot3(i['dest_rotation']))),
  'get_actor_bounds': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.getActorBounds(c.self, i['target']);
    return {'origin': r.origin, 'box_extent': r.boxExtent};
  },
  'get_actor_forward_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorForwardVector(c.self, i['target'])),
  'get_actor_right_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorRightVector(c.self, i['target'])),
  'get_actor_up_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getActorUpVector(c.self, i['target'])),
  'attach_actor_to_component': (c, i) {
    LuminaBlueprintFunctionLibrary.attachActorToComponent(c.self, i['target'], i['parent'], i['socket_name'] as String? ?? '');
    return const {};
  },
  'detach_from_actor': (c, i) {
    LuminaBlueprintFunctionLibrary.detachFromActor(c.self, i['target']);
    return const {};
  },
  'get_attach_parent_actor': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getAttachParentActor(c.self, i['target'])),
  'get_owner': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getOwner(c.self, i['target'])),
  'set_owner': (c, i) {
    LuminaBlueprintFunctionLibrary.setOwner(c.self, i['target'], i['new_owner']);
    return const {};
  },
  'get_instigator': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getInstigator(c.self, i['target'])),
  'actor_has_tag': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.actorHasTag(c.self, i['target'], i['tag'] as String? ?? '')),
  'add_tag': (c, i) {
    LuminaBlueprintFunctionLibrary.addTag(c.self, i['target'], i['tag'] as String? ?? '');
    return const {};
  },
  'remove_tag': (c, i) {
    LuminaBlueprintFunctionLibrary.removeTag(c.self, i['target'], i['tag'] as String? ?? '');
    return const {};
  },
  'get_distance_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getDistanceTo(c.self, i['target'], i['other_actor'])),
  'get_horizontal_distance_to': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getHorizontalDistanceTo(c.self, i['target'], i['other_actor'])),
  'is_actor_being_destroyed': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isActorBeingDestroyed(c.self, i['target'])),
  'apply_damage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.applyDamage(c.self, i['damaged_actor'], LuminaBlueprintFunctionLibrary._d(i['base_damage'], 0.0), i['event_instigator'], i['damage_causer'],
      i['damage_type_class'] as String? ?? '')),
  'apply_point_damage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.applyPointDamage(c.self, i['damaged_actor'], LuminaBlueprintFunctionLibrary._d(i['base_damage'], 0.0), _vec3(i['hit_from_direction']),
      i['hit_info'], i['event_instigator'], i['damage_causer'], i['damage_type_class'] as String? ?? '')),
  'apply_radial_damage': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.applyRadialDamage(c.self, LuminaBlueprintFunctionLibrary._d(i['base_damage'], 0.0), _vec3(i['origin']), LuminaBlueprintFunctionLibrary._d(i['damage_radius'], 0.0),
      i['damage_type_class'] as String? ?? '', i['ignore_actors'], i['damage_causer'], i['instigated_by'], i['do_full_damage'] as bool? ?? false)),
};

/// Custom events, functions, dispatchers, interfaces, enums,
/// timers.
final Map<String, LuminaBlueprintFunction> _graphMemberFunctions = <String, LuminaBlueprintFunction>{
  // --- custom events, functions, dispatchers, interfaces, enums, timers --
  'call_custom_event': (c, i) {
    LuminaBlueprintFunctionLibrary.callCustomEvent(c.self, i['event'] as String? ?? '', LuminaBlueprintFunctionLibrary.signatureArgs(i, const {'event', 'target', 'class'}), i['target']);
    return const {};
  },
  'call_function': (c, i) => LuminaBlueprintFunctionLibrary.callFunction(c.self, i['function'] as String? ?? '', LuminaBlueprintFunctionLibrary.signatureArgs(i, const {'function'})),
  'call_function_pure': (c, i) => LuminaBlueprintFunctionLibrary.callFunction(c.self, i['function'] as String? ?? '', LuminaBlueprintFunctionLibrary.signatureArgs(i, const {'function'})),
  'call_dispatcher': (c, i) {
    LuminaBlueprintFunctionLibrary.callDispatcher(c.self, i['dispatcher'] as String? ?? '', LuminaBlueprintFunctionLibrary.signatureArgs(i, const {'dispatcher'}));
    return const {};
  },
  'bind_event_to_dispatcher': (c, i) {
    LuminaBlueprintFunctionLibrary.bindEventToDispatcher(c.self, i['target'], i['dispatcher'] as String? ?? '', i['event']);
    return const {};
  },
  'unbind_event_from_dispatcher': (c, i) {
    LuminaBlueprintFunctionLibrary.unbindEventFromDispatcher(c.self, i['target'], i['dispatcher'] as String? ?? '', i['event']);
    return const {};
  },
  'unbind_all_events': (c, i) {
    LuminaBlueprintFunctionLibrary.unbindAllEvents(c.self, i['target'], i['dispatcher'] as String? ?? '');
    return const {};
  },
  'interface_message': (c, i) => LuminaBlueprintFunctionLibrary.interfaceMessage(c.self, i['target'], i['interface'] as String? ?? '', i['function'] as String? ?? '',
      LuminaBlueprintFunctionLibrary.signatureArgs(i, const {'target', 'interface', 'function'})),
  'implements_interface': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.implementsInterface(i['target'] ?? c.self, i['interface'] as String? ?? '')),
  'enum_literal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.enumLiteral(i['enum'] as String? ?? '', i['value'] as String? ?? '')),
  'enum_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.enumToString(i['value'] as String? ?? '')),
  'enum_to_int': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.enumToInt(i['enum'] as String? ?? '', i['value'] as String? ?? '')),
  'int_to_enum': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.intToEnum(i['enum'] as String? ?? '', LuminaBlueprintFunctionLibrary._n(i['value'], 0))),
  'enum_equal': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.enumEqual(i['a'] as String? ?? '', i['b'] as String? ?? '')),
  'get_enum_value_count': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getEnumValueCount(i['enum'] as String? ?? '')),
  'set_timer_by_event': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.setTimerByEvent(c.self, i['event'], LuminaBlueprintFunctionLibrary._d(i['time'], 0.0), i['looping'] as bool? ?? false, LuminaBlueprintFunctionLibrary._d(i['initial_start_delay'], -1.0))),
  'set_timer_by_function_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.setTimerByFunctionName(
      c.self, i['function_name'] as String? ?? '', LuminaBlueprintFunctionLibrary._d(i['time'], 0.0), i['looping'] as bool? ?? false, LuminaBlueprintFunctionLibrary._d(i['initial_start_delay'], -1.0))),
  'set_timer_for_next_tick': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.setTimerForNextTick(c.self, i['event'])),
  'clear_timer_by_handle': (c, i) {
    LuminaBlueprintFunctionLibrary.clearTimerByHandle(c.self, i['handle']);
    return const {};
  },
  'clear_and_invalidate_timer': (c, i) {
    LuminaBlueprintFunctionLibrary.clearAndInvalidateTimer(c.self, i['handle']);
    return const {};
  },
  'pause_timer': (c, i) {
    LuminaBlueprintFunctionLibrary.pauseTimer(c.self, i['handle']);
    return const {};
  },
  'unpause_timer': (c, i) {
    LuminaBlueprintFunctionLibrary.unpauseTimer(c.self, i['handle']);
    return const {};
  },
  'is_timer_active': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isTimerActive(c.self, i['handle'])),
  'is_timer_paused': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isTimerPaused(c.self, i['handle'])),
  'get_timer_remaining_time': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTimerRemainingTime(c.self, i['handle'])),
  'get_timer_elapsed_time': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getTimerElapsedTime(c.self, i['handle'])),
};
