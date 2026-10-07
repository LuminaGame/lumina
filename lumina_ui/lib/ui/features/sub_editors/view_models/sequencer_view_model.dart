import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';

part 'sequencer_view_model/state.dart';
part 'sequencer_view_model/tracks_and_keys.dart';
part 'sequencer_view_model/curve_editing.dart';
part 'sequencer_view_model/playback_and_level_binding.dart';
part 'sequencer_view_model/render_queue.dart';
part 'sequencer_view_model/keying.dart';

/// How the transport bar's current-time readout is formatted.
enum SequencerTimeFormat { frames, seconds, timecode }

/// A keyframe reference `(trackId, channelName, keyIndex)`.
typedef SequencerKeyRef = (String trackId, String channelName, int keyIndex);

class SequencerViewModel extends _SequencerViewModelState
    with
        _SequencerTracksAndKeys,
        _SequencerCurveEditing,
        _SequencerPlaybackAndLevelBinding,
        _SequencerRenderQueue,
        _SequencerKeying {
  SequencerViewModel({
    required super.assetPath,
    super.initialAsset,
    super.transactionManager,
    super.vsync,
    super.levelActorsProvider,
    super.onLevelChanged,
    super.projectDirPath,
    super.renderService,
    super.autoKey,
  });
  static const SequencerEvaluator _evaluator = SequencerEvaluator();

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  @override
  LuminaAsset? get asset => _asset;

  SequencerData get data => _data;
  @override
  int get fps => _data.fps;
  @override
  int get lengthFrames => _data.lengthFrames;
  @override
  int get playheadFrame => _playheadPosition.round();
  @override
  set playheadFrame(int frame) => scrubToFrame(frame);
  double get playheadPosition => _playheadPosition;
  @override
  List<SequencerTrack> get tracks => List.unmodifiable(_data.tracks);
  String? get selectedTrackId => _selectedTrackId;
  SequencerKeyRef? get selectedKey => _selectedKey;
  Set<SequencerKeyRef> get selectedKeys => Set.unmodifiable(_selectedKeys);

  bool get isPlaying => _isPlaying;
  bool get isLooping => _isLooping;
  int get rangeStart => _rangeStart;
  @override
  int get rangeEnd => (_rangeEnd ?? _data.lengthFrames).clamp(0, _data.lengthFrames);
  SequencerTimeFormat get timeFormat => _timeFormat;
  bool get hasLevelBinding => _levelActors != null;
  bool get isPreviewingLevel => _snapshot.isNotEmpty;

  /// Current-time readout in the selected [timeFormat].
  String get timeReadout {
    switch (_timeFormat) {
      case SequencerTimeFormat.frames:
        return '$playheadFrame f';
      case SequencerTimeFormat.seconds:
        final curFps = fps > 0 ? fps : 30;
        return '${(_playheadPosition / curFps).toStringAsFixed(3)} s';
      case SequencerTimeFormat.timecode:
        return timecodeStr;
    }
  }

  bool get canUndo => transactions.canUndo;
  bool get canRedo => transactions.canRedo;
  @override
  void undo() => transactions.undo();
  @override
  void redo() => transactions.redo();

  @override
  String get fileBasename {
    final file = File(assetPath);
    return file.path.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  }

  String get timecodeStr {
    final curFps = fps > 0 ? fps : 30;
    final wholeFrame = playheadFrame;
    final totalSeconds = wholeFrame / curFps;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds.toInt() % 60).toString().padLeft(2, '0');
    final frame = (wholeFrame % curFps).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds:$frame';
  }

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      if (initialAsset != null) {
        _asset = initialAsset;
      } else {
        final file = File(assetPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            _asset = LuminaAsset.fromBytes(bytes);
          } catch (_) {}
        }
      }

      if (_asset?.rawPayload != null && _asset!.rawPayload!.isNotEmpty) {
        _data = SequencerData.fromBytes(_asset!.rawPayload!);
      } else {
        _data = SequencerData(fps: 30, lengthFrames: 120, tracks: []);
      }

      _isLoading = false;
      _isDirty = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  /// Moves the playhead and writes the sampled pose onto the live level
  /// immediately — no play required.
  @override
  void scrubToFrame(int frame) {
    _setPlayhead(frame.toDouble());
  }

  @override
  void _setPlayhead(double position) {
    _playheadPosition = position.clamp(0.0, _data.lengthFrames.toDouble());
    _applyPlayheadToLevel();
    notifyListeners();
  }

  void setFps(int newFps) {
    if (newFps <= 0 || newFps == _data.fps) return;
    final oldFps = _data.fps;
    _data.fps = newFps;
    _isDirty = true;
    transactions.record(EditorTransaction(
      label: 'Change FPS ($newFps)',
      undo: () {
        _data.fps = oldFps;
        _isDirty = true;
        notifyListeners();
      },
      redo: () {
        _data.fps = newFps;
        _isDirty = true;
        notifyListeners();
      },
    ));
    notifyListeners();
  }

  void setLengthFrames(int len) {
    if (len < 10) len = 10;
    if (len == _data.lengthFrames) return;
    final oldLen = _data.lengthFrames;
    _data.lengthFrames = len;
    if (_playheadPosition > len) {
      _playheadPosition = len.toDouble();
    }
    _clampRangeToLength();
    _isDirty = true;
    transactions.record(EditorTransaction(
      label: 'Change Sequence Length ($len f)',
      undo: () {
        _data.lengthFrames = oldLen;
        _clampRangeToLength();
        _isDirty = true;
        notifyListeners();
      },
      redo: () {
        _data.lengthFrames = len;
        if (_playheadPosition > len) {
          _playheadPosition = len.toDouble();
        }
        _clampRangeToLength();
        _isDirty = true;
        notifyListeners();
      },
    ));
    notifyListeners();
  }

  void _clampRangeToLength() {
    final len = _data.lengthFrames;
    if (_rangeStart > len) _rangeStart = len;
    if (_rangeEnd != null && _rangeEnd! > len) _rangeEnd = null;
  }

  /// Selects [trackId] (clearing the key selection) and its actor in the
  /// level, so the Sequencer viewport's gizmo and Details show it.
  void selectTrack(String? trackId) {
    _selectedTrackId = trackId;
    _selectedKey = null;
    _selectedKeys.clear();
    final actorId = trackId == null ? null : findTrack(trackId)?.actorId;
    if (actorId != null && actorId.isNotEmpty) _selectLevelActor?.call(actorId);
    notifyListeners();
  }

  void selectKey(String trackId, String channelName, int keyIndex) {
    _selectedKey = (trackId, channelName, keyIndex);
    _selectedKeys
      ..clear()
      ..add(_selectedKey!);
    _selectedTrackId = trackId;
    notifyListeners();
  }

  /// Shift-click: adds the key to the selection (it becomes the primary key
  /// the Key panel shows), or takes it out when it is already selected.
  void toggleKeySelection(String trackId, String channelName, int keyIndex) {
    final ref = (trackId, channelName, keyIndex);
    if (_selectedKeys.contains(ref)) {
      _selectedKeys.remove(ref);
      if (_selectedKey == ref) _selectedKey = _selectedKeys.isEmpty ? null : _selectedKeys.last;
    } else {
      _selectedKeys.add(ref);
      _selectedKey = ref;
      _selectedTrackId = trackId;
    }
    notifyListeners();
  }

  /// Box-select: replaces the selection with [keys]; the first becomes the
  /// primary [selectedKey] whose tangent handles are shown.
  void selectKeys(Iterable<SequencerKeyRef> keys) {
    _selectedKeys
      ..clear()
      ..addAll(keys);
    _selectedKey = _selectedKeys.isEmpty ? null : _selectedKeys.first;
    if (_selectedKey != null) _selectedTrackId = _selectedKey!.$1;
    notifyListeners();
  }

  bool isKeySelected(String trackId, String channelName, int keyIndex) =>
      _selectedKeys.contains((trackId, channelName, keyIndex));

  void clearKeySelection() {
    _selectedKey = null;
    _selectedKeys.clear();
    notifyListeners();
  }

  @override
  SequencerTrack? findTrack(String trackId) {
    try {
      return _data.tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  @override
  SequencerChannel? findChannel(String trackId, String channelName) {
    final track = findTrack(trackId);
    if (track == null) return null;
    try {
      return track.channels.firstWhere((c) => c.name == channelName);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    restoreLevel();
    super.dispose();
  }

  @override
  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});
    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['fps'] = '${_data.fps}';
    updatedMetadata['length_frames'] = '${_data.lengthFrames}';
    updatedMetadata['track_count'] = '${_data.tracks.length}';

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.sequencer,
      rawPayload: _data.toBytes(),
      thumbnailPng: _asset?.thumbnailPng,
      metadata: updatedMetadata,
      references: _asset?.references ?? [],
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;
      EngineLoggerService().log('Saved Sequencer asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save Sequencer asset: $e\n$st', level: 'error');
      return false;
    }
  }
}

/// One animated actor property: knows how to read/write it on an
/// [EditorActorNode] and keeps the pre-preview value for [restore]. The
/// snapshot is per channel, never a whole-actor copy.
class _ChannelSnapshot {
  final String actorId;
  final String id;
  final void Function(EditorActorNode actor, double value) _write;
  final dynamic Function(EditorActorNode actor) _read;
  final void Function(EditorActorNode actor, dynamic original) _restore;
  dynamic _original;

  _ChannelSnapshot._({
    required this.actorId,
    required this.id,
    required void Function(EditorActorNode, double) write,
    required dynamic Function(EditorActorNode) read,
    required void Function(EditorActorNode, dynamic) restore,
  })  : _write = write, // ignore: prefer_initializing_formals
        _read = read, // ignore: prefer_initializing_formals
        _restore = restore; // ignore: prefer_initializing_formals

  void capture(EditorActorNode actor) => _original = _read(actor);

  /// Records [original] as the pre-preview value (an edit's before-value,
  /// when the actor already moved).
  void captureValue(dynamic original) => _original = original;
  void write(EditorActorNode actor, double value) => _write(actor, value);
  void restore(EditorActorNode actor) => _restore(actor, _original);

  static const _axis = {'X': 0, 'Y': 1, 'Z': 2};

  static _ChannelSnapshot? resolve(EditorActorNode actor, TrackSample sample, String channelName) {
    switch (sample.kind) {
      case SequencerTrackKind.transform:
        final parts = channelName.split('.');
        if (parts.length != 2) return null;
        final axis = _axis[parts[1].toUpperCase()];
        if (axis == null) return null;
        final group = parts[0].toLowerCase();
        List<double> Function(EditorActorNode) getList;
        void Function(EditorActorNode, List<double>) setList;
        switch (group) {
          case 'location':
            getList = (a) => a.location;
            setList = (a, v) => a.location = v;
            break;
          case 'rotation':
            getList = (a) => a.rotation;
            setList = (a, v) => a.rotation = v;
            break;
          case 'scale':
            getList = (a) => a.scale;
            setList = (a, v) => a.scale = v;
            break;
          default:
            return null;
        }
        return _ChannelSnapshot._(
          actorId: actor.id,
          id: '${actor.id}|$group.$axis',
          read: (a) => getList(a)[axis],
          write: (a, v) {
            final list = List<double>.from(getList(a));
            while (list.length < 3) {
              list.add(group == 'scale' ? 1.0 : 0.0);
            }
            list[axis] = v;
            setList(a, list); // new list instance so listeners see a change
          },
          restore: (a, original) {
            final list = List<double>.from(getList(a));
            while (list.length < 3) {
              list.add(group == 'scale' ? 1.0 : 0.0);
            }
            list[axis] = (original as num).toDouble();
            setList(a, list);
          },
        );

      case SequencerTrackKind.visibility:
        return _ChannelSnapshot._(
          actorId: actor.id,
          id: '${actor.id}|visible',
          read: (a) => a.isVisible,
          write: (a, v) => a.isVisible = v >= 0.5,
          restore: (a, original) => a.isVisible = original as bool,
        );

      case SequencerTrackKind.property:
        final prop = sample.propertyName ?? channelName;
        final lower = prop.toLowerCase();
        if (lower == 'lightintensity' || lower == 'intensity') {
          return _ChannelSnapshot._(
            actorId: actor.id,
            id: '${actor.id}|lightIntensity',
            read: (a) => (
              a.lightIntensity,
              {for (final c in a.components) if (c.properties.containsKey('lightIntensity')) c.id: c.properties['lightIntensity']},
            ),
            write: (a, v) {
              a.lightIntensity = v;
              for (final c in a.components) {
                if (c.properties.containsKey('lightIntensity')) c.properties['lightIntensity'] = v;
              }
            },
            restore: (a, original) {
              final (double intensity, Map<String, dynamic> comps) = original as (double, Map<String, dynamic>);
              a.lightIntensity = intensity;
              for (final c in a.components) {
                if (comps.containsKey(c.id)) c.properties['lightIntensity'] = comps[c.id];
              }
            },
          );
        }
        // Any numeric component property with that name.
        for (final c in actor.components) {
          if (c.properties[prop] is num) {
            final compId = c.id;
            return _ChannelSnapshot._(
              actorId: actor.id,
              id: '${actor.id}|comp:$compId:$prop',
              read: (a) => a.components.firstWhere((x) => x.id == compId).properties[prop],
              write: (a, v) => a.components.firstWhere((x) => x.id == compId).properties[prop] = v,
              restore: (a, original) => a.components.firstWhere((x) => x.id == compId).properties[prop] = original,
            );
          }
        }
        return null;
    }
  }
}
