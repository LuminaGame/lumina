import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

import 'package:lumina/lumina.dart';
import 'package:lumina_editor_data/src/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina_editor_data/src/services/blueprint_function_manifest.dart';

export 'package:lumina_editor_data/src/services/blueprint_function_manifest.dart';

part 'blueprint_function_scanner/declaration_reader.dart';

/// A type as generated code names it: `double`, `Vector3`, `LuminaActor`,
/// or a project class through its library's import prefix.
class _TypeRef {
  final String name;

  /// The library to import it from (prefixed); null for `dart:core`,
  /// vector_math and lumina (the registration imports those unprefixed).
  final String? library;
  final bool nullable;
  final bool vectorMath;

  const _TypeRef(this.name, {this.library, this.nullable = false, this.vectorMath = false});

  String code() => '${library == null ? '' : '${BlueprintDartGenerator.functionPrefix(library!)}.'}$name${nullable ? '?' : ''}';
}

/// What the registration needs beyond the node spec: each argument's Dart
/// type, and each output's.
class _Signature {
  final Map<String, _TypeRef> args;
  final Map<String, _TypeRef> outputs;
  const _Signature(this.args, this.outputs);
}

/// What [BlueprintFunctionScanner.scan] found in a project's `lib/`: a node
/// per valid annotated function, sorted by id, and a diagnostic per refused
/// one.
class BlueprintFunctionScan {
  final List<BlueprintExposedFunction> functions;
  final List<BlueprintFunctionDiagnostic> diagnostics;

  /// The project's Dart package, as the scanned libraries' URIs name it.
  final String? packageName;
  final Map<String, _Signature> _signatures;

  const BlueprintFunctionScan._(this.functions, this.diagnostics, this.packageName, this._signatures);

  const BlueprintFunctionScan.empty([this.diagnostics = const []])
      : functions = const [],
        packageName = null,
        _signatures = const {};

  BlueprintExposedFunction? function(String id) => functions.where((f) => f.spec.id == id).firstOrNull;

  /// `project.blueprint_functions.json`'s content.
  BlueprintFunctionManifest get manifest => BlueprintFunctionManifest(functions: functions, diagnostics: diagnostics);
}

/// Lumina's "header tool": reads the `@BlueprintCallable` /
/// `@BlueprintPure` functions of a project's `lib/` with `package:analyzer`,
/// derives each one's node — pins from the parameters and the return type,
/// category, title, keywords, and the doc comment as tooltip — and generates
/// the registration the Blueprint VM calls, since Flutter has no run-time
/// reflection.
///
/// Types are resolved, not matched by name: a project class called `Vector3`
/// is not vector_math's, and any `LuminaActor` subclass is an object pin. The
/// project needs its `.dart_tool/package_config.json` (`flutter pub get`);
/// the Dart SDK is the one of the Flutter SDK that wrote it, unless
/// [sdkPath] names one. Editor side only: games never import the analyzer.
class BlueprintFunctionScanner {
  /// The Dart SDK to resolve against (`<flutter>/bin/cache/dart-sdk`); found
  /// from the project's package config, `FLUTTER_ROOT` or the running `dart`
  /// when null.
  final String? sdkPath;

  /// Keep the analysis context of each scanned `lib/` alive between scans,
  /// telling it only which files changed (the editor rescans on every save;
  /// a cold scan takes seconds, a warm one a fraction of that). Release it
  /// with [release] when the project closes.
  final bool keepWarm;

  const BlueprintFunctionScanner({this.sdkPath, this.keepWarm = false});

  static final Map<String, _WarmContext> _warm = {};

  /// Disposes the warm analysis context kept for [libDir] (see [keepWarm]).
  static Future<void> release(Directory libDir) async {
    final warm = _warm.remove(p.normalize(libDir.absolute.path));
    await warm?.collection.dispose();
  }

  /// Where the generated registration goes, relative to the project.
  static const String registrationPath = 'lib/blueprint/blueprint_functions.g.dart';

  static const String _annotationLibrary = 'package:lumina/src/blueprint/blueprint_annotations.dart';
  static final RegExp _marker = RegExp(r'\bBlueprint(Callable|Pure)\b');
  static const int _callableColor = 0xFF1565C0; // the node library's function colour
  static const int _pureColor = 0xFF2E7D32; // and its pure colour

  /// Scans every `.dart` file under [libDir] (generated `*.g.dart` files
  /// excepted). Files that mention no annotation are not analyzed, so a
  /// project without exposed functions scans in milliseconds.
  Future<BlueprintFunctionScan> scan(Directory libDir) async {
    final lib = p.normalize(libDir.absolute.path);
    final root = p.dirname(lib);
    if (!Directory(lib).existsSync()) return const BlueprintFunctionScan.empty();
    final candidates = <String>[];
    final files = Directory(lib).listSync(recursive: true, followLinks: false).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final path = p.normalize(f.absolute.path);
      final relative = p.relative(path, from: lib);
      if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
      if (p.split(relative).any((s) => s.startsWith('.'))) continue;
      if (_marker.hasMatch(f.readAsStringSync())) candidates.add(path);
    }
    if (candidates.isEmpty) return const BlueprintFunctionScan.empty();

    String rel(String path) => p.posix.joinAll(p.split(p.relative(path, from: root)));
    BlueprintFunctionScan fail(String message) => BlueprintFunctionScan.empty([
          BlueprintFunctionDiagnostic(path: rel(candidates.first), line: 1, function: '', message: message),
        ]);

    final config = _packageConfig(lib);
    if (config == null) {
      return fail('No .dart_tool/package_config.json above ${rel(lib)}/: run `flutter pub get` in the project '
          'before its Blueprint functions can be read.');
    }
    final sdk = sdkPath ?? _sdkFor(config);
    if (sdk == null) {
      return fail('No Dart SDK found to read the Blueprint functions with (set FLUTTER_ROOT, or run '
          '`flutter pub get` so the package config names the Flutter SDK).');
    }

    AnalysisContextCollection? collection;
    final found = <BlueprintExposedFunction>[];
    final signatures = <String, _Signature>{};
    final diagnostics = <BlueprintFunctionDiagnostic>[];
    String? packageName;
    try {
      collection = await _collectionFor(lib, sdk, files);
      for (final path in candidates) {
        final result = await collection.contextFor(path).currentSession.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          diagnostics.add(BlueprintFunctionDiagnostic(
              path: rel(path), line: 1, function: '', message: '${rel(path)} could not be analyzed ($result).'));
          continue;
        }
        final broken = result.diagnostics.where((d) => d.severity == Severity.error).firstOrNull;
        if (broken != null) {
          final line = result.lineInfo.getLocation(broken.offset).lineNumber;
          diagnostics.add(BlueprintFunctionDiagnostic(
              path: rel(path), line: line, function: '', message: '${rel(path)} does not compile: ${broken.message}'));
        }
        final library = result.libraryElement.uri.toString();
        if (library.startsWith('package:')) packageName ??= library.substring(8).split('/').first;
        final reader = _Reader(result, library, rel(path));
        result.unit.accept(_Declarations(reader.read));
        found.addAll(reader.functions);
        signatures.addAll(reader.signatures);
        diagnostics.addAll(reader.diagnostics);
      }
    } catch (e) {
      // The editor rescans on every save: report, never crash it.
      diagnostics.add(BlueprintFunctionDiagnostic(
          path: rel(candidates.first), line: 1, function: '', message: 'Reading the Blueprint functions failed: $e'));
      if (keepWarm) await release(libDir);
    } finally {
      if (!keepWarm) await collection?.dispose();
    }
    found.sort((a, b) => a.spec.id.compareTo(b.spec.id));
    diagnostics.sort((a, b) {
      final byPath = a.path.compareTo(b.path);
      return byPath != 0 ? byPath : a.line.compareTo(b.line);
    });
    return BlueprintFunctionScan._(List.unmodifiable(found), List.unmodifiable(diagnostics), packageName, signatures);
  }

  /// A fresh collection, or with [keepWarm] the one kept for [lib], told
  /// which of [files] were added, changed or removed since the last scan.
  Future<AnalysisContextCollection> _collectionFor(String lib, String sdk, List<File> files) async {
    if (!keepWarm) return AnalysisContextCollection(includedPaths: [lib], sdkPath: sdk);
    final stamps = <String, DateTime>{
      for (final f in files)
        if (f.path.endsWith('.dart')) p.normalize(f.absolute.path): f.lastModifiedSync(),
    };
    final warm = _warm[lib];
    if (warm == null || warm.sdk != sdk) {
      await warm?.collection.dispose();
      final created = _WarmContext(AnalysisContextCollection(includedPaths: [lib], sdkPath: sdk), sdk, stamps);
      _warm[lib] = created;
      return created.collection;
    }
    final changed = <String>{
      for (final e in stamps.entries)
        if (warm.stamps[e.key] != e.value) e.key,
      for (final path in warm.stamps.keys)
        if (!stamps.containsKey(path)) path,
    };
    if (changed.isNotEmpty) {
      final context = warm.collection.contextFor(lib);
      for (final path in changed) {
        context.changeFile(path);
      }
      await context.applyPendingFileChanges();
    }
    warm.stamps
      ..clear()
      ..addAll(stamps);
    return warm.collection;
  }

  /// `lib/blueprint/blueprint_functions.g.dart`: `registerProjectBlueprintFunctions()`
  /// registers each function of [scan] with a closure that unpacks the pin
  /// values, calls the function and packs its outputs. Libraries of the
  /// project package [libraryName] (default: the scanned one) are imported
  /// relatively, others by URI. Byte-stable for the same scan.
  String generateRegistration(BlueprintFunctionScan scan, {String? libraryName}) {
    final package = libraryName ?? scan.packageName;
    final libraries = <String>{};
    var vectorMath = false;
    for (final f in scan.functions) {
      libraries.add(f.call.library!);
      final sig = scan._signatures[f.spec.id]!;
      for (final t in [...sig.args.values, ...sig.outputs.values]) {
        if (t.library != null) libraries.add(t.library!);
        vectorMath |= t.vectorMath;
      }
    }
    String importUri(String uri) =>
        package != null && uri.startsWith('package:$package/') ? '../${uri.substring('package:$package/'.length)}' : uri;

    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    b.writeln("// The project's Dart functions exposed to Blueprints: every");
    b.writeln('// @BlueprintCallable / @BlueprintPure function under lib/, read by');
    b.writeln("// BlueprintFunctionScanner. Generated Blueprint classes call them directly; this");
    b.writeln('// registers them for the Blueprint VM.');
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    if (vectorMath) b.writeln("import 'package:vector_math/vector_math_64.dart';");
    if (libraries.isNotEmpty) {
      b.writeln();
      for (final uri in libraries.toList()..sort()) {
        b.writeln('import ${_str(importUri(uri))} as ${BlueprintDartGenerator.functionPrefix(uri)};');
      }
    }
    b.writeln();
    b.writeln('/// Registers the functions with [LuminaBlueprintFunctionRegistry] so the');
    b.writeln("/// Blueprint VM can run them. The generated game's `main()` calls it once,");
    b.writeln('/// before the world starts.');
    b.writeln('void registerProjectBlueprintFunctions() {');
    for (final (i, f) in scan.functions.indexed) {
      if (i > 0) b.writeln();
      _registration(b, f, scan._signatures[f.spec.id]!);
    }
    b.writeln('}');
    return b.toString();
  }

  /// Writes [registrationPath] and `project.blueprint_functions.json` (next
  /// to the `.lmproject`) for the project at [projectDir].
  void writeProjectOutputs(Directory projectDir, BlueprintFunctionScan scan, {String? libraryName}) {
    File('${projectDir.path}/$registrationPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(generateRegistration(scan, libraryName: libraryName));
    scan.manifest.write(projectDir);
  }

  static void _registration(StringBuffer b, BlueprintExposedFunction f, _Signature sig) {
    final s = f.spec;
    final call = f.call;
    b.writeln('  // ${f.path}:${f.line}');
    b.writeln('  LuminaBlueprintFunctionRegistry.register(');
    b.writeln('    const LuminaBlueprintNodeSpec(');
    b.writeln('      id: ${_str(s.id)},');
    b.writeln('      title: ${_str(s.title)},');
    b.writeln('      category: ${_str(s.category)},');
    b.writeln('      kind: LuminaBlueprintNodeKind.${s.kind.name},');
    b.writeln('      headerColor: 0x${s.headerColor.toRadixString(16).toUpperCase().padLeft(8, '0')},');
    if (s.keywords.isNotEmpty) b.writeln('      keywords: [${s.keywords.map(_str).join(', ')}],');
    if (s.tooltip != null) b.writeln('      tooltip: ${_str(s.tooltip!)},');
    for (final (name, pins) in [('inputs', s.inputs), ('outputs', s.outputs)]) {
      if (pins.isEmpty) continue;
      b.writeln('      $name: [');
      for (final pin in pins) {
        b.writeln('        LuminaBlueprintPinSpec(${[
          _str(pin.id),
          _str(pin.name),
          'LuminaPinType.${pin.type.name}',
          if (pin.defaultValue != null) 'defaultValue: ${_value(pin.defaultValue)}',
          if (pin.required) 'required: true',
        ].join(', ')}),');
      }
      b.writeln('      ],');
    }
    b.writeln('    ),');

    final args = [
      if (call.self) 'context.self',
      for (final a in call.args)
        '${call.named.contains(a) ? '$a: ' : ''}inputs[${_str(a)}] as ${sig.args[a]!.code()}',
    ];
    final invocation = '${BlueprintDartGenerator.functionPrefix(call.library!)}.${call.method}(${args.join(', ')})';
    b.writeln('    (context, inputs) {');
    if (call.outputs.isEmpty) {
      b.writeln('      $invocation;');
      b.writeln('      return const {};');
    } else {
      b.writeln('      final result = $invocation;');
      final fields = [
        for (final o in call.outputs) '${_str(o)}: ${call.returnsRecord ? 'result.$o' : 'result'}',
      ];
      b.writeln('      return {${fields.join(', ')}};');
    }
    b.writeln('    },');
    final shape = [
      _str(call.method),
      '[${call.args.map(_str).join(', ')}]',
      if (call.self) 'self: true',
      if (call.outputs.isNotEmpty) 'outputs: [${call.outputs.map(_str).join(', ')}]',
      'library: ${_str(call.library!)}',
      if (call.named.isNotEmpty) 'named: {${call.args.where(call.named.contains).map(_str).join(', ')}}',
      if (call.optional.isNotEmpty) 'optional: {${call.args.where(call.optional.contains).map(_str).join(', ')}}',
      if (call.returnsRecord) 'record: true',
    ];
    b.writeln('    call: const LuminaBlueprintCallShape(${shape.join(', ')}),');
    b.writeln('  );');
  }

  /// The package config of the package [lib] belongs to.
  static File? _packageConfig(String lib) {
    for (var dir = p.dirname(lib);; dir = p.dirname(dir)) {
      final file = File(p.join(dir, '.dart_tool', 'package_config.json'));
      if (file.existsSync()) return file;
      if (p.dirname(dir) == dir) return null;
    }
  }

  /// The Dart SDK of the Flutter SDK that wrote [config], else
  /// `FLUTTER_ROOT`'s, else the running `dart`'s.
  static String? _sdkFor(File config) {
    String? dartSdk(String? flutterRoot) {
      if (flutterRoot == null || flutterRoot.isEmpty) return null;
      final sdk = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
      return Directory(sdk).existsSync() ? sdk : null;
    }

    try {
      final json = jsonDecode(config.readAsStringSync());
      final root = json is Map ? json['flutterRoot'] : null;
      if (root is String) {
        final found = dartSdk(Uri.parse(root).toFilePath());
        if (found != null) return found;
      }
    } on FormatException {
      // Fall through to the environment.
    }
    final fromEnv = dartSdk(Platform.environment['FLUTTER_ROOT']);
    if (fromEnv != null) return fromEnv;
    final exe = Platform.resolvedExecutable;
    if (p.basenameWithoutExtension(exe) == 'dart') {
      final sdk = p.dirname(p.dirname(exe));
      if (File(p.join(sdk, 'version')).existsSync()) return sdk;
    }
    return null;
  }
}

String _str(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'";

/// A pin default as a Dart literal.
String _value(Object? v) {
  if (v is double) {
    final s = v.toString();
    return s.contains('.') || s.contains('e') ? s : '$s.0';
  }
  if (v is String) return _str(v);
  if (v is List) return '[${v.map(_value).join(', ')}]';
  return '$v';
}

/// An analysis context kept between scans, with the modification time of
/// every Dart file it last saw.
class _WarmContext {
  final AnalysisContextCollection collection;
  final String sdk;
  final Map<String, DateTime> stamps;
  _WarmContext(this.collection, this.sdk, this.stamps);
}
