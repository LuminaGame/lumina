import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_editor_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/graph_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/parameter_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_preview_pane.dart';

class MaterialSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final LuminaAsset? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final MaterialEditorViewModel? viewModel;

  const MaterialSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  @override
  State<MaterialSubEditor> createState() => _MaterialSubEditorState();
}

class _MaterialSubEditorState extends State<MaterialSubEditor> {
  late final MaterialEditorViewModel _viewModel;
  late final bool _ownsViewModel;

  int _activeCenterTab = 0; // 0: GLSL Editor, 1: Node Graph

  late final GlslCodeController _codeController;
  final FocusNode _codeFocusNode = FocusNode();
  final GlobalKey<MaterialGlslEditorWidgetState> _editorKey = GlobalKey<MaterialGlslEditorWidgetState>();

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        MaterialEditorViewModel(
          assetPath: widget.assetPath ?? 'contents/materials/${widget.assetName}.lmas',
          initialAsset: widget.asset,
        );
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    _codeController = GlslCodeController(text: _viewModel.currentCode);
    _viewModel.addListener(_onViewModelChanged);

    if (_ownsViewModel && _viewModel.currentCode.isEmpty) {
      _viewModel.load().then((_) {
        if (mounted) {
          _codeController.text = _viewModel.currentCode;
        }
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  /// Incremented on every view-model change so the 3D preview re-applies
  /// parameter values to its material instance.
  int _paramRevision = 0;

  void _onViewModelChanged() {
    if (mounted) {
      if (_codeController.text != _viewModel.currentCode) {
        _codeController.text = _viewModel.currentCode;
      }
      setState(() {
        _paramRevision++;
      });
    }
  }

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
                _viewModel.discardChanges();
                widget.onClose?.call();
              },
            ),
            PrimaryButton(
              child: const Text('Save'),
              onPressed: () async {
                closeOverlay(dialogContext);
                await _viewModel.save();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = _viewModel;
    final hasErrors = vm.issues.any((i) => i.severity == MaterialCompileSeverity.error);

    return Container(
      color: EditorColors.background,
      child: Column(
        children: [
          // Sub-Editor Workspace Header Toolbar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: EditorColors.cardHeader,
            child: Row(
              children: [
                const SecondaryBadge(
                  child: Text('FILAMAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.assetName}${vm.isDirty ? ' *' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: EditorColors.foreground,
                  ),
                ),
                const SizedBox(width: 12),

                // Status Badge
                if (vm.syntaxStatus.startsWith('Compile OK'))
                  PrimaryBadge(child: Text(vm.syntaxStatus))
                else if (hasErrors || vm.syntaxStatus.contains('Error'))
                  DestructiveBadge(child: Text(vm.syntaxStatus))
                else
                  OutlineBadge(child: Text(vm.syntaxStatus)),

                const Spacer(),

                // Action Buttons
                GhostButton(
                  onPressed: vm.isCompiling ? null : () => vm.compile(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.play, size: 12),
                      SizedBox(width: 4),
                      Text('Apply', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GhostButton(
                  onPressed: vm.isCompiling ? null : () => vm.compile(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vm.isCompiling)
                        const Icon(LucideIcons.loader, size: 12, color: EditorColors.primary)
                      else
                        const Icon(LucideIcons.check, size: 12, color: EditorColors.logSuccess),
                      const SizedBox(width: 4),
                      const Text('Compile', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PrimaryButton(
                  onPressed: () => vm.save(),
                  child: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),

                // Close Button
                GhostButton(
                  onPressed: _handleClose,
                  child: const Icon(LucideIcons.x, size: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Center Workspace Split
          Expanded(
            child: ResizablePanel.horizontal(
              children: [
                // Left Pane: 3D preview above the material settings
                ResizablePane(
                  initialSize: 300,
                  minSize: 200,
                  child: MaterialPreviewPane(viewModel: _viewModel, parameterRevision: _paramRevision),
                ),

                // Center Pane: GLSL Editor & Compiler Log Panel
                ResizablePane.flex(
                  child: Column(
                    children: [
                      // Top: Tabs (GLSL Source vs Node Graph) & Inspector
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 32,
                              color: EditorColors.cardHeader,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  _buildSubTabHeader(0, LucideIcons.code, 'GLSL Source (.mat)'),
                                  _buildSubTabHeader(1, LucideIcons.gitFork, 'Node Graph'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _activeCenterTab == 0
                                  ? MaterialGlslEditorWidget(
                                      key: _editorKey,
                                      viewModel: vm,
                                      controller: _codeController,
                                      focusNode: _codeFocusNode,
                                    )
                                  : MaterialGraphView(viewModel: vm),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Bottom: Compiler Log Panel
                      SizedBox(
                        height: 160,
                        child: Container(
                          color: theme.colorScheme.card,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                color: EditorColors.cardHeader,
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.terminal, size: 12, color: EditorColors.mutedForeground),
                                    const SizedBox(width: 6),
                                    const Text('COMPILER LOG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                                    const SizedBox(width: 8),
                                    if (vm.compiledBytes != null)
                                      Text('${vm.compiledBytes!.length} bytes · ${vm.elapsedMs}ms', style: const TextStyle(fontSize: 10)).muted(),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              if (hasErrors)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  color: theme.colorScheme.destructive.withValues(alpha: 0.1),
                                  child: Row(
                                    children: [
                                      Icon(LucideIcons.triangleAlert, size: 14, color: theme.colorScheme.destructive),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          vm.issues.firstWhere((i) => i.severity == MaterialCompileSeverity.error).message,
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.destructive),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: vm.issues.isEmpty
                                    ? Center(child: const Text('No compiler diagnostics').muted())
                                    : ListView.builder(
                                        itemCount: vm.issues.length,
                                        itemBuilder: (context, index) {
                                          final issue = vm.issues[index];
                                          final isError = issue.severity == MaterialCompileSeverity.error;
                                          final isWarning = issue.severity == MaterialCompileSeverity.warning;
                                          final nodeId = issue.nodeId;
                                          final nodeTitle = nodeId == null ? null : vm.graph.editor.node(nodeId)?.title;
                                          return Clickable(
                                            onPressed: () {
                                              if (nodeId != null) {
                                                _showNode(nodeId);
                                                return;
                                              }
                                              if (issue.line > 0) _editorKey.currentState?.jumpToLine(issue.line);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(color: theme.colorScheme.border, width: 0.5),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  if (isError)
                                                    const DestructiveBadge(child: Text('ERROR'))
                                                  else if (isWarning)
                                                    const OutlineBadge(child: Text('WARN'))
                                                  else
                                                    const PrimaryBadge(child: Text('OK')),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    nodeTitle != null
                                                        ? 'Node $nodeTitle:'
                                                        : (issue.line > 0
                                                            ? 'Line ${issue.line}:'
                                                            : (issue.fromCompiler ? 'matc:' : 'Graph:')),
                                                    style: const TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 11),
                                                  ).muted(),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      issue.message,
                                                      style: TextStyle(
                                                        fontFamily: EditorTypography.monoFamily,
                                                        fontSize: 11,
                                                        color: isError
                                                            ? theme.colorScheme.destructive
                                                            : theme.colorScheme.foreground,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Pane: parameters and texture slots
                ResizablePane(
                  initialSize: 260,
                  minSize: 200,
                  child: MaterialParameterPanel(viewModel: _viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A compiler-log row about a graph node: show the graph, select and frame
  /// the node.
  void _showNode(String nodeId) {
    setState(() => _activeCenterTab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.graph.editor.focusNode(nodeId);
    });
  }

  Widget _buildSubTabHeader(int index, IconData icon, String label) {
    final active = _activeCenterTab == index;
    return Clickable(
      onPressed: () => setState(() => _activeCenterTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? EditorColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
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
}
