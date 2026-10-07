import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/palette.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

/// Widget Hierarchy `Tree`: rows are drop targets for palette
/// widgets and for reordering (`Draggable<String>` node ids); the
/// `ContextMenu` offers Wrap With / Replace With / Add Child / Rename / Delete.
class UmgHierarchyTree extends StatefulWidget {
  final UmgEditorViewModel vm;

  const UmgHierarchyTree({super.key, required this.vm});

  @override
  State<UmgHierarchyTree> createState() => _UmgHierarchyTreeState();
}

class _UmgHierarchyTreeState extends State<UmgHierarchyTree> {
  final Set<String> _collapsed = {};

  UmgEditorViewModel get vm => widget.vm;

  List<TreeNode<String>> _nodesFor(UmgNode node) {
    return [
      TreeItemNode<String>(
        data: node.id,
        expanded: !_collapsed.contains(node.id),
        selected: vm.selectedId == node.id,
        children: node.children.expand(_nodesFor).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Tree<String>(
            nodes: _nodesFor(vm.document.root),
            expandIcon: true,
            builder: (context, treeNode) => _row(context, treeNode),
          ),
        ),
        if (vm.lastRejectionReason != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(vm.lastRejectionReason!, style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning)),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, TreeItemNode<String> treeNode) {
    final node = vm.document.findNode(treeNode.data);
    if (node == null) return const SizedBox.shrink();
    final isRoot = node.id == vm.document.root.id;
    final selected = vm.selectedId == node.id;
    return EditorContextMenu(
      items: _menuItems(context, node, isRoot),
      child: DragTarget<UmgWidgetType>(
        onAcceptWithDetails: (d) => vm.addWidget(d.data, parentId: node.id, canvasPosition: const Offset(16, 16)),
        builder: (context, paletteCandidates, _) {
          return DragTarget<String>(
            onWillAcceptWithDetails: (d) => d.data != node.id,
            onAcceptWithDetails: (d) => _dropNode(d.data, node),
            builder: (context, nodeCandidates, _) {
              final highlight = paletteCandidates.isNotEmpty || nodeCandidates.isNotEmpty;
              final item = TreeItem(
                key: ValueKey('umg_tree_${node.id}'),
                expandable: node.children.isNotEmpty,
                onExpand: (expanded) => setState(() {
                  if (expanded) {
                    _collapsed.remove(node.id);
                  } else {
                    _collapsed.add(node.id);
                  }
                }),
                onPressed: () => vm.select(node.id),
                onDoublePressed: () => _openRenameDialog(context, node),
                leading: Icon(umgIconFor(node.type), size: 11, color: selected ? EditorColors.primary : EditorColors.mutedForeground),
                trailing: Text(node.type.displayName, style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                child: Container(
                  decoration: highlight ? BoxDecoration(border: Border.all(color: EditorColors.primary), borderRadius: BorderRadius.circular(2)) : null,
                  child: Text(
                    node.name,
                    style: TextStyle(fontSize: 9.5, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? EditorColors.primary : EditorColors.foreground),
                  ),
                ),
              );
              if (isRoot) return item;
              return Draggable<String>(
                data: node.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: EditorColors.cardHeader, border: Border.all(color: EditorColors.primary), borderRadius: BorderRadius.circular(3)),
                    child: Text(node.name, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground, decoration: TextDecoration.none)),
                  ),
                ),
                child: item,
              );
            },
          );
        },
      ),
    );
  }

  /// Reorder-by-drag: dropping on a panel with room nests the node, dropping
  /// on anything else inserts it right after that sibling.
  void _dropNode(String draggedId, UmgNode target) {
    if (target.type.isPanel && vm.document.rejectionReasonFor(target) == null) {
      vm.moveNode(draggedId, target.id);
      return;
    }
    final parent = vm.document.parentOf(target.id);
    if (parent == null) return;
    final index = parent.children.indexWhere((c) => c.id == target.id) + 1;
    vm.moveNode(draggedId, parent.id, index: index);
  }

  List<MenuItem> _menuItems(BuildContext context, UmgNode node, bool isRoot) {
    const style = TextStyle(fontSize: 10);
    final wrapTypes = [UmgWidgetType.border, UmgWidgetType.canvasPanel, UmgWidgetType.verticalBox, UmgWidgetType.horizontalBox, UmgWidgetType.overlay, UmgWidgetType.sizeBox, UmgWidgetType.scrollBox];
    final replaceTypes = UmgWidgetType.values.where((t) {
      if (t == node.type) return false;
      if (node.children.isEmpty) return true;
      if (t.capacity == UmgChildCapacity.none) return false;
      if (t.capacity == UmgChildCapacity.one) return node.children.length <= 1;
      return true;
    }).toList();
    return [
      if (node.type.isPanel)
        MenuButton(
          leading: const Icon(LucideIcons.plus, size: 11),
          subMenu: [
            for (final t in UmgWidgetType.values)
              MenuButton(
                leading: Icon(umgIconFor(t), size: 11),
                onPressed: (_) => vm.addWidget(t, parentId: node.id, canvasPosition: const Offset(16, 16)),
                child: Text(t.displayName, style: style),
              ),
          ],
          child: const Text('Add Child', style: style),
        ),
      MenuButton(
        enabled: !isRoot,
        leading: const Icon(LucideIcons.group, size: 11),
        subMenu: [
          for (final t in wrapTypes)
            MenuButton(
              leading: Icon(umgIconFor(t), size: 11),
              onPressed: (_) => vm.wrapWith(node.id, t),
              child: Text(t.displayName, style: style),
            ),
        ],
        child: const Text('Wrap With', style: style),
      ),
      MenuButton(
        enabled: replaceTypes.isNotEmpty,
        leading: const Icon(LucideIcons.replace, size: 11),
        subMenu: [
          for (final t in replaceTypes)
            MenuButton(
              leading: Icon(umgIconFor(t), size: 11),
              onPressed: (_) => vm.replaceWith(node.id, t),
              child: Text(t.displayName, style: style),
            ),
        ],
        child: const Text('Replace With', style: style),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.pencil, size: 11),
        onPressed: (_) => _openRenameDialog(context, node),
        child: const Text('Rename…', style: style),
      ),
      const MenuDivider(),
      MenuButton(
        enabled: !isRoot,
        leading: const Icon(LucideIcons.trash2, size: 11, color: EditorColors.logError),
        onPressed: (_) => vm.deleteNode(node.id),
        child: const Text('Delete', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
      ),
    ];
  }

  void _openRenameDialog(BuildContext context, UmgNode node) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => _RenameDialog(vm: vm, node: node),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final UmgEditorViewModel vm;
  final UmgNode node;
  const _RenameDialog({required this.vm, required this.node});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.node.name);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    if (widget.vm.rename(widget.node.id, _controller.text)) {
      closeOverlay(context);
    } else {
      setState(() => _error = widget.vm.lastRejectionReason ?? 'Invalid name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = UmgNaming.toFieldName(_controller.text);
    return AlertDialog(
      title: const Text('Rename Element'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('umg_rename_field'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 6),
          Text('Generated field: ${field.isEmpty ? '(invalid)' : field}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(fontSize: 9, color: EditorColors.logError)),
          ],
        ],
      ),
      actions: [
        GhostButton(onPressed: () => closeOverlay(context), child: const Text('Cancel')),
        PrimaryButton(key: const ValueKey('umg_rename_apply'), onPressed: _apply, child: const Text('Rename')),
      ],
    );
  }
}
