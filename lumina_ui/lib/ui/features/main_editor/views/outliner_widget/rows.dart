part of '../outliner_widget.dart';

/// An outliner row: selection clicks, drag and drop, and its content (icon,
/// name or inline rename, type, eye and lock toggles).
mixin _OutlinerRows on _OutlinerWidgetStateBase, _OutlinerRenameAndDrop, _OutlinerRowMenu {
  Widget _buildActorRow(_FlattenedNode fnode, List<_FlattenedNode> flatNodes) {
    final vm = _vm;
    final node = fnode.node;
    final isFolder = node.type == 'Folder';
    final isExpanded = vm.isOutlinerExpanded(node.id);
    final dragIds = _idsFor(node);

    final draggable = Draggable<_OutlinerDrag>(
      data: _OutlinerDrag(dragIds),
      maxSimultaneousDrags: _editingId == node.id ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: EditorColors.primary,
        child: Text(
          dragIds.length == 1 ? node.name : '${dragIds.length} items',
          style: const TextStyle(fontSize: 10, color: EditorColors.accentForeground),
        ),
      ),
      child: DragTarget<_OutlinerDrag>(
        onWillAcceptWithDetails: (details) => _canDropOn(details.data, node),
        onMove: (details) => _scheduleHoverExpand(node),
        onLeave: (data) => _cancelHoverExpand(node.id),
        onAcceptWithDetails: (details) => _dropOn(details.data, node),
        builder: (context, candidateData, rejectedData) {
          return EditorContextMenu(
            items: _rowMenu(node, dragIds),
            child: GestureDetector(
              key: ValueKey('row_gesture_${node.id}'),
              behavior: HitTestBehavior.opaque,
              // Double-click is detected here rather than with onDoubleTap,
              // which would hold every click in the row (the chevron's too)
              // for the double-tap timeout.
              onTap: () {
                final now = DateTime.now();
                final keys = HardwareKeyboard.instance.logicalKeysPressed;
                final isAdditive = keys.contains(LogicalKeyboardKey.controlLeft) ||
                    keys.contains(LogicalKeyboardKey.controlRight) ||
                    keys.contains(LogicalKeyboardKey.metaLeft) ||
                    keys.contains(LogicalKeyboardKey.metaRight);
                final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                    keys.contains(LogicalKeyboardKey.shiftRight);

                final isDoubleClick = !isShift &&
                    _lastTapId == node.id &&
                    _lastTapAt != null &&
                    now.difference(_lastTapAt!) <= kDoubleTapTimeout;
                _lastTapId = (isDoubleClick || isShift) ? null : node.id;
                _lastTapAt = (isDoubleClick || isShift) ? null : now;
                if (isDoubleClick) {
                  if (isFolder) {
                    vm.toggleOutlinerExpanded(node.id);
                  } else {
                    vm.requestOutlinerRename(node.id);
                  }
                  return;
                }

                if (isShift) {
                  final anchorId = (_selectionAnchorId != null &&
                          vm.selectedActorIds.contains(_selectionAnchorId))
                      ? _selectionAnchorId
                      : vm.selectedActorId;
                  final anchorIndex = anchorId != null
                      ? flatNodes.indexWhere((f) => f.node.id == anchorId)
                      : -1;
                  final targetIndex =
                      flatNodes.indexWhere((f) => f.node.id == node.id);

                  if (anchorIndex >= 0 && targetIndex >= 0) {
                    final start = min(anchorIndex, targetIndex);
                    final end = max(anchorIndex, targetIndex);
                    final rangeIds = [
                      for (var i = start; i <= end; i++) flatNodes[i].node.id
                    ];

                    if (isAdditive) {
                      vm.selectActors(rangeIds);
                    } else {
                      vm.setActorSelection(rangeIds, primaryId: node.id);
                    }
                    return;
                  }
                }

                _selectionAnchorId = node.id;
                if (isAdditive) {
                  vm.toggleActorSelection(node.id);
                } else {
                  vm.selectActorById(node.id);
                }
              },
              child: _rowContent(fnode, isExpanded: isExpanded, isDropTarget: candidateData.isNotEmpty),
            ),
          );
        },
      ),
    );

    return KeyedSubtree(key: ValueKey('outliner_row_${node.id}'), child: draggable);
  }

  Widget _rowContent(_FlattenedNode fnode, {required bool isExpanded, required bool isDropTarget}) {
    final vm = _vm;
    final node = fnode.node;
    final isFolder = node.type == 'Folder';
    final isSelected = vm.selectedActorIds.contains(node.id);
    final isEditing = _editingId == node.id;
    final cellLabel = isFolder ? null : vm.worldPartitionCellLabel(node);

    // Indented by a margin, so the amber selection starts at the row's own
    // indent, not at the panel edge.
    final onRow = EditorTreeRowStyle.foreground(selected: isSelected);
    final mutedOnRow = isSelected ? EditorColors.primaryForeground.withValues(alpha: 0.7) : EditorColors.mutedForeground;
    return Container(
      height: EditorDensity.rowHeight,
      margin: EditorTreeRowStyle.margin(fnode.depth),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: EditorTreeRowStyle.decoration(selected: isSelected, dropTarget: isDropTarget),
      child: Row(
        children: [
          // Expand chevron: every folder has one, even when empty.
          if (fnode.expandable)
            GestureDetector(
              key: ValueKey('outliner_chevron_${node.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => vm.toggleOutlinerExpanded(node.id),
              child: Icon(
                isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 14,
                color: mutedOnRow,
              ),
            )
          else
            const SizedBox(width: 14),
          const SizedBox(width: 4),

          // Eye toggle
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () {
              if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.altLeft) ||
                  HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.altRight)) {
                vm.toggleSoloWithTransaction(node.id);
              } else {
                vm.setActorVisibilityWithTransaction(node.id, !node.isVisible, recursive: isFolder);
              }
            },
            child: Icon(
              node.isVisible ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 11,
              color: node.isVisible ? mutedOnRow : EditorColors.destructive,
            ),
          ),
          // Lock toggle
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () => vm.setActorLockedWithTransaction(node.id, !node.isLocked),
            child: Icon(
              node.isLocked ? LucideIcons.lock : LucideIcons.lockOpen,
              size: 11,
              color: node.isLocked ? (isSelected ? EditorColors.primaryForeground : EditorColors.warning) : (isSelected ? mutedOnRow : EditorColors.border),
            ),
          ),
          const SizedBox(width: 4),

          Icon(
            isFolder ? (isExpanded ? LucideIcons.folderOpen : LucideIcons.folder) : _getIconForType(node.type),
            size: 12,
            color: isSelected ? onRow : _getColorForType(node.type),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: isEditing
                ? SizedBox(
                    height: 18,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): () {
                          _renameHadFocus = false;
                          vm.endOutlinerRename();
                        },
                      },
                      child: TextField(
                        key: const ValueKey('outliner_rename_field'),
                        controller: _renameController,
                        focusNode: _renameFocusNode,
                        style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
                        onSubmitted: (_) {
                          _renameHadFocus = false;
                          _commitRename();
                        },
                      ),
                    ),
                  )
                : Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? onRow : (node.isVisible ? EditorColors.foreground : EditorColors.mutedForeground),
                      decoration: node.isVisible ? TextDecoration.none : TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          // Which world-partition cell this actor falls in, when the level
          // authors an enabled partition. Computed exactly the way
          // LuminaWorldPartitionSubsystem.cellAt does it.
          if (cellLabel != null) ...[
            Tooltip(
              tooltip: (context) => const TooltipContainer(child: Text('World Partition cell (x, y)')),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: EditorColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(cellLabel, style: const TextStyle(fontSize: 8, color: EditorColors.primary)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            isFolder ? '${fnode.childCount}' : node.type,
            style: EditorTypography.mono(fontSize: 8, color: mutedOnRow),
          ),
        ],
      ),
    );
  }

  // One catalog answers what an actor type looks like, so the tree, the spawn
  // menu and the details panel cannot drift apart.
  IconData _getIconForType(String type) => EditorActorCatalog.iconFor(type);

  Color _getColorForType(String type) => EditorActorCatalog.colorFor(type);
}
