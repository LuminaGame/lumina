import 'dart:convert';
import 'dart:io';

import '../../src/blueprint/blueprint.dart';

/// A scanner finding on an annotated function: the file and
/// line, the function (`name` or `Class.name`), the parameter when one is at
/// fault, and what is wrong. The function gets no node.
class BlueprintFunctionDiagnostic {
  /// Project-relative (`lib/health.dart`).
  final String path;
  final int line;
  final String function;
  final String? parameter;
  final String message;

  const BlueprintFunctionDiagnostic({
    required this.path,
    required this.line,
    required this.function,
    this.parameter,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'line': line,
        'function': function,
        if (parameter != null) 'parameter': parameter,
        'message': message,
      };

  factory BlueprintFunctionDiagnostic.fromJson(Map<String, dynamic> json) => BlueprintFunctionDiagnostic(
        path: json['path'] as String? ?? '',
        line: json['line'] as int? ?? 0,
        function: json['function'] as String? ?? '',
        parameter: json['parameter'] as String?,
        message: json['message'] as String? ?? '',
      );

  @override
  String toString() => '$path:$line: $message';
}

/// An annotated Dart function as a Blueprint node: its [spec], how generated
/// code calls it ([call]), and where it is declared.
class BlueprintExposedFunction {
  final LuminaBlueprintNodeSpec spec;
  final LuminaBlueprintCallShape call;

  /// Project-relative (`lib/health.dart`).
  final String path;
  final int line;

  const BlueprintExposedFunction({required this.spec, required this.call, required this.path, required this.line});

  Map<String, dynamic> toJson() => {
        'id': spec.id,
        'title': spec.title,
        'category': spec.category,
        'kind': spec.kind.name,
        'keywords': spec.keywords,
        if (spec.tooltip != null) 'tooltip': spec.tooltip,
        'headerColor': spec.headerColor,
        'inputs': [for (final p in spec.inputs) _pinToJson(p)],
        'outputs': [for (final p in spec.outputs) _pinToJson(p)],
        'call': {
          'library': call.library,
          'method': call.method,
          'self': call.self,
          'args': call.args,
          'named': [for (final a in call.args) if (call.named.contains(a)) a],
          'optional': [for (final a in call.args) if (call.optional.contains(a)) a],
          'outputs': call.outputs,
          'record': call.returnsRecord,
        },
        'path': path,
        'line': line,
      };

  factory BlueprintExposedFunction.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => [for (final s in (v as List? ?? const [])) '$s'];
    List<LuminaBlueprintPinSpec> pins(Object? v) =>
        [for (final p in (v as List? ?? const [])) _pinFromJson(Map<String, dynamic>.from(p as Map))];
    final call = Map<String, dynamic>.from(json['call'] as Map? ?? const {});
    final kind = LuminaBlueprintNodeKind.values.where((k) => k.name == json['kind']).firstOrNull;
    return BlueprintExposedFunction(
      spec: LuminaBlueprintNodeSpec(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'Project',
        kind: kind ?? LuminaBlueprintNodeKind.impure,
        keywords: strings(json['keywords']),
        tooltip: json['tooltip'] as String?,
        headerColor: json['headerColor'] as int? ?? 0xFF1565C0,
        inputs: pins(json['inputs']),
        outputs: pins(json['outputs']),
      ),
      call: LuminaBlueprintCallShape(
        call['method'] as String? ?? '',
        strings(call['args']),
        library: call['library'] as String?,
        self: call['self'] as bool? ?? false,
        named: strings(call['named']).toSet(),
        optional: strings(call['optional']).toSet(),
        outputs: strings(call['outputs']),
        record: call['record'] as bool? ?? false,
      ),
      path: json['path'] as String? ?? '',
      line: json['line'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _pinToJson(LuminaBlueprintPinSpec p) => {
        'id': p.id,
        'name': p.name,
        'type': p.type.name,
        if (p.defaultValue != null) 'default': p.defaultValue,
        if (p.required) 'required': true,
      };

  static LuminaBlueprintPinSpec _pinFromJson(Map<String, dynamic> json) => LuminaBlueprintPinSpec(
        json['id'] as String? ?? '',
        json['name'] as String? ?? '',
        LuminaPinType.parse(json['type'] as String?) ?? LuminaPinType.structEnum,
        defaultValue: json['default'],
        required: json['required'] as bool? ?? false,
      );
}

/// `project.blueprint_functions.json`, next to the `.lmproject`:
/// what the scanner found in the project's `lib/`, so the
/// editor lists the project's functions in the palette, validates and
/// compiles Blueprints that use them, and reports the scanner's errors,
/// without compiling project code.
class BlueprintFunctionManifest {
  static const String fileName = 'project.blueprint_functions.json';
  static const int format = 1;

  final List<BlueprintExposedFunction> functions;
  final List<BlueprintFunctionDiagnostic> diagnostics;

  const BlueprintFunctionManifest({this.functions = const [], this.diagnostics = const []});

  Map<String, dynamic> toJson() => {
        'format': format,
        'functions': [for (final f in functions) f.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };

  factory BlueprintFunctionManifest.fromJson(Map<String, dynamic> json) => BlueprintFunctionManifest(
        functions: [
          for (final f in (json['functions'] as List? ?? const []))
            BlueprintExposedFunction.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        diagnostics: [
          for (final d in (json['diagnostics'] as List? ?? const []))
            BlueprintFunctionDiagnostic.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
      );

  /// The file's bytes: indented JSON, byte-stable for the same scan.
  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Reads the manifest of the project at [projectDir]; null when there is none.
  static BlueprintFunctionManifest? read(Directory projectDir) {
    final file = File('${projectDir.path}/$fileName');
    if (!file.existsSync()) return null;
    return BlueprintFunctionManifest.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  void write(Directory projectDir) => File('${projectDir.path}/$fileName').writeAsStringSync(encode());

  /// Makes these functions known to this process without running them
  /// ([LuminaBlueprintFunctionRegistry.declare]), replacing earlier
  /// declarations. Functions this process registered as callable keep their
  /// registration.
  void declareAll() {
    LuminaBlueprintFunctionRegistry.clearDeclared();
    for (final f in functions) {
      if (LuminaBlueprintFunctionRegistry.entry(f.spec.id)?.callable ?? false) continue;
      LuminaBlueprintFunctionRegistry.declare(f.spec, call: f.call);
    }
  }
}
