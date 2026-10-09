part of '../node_library.dart';

/// The node the editor puts between two pins of different types so a wire
/// can join them (an integer output into a float input gets To Float
/// (Integer)): [LuminaBlueprintNodeLibrary.conversionNodeFor].
class LuminaBlueprintConversion {
  /// The library node: `int_to_float`, `truncate`, …
  final String nodeId;

  /// The node's input pin the source output is wired into.
  final String inputPin;

  /// The node's output pin wired into the target input.
  final String outputPin;

  /// Whether the conversion can lose information (float → integer drops the
  /// fraction).
  final bool lossy;

  /// One line for the editor: what the conversion does.
  final String hint;

  const LuminaBlueprintConversion(this.nodeId, this.inputPin, {this.outputPin = _returnValue, this.lossy = false, required this.hint});
}

/// The conversions the editor inserts on its own, by (from, to). Pairs that
/// need a choice the author should make (string → number can fail, float →
/// bool has no single meaning, a vector has no single float) are absent.
const Map<(LuminaPinType, LuminaPinType), LuminaBlueprintConversion> _autoConversions = {
  (LuminaPinType.integer, LuminaPinType.float):
      LuminaBlueprintConversion('int_to_float', 'a', hint: 'To Float (Integer): the same number as a float'),
  (LuminaPinType.float, LuminaPinType.integer): LuminaBlueprintConversion('truncate', 'a',
      lossy: true, hint: 'Truncate drops the fraction (2.7 → 2, -2.7 → -2); use Round, Floor or Ceil to round instead'),
  (LuminaPinType.boolean, LuminaPinType.integer):
      LuminaBlueprintConversion('bool_to_int', 'in_bool', hint: 'To Integer (Bool): true → 1, false → 0'),
  (LuminaPinType.boolean, LuminaPinType.float):
      LuminaBlueprintConversion('bool_to_float', 'in_bool', hint: 'To Float (Bool): true → 1.0, false → 0.0'),
  (LuminaPinType.integer, LuminaPinType.string):
      LuminaBlueprintConversion('int_to_string', 'in_int', hint: 'To String (int)'),
  (LuminaPinType.float, LuminaPinType.string):
      LuminaBlueprintConversion('float_to_string', 'in_float', hint: 'To String (float), 2 decimals by default'),
  (LuminaPinType.boolean, LuminaPinType.string):
      LuminaBlueprintConversion('bool_to_string', 'in_bool', hint: 'To String (bool): "true" / "false"'),
  (LuminaPinType.name, LuminaPinType.string):
      LuminaBlueprintConversion('name_to_string', 'in_name', hint: 'To String (Name)'),
  (LuminaPinType.vector, LuminaPinType.string):
      LuminaBlueprintConversion('vector_to_string', 'in_vec', hint: 'To String (Vector): "X=… Y=… Z=…"'),
  (LuminaPinType.rotator, LuminaPinType.string):
      LuminaBlueprintConversion('rotator_to_string', 'in_rot', hint: 'To String (Rotator): "P=… Y=… R=…"'),
  (LuminaPinType.string, LuminaPinType.name):
      LuminaBlueprintConversion('string_to_name', 'in_string', hint: 'To Name (String)'),
};

LuminaBlueprintConversion? _conversionNodeFor(LuminaPinType from, LuminaPinType to) => _autoConversions[(from, to)];

const String _conversions = 'Math|Conversions';

/// A conversion node: one input, one output, the shared keywords.
LuminaBlueprintNodeSpec _conversion(String id, String title, LuminaBlueprintPinSpec input, LuminaBlueprintPinSpec out,
        List<String> keywords, {List<LuminaBlueprintPinSpec> extraInputs = const [], List<LuminaBlueprintPinSpec> extraOutputs = const []}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: _conversions,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _math,
      keywords: ['convert', 'cast', 'to', 'conversion', ...keywords],
      inputs: [input, ...extraInputs],
      outputs: [out, ...extraOutputs],
    );

const List<String> _floatToInt = ['float to int', 'float to integer', 'to int', 'to integer', 'int', 'integer'];

/// Built-in nodes: conversions between the scalar pin types and from a float
/// to a vector. Float → integer: NaN gives 0, ±infinity and values beyond the
/// 64-bit range saturate (on the web ±(2⁵³ − 1)). String → number reports
/// Success; a failed parse gives 0.
final List<LuminaBlueprintNodeSpec> _conversionNodes = <LuminaBlueprintNodeSpec>[
  // --- integer ↔ float -------------------------------------------------------
  _conversion('int_to_float', 'To Float (Integer)', _i('a', 'A'), _ret(LuminaPinType.float),
      const ['int to float', 'integer to float', 'to float', 'float', 'int', 'integer', 'double']),
  _conversion('truncate', 'Truncate', _f('a', 'A'), _ret(LuminaPinType.integer),
      const [..._floatToInt, 'trunc', 'integer part', 'toward zero', 'drop fraction']),
  _conversion('round', 'Round', _f('a', 'A'), _ret(LuminaPinType.integer), const [..._floatToInt, 'round', 'nearest']),
  _conversion('floor', 'Floor', _f('a', 'A'), _ret(LuminaPinType.integer), const [..._floatToInt, 'round down']),
  _conversion('ceil', 'Ceil', _f('a', 'A'), _ret(LuminaPinType.integer), const [..._floatToInt, 'ceiling', 'round up']),
  // --- bool ↔ integer / float ---------------------------------------------------
  _conversion('bool_to_int', 'To Integer (Bool)', _b('in_bool', 'In Bool'), _ret(LuminaPinType.integer),
      const ['bool to int', 'bool to integer', 'to int', 'to integer', 'bool', 'boolean', 'int', 'integer']),
  _conversion('int_to_bool', 'To Bool (Integer)', _i('in_int', 'In Int'), _ret(LuminaPinType.boolean),
      const ['int to bool', 'integer to bool', 'to bool', 'non zero', 'bool', 'boolean', 'int', 'integer']),
  _conversion('bool_to_float', 'To Float (Bool)', _b('in_bool', 'In Bool'), _ret(LuminaPinType.float),
      const ['bool to float', 'to float', 'bool', 'boolean', 'float']),
  // --- to string -----------------------------------------------------------------
  _conversion('int_to_string', 'To String (int)', _i('in_int', 'In Int'), _ret(LuminaPinType.string),
      const ['int to string', 'integer to string', 'to string', 'string', 'text', 'int', 'integer', 'fps']),
  _conversion('float_to_string', 'To String (float)', _f('in_float', 'In Float'), _ret(LuminaPinType.string),
      const ['float to string', 'to string', 'string', 'text', 'float', 'precision', 'decimals', 'fps'],
      extraInputs: [_i('decimals', 'Decimals', 2)]),
  _conversion('bool_to_string', 'To String (bool)', _b('in_bool', 'In Bool'), _ret(LuminaPinType.string),
      const ['bool to string', 'to string', 'string', 'text', 'bool', 'boolean']),
  _conversion('name_to_string', 'To String (Name)', const LuminaBlueprintPinSpec('in_name', 'In Name', LuminaPinType.name, defaultValue: ''),
      _ret(LuminaPinType.string), const ['name to string', 'to string', 'string', 'text', 'name']),
  // --- from string -----------------------------------------------------------------
  _conversion('string_to_int', 'String to Int', _s('in_string', 'In String'), _ret(LuminaPinType.integer),
      const ['string to int', 'string to integer', 'to int', 'parse', 'number', 'int', 'integer', 'string'],
      extraOutputs: [_b('success', 'Success')]),
  _conversion('string_to_float', 'String to Float', _s('in_string', 'In String'), _ret(LuminaPinType.float),
      const ['string to float', 'to float', 'parse', 'number', 'float', 'string'],
      extraOutputs: [_b('success', 'Success')]),
  _conversion('string_to_name', 'To Name (String)', _s('in_string', 'In String'),
      const LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.name), const ['string to name', 'to name', 'name', 'string']),
  // --- float → vector ----------------------------------------------------------------
  _conversion('float_to_vector', 'To Vector (Float)', _f('in_float', 'In Float'), _ret(LuminaPinType.vector),
      const ['float to vector', 'to vector', 'vector', 'uniform', 'splat', 'float']),
  _conversion('float_to_vector2d', 'To Vector 2D (Float)', _f('in_float', 'In Float'), _ret(LuminaPinType.vector2D),
      const ['float to vector 2d', 'float to vector2d', 'to vector 2d', 'vector2d', 'vector 2d', 'uniform', 'float']),
];
