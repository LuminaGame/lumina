import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina/lumina.dart' show LuminaBlueprintComponent;
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

/// Real Component Hierarchy Tree for Blueprint Editor.
class BlueprintComponentTree extends StatefulWidget {
  final BlueprintEditorViewModel viewModel;

  const BlueprintComponentTree({
    super.key,
    required this.viewModel,
  });

  @override
  State<BlueprintComponentTree> createState() => _BlueprintComponentTreeState();
}

class _BlueprintComponentTreeState extends State<BlueprintComponentTree> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final sceneNodes = vm.document.components.where((c) => c.isSceneComponent).toList();
        final nonSceneNodes = vm.document.components.where((c) => !c.isSceneComponent).toList();

        return Container(
          color: EditorColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: EditorColors.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.cuboid, size: 14, color: EditorColors.primary),
                    const SizedBox(width: 6),
                    const Text('COMPONENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                    const Spacer(),

                    // Add Component Button
                    PrimaryButton(
                      key: const ValueKey('add_component_button'),
                      size: ButtonSize.small,
                      onPressed: () => _showAddComponentModal(context, vm),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, size: 12),
                          SizedBox(width: 4),
                          Text('+ Add Comp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tree List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    // Scene Components (Hierarchical)
                    ..._buildSceneComponentHierarchy(sceneNodes, vm),

                    // Non-scene Actor Components Section
                    if (nonSceneNodes.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 10, bottom: 4),
                        child: Text('ACTOR COMPONENTS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                      ),
                      ...nonSceneNodes.map((node) => _buildNodeItem(node, 0, vm)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSceneComponentHierarchy(List<LuminaBlueprintComponent> nodes, BlueprintEditorViewModel vm) {
    final root = vm.rootComponent;
    if (root == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Center(
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
                        vm.document.parentClass == 'LuminaCharacter'
                            ? 'Add Character Components'
                            : 'Add Default Components',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    void addNodeRecursive(LuminaBlueprintComponent node, int depth) {
      widgets.add(_buildNodeItem(node, depth, vm));
      final children = nodes.where((c) => c.parentId == node.id).toList();
      for (final child in children) {
        addNodeRecursive(child, depth + 1);
      }
    }

    addNodeRecursive(root, 0);
    return widgets;
  }

  Widget _buildNodeItem(LuminaBlueprintComponent node, int depth, BlueprintEditorViewModel vm) {
    final isSelected = vm.selectedComponentId == node.id;
    final isRoot = node.id == vm.rootComponent?.id;

    IconData icon = LucideIcons.box;
    final registered = BlueprintComponentRegistry.getDescriptor(node.type)?.icon;
    if (registered != null && BlueprintComponentRegistry.isCollisionCapable(node.type)) {
      icon = registered;
    } else if (node.type.contains('Camera')) {
      icon = LucideIcons.camera;
    } else if (node.type.contains('SpringArm')) {
      icon = LucideIcons.move3d;
    } else if (node.type.contains('Capsule') || node.type.contains('Collision')) {
      icon = LucideIcons.shieldAlert;
    } else if (node.type.contains('Movement')) {
      icon = LucideIcons.footprints;
    } else if (node.type.contains('Mesh')) {
      icon = LucideIcons.cuboid;
    } else if (node.type.contains('Light')) {
      icon = registered ?? LucideIcons.lightbulb;
    }

    return Clickable(
      onPressed: () => vm.selectComponent(node.id),
      child: Container(
        padding: EdgeInsets.only(left: 12.0 + depth * 14.0, right: 8, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: isSelected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? EditorColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isSelected ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? EditorColors.foreground : EditorColors.foreground.withValues(alpha: 0.9),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRoot) ...[
              const SizedBox(width: 4),
              const PrimaryBadge(
                child: Text('ROOT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(width: 4),
            GhostButton(
              size: ButtonSize.small,
              onPressed: () => _showComponentActions(context, node, vm),
              child: const Icon(LucideIcons.ellipsisVertical, size: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showComponentActions(BuildContext context, LuminaBlueprintComponent node, BlueprintEditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Component Actions: ${node.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlineButton(
              onPressed: () {
                closeOverlay(dialogContext);
                _promptRename(node, vm);
              },
              child: const Row(
                children: [
                  Icon(LucideIcons.pencil, size: 14),
                  SizedBox(width: 8),
                  Text('Rename Component'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            OutlineButton(
              onPressed: () {
                closeOverlay(dialogContext);
                vm.duplicateComponent(node.id);
              },
              child: const Row(
                children: [
                  Icon(LucideIcons.copy, size: 14),
                  SizedBox(width: 8),
                  Text('Duplicate Component'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            DestructiveButton(
              onPressed: () {
                closeOverlay(dialogContext);
                vm.removeComponent(node.id);
              },
              child: const Row(
                children: [
                  Icon(LucideIcons.trash2, size: 14),
                  SizedBox(width: 8),
                  Text('Delete Component'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          GhostButton(
            child: const Text('Cancel'),
            onPressed: () => closeOverlay(dialogContext),
          ),
        ],
      ),
    );
  }

  void _promptRename(LuminaBlueprintComponent node, BlueprintEditorViewModel vm) {
    final controller = TextEditingController(text: node.name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Component'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new unique Dart identifier:').small().muted(),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          GhostButton(
            child: const Text('Cancel'),
            onPressed: () => closeOverlay(dialogContext),
          ),
          PrimaryButton(
            child: const Text('Rename'),
            onPressed: () {
              final success = vm.renameComponent(node.id, controller.text);
              if (success) {
                closeOverlay(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddComponentModal(BuildContext context, BlueprintEditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) {
        return _AddComponentDialog(
          viewModel: vm,
          onClose: () => closeOverlay(dialogContext),
        );
      },
    );
  }
}

class _AddComponentDialog extends StatefulWidget {
  final BlueprintEditorViewModel viewModel;
  final VoidCallback onClose;

  const _AddComponentDialog({required this.viewModel, required this.onClose});

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = BlueprintComponentRegistry.registeredComponents
        .where((d) => d.displayName.toLowerCase().contains(_filter.toLowerCase()) || d.typeName.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Add Component'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('add_component_search'),
              controller: _searchController,
              placeholder: const Text('Search Components...').small(),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final comp = filtered[index];
                  if (!comp.isAvailable) {
                    return Tooltip(
                      tooltip: (context) => TooltipContainer(child: Text(comp.gapReason ?? 'Not supported in engine yet').small()),
                      child: Opacity(
                        opacity: 0.45,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.lock, size: 12, color: EditorColors.mutedForeground),
                              const SizedBox(width: 8),
                              Text(comp.displayName, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Clickable(
                    key: ValueKey('add_component_${comp.typeName}'),
                    onPressed: () {
                      widget.viewModel.addComponent(comp.typeName);
                      widget.onClose();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            comp.icon ?? (comp.isSceneComponent ? LucideIcons.box : LucideIcons.cpu),
                            size: 13,
                            color: EditorColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comp.displayName,
                              style: const TextStyle(fontSize: 11, color: EditorColors.foreground),
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
      actions: [
        GhostButton(
          onPressed: widget.onClose,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
