import 'package:vector_math/vector_math_64.dart';

import '../../../src/blueprint/blueprint.dart';
import '../../../src/input/input_action.dart';
import '../dart_identifiers.dart';

part 'blueprint_dart_generator/graph_compiler.dart';
part 'blueprint_dart_generator/class_writer.dart';
part 'blueprint_dart_generator/anim_class_writer.dart';

/// What [BlueprintDartGenerator.generate] produced: the Dart source, or null
/// when an error stopped generation, and every issue found on the way.
class BlueprintGenerationResult {
  final String? code;
  final List<LuminaBlueprintDiagnostic> issues;

  /// The import directives [code] needs beyond `package:lumina/lumina_runtime.dart`
  /// and vector_math, for code embedded in another file (a level script);
  /// empty for a whole file.
  final List<String> imports;
  const BlueprintGenerationResult(this.code, this.issues, {this.imports = const []});

  bool get ok => code != null;
  List<LuminaBlueprintDiagnostic> get errors => issues.where((d) => d.isError).toList();
}

/// A generated class another generated class refers to by its `.lmas` path —
/// a mesh's Anim Class, a GameMode's Default Pawn Class: the class, and the
/// file generated code imports it from.
class BlueprintClassRef {
  final String className;
  final String? importUri;
  const BlueprintClassRef(this.className, [this.importUri]);
}

typedef BlueprintAnimClassRef = BlueprintClassRef;

/// Compiles a Blueprint document into a Dart class that behaves exactly like
/// the VM running it: the same component table, the same
/// shared runtime (latent Delay, input binding, tracing), and straight-line
/// event methods that call [LuminaBlueprintFunctionLibrary] directly,
/// evaluating pure nodes in the VM's order so both produce the same trace.
/// Animation Blueprints compile the same way ([generateAnimBlueprint]).
///
/// A node of a Dart function exposed with `@BlueprintCallable` /
/// `@BlueprintPure` (registered or declared in
/// [LuminaBlueprintFunctionRegistry]) compiles to a direct call through its
/// library's import prefix ([functionPrefix]); `functionImports` overrides
/// the URI a library is imported by.
class BlueprintDartGenerator {
  const BlueprintDartGenerator();

  /// The import prefix generated code uses for the exposed-function library
  /// [libraryUri]: `package:my_game/combat/health.dart` → `fn_my_game_combat_health`.
  /// A prefix, because an unprefixed top-level function would lose to an
  /// inherited member of the same name inside a generated class (`jump`), or
  /// clash with vector_math's top-level functions.
  static String functionPrefix(String libraryUri) {
    final uri = Uri.parse(libraryUri);
    final segments = uri.scheme == 'package' ? uri.pathSegments : [uri.pathSegments.lastOrNull ?? 'library'];
    var joined = segments.join('_');
    if (joined.endsWith('.dart')) joined = joined.substring(0, joined.length - '.dart'.length);
    final cleaned = joined.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return 'fn_$cleaned';
  }

  static const Map<String, String> _parents = {
    'LuminaCharacter': 'LuminaCharacter',
    'LuminaPawn': 'LuminaPawn',
    'LuminaActor': 'LuminaActor',
  };

  BlueprintGenerationResult generate(
    LuminaBlueprintDocument doc, {
    required String className,
    String? assetPath,
    List<LuminaInputAction> inputActions = const [],
    String? existingContent,
    Map<String, BlueprintAnimClassRef> animBlueprints = const {},
    Map<String, BlueprintClassRef> blueprintClasses = const {},
    Map<String, String> functionImports = const {},
  }) {
    // Comment boxes and reroutes are the editor's.
    doc = LuminaBlueprintEditorNodes.forEngine(doc);
    final issues = validateBlueprint(doc, inputActions: inputActions, className: _blueprintName(className, assetPath));
    if (issues.any((d) => d.isError)) return BlueprintGenerationResult(null, issues);
    if (doc.parentClass == 'LuminaGameMode') {
      final code = _gameMode(doc, className, assetPath, blueprintClasses, issues, _userRegions(existingContent));
      return BlueprintGenerationResult(code, issues);
    }
    if (!_parents.containsKey(doc.parentClass)) {
      issues.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error,
          'Parent class ${doc.parentClass} cannot be generated yet (Actor, Pawn and Character can).'));
      return BlueprintGenerationResult(null, issues);
    }
    final writer = _ClassWriter(doc, className, assetPath, inputActions, issues, animBlueprints, functionImports);
    final code = writer.write(_userRegions(existingContent));
    return BlueprintGenerationResult(writer.failed ? null : code, issues);
  }

  /// Compiles a Level Blueprint into the level's script class
  /// [className] (`_LTestScript`), a `LuminaLevelScriptActor` with the
  /// shared Blueprint runtime, keyed `<levelName>_script`: its events
  /// (BeginPlay, Tick, End Play, Level Loaded / Unloaded), custom events,
  /// functions, dispatchers and timelines as for a class Blueprint, and one
  /// field per placed actor of [levelActors] (`door01`), resolved by name once
  /// the level is loaded. [members], [beginPlay] and [tick] are the level's
  /// own script lines (the level generator's post-process, player login and
  /// controller tick), written ahead of the Blueprint's. The result is the
  /// class alone; [BlueprintGenerationResult.imports] lists what the level
  /// file must import for it.
  BlueprintGenerationResult generateLevelScript(
    LuminaLevelBlueprintDocument doc, {
    required String className,
    required String levelName,
    List<LuminaBlueprintLevelActorRef> levelActors = const [],
    List<LuminaInputAction> inputActions = const [],
    Map<String, String> actorParents = const {},
    Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = const {},
    List<String> members = const [],
    List<String> beginPlay = const [],
    List<String> tick = const [],
    Map<String, String> functionImports = const {},
  }) {
    final level = _LevelScript(levelName, levelActors, actorParents, customEventOwners, members, beginPlay, tick);
    final issues = validateBlueprint(doc.blueprint, inputActions: inputActions, typeContext: level.context(doc.blueprint, inputActions));
    if (issues.any((d) => d.isError)) return BlueprintGenerationResult(null, issues);
    final writer = _ClassWriter(doc.blueprint, className, doc.levelPath, inputActions, issues, const {}, functionImports, level: level);
    final code = writer.write(const {});
    return BlueprintGenerationResult(writer.failed ? null : code, issues, imports: writer.levelImports);
  }

  /// Compiles a widget's graph into its script class [className]
  /// (`WbpClickerGraph`), a `LuminaUserWidget` with the shared Blueprint
  /// runtime: Event Pre Construct / Construct / Destruct / Tick as the
  /// widget's lifecycle hooks, each bound element event as an
  /// `onWidgetEvent` case, and custom events, functions, dispatchers and
  /// timelines as for a class Blueprint. The result is the class alone, for
  /// the widget's generated file; [BlueprintGenerationResult.imports] lists
  /// what that file must import for it.
  BlueprintGenerationResult generateWidgetScript(
    LuminaWidgetBlueprintDocument doc, {
    required String className,
    List<LuminaInputAction> inputActions = const [],
    Map<String, String> actorParents = const {},
    Map<String, String> functionImports = const {},
  }) {
    // [doc] is the engine's document: the editor flattens its comment boxes
    // and reroutes first, as for every Blueprint it compiles.
    final blueprint = doc.blueprint;
    final widget = _WidgetScript(doc, actorParents);
    final issues = validateBlueprint(blueprint, inputActions: inputActions, typeContext: widget.context(inputActions));
    if (issues.any((d) => d.isError)) return BlueprintGenerationResult(null, issues);
    final writer = _ClassWriter(blueprint, className, null, inputActions, issues, const {}, functionImports, widget: widget);
    final code = writer.write(const {});
    return BlueprintGenerationResult(writer.failed ? null : code, issues, imports: writer.levelImports);
  }

  /// Compiles an Animation Blueprint into a
  /// `LuminaAnimBlueprintInstance` subclass: the update graph as a method,
  /// the state machine and the [blendSpaces] its states play as static
  /// tables, and each transition rule as a method returning its Result.
  BlueprintGenerationResult generateAnimBlueprint(
    LuminaAnimBlueprintDocument doc, {
    required String className,
    String? assetPath,
    Map<String, LuminaBlendSpaceDocument> blendSpaces = const {},
    String? existingContent,
    Map<String, String> functionImports = const {},
  }) {
    final issues = validateAnimBlueprint(doc, blendSpaces: blendSpaces);
    if (issues.any((d) => d.isError)) return BlueprintGenerationResult(null, issues);
    final writer = _AnimClassWriter(doc, className, assetPath, blendSpaces, issues, functionImports);
    final code = writer.write(_userRegions(existingContent));
    return BlueprintGenerationResult(writer.failed ? null : code, issues);
  }

  /// A GameMode Blueprint: a `LuminaGameMode` subclass whose
  /// factories come from the class defaults; the Default Pawn Class is a
  /// compiled Blueprint from [classes].
  static String? _gameMode(LuminaBlueprintDocument doc, String className, String? assetPath,
      Map<String, BlueprintClassRef> classes, List<LuminaBlueprintDiagnostic> issues, Map<String, String> userRegions) {
    final pawn = doc.classDefaults['defaultPawnClass'] as String? ?? '';
    final ref = pawn.isEmpty ? null : classes[pawn];
    if (pawn.isNotEmpty && ref == null) {
      issues.add(LuminaBlueprintDiagnostic(
          LuminaBlueprintSeverity.error, "Default Pawn Class '$pawn' is not a compiled Pawn or Character Blueprint."));
      return null;
    }
    if (doc.eventGraph.nodes.isNotEmpty) {
      issues.add(const LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
          "A GameMode Blueprint's event graph does not run yet; only its class defaults are used."));
    }
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).');
    b.writeln('// Blueprint ${assetPath ?? className}, compiled by Lumina.');
    b.writeln(_ignoreForFile);
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    if (ref?.importUri != null) b.writeln('import ${_str(ref!.importUri!)};');
    b.writeln();
    b.writeln('/// Spawns ${ref == null ? 'a plain LuminaPawn' : ref.className} at the player start and possesses it');
    b.writeln("/// with the local player's controller.");
    b.writeln('class $className extends LuminaGameMode {');
    b.writeln('  $className()');
    b.writeln('      : super(');
    b.writeln('          defaultPawnFactory: () => ${ref == null ? 'LuminaPawn' : ref.className}(),');
    b.writeln("          playerControllerFactory: () => LuminaPlayerController(playerName: 'Player'),");
    b.writeln('        );');
    _userRegion(b, userRegions);
    b.writeln('}');
    return b.toString();
  }

  /// A Blueprint enum asset as a Dart enum: `E_DoorState` →
  /// `enum EDoorState { closed, opening, open }` with the Blueprint value
  /// names, so generated game code can switch on it while pins keep the
  /// value name as a string (`EDoorState.opening.blueprintName`).
  String generateEnum(LuminaBlueprintEnumDocument doc, {String? assetPath}) {
    final className = _typeName(doc.name);
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.');
    b.writeln('// Blueprint enum ${assetPath ?? doc.name}, compiled by Lumina.');
    b.writeln(_ignoreForFile);
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln();
    b.writeln('enum $className {');
    for (var i = 0; i < doc.values.length; i++) {
      b.writeln('  ${_var(doc.values[i])}(${_str(doc.values[i])})${i == doc.values.length - 1 ? ';' : ','}');
    }
    if (doc.values.isEmpty) b.writeln('  ;');
    b.writeln();
    b.writeln('  /// The value name as Blueprint pins carry it.');
    b.writeln('  final String blueprintName;');
    b.writeln('  const $className(this.blueprintName);');
    b.writeln();
    b.writeln('  /// The document the registry serves at run time.');
    b.writeln('  static const LuminaBlueprintEnumDocument document = LuminaBlueprintEnumDocument(name: ${_str(doc.name)}, values: [${doc.values.map(_str).join(', ')}]);');
    b.writeln();
    b.writeln('  static $className? fromBlueprintName(String name) {');
    b.writeln('    for (final v in values) {');
    b.writeln('      if (v.blueprintName == name) return v;');
    b.writeln('    }');
    b.writeln('    return null;');
    b.writeln('  }');
    b.writeln('}');
    return b.toString();
  }

  /// A Blueprint interface asset as an abstract Dart mixin over
  /// [LuminaBlueprintRuntime]: one method per function taking
  /// its argument map, plus the document for the registry.
  String generateInterface(LuminaBlueprintInterfaceDocument doc, {String? assetPath}) {
    final className = _typeName(doc.name);
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.');
    b.writeln('// Blueprint interface ${assetPath ?? doc.name}, compiled by Lumina.');
    b.writeln(_ignoreForFile);
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln();
    b.writeln('/// Implementers answer each function through `callBlueprint(name, args)`.');
    b.writeln('abstract mixin class $className {');
    b.writeln('  static const LuminaBlueprintInterfaceDocument document = LuminaBlueprintInterfaceDocument(name: ${_str(doc.name)}, functions: [');
    for (final f in doc.functions) {
      b.writeln('    LuminaBlueprintFunctionSignature(name: ${_str(f.name)}, inputs: [${f.inputs.map(_variableLiteral).join(', ')}], outputs: [${f.outputs.map(_variableLiteral).join(', ')}]),');
    }
    b.writeln('  ]);');
    for (final f in doc.functions) {
      b.writeln();
      b.writeln('  /// ${f.name}(${f.inputs.map((i) => '${i.name}: ${i.typeName}').join(', ')})${f.outputs.isEmpty ? '' : ' → ${f.outputs.map((o) => '${o.name}: ${o.typeName}').join(', ')}'}');
      b.writeln('  Map<String, Object?> ${_var(f.name)}(Map<String, Object?> args);');
    }
    b.writeln('}');
    return b.toString();
  }

  static String _variableLiteral(LuminaBlueprintVariable v) =>
      'LuminaBlueprintVariable(name: ${_str(v.name)}, typeName: ${_str(v.typeName)}${v.defaultValue == null ? '' : ', defaultValue: ${_json(v.defaultValue)}'})';

  /// The Dart type [generateEnum] / [generateInterface] emit for the asset
  /// [name] (`E_DoorState` → `EDoorState`); the project registry names it.
  static String typeNameOf(String name) => _typeName(name);

  /// `E_DoorState` → `EDoorState`, `BPI_Interactable` → `BpiInteractable`
  /// ([dartTypeName]).
  static String _typeName(String name) => dartTypeName(name);

  /// The Blueprint's class name as the VM and `Actor:<class>` pins know it:
  /// the asset's file name (`contents/blueprints/BP_Door.lmas` → `BP_Door`),
  /// else the Dart class name.
  static String _blueprintName(String className, String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) return className;
    final base = assetPath.split('/').last;
    return base.toLowerCase().endsWith('.lmas') ? base.substring(0, base.length - 5) : base;
  }

  static Map<String, String> _userRegions(String? existing) {
    final regions = <String, String>{};
    if (existing == null) return regions;
    final regex = RegExp(r'// BEGIN USER CODE: ([a-zA-Z0-9_]+)\n([\s\S]*?)[ \t]*// END USER CODE');
    for (final m in regex.allMatches(existing)) {
      regions[m.group(1)!] = m.group(2)!;
    }
    return regions;
  }
}

/// The imports of the exposed-function [libraries] a class calls,
/// prefixed, sorted; [overrides] maps a library URI to the
/// URI to import it by.
void _functionImports(StringBuffer b, Set<String> libraries, Map<String, String> overrides) {
  for (final uri in libraries.toList()..sort()) {
    b.writeln('import ${_str(overrides[uri] ?? uri)} as ${BlueprintDartGenerator.functionPrefix(uri)};');
  }
}

void _userRegion(StringBuffer b, Map<String, String> userRegions) {
  b.writeln();
  b.writeln('  // BEGIN USER CODE: class_body');
  final region = userRegions['class_body'];
  if (region != null && region.trim().isNotEmpty) b.write(region);
  b.writeln('  // END USER CODE');
}

// --- Literals and names -----------------------------------------------------

String _id(String s) {
  final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
  return RegExp(r'^[0-9]').hasMatch(cleaned) ? 'n$cleaned' : cleaned;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _reserved = {
  'is', 'in', 'as', 'if', 'do', 'for', 'new', 'var', 'this', 'super', 'null', 'true', 'false', 'trace',
  // Members every generated class inherits (LuminaActor, LuminaBlueprintRuntime).
  'key', 'world', 'components', 'rootComponent', 'actorLocation', 'actorRotation', 'actorScale', 'variables',
  'isDestroyed', 'owner', 'build', 'destroy', 'lastError', 'blueprintComponents', 'blueprintFlowState',
  'tags', 'lifeSpan', 'instigator', 'hiddenInGame', 'debugShapes', 'actorBounds', 'isPendingDestroy',
  'callBlueprint', 'blueprintDispatchers', 'blueprintTimelines', 'blueprintInterfaces', 'blueprintTimerHandles', 'args', 'values',
  'blueprintMontage', 'blueprintMontageMesh', 'blueprintLatentCompletions', 'blueprintBeginPlayTime', 'blueprintInputEnabled', 'success', 'pin', 'o',
};

/// The lowerCamelCase member a user-named variable, pin, value or function
/// becomes ([dartMemberName]); keywords and the members every generated
/// class inherits get a trailing `_`.
String _var(String name) => dartMemberName(name, reserved: _reserved, fallback: 'variable');

String _dartType(LuminaPinType t) => switch (t) {
      LuminaPinType.float => 'double',
      LuminaPinType.integer => 'int',
      LuminaPinType.boolean => 'bool',
      LuminaPinType.string || LuminaPinType.name => 'String',
      LuminaPinType.vector => 'Vector3',
      LuminaPinType.vector2D => 'Vector2',
      LuminaPinType.rotator => 'LuminaRotator',
      LuminaPinType.color => 'List<double>',
      LuminaPinType.array => 'List<Object?>',
      LuminaPinType.transform || LuminaPinType.hitResult => 'Map<String, Object?>',
      LuminaPinType.enumeration => 'String',
      LuminaPinType.delegate => 'LuminaBlueprintDelegate?',
      LuminaPinType.timerHandle => 'LuminaTimerHandle?',
      _ => 'Object?',
    };

String _nullableType(LuminaPinType t) {
  final d = _dartType(t);
  return d.endsWith('?') ? d : '$d?';
}

String _double(double v) {
  if (v.isNaN) return 'double.nan';
  if (v.isInfinite) return v > 0 ? 'double.infinity' : 'double.negativeInfinity';
  final s = v.toString();
  return s.contains('.') || s.contains('e') ? s : '$s.0';
}

String _str(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'";

/// The Dart literal of a stored value converted as the VM converts it
/// (`luminaBlueprintLiteral`); null is the type's zero.
String _literal(LuminaPinType type, Object? stored) {
  final v = luminaBlueprintLiteral(type, stored);
  switch (type) {
    case LuminaPinType.float:
      return _double((v as double?) ?? 0.0);
    case LuminaPinType.integer:
      return '${(v as int?) ?? 0}';
    case LuminaPinType.boolean:
      return '${(v as bool?) ?? false}';
    case LuminaPinType.string:
    case LuminaPinType.name:
      return _str((v as String?) ?? '');
    case LuminaPinType.vector:
      final x = v as Vector3?;
      return x == null ? 'Vector3.zero()' : 'Vector3(${_double(x.x)}, ${_double(x.y)}, ${_double(x.z)})';
    case LuminaPinType.vector2D:
      final x = v as Vector2?;
      return x == null ? 'Vector2.zero()' : 'Vector2(${_double(x.x)}, ${_double(x.y)})';
    case LuminaPinType.rotator:
      final r = v as LuminaRotator?;
      return r == null ? 'const LuminaRotator.zero()' : 'const LuminaRotator(${_double(r.x)}, ${_double(r.y)}, ${_double(r.z)})';
    case LuminaPinType.color:
      final c = (v as List<double>?) ?? const [0.0, 0.0, 0.0, 1.0];
      return '<double>[${c.map(_double).join(', ')}]';
    case LuminaPinType.array:
      final list = (v as List<Object?>?) ?? const [];
      return '<Object?>[${list.map(_json).join(', ')}]';
    case LuminaPinType.transform:
      final t = v is Map ? v : luminaBlueprintZero(LuminaPinType.transform) as Map;
      return _json(<String, Object?>{for (final e in t.entries) '${e.key}': e.value});
    case LuminaPinType.hitResult:
      return v is Map ? _json(<String, Object?>{for (final e in v.entries) '${e.key}': e.value}) : 'null';
    case LuminaPinType.enumeration:
      return _str((v as String?) ?? '');
    case LuminaPinType.exec:
    case LuminaPinType.object:
    case LuminaPinType.structEnum:
    case LuminaPinType.wildcard:
    case LuminaPinType.delegate:
    case LuminaPinType.timerHandle:
      return v == null ? 'null' : _json(v);
  }
}

String _map(Map<String, String> values) => '{${values.entries.map((e) => '${_str(e.key)}: ${e.value}').join(', ')}}';

/// A JSON value as a Dart literal, typed so component properties read back
/// exactly as the VM reads them from the document.
String _json(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return '$v';
  if (v is int) return '$v';
  if (v is double) return _double(v);
  if (v is String) return _str(v);
  if (v is List) return '<dynamic>[${v.map(_json).join(', ')}]';
  if (v is Map) return '<String, dynamic>{${v.entries.map((e) => '${_str('${e.key}')}: ${_json(e.value)}').join(', ')}}';
  return _str('$v');
}
