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
        final sceneNodes = vm.allComponents.where((c) => c.isSceneComponent).toList();
        final nonSceneNodes = vm.allComponents.where((c) => !c.isSceneComponent).toList();

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

  final Set<String> _collapsedIds = {};

  void _toggleExpanded(String id) {
    setState(() {
      if (_collapsedIds.contains(id)) {
        _collapsedIds.remove(id);
      } else {
        _collapsedIds.add(id);
      }
    });
  }

  (IconData, Color) _getComponentIconAndColor(String type) {
    final registered = BlueprintComponentRegistry.getDescriptor(type)?.icon;
    if (type.contains('DirectionalLight')) {
      return (LucideIcons.sun, EditorColors.warning);
    }
    if (type.contains('PointLight')) {
      return (LucideIcons.lightbulb, EditorColors.warning);
    }
    if (type.contains('SpotLight')) {
      return (LucideIcons.flashlight, EditorColors.warning);
    }
    if (type.contains('Camera')) {
      return (LucideIcons.camera, EditorColors.chart2);
    }
    if (type.contains('SpringArm')) {
      return (LucideIcons.move3d, EditorColors.chart4);
    }
    if (type.contains('Capsule') || type.contains('Collision')) {
      return (registered ?? LucideIcons.shieldAlert, EditorColors.destructive);
    }
    if (type.contains('Movement')) {
      return (LucideIcons.footprints, EditorColors.chart5);
    }
    if (type.contains('Mesh')) {
      return (LucideIcons.box, EditorColors.primary);
    }
    return (registered ?? LucideIcons.box, EditorColors.mutedForeground);
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
      final children = nodes.where((c) => c.parentId == node.id).toList();
      final isExpanded = !_collapsedIds.contains(node.id);
      widgets.add(_buildNodeItem(
        node,
        depth,
        vm,
        hasChildren: children.isNotEmpty,
        isExpanded: isExpanded,
      ));
      if (isExpanded) {
        for (final child in children) {
          addNodeRecursive(child, depth + 1);
        }
      }
    }

    addNodeRecursive(root, 0);
    return widgets;
  }

  Widget _buildNodeItem(
    LuminaBlueprintComponent node,
    int depth,
    BlueprintEditorViewModel vm, {
    bool hasChildren = false,
    bool isExpanded = true,
  }) {
    final isSelected = vm.selectedComponentId == node.id;
    final isRoot = node.id == vm.rootComponent?.id;
    final isVisible = node.properties['visible'] != false;
    final isLocked = node.properties['isLocked'] == true;

    final (icon, iconColor) = _getComponentIconAndColor(node.type);
    final shortType = node.type.replaceAll('Lumina', '').replaceAll('Component', '');

    return GestureDetector(
      key: ValueKey('component_row_${node.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => vm.selectComponent(node.id),
      child: Container(
        height: EditorDensity.rowHeight,
        padding: EdgeInsets.only(
          left: EditorDensity.gutter + (depth * EditorDensity.indentStep),
          right: EditorDensity.gutter,
        ),
        decoration: BoxDecoration(
          color: isSelected ? EditorColors.selectionBg : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: EditorColors.primary, width: EditorDensity.selectionBarWidth))
              : null,
        ),
        child: Row(
          children: [
            // Chevron
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleExpanded(node.id),
                child: Icon(
                  isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 14,
                  color: EditorColors.mutedForeground,
                ),
              )
            else
              const SizedBox(width: 14),
            const SizedBox(width: 4),

            // Eye visibility toggle
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () {
                vm.setProperty(node.id, 'visible', !isVisible);
              },
              child: Icon(
                isVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 11,
                color: isVisible ? EditorColors.mutedForeground : EditorColors.destructive,
              ),
            ),

            // Lock toggle
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () {
                vm.setProperty(node.id, 'isLocked', !isLocked);
              },
              child: Icon(
                isLocked ? LucideIcons.lock : LucideIcons.lockOpen,
                size: 11,
                color: isLocked ? EditorColors.warning : EditorColors.border,
              ),
            ),
            const SizedBox(width: 4),

            // Type icon
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 6),

            // Component name
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? EditorColors.primary
                      : (isVisible ? EditorColors.foreground : EditorColors.mutedForeground),
                  decoration: isVisible ? TextDecoration.none : TextDecoration.lineThrough,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Inherited Badge
            if (vm.isInheritedComponent(node.id)) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (vm.isComponentOverridden(node.id) ? EditorColors.primary : EditorColors.muted).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  vm.isComponentOverridden(node.id) ? 'Overridden' : 'Inherited',
                  style: TextStyle(
                    fontSize: 7.5,
                    color: vm.isComponentOverridden(node.id) ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                ),
              ),
            ],

            // ROOT Badge
            if (isRoot) ...[
              const SizedBox(width: 4),
              const PrimaryBadge(
                child: Text('ROOT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],

            const SizedBox(width: 6),

            // Right-aligned Type name (matching Image 2)
            Text(
              shortType.isEmpty ? 'Component' : shortType,
              style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
            ),

            const SizedBox(width: 4),

            // Action ellipsis menu
            GhostButton(
              density: ButtonDensity.compact,
              size: ButtonSize.xSmall,
              onPressed: () => _showComponentActions(context, node, vm),
              child: const Icon(LucideIcons.ellipsisVertical, size: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showComponentActions(BuildContext context, LuminaBlueprintComponent node, BlueprintEditorViewModel vm) {
    final isInherited = vm.isInheritedComponent(node.id);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Component Actions: ${node.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isInherited) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: EditorColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, size: 14, color: EditorColors.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This component is inherited from parent class "${vm.document.parentClass}". To edit its hierarchy or remove it, edit the parent Blueprint.',
                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
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
            ],
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
            if (!isInherited) ...[
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
          ],
        ),
        actions: [
          GhostButton(
            child: const Text('Close'),
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
