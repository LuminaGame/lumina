part of '../blueprint_sub_editor.dart';

/// Editor chrome: toolbar, bottom panel, center tabs, right panel, left
/// tab buttons, My Blueprint view and the construction script canvas.
mixin _BlueprintSubEditorLayout on _BlueprintSubEditorStateBase {

  Widget _toolbar(bool isDirty) {
    final tx = _viewModel.transactions;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          OutlineBadge(
            key: const ValueKey('bp_mode_badge'),
            child: Text(_isLevel ? 'LEVEL BLUEPRINT · ${_viewModel.displayName}' : 'BLUEPRINT ACTOR',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_isLevel ? '${_viewModel.displayName} (Level Blueprint)' : widget.assetName}${isDirty ? ' *' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('Parent: ${_viewModel.document.parentClass}',
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(width: 12),
          BlueprintCompileBadge(status: _viewModel.compileStatus),
          const Spacer(),
          GhostButton(
            key: const ValueKey('bp_undo'),
            size: ButtonSize.small,
            onPressed: tx.canUndo ? _viewModel.undo : null,
            child: const Icon(LucideIcons.undo2, size: 13),
          ),
          GhostButton(
            key: const ValueKey('bp_redo'),
            size: ButtonSize.small,
            onPressed: tx.canRedo ? _viewModel.redo : null,
            child: const Icon(LucideIcons.redo2, size: 13),
          ),
          const SizedBox(width: 6),
          OutlineButton(
            key: const ValueKey('bp_compile'),
            size: ButtonSize.small,
            onPressed: _compiling ? null : _compile,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.hammer, size: 12, color: _compiling ? EditorColors.mutedForeground : EditorColors.logSuccess),
                const SizedBox(width: 4),
                Text(_compiling ? 'Compiling…' : 'Compile', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('bp_save'),
            size: ButtonSize.small,
            onPressed: () => _viewModel.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GhostButton(
            size: ButtonSize.small,
            onPressed: _handleClose,
            child: const Icon(LucideIcons.x, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: EditorColors.background,
            padding: const EdgeInsets.all(8),
            child: BlueprintCompilerResults(
              status: _viewModel.compileStatus,
              diagnostics: _viewModel.diagnostics,
              nodeTitle: _viewModel.diagnosticNodeTitle,
              onSelect: _selectDiagnostic,
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Container(
            color: EditorColors.background,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.code, size: 12, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Generated Dart (${_isLevel || _isWidget ? _viewModel.generatedFileName : '${widget.assetName}.dart'})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        _viewModel.generatedDartCode,
                        style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: Colors.cyan),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The centre: the 3D Viewport, a Timeline tab, the construction script
  /// placeholder, or the active graph's canvas.
  Widget _buildCenter() {
    if (_showViewport) return _buildPreviewViewport();
    final ref = _viewModel.activeGraph;
    if (ref.isTimeline) return BlueprintTimelineEditor(key: ValueKey('timeline_tab_${ref.name}'), viewModel: _viewModel, nodeId: ref.name!);
    if (ref.kind == BlueprintGraphKind.constructionScript) return _buildConstructionScriptCanvas();
    final editor = _viewModel.graphEditor(ref);
    return BlueprintGraphCanvas(
      key: ValueKey(ref.kind == BlueprintGraphKind.eventGraph ? 'blueprint_event_graph_canvas' : 'blueprint_graph_canvas_${ref.key}'),
      editor: editor,
      graphLabel: ref.label,
      actions: BlueprintGraphCanvasActions(
        onCollapse: ({required toMacro, required named}) => collapseSelection(toMacro: toMacro, named: named),
        onExpand: (id) => _viewModel.expandNode(id),
        onOpenTimeline: (id) => showGraph(BlueprintGraphRef.timeline(id)),
        onOpenGraph: (name, {required isMacro}) => showGraph(isMacro ? BlueprintGraphRef.macro(name) : BlueprintGraphRef.function(name)),
      ),
    );
  }

  Widget _buildRightPanel() {
    final ref = _viewModel.activeGraph;
    if (!_showViewport && ref.hasGraph) {
      final editor = _viewModel.graphEditor(ref);
      final selectedNodes = editor.selectedNodeIds;
      if (selectedNodes.length == 1) {
        final node = editor.node(selectedNodes.first);
        if (node != null) return _buildNodeDetails(node, editor);
      }
    }
    if (!_showViewport && ref.isTimeline) {
      final node = _viewModel.timelineNode(ref.name!);
      if (node != null) return _buildNodeDetails(node, _viewModel.timelineEditor(ref.name!)!);
    }
    final function = _viewModel.selectedFunction == null ? null : _viewModel.document.function(_viewModel.selectedFunction!);
    if (function != null) return _buildFunctionDetails(function);
    final macro = _viewModel.selectedMacro == null ? null : _viewModel.document.macro(_viewModel.selectedMacro!);
    if (macro != null) return _buildMacroDetails(macro);
    final dispatcher = _viewModel.selectedDispatcher == null ? null : _viewModel.document.dispatcher(_viewModel.selectedDispatcher!);
    if (dispatcher != null) return _buildDispatcherDetails(dispatcher);
    final variable = _viewModel.selectedVariable == null ? null : _viewModel.document.variable(_viewModel.selectedVariable!);
    if (variable != null) return _buildVariableDetails(variable);
    if (_isLevel) return _buildLevelDetails();
    if (_isWidget) return _buildWidgetDetails();
    return _buildDetailsInspector();
  }

  Widget _buildLeftTabBtn(int index, String label) {
    final active = _activeLeftTab == index;
    return Expanded(
      child: Clickable(
        onPressed: () => setState(() => _activeLeftTab = index),
        child: Container(
          color: active ? EditorColors.cardHeader : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? EditorColors.primary : EditorColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewportTabBtn() => _centerTab(LucideIcons.box, '3D Viewport', _showViewport, () => setState(() => _showViewport = true));

  Widget _buildGraphTabBtn(BlueprintGraphRef ref, IconData icon, {String? label}) =>
      _centerTab(icon, label ?? ref.label, !_showViewport && _viewModel.activeGraph == ref, () => showGraph(ref), key: ValueKey('graph_tab_${ref.key}'));

  Widget _centerTab(IconData icon, String label, bool active, VoidCallback onTap, {Key? key}) {
    return Clickable(
      key: key,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        margin: const EdgeInsets.only(right: 4),
        alignment: Alignment.center,
        // Both the graph canvases and the preview sit on the graph grey.
        decoration: EditorTabStyle.decoration(active: active, content: EditorColors.graphCanvas),
        child: Row(
          children: [
            Icon(icon, size: 12, color: active ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? EditorColors.primary : EditorColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBlueprintView() {
    final vm = _viewModel;
    final active = vm.activeGraph;
    final scopedFunction = active.isFunction ? vm.document.function(active.name) : null;
    return BlueprintMyBlueprintPanel(
      key: const ValueKey('bp_my_blueprint'),
      variables: vm.document.variables,
      context: vm.typeContext,
      selected: vm.selectedVariable,
      onSelect: vm.selectVariable,
      onAdd: () => vm.addVariable('NewVar', 'Float'),
      onRename: vm.renameVariable,
      onSetType: vm.setVariableType,
      onDelete: vm.deleteVariable,
      usageCount: (name) => vm.nodesUsingVariable(name).length,
      sections: BlueprintMyBlueprintSections(
        graphs: vm.graphs,
        activeGraph: _showViewport ? BlueprintGraphRef.constructionScript : active,
        onOpenGraph: showGraph,
        functions: [for (final f in vm.document.functions) f.name],
        macros: [for (final m in vm.document.macros) m.name],
        dispatchers: [for (final d in vm.document.dispatchers) d.name],
        selectedFunction: vm.selectedFunction,
        selectedMacro: vm.selectedMacro,
        selectedDispatcher: vm.selectedDispatcher,
        functionActions: (
          onAdd: () {
            vm.addFunction();
            setState(() => _showViewport = false);
          },
          onSelect: (name) {
            vm.selectFunction(name);
            showGraph(BlueprintGraphRef.function(name));
          },
          onRename: vm.renameFunction,
          onDelete: vm.deleteFunction,
          usageCount: (name) => vm.nodesCallingFunction(name).length,
        ),
        macroActions: (
          onAdd: () {
            vm.addMacro();
            setState(() => _showViewport = false);
          },
          onSelect: (name) {
            vm.selectMacro(name);
            showGraph(BlueprintGraphRef.macro(name));
          },
          onRename: vm.renameMacro,
          onDelete: vm.deleteMacro,
          usageCount: (name) => vm.nodesCallingMacro(name).length,
        ),
        dispatcherActions: (
          onAdd: vm.addDispatcher,
          onSelect: vm.selectDispatcher,
          onRename: vm.renameDispatcher,
          onDelete: vm.deleteDispatcher,
          usageCount: (name) => vm.nodesUsingDispatcher(name).length,
        ),
        localsOf: scopedFunction?.name,
        localVariables: scopedFunction?.localVariables ?? const [],
        onAddLocal: scopedFunction == null ? null : () => vm.addLocalVariable(scopedFunction.name),
        onRenameLocal: scopedFunction == null ? null : (o, n) => vm.renameLocalVariable(scopedFunction.name, o, n),
        onSetLocalType: scopedFunction == null ? null : (n, t) => vm.setLocalVariableType(scopedFunction.name, n, t),
        onDeleteLocal: scopedFunction == null ? null : (n) => vm.deleteLocalVariable(scopedFunction.name, n),
      ),
    );
  }

  Widget _buildConstructionScriptCanvas() {
    return Container(
      color: EditorColors.card,
      child: const Center(
        child: Text('Construction Script Graph (Ready)', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
      ),
    );
  }
}
