part of '../animation_sub_editor.dart';

/// State shared by the Animation sub-editor's panel mixins.
abstract class _AnimationSubEditorStateBase extends State<AnimationSubEditor> with SingleTickerProviderStateMixin {
  late final AnimationEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  final Set<int> _expandedNodeIndices = {};
  final FocusNode _focusNode = FocusNode();
  int _activeLeftTab = 0; // 0 = Properties, 1 = Bone Tracks, 2 = Notifies
  int _activeRightTab = 0; // 0 = Curves, 1 = BlendSpace

  /// The viewport's bone gizmo (authored sequences): rotate by default.
  late final SubEditorTransformGizmo _gizmo = SubEditorTransformGizmo(
    mode: GizmoMode.rotate,
    space: GizmoSpace.local,
    onDragBegin: (bone) => _viewModel.beginBonePose(bone),
    onDragUpdate: (_, delta) => _viewModel.previewGizmoDelta(delta),
    onDragEnd: (_) => _viewModel.endBonePose(),
    onDragCancel: (_) => _viewModel.cancelBonePose(),
    pick: (ray) => _viewModel.pickBone(ray.origin, ray.direction),
    onPick: (bone) {
      if (bone != null) _viewModel.selectBone(bone);
    },
  );

  // --- Implemented by the domain mixins or [_AnimationSubEditorState]. ---

  Widget _buildCurvesPanel();

  Widget _buildBlendSpacePanel();

  Widget _buildAuthoredKeyPanel(SelectedKeyframeDetails details);

  List<Widget> _authoringToolbarItems();

  Widget _buildTransformSectionHeader(String title, IconData icon);
}
