import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';

/// The Blueprint Interface sub-editor's state:
/// lumina's [LuminaBlueprintInterfaceDocument] read from and written to the
/// interface `.lmas` (`contents/interfaces/BPI_*.lmas`, payload
/// `kind: interface`): a list of function signatures (name, inputs,
/// outputs). Every edit is one undo step.
class BlueprintInterfaceViewModel extends ChangeNotifier {
  final String assetPath;
  final TransactionManager transactions = TransactionManager();

  String _name;
  List<LuminaBlueprintFunctionSignature> _functions;
  String _onDisk = '';
  String? _selected;

  BlueprintInterfaceViewModel({required this.assetPath, String? name, List<LuminaBlueprintFunctionSignature>? functions})
      : _name = name ?? _basename(assetPath),
        _functions = List.of(functions ?? const []);

  static String _basename(String path) => File(path).uri.pathSegments.last.replaceAll('.lmas', '');

  String get name => _name;
  List<LuminaBlueprintFunctionSignature> get functions => List.unmodifiable(_functions);
  String? get selectedFunction => _selected;
  LuminaBlueprintFunctionSignature? function(String? name) => _functions.where((f) => f.name == name).firstOrNull;
  LuminaBlueprintInterfaceDocument get document => LuminaBlueprintInterfaceDocument(name: _name, functions: List.of(_functions));
  String get _json => document.toFormattedJson();
  bool get isDirty => _json != _onDisk;

  /// The project directory the asset lives in (its `contents/` ancestor), or null.
  String? get projectDir {
    var dir = File(assetPath).absolute.parent;
    while (dir.path != dir.parent.path) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      dir = dir.parent;
    }
    return null;
  }

  Future<void> load() async {
    final doc = BlueprintAssetCatalog.readInterface(assetPath);
    if (doc != null) {
      if (doc.name.isNotEmpty) _name = doc.name;
      _functions = List.of(doc.functions);
      _onDisk = _json;
    }
    transactions.clear();
    notifyListeners();
  }

  Future<bool> save() async {
    final dir = projectDir;
    try {
      if (dir != null) {
        final rel = File(assetPath).absolute.path.substring(dir.length + 1);
        BlueprintAssetCatalog.writeInterface(dir, document, path: rel);
      } else {
        BlueprintAssetCatalog.writeInterface(File(assetPath).absolute.parent.path, document,
            path: File(assetPath).uri.pathSegments.last);
      }
      _onDisk = _json;
      EngineLoggerService().log('Saved interface $_name (${_functions.length} functions) to $assetPath', level: 'info');
      AssetRepository.notifyAssetsChanged();
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save interface $_name: $e\n$st', level: 'error');
      return false;
    }
  }

  void _mutate(String label, List<LuminaBlueprintFunctionSignature> next) {
    final before = List.of(_functions);
    if (jsonEncode(before.map((f) => f.toJson()).toList()) == jsonEncode(next.map((f) => f.toJson()).toList())) return;
    void apply(List<LuminaBlueprintFunctionSignature> v) {
      _functions = List.of(v);
      if (_selected != null && function(_selected) == null) _selected = null;
      notifyListeners();
    }

    transactions.record(EditorTransaction(label: label, undo: () => apply(before), redo: () => apply(next)));
    apply(next);
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  void select(String? name) {
    _selected = name;
    notifyListeners();
  }

  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Adds a function named [name] (made unique) with no parameters; returns its name.
  String addFunction([String name = 'NewFunction']) {
    var unique = name;
    for (var n = 2; function(unique) != null; n++) {
      unique = '$name$n';
    }
    _mutate('Add $unique', [..._functions, LuminaBlueprintFunctionSignature(name: unique)]);
    _selected = unique;
    notifyListeners();
    return unique;
  }

  bool renameFunction(String oldName, String newName) {
    final trimmed = newName.trim();
    final f = function(oldName);
    if (f == null || trimmed == oldName || !_identifier.hasMatch(trimmed) || function(trimmed) != null) return false;
    _mutate('Rename $oldName', [
      for (final x in _functions) x.name == oldName ? LuminaBlueprintFunctionSignature(name: trimmed, inputs: x.inputs, outputs: x.outputs) : x,
    ]);
    if (_selected == oldName) _selected = trimmed;
    return true;
  }

  bool removeFunction(String name) {
    if (function(name) == null) return false;
    _mutate('Remove $name', [for (final x in _functions) if (x.name != name) x]);
    return true;
  }

  bool setInputs(String name, List<LuminaBlueprintVariable> inputs) {
    final f = function(name);
    if (f == null) return false;
    _mutate('Edit inputs of $name', [
      for (final x in _functions) x.name == name ? LuminaBlueprintFunctionSignature(name: x.name, inputs: List.of(inputs), outputs: x.outputs) : x,
    ]);
    return true;
  }

  bool setOutputs(String name, List<LuminaBlueprintVariable> outputs) {
    final f = function(name);
    if (f == null) return false;
    _mutate('Edit outputs of $name', [
      for (final x in _functions) x.name == name ? LuminaBlueprintFunctionSignature(name: x.name, inputs: x.inputs, outputs: List.of(outputs)) : x,
    ]);
    return true;
  }

  /// Adds a parameter to [name]'s inputs or outputs; returns the parameter name.
  String addParameter(String name, {required bool output, String parameter = 'NewParam', String type = 'Float'}) {
    final f = function(name);
    if (f == null) return parameter;
    final list = output ? f.outputs : f.inputs;
    var unique = parameter;
    for (var n = 2; list.any((v) => v.name == unique); n++) {
      unique = '$parameter$n';
    }
    final next = [...list, LuminaBlueprintVariable(name: unique, typeName: type, defaultValue: BlueprintPinStyle.defaultValueFor(type))];
    if (output) {
      setOutputs(name, next);
    } else {
      setInputs(name, next);
    }
    return unique;
  }
}
