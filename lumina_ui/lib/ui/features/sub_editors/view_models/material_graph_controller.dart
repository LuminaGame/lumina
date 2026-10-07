import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_graph_editor.dart';

/// The Material Editor's node graph and its link to the `.mat` source.
///
/// Graph and source are two views of one material. A graph edit is one undo
/// step on [transactions] that regenerates the source (unless the graph has
/// type errors, which the compiler log shows instead); a hand edit of the
/// source re-parses it into the graph the next time the graph is looked at
/// ([ensureSynced]), keeping the nodes where the author put them. The graph is
/// stored in the `.lmas` metadata `material_graph` with a hash of the source
/// it matches, so its layout survives a save and reload.
class MaterialGraphController extends ChangeNotifier implements BlueprintGraphHost {
  final MaterialEditorViewModel _vm;
  final TransactionManager transactions = TransactionManager();

  MaterialGraphController(this._vm);

  LuminaBlueprintGraph _graph = LuminaBlueprintGraph();
  MaterialGraphAnalysis _analysis = MaterialGraphAnalysis.empty;

  /// The source the graph mirrors: what it was parsed from or generated into.
  String? _syncedCode;
  bool _initialized = false;

  /// The graph has edits the source lacks (it has type errors).
  bool _ahead = false;
  bool _layoutDirty = false;
  String? _fallbackReason;
  List<String> _notes = const [];
  Map<String, dynamic>? _stored;

  late final MaterialGraphEditor editor = MaterialGraphEditor(
    host: this,
    graphSource: () => _graph,
    analysis: () => _analysis,
    surface: () => surface,
    textures: () => _vm.availableTextures,
    textureFor: (parameter) {
      final p = _vm.parameters.where((p) => p.name == parameter && p.isSampler).firstOrNull;
      return p == null ? null : _vm.textureAssetFor(p);
    },
    bindTexture: bindTexture,
  );

  /// Binds sampler [parameter] to [asset] (null clears it) as one undo step:
  /// the panel, the node Details and the Texture Sample node all go through
  /// here. The binding lives in the view model's
  /// parameters, not in the graph, so the step restores it directly.
  bool bindTexture(String parameter, RealAssetInfo? asset) {
    final param = _vm.parameters.where((p) => p.name == parameter && p.isSampler).firstOrNull;
    if (param == null) return false;
    final before = param.textureRef;
    final afterId = asset?.assetId ?? (asset?.fileName.replaceAll(RegExp(r'\.lmas$'), ''));
    if (before?.assetPath == asset?.relativePath && before?.assetId == afterId) return false;
    void apply(String? id, String? path) {
      if (path == null || id == null) {
        _vm.clearTextureReference(parameter);
      } else {
        _vm.setTextureReference(parameter, assetId: id, assetPath: path);
      }
      editor.documentChanged();
      notifyListeners();
    }

    apply(afterId, asset?.relativePath);
    transactions.record(EditorTransaction(
      label: asset == null ? 'Clear $parameter texture' : 'Set $parameter texture',
      undo: () => apply(before?.assetId, before?.assetPath),
      redo: () => apply(afterId, asset?.relativePath),
    ));
    return true;
  }

  LuminaBlueprintGraph get graph => _graph;
  MaterialGraphAnalysis get analysis => _analysis;
  MaterialSurface get surface => MaterialSurface(shading: _vm.shading, blending: _vm.blending);
  bool get isInitialized => _initialized;
  /// The graph holds edits the source lacks (its type errors kept it from
  /// being written). A hand edit of the source since makes the source the
  /// newer of the two again.
  bool get isAhead => _initialized && _ahead && _vm.currentCode == _syncedCode;
  bool get isLayoutDirty => _layoutDirty;

  /// Why the fragment is one Custom (Fragment) node, when it is.
  String? get fallbackReason => _fallbackReason;
  List<String> get notes => _notes;

  @override
  LuminaBlueprintTypeContext get typeContext => const LuminaBlueprintTypeContext();

  @override
  List<String> get availableWidgetClasses => const [];

  @override
  void declareVariable(LuminaBlueprintVariable variable) {}

  static String sourceHash(String code) {
    // FNV-1a, 32 bit: enough to tell whether a stored graph matches a source.
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(code)) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  /// Forgets the graph; the next [ensureSynced] reads it from [storedJson]
  /// (the `.lmas` metadata) or parses the source.
  void restore(String? storedJson) {
    _stored = null;
    if (storedJson != null && storedJson.isNotEmpty) {
      try {
        _stored = Map<String, dynamic>.from(jsonDecode(storedJson) as Map);
      } catch (_) {}
    }
    _initialized = false;
    _syncedCode = null;
    _ahead = false;
    _layoutDirty = false;
    transactions.clear();
  }

  /// The metadata value [restore] reads back.
  String storedJson() => jsonEncode({
        'version': 1,
        'source_hash': sourceHash(_vm.currentCode),
        'ahead': _ahead,
        'graph': _graph.toJson(),
      });

  void markSaved() {
    _stored = jsonDecode(storedJson()) as Map<String, dynamic>;
    _layoutDirty = false;
  }

  LuminaBlueprintGraph? _storedGraph() {
    final g = _stored?['graph'];
    if (g is! Map) return null;
    try {
      return LuminaBlueprintGraph.fromJson(Map<String, dynamic>.from(g));
    } catch (_) {
      return null;
    }
  }

  /// Brings the graph in line with the source: the stored graph when it was
  /// saved with this very source, else a parse of the source laid out like
  /// the graph before it. A re-parse after a hand edit clears graph undo.
  void ensureSynced() {
    final code = _vm.currentCode;
    if (_initialized && code == _syncedCode) return;
    final wasInitialized = _initialized;
    final stored = _storedGraph();
    if (!wasInitialized && stored != null && _stored?['source_hash'] == sourceHash(code)) {
      _graph = stored;
      MaterialNodes.ensureOutput(_graph, materialName: _vm.asset?.name);
      _ahead = _stored?['ahead'] == true;
      _fallbackReason = null;
      _notes = const [];
    } else {
      final result = MaterialGraphParser.parse(code);
      final previous = wasInitialized ? _graph : stored;
      if (previous != null) MaterialGraphLayout.keepPositions(result.graph, previous);
      _graph = result.graph;
      _ahead = false;
      _fallbackReason = result.fallbackReason;
      _notes = result.notes;
      if (wasInitialized) transactions.clear();
    }
    _syncedCode = code;
    _initialized = true;
    _refreshTitles();
    _analyze();
    editor.documentChanged();
    notifyListeners();
  }

  /// The source's header changed (shading model, blend mode) without its
  /// fragment: keep the graph, re-check it against the new surface, and
  /// regenerate the fragment so the pins the new surface does not use are
  /// left out, and come back when it uses them again (e.g. Unlit
  /// rejects `material.metallic`). A graph not opened yet is read first;
  /// a hand-written fragment kept as Custom (Fragment) stays as it is.
  void headerChanged(String previousCode) {
    if (!_initialized) {
      ensureSynced();
    } else if (previousCode != _syncedCode) {
      return;
    } else {
      _syncedCode = _vm.currentCode;
    }
    _analyze();
    if (_fallbackReason == null && !_analysis.hasErrors) {
      final code = MaterialGraphCodegen.generate(
        _graph,
        currentSource: _vm.currentCode,
        surface: surface,
        analysis: _analysis,
        materialName: _vm.asset?.name,
      );
      if (code != _vm.currentCode) {
        _syncedCode = code;
        _vm.applyGraphSource(code, issues);
      }
    }
    editor.documentChanged();
    notifyListeners();
  }

  void _refreshTitles() {
    for (final n in _graph.nodes) {
      n.title = n.id == MaterialNodes.outputNodeId
          ? (_vm.asset?.name ?? 'Material')
          : MaterialNodes.titleOf(n);
    }
  }

  void _analyze() => _analysis = MaterialGraphChecker.check(_graph, surface);

  /// The graph's diagnostics as compiler-log rows.
  List<MaterialCompileIssue> get issues => [
        for (final d in _analysis.diagnostics)
          MaterialCompileIssue(
            line: 0,
            message: d.message,
            severity: d.isError ? MaterialCompileSeverity.error : MaterialCompileSeverity.warning,
            nodeId: d.nodeId,
          ),
        for (final note in _notes) MaterialCompileIssue(line: 0, message: note, severity: MaterialCompileSeverity.info),
        if (_fallbackReason != null)
          MaterialCompileIssue(
            line: 0,
            message: 'The fragment is a Custom (Fragment) node: $_fallbackReason.',
            severity: MaterialCompileSeverity.info,
          ),
      ];

  /// Regenerates the source from the graph, or reports why it cannot.
  void _apply() {
    _refreshTitles();
    _analyze();
    if (_analysis.hasErrors) {
      _ahead = true;
      _vm.showGraphIssues(issues);
    } else {
      final code = MaterialGraphCodegen.generate(
        _graph,
        currentSource: _vm.currentCode,
        surface: surface,
        analysis: _analysis,
        materialName: _vm.asset?.name,
      );
      _ahead = false;
      _syncedCode = code;
      _vm.applyGraphSource(code, issues);
    }
    editor.documentChanged();
    notifyListeners();
  }

  String _snapshot() => jsonEncode({'graph': _graph.toJson(), 'code': _vm.currentCode, 'ahead': _ahead});

  void _restore(String json, {bool touchSource = true}) {
    final m = Map<String, dynamic>.from(jsonDecode(json) as Map);
    _graph = LuminaBlueprintGraph.fromJson(Map<String, dynamic>.from(m['graph'] as Map));
    _ahead = m['ahead'] == true;
    _refreshTitles();
    _analyze();
    if (touchSource) {
      final code = m['code'] as String;
      _syncedCode = code;
      if (_ahead) {
        _vm.applyGraphSource(code, const []);
        _vm.showGraphIssues(issues);
      } else {
        _vm.applyGraphSource(code, issues);
      }
    }
    _layoutDirty = true;
    editor.documentChanged();
    notifyListeners();
  }

  @override
  T mutate<T>(String label, T Function() mutation) {
    ensureSynced();
    final before = _snapshot();
    final graphBefore = jsonEncode(_graph.toJson());
    final result = mutation();
    if (result == null || result == false) {
      _restore(before, touchSource: false);
      return result;
    }
    if (jsonEncode(_graph.toJson()) == graphBefore) return result;
    _apply();
    _layoutDirty = true;
    final after = _snapshot();
    transactions.record(EditorTransaction(label: label, undo: () => _restore(before), redo: () => _restore(after)));
    return result;
  }

  String? _interactionBefore;
  String? _interactionLabel;

  @override
  void beginInteraction(String label) {
    ensureSynced();
    _interactionBefore ??= _snapshot();
    _interactionLabel = label;
  }

  @override
  void endInteraction({bool layoutOnly = false}) {
    final before = _interactionBefore;
    _interactionBefore = null;
    if (before == null) return;
    if (!layoutOnly) _apply();
    final after = _snapshot();
    if (after == before) return;
    _layoutDirty = true;
    transactions.record(EditorTransaction(
      label: _interactionLabel ?? 'Edit graph',
      undo: () => _restore(before),
      redo: () => _restore(after),
    ));
    _vm.graphLayoutChanged();
    notifyListeners();
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  /// Lays the graph out again (one undo step).
  void arrange() {
    mutate('Arrange nodes', () {
      final before = [for (final n in _graph.nodes) (n.x, n.y)];
      MaterialGraphLayout.arrange(_graph);
      return [for (final n in _graph.nodes) (n.x, n.y)].toString() != before.toString();
    });
  }
}
