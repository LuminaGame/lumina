part of '../animation_dope_sheet_widget.dart';

/// State shared by the dope sheet's header and track mixins.
abstract class _AnimationDopeSheetWidgetStateBase extends State<AnimationDopeSheetWidget> {
  bool _expandBoneTracks = true;
  final Set<String> _expandedBones = <String>{};
  final ScrollController _horizontalTimelineScroll = ScrollController();
  final ScrollController _verticalTracksScroll = ScrollController();
  final ScrollController _verticalHeadersScroll = ScrollController();
  bool _isSyncingScroll = false;

  /// Pixels the selected bone keys are being dragged by, or null.
  double? _boneKeyDragDx;

  /// The left edge and width of the bar over `[startTime, endTime]`: at least
  /// [minWidth] wide (or the whole track when it is narrower) and inside the
  /// track, also for a range that starts on the clip's last frame.
  static ({double left, double width}) _rangeBar(
    double startTime,
    double endTime,
    double duration,
    double trackWidth,
    double minWidth,
  ) {
    final width = math.min(minWidth, trackWidth);
    final left = (startTime / duration * trackWidth).clamp(0.0, trackWidth - width);
    final right = (endTime / duration * trackWidth).clamp(left + width, trackWidth);
    return (left: left, width: right - left);
  }

  /// A mark [markWidth] wide at [x], kept on a track of [trackWidth] (at its
  /// left edge when the track is narrower than the mark).
  static double _markLeft(double x, double trackWidth, double markWidth) =>
      x.clamp(0.0, math.max(0.0, trackWidth - markWidth));

  // --- Implemented by the domain mixins or [_AnimationDopeSheetWidgetState]. ---

  Widget _buildIndividualBoneTrackStrip(
    AnimBoneTrackInfo bone,
    double trackWidth,
    double duration,
    AnimationEditorViewModel vm,
  );

  Widget _buildSubTrackStrip(
    AnimBoneTrackInfo bone,
    AnimBoneSubTrack subTrack,
    double trackWidth,
    double duration,
    AnimationEditorViewModel vm,
  );

  Widget _buildNotifiesTrackRow(double trackWidth, double duration, AnimationEditorViewModel vm);

  Widget _buildCurvesTrackRow(double trackWidth, double duration, AnimationEditorViewModel vm);

  Widget _buildIndividualCurveRow(AnimCurveData curve, double trackWidth, double duration, AnimationEditorViewModel vm);
}
