part of '../skeletal_mesh_sub_editor.dart';

/// State shared by the Skeletal Mesh sub-editor's panel mixins.
abstract class _SkeletalMeshSubEditorStateBase extends State<SkeletalMeshSubEditor> {
  late final SkeletalMeshEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  final Set<int> _expandedNodeIndices = {};
  int _activeLeftTab = 0; // the lower left island: 2 = RigLogic (DNA), anything else = Morph Targets
  String _dnaControlSearchFilter = '';

  // --- Implemented by the domain mixins or [_SkeletalMeshSubEditorState]. ---

  Widget _buildBoneTreePanel();

  Widget _buildSocketRow(SkeletalMeshSocket socket, int depth);

  void _confirmRemoveSocket(String socketName);
}
