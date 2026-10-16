/// Reads the shader side of the `.mat` language from Filament's
/// `shaders/src`: the functions marked `@public-api` (with their
/// `@deprecated` notes, and the expression a deprecated getter returns, which
/// is what replaces a call to it) and the fields of `MaterialInputs` and
/// `MaterialVertexInputs` with the shading models and the material API level
/// their preprocessor conditions allow. Pure Dart.
library;

/// The shading models and the macro each one defines.
const shadingModelMacros = {
  'lit': 'SHADING_MODEL_LIT',
  'subsurface': 'SHADING_MODEL_SUBSURFACE',
  'cloth': 'SHADING_MODEL_CLOTH',
  'unlit': 'SHADING_MODEL_UNLIT',
  'specularGlossiness': 'SHADING_MODEL_SPECULAR_GLOSSINESS',
};

/// A shader stage of a public API: `any`, `vertex`, `fragment` or `compute`.
typedef ShaderStageName = String;

/// A function marked `@public-api` in Filament's shaders.
class ShaderApiFunction {
  final String name;

  /// The signature with Filament's type names (`float3 getWorldOffset()`).
  final String signature;
  final String returnType;
  final ShaderStageName stage;

  /// The `@deprecated` note; null when the function is current.
  final String? deprecated;

  /// For a deprecated function without arguments whose body is one
  /// `return <expression>;`: that expression, which a call can be replaced with.
  final String? replacement;

  /// The shader file that declares it.
  final String file;

  const ShaderApiFunction({
    required this.name,
    required this.signature,
    required this.returnType,
    required this.stage,
    required this.file,
    this.deprecated,
    this.replacement,
  });
}

/// A field of `MaterialInputs` or `MaterialVertexInputs` as the shaders declare it.
class CodeStructField {
  final String name;

  /// The type with Filament's names (`float3`).
  final String glslType;

  /// The shading models the field exists with; empty means all.
  final List<String> shadingModels;

  /// The lowest material API level the field exists at.
  final int apiLevel;

  const CodeStructField(this.name, this.glslType, {this.shadingModels = const [], this.apiLevel = 1});
}

class FilamentShaderCode {
  final List<ShaderApiFunction> functions;
  final List<CodeStructField> materialInputs;
  final List<CodeStructField> vertexInputs;
  const FilamentShaderCode(this.functions, this.materialInputs, this.vertexInputs);

  /// [shaders]: file name → contents, for the files of `shaders/src`.
  static FilamentShaderCode parse(Map<String, String> shaders) {
    final functions = <ShaderApiFunction>[];
    final seen = <String>{};
    List<CodeStructField> fragment = const [];
    List<CodeStructField> vertex = const [];
    for (final name in shaders.keys.toList()..sort()) {
      final source = shaders[name]!.replaceAll('\r\n', '\n');
      for (final f in _publicApi(name, source)) {
        if (seen.add('${f.stage} ${f.signature}')) functions.add(f);
      }
      if (source.contains('struct MaterialInputs {')) fragment = _structFields(source, 'MaterialInputs');
      if (source.contains('struct MaterialVertexInputs {')) vertex = _structFields(source, 'MaterialVertexInputs');
    }
    return FilamentShaderCode(functions, fragment, vertex);
  }

  static ShaderStageName _stageOf(String file) => switch (file.split('.').last) {
    'fs' => 'fragment',
    'vs' => 'vertex',
    'cs' => 'compute',
    _ => 'any',
  };

  /// GLSL type names → the names Filament's documentation uses.
  static String filamentType(String glsl) => glsl
      .replaceAll(RegExp(r'\b(highp|mediump|lowp|const|in)\s+'), '')
      .replaceAllMapped(RegExp(r'\b([iu]?)vec([234])\b'), (m) => '${switch (m[1]) {
            'i' => 'int',
            'u' => 'uint',
            _ => 'float',
          }}${m[2]}')
      .replaceAll(RegExp(r'\bmat3\b'), 'float3x3')
      .replaceAll(RegExp(r'\bmat4\b'), 'float4x4')
      .trim();

  static List<ShaderApiFunction> _publicApi(String file, String source) {
    final out = <ShaderApiFunction>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('@public-api')) continue;
      final tag = lines[i];
      var j = i + 1;
      while (j < lines.length && (lines[j].trim().isEmpty || lines[j].trim().startsWith('//') || lines[j].trim().startsWith('*'))) {
        j++;
      }
      if (j >= lines.length || lines[j].trim().startsWith('#')) continue;
      final declaration = StringBuffer(lines[j].trim());
      while (!declaration.toString().contains(')') && j + 1 < lines.length) {
        declaration.write(' ${lines[++j].trim()}');
      }
      final m = RegExp(r'^(.*?)\b(\w+)\s*\(([^)]*)\)').firstMatch(declaration.toString());
      if (m == null) continue;
      final returnType = filamentType(m[1]!);
      final params = m[3]!.trim().isEmpty
          ? ''
          : m[3]!.split(',').map((p) => filamentType(p.trim())).join(', ');
      final deprecatedAt = tag.indexOf('@deprecated');
      final deprecated = deprecatedAt < 0
          ? null
          : tag.substring(deprecatedAt + '@deprecated'.length).replaceAll('*/', '').trim();
      String? replacement;
      if (deprecated != null && params.isEmpty) {
        final rest = lines.skip(j).take(6).join(' ');
        final body = RegExp(r'\{\s*return\s+([^;]+);\s*\}').firstMatch(rest);
        replacement = body?[1]?.trim();
      }
      out.add(ShaderApiFunction(
        name: m[2]!,
        signature: '$returnType ${m[2]}($params)',
        returnType: returnType,
        stage: _stageOf(file),
        file: file,
        deprecated: deprecated,
        replacement: replacement,
      ));
    }
    return out;
  }

  /// The fields of `struct <name> { … };`, each with the shading models and
  /// the lowest API level for which some choice of the material's optional
  /// features (`MATERIAL_HAS_…`, attributes, refraction type) reaches it.
  static List<CodeStructField> _structFields(String source, String struct) {
    final start = source.indexOf('struct $struct {');
    final end = source.indexOf('\n};', start);
    final frames = <_Frame>[];
    final byName = <String, (String, Set<String>, int)>{};
    final order = <String>[];
    for (final raw in source.substring(start, end).split('\n').skip(1)) {
      final line = raw.trim();
      final directive = RegExp(r'^#\s*(ifdef|ifndef|if|elif|else|endif)\b\s*(.*?)\s*(//.*)?$').firstMatch(line);
      if (directive != null) {
        final expr = directive[2]!;
        switch (directive[1]) {
          case 'ifdef':
            frames.add(_Frame('defined($expr)'));
          case 'ifndef':
            frames.add(_Frame('!defined($expr)'));
          case 'if':
            frames.add(_Frame(expr));
          case 'elif':
            frames.last.next(expr);
          case 'else':
            frames.last.next('1');
          case 'endif':
            frames.removeLast();
        }
        continue;
      }
      final field = RegExp(r'^(\w+)\s+(\w+)\s*;').firstMatch(line);
      if (field == null || field[2]!.toUpperCase() == field[2]) continue;
      final path = [for (final f in frames) f.condition];
      final models = <String>{};
      var level = 0;
      for (final MapEntry(key: model, value: macro) in shadingModelMacros.entries) {
        for (final api in const [1, 2]) {
          if (_Preprocessor.reachable(path, macro, api)) {
            models.add(model);
            if (level == 0 || api < level) level = api;
            break;
          }
        }
      }
      if (models.isEmpty) continue; // only above the stable API levels
      final name = field[2]!;
      final previous = byName[name];
      if (previous == null) {
        order.add(name);
        byName[name] = (filamentType(field[1]!), models, level);
      } else {
        byName[name] = (previous.$1, {...previous.$2, ...models}, previous.$3 < level ? previous.$3 : level);
      }
    }
    return [
      for (final name in order)
        CodeStructField(
          name,
          byName[name]!.$1,
          shadingModels: byName[name]!.$2.length == shadingModelMacros.length
              ? const []
              : [for (final m in shadingModelMacros.keys) if (byName[name]!.$2.contains(m)) m],
          apiLevel: byName[name]!.$3,
        ),
    ];
  }
}

/// One `#if` … `#endif` level: the branch taken now is [condition].
class _Frame {
  final List<String> _earlier = [];
  String _current;
  _Frame(this._current);

  void next(String expr) {
    _earlier.add(_current);
    _current = expr;
  }

  /// This branch, and none of the earlier ones of the same `#if`.
  String get condition => [for (final e in _earlier) '!($e)', '($_current)'].join(' && ');
}

/// Evaluates `#if` conditions for one shading model and API level, with the
/// other macros (a material's optional features) free: a path is reachable
/// when some assignment of them makes every condition true.
class _Preprocessor {
  static const _unstableApiLevel = 99;

  static bool reachable(List<String> conditions, String modelMacro, int apiLevel) {
    final free = <String>{};
    for (final c in conditions) {
      for (final m in RegExp(r'[A-Za-z_]\w*').allMatches(c)) {
        final id = m[0]!;
        if (id == 'defined' || id.startsWith('SHADING_MODEL_') || _fixed(id, apiLevel) != null) continue;
        free.add(id);
      }
    }
    final names = free.toList();
    for (var mask = 0; mask < (1 << names.length); mask++) {
      final env = {for (var i = 0; i < names.length; i++) names[i]: (mask >> i) & 1};
      int lookup(String id) => id.startsWith('SHADING_MODEL_')
          ? (id == modelMacro ? 1 : 0)
          : _fixed(id, apiLevel) ?? env[id] ?? 0;
      if (conditions.every((c) => _Expr(c, lookup).evaluate() != 0)) return true;
    }
    return false;
  }

  static int? _fixed(String id, int apiLevel) => switch (id) {
    'CLIENT_MATERIAL_API_LEVEL' => apiLevel,
    'UNSTABLE_MATERIAL_API_LEVEL' => _unstableApiLevel,
    'REFRACTION_TYPE_SOLID' => 0,
    'REFRACTION_TYPE_THIN' => 1,
    _ => null,
  };
}

/// A recursive-descent evaluator of preprocessor expressions (`defined`, `!`,
/// `&&`, `||`, comparisons, integers and macros).
class _Expr {
  final List<String> _tokens;
  final int Function(String) _lookup;
  int _at = 0;

  _Expr(String source, this._lookup)
      : _tokens = [for (final m in RegExp(r'\d+|[A-Za-z_]\w*|&&|\|\||==|!=|>=|<=|[!()<>]').allMatches(source)) m[0]!];

  String? get _peek => _at < _tokens.length ? _tokens[_at] : null;
  String _take() => _tokens[_at++];

  int evaluate() => _or();

  int _or() {
    var v = _and();
    while (_peek == '||') {
      _take();
      final r = _and();
      v = (v != 0 || r != 0) ? 1 : 0;
    }
    return v;
  }

  int _and() {
    var v = _compare();
    while (_peek == '&&') {
      _take();
      final r = _compare();
      v = (v != 0 && r != 0) ? 1 : 0;
    }
    return v;
  }

  int _compare() {
    final left = _unary();
    const ops = {'==', '!=', '>=', '<=', '>', '<'};
    if (!ops.contains(_peek)) return left;
    final op = _take();
    final right = _unary();
    final result = switch (op) {
      '==' => left == right,
      '!=' => left != right,
      '>=' => left >= right,
      '<=' => left <= right,
      '>' => left > right,
      _ => left < right,
    };
    return result ? 1 : 0;
  }

  int _unary() {
    final t = _take();
    if (t == '!') return _unary() == 0 ? 1 : 0;
    if (t == '(') {
      final v = _or();
      _take(); // ')'
      return v;
    }
    if (t == 'defined') {
      final paren = _peek == '(';
      if (paren) _take();
      final id = _take();
      if (paren) _take();
      return _lookup(id) != 0 ? 1 : 0;
    }
    return int.tryParse(t) ?? _lookup(t);
  }
}
