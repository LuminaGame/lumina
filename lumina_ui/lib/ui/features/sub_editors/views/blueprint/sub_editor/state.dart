part of '../blueprint_sub_editor.dart';

/// State shared by the Blueprint editor's domain mixins: every instance
/// field (in the original order) and the members the mixins call on one another.
abstract class _BlueprintSubEditorStateBase extends State<BlueprintSubEditor> {
  late final BlueprintEditorViewModel _viewModel;
  late final bool _ownsViewModel;

  /// True while the 3D Viewport tab is shown; otherwise the view model's
  /// active graph (event graph, construction script, a function, a macro or
  /// a Timeline tab) is the centre tab.
  bool _showViewport = false;
  int _activeLeftTab = 0; // 0: Components, 1: My Blueprint
  bool _compiling = false;

  /// The 3D Viewport's component transform gizmo.
  late final SubEditorTransformGizmo _gizmo = SubEditorTransformGizmo(
    mode: widget.gizmoDefaults?.mode ?? GizmoMode.translate,
    space: widget.gizmoDefaults?.space ?? GizmoSpace.world,
    snap: widget.gizmoDefaults?.snap ?? TransformGizmoSnap.none,
    onDragBegin: _onGizmoDragBegin,
    onDragUpdate: _onGizmoDragUpdate,
    onDragEnd: (_) => _viewModel.endComponentTransformDrag(),
    onDragCancel: (_) => _viewModel.cancelComponentTransformDrag(),
    pick: (ray) => _viewModel.preview.pick(ray),
    onPick: (id) {
      if (id != null) _viewModel.selectComponent(id);
    },
  );

  /// The relative transform (authoring values) and the frames of the
  /// component a gizmo drag started on.
  ({List<double> location, List<double> rotation, List<double> scale, Quaternion parentRotation, Quaternion worldRotation})?
      _gizmoDragStart;

  // --- Implemented by the domain mixins or [BlueprintSubEditorState]. ---

  BlueprintEditorViewModel get viewModel;

  bool get _isLevel;

  bool get _isWidget;

  SubEditorTransformGizmo get transformGizmo;

  void _onGizmoDragBegin(String id);

  void _onGizmoDragUpdate(String id, SubEditorGizmoDelta delta);

  void showGraph(BlueprintGraphRef ref);

  void collapseSelection({required bool toMacro, required bool named});

  Future<void> _compile();

  void _selectDiagnostic(LuminaBlueprintDiagnostic d);

  Future<void> _handleClose();

  Widget _buildPreviewViewport();

  Widget _buildLevelDetails();

  Widget _buildWidgetDetails();

  Widget _buildFunctionDetails(LuminaBlueprintFunctionGraph fn);

  Widget _buildMacroDetails(LuminaBlueprintMacroGraph macro);

  Widget _buildDispatcherDetails(LuminaBlueprintDispatcher d);

  Widget _detailsHeader(IconData icon, String title, String? subtitle);

  Widget _buildNodeDetails(LuminaBlueprintNode node, BlueprintGraphEditor editor);

  Widget _buildVariableDetails(LuminaBlueprintVariable v);

  Widget _buildDetailsInspector();
}
