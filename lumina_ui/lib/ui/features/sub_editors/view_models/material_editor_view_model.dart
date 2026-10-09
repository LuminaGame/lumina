import 'dart:isolate';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:flutter_filament/flutter_filament.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_graph_controller.dart';

part 'material_editor_view_model/models.dart';
part 'material_editor_view_model/parameter_parsing.dart';

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
      _doubleSided = _parseDoubleSided(_currentCode);
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

  /// Loads the asset from the given [assetPath]. A missing file starts from
  /// the new-material template, which declares `flipUV : false`: meshes carry
  /// glTF texture coordinates (v = 0 at the image top), so a texture sampled
  /// with `getUV0()` draws upright (matc's default `true` turns it upside down).
  Future<void> load() async {
    final file = File(assetPath);
    if (!file.existsSync()) {
      _asset = LuminaAsset(
        assetId: file.uri.pathSegments.last,
        name: file.uri.pathSegments.last.replaceAll('.lmas', ''),
        type: AssetType.filamat,
        rawMatSource: newMaterialSource(file.uri.pathSegments.last.replaceAll('.lmas', '')),
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
    _doubleSided = _parseDoubleSided(_currentCode);
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

  /// Quick structural hints while typing (blocks and braces, read like the
  /// compiler reads them: comments and strings skipped) and the line where the
  /// fragment body starts. They only fill the issue list until the next
  /// compile; the compiler alone decides whether a material compiles.
  void _validateDartSyntax() {
    final text = _currentCode;
    _issues = [];

    int lineOf(int offset) => '\n'.allMatches(text.substring(0, offset.clamp(0, text.length))).length + 1;

    final fragIndex = text.indexOf('void material');
    final fragmentAt = RegExp(r'\bfragment\s*\{').firstMatch(text)?.start ?? -1;
    if (fragIndex != -1) {
      _bodyLineOffset = lineOf(fragIndex);
    } else {
      _bodyLineOffset = fragmentAt >= 0 ? lineOf(fragmentAt) : 1;
    }

    MatSource source;
    try {
      source = MatSource.parse(text);
    } on FormatException catch (e) {
      final unbalanced = e.message.contains('unbalanced');
      _issues.add(MaterialCompileIssue(
        line: e.offset == null ? 1 : lineOf(e.offset!),
        message: unbalanced ? 'Unmatched braces: the block opened here is never closed' : 'Syntax: ${e.message}',
        severity: MaterialCompileSeverity.error,
      ));
      _syntaxStatus = unbalanced ? 'Syntax Error: Unmatched braces' : 'Syntax Error';
      return;
    }

    final fragment = source.block('fragment');
    if (source.block('material') == null && fragment == null && source.block('compute') == null) {
      _issues.add(const MaterialCompileIssue(
        line: 1,
        message: 'Missing material {} or fragment {} block',
        severity: MaterialCompileSeverity.error,
      ));
      _syntaxStatus = 'Syntax Error: Missing blocks';
    } else if (fragment != null &&
        // Post-process and compute materials have no prepareMaterial.
        !const {'postprocess', 'compute'}.contains(_headerWord(text, 'domain')?.toLowerCase()) &&
        !fragment.body.replaceAll(RegExp(r'//[^\n]*|/\*[\s\S]*?\*/'), '').contains('prepareMaterial')) {
      _issues.add(MaterialCompileIssue(
        line: fragmentAt >= 0 ? lineOf(fragmentAt) : 1,
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

  /// Compiles the whole current `.mat` source with the material compiler
  /// (Filament's own `.mat` parser, as `matc` uses it): the header, the
  /// `vertex` and `fragment` blocks in any order. The editor's own checks do
  /// not stand in the way; the compiler's messages become [issues].
  Future<bool> compile() async {
    if (graph.isAhead && graph.analysis.hasErrors) {
      // The source is older than the graph: compiling it would preview a
      // material the graph no longer describes.
      showGraphIssues(graph.issues);
      return false;
    }
    _validateDartSyntax();
    // Declarations and header values edited by hand reach the panel and the
    // header bar too.
    _reparseParametersKeepingValues();
    _shading = _parseShadingModel(_currentCode);
    _blending = _parseBlendingMode(_currentCode);
    _doubleSided = _parseDoubleSided(_currentCode);

    _isCompiling = true;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    final name = _asset?.name ?? File(assetPath).uri.pathSegments.last.replaceAll('.lmas', '');
    final result = await compilerRunner.compile(
      name: name.isEmpty ? 'Material' : name,
      source: _currentCode,
      includeDirectory: File(assetPath).parent.path,
    );

    stopwatch.stop();
    _elapsedMs = stopwatch.elapsedMilliseconds;
    _isCompiling = false;

    final bytes = result.bytes;
    if (result.ok) {
      _compiledBytes = bytes;
      _issues = [
        MaterialCompileIssue(
          line: 1,
          message: 'Compilation successful (${bytes!.length} bytes in ${_elapsedMs}ms)',
          severity: MaterialCompileSeverity.info,
        ),
        ...result.issues,
      ];
      if (graph.isInitialized) {
        _issues.addAll(graph.issues.where((i) => i.severity != MaterialCompileSeverity.error));
      }
      _syntaxStatus = 'Compile OK (${bytes.length} B, ${_elapsedMs}ms)';
      onHotApply?.call(bytes);
      EngineLoggerService().log('Compiled material "$name" (${bytes.length} bytes) in ${_elapsedMs}ms', level: 'info');
      notifyListeners();
      return true;
    }
    final errors = result.issues.where((i) => i.severity == MaterialCompileSeverity.error).toList();
    _issues = result.issues.isEmpty
        ? [const MaterialCompileIssue(line: 0, message: 'The material compiler produced no package', fromCompiler: true)]
        : [...result.issues];
    _syntaxStatus = 'Compile Error (${errors.isEmpty ? 1 : errors.length})';
    final first = errors.isEmpty ? _issues.first : errors.first;
    EngineLoggerService().log(
      'Material "$name" did not compile${first.line > 0 ? ' (line ${first.line})' : ''}: ${first.message}',
      level: 'error',
      source: 'FilamatCompiler',
    );
    notifyListeners();
    return false;
  }

  /// A header entry's bare value (`shadingModel : lit` → `lit`), read with the
  /// `.mat` block reader; for the header bar and panel only (compiling never
  /// depends on it). A source it cannot split falls back to a plain match.
  static String? _headerWord(String source, String key) {
    try {
      final value = MatSource.parse(source).headerValue(key);
      if (value is MatAtom) return value.text;
      if (value is MatString) return value.text;
      return null;
    } on FormatException {
      return RegExp('\\b$key\\s*:\\s*"?([A-Za-z0-9_]+)').firstMatch(source)?.group(1);
    }
  }

  static FilamatShading _parseShadingModel(String source) {
    final word = _headerWord(source, 'shadingModel')?.toLowerCase();
    return FilamatShading.values.where((s) => s.name.toLowerCase() == word).firstOrNull ?? FilamatShading.lit;
  }

  static BlendingMode _parseBlendingMode(String source) {
    final word = _headerWord(source, 'blending')?.toLowerCase();
    return BlendingMode.values.where((b) => b.name.toLowerCase() == word).firstOrNull ?? BlendingMode.opaque;
  }

  static bool _parseDoubleSided(String source) => _headerWord(source, 'doubleSided')?.toLowerCase() == 'true';

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
    _doubleSided = _parseDoubleSided(code);
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

  /// The source a new material starts from, whichever way it is made (the
  /// editor on a missing file, Content Browser ▸ New, MCP `create_asset`).
  /// `flipUV : false`: every mesh
  /// carries glTF texture coordinates (v = 0 at the image top) and textures
  /// upload top row first, so a texture sampled with `getUV0()` draws upright
  /// only unflipped (matc's default, `true`, turns it upside down).
  static String newMaterialSource(String name) {
    return '''material {
    name : "$name",
    shadingModel : lit,
    blending : opaque,
    flipUV : false,
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
