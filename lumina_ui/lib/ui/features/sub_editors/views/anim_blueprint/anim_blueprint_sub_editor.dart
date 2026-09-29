import 'package:flutter/services.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../../core/theme/editor_theme.dart';
import '../../../../core/property_editors/asset_picker_select.dart';
import '../../sub_editor_binding.dart';
import '../../view_models/anim_blueprint_editor_view_model.dart';
import '../blueprint/compile_results.dart';
import '../blueprint/graph_canvas.dart';
import '../blueprint/my_blueprint_panel.dart';
import '../blueprint/pin_literal_editor.dart';
import '../sub_editor_3d_viewport.dart';
import 'anim_graph_view.dart';
import 'anim_preview_editor.dart';
import 'state_machine_graph.dart';
import 'state_pose_editor.dart';
import '../../widgets/anim_blueprint_retarget_modal.dart';

/// The Animation Blueprint editor: preview viewport and My Blueprint on the left, the AnimGraph /
/// state machine / state pose / transition rule / EventGraph in the centre
/// with breadcrumbs, Details on the right, Compiler Results and the Anim
/// Preview Editor at the bottom.
class AnimBlueprintSubEditor extends StatefulWidget {
  final String assetName;
  final String assetPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final AnimBlueprintEditorViewModel? viewModel;
  final VoidCallback? onAssetsModified;

  /// False shows the preview's state as text instead of mounting the
  /// Filament viewport; the preview still runs, in a world without a
  /// renderer (widget tests, where a native viewport never settles).
  final bool showPreviewViewport;

  const AnimBlueprintSubEditor({
    super.key,
    required this.assetName,
    required this.assetPath,
    this.onClose,
    this.onBind,
    this.viewModel,
    this.onAssetsModified,
    this.showPreviewViewport = true,
  });

  @override
  State<AnimBlueprintSubEditor> createState() => AnimBlueprintSubEditorState();
}

class AnimBlueprintSubEditorState extends State<AnimBlueprintSubEditor> {
  late final AnimBlueprintEditorViewModel _vm;
  late final bool _ownsViewModel;
  bool _compiling = false;

  AnimBlueprintEditorViewModel get viewModel => _vm;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm = widget.viewModel ?? AnimBlueprintEditorViewModel(assetPath: widget.assetPath);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    if (_ownsViewModel) _vm.load();
    // The viewport hands its world over when Filament is up; until then (and
    // where it never is) the preview runs headless so the state machine and
    // clip choice still update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_vm.preview.isAttached) _vm.startHeadlessPreview();
    });
  }

  @override
  void dispose() {
    if (_ownsViewModel) _vm.dispose();
    super.dispose();
  }

  Future<void> _compile() async {
    if (_compiling) return;
    setState(() => _compiling = true);
    try {
      await _vm.compile();
    } finally {
      if (mounted) setState(() => _compiling = false);
    }
  }

  void _close() {
    if (!_vm.isDirty) {
      widget.onClose?.call();
      return;
    }
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text('Save changes to "${widget.assetName}" before closing?'),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          DestructiveButton(
            onPressed: () {
              closeOverlay(dialogContext);
              widget.onClose?.call();
            },
            child: const Text('Discard'),
          ),
          PrimaryButton(
            onPressed: () async {
              await _vm.save();
              if (dialogContext.mounted) closeOverlay(dialogContext);
              widget.onClose?.call();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openRetargetDialog(BuildContext context, {String? initialTargetMeshPath}) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AnimBlueprintRetargetModal(
        viewModel: _vm,
        initialTargetMeshPath: initialTargetMeshPath,
        onCompleted: widget.onAssetsModified,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _vm.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _vm.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _vm.redo,
        const SingleActivator(LogicalKeyboardKey.f7): _compile,
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_vm, _vm.transactions]),
        builder: (context, _) => Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _toolbar(),
              const Divider(height: 1),
              Expanded(
                child: ResizablePanel.horizontal(
                  children: [
                    ResizablePane(initialSize: 320, minSize: 240, child: _left()),
                    ResizablePane.flex(
                      child: Column(
                        children: [
                          _graphBar(),
                          const Divider(height: 1),
                          Expanded(child: _center()),
                          const Divider(height: 1),
                          SizedBox(height: 200, child: _bottom()),
                        ],
                      ),
                    ),
                    ResizablePane(initialSize: 280, minSize: 220, child: _details()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final tx = _vm.transactions;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(child: Text('ANIMATION BLUEPRINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${widget.assetName}${_vm.isDirty ? ' *' : ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          ),
          const SizedBox(width: 8),
          Text('Target: ${AnimStatePoseEditor.shortName(_vm.document.targetMesh)}',
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(width: 12),
          BlueprintCompileBadge(status: _vm.compileStatus),
          const Spacer(),
          GhostButton(
            key: const ValueKey('abp_retarget_button'),
            size: ButtonSize.small,
            onPressed: () => _openRetargetDialog(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.repeat, size: 12, color: Colors.cyan),
                SizedBox(width: 4),
                Text('Retarget Blueprint', style: TextStyle(fontSize: 10, color: Colors.cyan, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GhostButton(
            key: const ValueKey('abp_undo'),
            size: ButtonSize.small,
            onPressed: tx.canUndo ? _vm.undo : null,
            child: const Icon(LucideIcons.undo2, size: 13),
          ),
          GhostButton(
            key: const ValueKey('abp_redo'),
            size: ButtonSize.small,
            onPressed: tx.canRedo ? _vm.redo : null,
            child: const Icon(LucideIcons.redo2, size: 13),
          ),
          const SizedBox(width: 6),
          OutlineButton(
            key: const ValueKey('abp_compile'),
            size: ButtonSize.small,
            onPressed: _compiling ? null : _compile,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.hammer, size: 12, color: EditorColors.logSuccess),
              const SizedBox(width: 4),
              Text(_compiling ? 'Compiling…' : 'Compile', style: const TextStyle(fontSize: 10)),
            ]),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('abp_save'),
            size: ButtonSize.small,
            onPressed: () => _vm.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GhostButton(size: ButtonSize.small, onPressed: _close, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }

  Widget _left() {
    final m = _vm.machine;
    Widget link(String key, String label, IconData icon, AnimGraphLocation to, {int depth = 0}) {
      final active = _vm.location == to;
      return Clickable(
        key: ValueKey(key),
        onPressed: () => _vm.open(to),
        child: Container(
          padding: EdgeInsets.fromLTRB(6.0 + depth * 14, 3, 6, 3),
          color: active ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          child: Row(children: [
            Icon(icon, size: 11, color: active ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
          ]),
        ),
      );
    }

    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        children: [
          SizedBox(
            height: 300,
            child: widget.showPreviewViewport
                ? SubEditor3DViewport(
                    key: const ValueKey('abp_preview_viewport'),
                    title: 'Anim Preview',
                    showShapeSelector: false,
                    yUpCamera: true,
                    initialCameraDistance: 330,
                    initialCameraTarget: Vector3(0, 95, 0),
                    statsLabel: 'Preview: ${_vm.previewState ?? '—'} · ${_vm.previewClip ?? 'no clip'}',
                    onPreviewWorldReady: _vm.attachPreviewWorld,
                    onPreviewWorldDisposing: _vm.detachPreviewWorld,
                  )
                : Container(
                    key: const ValueKey('abp_preview_text'),
                    color: EditorColors.graphCanvas,
                    alignment: Alignment.center,
                    child: Text('Preview (no renderer): ${_vm.previewState ?? '—'} · ${_vm.previewClip ?? 'no clip'}',
                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlueprintMyBlueprintPanel(
              key: const ValueKey('abp_my_blueprint'),
              variables: _vm.document.variables,
              selected: _vm.selectedVariable,
              onSelect: _vm.selectVariable,
              onAdd: () => _vm.addVariable('NewVar', 'Float'),
              onRename: _vm.renameVariable,
              onSetType: _vm.setVariableType,
              onDelete: _vm.deleteVariable,
              usageCount: (n) => _vm.nodesUsingVariable(n).length,
              graphs: [
                const Text('GRAPHS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                const SizedBox(height: 4),
                link('graph_link_EventGraph', 'EventGraph', LucideIcons.gitFork, const AnimGraphLocation.eventGraph()),
                link('graph_link_AnimGraph', 'AnimGraph', LucideIcons.personStanding, const AnimGraphLocation.animGraph()),
                if (m != null) ...[
                  link('graph_link_machine_${m.name}', m.name, LucideIcons.workflow, AnimGraphLocation.stateMachine(m.name), depth: 1),
                  for (final s in m.states)
                    link('graph_link_state_${s.name}', s.name, LucideIcons.squareStack, AnimGraphLocation.state(m.name, s.name), depth: 2),
                  for (final t in m.transitions)
                    link('graph_link_rule_${t.id}', '${t.from} → ${t.to}', LucideIcons.arrowLeftRight,
                        AnimGraphLocation.transition(m.name, t.id),
                        depth: 2),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _graphBar() {
    final crumbs = _vm.breadcrumbs;
    Widget tab(String label, AnimGraphLocation to, IconData icon) {
      final active = to.view == AnimGraphView.eventGraph
          ? _vm.location.view == AnimGraphView.eventGraph
          : _vm.location.view != AnimGraphView.eventGraph;
      return Clickable(
        key: ValueKey('abp_tab_$label'),
        onPressed: () => _vm.open(to),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: active ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(children: [
            Icon(icon, size: 12, color: active ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          ]),
        ),
      );
    }

    return Container(
      height: 32,
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          tab('EventGraph', const AnimGraphLocation.eventGraph(), LucideIcons.gitFork),
          tab('AnimGraph', const AnimGraphLocation.animGraph(), LucideIcons.personStanding),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              key: const ValueKey('abp_breadcrumbs'),
              children: [
                for (var i = 0; i < crumbs.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('›', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                    ),
                  Clickable(
                    key: ValueKey('abp_crumb_$i'),
                    onPressed: () => _vm.open(crumbs[i].$2),
                    child: Text(crumbs[i].$1,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == crumbs.length - 1 ? FontWeight.bold : FontWeight.normal,
                            color: i == crumbs.length - 1 ? EditorColors.foreground : EditorColors.primary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _center() {
    final at = _vm.location;
    switch (at.view) {
      case AnimGraphView.animGraph:
        return AnimGraphOutputView(key: const ValueKey('abp_animgraph'), viewModel: _vm);
      case AnimGraphView.stateMachine:
        return AnimStateMachineGraph(key: const ValueKey('abp_state_machine'), viewModel: _vm);
      case AnimGraphView.state:
        return AnimStatePoseEditor(key: ValueKey('abp_state_${at.state}'), viewModel: _vm, state: at.state!);
      case AnimGraphView.transition:
        final t = _vm.transition(at.transition!);
        return BlueprintGraphCanvas(
          key: ValueKey('abp_rule_${at.transition}'),
          editor: _vm.ruleEditor(at.transition!),
          graphLabel: t == null ? 'Rule' : 'Rule: ${t.from} → ${t.to}',
        );
      case AnimGraphView.eventGraph:
        return BlueprintGraphCanvas(key: const ValueKey('abp_event_graph'), editor: _vm.eventGraph, graphLabel: 'EventGraph');
    }
  }

  Widget _bottom() {
    final rows = _vm.compileRows;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: EditorColors.background,
            child: BlueprintCompilerResults(
              status: _vm.compileStatus,
              diagnostics: [for (final r in rows) r.diagnostic],
              nodeTitle: (d) {
                final row = rows.where((r) => identical(r.diagnostic, d)).firstOrNull;
                return row?.nodeTitle;
              },
              onSelect: (d) {
                final row = rows.where((r) => identical(r.diagnostic, d)).firstOrNull;
                if (row != null) _vm.openRow(row);
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: Container(color: EditorColors.background, child: AnimPreviewEditorPanel(viewModel: _vm))),
      ],
    );
  }

  Widget _details() {
    final m = _vm.machine;
    Widget header(IconData icon, String title) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(icon, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
            ),
          ]),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(t, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        );

    final t = _vm.selectedTransition == null ? null : _vm.transition(_vm.selectedTransition!);
    final s = _vm.selectedState == null ? null : m?.state(_vm.selectedState!);
    final v = _vm.selectedVariable == null
        ? null
        : _vm.document.variables.where((x) => x.name == _vm.selectedVariable).firstOrNull;

    List<Widget> children;
    if (t != null) {
      children = [
        header(LucideIcons.arrowLeftRight, 'TRANSITION: ${t.from} → ${t.to}'),
        label('Blend Duration (s)'),
        BlueprintPinLiteralEditor(
          keyPrefix: 'transition_blend',
          type: LuminaPinType.float,
          value: t.blendDuration,
          expanded: true,
          onCommit: (x) => _vm.updateTransition(t.id, blendDuration: (x as num).toDouble()),
        ),
        label('Priority (lower is checked first)'),
        BlueprintPinLiteralEditor(
          keyPrefix: 'transition_priority',
          type: LuminaPinType.integer,
          value: t.priority,
          expanded: true,
          onCommit: (x) => _vm.updateTransition(t.id, priority: (x as num).toInt()),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          key: const ValueKey('details_open_rule'),
          size: ButtonSize.small,
          onPressed: () => _vm.open(AnimGraphLocation.transition(m!.name, t.id)),
          child: const Text('Open Rule Graph', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(height: 6),
        DestructiveButton(
          key: const ValueKey('details_delete_transition'),
          size: ButtonSize.small,
          onPressed: () => _vm.deleteTransition(t.id),
          child: const Text('Delete Transition', style: TextStyle(fontSize: 10)),
        ),
      ];
    } else if (s != null) {
      children = [
        header(LucideIcons.squareStack, 'STATE: ${s.name}'),
        Text('Pose: ${s.pose.kind.name}', style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Entry State', style: TextStyle(fontSize: 10)),
          const Spacer(),
          Switch(
            key: const ValueKey('details_entry_state'),
            value: m?.entryState == s.name,
            onChanged: (on) {
              if (on) _vm.setEntryState(s.name);
            },
          ),
        ]),
        const SizedBox(height: 8),
        OutlineButton(
          key: const ValueKey('details_open_state'),
          size: ButtonSize.small,
          onPressed: () => _vm.open(AnimGraphLocation.state(m!.name, s.name)),
          child: const Text('Open Pose', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(height: 6),
        OutlineButton(
          key: const ValueKey('details_rename_state'),
          size: ButtonSize.small,
          onPressed: () => showRenameState(context, _vm, s.name),
          child: const Text('Rename', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(height: 6),
        DestructiveButton(
          key: const ValueKey('details_delete_state'),
          size: ButtonSize.small,
          onPressed: () => _vm.deleteState(s.name),
          child: const Text('Delete State', style: TextStyle(fontSize: 10)),
        ),
      ];
    } else if (v != null) {
      children = [
        header(LucideIcons.variable, 'VARIABLE: ${v.name}'),
        label('Default Value'),
        if (v.type != null && BlueprintPinLiteralEditor.supports(v.type!))
          BlueprintPinLiteralEditor(
            keyPrefix: 'abp_variable_default_${v.name}',
            type: v.type!,
            value: v.defaultValue,
            expanded: true,
            onCommit: (x) => _vm.setVariableDefault(v.name, x),
          ),
        const SizedBox(height: 8),
        Text('Used by ${_vm.nodesUsingVariable(v.name).length} node(s)',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      ];
    } else {
      final meshes = _vm.availableSkeletalMeshes;
      children = [
        header(LucideIcons.info, 'ANIMATION BLUEPRINT'),
        label('Target Skeletal Mesh'),
        if (meshes.isNotEmpty) ...[
          AssetPickerSelect(
            key: const ValueKey('abp_target_mesh_select'),
            keyPrefix: 'abp_target_mesh',
            assets: meshes,
            selectedPath: _vm.document.targetMesh.isNotEmpty ? _vm.document.targetMesh : null,
            placeholder: 'Select a skeletal mesh',
            allowClear: false,
            onSelected: (m) {
              final v = m.relativePath;
              if (v != _vm.document.targetMesh) {
                _openRetargetDialog(context, initialTargetMeshPath: v);
              } else {
                _vm.setTargetMesh(v);
              }
            },
          ),
          const SizedBox(height: 4),
          Text(
            _vm.document.targetMesh,
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          OutlineButton(
            key: const ValueKey('abp_details_retarget_button'),
            size: ButtonSize.small,
            onPressed: () => _openRetargetDialog(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.repeat, size: 12, color: Colors.cyan),
                SizedBox(width: 6),
                Text('Retarget Linked Animations…',
                    style: TextStyle(fontSize: 10, color: Colors.cyan, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ] else ...[
          Text('Target mesh: ${_vm.document.targetMesh}', style: const TextStyle(fontSize: 10)),
        ],
        const SizedBox(height: 6),
        Text('${_vm.clips.length} clips · ${_vm.blendSpacePaths.length} Blend Spaces for this mesh',
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 6),
        const Text('Select a state or transition in the state machine to edit it.',
            style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
      ];
    }
    return Container(
      color: EditorColors.cardHeader,
      child: ListView(key: const ValueKey('abp_details'), padding: const EdgeInsets.all(12), children: children),
    );
  }
}
