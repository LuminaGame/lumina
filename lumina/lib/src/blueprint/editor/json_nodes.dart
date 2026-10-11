import 'dart:convert';

import 'package:lumina/src/blueprint/blueprint_function_registry.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/node_library.dart';

/// The `Json` value nodes editor panel graphs use to build and read the
/// structured data they pass to a plugin process (`Call Plugin Process`) and
/// receive from it (`On Plugin Process Event`). Values stay JSON-plain:
/// maps, lists, strings, numbers, bools and null. VM only and editor-only
/// (editor panels are never compiled to Dart).
abstract final class LuminaJsonBlueprintNodes {
  static const String makeObject = 'json_make_object';
  static const String makeArray = 'json_make_array';
  static const String getString = 'json_get_string';
  static const String getNumber = 'json_get_number';
  static const String getBool = 'json_get_bool';
  static const String getJson = 'json_get_json';
  static const String getArray = 'json_get_array';
  static const String setField = 'json_set_field';
  static const String hasField = 'json_has_field';
  static const String parse = 'json_parse';
  static const String toText = 'json_to_string';

  static const String category = 'Utilities|Json';
  static const int _pure = 0xFF2E7D32;
  static const int _function = 0xFF1565C0;

  static const LuminaBlueprintPinSpec _json = LuminaBlueprintPinSpec('json', 'Json', LuminaPinType.json);
  static const LuminaBlueprintPinSpec _field = LuminaBlueprintPinSpec('field', 'Field', LuminaPinType.string, defaultValue: '');
  static const LuminaBlueprintPinSpec _found = LuminaBlueprintPinSpec('found', 'Found', LuminaPinType.boolean, defaultValue: false);

  static LuminaBlueprintPinSpec _ret(LuminaPinType type, {LuminaPinType? elementType}) =>
      LuminaBlueprintPinSpec('return_value', 'Return Value', type, elementType: elementType);

  static LuminaBlueprintNodeSpec _spec(String id, String title, List<LuminaBlueprintPinSpec> inputs,
          List<LuminaBlueprintPinSpec> outputs, {LuminaBlueprintNodeKind kind = LuminaBlueprintNodeKind.pure, String? tooltip}) =>
      LuminaBlueprintNodeSpec(
        id: id,
        title: title,
        category: category,
        kind: kind,
        headerColor: kind == LuminaBlueprintNodeKind.pure ? _pure : _function,
        inputs: inputs,
        outputs: outputs,
        keywords: const ['json', 'data', 'object', 'map', 'structured'],
        tooltip: tooltip,
        editorOnly: true,
      );

  /// Every Json node's spec.
  static final List<LuminaBlueprintNodeSpec> specs = [
    _spec(makeObject, 'Make Json Object', const [
      LuminaBlueprintPinSpec('keys', 'Keys', LuminaPinType.array, elementType: LuminaPinType.string),
      LuminaBlueprintPinSpec('values', 'Values', LuminaPinType.array, elementType: LuminaPinType.wildcard),
    ], [
      _ret(LuminaPinType.json)
    ], tooltip: 'A Json object of Keys[i] → Values[i].'),
    _spec(makeArray, 'Make Json Array', const [
      LuminaBlueprintPinSpec('items', 'Items', LuminaPinType.array, elementType: LuminaPinType.wildcard),
    ], [
      _ret(LuminaPinType.json)
    ]),
    _spec(getString, 'Json Get String', const [_json, _field], [_ret(LuminaPinType.string), _found]),
    _spec(getNumber, 'Json Get Number', const [_json, _field], [_ret(LuminaPinType.float), _found]),
    _spec(getBool, 'Json Get Bool', const [_json, _field], [_ret(LuminaPinType.boolean), _found]),
    _spec(getJson, 'Json Get Json', const [_json, _field], [_ret(LuminaPinType.json), _found]),
    _spec(getArray, 'Json Get Array', const [_json, _field],
        [_ret(LuminaPinType.array, elementType: LuminaPinType.json), _found]),
    _spec(setField, 'Json Set Field', const [
      _json,
      _field,
      LuminaBlueprintPinSpec('value', 'Value', LuminaPinType.wildcard),
    ], [
      _ret(LuminaPinType.json)
    ], tooltip: 'A copy of the object with Field set to Value.'),
    _spec(hasField, 'Json Has Field', const [_json, _field], [_ret(LuminaPinType.boolean)]),
    _spec(
        parse,
        'Parse Json',
        const [
          LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
          LuminaBlueprintPinSpec('text', 'Text', LuminaPinType.string, defaultValue: ''),
        ],
        const [
          LuminaBlueprintPinSpec('exec_out', 'Parsed', LuminaPinType.exec),
          LuminaBlueprintPinSpec('failed', 'Failed', LuminaPinType.exec),
          LuminaBlueprintPinSpec('json', 'Json', LuminaPinType.json),
          LuminaBlueprintPinSpec('error', 'Error', LuminaPinType.string, defaultValue: ''),
        ],
        kind: LuminaBlueprintNodeKind.impure,
        tooltip: 'Parses Text; invalid text takes the Failed branch with the parse error.'),
    _spec(toText, 'Json To String', const [
      _json,
      LuminaBlueprintPinSpec('pretty', 'Pretty', LuminaPinType.boolean, defaultValue: false),
    ], [
      _ret(LuminaPinType.string)
    ]),
  ];

  /// Registers the Json nodes in [LuminaBlueprintFunctionRegistry] (once;
  /// again after the registry was cleared).
  static void ensureRegistered() {
    for (final spec in specs) {
      if (LuminaBlueprintFunctionRegistry.entry(spec.id) != null) continue;
      LuminaBlueprintFunctionRegistry.register(spec, (_, inputs) => _run(spec.id, inputs));
    }
  }

  /// [value] as a JSON-plain value: maps with string keys, lists, strings,
  /// numbers, bools, null (anything else as its string).
  static Object? plain(Object? value) {
    if (value == null || value is String || value is num || value is bool) return value;
    if (value is Map) return {for (final e in value.entries) '${e.key}': plain(e.value)};
    if (value is Iterable) return [for (final v in value) plain(v)];
    return '$value';
  }

  static Map<String, Object?> _ret1(Object? v) => {'return_value': v};

  static Map<String, Object?> _run(String id, Map<String, Object?> inputs) {
    Object? field(Object? json, String name) => json is Map ? json[name] : null;
    final json = inputs['json'];
    final name = '${inputs['field'] ?? ''}';
    final has = json is Map && json.containsKey(name);
    switch (id) {
      case makeObject:
        final keys = inputs['keys'] is List ? inputs['keys'] as List : const [];
        final values = inputs['values'] is List ? inputs['values'] as List : const [];
        return _ret1(<String, Object?>{
          for (var i = 0; i < keys.length; i++) '${keys[i]}': i < values.length ? plain(values[i]) : null,
        });
      case makeArray:
        return _ret1(plain(inputs['items'] is List ? inputs['items'] : const []));
      case getString:
        final v = field(json, name);
        return {'return_value': v == null ? '' : (v is String ? v : jsonEncode(v)), 'found': has};
      case getNumber:
        final v = field(json, name);
        return {'return_value': v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0.0 : 0.0), 'found': has};
      case getBool:
        final v = field(json, name);
        return {'return_value': v is bool ? v : (v is num ? v != 0 : v == 'true'), 'found': has};
      case getJson:
        return {'return_value': plain(field(json, name)), 'found': has};
      case getArray:
        final v = field(json, name);
        return {'return_value': v is List ? plain(v) : <Object?>[], 'found': has};
      case setField:
        final copy = json is Map ? <String, Object?>{for (final e in json.entries) '${e.key}': e.value} : <String, Object?>{};
        copy[name] = plain(inputs['value']);
        return _ret1(copy);
      case hasField:
        return _ret1(has);
      case parse:
        try {
          return {'json': plain(jsonDecode('${inputs['text'] ?? ''}')), 'error': ''};
        } on FormatException catch (e) {
          return {'json': null, 'error': e.message, LuminaBlueprintFunctionRegistry.execPinKey: 'failed'};
        }
      case toText:
        final value = plain(json);
        return _ret1(inputs['pretty'] == true ? const JsonEncoder.withIndent('  ').convert(value) : jsonEncode(value));
    }
    return const {};
  }
}
