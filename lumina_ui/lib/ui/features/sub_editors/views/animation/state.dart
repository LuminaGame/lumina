part of '../animation_sub_editor.dart';

/// State shared by the Animation sub-editor's panel mixins.
abstract class _AnimationSubEditorStateBase extends State<AnimationSubEditor> with SingleTickerProviderStateMixin {
  late final AnimationEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  final Set<int> _expandedNodeIndices = {};
  final FocusNode _focusNode = FocusNode();
  int _activeLeftTab = 0; // 0 = Properties, 1 = Bone Tracks, 2 = Notifies
  int _activeRightTab = 0; // 0 = Key Details, 1 = Curves, 2 = BlendSpace, 3 = Pose (authored)
  double _bottomTimelineHeight = 260.0;

  /// Viewport clicks add root path points (the Pose tab's Draw Path).
  bool _drawingRootPath = false;

  /// The viewport's bone gizmo (authored sequences): rotate by default.
  late final SubEditorTransformGizmo _gizmo = SubEditorTransformGizmo(
    mode: GizmoMode.rotate,
    space: GizmoSpace.local,
    // A bone, or in IK mode a chain's target (`ik:<chain>`) or pole
    // (`pole:<chain>`).
    onDragBegin: (id) => _isIkHandle(id) ? _viewModel.beginIkDrag() : _viewModel.beginBonePose(id),
    onDragUpdate: (id, delta) => _isIkHandle(id) ? _viewModel.previewIkDelta(delta) : _viewModel.previewGizmoDelta(delta),
    onDragEnd: (id) => _isIkHandle(id) ? _viewModel.endIkDrag() : _viewModel.endBonePose(),
    onDragCancel: (id) => _isIkHandle(id) ? _viewModel.cancelIkDrag() : _viewModel.cancelBonePose(),
    pick: (ray) => _viewModel.pickBone(ray.origin, ray.direction),
    onPick: (bone) {
      if (bone == null) return;
      final chain = _viewModel.ikMode ? _viewModel.ikChainOfBone(bone) : null;
      chain != null ? _viewModel.selectIkChain(chain) : _viewModel.selectBone(bone);
    },
  );

  static bool _isIkHandle(String id) => id.startsWith('ik:') || id.startsWith('pole:');

  // --- Implemented by the domain mixins or [_AnimationSubEditorState]. ---

  Widget _buildPoseToolsPanel();

  List<SubEditorGhostSkeleton> _ghostSkeletons();

  List<SubEditorOverlayMarker> _ikMarkers();

  List<SubEditorOverlayPath> _rootPaths();

  /// IK mode on or off; on, the gizmo moves (translate) the chain's target.
  void _setIkMode(bool value);

  Widget _buildCurvesPanel();

  Widget _buildBlendSpacePanel();

  Widget _buildAuthoredKeyPanel(SelectedKeyframeDetails details);

  List<Widget> _authoringToolbarItems();

  Widget _buildTransformSectionHeader(String title, IconData icon);
}
