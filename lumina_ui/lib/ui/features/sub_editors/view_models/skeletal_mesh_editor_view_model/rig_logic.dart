part of '../skeletal_mesh_editor_view_model.dart';

/// The MetaHuman DNA rig: loading it and evaluating its controls.
mixin _SkeletalMeshRigLogic on _SkeletalMeshEditorViewModelState {
  Future<bool> loadDnaFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      _rigLogicEvaluator?.dispose();
      _rigLogicEvaluator = RigLogicEvaluator.fromFile(path);
      _dnaPath = path;
      _rigLogicControlValues.clear();
      for (final name in _rigLogicEvaluator!.rawControlNames) {
        _rigLogicControlValues[name] = 0.0;
      }
      _evaluateRigLogic();
      _isDirty = true;
      notifyListeners();
      return true;
    } catch (e) {
      EngineLoggerService().log('Failed to load DNA from $path: $e', level: 'error');
      return false;
    }
  }

  Future<bool> loadDnaBytes(Uint8List bytes, {String? filename}) async {
    try {
      _rigLogicEvaluator?.dispose();
      _rigLogicEvaluator = RigLogicEvaluator.fromMemory(bytes);
      _dnaPath = filename ?? 'in_memory.dna';
      _rigLogicControlValues.clear();
      for (final name in _rigLogicEvaluator!.rawControlNames) {
        _rigLogicControlValues[name] = 0.0;
      }
      _evaluateRigLogic();
      _isDirty = true;
      notifyListeners();
      return true;
    } catch (e) {
      EngineLoggerService().log('Failed to load DNA from memory: $e', level: 'error');
      return false;
    }
  }

  void unloadDna() {
    if (_rigLogicEvaluator != null) {
      _rigLogicEvaluator!.dispose();
      _rigLogicEvaluator = null;
      _dnaPath = null;
      _rigLogicControlValues.clear();
      _jointDeltas.clear();
      _isDirty = true;
      notifyListeners();
    }
  }

  void setRigLogicControl(String name, double value) {
    if (_rigLogicEvaluator == null) return;
    _rigLogicControlValues[name] = value;
    _rigLogicEvaluator!.setControlByName(name, value);
    _evaluateRigLogic();
    _isDirty = true;
    notifyListeners();
  }

  void resetRigLogicControls() {
    if (_rigLogicEvaluator == null) return;
    for (final key in _rigLogicControlValues.keys.toList()) {
      _rigLogicControlValues[key] = 0.0;
    }
    _rigLogicEvaluator!.resetControls();
    _evaluateRigLogic();
    _isDirty = true;
    notifyListeners();
  }

  void _evaluateRigLogic() {
    if (_rigLogicEvaluator == null) return;
    final result = _rigLogicEvaluator!.evaluate();
    for (final entry in result.blendShapeWeights.entries) {
      _morphWeights[entry.key] = entry.value;
    }
    _jointDeltas.clear();
    final jointNames = _rigLogicEvaluator!.jointNames;
    final outputs = result.jointOutputs;
    final count = jointNames.length;
    for (int i = 0; i < count; i++) {
      final offset = i * 9;
      if (offset + 9 <= outputs.length) {
        final sub = outputs.sublist(offset, offset + 9);
        if (sub.any((v) => v.abs() > 1e-5)) {
          _jointDeltas[jointNames[i]] = sub;
        }
      }
    }
  }
}
