import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina/data/services/engine_logger_service.dart';
import 'package:flutter_filament/flutter_filament.dart';

import '../../main_editor/commands/editor_transaction.dart';
import 'material_graph_controller.dart';

enum MaterialCompileSeverity {
  error,
  warning,
  info,
}

class MaterialCompileIssue {
  final int line;
  final String message;
  final MaterialCompileSeverity severity;

  /// The graph node the issue is about (a type error), when it comes from
  /// the node graph rather than a source line.
  final String? nodeId;

  const MaterialCompileIssue({
    required this.line,
    required this.message,
    this.severity = MaterialCompileSeverity.error,
    this.nodeId,
  });
}

/// Abstract compiler runner to facilitate testing in environments without native Filament binaries.
abstract class FilamatCompilerRunner {
  /// [parameters] are the uniforms and samplers the `.mat` header declares, and
  /// [requiredAttributes] the vertex attributes its `requires : [ … ]` block
  /// asks for (`VertexAttribute` indices — `uv0` is 3). Both have to reach the
  /// builder: the compiler only sees the fragment body, so anything the header
  /// declares but the builder is not told about leaves every `materialParams…`
  /// reference undefined.
  Future<Uint8List?> compile({
    required String name,
    required String code,
    required FilamatShading shading,
    required BlendingMode blending,
    required bool doubleSided,
    List<MaterialParamModel> parameters = const [],
    Set<int> requiredAttributes = const {},
  });
}

/// `VertexAttribute` indices, as `filament/libs/filabridge/include/filament/MaterialEnums.h`
/// defines them. Only the ones a `.mat` `requires` block can name are listed.
class MaterialVertexAttribute {
  static const int color = 2;
  static const int uv0 = 3;
  static const int uv1 = 4;

  static int? fromName(String name) => switch (name.trim().toLowerCase()) {
        'color' => color,
        'uv0' => uv0,
        'uv1' => uv1,
        _ => null,
      };
}

class DefaultFilamatCompilerRunner implements FilamatCompilerRunner {
  static bool _engineInitialized = false;

  @override
  Future<Uint8List?> compile({
    required String name,
    required String code,
    required FilamatShading shading,
    required BlendingMode blending,
    required bool doubleSided,
    List<MaterialParamModel> parameters = const [],
    Set<int> requiredAttributes = const {},
  }) async {
    try {
      if (!_engineInitialized) {
        FilamentMaterialBuilder.initEngine();
        _engineInitialized = true;
      }
      final builder = FilamentMaterialBuilder.create();
      builder.setName(name);
      builder.setCode(code);
      builder.setShading(shading);
      builder.blending(blending);
      builder.setDoubleSided(doubleSided);

      for (final attribute in requiredAttributes) {
        builder.requireAttribute(attribute);
      }
      for (final parameter in parameters) {
        if (parameter.isSampler) {
          builder.addSamplerParameter(parameter.name);
          continue;
        }
        final uniformType = uniformTypeFor(parameter.type);
        if (uniformType == null) {
          // Dropping a declared parameter silently is what made every textured
          // material fail to compile; say so instead.
          EngineLoggerService().log(
            'Material "$name" declares parameter "${parameter.name}" of type '
            '${parameter.type.name}, which has no UniformType mapping — it will not '
            'be visible to the shader.',
            level: 'warning',
            source: 'FilamatCompiler',
          );
          continue;
        }
        builder.addParameter(parameter.name, uniformType);
      }

      final bytes = builder.build();
      builder.dispose();
      return bytes;
    } catch (e, st) {
      EngineLoggerService().log('DefaultFilamatCompilerRunner failed: $e\n$st', level: 'error');
      return null;
    }
  }
}

/// Maps an editor-side parameter type onto the builder's [UniformType].
/// Returns null for [MaterialParamType.sampler2dType], which goes through
/// `addSamplerParameter` instead, and for anything without a mapping.
UniformType? uniformTypeFor(MaterialParamType type) => switch (type) {
      MaterialParamType.floatType => UniformType.floatType,
      MaterialParamType.vec2Type => UniformType.float2,
      MaterialParamType.vec3Type => UniformType.float3,
      MaterialParamType.vec4Type => UniformType.float4,
      MaterialParamType.colorType => UniformType.float4,
      MaterialParamType.boolType => UniformType.boolType,
      MaterialParamType.sampler2dType => null,
    };

enum MaterialParamType {
  floatType,
  colorType,
  sampler2dType,
  boolType,
  vec2Type,
  vec3Type,
  vec4Type,
}

class MaterialParamModel {
  final String name;
  final MaterialParamType type;
  dynamic value;
  final double min;
  final double max;
  final bool isSampler;
  AssetReference? textureRef;

  /// [textureRef]'s path made absolute, for anything that has to open the file.
  ///
  /// References are stored project-relative so a project stays portable; the
  /// preview renderer needs a real path. Runtime only — never persisted.
  String? resolvedTexturePath;

  MaterialParamModel({
    required this.name,
    required this.type,
    this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.isSampler = false,
    this.textureRef,
  });
}

class MaterialEditorViewModel extends ChangeNotifier {
  final String assetPath;
  final FilamatCompilerRunner compilerRunner;

  LuminaAsset? _asset;
  String _currentCode = '';
  String _onDiskCode = '';
  Uint8List? _compiledBytes;
  int _elapsedMs = 0;
  bool _isCompiling = false;
  String _syntaxStatus = 'Syntax OK';
  List<MaterialCompileIssue> _issues = [];
  int _bodyLineOffset = 0;

  FilamatShading _shading = FilamatShading.lit;
  BlendingMode _blending = BlendingMode.opaque;
  bool _doubleSided = false;
  List<MaterialParamModel> _parameters = [];
  bool _isParamDirty = false;

  /// The material as a node graph: the other view of [currentCode].
  late final MaterialGraphController graph = MaterialGraphController(this);

  // Callbacks for live write-through without recompile
  void Function(Uint8List compiledBytes)? onHotApply;
  void Function(String name, dynamic value)? onParamChanged;

  MaterialEditorViewModel({
    required this.assetPath,
    LuminaAsset? initialAsset,
    FilamatCompilerRunner? compilerRunner,
  })  : _asset = initialAsset,
        compilerRunner = compilerRunner ?? DefaultFilamatCompilerRunner() {
    if (_asset != null) {
      _currentCode = _asset!.rawMatSource;
      _onDiskCode = _asset!.rawMatSource;
      _compiledBytes = _asset!.rawPayload;
      _shading = _parseShadingModel(_currentCode);
      _blending = _parseBlendingMode(_currentCode);
      _doubleSided = _currentCode.contains('doubleSided : true') || _currentCode.contains('doubleSided: true');
      _parseParameters();
      graph.restore(_asset!.metadata['material_graph']);
    }
  }

  LuminaAsset? get asset => _asset;
  String get currentCode => _currentCode;
  Uint8List? get compiledBytes => _compiledBytes;
  int get elapsedMs => _elapsedMs;
  bool get isCompiling => _isCompiling;
  String get syntaxStatus => _syntaxStatus;
  List<MaterialCompileIssue> get issues => List.unmodifiable(_issues);
  int get bodyLineOffset => _bodyLineOffset;
  bool get isDirty => (_currentCode != _onDiskCode) || _isParamDirty || graph.isLayoutDirty || graph.isAhead;
  FilamatShading get shading => _shading;
  BlendingMode get blending => _blending;
  bool get doubleSided => _doubleSided;
  List<MaterialParamModel> get parameters => List.unmodifiable(_parameters);

  set currentCode(String value) {
    if (_currentCode != value) {
      _currentCode = value;
      _validateDartSyntax();
      notifyListeners();
    }
  }

  /// Updates code directly from the text editor without triggering continuous rebuild loops.
  void updateCodeFromEditor(String value) {
    if (_currentCode != value) {
      final wasDirty = isDirty;
      _currentCode = value;
      _validateDartSyntax();
      if (wasDirty != isDirty) {
        notifyListeners();
      }
    }
  }

  /// The tab's own undo stack, as the Blueprint editor has.
  final TransactionManager transactions = TransactionManager();

  /// Replaces the whole source as one undo step (`set_material_source`).
  /// Its undo refuses — the step stays on the stack, a warning is logged —
  /// when the source was changed since (the user typed), so typed text is
  /// never overwritten; redo refuses likewise.
  void replaceSourceWithTransaction(String source, {String label = 'Set Material Source'}) {
    final before = _currentCode;
    final after = source;
    if (before == after) return;
    currentCode = after;
    transactions.record(EditorTransaction(
      label: label,
      undo: () {
        if (_currentCode != after) {
          throw const TransactionRefused('the source changed since; undo would overwrite those edits');
        }
        currentCode = before;
      },
      redo: () {
        if (_currentCode != before) {
          throw const TransactionRefused('the source changed since; redo would overwrite those edits');
        }
        currentCode = after;
      },
    ));
  }

  /// Undo / redo on this tab; a refused step is logged and stays.
  void undo() => _applyHistory(transactions.undo, 'Undo');
  void redo() => _applyHistory(transactions.redo, 'Redo');

  void _applyHistory(void Function() apply, String verb) {
    try {
      apply();
    } on TransactionRefused catch (e) {
      EngineLoggerService().log('$verb refused on ${assetPath.split(RegExp(r'[\\/]')).last}: ${e.message}',
          level: 'warning', source: 'MaterialEditor');
    }
  }

  /// Loads the asset from the given [assetPath].
  Future<void> load() async {
    final file = File(assetPath);
    if (!file.existsSync()) {
      _asset = LuminaAsset(
        assetId: file.uri.pathSegments.last,
        name: file.uri.pathSegments.last.replaceAll('.lmas', ''),
        type: AssetType.filamat,
        rawMatSource: _defaultTemplate(file.uri.pathSegments.last.replaceAll('.lmas', '')),
      );
    } else {
      final bytes = await file.readAsBytes();
      _asset = LuminaAsset.fromBytes(bytes);
    }

    _currentCode = _asset!.rawMatSource;
    _onDiskCode = _asset!.rawMatSource;
    _compiledBytes = _asset!.rawPayload;
    _availableTextures = null;
    graph.restore(_asset!.metadata['material_graph']);
    // Re-read everything the header declares. Without this a material opened
    // from disk reports zero parameters in the inspector and hands the compiler
    // nothing, so every `materialParams…` reference it uses is undefined.
    _shading = _parseShadingModel(_currentCode);
    _blending = _parseBlendingMode(_currentCode);
    _doubleSided = _currentCode.contains('doubleSided : true') ||
        _currentCode.contains('doubleSided: true');
    _parseParameters();
    _validateDartSyntax();
    notifyListeners();

    // A material saved from this editor carries its compiled bytes; one emitted
    // by the importer carries only source. Without bytes the 3D preview has no
    // material to put on the sphere and falls back to the default colour, so
    // opening an imported material showed nothing of the material. Compile it
    // once on open.
    if ((_compiledBytes == null || _compiledBytes!.isEmpty) &&
        _currentCode.trim().isNotEmpty) {
      await compile();
    }
  }

  /// Validates Dart-side structural constraints and maps line offsets.
  void _validateDartSyntax() {
    final text = _currentCode;
    _issues = [];

    int openBraces = 0;
    int closeBraces = 0;
    final lines = text.split('\n');

    int materialBlockLine = -1;
    int fragmentBlockLine = -1;
    int prepareMaterialLine = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '{') openBraces++;
        if (line[j] == '}') closeBraces++;
      }
      if (line.contains('material') && line.contains('{') && materialBlockLine == -1) {
        materialBlockLine = i + 1;
      }
      if (line.contains('fragment') && line.contains('{') && fragmentBlockLine == -1) {
        fragmentBlockLine = i + 1;
      }
      if (line.contains('prepareMaterial') && prepareMaterialLine == -1) {
        prepareMaterialLine = i + 1;
      }
    }

    // Determine bodyLineOffset (where the fragment/material body begins)
    final fragIndex = text.indexOf('void material');
    if (fragIndex != -1) {
      final beforeFrag = text.substring(0, fragIndex);
      _bodyLineOffset = beforeFrag.split('\n').length;
    } else {
      _bodyLineOffset = fragmentBlockLine > 0 ? fragmentBlockLine : 1;
    }

    if (openBraces != closeBraces) {
      _issues.add(MaterialCompileIssue(
        line: lines.length,
        message: 'Unmatched braces: $openBraces open vs $closeBraces close',
        severity: MaterialCompileSeverity.error,
      ));
      _syntaxStatus = 'Syntax Error: Unmatched braces';
    } else if (materialBlockLine == -1 && fragmentBlockLine == -1) {
      _issues.add(const MaterialCompileIssue(
        line: 1,
        message: 'Missing material {} or fragment {} block',
        severity: MaterialCompileSeverity.error,
      ));
      _syntaxStatus = 'Syntax Error: Missing blocks';
    } else if (prepareMaterialLine == -1 && text.contains('fragment')) {
      _issues.add(MaterialCompileIssue(
        line: fragmentBlockLine > 0 ? fragmentBlockLine : 1,
        message: 'Missing prepareMaterial(material) call in fragment shader',
        severity: MaterialCompileSeverity.error,
      ));
      _syntaxStatus = 'Syntax Error: Missing prepareMaterial';
    } else {
      _syntaxStatus = 'Syntax OK';
    }
  }

  /// Extracts parameter names declared in parameters {} or material {} block for autocomplete.
  List<String> extractDeclaredParameters() {
    final results = <String>{};
    final paramRegex = RegExp(r'(\bfloat\b|\bvec2\b|\bvec3\b|\bvec4\b|\bmat3\b|\bmat4\b|\bsampler2d\b)\s+([a-zA-Z0-9_]+)', caseSensitive: false);
    for (final match in paramRegex.allMatches(_currentCode)) {
      final name = match.group(2);
      if (name != null && name.isNotEmpty) {
        results.add(name);
        results.add('material.$name');
        results.add('materialParams.$name');
      }
    }
    return results.toList();
  }

  /// Reads the header's `requires : [ uv0, … ]` block into `VertexAttribute`
  /// indices. `getUV0()` in a fragment is only valid when UV0 is required.
  static Set<int> _parseRequiredAttributes(String source) {
    final match = RegExp(r'requires\s*:\s*\[([^\]]*)\]').firstMatch(source);
    if (match == null) return const {};
    final result = <int>{};
    for (final raw in (match.group(1) ?? '').split(',')) {
      final attribute = MaterialVertexAttribute.fromName(raw);
      if (attribute != null) result.add(attribute);
    }
    return result;
  }

  /// Compiles the current GLSL source using the filamat compiler.
  Future<bool> compile() async {
    if (graph.isAhead && graph.analysis.hasErrors) {
      // The source is older than the graph: compiling it would preview a
      // material the graph no longer describes.
      showGraphIssues(graph.issues);
      return false;
    }
    _validateDartSyntax();
    // Declarations edited by hand reach the builder too.
    _reparseParametersKeepingValues();
    if (_issues.any((i) => i.severity == MaterialCompileSeverity.error)) {
      notifyListeners();
      return false;
    }

    _isCompiling = true;
    notifyListeners();

    final stopwatch = Stopwatch()..start();

    // Extract fragment code body or pass the full fragment block
    final codeToCompile = _extractFragmentBody(_currentCode);
    final shading = _parseShadingModel(_currentCode);
    final blending = _parseBlendingMode(_currentCode);
    final doubleSided = _currentCode.contains('doubleSided : true') || _currentCode.contains('doubleSided: true');
    final name = _asset?.name ?? 'Material';

    final bytes = await compilerRunner.compile(
      name: name,
      code: codeToCompile,
      shading: shading,
      blending: blending,
      doubleSided: doubleSided,
      parameters: _parameters,
      requiredAttributes: _parseRequiredAttributes(_currentCode),
    );

    stopwatch.stop();
    _elapsedMs = stopwatch.elapsedMilliseconds;
    _isCompiling = false;

    if (bytes != null && bytes.isNotEmpty) {
      _compiledBytes = bytes;
      _issues = [
        MaterialCompileIssue(
          line: 1,
          message: 'Compilation successful (${bytes.length} bytes in ${_elapsedMs}ms)',
          severity: MaterialCompileSeverity.info,
        ),
      ];
      if (graph.isInitialized) {
        _issues.addAll(graph.issues.where((i) => i.severity != MaterialCompileSeverity.error));
      }
      _syntaxStatus = 'Compile OK (${bytes.length} B, ${_elapsedMs}ms)';
      onHotApply?.call(bytes);
      EngineLoggerService().log('Compiled material "$name" (${bytes.length} bytes) in ${_elapsedMs}ms', level: 'info');
      notifyListeners();
      return true;
    } else {
      _issues = [
        const MaterialCompileIssue(
          line: 1,
          message: 'filamat backend rejected the source (compile failed)',
          severity: MaterialCompileSeverity.error,
        ),
      ];
      _syntaxStatus = 'Compile Error';
      EngineLoggerService().log('filamat backend compilation failed for material "$name"', level: 'error');
      notifyListeners();
      return false;
    }
  }

  /// Extracts the fragment material(...) body from the full .mat string.
  String _extractFragmentBody(String source) {
    final fragIndex = source.indexOf('fragment {');
    if (fragIndex != -1) {
      final afterFrag = source.substring(fragIndex + 10);
      final lastBrace = afterFrag.lastIndexOf('}');
      if (lastBrace != -1) {
        return afterFrag.substring(0, lastBrace).trim();
      }
      return afterFrag.trim();
    }
    return source;
  }

  FilamatShading _parseShadingModel(String source) {
    if (source.contains('shadingModel : unlit') || source.contains('shadingModel: unlit')) {
      return FilamatShading.unlit;
    }
    if (source.contains('shadingModel : cloth') || source.contains('shadingModel: cloth')) {
      return FilamatShading.cloth;
    }
    if (source.contains('shadingModel : subsurface') || source.contains('shadingModel: subsurface')) {
      return FilamatShading.subsurface;
    }
    return FilamatShading.lit;
  }

  BlendingMode _parseBlendingMode(String source) {
    if (source.contains('blending : transparent') || source.contains('blending: transparent')) {
      return BlendingMode.transparent;
    }
    if (source.contains('blending : masked') || source.contains('blending: masked')) {
      return BlendingMode.masked;
    }
    if (source.contains('blending : add') || source.contains('blending: add')) {
      return BlendingMode.add;
    }
    return BlendingMode.opaque;
  }

  /// Gets parameter value by name.
  dynamic getParamValue(String name) {
    try {
      return _parameters.firstWhere((p) => p.name == name).value;
    } catch (_) {
      return null;
    }
  }

  /// Sets a parameter value, calls the onParamChanged write-through hook, and marks the editor dirty.
  void setParam(String name, dynamic value) {
    try {
      final param = _parameters.firstWhere((p) => p.name == name);
      if (param.value != value) {
        param.value = value;
        onParamChanged?.call(name, value);
        _isParamDirty = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Sets a texture slot reference for a sampler parameter.
  void setTextureReference(String paramName, {required String assetId, required String assetPath}) {
    try {
      final param = _parameters.firstWhere((p) => p.name == paramName);
      param.textureRef = AssetReference(
        slotName: paramName,
        assetId: assetId,
        assetPath: assetPath,
      );
      param.resolvedTexturePath = resolveProjectPath(assetPath);
      _isParamDirty = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Clears a texture reference slot.
  void clearTextureReference(String paramName) {
    try {
      final param = _parameters.firstWhere((p) => p.name == paramName);
      param.textureRef = null;
      param.resolvedTexturePath = null;
      _isParamDirty = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Updates material header settings and recompiles.
  Future<void> updateHeaderSettings({
    FilamatShading? shading,
    BlendingMode? blending,
    bool? doubleSided,
  }) async {
    if (shading != null) _shading = shading;
    if (blending != null) _blending = blending;
    if (doubleSided != null) _doubleSided = doubleSided;

    // Rewrite header in _currentCode
    final previousCode = _currentCode;
    String updated = _currentCode;
    final shadingStr = _shading.name;
    final blendingStr = _blending.name;

    if (updated.contains('shadingModel :') || updated.contains('shadingModel:')) {
      updated = updated.replaceAll(RegExp(r'shadingModel\s*:\s*[a-zA-Z0-9_]+'), 'shadingModel : $shadingStr');
    } else if (updated.contains('material {')) {
      updated = updated.replaceFirst('material {', 'material {\n    shadingModel : $shadingStr,');
    }

    if (updated.contains('blending :') || updated.contains('blending:')) {
      updated = updated.replaceAll(RegExp(r'blending\s*:\s*[a-zA-Z0-9_]+'), 'blending : $blendingStr');
    } else if (updated.contains('material {')) {
      updated = updated.replaceFirst('material {', 'material {\n    blending : $blendingStr,');
    }

    if (updated.contains('doubleSided :') || updated.contains('doubleSided:')) {
      updated = updated.replaceAll(RegExp(r'doubleSided\s*:\s*[a-zA-Z0-9_]+'), 'doubleSided : $_doubleSided');
    } else if (_doubleSided && updated.contains('material {')) {
      updated = updated.replaceFirst('material {', 'material {\n    doubleSided : true,');
    }

    _currentCode = updated;
    _validateDartSyntax();
    // Same fragment, new surface: the graph stays, its pins are re-checked.
    graph.headerChanged(previousCode);
    await compile();
    notifyListeners();
  }

  /// Takes source the node graph generated: re-reads what its header
  /// declares (keeping the panel's values and texture bindings) and lists
  /// the graph's warnings. Compiling stays explicit (Apply / Compile).
  void applyGraphSource(String code, List<MaterialCompileIssue> graphIssues) {
    _currentCode = code;
    _shading = _parseShadingModel(code);
    _blending = _parseBlendingMode(code);
    _doubleSided = code.contains('doubleSided : true') || code.contains('doubleSided: true');
    _validateDartSyntax();
    _reparseParametersKeepingValues();
    if (!_issues.any((i) => i.severity == MaterialCompileSeverity.error)) {
      _issues = [...graphIssues];
      _syntaxStatus = code == _onDiskCode ? 'Syntax OK' : 'Graph edited — Apply to compile';
    }
    notifyListeners();
  }

  /// Shows why the graph cannot be written as source (its type errors).
  void showGraphIssues(List<MaterialCompileIssue> graphIssues) {
    _issues = [...graphIssues];
    final errors = graphIssues.where((i) => i.severity == MaterialCompileSeverity.error).length;
    _syntaxStatus = 'Graph Error ($errors)';
    notifyListeners();
  }

  /// Nodes moved: nothing to regenerate, but there is something to save.
  void graphLayoutChanged() => notifyListeners();

  /// Re-reads the header's parameters, keeping each surviving parameter's
  /// panel value and texture binding.
  void _reparseParametersKeepingValues() {
    final previous = {for (final p in _parameters) p.name: p};
    _parseParameters();
    for (final p in _parameters) {
      final old = previous[p.name];
      if (old == null || old.type != p.type) continue;
      p.value = old.value;
      p.textureRef = old.textureRef;
      p.resolvedTexturePath = old.resolvedTexturePath;
    }
  }

  /// Parses declared parameters from the parameters block or material inputs in the source.
  void _parseParameters() {
    _parameters = [];
    final text = _currentCode;

    // 1. Parse parameter items in material header / parameters block
    final headerSection = text.contains('fragment {') 
        ? text.substring(0, text.indexOf('fragment {')) 
        : text;

    if (headerSection.contains('parameters') || headerSection.contains('type')) {
      final itemBlockRegex = RegExp(r'\{([^{}]+)\}');
      for (final itemMatch in itemBlockRegex.allMatches(headerSection)) {
        final itemText = itemMatch.group(1) ?? '';
        final typeMatch = RegExp(r'type\s*:\s*([a-zA-Z0-9_]+)').firstMatch(itemText);
        final nameMatch = RegExp(r'name\s*:\s*([a-zA-Z0-9_]+)').firstMatch(itemText);
        final defaultMatch = RegExp(r'default\s*:\s*(\[[^\]]+\]|[^,}]+)').firstMatch(itemText);

        if (typeMatch == null || nameMatch == null) continue;

        final typeStr = typeMatch.group(1)?.toLowerCase() ?? '';
        final name = nameMatch.group(1) ?? '';
        final defaultStr = defaultMatch?.group(1)?.trim();

        if (name.isEmpty) continue;

        MaterialParamType type = MaterialParamType.floatType;
        dynamic defaultVal;
        bool isSampler = false;
        double min = 0.0;
        double max = 1.0;

        if (typeStr == 'float') {
          type = MaterialParamType.floatType;
          defaultVal = double.tryParse(defaultStr ?? '') ?? 0.5;
          if (name.toLowerCase().contains('normal')) max = 5.0;
        } else if (typeStr == 'float4' || typeStr == 'float3' || typeStr == 'vec4' || typeStr == 'vec3' || typeStr == 'color') {
          type = MaterialParamType.colorType;
          defaultVal = _parseColorDefault(defaultStr);
        } else if (typeStr.contains('sampler')) {
          type = MaterialParamType.sampler2dType;
          isSampler = true;
        } else if (typeStr == 'bool') {
          type = MaterialParamType.boolType;
          defaultVal = defaultStr == 'true';
        }

        _parameters.add(MaterialParamModel(
          name: name,
          type: type,
          value: defaultVal,
          min: min,
          max: max,
          isSampler: isSampler,
        ));
      }
    }

    // 2. If no parameters array was defined, extract from uniforms and standard material inputs
    if (_parameters.isEmpty) {
      final declared = extractDeclaredParameters();
      for (final name in declared) {
        if (name.startsWith('material.') || name.startsWith('materialParams.')) continue;
        if (name.toLowerCase().contains('map') || name.toLowerCase().contains('tex') || name.toLowerCase().contains('sampler')) {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.sampler2dType,
            isSampler: true,
          ));
        } else if (name.toLowerCase().contains('color') || name.toLowerCase().contains('emissive')) {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.colorType,
            value: [1.0, 1.0, 1.0, 1.0],
          ));
        } else {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.floatType,
            value: 0.5,
            min: 0.0,
            max: name.toLowerCase().contains('normal') ? 5.0 : 1.0,
          ));
        }
      }
    }

    // 3. Fallback defaults, only when the material never said what it declares.
    // A header that explicitly reads `parameters : []` is an answer, not a gap —
    // fabricating a PBR set there makes the inspector lie and hands the compiler
    // uniforms the shader does not use.
    final declaresParameterBlock = RegExp(r'parameters\s*:\s*\[').hasMatch(text);
    if (_parameters.isEmpty && !declaresParameterBlock) {
      _parameters = [
        MaterialParamModel(name: 'roughness', type: MaterialParamType.floatType, value: 0.3, min: 0.0, max: 1.0),
        MaterialParamModel(name: 'metallic', type: MaterialParamType.floatType, value: 0.8, min: 0.0, max: 1.0),
        MaterialParamModel(name: 'normalStrength', type: MaterialParamType.floatType, value: 1.0, min: 0.0, max: 5.0),
        MaterialParamModel(name: 'baseColor', type: MaterialParamType.colorType, value: [0.0, 0.9, 0.46, 1.0]),
        MaterialParamModel(name: 'albedoMap', type: MaterialParamType.sampler2dType, isSampler: true),
      ];
    }

    // 4. Restore saved defaults from asset metadata
    if (_asset?.metadata['parameter_defaults'] != null) {
      try {
        dynamic parsed = _asset!.metadata['parameter_defaults'];
        if (parsed is String) {
          parsed = jsonDecode(parsed);
        }
        if (parsed is Map) {
          for (final entry in parsed.entries) {
            final param = _parameters.where((p) => p.name == entry.key).firstOrNull;
            if (param != null) {
              param.value = entry.value;
            }
          }
        }
      } catch (_) {}
    }

    // 5. Restore saved texture references
    if (_asset?.references != null) {
      for (final ref in _asset!.references) {
        if (ref.slotName.isNotEmpty) {
          final param = _parameters.where((p) => p.name == ref.slotName).firstOrNull;
          if (param != null) {
            param.textureRef = ref;
            param.resolvedTexturePath = resolveProjectPath(ref.assetPath);
          }
        }
      }
    }
  }

  /// The declared `default : [r, g, b(, a)]` of a colour/vector parameter as
  /// the four floats of the `float4` uniform it compiles to ([uniformTypeFor]):
  /// a missing alpha is opaque. White when nothing (or nothing numeric) is
  /// declared.
  static List<double> _parseColorDefault(String? declared) {
    final numbers = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?')
        .allMatches(declared ?? '')
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .take(4)
        .toList();
    if (numbers.isEmpty) return [1.0, 1.0, 1.0, 1.0];
    while (numbers.length < 4) {
      numbers.add(1.0);
    }
    return numbers;
  }

  /// The project root this material lives in: the nearest ancestor owning a
  /// `contents/` directory, or null when the asset sits outside a project.
  String? get projectRoot {
    var dir = File(assetPath).parent;
    for (var i = 0; i < 12; i++) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  List<RealAssetInfo>? _availableTextures;

  /// The project's TEXTURE assets a sampler can be bound to, scanned from
  /// [projectRoot] on first use and on every [load]; empty outside a project.
  List<RealAssetInfo> get availableTextures => _availableTextures ??= _scanTextures();

  List<RealAssetInfo> _scanTextures() {
    final root = projectRoot;
    if (root == null) return const [];
    final textures = AssetRepository().scanProjectContents(root).where((a) => a.type == AssetType.texture).toList()
      ..sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
    return List.unmodifiable(textures);
  }

  /// The project texture [param] is bound to (matched by id, then by path), or
  /// null when it has none or the file is gone.
  RealAssetInfo? textureAssetFor(MaterialParamModel param) {
    final ref = param.textureRef;
    if (ref == null) return null;
    for (final t in availableTextures) {
      if (ref.assetId.isNotEmpty && t.assetId == ref.assetId) return t;
    }
    for (final t in availableTextures) {
      if (t.relativePath == ref.assetPath || t.lmasPath == param.resolvedTexturePath) return t;
    }
    return null;
  }

  /// The name a texture row shows for [param]'s binding: the texture asset's
  /// file name without `.lmas` (the asset's own name), never its UUID.
  String? textureDisplayName(MaterialParamModel param) {
    final ref = param.textureRef;
    if (ref == null) return null;
    final file = textureAssetFor(param)?.fileName ?? ref.assetPath.split('/').last;
    return file.replaceAll(RegExp(r'\.lmas$'), '');
  }

  /// Turns a stored asset path into one that can be opened. Absolute paths and
  /// paths that already resolve are returned as they are.
  String? resolveProjectPath(String? storedPath) {
    if (storedPath == null || storedPath.isEmpty) return null;
    if (storedPath.startsWith('/') || File(storedPath).existsSync()) return storedPath;
    final root = projectRoot;
    if (root == null) return storedPath;
    return '$root/$storedPath';
  }

  /// Saves the current GLSL source, parameter defaults, texture references, and compiled payload back into the .lmas file on disk.
  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});
    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    if (_compiledBytes != null) {
      updatedMetadata['compiled_size'] = _compiledBytes!.length.toString();
    }

    // Build parameter defaults map
    final defaultsMap = <String, dynamic>{};
    for (final p in _parameters) {
      if (p.value != null && !p.isSampler) {
        defaultsMap[p.name] = p.value;
      }
    }
    updatedMetadata['parameter_defaults'] = jsonEncode(defaultsMap);
    if (graph.isInitialized) {
      graph.ensureSynced();
      updatedMetadata['material_graph'] = graph.storedJson();
    }

    // Build references list
    final refs = <AssetReference>[];
    for (final p in _parameters) {
      if (p.textureRef != null) {
        refs.add(p.textureRef!);
      }
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? file.uri.pathSegments.last,
      name: _asset?.name ?? file.uri.pathSegments.last.replaceAll('.lmas', ''),
      type: AssetType.filamat,
      hasThumbnail: _asset?.hasThumbnail ?? false,
      thumbnailPng: _asset?.thumbnailPng,
      rawPayload: _compiledBytes ?? _asset?.rawPayload,
      rawMatSource: _currentCode,
      references: refs,
      metadata: updatedMetadata,
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());

      _asset = updatedAsset;
      _onDiskCode = _currentCode;
      _isParamDirty = false;
      if (graph.isInitialized) graph.markSaved();
      EngineLoggerService().log('Saved material asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save material asset to $assetPath: $e\n$st', level: 'error');
      return false;
    }
  }

  /// Discards unsaved edits and reloads the code from disk.
  void discardChanges() {
    _currentCode = _onDiskCode;
    _isParamDirty = false;
    graph.restore(_asset?.metadata['material_graph']);
    _validateDartSyntax();
    _parseParameters();
    notifyListeners();
  }

  static String _defaultTemplate(String name) {
    return '''material {
    name : "$name",
    shadingModel : lit,
    blending : opaque,
    parameters : [
        { type : float, name : roughness, default : 0.30 },
        { type : float, name : metallic, default : 0.80 },
        { type : float, name : normalStrength, default : 1.00 },
        { type : float4, name : baseColor, default : [0.0, 0.9, 0.46, 1.0] },
        { type : sampler2d, name : albedoMap }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}''';
  }
}
