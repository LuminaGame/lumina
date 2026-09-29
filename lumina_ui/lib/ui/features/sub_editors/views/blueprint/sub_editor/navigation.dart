part of '../blueprint_sub_editor.dart';

/// Tab and graph navigation, selection collapse, debugger sync, compile,
/// diagnostic jumps and the close/save prompt.
mixin _BlueprintSubEditorNavigation on _BlueprintSubEditorStateBase {

  /// Shows a left-panel tab (0 Components, 1 My Blueprint).
  void showLeftTab(int index) => setState(() => _activeLeftTab = index);

  /// Shows [ref]'s graph (or Timeline) tab in the centre.
  @override
  void showGraph(BlueprintGraphRef ref) {
    _viewModel.showGraph(ref);
    setState(() => _showViewport = false);
  }

  /// The centre tab shown: the active graph ref, or null for the 3D Viewport.
  BlueprintGraphRef? get activeCenterGraph => _showViewport ? null : _viewModel.activeGraph;

  /// The graph editor of the centre tab (the event graph's when a Timeline
  /// or the viewport is shown).
  BlueprintGraphEditor get activeGraphEditor => _viewModel.activeGraphEditor;

  /// Collapses the active graph's selection (Collapse Nodes / to
  /// Function / to Macro); a named collapse asks for the name first.
  @override
  void collapseSelection({required bool toMacro, required bool named}) {
    void run(String? name) {
      final call = _viewModel.collapseSelection(toMacro: toMacro, name: name);
      if (call == null && _viewModel.collapseRefusal != null && mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(title: const Text('Cannot collapse'), content: Text(_viewModel.collapseRefusal!)),
          ),
        );
      }
    }

    if (!named) return run(null);
    final controller = TextEditingController(text: toMacro ? 'NewMacro' : 'NewFunction');
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text(toMacro ? 'Collapse to Macro' : 'Collapse to Function'),
        content: SizedBox(
          width: 280,
          child: TextField(
            key: const ValueKey('collapse_name_field'),
            controller: controller,
            autofocus: true,
            onSubmitted: (v) {
              closeOverlay(dialogContext);
              run(v);
            },
          ),
        ),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          PrimaryButton(
            key: const ValueKey('collapse_name_ok'),
            onPressed: () {
              closeOverlay(dialogContext);
              run(controller.text);
            },
            child: const Text('Collapse'),
          ),
        ],
      ),
    );
  }

  /// This Blueprint's project-relative path (how Play and the debugger name
  /// classes).
  String? get _relativePath {
    final dir = _viewModel.projectDir;
    final abs = File(_viewModel.assetPath).absolute.path;
    return dir != null && abs.startsWith('$dir/') ? abs.substring(dir.length + 1) : null;
  }

  /// Opens the node Play's compile-errors dialog asked for.
  void _takeNavigation() {
    final rel = _relativePath;
    if (rel == null) return;
    final nodeId = BlueprintNavigation.instance.take(rel);
    if (nodeId == null) return;
    _focusNodeInItsGraph(nodeId);
  }

  /// Shows the graph that holds [nodeId] and frames the node.
  void _focusNodeInItsGraph(String nodeId) {
    final found = _viewModel.findNode(nodeId);
    if (found == null) return;
    showGraph(found.graph);
    final editor = _viewModel.graphEditor(found.graph);
    editor.select(nodeId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) editor.focusNode(nodeId);
    });
  }

  /// During Play, lights the graph from the running instance of this class.
  void _syncDebugger() {
    final rel = _relativePath;
    _viewModel.eventGraph.debug = rel == null ? null : BlueprintPieDebugger.instance.recorderFor(rel);
  }

  @override
  Future<void> _compile() async {
    if (_compiling) return;
    setState(() => _compiling = true);
    try {
      await _viewModel.compile();
    } finally {
      if (mounted) setState(() => _compiling = false);
    }
  }

  @override
  void _selectDiagnostic(LuminaBlueprintDiagnostic d) {
    final id = d.nodeId;
    if (id == null || _viewModel.findNode(id) == null) return;
    _viewModel.selectComponent(null);
    _viewModel.selectVariable(null);
    _focusNodeInItsGraph(id);
  }

  @override
  Future<void> _handleClose() async {
    if (_viewModel.isDirty) {
      showOverlay(
        context,
        const DialogConfiguration(),
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text('Save changes to "${widget.assetName}" before closing?'),
          actions: [
            GhostButton(
              child: const Text('Cancel'),
              onPressed: () => closeOverlay(dialogContext),
            ),
            DestructiveButton(
              child: const Text('Discard'),
              onPressed: () {
                closeOverlay(dialogContext);
                widget.onClose?.call();
              },
            ),
            PrimaryButton(
              child: const Text('Save'),
              onPressed: () async {
                await _viewModel.save();
                if (dialogContext.mounted) {
                  closeOverlay(dialogContext);
                }
                widget.onClose?.call();
              },
            ),
          ],
        ),
      );
    } else {
      widget.onClose?.call();
    }
  }
}
