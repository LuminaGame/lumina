import 'package:flutter/services.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart' show UmgWidgetCodegen;
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/designer_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/hierarchy_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/slot_inspector.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

/// The UMG designer: Palette | Hierarchy tabs on the left, the live
/// designer canvas in the center and the slot/appearance/events inspector
/// on the right — all bound to one [UmgEditorViewModel] over a real WIDGET
/// `.lmas`. Graph mode is the widget's own Blueprint event
/// graph, with the generated source behind View Generated Code.
class UMGWidgetSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final LuminaAsset? asset;
  final String? projectDirPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final UmgEditorViewModel? viewModel;

  const UMGWidgetSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.projectDirPath,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  @override
  State<UMGWidgetSubEditor> createState() => _UMGWidgetSubEditorState();
}

class _UMGWidgetSubEditorState extends State<UMGWidgetSubEditor> {
  late final UmgEditorViewModel _vm;
  late final bool _ownsViewModel;
  int _leftTab = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'umg_editor');

  UmgEditorViewModel get viewModelForTest => _vm;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm = widget.viewModel ??
        UmgEditorViewModel(
          assetPath: widget.assetPath ??
              '${widget.projectDirPath ?? '.'}/contents/widgets/'
                  '${widget.assetName.endsWith('.lmas') ? widget.assetName : '${widget.assetName}.lmas'}',
          initialAsset: widget.asset,
          projectDirPathOverride: widget.projectDirPath,
        );
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    _vm.addListener(_onVmChanged);
    _vm.transactions.addListener(_onVmChanged);
    if (_ownsViewModel && !_vm.isLoaded) {
      _vm.load();
    } else if (_ownsViewModel) {
      _vm.refreshTextures();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.transactions.removeListener(_onVmChanged);
    if (_ownsViewModel) _vm.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleClose() async {
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
              _vm.discardChanges();
              widget.onClose?.call();
            },
            child: const Text('Discard'),
          ),
          PrimaryButton(
            onPressed: () async {
              closeOverlay(dialogContext);
              await _vm.save();
              widget.onClose?.call();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): vm.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): vm.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): vm.redo,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => vm.save(),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          // In Graph mode Delete belongs to the graph.
          final id = vm.selectedId;
          if (id != null && vm.mode == UmgEditorMode.designer) vm.deleteNode(id);
        },
      },
      child: Focus(
        focusNode: _focusNode,
        child: Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _toolbar(vm),
              // What stops this widget compiling for the project.
              for (final error in vm.validationErrors)
                Container(
                  key: const ValueKey('umg_validation_error'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: EditorColors.logError.withValues(alpha: 0.12),
                  child: Row(children: [
                    const Icon(LucideIcons.circleAlert, size: 11, color: EditorColors.logError),
                    const SizedBox(width: 6),
                    Expanded(child: Text(error, style: const TextStyle(fontSize: 9.5, color: EditorColors.logError))),
                  ]),
                ),
              Expanded(
                child: vm.mode == UmgEditorMode.graph ? _graphMode(vm) : ResizablePanel.horizontal(
                  children: [
                    ResizablePane(
                      initialSize: 260,
                      minSize: 180,
                      child: Container(color: EditorColors.cardHeader, child: _leftPanel(vm)),
                    ),
                    ResizablePane.flex(
                      child: UmgDesignerCanvas(vm: vm),
                    ),
                    ResizablePane(
                      initialSize: 290,
                      minSize: 220,
                      child: Container(color: EditorColors.cardHeader, child: UmgSlotInspector(vm: vm)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(UmgEditorViewModel vm) {
    final compile = vm.lastCompile;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
            child: const Text('UMG WIDGET', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 8),
          Text(widget.assetName.endsWith('.lmas') ? widget.assetName : '${widget.assetName}.lmas', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          if (vm.isDirty) ...[
            const SizedBox(width: 4),
            const Text('●', style: TextStyle(fontSize: 10, color: EditorColors.primary)),
          ],
          const SizedBox(width: 12),
          // The graph's own history in Graph mode.
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(vm.activeTransactions.undoLabel, style: const TextStyle(fontSize: 9))),
            child: GhostButton(
              key: const ValueKey('umg_undo'),
              onPressed: vm.activeTransactions.canUndo ? vm.undo : null,
              child: const Icon(LucideIcons.undo2, size: 13),
            ),
          ),
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(vm.activeTransactions.redoLabel, style: const TextStyle(fontSize: 9))),
            child: GhostButton(
              key: const ValueKey('umg_redo'),
              onPressed: vm.activeTransactions.canRedo ? vm.redo : null,
              child: const Icon(LucideIcons.redo2, size: 13),
            ),
          ),
          const Spacer(),
          if (vm.compileError != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DestructiveBadge(child: Text(vm.compileError!, style: const TextStyle(fontSize: 8))),
            )
          else if (compile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                tooltip: (_) => TooltipContainer(child: Text(compile.filePath, style: const TextStyle(fontSize: 9))),
                child: SecondaryBadge(
                  child: Text(
                    compile.written ? 'Generated lib/widgets/${compile.filePath.split('/').last}' : 'Up to date: lib/widgets/${compile.filePath.split('/').last}',
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              ),
            ),
          for (final m in UmgEditorMode.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Button(
                key: ValueKey('umg_mode_${m.name}'),
                style: vm.mode == m ? const ButtonStyle.primary() : const ButtonStyle.ghost(),
                onPressed: () => vm.setMode(m),
                child: Text(m == UmgEditorMode.designer ? 'Designer' : 'Graph', style: const TextStyle(fontSize: 9)),
              ),
            ),
          if (vm.mode == UmgEditorMode.graph) ...[
            const SizedBox(width: 4),
            Tooltip(
              tooltip: (_) => const TooltipContainer(child: Text('Show the generated lib/widgets source instead of the graph', style: TextStyle(fontSize: 9))),
              child: Button(
                key: const ValueKey('umg_view_generated_code'),
                style: vm.showGeneratedCode ? const ButtonStyle.secondary() : const ButtonStyle.ghost(),
                onPressed: () => vm.setShowGeneratedCode(!vm.showGeneratedCode),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.code, size: 11),
                  SizedBox(width: 4),
                  Text('View Generated Code', style: TextStyle(fontSize: 9)),
                ]),
              ),
            ),
          ],
          const SizedBox(width: 8),
          UmgThemeHelper.buildDocumentThemePicker(vm: vm, compact: true),
          const SizedBox(width: 8),
          OutlineButton(
            key: const ValueKey('umg_save'),
            onPressed: () => vm.save(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.save, size: 11), SizedBox(width: 4), Text('Save', style: TextStyle(fontSize: 9))]),
          ),
          const SizedBox(width: 4),
          PrimaryButton(
            key: const ValueKey('umg_compile'),
            onPressed: () => vm.compile(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.hammer, size: 11), SizedBox(width: 4), Text('Compile', style: TextStyle(fontSize: 9))]),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GhostButton(onPressed: _handleClose, child: const Icon(LucideIcons.x, size: 14)),
          ],
        ],
      ),
    );
  }

  Widget _leftPanel(UmgEditorViewModel vm) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: Tabs(
            index: _leftTab,
            onChanged: (i) => setState(() => _leftTab = i),
            children: const [
              TabItem(key: ValueKey('umg_left_tab_palette'), child: Text('Palette', style: TextStyle(fontSize: 9))),
              TabItem(key: ValueKey('umg_left_tab_hierarchy'), child: Text('Hierarchy', style: TextStyle(fontSize: 9))),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _leftTab == 0 ? UmgPalette(vm: vm) : UmgHierarchyTree(vm: vm),
          ),
        ),
      ],
    );
  }

  /// Graph mode: the widget's own Blueprint event graph —
  /// the Blueprint editor in its widget configuration — or, with View
  /// Generated Code on, the generated source.
  Widget _graphMode(UmgEditorViewModel vm) {
    if (vm.showGeneratedCode) return _generatedCodeView(vm);
    return BlueprintSubEditor(
      key: const ValueKey('umg_graph_editor'),
      assetName: vm.fileBasename,
      assetPath: vm.assetPath,
      viewModel: vm.graphEditor,
      showPreviewViewport: false,
    );
  }

  /// The generated handler/widget source (View Generated Code).
  Widget _generatedCodeView(UmgEditorViewModel vm) {
    final source = vm.generatedSource;
    return Container(
      color: EditorColors.background,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.code, size: 12, color: Colors.amber),
              const SizedBox(width: 6),
              Text('Generated lib/widgets/${UmgWidgetCodegen.dartFileNameFor(vm.fileBasename)} — event handlers carry // BEGIN USER CODE guards',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: CodeSnippet(
                key: const ValueKey('umg_graph_source'),
                code: Text(source, style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: Colors.cyan)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
