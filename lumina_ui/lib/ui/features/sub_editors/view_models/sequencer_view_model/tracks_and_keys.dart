part of '../sequencer_view_model.dart';

/// Track and key editing: add/delete/rename tracks, add/move/delete keys,
/// interpolation and rebinding a track's actor.
mixin _SequencerTracksAndKeys on _SequencerViewModelState {

  void addTrack(String actorId, String actorName, SequencerTrackKind kind, {String? propertyName}) {
    final id = 'seq_track_${DateTime.now().millisecondsSinceEpoch}_${_data.tracks.length + 1}';
    final List<SequencerChannel> channels = [];

    switch (kind) {
      case SequencerTrackKind.transform:
        final names = [
          'Location.X', 'Location.Y', 'Location.Z',
          'Rotation.X', 'Rotation.Y', 'Rotation.Z',
          'Scale.X', 'Scale.Y', 'Scale.Z',
        ];
        for (final name in names) {
          channels.add(SequencerChannel(name: name));
        }
        break;
      case SequencerTrackKind.property:
        final prop = propertyName ?? 'intensity';
        channels.add(SequencerChannel(name: prop));
        break;
      case SequencerTrackKind.visibility:
        channels.add(SequencerChannel(name: 'visibility'));
        break;
    }

    final newTrack = SequencerTrack(
      id: id,
      actorId: actorId,
      actorName: actorName,
      kind: kind,
      propertyName: propertyName,
      channels: channels,
    );

    final trackIndex = _data.tracks.length;
    _data.tracks.add(newTrack);
    _selectedTrackId = id;
    _isDirty = true;
    EngineLoggerService().log('Sequencer: Added track "$actorName" (${kind.name})', level: 'info');

    transactions.record(EditorTransaction(
      label: 'Add Track "$actorName"',
      undo: () {
        _data.tracks.removeWhere((t) => t.id == id);
        if (_selectedTrackId == id) _selectedTrackId = null;
        _isDirty = true;
        notifyListeners();
      },
      redo: () {
        _data.tracks.insert(trackIndex.clamp(0, _data.tracks.length), newTrack);
        _selectedTrackId = id;
        _isDirty = true;
        notifyListeners();
      },
    ));

    notifyListeners();
  }

  void deleteTrack(String trackId) {
    final track = findTrack(trackId);
    if (track == null) return;
    final trackIndex = _data.tracks.indexOf(track);

    _data.tracks.removeWhere((t) => t.id == trackId);
    if (_selectedTrackId == trackId) {
      _selectedTrackId = null;
    }
    if (_selectedKey?.$1 == trackId) {
      _selectedKey = null;
    }
    _isDirty = true;
    EngineLoggerService().log('Sequencer: Deleted track "$trackId"', level: 'info');

    transactions.record(EditorTransaction(
      label: 'Delete Track "${track.actorName}"',
      undo: () {
        _data.tracks.insert(trackIndex.clamp(0, _data.tracks.length), track);
        _selectedTrackId = track.id;
        _isDirty = true;
        notifyListeners();
      },
      redo: () {
        _data.tracks.removeWhere((t) => t.id == trackId);
        if (_selectedTrackId == trackId) _selectedTrackId = null;
        _isDirty = true;
        notifyListeners();
      },
    ));

    notifyListeners();
  }

  void renameTrack(String trackId, String newActorName) {
    final track = findTrack(trackId);
    if (track != null) {
      final oldName = track.actorName;
      track.actorName = newActorName;
      _isDirty = true;
      transactions.record(EditorTransaction(
        label: 'Rename Track "$oldName" -> "$newActorName"',
        undo: () {
          final t = findTrack(trackId);
          if (t != null) {
            t.actorName = oldName;
            _isDirty = true;
            notifyListeners();
          }
        },
        redo: () {
          final t = findTrack(trackId);
          if (t != null) {
            t.actorName = newActorName;
            _isDirty = true;
            notifyListeners();
          }
        },
      ));
      notifyListeners();
    }
  }

  void addKey(
    String trackId,
    String channelName,
    int frame,
    double value, {
    KeyInterpolation interpolation = KeyInterpolation.linear,
    double inTangent = 0.0,
    double outTangent = 0.0,
  }) {
    final channel = findChannel(trackId, channelName);
    if (channel == null) return;

    final clampedFrame = frame.clamp(0, _data.lengthFrames);
    final existingIndex = channel.keys.indexWhere((k) => k.frame == clampedFrame);

    if (existingIndex >= 0) {
      final oldKey = channel.keys[existingIndex].copyWith();
      final newKey = oldKey.copyWith(
        value: value,
        interpolation: interpolation,
        inTangent: inTangent,
        outTangent: outTangent,
      );
      channel.keys[existingIndex] = newKey;
      _isDirty = true;

      transactions.record(EditorTransaction(
        label: 'Update Keyframe at frame $clampedFrame',
        undo: () {
          final ch = findChannel(trackId, channelName);
          if (ch != null && existingIndex < ch.keys.length) {
            ch.keys[existingIndex] = oldKey;
            _isDirty = true;
            notifyListeners();
          }
        },
        redo: () {
          final ch = findChannel(trackId, channelName);
          if (ch != null && existingIndex < ch.keys.length) {
            ch.keys[existingIndex] = newKey;
            _isDirty = true;
            notifyListeners();
          }
        },
      ));
    } else {
      final addedKey = SequencerKey(
        frame: clampedFrame,
        value: value,
        interpolation: interpolation,
        inTangent: inTangent,
        outTangent: outTangent,
      );
      channel.keys.add(addedKey);
      channel.keys.sort((a, b) => a.frame.compareTo(b.frame));
      _isDirty = true;

      transactions.record(EditorTransaction(
        label: 'Add Keyframe at frame $clampedFrame',
        undo: () {
          final ch = findChannel(trackId, channelName);
          if (ch != null) {
            ch.keys.remove(addedKey);
            if (_selectedKey?.$1 == trackId && _selectedKey?.$2 == channelName) {
              _selectedKey = null;
            }
            _isDirty = true;
            notifyListeners();
          }
        },
        redo: () {
          final ch = findChannel(trackId, channelName);
          if (ch != null) {
            ch.keys.add(addedKey);
            ch.keys.sort((a, b) => a.frame.compareTo(b.frame));
            _isDirty = true;
            notifyListeners();
          }
        },
      ));
    }

    notifyListeners();
  }

  void moveKey(String trackId, String channelName, int keyIndex, int newFrame) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;

    final key = channel.keys[keyIndex];
    final oldFrame = key.frame;
    final targetFrame = newFrame.clamp(0, _data.lengthFrames);
    if (oldFrame == targetFrame) return;

    key.frame = targetFrame;
    channel.keys.sort((a, b) => a.frame.compareTo(b.frame));
    final newIndex = channel.keys.indexOf(key);
    _selectedKey = (trackId, channelName, newIndex);
    _isDirty = true;

    transactions.record(EditorTransaction(
      label: 'Move Keyframe from $oldFrame to $targetFrame',
      undo: () {
        key.frame = oldFrame;
        final ch = findChannel(trackId, channelName);
        ch?.keys.sort((a, b) => a.frame.compareTo(b.frame));
        final idx = ch?.keys.indexOf(key) ?? 0;
        _selectedKey = (trackId, channelName, idx);
        _isDirty = true;
        notifyListeners();
      },
      redo: () {
        key.frame = targetFrame;
        final ch = findChannel(trackId, channelName);
        ch?.keys.sort((a, b) => a.frame.compareTo(b.frame));
        final idx = ch?.keys.indexOf(key) ?? 0;
        _selectedKey = (trackId, channelName, idx);
        _isDirty = true;
        notifyListeners();
      },
    ));

    notifyListeners();
  }

  void deleteKey(String trackId, String channelName, int keyIndex) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;

    final removedKey = channel.keys[keyIndex];
    channel.keys.removeAt(keyIndex);
    if (_selectedKey?.$1 == trackId && _selectedKey?.$2 == channelName && _selectedKey?.$3 == keyIndex) {
      _selectedKey = null;
    }
    _selectedKeys.remove((trackId, channelName, keyIndex));
    _brokenTangentKeys.remove(_keyId(trackId, channelName, keyIndex));
    _applyPlayheadToLevel();

    _isDirty = true;

    transactions.record(EditorTransaction(
      label: 'Delete Keyframe at frame ${removedKey.frame}',
      undo: () {
        final ch = findChannel(trackId, channelName);
        if (ch != null) {
          ch.keys.insert(keyIndex.clamp(0, ch.keys.length), removedKey);
          ch.keys.sort((a, b) => a.frame.compareTo(b.frame));
          final idx = ch.keys.indexOf(removedKey);
          _selectedKey = (trackId, channelName, idx);
          _isDirty = true;
          notifyListeners();
        }
      },
      redo: () {
        final ch = findChannel(trackId, channelName);
        if (ch != null) {
          ch.keys.remove(removedKey);
          if (_selectedKey?.$1 == trackId && _selectedKey?.$2 == channelName) {
            _selectedKey = null;
          }
          _isDirty = true;
          notifyListeners();
        }
      },
    ));

    notifyListeners();
  }

  @override
  void setKeyInterpolation(String trackId, String channelName, int keyIndex, KeyInterpolation interp) {
    final channel = findChannel(trackId, channelName);
    if (channel == null || keyIndex < 0 || keyIndex >= channel.keys.length) return;

    final oldInterp = channel.keys[keyIndex].interpolation;
    if (oldInterp == interp) return;
    channel.keys[keyIndex].interpolation = interp;
    _isDirty = true;

    transactions.record(EditorTransaction(
      label: 'Set Key Interpolation (${interp.name})',
      undo: () {
        final ch = findChannel(trackId, channelName);
        if (ch != null && keyIndex < ch.keys.length) {
          ch.keys[keyIndex].interpolation = oldInterp;
          _isDirty = true;
          notifyListeners();
        }
      },
      redo: () {
        final ch = findChannel(trackId, channelName);
        if (ch != null && keyIndex < ch.keys.length) {
          ch.keys[keyIndex].interpolation = interp;
          _isDirty = true;
          notifyListeners();
        }
      },
    ));

    notifyListeners();
  }

  bool isActorMissing(String actorId, Set<String> levelActorIds) {
    if (actorId.isEmpty) return true;
    return !levelActorIds.contains(actorId);
  }

  void rebindActor(String trackId, String newActorId, String newActorName) {
    final track = findTrack(trackId);
    if (track != null) {
      final oldId = track.actorId;
      final oldName = track.actorName;
      track.actorId = newActorId;
      track.actorName = newActorName;
      _isDirty = true;
      EngineLoggerService().log('Sequencer: Rebound track "$trackId" to actor "$newActorName" ($newActorId)', level: 'info');

      transactions.record(EditorTransaction(
        label: 'Rebind Track to "$newActorName"',
        undo: () {
          final t = findTrack(trackId);
          if (t != null) {
            t.actorId = oldId;
            t.actorName = oldName;
            _isDirty = true;
            notifyListeners();
          }
        },
        redo: () {
          final t = findTrack(trackId);
          if (t != null) {
            t.actorId = newActorId;
            t.actorName = newActorName;
            _isDirty = true;
            notifyListeners();
          }
        },
      ));

      notifyListeners();
    }
  }
}
