part of '../animation_sub_editor.dart';

/// State shared by the Animation sub-editor's panel mixins.
abstract class _AnimationSubEditorStateBase extends State<AnimationSubEditor> with SingleTickerProviderStateMixin {
  late final AnimationEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  final Set<int> _expandedNodeIndices = {};
  final FocusNode _focusNode = FocusNode();
  int _activeLeftTab = 0; // 0 = Properties, 1 = Bone Tracks, 2 = Notifies
  int _activeRightTab = 0; // 0 = Curves, 1 = BlendSpace

  // --- Implemented by the domain mixins or [_AnimationSubEditorState]. ---

  Widget _buildCurvesPanel();

  Widget _buildBlendSpacePanel();
}
