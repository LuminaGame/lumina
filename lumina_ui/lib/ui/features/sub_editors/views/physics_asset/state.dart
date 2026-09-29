part of '../physics_asset_sub_editor.dart';

/// State shared by the Physics Asset editor's panel mixins.
abstract class _PhysicsAssetSubEditorStateBase extends State<PhysicsAssetSubEditor> {
  late final PhysicsAssetEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  final PhysicsPreviewScene _previewScene = PhysicsPreviewScene();
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _filterController = TextEditingController();
  final Set<String> _collapsedBones = {};
  String? _pendingMeshBinding;

  /// True while [_controller] shows a new value in a field. A text field
  /// reports every controller change through `onChanged`, synchronously, and
  /// at that moment the field still carries the closure of the body or
  /// constraint it was built for, so that report must not be taken as an
  /// edit.
  bool _syncingField = false;

  // ----------------------------------------------------------- workspace

  /// Where the preview camera starts, per bound mesh: framing the mesh and the
  /// bodies in cm, the units they are drawn in.
  ({Vector3 target, double distance})? _framing;
  String? _framedMeshPath;

  // --- Implemented by the domain mixins or [_PhysicsAssetSubEditorState]. ---

  void _syncOverlay();

  ValueChanged<String> _userEdit(ValueChanged<String> onChanged);

  TextEditingController _controller(String key, String text);

  Widget _buildTreePanel();

  Widget _buildValidationPanel();

  Widget _buildInspector();
}
