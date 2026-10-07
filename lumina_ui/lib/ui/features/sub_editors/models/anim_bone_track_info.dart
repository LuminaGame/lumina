import 'package:flutter/widgets.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/selected_keyframe_details.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Metadata and active animation range for a bone track.
class AnimBoneTrackInfo {
  final String boneName;
  final int nodeIndex;
  final List<double> keyframeTimes;
  final double startTime;
  final double endTime;
  final bool hasVariation;
  final List<GlbAnimationChannel> channels;

  const AnimBoneTrackInfo({
    required this.boneName,
    required this.nodeIndex,
    required this.keyframeTimes,
    required this.startTime,
    required this.endTime,
    required this.hasVariation,
    this.channels = const [],
  });

  double get duration => (endTime - startTime).clamp(0.0, double.infinity);

  /// Analyzes keyframe channels and determines whether values vary over time,
  /// as well as the active start and end timestamps of the movement range.
  static AnimBoneTrackInfo compute(
    String boneName,
    int nodeIndex,
    List<GlbAnimationChannel> channels,
    double clipDuration,
  ) {
    final Set<double> timesSet = {};
    double earliestChange = double.infinity;
    double latestChange = -double.infinity;
    bool anyChangeDetected = false;

    for (final ch in channels) {
      final times = ch.keyframeTimes;
      final vals = ch.values;
      if (times.length < 2 || vals.isEmpty) continue;

      final numComp = switch (ch.path) {
        'translation' => 3,
        'rotation' => 4,
        'scale' => 3,
        _ => 1,
      };

      if (vals.length < times.length * numComp) continue;

      final baseVals = List<double>.generate(numComp, (i) => vals[i]);

      for (int f = 1; f < times.length; f++) {
        final t = times[f];
        bool frameChanged = false;
        for (int c = 0; c < numComp; c++) {
          final val = vals[f * numComp + c];
          if ((val - baseVals[c]).abs() > 1e-4) {
            frameChanged = true;
            break;
          }
        }

        if (frameChanged) {
          anyChangeDetected = true;
          timesSet.add(t);
          if (t < earliestChange) earliestChange = t;
          if (t > latestChange) latestChange = t;
        }
      }
    }

    final sortedTimes = timesSet.toList()..sort();
    final effectiveStart = anyChangeDetected ? earliestChange : 0.0;
    final effectiveEnd = anyChangeDetected ? latestChange : (sortedTimes.isNotEmpty ? sortedTimes.last : clipDuration);

    return AnimBoneTrackInfo(
      boneName: boneName,
      nodeIndex: nodeIndex,
      keyframeTimes: sortedTimes,
      startTime: effectiveStart.clamp(0.0, clipDuration),
      endTime: effectiveEnd.clamp(effectiveStart, clipDuration),
      hasVariation: anyChangeDetected,
      channels: channels,
    );
  }

  /// Generates the individual component sub-tracks (Location X/Y/Z, Rotation P/Y/R, Scale X/Y/Z)
  /// with per-component active variation detection and filtered keyframe lists.
  List<AnimBoneSubTrack> get subTracks {
    final List<AnimBoneSubTrack> list = [];

    GlbAnimationChannel? locCh;
    GlbAnimationChannel? rotCh;
    GlbAnimationChannel? sclCh;

    for (final ch in channels) {
      if (ch.path == 'translation') locCh = ch;
      if (ch.path == 'rotation') rotCh = ch;
      if (ch.path == 'scale') sclCh = ch;
    }

    // Location X, Y, Z
    if (locCh != null && locCh.keyframeTimes.isNotEmpty) {
      final xVar = _analyzeComponent(locCh.keyframeTimes, locCh.values, 0, 3);
      final yVar = _analyzeComponent(locCh.keyframeTimes, locCh.values, 1, 3);
      final zVar = _analyzeComponent(locCh.keyframeTimes, locCh.values, 2, 3);

      list.add(AnimBoneSubTrack(
        id: '${boneName}_loc_x',
        label: 'Location.X',
        group: 'Location',
        color: EditorColors.destructive,
        keyframeTimes: xVar.keyframeTimes,
        startTime: xVar.startTime,
        endTime: xVar.endTime,
        hasVariation: xVar.hasVariation,
        staticValue: xVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_loc_y',
        label: 'Location.Y',
        group: 'Location',
        color: EditorColors.chart3,
        keyframeTimes: yVar.keyframeTimes,
        startTime: yVar.startTime,
        endTime: yVar.endTime,
        hasVariation: yVar.hasVariation,
        staticValue: yVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_loc_z',
        label: 'Location.Z',
        group: 'Location',
        color: EditorColors.accent,
        keyframeTimes: zVar.keyframeTimes,
        startTime: zVar.startTime,
        endTime: zVar.endTime,
        hasVariation: zVar.hasVariation,
        staticValue: zVar.staticValue,
      ));
    }

    // Rotation Pitch, Yaw, Roll (P, Y, R)
    if (rotCh != null && rotCh.keyframeTimes.isNotEmpty) {
      final pVar = _analyzeEulerComponent(rotCh.keyframeTimes, rotCh.values, 0);
      final yVar = _analyzeEulerComponent(rotCh.keyframeTimes, rotCh.values, 1);
      final rVar = _analyzeEulerComponent(rotCh.keyframeTimes, rotCh.values, 2);

      list.add(AnimBoneSubTrack(
        id: '${boneName}_rot_p',
        label: 'Rotation.Pitch (P)',
        group: 'Rotation',
        color: EditorColors.warning,
        keyframeTimes: pVar.keyframeTimes,
        startTime: pVar.startTime,
        endTime: pVar.endTime,
        hasVariation: pVar.hasVariation,
        staticValue: pVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_rot_y',
        label: 'Rotation.Yaw (Y)',
        group: 'Rotation',
        color: EditorColors.chart3,
        keyframeTimes: yVar.keyframeTimes,
        startTime: yVar.startTime,
        endTime: yVar.endTime,
        hasVariation: yVar.hasVariation,
        staticValue: yVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_rot_r',
        label: 'Rotation.Roll (R)',
        group: 'Rotation',
        color: EditorColors.chart4,
        keyframeTimes: rVar.keyframeTimes,
        startTime: rVar.startTime,
        endTime: rVar.endTime,
        hasVariation: rVar.hasVariation,
        staticValue: rVar.staticValue,
      ));
    }

    // Scale X, Y, Z
    if (sclCh != null && sclCh.keyframeTimes.isNotEmpty) {
      final xVar = _analyzeComponent(sclCh.keyframeTimes, sclCh.values, 0, 3);
      final yVar = _analyzeComponent(sclCh.keyframeTimes, sclCh.values, 1, 3);
      final zVar = _analyzeComponent(sclCh.keyframeTimes, sclCh.values, 2, 3);

      list.add(AnimBoneSubTrack(
        id: '${boneName}_scl_x',
        label: 'Scale.X',
        group: 'Scale',
        color: EditorColors.destructive,
        keyframeTimes: xVar.keyframeTimes,
        startTime: xVar.startTime,
        endTime: xVar.endTime,
        hasVariation: xVar.hasVariation,
        staticValue: xVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_scl_y',
        label: 'Scale.Y',
        group: 'Scale',
        color: EditorColors.chart3,
        keyframeTimes: yVar.keyframeTimes,
        startTime: yVar.startTime,
        endTime: yVar.endTime,
        hasVariation: yVar.hasVariation,
        staticValue: yVar.staticValue,
      ));
      list.add(AnimBoneSubTrack(
        id: '${boneName}_scl_z',
        label: 'Scale.Z',
        group: 'Scale',
        color: EditorColors.accent,
        keyframeTimes: zVar.keyframeTimes,
        startTime: zVar.startTime,
        endTime: zVar.endTime,
        hasVariation: zVar.hasVariation,
        staticValue: zVar.staticValue,
      ));
    }

    return list;
  }

  static _ComponentVarInfo _analyzeComponent(
    List<double> times,
    List<double> values,
    int componentIndex,
    int numComponents,
  ) {
    if (times.isEmpty || values.isEmpty || values.length < numComponents) {
      return const _ComponentVarInfo(hasVariation: false, startTime: 0.0, endTime: 0.0, keyframeTimes: [], staticValue: 0.0);
    }

    final baseVal = values[componentIndex];
    double earliest = double.infinity;
    double latest = -double.infinity;
    final List<double> varyingTimes = [];
    bool changed = false;

    for (int f = 1; f < times.length; f++) {
      final idx = f * numComponents + componentIndex;
      if (idx >= values.length) break;
      final val = values[idx];
      if ((val - baseVal).abs() > 1e-4) {
        changed = true;
        varyingTimes.add(times[f]);
        if (times[f] < earliest) earliest = times[f];
        if (times[f] > latest) latest = times[f];
      }
    }

    if (!changed) {
      return _ComponentVarInfo(
        hasVariation: false,
        startTime: 0.0,
        endTime: 0.0,
        keyframeTimes: const [],
        staticValue: baseVal,
      );
    }

    return _ComponentVarInfo(
      hasVariation: true,
      startTime: earliest.clamp(0.0, double.infinity),
      endTime: latest.clamp(earliest, double.infinity),
      keyframeTimes: varyingTimes,
      staticValue: baseVal,
    );
  }

  static _ComponentVarInfo _analyzeEulerComponent(
    List<double> times,
    List<double> quatValues,
    int eulerIndex,
  ) {
    if (times.isEmpty || quatValues.length < 4) {
      return const _ComponentVarInfo(hasVariation: false, startTime: 0.0, endTime: 0.0, keyframeTimes: [], staticValue: 0.0);
    }

    final baseEuler = SelectedKeyframeDetails.quaternionToEuler(
      quatValues[0],
      quatValues[1],
      quatValues[2],
      quatValues[3],
    );
    final baseVal = baseEuler[eulerIndex];

    double earliest = double.infinity;
    double latest = -double.infinity;
    final List<double> varyingTimes = [];
    bool changed = false;

    for (int f = 1; f < times.length; f++) {
      final idx = f * 4;
      if (idx + 3 >= quatValues.length) break;
      final euler = SelectedKeyframeDetails.quaternionToEuler(
        quatValues[idx],
        quatValues[idx + 1],
        quatValues[idx + 2],
        quatValues[idx + 3],
      );
      final val = euler[eulerIndex];
      if ((val - baseVal).abs() > 1e-2) {
        changed = true;
        varyingTimes.add(times[f]);
        if (times[f] < earliest) earliest = times[f];
        if (times[f] > latest) latest = times[f];
      }
    }

    if (!changed) {
      return _ComponentVarInfo(
        hasVariation: false,
        startTime: 0.0,
        endTime: 0.0,
        keyframeTimes: const [],
        staticValue: baseVal,
      );
    }

    return _ComponentVarInfo(
      hasVariation: true,
      startTime: earliest.clamp(0.0, double.infinity),
      endTime: latest.clamp(earliest, double.infinity),
      keyframeTimes: varyingTimes,
      staticValue: baseVal,
    );
  }
}

class _ComponentVarInfo {
  final bool hasVariation;
  final double startTime;
  final double endTime;
  final List<double> keyframeTimes;
  final double staticValue;

  const _ComponentVarInfo({
    required this.hasVariation,
    required this.startTime,
    required this.endTime,
    required this.keyframeTimes,
    required this.staticValue,
  });
}

/// An individual component sub-track (e.g. Location.X, Rotation.Pitch, Scale.Z)
class AnimBoneSubTrack {
  final String id;
  final String label;
  final String group;
  final Color color;
  final List<double> keyframeTimes;
  final double startTime;
  final double endTime;
  final bool hasVariation;
  final double staticValue;

  const AnimBoneSubTrack({
    required this.id,
    required this.label,
    required this.group,
    required this.color,
    required this.keyframeTimes,
    required this.startTime,
    required this.endTime,
    this.hasVariation = true,
    this.staticValue = 0.0,
  });
}
