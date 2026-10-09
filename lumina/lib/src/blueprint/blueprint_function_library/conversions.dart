part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the Math|Conversions nodes.
const Map<String, LuminaBlueprintCallShape> _conversionCallShapes = <String, LuminaBlueprintCallShape>{
  'int_to_float': LuminaBlueprintCallShape('intToFloat', ['a'], outputs: LuminaBlueprintFunctionLibrary._r),
  'round': LuminaBlueprintCallShape('round', ['a'], outputs: LuminaBlueprintFunctionLibrary._r),
  'truncate': LuminaBlueprintCallShape('truncate', ['a'], outputs: LuminaBlueprintFunctionLibrary._r),
  'floor': LuminaBlueprintCallShape('floor', ['a'], outputs: LuminaBlueprintFunctionLibrary._r),
  'ceil': LuminaBlueprintCallShape('ceil', ['a'], outputs: LuminaBlueprintFunctionLibrary._r),
  'bool_to_int': LuminaBlueprintCallShape('boolToInt', ['in_bool'], outputs: LuminaBlueprintFunctionLibrary._r),
  'int_to_bool': LuminaBlueprintCallShape('intToBool', ['in_int'], outputs: LuminaBlueprintFunctionLibrary._r),
  'bool_to_float': LuminaBlueprintCallShape('boolToFloat', ['in_bool'], outputs: LuminaBlueprintFunctionLibrary._r),
  'int_to_string': LuminaBlueprintCallShape('intToString', ['in_int'], outputs: LuminaBlueprintFunctionLibrary._r),
  'float_to_string':
      LuminaBlueprintCallShape('floatToString', ['in_float', 'decimals'], outputs: LuminaBlueprintFunctionLibrary._r),
  'bool_to_string': LuminaBlueprintCallShape('boolToString', ['in_bool'], outputs: LuminaBlueprintFunctionLibrary._r),
  'name_to_string': LuminaBlueprintCallShape('nameToString', ['in_name'], outputs: LuminaBlueprintFunctionLibrary._r),
  'string_to_name': LuminaBlueprintCallShape('stringToName', ['in_string'], outputs: LuminaBlueprintFunctionLibrary._r),
  'string_to_int': LuminaBlueprintCallShape('stringToIntChecked', ['in_string'], outputs: ['return_value', 'success']),
  'string_to_float': LuminaBlueprintCallShape('stringToFloatChecked', ['in_string'], outputs: ['return_value', 'success']),
  'float_to_vector': LuminaBlueprintCallShape('floatToVector', ['in_float'], outputs: LuminaBlueprintFunctionLibrary._r),
  'float_to_vector2d': LuminaBlueprintCallShape('floatToVector2D', ['in_float'], outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the Math|Conversions
/// nodes.
final Map<String, LuminaBlueprintFunction> _conversionFunctions = <String, LuminaBlueprintFunction>{
  'int_to_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(_intToFloat(LuminaBlueprintFunctionLibrary._n(i['a'], 0))),
  'round': (c, i) => LuminaBlueprintFunctionLibrary._ret(_round(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'truncate': (c, i) => LuminaBlueprintFunctionLibrary._ret(_truncate(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'floor': (c, i) => LuminaBlueprintFunctionLibrary._ret(_floor(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'ceil': (c, i) => LuminaBlueprintFunctionLibrary._ret(_ceil(LuminaBlueprintFunctionLibrary._d(i['a'], 0))),
  'bool_to_int': (c, i) => LuminaBlueprintFunctionLibrary._ret(_boolToInt(i['in_bool'] as bool? ?? false)),
  'int_to_bool': (c, i) => LuminaBlueprintFunctionLibrary._ret(_intToBool(LuminaBlueprintFunctionLibrary._n(i['in_int'], 0))),
  'bool_to_float': (c, i) => LuminaBlueprintFunctionLibrary._ret(_boolToFloat(i['in_bool'] as bool? ?? false)),
  'int_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(_intToString(LuminaBlueprintFunctionLibrary._n(i['in_int'], 0))),
  'float_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(
      _floatToString(LuminaBlueprintFunctionLibrary._d(i['in_float'], 0), LuminaBlueprintFunctionLibrary._n(i['decimals'], 2))),
  'bool_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(_boolToString(i['in_bool'] as bool? ?? false)),
  'name_to_string': (c, i) => LuminaBlueprintFunctionLibrary._ret(_nameToString(i['in_name']?.toString() ?? '')),
  'string_to_name': (c, i) => LuminaBlueprintFunctionLibrary._ret(_stringToName(i['in_string']?.toString() ?? '')),
  'string_to_int': (c, i) {
    final r = _stringToIntChecked(i['in_string']?.toString() ?? '');
    return {'return_value': r.returnValue, 'success': r.success};
  },
  'string_to_float': (c, i) {
    final r = _stringToFloatChecked(i['in_string']?.toString() ?? '');
    return {'return_value': r.returnValue, 'success': r.success};
  },
  'float_to_vector': (c, i) => LuminaBlueprintFunctionLibrary._ret(_floatToVector(LuminaBlueprintFunctionLibrary._d(i['in_float'], 0))),
  'float_to_vector2d': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_floatToVector2D(LuminaBlueprintFunctionLibrary._d(i['in_float'], 0))),
};

// --- float → integer ----------------------------------------------------------

/// Whether ints are JavaScript numbers (the web): no 64-bit range there.
const bool _jsNumbers = identical(0, 0.0);

/// The largest integer a float → integer conversion gives: 2⁶³ − 1, or
/// 2⁵³ − 1 on the web.
final int _maxConvertedInt = _jsNumbers ? 9007199254740991 : 1e300.toInt();
final int _minConvertedInt = _jsNumbers ? -9007199254740991 : (-1e300).toInt();

/// An already-rounded [v] as an integer: NaN → 0; ±infinity and values
/// beyond the integer range saturate.
int _saturatingInt(double v) {
  if (v.isNaN) return 0;
  if (v >= _maxConvertedInt.toDouble()) return _maxConvertedInt;
  if (v <= _minConvertedInt.toDouble()) return _minConvertedInt;
  return v.toInt();
}

/// Rounds half away from zero (2.5 → 3, -2.5 → -3).
int _round(double a) => _saturatingInt(a.isFinite ? a.roundToDouble() : a);

/// Toward zero (-2.7 → -2).
int _truncate(double a) => _saturatingInt(a.isFinite ? a.truncateToDouble() : a);

/// Toward −∞ (-2.1 → -3).
int _floor(double a) => _saturatingInt(a.isFinite ? a.floorToDouble() : a);

/// Toward +∞ (2.1 → 3).
int _ceil(double a) => _saturatingInt(a.isFinite ? a.ceilToDouble() : a);

double _intToFloat(int a) => a.toDouble();

// --- bool ↔ number ----------------------------------------------------------------

int _boolToInt(bool inBool) => inBool ? 1 : 0;

/// Any non-zero integer is true.
bool _intToBool(int inInt) => inInt != 0;

double _boolToFloat(bool inBool) => inBool ? 1.0 : 0.0;

// --- string ------------------------------------------------------------------------

/// [decimals] clamps to 0–20; NaN and infinities print as `NaN`, `Infinity`.
String _floatToString(double inFloat, [int decimals = 2]) =>
    inFloat.isFinite ? inFloat.toStringAsFixed(decimals < 0 ? 0 : (decimals > 20 ? 20 : decimals)) : '$inFloat';

String _intToString(int inInt) => '$inInt';

String _boolToString(bool inBool) => inBool ? 'true' : 'false';

String _nameToString(String inName) => inName;

String _stringToName(String inString) => inString;

/// An integer (optional sign) or, failing that, a finite decimal / exponent
/// number truncated toward zero; whitespace around it is ignored. Anything
/// else gives 0 and Success false.
({int returnValue, bool success}) _stringToIntChecked(String inString) {
  final s = inString.trim();
  final i = int.tryParse(s);
  if (i != null) return (returnValue: i, success: true);
  final d = double.tryParse(s);
  if (d == null || !d.isFinite) return (returnValue: 0, success: false);
  return (returnValue: _truncate(d), success: true);
}

/// Any finite number, whitespace around it ignored; anything else (including
/// `NaN` and `Infinity`) gives 0.0 and Success false.
({double returnValue, bool success}) _stringToFloatChecked(String inString) {
  final d = double.tryParse(inString.trim());
  if (d == null || !d.isFinite) return (returnValue: 0.0, success: false);
  return (returnValue: d, success: true);
}

/// String to Int without its Success output.
int _stringToInt(String inString) => _stringToIntChecked(inString).returnValue;

/// String to Float without its Success output.
double _stringToFloat(String inString) => _stringToFloatChecked(inString).returnValue;

// --- float → vector ---------------------------------------------------------------

/// (f, f, f).
Vector3 _floatToVector(double inFloat) => Vector3.all(inFloat);

/// (f, f).
Vector2 _floatToVector2D(double inFloat) => Vector2.all(inFloat);
