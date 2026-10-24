import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintComponent;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

part 'component_tree/add_component_dialog.dart';
part 'component_tree/rows.dart';

/// What a component row carries while it is dragged.
class _ComponentDrag {
  final String id;
  const _ComponentDrag(this.id);
}

/// One visible row of the component tree.
class _ComponentRow {
  final LuminaBlueprintComponent node;
  final int depth;
  final bool expandable;
  const _ComponentRow(this.node, this.depth, this.expandable);
}

/// The Blueprint editor's component hierarchy, built like the Level Editor's
/// World Outliner: the same header (title, Expand All / Collapse All, Add),
/// search field, 24 px rows with chevron, eye, lock, type icon, name and
/// type, the same selection and drop highlights, a right-click menu and
/// inline rename (double-click). Scene components are dragged onto
/// another scene component to attach to it, or onto the empty area below
/// the rows to attach to the root.
class BlueprintComponentTree extends StatefulWidget {
  final BlueprintEditorViewModel viewModel;

  const BlueprintComponentTree({super.key, required this.viewModel});

  @override
  State<BlueprintComponentTree> createState() => _BlueprintComponentTreeState();
}

abstract class _ComponentTreeStateBase extends State<BlueprintComponentTree> {
  BlueprintEditorViewModel get _vm => widget.viewModel;
  final Set<String> _collapsedIds = {};
  String _filterQuery = '';

  // Inline rename.
  String? _editingId;
  bool _renameInvalid = false;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  // Double-click detection (see the outliner: onDoubleTap would delay every click).
  String? _lastTapId;
  DateTime? _lastTapAt;

  void _toggleExpanded(String id) => setState(() {
        if (!_collapsedIds.remove(id)) _collapsedIds.add(id);
      });

  void _startRename(LuminaBlueprintComponent node) {
    if (_vm.isInheritedComponent(node.id)) return;
    setState(() {
      _editingId = node.id;
      _renameInvalid = false;
      _renameController.text = node.name;
      _renameController.selection = TextSelection(baseOffset: 0, extentOffset: node.name.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingId == node.id) _renameFocusNode.requestFocus();
    });
  }

  /// Applies the typed name; an invalid or taken one keeps the field open.
  void _commitRename() {
    final id = _editingId;
    if (id == null) return;
    final name = _renameController.text.trim();
    if (name == _vm.getComponent(id)?.name || _vm.renameComponent(id, name)) {
      setState(() => _editingId = null);
    } else {
      setState(() => _renameInvalid = true);
      _renameFocusNode.requestFocus();
    }
  }

  void _cancelRename() => setState(() => _editingId = null);
}

class _BlueprintComponentTreeState extends _ComponentTreeStateBase with _ComponentRows {
  @override
  void initState() {
    super.initState();
    _renameFocusNode.addListener(() {
      if (!_renameFocusNode.hasFocus && _editingId != null && !_renameInvalid) _commitRename();
    });
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  /// The scene hierarchy from the root, depth first, skipping collapsed subtrees.
  List<_ComponentRow> _sceneRows() {
    final vm = _vm;
    final scene = vm.allComponents.where((c) => c.isSceneComponent).toList();
    final root = vm.rootComponent;
    if (root == null) return const [];
    final rows = <_ComponentRow>[];
    void visit(LuminaBlueprintComponent node, int depth) {
      final children = scene.where((c) => c.parentId == node.id).toList();
      rows.add(_ComponentRow(node, depth, children.isNotEmpty));
      if (_collapsedIds.contains(node.id)) return;
      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    visit(root, 0);
    return rows;
  }

  void _setAllExpanded(bool expanded) => setState(() {
        _collapsedIds.clear();
        if (!expanded) {
          _collapsedIds.addAll(_vm.allComponents.where((c) => c.isSceneComponent).map((c) => c.id));
        }
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _vm, builder: (context, _) => _buildTree(context));
  }

  Widget _buildTree(BuildContext context) {
    final vm = _vm;
    final query = _filterQuery.toLowerCase();
    final filtering = query.isNotEmpty;
    final sceneRows = filtering
        ? [
            for (final c in vm.allComponents)
              if (c.isSceneComponent && c.name.toLowerCase().contains(query)) _ComponentRow(c, 0, false),
          ]
        : _sceneRows();
    final actorRows = [
      for (final c in vm.allComponents)
        if (!c.isSceneComponent && (!filtering || c.name.toLowerCase().contains(query))) _ComponentRow(c, 0, false),
    ];

    // On its island, as the World Outliner: the island header (title,
    // count, expand / collapse, Add), the search field, the rows.
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorIslandHeader(
            title: 'Components',
            trailingInfo: '${vm.allComponents.length}',
            actions: [
              _headerIcon(
                key: const ValueKey('components_expand_all'),
                icon: LucideIcons.chevronsUpDown,
                tooltip: 'Expand All',
                onPressed: () => _setAllExpanded(true),
              ),
              _headerIcon(
                key: const ValueKey('components_collapse_all'),
                icon: LucideIcons.chevronsDownUp,
                tooltip: 'Collapse All',
                onPressed: () => _setAllExpanded(false),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: PrimaryButton(
                  key: const ValueKey('add_component_button'),
                  density: EditorDensity.chipButton,
                  alignment: Alignment.center,
                  onPressed: () => _showAddComponentModal(context, vm),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.plus, size: 12, color: EditorColors.primaryForeground),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: EditorTypography.ui(
                              fontSize: EditorTypography.labelSize, fontWeight: FontWeight.w700, color: EditorColors.primaryForeground)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Search field, on the island as the outliner's.
          Padding(
            padding: const EdgeInsets.fromLTRB(EditorDensity.gutter, 8, EditorDensity.gutter, 4),
            child: TextField(
              key: const ValueKey('components_search'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              borderRadius: BorderRadius.circular(8),
              onChanged: (v) => setState(() => _filterQuery = v),
              style: EditorTypography.ui(fontSize: EditorTypography.bodySize, color: EditorColors.foreground),
              placeholder: Text('Search components...',
                  style: EditorTypography.ui(fontSize: EditorTypography.bodySize, color: EditorColors.mutedForeground)),
            ),
          ),

          Expanded(
            child: vm.rootComponent == null && actorRows.isEmpty
                ? _buildNoComponents(vm)
                : CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildListDelegate([
                          for (final r in sceneRows) _buildRow(r),
                          if (actorRows.isNotEmpty) ...[
                            Container(
                              height: EditorDensity.rowHeight,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: EditorDensity.gutter, top: 6),
                              child: Text('ACTOR COMPONENTS', style: EditorIslandSectionLabel.style),
                            ),
                            for (final r in actorRows) _buildRow(r),
                          ],
                        ]),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 32),
                          child: _buildEmptyArea(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
    );
  }

  Widget _headerIcon({required Key key, required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(tooltip)),
      child: GhostButton(
        key: key,
        density: ButtonDensity.compact,
        onPressed: onPressed,
        child: Icon(icon, size: 11, color: EditorColors.mutedForeground),
      ),
    );
  }

  /// Below the rows: a scene component dropped here attaches to the root; a
  /// click clears the selection.
  Widget _buildEmptyArea() {
    final vm = _vm;
    final root = vm.rootComponent;
    return DragTarget<_ComponentDrag>(
      onWillAcceptWithDetails: (d) => root != null && _canAttach(d.data.id, root.id),
      onAcceptWithDetails: (d) => vm.reparent(d.data.id, root!.id),
      builder: (context, candidate, rejected) => GestureDetector(
        key: const ValueKey('components_empty_area'),
        behavior: HitTestBehavior.opaque,
        onTap: () => vm.selectComponent(null),
        child: Container(
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? EditorColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            border: candidate.isNotEmpty ? const Border(top: BorderSide(color: EditorColors.primary, width: 1)) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNoComponents(BlueprintEditorViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.cuboid, size: 22, color: EditorColors.mutedForeground),
          const SizedBox(height: 8),
          const Text('No Scene Components attached', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(height: 12),
          OutlineButton(
            size: ButtonSize.small,
            onPressed: () => vm.resetToDefaultComponents(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, size: 12, color: EditorColors.primary),
                const SizedBox(width: 6),
                Text(
                  vm.document.parentClass == 'LuminaCharacter' ? 'Add Character Components' : 'Add Default Components',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddComponentModal(BuildContext context, BlueprintEditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => _AddComponentDialog(viewModel: vm, onClose: () => closeOverlay(dialogContext)),
    );
  }
}
