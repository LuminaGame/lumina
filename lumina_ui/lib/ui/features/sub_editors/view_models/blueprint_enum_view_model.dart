import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';

/// The Enumeration sub-editor's state: lumina's
/// [LuminaBlueprintEnumDocument] read from and written to the enum `.lmas`
/// (`contents/enums/E_*.lmas`, payload `kind: enum`). Values are ordered,
/// renamed and reordered here; every edit is one undo step, and saving a
/// reordered enum moves the `Switch on <enum>` case wires of every Blueprint
/// in the project so each case keeps following its value by name.
class BlueprintEnumViewModel extends ChangeNotifier {
  final String assetPath;
  final TransactionManager transactions = TransactionManager();

  String _name;
  List<String> _values;
  List<String> _onDisk = const [];
  int? _selected;

  BlueprintEnumViewModel({required this.assetPath, String? name, List<String>? values})
      : _name = name ?? _basename(assetPath),
        _values = List.of(values ?? const ['NewEnumerator0']);

  static String _basename(String path) => File(path).uri.pathSegments.last.replaceAll('.lmas', '');

  String get name => _name;
  List<String> get values => List.unmodifiable(_values);
  int? get selectedIndex => _selected;
  bool get isDirty => !listEquals(_values, _onDisk) || _onDisk.isEmpty && _values.isNotEmpty && !File(assetPath).existsSync();
  LuminaBlueprintEnumDocument get document => LuminaBlueprintEnumDocument(name: _name, values: List.of(_values));

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
    final doc = BlueprintAssetCatalog.readEnum(assetPath);
    if (doc != null) {
      if (doc.name.isNotEmpty) _name = doc.name;
      _values = List.of(doc.values);
      _onDisk = List.of(doc.values);
    }
    transactions.clear();
    notifyListeners();
  }

  /// Writes the `.lmas`; a reorder / rename also rewires the project's
  /// switches on this enum. Returns whether the file was written.
  Future<bool> save() async {
    final dir = projectDir;
    try {
      if (dir != null) {
        final rel = File(assetPath).absolute.path.substring(dir.length + 1);
        BlueprintAssetCatalog.writeEnum(dir, document, path: rel);
        BlueprintAssetCatalog.remapProjectSwitchWires(dir, _name, _onDisk, _values);
      } else {
        BlueprintAssetCatalog.writeEnum(File(assetPath).absolute.parent.path, document, path: File(assetPath).uri.pathSegments.last);
      }
      _onDisk = List.of(_values);
      EngineLoggerService().log('Saved enum $_name (${_values.length} values) to $assetPath', level: 'info');
      AssetRepository.notifyAssetsChanged();
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save enum $_name: $e\n$st', level: 'error');
      return false;
    }
  }

  void _mutate(String label, List<String> next) {
    final before = List.of(_values);
    if (listEquals(before, next)) return;
    void apply(List<String> v) {
      _values = List.of(v);
      if (_selected != null && _selected! >= _values.length) _selected = _values.isEmpty ? null : _values.length - 1;
      notifyListeners();
    }

    transactions.record(EditorTransaction(label: label, undo: () => apply(before), redo: () => apply(next)));
    apply(next);
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  void select(int? index) {
    _selected = index;
    notifyListeners();
  }

  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Adds a value and selects it; returns its name. Without [name] the
  /// next free `NewEnumerator<n>`; a given name gets a numeric suffix if taken.
  String addValue([String? name]) {
    String unique;
    if (name == null) {
      var n = _values.length;
      unique = 'NewEnumerator$n';
      while (_values.contains(unique)) {
        unique = 'NewEnumerator${++n}';
      }
    } else {
      unique = name;
      for (var n = 2; _values.contains(unique); n++) {
        unique = '$name$n';
      }
    }
    _mutate('Add $unique', [..._values, unique]);
    _selected = _values.length - 1;
    notifyListeners();
    return unique;
  }

  bool renameValue(int index, String newName) {
    final trimmed = newName.trim();
    if (index < 0 || index >= _values.length || !_identifier.hasMatch(trimmed)) return false;
    if (_values[index] == trimmed) return false;
    if (_values.contains(trimmed)) return false;
    _mutate('Rename ${_values[index]}', [..._values]..[index] = trimmed);
    return true;
  }

  bool removeValue(int index) {
    if (index < 0 || index >= _values.length) return false;
    _mutate('Remove ${_values[index]}', [..._values]..removeAt(index));
    return true;
  }

  /// Moves the value at [from] to [to] (reorder).
  bool moveValue(int from, int to) {
    if (from < 0 || from >= _values.length || to < 0 || to >= _values.length || from == to) return false;
    final next = [..._values];
    final v = next.removeAt(from);
    next.insert(to, v);
    _mutate('Move $v', next);
    _selected = to;
    notifyListeners();
    return true;
  }

  bool moveUp(int index) => moveValue(index, index - 1);
  bool moveDown(int index) => moveValue(index, index + 1);
}
