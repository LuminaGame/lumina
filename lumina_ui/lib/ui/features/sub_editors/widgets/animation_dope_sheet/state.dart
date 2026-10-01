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
