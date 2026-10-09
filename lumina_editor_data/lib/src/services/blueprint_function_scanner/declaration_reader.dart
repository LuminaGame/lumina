part of '../blueprint_function_scanner.dart';

/// Visits top-level functions and methods, the only places annotations
/// matter (local functions cannot be called from outside).
class _Declarations extends RecursiveAstVisitor<void> {
  final void Function(Declaration node) found;
  _Declarations(this.found);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) found(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) => found(node);
}

/// Reads the annotated declarations of one resolved file.
class _Reader {
  final ResolvedUnitResult unit;
  final String library;
  final String path;
  final List<BlueprintExposedFunction> functions = [];
  final Map<String, _Signature> signatures = {};
  final List<BlueprintFunctionDiagnostic> diagnostics = [];

  _Reader(this.unit, this.library, this.path);

  void read(Declaration node) {
    final annotations = [for (final a in node.metadata) ?_blueprintAnnotation(a)];
    if (annotations.isEmpty) return;
    final nameToken = node is FunctionDeclaration ? node.name : (node as MethodDeclaration).name;
    final line = unit.lineInfo.getLocation(nameToken.offset).lineNumber;
    final element = node.declaredFragment?.element;
    final owner = element?.enclosingElement;
    final ownerName = owner is LibraryElement ? null : owner?.name;
    final function = ownerName == null ? nameToken.lexeme : '$ownerName.${nameToken.lexeme}';

    void error(String message, {String? parameter}) => diagnostics.add(BlueprintFunctionDiagnostic(
        path: path, line: line, function: function, parameter: parameter, message: '$function: $message'));

    if (annotations.length > 1) {
      return error('has more than one Blueprint annotation; use @BlueprintCallable or @BlueprintPure.');
    }
    final (pure, annotation) = annotations.single;
    if (element is! ExecutableElement) return error('could not be resolved.');
    final body = node is FunctionDeclaration ? node.functionExpression.body : (node as MethodDeclaration).body;
    final isAccessor = node is FunctionDeclaration
        ? node.isGetter || node.isSetter
        : (node as MethodDeclaration).isGetter || node.isSetter || node.isOperator;
    if (isAccessor) return error('is a getter, setter or operator; only functions can be Blueprint nodes.');
    if (node is MethodDeclaration && !node.isStatic) {
      return error('is an instance method. Blueprints cannot call instance methods yet: that needs the editor to '
          'construct $ownerName, which it cannot (instance methods on a user parent class are a later step). '
          'Make it static or top-level and pass the object as a parameter.');
    }
    if (owner != null && owner is! LibraryElement && ownerName == null) {
      return error('is declared in an unnamed extension, which generated code cannot name.');
    }
    if (nameToken.lexeme.startsWith('_') || (ownerName?.startsWith('_') ?? false)) {
      return error('is private; the generated registration in another library cannot call it.');
    }
    if (element.typeParameters.isNotEmpty) {
      return error('is generic (type parameter ${element.typeParameters.map((t) => t.name).join(', ')}); '
          'Blueprint pins have fixed types.');
    }
    final returnType = element.returnType;
    if (returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr || returnType.isDartAsyncStream) {
      return error('returns ${returnType.getDisplayString()}: async functions cannot be Blueprint nodes '
          '(a node runs to completion in its frame).');
    }
    if (body.isAsynchronous || body.isGenerator) {
      return error('is async or a generator; a Blueprint node runs to completion in its frame.');
    }

    // Parameters: an implicit `self`, then one pin each.
    final params = element.formalParameters;
    var self = false;
    final inputs = <LuminaBlueprintPinSpec>[];
    final argTypes = <String, _TypeRef>{};
    final args = <String>[];
    final named = <String>{};
    final optional = <String>{};
    for (final (index, param) in params.indexed) {
      final name = param.name ?? '';
      if (index == 0 && name == 'self' && !param.isNamed) {
        final t = param.type;
        if (t is! InterfaceType ||
            !_isLumina(t.element, 'LuminaActor', 'package:lumina/src/object/actor.dart') ||
            t.nullabilitySuffix == NullabilitySuffix.question) {
          return error("parameter 'self' must be a LuminaActor: it is the Blueprint running the node, whatever its "
              'parent class (test `self is LuminaPawn` inside, as the built-in library does); it is '
              '${t.getDisplayString()}.', parameter: 'self');
        }
        self = true;
        continue;
      }
      if (name == 'exec_in' || name == 'exec_out') {
        return error("parameter '$name' collides with an exec pin; rename it.", parameter: name);
      }
      final mapped = _pin(param.type);
      if (mapped.error != null) return error("parameter '$name' ${mapped.error}", parameter: name);
      Object? defaultValue;
      if (param.hasDefaultValue) {
        final constant = param.computeConstantValue();
        final value = constant == null ? null : _defaultOf(mapped.type!, constant);
        if (constant == null || (value == null && !constant.isNull)) {
          return error("parameter '$name' has a default Blueprint pins cannot hold "
              '(${param.defaultValueCode ?? '?'}).', parameter: name);
        }
        defaultValue = value;
      }
      inputs.add(LuminaBlueprintPinSpec(
        name,
        _words(name),
        mapped.type!,
        defaultValue: defaultValue,
        required: mapped.type == LuminaPinType.object && !mapped.ref!.nullable && !param.isOptional,
      ));
      argTypes[name] = mapped.ref!;
      args.add(name);
      if (param.isNamed) named.add(name);
      if (param.isOptional) optional.add(name);
    }

    // Outputs: none, return_value, or a record's named fields in order.
    final outputs = <LuminaBlueprintPinSpec>[];
    final outputTypes = <String, _TypeRef>{};
    var record = false;
    if (returnType is RecordType) {
      if (returnType.nullabilitySuffix == NullabilitySuffix.question) {
        return error('returns a nullable record; outputs cannot be empty.');
      }
      if (returnType.positionalFields.isNotEmpty || returnType.namedFields.isEmpty) {
        return error('returns a record with positional fields; name every field, one output pin each.');
      }
      record = true;
      final declared = node is FunctionDeclaration ? node.returnType : (node as MethodDeclaration).returnType;
      final order = declared is RecordTypeAnnotation
          ? [for (final f in declared.namedFields?.fields ?? const <RecordTypeAnnotationNamedField>[]) f.name.lexeme]
          : [for (final f in returnType.namedFields) f.name];
      for (final field in order) {
        final type = returnType.namedFields.firstWhere((f) => f.name == field).type;
        if (field == 'exec_out') return error("record field 'exec_out' collides with an exec pin; rename it.");
        final mapped = _pin(type);
        if (mapped.error != null) return error("record field '$field' ${mapped.error}");
        outputs.add(LuminaBlueprintPinSpec(field, _words(field), mapped.type!));
        outputTypes[field] = mapped.ref!;
      }
    } else if (returnType is! VoidType) {
      final mapped = _pin(returnType);
      if (mapped.error != null) return error('return type ${mapped.error}');
      outputs.add(LuminaBlueprintPinSpec('return_value', 'Return Value', mapped.type!));
      outputTypes['return_value'] = mapped.ref!;
    }
    if (pure && outputs.isEmpty) return error('is @BlueprintPure but returns nothing; a pure node must give a value.');

    final methodName = nameToken.lexeme;
    final id = LuminaBlueprintFunctionRegistry.idFor(library, function);
    final spec = LuminaBlueprintNodeSpec(
      id: id,
      title: _string(annotation, 'displayName') ?? _words(methodName),
      category: _string(annotation, 'category') ?? 'Project',
      kind: pure ? LuminaBlueprintNodeKind.pure : LuminaBlueprintNodeKind.impure,
      keywords: [for (final k in annotation.getField('keywords')?.toListValue() ?? const <DartObject>[]) ?k.toStringValue()],
      tooltip: _string(annotation, 'tooltip') ?? _docText(element.documentationComment),
      headerColor: pure ? BlueprintFunctionScanner._pureColor : BlueprintFunctionScanner._callableColor,
      inputs: [
        if (!pure) const LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
        ...inputs,
      ],
      outputs: [
        if (!pure) const LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec),
        ...outputs,
      ],
    );
    final call = LuminaBlueprintCallShape(
      function,
      args,
      self: self,
      outputs: [for (final o in outputs) o.id],
      library: library,
      named: named,
      optional: optional,
      record: record,
    );
    functions.add(BlueprintExposedFunction(spec: spec, call: call, path: path, line: line));
    signatures[id] = _Signature(argTypes, outputTypes);
  }

  /// `(pure, annotation value)` when [a] is `@BlueprintCallable` or
  /// `@BlueprintPure` from lumina.
  static (bool, DartObject)? _blueprintAnnotation(Annotation a) {
    final value = a.elementAnnotation?.computeConstantValue();
    final type = value?.type;
    if (value == null || type is! InterfaceType) return null;
    if (type.element.library.uri.toString() != BlueprintFunctionScanner._annotationLibrary) return null;
    return switch (type.element.name) {
      'BlueprintCallable' => (false, value),
      'BlueprintPure' => (true, value),
      _ => null,
    };
  }

  static String? _string(DartObject annotation, String field) {
    final v = annotation.getField(field)?.toStringValue();
    return v == null || v.isEmpty ? null : v;
  }

  static bool _isLumina(InterfaceElement element, String name, String library) =>
      element.name == name && element.library.uri.toString() == library;

  /// The pin type of Dart [type] and how generated code names it, or why it
  /// has none.
  static ({LuminaPinType? type, _TypeRef? ref, String? error}) _pin(DartType type) {
    const supported = '(double, int, bool, String, Vector3, Vector2, LuminaRotator, LuminaActor or a subclass)';
    final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    String describe() {
      if (type is InterfaceType) {
        final uri = type.element.library.uri.toString();
        return uri.startsWith('dart:') ? type.getDisplayString() : '${type.getDisplayString()} ($uri)';
      }
      return type.getDisplayString();
    }

    ({LuminaPinType? type, _TypeRef? ref, String? error}) ok(LuminaPinType pin, _TypeRef ref) {
      if (nullable && pin != LuminaPinType.object) {
        return (type: null, ref: null, error: 'is nullable (${describe()}); only object pins can be empty.');
      }
      return (type: pin, ref: ref, error: null);
    }

    if (type.isDartCoreDouble) return ok(LuminaPinType.float, const _TypeRef('double'));
    if (type.isDartCoreInt) return ok(LuminaPinType.integer, const _TypeRef('int'));
    if (type.isDartCoreBool) return ok(LuminaPinType.boolean, const _TypeRef('bool'));
    if (type.isDartCoreString) return ok(LuminaPinType.string, const _TypeRef('String'));
    if (type is InterfaceType) {
      final element = type.element;
      final uri = element.library.uri.toString();
      if (uri == 'package:vector_math/vector_math_64.dart' && element.name == 'Vector3') {
        return ok(LuminaPinType.vector, const _TypeRef('Vector3', vectorMath: true));
      }
      if (uri == 'package:vector_math/vector_math_64.dart' && element.name == 'Vector2') {
        return ok(LuminaPinType.vector2D, const _TypeRef('Vector2', vectorMath: true));
      }
      if (_isLumina(element, 'LuminaRotator', 'package:lumina/src/blueprint/blueprint_model.dart')) {
        return ok(LuminaPinType.rotator, const _TypeRef('LuminaRotator'));
      }
      final actor = _isLumina(element, 'LuminaActor', 'package:lumina/src/object/actor.dart') ||
          type.allSupertypes.any((s) => _isLumina(s.element, 'LuminaActor', 'package:lumina/src/object/actor.dart'));
      if (actor && type.typeArguments.isEmpty) {
        final name = element.name ?? '';
        if (name.startsWith('_')) {
          return (type: null, ref: null, error: 'has the private type $name, which generated code cannot name.');
        }
        final ref = _TypeRef(name, library: uri.startsWith('package:lumina/') ? null : uri, nullable: nullable);
        return (type: LuminaPinType.object, ref: ref, error: null);
      }
    }
    return (type: null, ref: null, error: 'has type ${describe()}, which no Blueprint pin carries $supported.');
  }

  /// A parameter default as the pin stores it; null when it cannot be one.
  static Object? _defaultOf(LuminaPinType type, DartObject value) {
    if (value.isNull) return null;
    switch (type) {
      case LuminaPinType.float:
        return value.toDoubleValue() ?? value.toIntValue()?.toDouble();
      case LuminaPinType.integer:
        return value.toIntValue();
      case LuminaPinType.boolean:
        return value.toBoolValue();
      case LuminaPinType.string:
        return value.toStringValue();
      case LuminaPinType.rotator:
        final xyz = [for (final f in const ['x', 'y', 'z']) value.getField(f)?.toDoubleValue()];
        return xyz.contains(null) ? null : [for (final v in xyz) v!];
      default:
        return null;
    }
  }
}

/// A doc comment's text without its `///` / `/** */` markers.
String? _docText(String? comment) {
  if (comment == null) return null;
  final lines = <String>[];
  for (var line in const LineSplitter().convert(comment)) {
    line = line.trim();
    if (line.startsWith('///')) {
      line = line.substring(3);
    } else {
      if (line.startsWith('/**')) line = line.substring(3);
      if (line.endsWith('*/')) line = line.substring(0, line.length - 2);
      if (line.startsWith('*')) line = line.substring(1);
    }
    lines.add(line.startsWith(' ') ? line.substring(1) : line);
  }
  final text = lines.join('\n').trim();
  return text.isEmpty ? null : text;
}

/// `applyDamage` → "Apply Damage", `getHUDText` → "Get HUD Text".
String _words(String name) {
  final spaced = name
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z0-9])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}');
  return spaced
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
