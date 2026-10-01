part of '../sequencer_view_model.dart';

/// An actor's location, rotation and scale (stored axes, degrees, cm).
typedef _ActorTransform = ({List<double> location, List<double> rotation, List<double> scale});

/// A transform edit the level made on an actor (the level viewport's gizmo,
/// Details), with the actor's transform before it.
typedef SequencerLevelTransformEdit = ({
  EditorActorNode actor,
  List<double> location,
  List<double> rotation,
  List<double> scale,
});

/// The interpolation choices the Key panel offers: the model's three modes,
/// and cubic with tangents computed from the neighbours.
enum SequencerKeyInterpolationChoice { constant, linear, cubic, cubicAuto }

/// Keying from the viewport (Auto Key, the gizmo's edit path, the level's
/// transform edits while the Sequencer is open, the Key button) and the Key
/// panel's edits of the selected keys. Every multi-key edit is one undo step
/// that restores the sequence's own track, channel and key objects in place.
mixin _SequencerKeying on _SequencerViewModelState {
  /// The nine channels of a transform track, in order.
  static const List<String> transformChannels = [
    'Location.X', 'Location.Y', 'Location.Z',
    'Rotation.X', 'Rotation.Y', 'Rotation.Z',
    'Scale.X', 'Scale.Y', 'Scale.Z',
  ];

  static const double _tolerance = 1e-4;

  /// Whether a transform change is keyed at the playhead when it is made
  /// (on by default); off, it is a preview the next scrub reverts.
  bool get autoKey => _autoKey;

  void setAutoKey(bool value) {
    if (value == _autoKey) return;
    _autoKey = value;
    onAutoKeyChanged?.call(value);
    notifyListeners();
  }

  /// Whether a transform change made with Auto Key off waits to be keyed.
  bool get hasPendingPreview => _pendingPreview.isNotEmpty;

  /// The actor ids whose unkeyed previews the next evaluation reverts.
  Set<String> get pendingPreviewActorIds => Set.unmodifiable(_pendingPreview.keys);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<double> _three(List<double> v, double fill) =>
      [for (var i = 0; i < 3; i++) i < v.length ? v[i] : fill];

  static _ActorTransform _transformOf(EditorActorNode a) =>
      (location: _three(a.location, 0.0), rotation: _three(a.rotation, 0.0), scale: _three(a.scale, 1.0));

  static void _applyTransform(EditorActorNode a, _ActorTransform t) {
    a.location = List<double>.of(t.location);
    a.rotation = List<double>.of(t.rotation);
    a.scale = List<double>.of(t.scale);
  }

  /// The value of transform channel [name] (`Location.X` …) in [t].
  static double channelValue(_ActorTransform t, String name) {
    final i = transformChannels.indexOf(name);
    final list = i < 3 ? t.location : (i < 6 ? t.rotation : t.scale);
    return list[i % 3];
  }

  /// The channels whose value differs between [before] and [after].
  static Map<String, double> _changedChannels(_ActorTransform before, _ActorTransform after) => {
        for (final name in transformChannels)
          if ((channelValue(before, name) - channelValue(after, name)).abs() > _tolerance) name: channelValue(after, name),
      };

  EditorActorNode? _levelActor(String actorId) {
    final actors = _levelActors?.call();
    return actors == null ? null : _findActor(actors, actorId);
  }

  /// The first transform track bound to [actorId].
  SequencerTrack? transformTrackFor(String actorId) {
    for (final t in _data.tracks) {
      if (t.actorId == actorId && t.kind == SequencerTrackKind.transform) return t;
    }
    return null;
  }

  /// Whether any track of the sequence is bound to [actorId].
  bool isActorBound(String actorId) => _data.tracks.any((t) => t.actorId == actorId);

  /// Remembers the level's values of [actor]'s nine transform channels
  /// (taken from [before], the transform before any edit) for [restoreLevel],
  /// unless an earlier write already did.
  void _captureTransformOriginals(EditorActorNode actor, _ActorTransform before) {
    final sample = TrackSample(
        trackId: '', actorId: actor.id, kind: SequencerTrackKind.transform, propertyName: null, values: const {});
    for (final name in transformChannels) {
      final writer = _ChannelSnapshot.resolve(actor, sample, name);
      if (writer == null) continue;
      _snapshot.putIfAbsent(writer.id, () => writer..captureValue(channelValue(before, name)));
    }
  }

  @override
  void _revertPendingPreviews(List<EditorActorNode> actors) {
    if (_pendingPreview.isEmpty) return;
    for (final entry in _pendingPreview.entries) {
      final actor = _findActor(actors, entry.key);
      if (actor != null) _applyTransform(actor, entry.value);
    }
    _pendingPreview.clear();
  }

  void _pruneKeySelection() {
    bool valid(SequencerKeyRef r) {
      final ch = findChannel(r.$1, r.$2);
      return ch != null && r.$3 >= 0 && r.$3 < ch.keys.length;
    }

    _selectedKeys.removeWhere((r) => !valid(r));
    if (_selectedKey != null && !valid(_selectedKey!)) {
      _selectedKey = _selectedKeys.isEmpty ? null : _selectedKeys.last;
    }
    if (_selectedTrackId != null && findTrack(_selectedTrackId!) == null) _selectedTrackId = null;
  }

  /// Records one undo step from [before] to the sequence as it is now, and
  /// optionally the actors' poses before/after (an auto-key also puts the
  /// actor back on undo: with its key gone nothing would sample it back).
  void _recordKeyEdit(
    String label,
    _SequenceKeyState before, {
    Map<String, (_ActorTransform before, _ActorTransform after)> poses = const {},
  }) {
    final after = _SequenceKeyState.capture(_data);
    final beforeSelection = (_selectedKey, Set<SequencerKeyRef>.of(_selectedKeys));
    void apply(_SequenceKeyState state, bool undo) {
      state.restore(_data);
      if (poses.isNotEmpty) {
        final actors = _levelActors?.call() ?? const <EditorActorNode>[];
        for (final entry in poses.entries) {
          final actor = _findActor(actors, entry.key);
          if (actor != null) _applyTransform(actor, undo ? entry.value.$1 : entry.value.$2);
        }
      }
      if (undo) {
        _selectedKey = beforeSelection.$1;
        _selectedKeys
          ..clear()
          ..addAll(beforeSelection.$2);
      }
      _pruneKeySelection();
      _isDirty = true;
      _applyPlayheadToLevel();
      if (poses.isNotEmpty) _onLevelChanged?.call();
      notifyListeners();
    }

    transactions.record(EditorTransaction(
      label: label,
      undo: () => apply(before, true),
      redo: () => apply(after, false),
    ));
    _isDirty = true;
  }

  /// Puts [value] on [channel] at [frame]: updates the key there (keeping its
  /// interpolation and tangents) or adds a key with the default
  /// interpolation.
  static SequencerKey _setKeyAt(SequencerChannel channel, int frame, double value) {
    for (final k in channel.keys) {
      if (k.frame == frame) {
        k.value = value;
        return k;
      }
    }
    final key = SequencerKey(frame: frame, value: value);
    channel.keys.add(key);
    channel.keys.sort((a, b) => a.frame.compareTo(b.frame));
    return key;
  }

  SequencerChannel _channelOf(SequencerTrack track, String name) {
    for (final c in track.channels) {
      if (c.name == name) return c;
    }
    final channel = SequencerChannel(name: name);
    if (track.kind == SequencerTrackKind.transform) {
      // Keep the nine channels in their usual order.
      final order = transformChannels.indexOf(name);
      var at = track.channels.length;
      for (var i = 0; i < track.channels.length; i++) {
        final o = transformChannels.indexOf(track.channels[i].name);
        if (o > order) {
          at = i;
          break;
        }
      }
      track.channels.insert(at, channel);
    } else {
      track.channels.add(channel);
    }
    return channel;
  }

  /// The transform track of [actor], created (bound, nine channels) when missing.
  SequencerTrack _ensureTransformTrack(EditorActorNode actor) {
    final existing = transformTrackFor(actor.id);
    if (existing != null) return existing;
    final track = SequencerTrack(
      id: 'seq_track_${DateTime.now().microsecondsSinceEpoch}_${_data.tracks.length + 1}',
      actorId: actor.id,
      actorName: actor.name,
      kind: SequencerTrackKind.transform,
      channels: [for (final name in transformChannels) SequencerChannel(name: name)],
    );
    _data.tracks.add(track);
    EngineLoggerService().log('Sequencer: Added track "${actor.name}" (transform) by keying it', level: 'info');
    return track;
  }

  /// Keys [values] (channel → value per actor) at the playhead as one step.
  void _keyTransforms(
    Map<EditorActorNode, Map<String, double>> values,
    String label, {
    Map<String, (_ActorTransform, _ActorTransform)> poses = const {},
  }) {
    if (values.values.every((v) => v.isEmpty)) return;
    final before = _SequenceKeyState.capture(_data);
    final frame = playheadFrame.clamp(0, _data.lengthFrames);
    String? trackId;
    for (final entry in values.entries) {
      if (entry.value.isEmpty) continue;
      final track = _ensureTransformTrack(entry.key);
      trackId = track.id;
      for (final c in entry.value.entries) {
        _setKeyAt(_channelOf(track, c.key), frame, c.value);
      }
    }
    if (trackId != null) _selectedTrackId = trackId;
    _recordKeyEdit(label, before, poses: poses);
    _applyPlayheadToLevel();
    notifyListeners();
  }

  /// Keys the change from [before] to [actor]'s transform now (Auto Key on)
  /// or keeps it as a preview to key later (off). Returns whether anything
  /// changed.
  bool _commitTransformChange(EditorActorNode actor, _ActorTransform before) {
    final after = _transformOf(actor);
    final changed = _changedChannels(before, after);
    if (changed.isEmpty) return false;
    if (_autoKey) {
      _pendingPreview.remove(actor.id);
      _keyTransforms({actor: changed}, 'Auto Key ${actor.name} (frame $playheadFrame)',
          poses: {actor.id: (before, after)});
    } else {
      _pendingPreview.putIfAbsent(actor.id, () => before);
      notifyListeners();
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // The Sequencer viewport's gizmo
  // ---------------------------------------------------------------------------

  /// A gizmo gesture on [actorId] starts: remembers its transform and the
  /// level's values for [restoreLevel].
  void beginActorTransform(String actorId) {
    final actor = _levelActor(actorId);
    if (actor == null) return;
    final before = _transformOf(actor);
    _editBefore[actorId] = before;
    _captureTransformOriginals(actor, before);
  }

  /// A gizmo drag frame: writes the transform straight onto the actor (no
  /// undo step, no key yet).
  void previewActorTransform(String actorId, {List<double>? location, List<double>? rotation, List<double>? scale}) {
    final actor = _levelActor(actorId);
    if (actor == null) return;
    if (!_editBefore.containsKey(actorId)) beginActorTransform(actorId);
    if (location != null) actor.location = List<double>.of(location);
    if (rotation != null) actor.rotation = List<double>.of(rotation);
    if (scale != null) actor.scale = List<double>.of(scale);
    _onLevelChanged?.call();
  }

  /// The gesture ends: keys the changed channels at the playhead (one undo
  /// step, binding the actor when the sequence has no track for it) with
  /// Auto Key on, or keeps the change as a preview with it off.
  bool endActorTransform(String actorId) {
    final before = _editBefore.remove(actorId);
    final actor = _levelActor(actorId);
    if (before == null || actor == null) return false;
    return _commitTransformChange(actor, before);
  }

  /// Esc during a drag: the actor goes back, nothing is keyed.
  void cancelActorTransform(String actorId) {
    final before = _editBefore.remove(actorId);
    final actor = _levelActor(actorId);
    if (before == null || actor == null) return;
    _applyTransform(actor, before);
    _onLevelChanged?.call();
  }

  /// The level's transform edits while this Sequencer is open: the actors the
  /// sequence animates are keyed (or previewed, Auto Key off) here instead
  /// of being written into the level. Returns the ids taken.
  Set<String> handleLevelTransformEdits(List<SequencerLevelTransformEdit> edits) {
    final taken = <String>{};
    final keyed = <EditorActorNode, Map<String, double>>{};
    final poses = <String, (_ActorTransform, _ActorTransform)>{};
    for (final edit in edits) {
      final actor = edit.actor;
      if (!isActorBound(actor.id)) continue;
      final before = (location: _three(edit.location, 0.0), rotation: _three(edit.rotation, 0.0), scale: _three(edit.scale, 1.0));
      _captureTransformOriginals(actor, before);
      taken.add(actor.id);
      final after = _transformOf(actor);
      final changed = _changedChannels(before, after);
      if (changed.isEmpty) continue;
      if (_autoKey) {
        _pendingPreview.remove(actor.id);
        keyed[actor] = changed;
        poses[actor.id] = (before, after);
      } else {
        _pendingPreview.putIfAbsent(actor.id, () => before);
      }
    }
    if (keyed.isNotEmpty) {
      final names = keyed.keys.map((a) => a.name).join(', ');
      _keyTransforms(keyed, 'Auto Key $names (frame $playheadFrame)', poses: poses);
    } else if (taken.isNotEmpty) {
      notifyListeners();
    }
    return taken;
  }

  /// The Key button: keys the previews Auto Key did not key, or else every
  /// transform channel of [selectedActorId] at the playhead.
  void keyPendingOrSelected({String? selectedActorId}) {
    final actors = _levelActors?.call() ?? const <EditorActorNode>[];
    if (_pendingPreview.isNotEmpty) {
      final values = <EditorActorNode, Map<String, double>>{};
      final poses = <String, (_ActorTransform, _ActorTransform)>{};
      for (final entry in _pendingPreview.entries) {
        final actor = _findActor(actors, entry.key);
        if (actor == null) continue;
        final after = _transformOf(actor);
        values[actor] = _changedChannels(entry.value, after);
        poses[actor.id] = (entry.value, after);
      }
      _pendingPreview.clear();
      _keyTransforms(values, 'Key ${values.keys.map((a) => a.name).join(', ')} (frame $playheadFrame)', poses: poses);
      notifyListeners();
      return;
    }
    if (selectedActorId == null) return;
    final actor = _findActor(actors, selectedActorId);
    if (actor == null) return;
    final now = _transformOf(actor);
    _captureTransformOriginals(actor, now);
    _keyTransforms({actor: {for (final name in transformChannels) name: channelValue(now, name)}},
        'Key ${actor.name} (frame $playheadFrame)');
  }

  /// Selects the track of [actorId] (the viewport's click), without touching
  /// the key selection or the level selection.
  void selectTrackForActor(String? actorId) {
    if (actorId == null) return;
    final current = _selectedTrackId == null ? null : findTrack(_selectedTrackId!);
    if (current?.actorId == actorId) return;
    for (final t in _data.tracks) {
      if (t.actorId == actorId) {
        _selectedTrackId = t.id;
        notifyListeners();
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // The Key panel
  // ---------------------------------------------------------------------------

  /// The key [ref] points at, or null.
  SequencerKey? keyAt(SequencerKeyRef ref) {
    final ch = findChannel(ref.$1, ref.$2);
    if (ch == null || ref.$3 < 0 || ref.$3 >= ch.keys.length) return null;
    return ch.keys[ref.$3];
  }

  /// [channelName]'s value at [frame]: the key there, else the curve sampled
  /// there, else null (the channel has no keys).
  double? channelValueAtFrame(String trackId, String channelName, int frame) {
    final ch = findChannel(trackId, channelName);
    if (ch == null) return null;
    return SequencerEvaluator.evaluateChannel(ch, frame.toDouble());
  }

  /// The live value of transform channel [channelName] on the level's actor
  /// [actorId] (what an unkeyed channel shows), or null.
  double? currentActorChannelValue(String actorId, String channelName) {
    final actor = _levelActor(actorId);
    if (actor == null || !transformChannels.contains(channelName)) return null;
    return channelValue(_transformOf(actor), channelName);
  }

  /// Whether [channelName] has a key exactly at [frame].
  bool hasKeyAt(String trackId, String channelName, int frame) =>
      findChannel(trackId, channelName)?.keys.any((k) => k.frame == frame) ?? false;

  /// Writes [value] at [frame] on [channelName] (a key there is updated, else
  /// added; a missing transform channel is created) as one undo step.
  void setChannelValueAtFrame(String trackId, String channelName, int frame, double value) {
    final track = findTrack(trackId);
    if (track == null) return;
    final f = frame.clamp(0, _data.lengthFrames);
    final existing = findChannel(trackId, channelName)?.keys.where((k) => k.frame == f).firstOrNull;
    if (existing != null && (existing.value - value).abs() <= 1e-9) return;
    final before = _SequenceKeyState.capture(_data);
    _setKeyAt(_channelOf(track, channelName), f, value);
    _recordKeyEdit('Set $channelName = ${value.toStringAsFixed(2)} (frame $f)', before);
    _applyPlayheadToLevel();
    notifyListeners();
  }

  /// Retimes every selected key to [frameOf] its frame; a key already at the
  /// target frame on the same channel (and not selected) is replaced. One
  /// undo step; the selection follows the keys.
  void _retimeSelectedKeys(int Function(int frame) frameOf, String label) {
    if (_selectedKeys.isEmpty) return;
    final refs = _selectedKeys.toList();
    final moving = <(String, String, SequencerKey)>[];
    for (final r in refs) {
      final key = keyAt(r);
      if (key != null) moving.add((r.$1, r.$2, key));
    }
    if (moving.isEmpty) return;
    final targets = {for (final m in moving) m.$3: frameOf(m.$3.frame).clamp(0, _data.lengthFrames)};
    if (targets.entries.every((e) => e.key.frame == e.value)) return;
    final primary = _selectedKey == null ? null : keyAt(_selectedKey!);
    final before = _SequenceKeyState.capture(_data);
    final movingKeys = targets.keys.toSet();
    for (final m in moving) {
      final ch = findChannel(m.$1, m.$2)!;
      final target = targets[m.$3]!;
      ch.keys.removeWhere((k) => !movingKeys.contains(k) && k.frame == target);
    }
    for (final m in moving) {
      m.$3.frame = targets[m.$3]!;
    }
    _selectedKeys.clear();
    _selectedKey = null;
    for (final m in moving) {
      final ch = findChannel(m.$1, m.$2)!;
      ch.keys.sort((a, b) => a.frame.compareTo(b.frame));
    }
    for (final m in moving) {
      final ch = findChannel(m.$1, m.$2)!;
      final ref = (m.$1, m.$2, ch.keys.indexOf(m.$3));
      _selectedKeys.add(ref);
      if (identical(m.$3, primary)) _selectedKey = ref;
    }
    _selectedKey ??= _selectedKeys.isEmpty ? null : _selectedKeys.first;
    _recordKeyEdit(label, before);
    _applyPlayheadToLevel();
    notifyListeners();
  }

  /// The Key panel's frame field: moves the selected keys to [frame].
  void moveSelectedKeysToFrame(int frame) =>
      _retimeSelectedKeys((_) => frame, 'Move ${_selectedKeys.length} key(s) to frame $frame');

  /// Left/Right on the timeline: moves the selected keys by [delta] frames.
  void nudgeSelectedKeys(int delta) =>
      _retimeSelectedKeys((f) => f + delta, 'Nudge ${_selectedKeys.length} key(s) ${delta > 0 ? '+' : ''}$delta');

  /// Sets the selected keys' interpolation (one undo step); Cubic (Auto)
  /// also sets each key's tangents from its neighbours.
  void setSelectedKeysInterpolation(SequencerKeyInterpolationChoice choice) {
    if (_selectedKeys.isEmpty) return;
    final before = _SequenceKeyState.capture(_data);
    var changed = false;
    for (final r in _selectedKeys) {
      final ch = findChannel(r.$1, r.$2);
      final key = keyAt(r);
      if (ch == null || key == null) continue;
      final interp = switch (choice) {
        SequencerKeyInterpolationChoice.constant => KeyInterpolation.constant,
        SequencerKeyInterpolationChoice.linear => KeyInterpolation.linear,
        _ => KeyInterpolation.cubic,
      };
      if (key.interpolation != interp) {
        key.interpolation = interp;
        changed = true;
      }
      if (choice == SequencerKeyInterpolationChoice.cubicAuto) {
        final t = SequencerEvaluator.autoTangent(ch.keys, r.$3);
        if (key.inTangent != t || key.outTangent != t) {
          key.inTangent = t;
          key.outTangent = t;
          changed = true;
        }
        _brokenTangentKeys.remove(_keyId(r.$1, r.$2, r.$3));
      }
    }
    if (!changed) return;
    _recordKeyEdit('Set Interpolation (${choice.name})', before);
    _applyPlayheadToLevel();
    notifyListeners();
  }

  /// Deletes every selected key as one undo step.
  void deleteSelectedKeys() {
    if (_selectedKeys.isEmpty) return;
    final before = _SequenceKeyState.capture(_data);
    final doomed = <SequencerChannel, Set<SequencerKey>>{};
    for (final r in _selectedKeys) {
      final ch = findChannel(r.$1, r.$2);
      final key = keyAt(r);
      if (ch != null && key != null) (doomed[ch] ??= {}).add(key);
      _brokenTangentKeys.remove(_keyId(r.$1, r.$2, r.$3));
    }
    if (doomed.isEmpty) return;
    var count = 0;
    for (final e in doomed.entries) {
      count += e.value.length;
      e.key.keys.removeWhere(e.value.contains);
    }
    _selectedKeys.clear();
    _selectedKey = null;
    _recordKeyEdit('Delete $count key(s)', before);
    _applyPlayheadToLevel();
    notifyListeners();
  }
}

/// The keys of a whole sequence, held as the sequence's own objects with
/// their field values, so restoring puts the same objects back (older undo
/// steps keep their references valid).
class _SequenceKeyState {
  final List<SequencerTrack> _tracks;
  final Map<SequencerTrack, List<SequencerChannel>> _channels;
  final Map<SequencerChannel, List<(SequencerKey, int, double, KeyInterpolation, double, double)>> _keys;

  _SequenceKeyState._(this._tracks, this._channels, this._keys);

  factory _SequenceKeyState.capture(SequencerData data) {
    final channels = <SequencerTrack, List<SequencerChannel>>{};
    final keys = <SequencerChannel, List<(SequencerKey, int, double, KeyInterpolation, double, double)>>{};
    for (final t in data.tracks) {
      channels[t] = List.of(t.channels);
      for (final c in t.channels) {
        keys[c] = [for (final k in c.keys) (k, k.frame, k.value, k.interpolation, k.inTangent, k.outTangent)];
      }
    }
    return _SequenceKeyState._(List.of(data.tracks), channels, keys);
  }

  void restore(SequencerData data) {
    data.tracks
      ..clear()
      ..addAll(_tracks);
    for (final t in _tracks) {
      t.channels
        ..clear()
        ..addAll(_channels[t] ?? const []);
    }
    for (final e in _keys.entries) {
      e.key.keys
        ..clear()
        ..addAll([
          for (final (k, frame, value, interp, inT, outT) in e.value)
            k
              ..frame = frame
              ..value = value
              ..interpolation = interp
              ..inTangent = inT
              ..outTangent = outT,
        ]);
    }
  }
}
