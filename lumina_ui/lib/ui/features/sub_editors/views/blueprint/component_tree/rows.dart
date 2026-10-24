part of '../component_tree.dart';

/// A component row, as an outliner row: selection and double-click rename,
/// drag to attach, the right-click menu, and its content (chevron, eye and
/// lock toggles, type icon, name or rename field, badges, type).
mixin _ComponentRows on _ComponentTreeStateBase {
  /// Whether scene component [childId] may be attached to [parentId]: not the
  /// root, not inherited, not onto itself or a descendant, and not where it
  /// already is.
  bool _canAttach(String childId, String parentId) {
    final vm = _vm;
    final child = vm.getComponent(childId);
    if (child == null || !child.isSceneComponent || child.id == vm.rootComponent?.id) return false;
    if (child.parentId == parentId) return false;
    return vm.canReparent(childId, parentId);
  }

  bool _isDraggable(LuminaBlueprintComponent node) =>
      node.isSceneComponent && node.id != _vm.rootComponent?.id && !_vm.isInheritedComponent(node.id);

  Widget _buildRow(_ComponentRow row) {
    final vm = _vm;
    final node = row.node;
    final isFolderLike = row.expandable;

    Widget target = DragTarget<_ComponentDrag>(
      onWillAcceptWithDetails: (d) => node.isSceneComponent && _canAttach(d.data.id, node.id),
      onAcceptWithDetails: (d) {
        if (vm.reparent(d.data.id, node.id)) setState(() => _collapsedIds.remove(node.id));
      },
      builder: (context, candidate, rejected) => EditorContextMenu(
        items: _rowMenu(node),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final now = DateTime.now();
            final isDoubleClick =
                _lastTapId == node.id && _lastTapAt != null && now.difference(_lastTapAt!) <= kDoubleTapTimeout;
            _lastTapId = isDoubleClick ? null : node.id;
            _lastTapAt = isDoubleClick ? null : now;
            vm.selectComponent(node.id);
            // Double-click renames; an inherited component (not renamable)
            // expands or collapses instead, as an outliner folder does.
            if (isDoubleClick) {
              if (!_vm.isInheritedComponent(node.id)) {
                _startRename(node);
              } else if (isFolderLike) {
                _toggleExpanded(node.id);
              }
            }
          },
          child: _rowContent(row, isDropTarget: candidate.isNotEmpty),
        ),
      ),
    );

    if (_isDraggable(node)) {
      target = Draggable<_ComponentDrag>(
        data: _ComponentDrag(node.id),
        maxSimultaneousDrags: _editingId == node.id ? 0 : 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: EditorColors.primary,
          child: Text(node.name, style: const TextStyle(fontSize: 10, color: EditorColors.accentForeground)),
        ),
        child: target,
      );
    }
    return KeyedSubtree(key: ValueKey('component_row_${node.id}'), child: target);
  }

  Widget _rowContent(_ComponentRow row, {required bool isDropTarget}) {
    final vm = _vm;
    final node = row.node;
    final isSelected = vm.selectedComponentId == node.id;
    final isRoot = node.id == vm.rootComponent?.id;
    final isVisible = node.properties['visible'] != false;
    final isLocked = node.properties['isLocked'] == true;
    final isExpanded = !_collapsedIds.contains(node.id);
    final isEditing = _editingId == node.id;
    final (icon, iconColor) = _iconFor(node.type);
    final shortType = node.type.replaceAll('Lumina', '').replaceAll('Component', '');
    final inherited = vm.isInheritedComponent(node.id);
    final overridden = inherited && vm.isComponentOverridden(node.id);

    // Indented by a margin, so the amber selection starts at the indent.
    return Container(
      height: EditorDensity.rowHeight,
      margin: EditorTreeRowStyle.margin(row.depth),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: EditorTreeRowStyle.decoration(selected: isSelected, dropTarget: isDropTarget),
      child: Row(
        children: [
          if (row.expandable)
            GestureDetector(
              key: ValueKey('component_chevron_${node.id}'),
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
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () => vm.setProperty(node.id, 'visible', !isVisible),
            child: Icon(
              isVisible ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 11,
              color: isVisible ? EditorColors.mutedForeground : EditorColors.destructive,
            ),
          ),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () => vm.setProperty(node.id, 'isLocked', !isLocked),
            child: Icon(
              isLocked ? LucideIcons.lock : LucideIcons.lockOpen,
              size: 11,
              color: isLocked ? EditorColors.warning : EditorColors.border,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: isEditing
                ? SizedBox(
                    height: 18,
                    child: CallbackShortcuts(
                      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancelRename},
                      child: TextField(
                        key: const ValueKey('component_rename_field'),
                        controller: _renameController,
                        focusNode: _renameFocusNode,
                        style: TextStyle(
                          fontSize: 10,
                          color: _renameInvalid ? EditorColors.destructive : EditorColors.foreground,
                        ),
                        onChanged: (_) {
                          if (_renameInvalid) setState(() => _renameInvalid = false);
                        },
                        onSubmitted: (_) => _commitRename(),
                      ),
                    ),
                  )
                : Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: EditorTreeRowStyle.foreground(
                          selected: isSelected, normal: isVisible ? EditorColors.foreground : EditorColors.mutedForeground),
                      decoration: isVisible ? TextDecoration.none : TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          // Badges, as the outliner's world partition cell chip.
          if (inherited) _chip(overridden ? 'Overridden' : 'Inherited', overridden),
          if (isRoot) _chip('ROOT', true),
          Text(
            shortType.isEmpty ? 'Component' : shortType,
            style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool primary) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: (primary ? EditorColors.primary : EditorColors.muted).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 8, color: primary ? EditorColors.primary : EditorColors.mutedForeground),
          ),
        ),
      );

  List<MenuItem> _rowMenu(LuminaBlueprintComponent node) {
    final vm = _vm;
    final inherited = vm.isInheritedComponent(node.id);
    final root = vm.rootComponent;
    final attachTargets = [
      for (final c in vm.allComponents)
        if (c.isSceneComponent && _canAttach(node.id, c.id)) c,
    ];
    return [
      MenuButton(
        leading: const Icon(LucideIcons.pencil, size: 14),
        enabled: !inherited,
        onPressed: (ctx) => _startRename(node),
        child: const Text('Rename', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.copy, size: 14),
        onPressed: (ctx) => vm.duplicateComponent(node.id),
        child: const Text('Duplicate', style: TextStyle(fontSize: 10)),
      ),
      if (node.isSceneComponent)
        MenuButton(
          leading: const Icon(LucideIcons.link, size: 14),
          enabled: attachTargets.isNotEmpty,
          subMenu: [
            for (final c in attachTargets)
              MenuButton(
                onPressed: (ctx) => vm.reparent(node.id, c.id),
                child: Text(c.id == root?.id ? '${c.name} (Root)' : c.name, style: const TextStyle(fontSize: 10)),
              ),
          ],
          child: const Text('Attach To', style: TextStyle(fontSize: 10)),
        ),
      const MenuDivider(),
      MenuButton(
        leading: const Icon(LucideIcons.trash2, size: 14),
        enabled: !inherited,
        onPressed: (ctx) => vm.removeComponent(node.id),
        child: Text(inherited ? 'Delete (inherited from ${vm.document.parentClass})' : 'Delete',
            style: const TextStyle(fontSize: 10)),
      ),
    ];
  }

  (IconData, Color) _iconFor(String type) {
    final registered = BlueprintComponentRegistry.getDescriptor(type)?.icon;
    if (type.contains('DirectionalLight')) return (LucideIcons.sun, EditorColors.warning);
    if (type.contains('PointLight')) return (LucideIcons.lightbulb, EditorColors.warning);
    if (type.contains('SpotLight')) return (LucideIcons.flashlight, EditorColors.warning);
    if (type.contains('Camera')) return (LucideIcons.camera, EditorColors.chart2);
    if (type.contains('SpringArm')) return (LucideIcons.move3d, EditorColors.chart4);
    if (type.contains('Capsule') || type.contains('Collision')) {
      return (registered ?? LucideIcons.shieldAlert, EditorColors.destructive);
    }
    if (type.contains('Movement')) return (LucideIcons.footprints, EditorColors.chart5);
    if (type.contains('Mesh')) return (LucideIcons.box, EditorColors.primary);
    return (registered ?? LucideIcons.box, EditorColors.mutedForeground);
  }
}
