part of '../sequencer_view_model.dart';

/// Curve editing: tangents (broken, flattened, dragged), retime + revalue
/// of keys and the interpolation presets.
mixin _SequencerCurveEditing on _SequencerViewModelState {

  // ---------------------------------------------------------------------------
  // Curve editing (tangents, retime + revalue, interpolation presets)
  // ---------------------------------------------------------------------------

  @override
  String _keyId(String trackId, String channelName, int keyIndex) => '$trackId|$channelName|$keyIndex';

  bool isTangentBroken(String trackId, String channelName, int keyIndex) =>
      _brokenTangentKeys.contains(_keyId(trackId, channelName, keyIndex));

  void setTangentBroken(String trackId, String channelName, int keyIndex, bool broken) {
    final id = _keyId(trackId, channelName, keyIndex);
    if (broken) {
      _brokenTangentKeys.add(id);
    } else {
      _brokenTangentKeys.remove(id);
    }
    notifyListeners();
  }

  /// Opens a coalesced transaction so a whole drag lands as one undo step.
  void beginCurveDrag(String label, String coalesceKey) {
    transactions.beginTransaction(label, coalesceKey: coalesceKey);
  }

  void endCurveDrag() {
    transactions.endTransaction();
    notifyListeners();
  }

  /// Sets a key's tangents (value units per frame). With [coalesceKey] set the
  /// edit merges into the open drag transaction.
  void setKeyTangents(
    String trackId,
    String channelName,
    int keyIndex, {
    double? inTangent,
    double? outTangent,
    String? coalesceKey,
  }) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;
    final key = channel.keys[keyIndex];
    final oldIn = key.inTangent;
    final oldOut = key.outTangent;
    final newIn = inTangent ?? oldIn;
    final newOut = outTangent ?? oldOut;
    if (newIn == oldIn && newOut == oldOut) return;

    key.inTangent = newIn;
    key.outTangent = newOut;
    _isDirty = true;
    _applyPlayheadToLevel();

    transactions.record(EditorTransaction(
      label: 'Edit Tangents (frame ${key.frame})',
      coalesceKey: coalesceKey,
      undo: () {
        key.inTangent = oldIn;
        key.outTangent = oldOut;
        _isDirty = true;
        _applyPlayheadToLevel();
        notifyListeners();
      },
      redo: () {
        key.inTangent = newIn;
        key.outTangent = newOut;
        _isDirty = true;
        _applyPlayheadToLevel();
        notifyListeners();
      },
    ));
    notifyListeners();
  }

  void flattenTangents(String trackId, String channelName, int keyIndex) {
    setKeyTangents(trackId, channelName, keyIndex, inTangent: 0.0, outTangent: 0.0);
  }

  /// Retimes and/or revalues a key in one step (curve-editor key drag). The
  /// frame is clamped strictly between the neighbouring keys so the time axis
  /// stays monotone; the key index never changes.
  void updateKey(
    String trackId,
    String channelName,
    int keyIndex, {
    int? frame,
    double? value,
    String? coalesceKey,
  }) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;
    final key = channel.keys[keyIndex];
    final oldFrame = key.frame;
    final oldValue = key.value;

    int newFrame = oldFrame;
    if (frame != null) {
      int lo = 0;
      int hi = _data.lengthFrames;
      if (keyIndex > 0) lo = channel.keys[keyIndex - 1].frame + 1;
      if (keyIndex < channel.keys.length - 1) hi = channel.keys[keyIndex + 1].frame - 1;
      if (lo <= hi) newFrame = frame.clamp(lo, hi);
    }
    final newValue = value ?? oldValue;
    if (newFrame == oldFrame && newValue == oldValue) return;

    key.frame = newFrame;
    key.value = newValue;
    _isDirty = true;
    _applyPlayheadToLevel();

    transactions.record(EditorTransaction(
      label: 'Edit Keyframe ($newFrame f, ${newValue.toStringAsFixed(2)})',
      coalesceKey: coalesceKey,
      undo: () {
        key.frame = oldFrame;
        key.value = oldValue;
        _isDirty = true;
        _applyPlayheadToLevel();
        notifyListeners();
      },
      redo: () {
        key.frame = newFrame;
        key.value = newValue;
        _isDirty = true;
        _applyPlayheadToLevel();
        notifyListeners();
      },
    ));
    notifyListeners();
  }

  /// `Cubic (Auto)`: cubic interpolation with Catmull-Rom tangents computed
  /// from the neighbours, in == out (unified handles).
  void setKeyInterpolationCubicAuto(String trackId, String channelName, int keyIndex) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;
    setKeyInterpolation(trackId, channelName, keyIndex, KeyInterpolation.cubic);
    final t = SequencerEvaluator.autoTangent(channel.keys, keyIndex);
    _brokenTangentKeys.remove(_keyId(trackId, channelName, keyIndex));
    setKeyTangents(trackId, channelName, keyIndex, inTangent: t, outTangent: t);
  }

  /// `Cubic (Broken)`: cubic interpolation whose two handles move independently.
  void setKeyInterpolationCubicBroken(String trackId, String channelName, int keyIndex) {
    setKeyInterpolation(trackId, channelName, keyIndex, KeyInterpolation.cubic);
    setTangentBroken(trackId, channelName, keyIndex, true);
  }
}
