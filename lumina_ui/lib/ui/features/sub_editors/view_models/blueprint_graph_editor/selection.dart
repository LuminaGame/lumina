part of '../blueprint_graph_editor.dart';

/// Selection and Compiler Results navigation.
mixin _BlueprintGraphSelection on _BlueprintGraphEditorCore {

  // ---------------------------------------------------------------------------
  // Selection and navigation
  // ---------------------------------------------------------------------------

  @override
  Set<String> get selectedNodeIds => {for (final id in _selected) if (node(id) != null) id};

  void select(String nodeId, {bool additive = false}) {
    if (!additive) _selected.clear();
    _selected.add(nodeId);
    notifyListeners();
  }

  void toggle(String nodeId) {
    if (!_selected.remove(nodeId)) _selected.add(nodeId);
    notifyListeners();
  }

  void selectMany(Set<String> ids) {
    _selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Selects [nodeId] and asks the canvas to centre it.
  void focusNode(String nodeId) {
    if (node(nodeId) == null) return;
    select(nodeId);
    focusRequest.value = (nodeId: nodeId, serial: ++_focusSerial);
  }
}
