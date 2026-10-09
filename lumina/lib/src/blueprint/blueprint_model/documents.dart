part of '../blueprint_model.dart';

List<LuminaBlueprintVariable> _variables(Object? list) => [
      for (final v in list as List? ?? const []) LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(v as Map)),
    ];

/// A user function of a Blueprint: its signature, its own
/// graph (with a `function_entry` and, when it has outputs, a
/// `function_result` node), local variables, and whether it is pure (no exec
/// pins; callable from data chains).
class LuminaBlueprintFunctionGraph {
  String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;
  final List<LuminaBlueprintVariable> localVariables;
  final LuminaBlueprintGraph graph;
  bool pure;
  String category;

  LuminaBlueprintFunctionGraph({
    required this.name,
    List<LuminaBlueprintVariable>? inputs,
    List<LuminaBlueprintVariable>? outputs,
    List<LuminaBlueprintVariable>? localVariables,
    LuminaBlueprintGraph? graph,
    this.pure = false,
    this.category = 'Default',
  })  : inputs = inputs ?? <LuminaBlueprintVariable>[],
        outputs = outputs ?? <LuminaBlueprintVariable>[],
        localVariables = localVariables ?? <LuminaBlueprintVariable>[],
        graph = graph ?? LuminaBlueprintGraph();

  LuminaBlueprintVariable? localVariable(String name) {
    for (final v in localVariables) {
      if (v.name == name) return v;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
        'localVariables': localVariables.map((v) => v.toJson()).toList(),
        'graph': graph.toJson(),
        'pure': pure,
        'category': category,
      };

  factory LuminaBlueprintFunctionGraph.fromJson(Map<String, dynamic> map) => LuminaBlueprintFunctionGraph(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
        localVariables: _variables(map['localVariables']),
        graph: LuminaBlueprintGraph.fromJson(map['graph'] == null ? null : Map<String, dynamic>.from(map['graph'] as Map)),
        pure: map['pure'] as bool? ?? false,
        category: map['category'] as String? ?? 'Default',
      );
}

/// A macro of a Blueprint: exec and data inputs / outputs
/// (`typeName: 'Exec'` for exec pins) and a body graph with a `macro_input`
/// and a `macro_output` node. A `call_macro` node is expanded into its
/// caller by [LuminaBlueprintMacroExpander]; the document keeps it folded.
class LuminaBlueprintMacroGraph {
  String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;
  final LuminaBlueprintGraph graph;

  LuminaBlueprintMacroGraph({
    required this.name,
    List<LuminaBlueprintVariable>? inputs,
    List<LuminaBlueprintVariable>? outputs,
    LuminaBlueprintGraph? graph,
  })  : inputs = inputs ?? <LuminaBlueprintVariable>[],
        outputs = outputs ?? <LuminaBlueprintVariable>[],
        graph = graph ?? LuminaBlueprintGraph();

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
        'graph': graph.toJson(),
      };

  factory LuminaBlueprintMacroGraph.fromJson(Map<String, dynamic> map) => LuminaBlueprintMacroGraph(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
        graph: LuminaBlueprintGraph.fromJson(map['graph'] == null ? null : Map<String, dynamic>.from(map['graph'] as Map)),
      );
}

/// An event dispatcher of a Blueprint: a name and the
/// parameters every bound event receives.
class LuminaBlueprintDispatcher {
  String name;
  final List<LuminaBlueprintVariable> parameters;

  LuminaBlueprintDispatcher({required this.name, List<LuminaBlueprintVariable>? parameters})
      : parameters = parameters ?? <LuminaBlueprintVariable>[];

  Map<String, dynamic> toJson() => {'name': name, 'parameters': parameters.map((v) => v.toJson()).toList()};

  factory LuminaBlueprintDispatcher.fromJson(Map<String, dynamic> map) =>
      LuminaBlueprintDispatcher(name: map['name'] as String? ?? '', parameters: _variables(map['parameters']));
}

/// One function of a Blueprint interface. A function with
/// outputs is implemented as a Blueprint function of that name; one without
/// as an `event_interface_function` event.
class LuminaBlueprintFunctionSignature {
  final String name;
  final List<LuminaBlueprintVariable> inputs;
  final List<LuminaBlueprintVariable> outputs;

  const LuminaBlueprintFunctionSignature({required this.name, this.inputs = const [], this.outputs = const []});

  Map<String, dynamic> toJson() => {
        'name': name,
        'inputs': inputs.map((v) => v.toJson()).toList(),
        'outputs': outputs.map((v) => v.toJson()).toList(),
      };

  factory LuminaBlueprintFunctionSignature.fromJson(Map<String, dynamic> map) => LuminaBlueprintFunctionSignature(
        name: map['name'] as String? ?? '',
        inputs: _variables(map['inputs']),
        outputs: _variables(map['outputs']),
      );
}

/// A Blueprint interface asset: the `.lmas` payload
/// `{"kind": "interface", "name": …, "functions": […]}`.
class LuminaBlueprintInterfaceDocument {
  static const String kind = 'interface';
  final String name;
  final List<LuminaBlueprintFunctionSignature> functions;

  const LuminaBlueprintInterfaceDocument({required this.name, this.functions = const []});

  LuminaBlueprintFunctionSignature? function(String? name) {
    for (final f in functions) {
      if (f.name == name) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'functions': functions.map((f) => f.toJson()).toList()};

  factory LuminaBlueprintInterfaceDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintInterfaceDocument(
        name: map['name'] as String? ?? '',
        functions: [
          for (final f in map['functions'] as List? ?? const [])
            LuminaBlueprintFunctionSignature.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// A Blueprint enum asset: the `.lmas` payload
/// `{"kind": "enum", "name": …, "values": […]}`. Values are their names at
/// run time.
class LuminaBlueprintEnumDocument {
  static const String kind = 'enum';
  final String name;
  final List<String> values;

  const LuminaBlueprintEnumDocument({required this.name, this.values = const []});

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'values': values};

  factory LuminaBlueprintEnumDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintEnumDocument(
        name: map['name'] as String? ?? '',
        values: [for (final v in map['values'] as List? ?? const []) '$v'],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// The kind of Blueprint document a `.lmas` payload holds: `class` (an
/// actor Blueprint), `enum` or `interface`.
String luminaBlueprintDocumentKind(Map<String, dynamic> payload) => payload['kind'] as String? ?? 'class';

/// A Blueprint class document: what an ACTOR `.lmas` carries in its payload.
class LuminaBlueprintDocument {
  String parentClass;
  final List<LuminaBlueprintComponent> components;
  final LuminaBlueprintGraph eventGraph;
  final List<LuminaBlueprintVariable> variables;
  final Map<String, dynamic> classDefaults;

  /// User functions, macros and event dispatchers.
  final List<LuminaBlueprintFunctionGraph> functions;
  final List<LuminaBlueprintMacroGraph> macros;
  final List<LuminaBlueprintDispatcher> dispatchers;

  /// The names of the interface assets this Blueprint implements.
  final List<String> interfaces;

  LuminaBlueprintDocument({
    this.parentClass = 'LuminaActor',
    List<LuminaBlueprintComponent>? components,
    LuminaBlueprintGraph? eventGraph,
    List<LuminaBlueprintVariable>? variables,
    Map<String, dynamic>? classDefaults,
    List<LuminaBlueprintFunctionGraph>? functions,
    List<LuminaBlueprintMacroGraph>? macros,
    List<LuminaBlueprintDispatcher>? dispatchers,
    List<String>? interfaces,
  })  : components = components ?? <LuminaBlueprintComponent>[],
        eventGraph = eventGraph ?? LuminaBlueprintGraph(),
        variables = variables ?? <LuminaBlueprintVariable>[],
        classDefaults = classDefaults ?? <String, dynamic>{},
        functions = functions ?? <LuminaBlueprintFunctionGraph>[],
        macros = macros ?? <LuminaBlueprintMacroGraph>[],
        dispatchers = dispatchers ?? <LuminaBlueprintDispatcher>[],
        interfaces = interfaces ?? <String>[];

  LuminaBlueprintVariable? variable(String name) {
    for (final v in variables) {
      if (v.name == name) return v;
    }
    return null;
  }

  LuminaBlueprintFunctionGraph? function(String? name) {
    for (final f in functions) {
      if (f.name == name) return f;
    }
    return null;
  }

  LuminaBlueprintMacroGraph? macro(String? name) {
    for (final m in macros) {
      if (m.name == name) return m;
    }
    return null;
  }

  LuminaBlueprintDispatcher? dispatcher(String? name) {
    for (final d in dispatchers) {
      if (d.name == name) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'parentClass': parentClass,
        'components': components.map((c) => c.toJson()).toList(),
        'eventGraph': eventGraph.toJson(),
        'variables': variables.map((v) => v.toJson()).toList(),
        'classDefaults': classDefaults,
        if (functions.isNotEmpty) 'functions': functions.map((f) => f.toJson()).toList(),
        if (macros.isNotEmpty) 'macros': macros.map((m) => m.toJson()).toList(),
        if (dispatchers.isNotEmpty) 'dispatchers': dispatchers.map((d) => d.toJson()).toList(),
        if (interfaces.isNotEmpty) 'interfaces': interfaces,
      };

  factory LuminaBlueprintDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintDocument(
        parentClass: map['parentClass'] as String? ?? 'LuminaActor',
        components: (map['components'] as List? ?? const [])
            .map((c) => LuminaBlueprintComponent.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList(),
        eventGraph: LuminaBlueprintGraph.fromJson(
          map['eventGraph'] == null ? null : Map<String, dynamic>.from(map['eventGraph'] as Map),
        ),
        variables: (map['variables'] as List? ?? const [])
            .map((v) => LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        classDefaults: Map<String, dynamic>.from(map['classDefaults'] as Map? ?? const {}),
        functions: [
          for (final f in map['functions'] as List? ?? const [])
            LuminaBlueprintFunctionGraph.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        macros: [
          for (final m in map['macros'] as List? ?? const []) LuminaBlueprintMacroGraph.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        dispatchers: [
          for (final d in map['dispatchers'] as List? ?? const [])
            LuminaBlueprintDispatcher.fromJson(Map<String, dynamic>.from(d as Map)),
        ],
        interfaces: [for (final i in map['interfaces'] as List? ?? const []) '$i'],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
