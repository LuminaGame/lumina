/// Reads the `.mat` language from Filament's source, where the material
/// documentation is incomplete or behind: the header keys matc registers
/// (`libs/filament-matp/src/ParametersProcessor.cpp`) with the values each one
/// accepts, the aliases kept for backward compatibility and the values matc
/// ignores with a deprecation warning; the type and precision tables of
/// filamat (`libs/filamat/src/Enums.cpp`); the `MaterialBuilder` comments of
/// the keys the documentation leaves out (`libs/filamat/include/filamat/
/// MaterialBuilder.h`); and the shader public API (`shaders/src`, see
/// `filament_shader_code.dart`). Pure Dart; the caller reads the files.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'filament_shader_code.dart';

export 'filament_shader_code.dart';

/// A header key as matc registers and validates it.
class MatcHeaderKey {
  final String name;

  /// matc's JSON type: `STRING`, `BOOL`, `NUMBER`, `ARRAY` or `OBJECT`.
  final String jsonType;

  /// The values matc accepts, in the order its table lists them; empty when
  /// any value of [jsonType] is accepted.
  final List<String> values;

  /// Values matc still accepts for backward compatibility → the value they
  /// stand for (`specularAmbientOcclusion : true` → `simple`).
  final Map<String, String> aliases;

  /// Values matc skips with a deprecation warning → that warning.
  final Map<String, String> ignored;

  /// The comment of the `MaterialBuilder` method the key sets; empty when the
  /// method has none.
  final String builderDoc;

  const MatcHeaderKey({
    required this.name,
    required this.jsonType,
    this.values = const [],
    this.aliases = const {},
    this.ignored = const {},
    this.builderDoc = '',
  });

  /// The documentation's wording of [jsonType].
  String get typeName => switch (jsonType) {
    'STRING' => 'string',
    'BOOL' => 'boolean',
    'NUMBER' => 'number',
    'ARRAY' => 'array',
    'OBJECT' => 'object',
    _ => jsonType.toLowerCase(),
  };
}

/// Everything the `.mat` tables take from Filament's source.
class FilamentMaterialCode {
  /// The header keys, in matc's registration order.
  final List<MatcHeaderKey> headerKeys;

  /// The values of each field of `blendFunction`.
  final List<String> blendFunctions;

  /// Parameter types (`UniformType` and `SamplerType` tables): name → the
  /// name it is an alias of, or itself.
  final Map<String, String> parameterTypes;
  final List<String> precisions;
  final List<String> constantTypes;

  /// The `MaterialInputs` / `MaterialVertexInputs` properties filamat knows.
  final List<String> properties;
  final List<ShaderApiFunction> functions;
  final List<CodeStructField> materialInputs;
  final List<CodeStructField> vertexInputs;

  const FilamentMaterialCode({
    required this.headerKeys,
    required this.blendFunctions,
    required this.parameterTypes,
    required this.precisions,
    required this.constantTypes,
    required this.properties,
    required this.functions,
    required this.materialInputs,
    required this.vertexInputs,
  });

  /// The files of a Filament checkout this reads, relative to its root.
  static const parametersProcessorPath = 'libs/filament-matp/src/ParametersProcessor.cpp';
  static const enumsPath = 'libs/filamat/src/Enums.cpp';
  static const builderHeaderPath = 'libs/filamat/include/filamat/MaterialBuilder.h';
  static const shadersPath = 'shaders/src';

  /// Whether [root] holds the files [read] needs.
  static bool existsIn(String root) =>
      File(p.join(root, parametersProcessorPath)).existsSync() && Directory(p.join(root, shadersPath)).existsSync();

  /// Reads a Filament checkout (a tool and its tests run this; synchronous).
  static FilamentMaterialCode read(String root) {
    final shaders = <String, String>{};
    for (final f in Directory(p.join(root, shadersPath)).listSync().whereType<File>()) {
      shaders[p.basename(f.path)] = f.readAsStringSync();
    }
    return parse(
      parametersProcessor: File(p.join(root, parametersProcessorPath)).readAsStringSync(),
      enums: File(p.join(root, enumsPath)).readAsStringSync(),
      builderHeader: File(p.join(root, builderHeaderPath)).readAsStringSync(),
      shaders: shaders,
    );
  }

  static FilamentMaterialCode parse({
    required String parametersProcessor,
    required String enums,
    required String builderHeader,
    required Map<String, String> shaders,
  }) {
    final processor = parametersProcessor.replaceAll('\r\n', '\n');
    final header = builderHeader.replaceAll('\r\n', '\n');
    final enumSource = enums.replaceAll('\r\n', '\n');
    final keys = <MatcHeaderKey>[];
    final registry = RegExp(r'mParameters\["(\w+)"\]\s*=\s*\{\s*&(\w+),\s*Type::(\w+)\s*\}');
    for (final m in registry.allMatches(processor)) {
      final body = _functionBody(processor, m[2]!);
      final table = _enumTable(body);
      keys.add(MatcHeaderKey(
        name: m[1]!,
        jsonType: m[3]!,
        values: table.values.isNotEmpty ? table.values : _numberValues(body),
        aliases: table.aliases,
        ignored: _ignoredValues(body),
        builderDoc: _builderDoc(header, processor, body),
      ));
    }
    final shaderCode = FilamentShaderCode.parse(shaders);
    Map<String, String> table(String name) => _enumsTable(enumSource, name);
    return FilamentMaterialCode(
      headerKeys: keys,
      blendFunctions: _enumTable(_functionBody(processor, 'processBlendFunction')).values,
      parameterTypes: {...table('mStringToUniformType'), ...table('mStringToSamplerType')},
      precisions: table('mStringToSamplerPrecision').keys.toList(),
      constantTypes: table('mStringToConstantType').keys.toList(),
      properties: table('mStringToProperty').keys.toList(),
      functions: shaderCode.functions,
      materialInputs: shaderCode.materialInputs,
      vertexInputs: shaderCode.vertexInputs,
    );
  }

  /// The body of `static Status <name>(…) { … }`; empty when not found.
  static String _functionBody(String source, String name) {
    final start = RegExp('static Status $name\\(').firstMatch(source);
    if (start == null) return '';
    final open = source.indexOf('{', start.end);
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}' && --depth == 0) return source.substring(open + 1, i);
    }
    return '';
  }

  /// The `strToEnum` table of a processor: `{ "add", X::ADD },` entries or
  /// `strToEnum["skinning"] = X::SKINNING;` assignments. Entries after a
  /// `// Backward compatibility` comment are aliases of the first earlier
  /// entry with the same enumerator.
  static ({List<String> values, Map<String, String> aliases}) _enumTable(String body) {
    final values = <String>[];
    final aliases = <String, String>{};
    final enumOf = <String, String>{};
    var legacy = false;
    final entry = RegExp(r'^\s*(?:\{\s*"(\w+)",\s*([^}]+?)\s*\},?|strToEnum\["(\w+)"\]\s*=\s*([^;]+);)');
    for (final line in body.split('\n')) {
      if (line.contains('Backward compatibility')) legacy = true;
      final m = entry.firstMatch(line);
      if (m == null) continue;
      final name = m[1] ?? m[3]!;
      final value = (m[2] ?? m[4]!).replaceAll(' ', '');
      // `{ "srcRGB", &srcRGB }`: blendFunction's table of fields, not values.
      if (value.startsWith('&')) continue;
      if (legacy) {
        final target = enumOf.entries.where((e) => e.value == value).map((e) => e.key).firstOrNull;
        if (target != null) {
          aliases[name] = target;
          continue;
        }
      }
      enumOf[name] = value;
      values.add(name);
    }
    return (values: values, aliases: aliases);
  }

  /// The numbers a processor compares its value with (`featureLevel`).
  static List<String> _numberValues(String body) => [
    for (final m in RegExp(r'getFloat\(\)\s*==\s*(\d+)(?:\.0)?f').allMatches(body)) m[1]!,
  ];

  /// `if (s == "x") { … "… deprecated …" … continue; }` → {x: the message}.
  static Map<String, String> _ignoredValues(String body) => {
    for (final m in RegExp(r'if \(s == "(\w+)"\) \{[^}]*?"([^"]*deprecated[^"]*)"').allMatches(body))
      m[1]!: m[2]!.replaceFirst(RegExp(r'^\s*Warning:\s*'), '').trim(),
  };

  /// The comment of the builder method the processor calls (through a helper
  /// such as `processBuffer` for an array key).
  static String _builderDoc(String header, String processor, String body, [int depth = 0]) {
    final call = RegExp(r'builder\.(\w+)\(').firstMatch(body);
    if (call != null) return _methodComment(header, call[1]!);
    final helper = RegExp(r'(process\w+)\(builder').firstMatch(body);
    if (helper == null || depth > 1) return '';
    return _builderDoc(header, processor, _functionBody(processor, helper[1]!), depth + 1);
  }

  /// The `/** … */` or `//!` comment right above the first declaration of
  /// `MaterialBuilder& <method>(` that has one.
  static String _methodComment(String header, String method) {
    for (final m in RegExp('MaterialBuilder& $method\\(').allMatches(header)) {
      final lines = header.substring(0, m.start).split('\n');
      if (lines.isNotEmpty) lines.removeLast();
      final comment = <String>[];
      var block = false;
      for (var i = lines.length - 1; i >= 0; i--) {
        final l = lines[i].trim();
        if (comment.isEmpty && !block && l.endsWith('*/')) block = true;
        if (block) {
          comment.insert(0, l);
          if (l.startsWith('/**')) break;
          continue;
        }
        if (l.startsWith('//!')) {
          comment.insert(0, l);
          continue;
        }
        break;
      }
      final text = comment
          .map((l) => l.replaceFirst(RegExp(r'^(/\*\*|\*/|\*|//!)'), '').replaceFirst(RegExp(r'\*/$'), '').trim())
          .where((l) => l.isNotEmpty && !l.startsWith('@'))
          .join(' ')
          .replaceAll(RegExp(r'\\c\s+'), '')
          .replaceAll('`', '');
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// A table of filamat's `Enums.cpp`: name → the name of the first entry
  /// with the same enumerator (itself for the canonical spelling).
  static Map<String, String> _enumsTable(String source, String table) {
    final start = source.indexOf('Enums::$table = {');
    if (start < 0) return const {};
    final end = source.indexOf('};', start);
    final out = <String, String>{};
    final byEnum = <String, String>{};
    for (final m in RegExp(r'\{\s*"(\w+)",\s*([\w:]+)\s*\}').allMatches(source.substring(start, end))) {
      out[m[1]!] = byEnum.putIfAbsent(m[2]!, () => m[1]!);
    }
    return out;
  }
}
