import 'dart:typed_data';
import 'package:flutter_riglogic/flutter_riglogic.dart';
import 'package:lumina/lumina.dart';

/// Evaluation result containing calculated blend shapes, joint deltas, and animated maps.
class RigLogicEvaluationResult {
  /// Calculated blend shape channel weights mapped by channel name.
  final Map<String, double> blendShapeWeights;

  /// Raw float list of blend shape weights in channel index order.
  final List<double> rawBlendShapes;

  /// Raw joint outputs (9 floats per joint: Tx, Ty, Tz, Rx, Ry, Rz, Sx, Sy, Sz).
  final List<double> jointOutputs;

  /// Raw animated map (wrinkle map) multiplier outputs.
  final List<double> animatedMapOutputs;

  const RigLogicEvaluationResult({
    required this.blendShapeWeights,
    required this.rawBlendShapes,
    required this.jointOutputs,
    required this.animatedMapOutputs,
  });
}

/// Evaluates MetaHuman DNA facial rigs using OpenRigLogic C++ engine.
///
/// Converts raw/GUI control inputs into microsecond-evaluated blend shape
/// weights and skeletal joint transforms that drive 3D facial animation.
class RigLogicEvaluator {
  final DnaReader _reader;
  final RigLogic _rigLogic;
  final RigInstance _instance;

  final Map<String, int> _rawControlNameToIndex = {};
  final List<String> _rawControlNames = [];
  final List<String> _blendShapeNames = [];
  final List<String> _jointNames = [];
  final List<String> _animatedMapNames = [];

  final Map<int, double> _controlValues = {};
  bool _isDisposed = false;

  RigLogicEvaluator._({
    required this._reader,
    required this._rigLogic,
    required this._instance,
  }) {
    _initMetadata();
  }

  void _initMetadata() {
    for (int i = 0; i < _reader.rawControlCount; i++) {
      final name = _reader.getRawControlName(i);
      _rawControlNames.add(name);
      _rawControlNameToIndex[name] = i;
      _controlValues[i] = 0.0;
      _instance.setRawControl(i, 0.0);
    }

    for (int i = 0; i < _reader.blendShapeChannelCount; i++) {
      _blendShapeNames.add(_reader.getBlendShapeChannelName(i));
    }

    for (int i = 0; i < _reader.jointCount; i++) {
      _jointNames.add(_reader.getJointName(i));
    }

    for (int i = 0; i < _reader.animatedMapCount; i++) {
      _animatedMapNames.add(_reader.getAnimatedMapName(i));
    }

    // Initial evaluation with zero controls
    _rigLogic.calculate(_instance);
  }

  /// Creates a [RigLogicEvaluator] by reading a binary `.dna` file from disk.
  factory RigLogicEvaluator.fromFile(String path) {
    final reader = DnaReader.fromFile(path);
    try {
      final rigLogic = RigLogic.create(reader);
      try {
        final instance = RigInstance.create(rigLogic);
        return RigLogicEvaluator._(
          reader: reader,
          rigLogic: rigLogic,
          instance: instance,
        );
      } catch (_) {
        rigLogic.dispose();
        rethrow;
      }
    } catch (_) {
      reader.dispose();
      rethrow;
    }
  }

  /// Creates a [RigLogicEvaluator] from an in-memory byte buffer containing `.dna` data.
  factory RigLogicEvaluator.fromMemory(Uint8List bytes) {
    final reader = DnaReader.fromMemory(bytes);
    try {
      final rigLogic = RigLogic.create(reader);
      try {
        final instance = RigInstance.create(rigLogic);
        return RigLogicEvaluator._(
          reader: reader,
          rigLogic: rigLogic,
          instance: instance,
        );
      } catch (_) {
        rigLogic.dispose();
        rethrow;
      }
    } catch (_) {
      reader.dispose();
      rethrow;
    }
  }

  // --- DNA Metadata ---

  bool get isDisposed => _isDisposed;

  String get characterName => _reader.name;

  int get lodCount => _reader.lodCount;

  int get jointCount => _reader.jointCount;

  int get blendShapeCount => _reader.blendShapeChannelCount;

  int get rawControlCount => _reader.rawControlCount;

  int get guiControlCount => _reader.guiControlCount;

  int get animatedMapCount => _reader.animatedMapCount;

  List<String> get rawControlNames => List.unmodifiable(_rawControlNames);

  List<String> get blendShapeNames => List.unmodifiable(_blendShapeNames);

  List<String> get jointNames => List.unmodifiable(_jointNames);

  List<String> get animatedMapNames => List.unmodifiable(_animatedMapNames);

  int get lod => _instance.lod;

  set lod(int value) => _instance.lod = value;

  // --- Input Controls ---

  int? indexOfRawControl(String name) => _rawControlNameToIndex[name];

  double getRawControl(int index) {
    _checkDisposed();
    return _controlValues[index] ?? 0.0;
  }

  double? getControlByName(String name) {
    final index = _rawControlNameToIndex[name];
    if (index == null) return null;
    return getRawControl(index);
  }

  void setRawControl(int index, double value) {
    _checkDisposed();
    if (index < 0 || index >= _rawControlNames.length) {
      throw RangeError.range(index, 0, _rawControlNames.length - 1, 'index');
    }
    _controlValues[index] = value;
    _instance.setRawControl(index, value);
  }

  bool setControlByName(String name, double value) {
    final index = _rawControlNameToIndex[name];
    if (index == null) return false;
    setRawControl(index, value);
    return true;
  }

  void applyControls(Map<String, double> controls) {
    for (final entry in controls.entries) {
      setControlByName(entry.key, entry.value);
    }
  }

  void resetControls() {
    _checkDisposed();
    for (int i = 0; i < _rawControlNames.length; i++) {
      _controlValues[i] = 0.0;
      _instance.setRawControl(i, 0.0);
    }
  }

  // --- Evaluation ---

  /// Evaluates the rig logic graph with current control inputs and returns
  /// blend shape weights, joint deltas, and animated maps.
  RigLogicEvaluationResult evaluate() {
    _checkDisposed();
    _rigLogic.calculate(_instance);

    final rawBlendShapes = _instance.getBlendShapeOutputs();
    final jointOutputs = _instance.getJointOutputs();
    final animatedMapOutputs = _instance.getAnimatedMapOutputs();

    final blendShapeWeights = <String, double>{};
    for (int i = 0; i < rawBlendShapes.length && i < _blendShapeNames.length; i++) {
      blendShapeWeights[_blendShapeNames[i]] = rawBlendShapes[i];
    }

    return RigLogicEvaluationResult(
      blendShapeWeights: blendShapeWeights,
      rawBlendShapes: rawBlendShapes,
      jointOutputs: jointOutputs,
      animatedMapOutputs: animatedMapOutputs,
    );
  }

  /// Evaluates current control state and pushes matching blend shape weights
  /// directly into [mesh] (via [LuminaSkinnedMeshComponent.setMorphTarget]).
  RigLogicEvaluationResult applyToSkinnedMesh(LuminaSkinnedMeshComponent mesh) {
    final result = evaluate();
    List<String>? availableNames;
    try {
      availableNames = mesh.morphTargetNames;
    } catch (_) {
      availableNames = null;
    }

    if (availableNames != null && availableNames.isNotEmpty) {
      for (final entry in result.blendShapeWeights.entries) {
        if (availableNames.contains(entry.key)) {
          mesh.setMorphTarget(entry.key, entry.value);
        }
      }
    }
    return result;
  }

  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _instance.dispose();
      _rigLogic.dispose();
      _reader.dispose();
    }
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('RigLogicEvaluator has already been disposed');
    }
  }
}
