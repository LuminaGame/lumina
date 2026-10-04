import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/services/file_reveal.dart';
import '../../../core/theme/editor_theme.dart';
import '../models/editor_actor_catalog.dart';
import '../view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

/// What an outliner row carries while it is dragged: the node itself, or the
/// whole selection when the dragged row is part of it.
class _OutlinerDrag {
  final List<String> ids;
  const _OutlinerDrag(this.ids);
}

class OutlinerWidget extends StatefulWidget {
  final EditorViewModel viewModel;

  const OutlinerWidget({super.key, required this.viewModel});

  @override
  State<OutlinerWidget> createState() => _OutlinerWidgetState();
}

class _OutlinerWidgetState extends State<OutlinerWidget> {
  String _filterQuery = '';
  String? _editingId;
  bool _renameHadFocus = false;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  // A collapsed folder hovered by a drag opens after a short hold.
  static const Duration _hoverExpandDelay = Duration(milliseconds: 600);
  Timer? _hoverExpandTimer;
  String? _hoverExpandId;

  String? _lastTapId;
  DateTime? _lastTapAt;
  String? _selectionAnchorId;

  // The row being renamed, or the newly selected one, is scrolled into view.
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledTo;

  EditorViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _renameFocusNode.addListener(_onRenameFocusChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hoverExpandTimer?.cancel();
    _renameFocusNode.removeListener(_onRenameFocusChanged);
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  // --- Inline rename, driven by EditorViewModel.outlinerRenamingId ---------

  /// Follows the VM's rename request (F2, New Folder, context menu).
  void _syncRenameRequest() {
    final requested = _vm.outlinerRenamingId;
    if (requested == _editingId) return;
    _editingId = requested;
    _renameHadFocus = false;
    if (requested == null) return;
    final node = _vm.actors.where((a) => a.id == requested).firstOrNull;
    _renameController.text = node?.name ?? '';
    _renameController.selection = TextSelection(baseOffset: 0, extentOffset: _renameController.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingId == requested) _renameFocusNode.requestFocus();
    });
  }

  void _onRenameFocusChanged() {
    if (_renameFocusNode.hasFocus) {
      _renameHadFocus = true;
    } else if (_renameHadFocus && _editingId != null) {
      _commitRename();
    }
  }

  void _commitRename() {
    final id = _editingId;
    if (id == null) return;
    final name = _renameController.text.trim();
    final node = _vm.actors.where((a) => a.id == id).firstOrNull;
    if (node != null && name.isNotEmpty && name != node.name) {
      _vm.renameActorWithTransaction(id, name);
    }
    _vm.endOutlinerRename();
  }

  // --- Drag and drop -------------------------------------------------------

  List<String> _idsFor(EditorActorNode node) =>
      _vm.selectedActorIds.contains(node.id) ? _vm.selectedActorIds.toList() : [node.id];

  bool _canDropOn(_OutlinerDrag drag, EditorActorNode target) => target.type == 'Folder'
      ? drag.ids.any((id) => _vm.canMoveToFolder(id, target.id))
      : drag.ids.any((id) => _vm.canAttachToActor(id, target.id));

  void _dropOn(_OutlinerDrag drag, EditorActorNode target) {
    _cancelHoverExpand();
    if (target.type == 'Folder') {
      _vm.moveToFolder(drag.ids, target.id);
    } else {
      _vm.attachToActor(drag.ids, target.id);
    }
  }

  void _scheduleHoverExpand(EditorActorNode node) {
    if (node.type != 'Folder' || _vm.isOutlinerExpanded(node.id) || _hoverExpandId == node.id) return;
    _cancelHoverExpand();
    _hoverExpandId = node.id;
    _hoverExpandTimer = Timer(_hoverExpandDelay, () {
      if (mounted && _hoverExpandId == node.id) _vm.setOutlinerExpanded(node.id, true);
      _hoverExpandId = null;
    });
  }

  void _cancelHoverExpand([String? onlyFor]) {
    if (onlyFor != null && _hoverExpandId != onlyFor) return;
    _hoverExpandTimer?.cancel();
    _hoverExpandTimer = null;
    _hoverExpandId = null;
  }

  /// Where a folder that wraps [ids] is created: their shared parent folder,
  /// else the root.
  String? _sharedParentFolder(List<String> ids) {
    final parents = ids.map((id) => _vm.actors.where((a) => a.id == id).firstOrNull?.parentId).toSet();
    if (parents.length != 1 || parents.single == null) return null;
    final parent = _vm.actors.where((a) => a.id == parents.single).firstOrNull;
    return parent?.type == 'Folder' ? parent!.id : null;
  }

  // --- Tree ----------------------------------------------------------------

  List<_FlattenedNode> _buildFlatList() {
    final flat = <_FlattenedNode>[];
    void visit(EditorActorNode node, int depth) {
      final children = _vm.outlinerChildrenOf(node.id);
      flat.add(_FlattenedNode(node, depth, children.isNotEmpty || node.type == 'Folder', children.length));
      if (_vm.isOutlinerExpanded(node.id)) {
        for (final child in children) {
          visit(child, depth + 1);
        }
      }
    }

    for (final root in _vm.outlinerChildrenOf(null)) {
      visit(root, 0);
    }
    return flat;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _vm, builder: (context, _) => _buildOutliner(context));
  }

  Widget _buildOutliner(BuildContext context) {
    final vm = _vm;
    _syncRenameRequest();

    final flatNodes = _filterQuery.isEmpty
        ? _buildFlatList()
        : vm.actors
            .where((a) => a.name.toLowerCase().contains(_filterQuery.toLowerCase()))
            .map((a) => _FlattenedNode(a, 0, false, 0))
            .toList();

    final focusId = vm.outlinerRenamingId ?? vm.selectedActorId;
    if (focusId != _lastScrolledTo) {
      _lastScrolledTo = focusId;
      if (focusId != null) _scrollRowIntoView(focusId, flatNodes);
    }

    return Column(
      children: [
        // Header
        Container(
          // `h-7 px-2 bg-[oklch(0.105 0 0)]` in the prototype's OutlinerPanel.
          height: EditorDensity.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
          color: EditorColors.cardHeader,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'WORLD OUTLINER',
                  // `text-[10px] font-semibold uppercase tracking-widest
                  //  text-muted-foreground`.
                  style: EditorTypography.panelHeading,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _headerIcon(
                key: const ValueKey('outliner_new_folder'),
                icon: LucideIcons.folderPlus,
                tooltip: 'New Folder',
                onPressed: () => vm.createFolderFromSelection(),
              ),
              _headerIcon(
                key: const ValueKey('outliner_expand_all'),
                icon: LucideIcons.chevronsUpDown,
                tooltip: 'Expand All',
                onPressed: () => vm.expandAllInOutliner(),
              ),
              _headerIcon(
                key: const ValueKey('outliner_collapse_all'),
                icon: LucideIcons.chevronsDownUp,
                tooltip: 'Collapse All',
                onPressed: () => vm.collapseAllInOutliner(),
              ),
              SizedBox(height: EditorDensity.chipHeight, child: GhostButton(
                key: const ValueKey('outliner_add_actor'),
                density: EditorDensity.chipButton,
                alignment: Alignment.center,
                onPressed: () => _showAddActorDialog(context, vm),
                child: const Row(
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: EditorColors.primary),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(fontSize: EditorTypography.labelSize, color: EditorColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            ],
          ),
        ),

        // Search Field
        // `px-2 py-1.5 border-b bg-[oklch(0.1 0 0)]` with an `h-5.5` box.
        Container(
          color: EditorColors.rail,
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter, vertical: 6),
          child: Container(
            height: EditorDensity.compactRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: EditorColors.background,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: EditorColors.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _filterQuery = v),
              style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
              placeholder: const Text('Search actors...', style: TextStyle(fontSize: 10)),
            ),
          ),
        ),

        // Actor tree. Content-browser assets dropped anywhere on it spawn at
        // the root; outliner rows dropped on the empty area below the rows
        // move to the root.
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data.startsWith('asset:'),
            onAcceptWithDetails: (details) => vm.spawnNewActor(details.data.split(':').last),
            builder: (context, candidateData, rejectedData) {
              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildActorRow(flatNodes[index], flatNodes),
                      childCount: flatNodes.length,
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: _buildEmptyArea(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Scrolls the list (rows are built lazily and all [EditorDensity.rowHeight]
  /// tall) just enough to show [id]'s row, after this frame lays it out.
  void _scrollRowIntoView(String id, List<_FlattenedNode> flat) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final index = flat.indexWhere((f) => f.node.id == id);
      if (index < 0) return;
      const extent = EditorDensity.rowHeight;
      final top = index * extent;
      final position = _scrollController.position;
      double? target;
      if (top < position.pixels) {
        target = top;
      } else if (top + extent > position.pixels + position.viewportDimension) {
        target = top + extent - position.viewportDimension;
      }
      if (target != null) {
        _scrollController.jumpTo(target.clamp(position.minScrollExtent, position.maxScrollExtent));
      }
    });
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

  /// The space below the rows: a drop here moves rows to the root, a click
  /// clears the selection, and its context menu creates folders.
  Widget _buildEmptyArea() {
    final vm = _vm;
    return DragTarget<_OutlinerDrag>(
      onWillAcceptWithDetails: (details) => details.data.ids.any((id) => vm.canMoveToFolder(id, null)),
      onAcceptWithDetails: (details) => vm.moveToFolder(details.data.ids, null),
      builder: (context, candidateData, rejectedData) {
        return EditorContextMenu(
          items: [
            MenuButton(
              leading: const Icon(LucideIcons.folderPlus, size: 14),
              onPressed: (ctx) {
                _selectionAnchorId = null;
                vm.clearSelection();
                vm.createFolder();
              },
              child: const Text('New Folder', style: TextStyle(fontSize: 10)),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.chevronsUpDown, size: 14),
              onPressed: (ctx) => vm.expandAllInOutliner(),
              child: const Text('Expand All', style: TextStyle(fontSize: 10)),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.chevronsDownUp, size: 14),
              onPressed: (ctx) => vm.collapseAllInOutliner(),
              child: const Text('Collapse All', style: TextStyle(fontSize: 10)),
            ),
          ],
          child: GestureDetector(
            key: const ValueKey('outliner_empty_area'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _lastTapId = null;
              _lastTapAt = null;
              _selectionAnchorId = null;
              vm.clearSelection();
            },
            child: Container(
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty ? EditorColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                border: candidateData.isNotEmpty
                    ? const Border(top: BorderSide(color: EditorColors.primary, width: 1))
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

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

    return Container(
      // `h-6 px-2` with `paddingLeft: 8 + depth * 14` and, when selected,
      // `bg-primary/20 border-l-2 border-primary`.
      height: EditorDensity.rowHeight,
      padding: EdgeInsets.only(
        left: EditorDensity.gutter + (fnode.depth * EditorDensity.indentStep),
        right: EditorDensity.gutter,
      ),
      decoration: BoxDecoration(
        color: isDropTarget
            ? EditorColors.primary.withValues(alpha: 0.18)
            : (isSelected ? EditorColors.selectionBg : Colors.transparent),
        border: isDropTarget
            ? Border.all(color: EditorColors.primary, width: 1)
            : (isSelected
                ? const Border(left: BorderSide(color: EditorColors.primary, width: EditorDensity.selectionBarWidth))
                : null),
      ),
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
                color: EditorColors.mutedForeground,
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
              color: node.isVisible ? EditorColors.mutedForeground : EditorColors.destructive,
            ),
          ),
          // Lock toggle
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () => vm.setActorLockedWithTransaction(node.id, !node.isLocked),
            child: Icon(
              node.isLocked ? LucideIcons.lock : LucideIcons.lockOpen,
              size: 11,
              color: node.isLocked ? EditorColors.warning : EditorColors.border,
            ),
          ),
          const SizedBox(width: 4),

          Icon(
            isFolder ? (isExpanded ? LucideIcons.folderOpen : LucideIcons.folder) : _getIconForType(node.type),
            size: 12,
            color: _getColorForType(node.type),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? EditorColors.primary
                          : (node.isVisible ? EditorColors.foreground : EditorColors.mutedForeground),
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
            style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  /// The absolute path of the asset file [node] is placed from, when it is
  /// on disk: its mesh, else a placed Blueprint's class `.lmas`.
  String? _assetFileOf(EditorActorNode node) {
    final ref = node.meshAssetPath ?? node.blueprintClass;
    if (ref == null || ref.isEmpty) return null;
    final path = FileReveal.resolve(_vm.projectDirPath, ref);
    return File(path).existsSync() ? path : null;
  }

  List<MenuItem> _rowMenu(EditorActorNode node, List<String> ids) {
    final vm = _vm;
    final isFolder = node.type == 'Folder';
    final targets = vm.folderPaths.where((f) => ids.any((id) => vm.canMoveToFolder(id, f.folder.id))).toList();
    final canMoveToRoot = ids.any((id) => vm.canMoveToFolder(id, null));

    return [
      MenuButton(
        leading: const Icon(LucideIcons.pencil, size: 14),
        trailing: const Text('F2', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        onPressed: (ctx) => vm.requestOutlinerRename(node.id),
        child: const Text('Rename', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.folderPlus, size: 14),
        onPressed: (ctx) => isFolder
            ? vm.createFolder(parentFolderId: node.id)
            : vm.createFolder(parentFolderId: _sharedParentFolder(ids), wrapIds: ids),
        child: Text(isFolder ? 'New Subfolder' : 'New Folder', style: const TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.folderInput, size: 14),
        subMenu: [
          if (canMoveToRoot)
            MenuButton(
              onPressed: (ctx) => vm.moveToFolder(ids, null),
              child: const Text('(Root)', style: TextStyle(fontSize: 10)),
            ),
          for (final target in targets)
            MenuButton(
              leading: const Icon(LucideIcons.folder, size: 12),
              onPressed: (ctx) => vm.moveToFolder(ids, target.folder.id),
              child: Text(target.path, style: const TextStyle(fontSize: 10)),
            ),
          if (canMoveToRoot || targets.isNotEmpty) const MenuDivider(),
          MenuButton(
            leading: const Icon(LucideIcons.folderPlus, size: 12),
            onPressed: (ctx) => vm.createFolder(parentFolderId: _sharedParentFolder(ids), wrapIds: ids),
            child: const Text('New Folder…', style: TextStyle(fontSize: 10)),
          ),
        ],
        child: const Text('Move to Folder', style: TextStyle(fontSize: 10)),
      ),
      if (!isFolder) ...[
        MenuButton(
          leading: const Icon(LucideIcons.copy, size: 14),
          onPressed: (ctx) => vm.duplicateSelectedActor(),
          child: const Text('Duplicate', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.locate, size: 14, color: EditorColors.accent),
          onPressed: (ctx) => vm.focusCameraOnActor(node),
          child: const Text('Focus Camera on Actor', style: TextStyle(fontSize: 10)),
        ),
        // The file the actor is placed from (its mesh, or a Blueprint's
        // class asset) in the platform file manager.
        if (_assetFileOf(node) case final asset?)
          MenuButton(
            key: const ValueKey('outliner_menu_reveal_asset'),
            leading: const Icon(LucideIcons.folderSearch, size: 14),
            onPressed: (ctx) => FileReveal.reveal(asset),
            child: Text(FileReveal.menuLabel(subject: 'Asset'), style: const TextStyle(fontSize: 10)),
          ),
      ],
      if (node.type == 'Environment' || node.type == 'Light' || node.type == 'DirectionalLight')
        MenuButton(
          leading: const Icon(LucideIcons.sun, size: 14, color: EditorColors.warning),
          onPressed: (ctx) => vm.commands.execute('tools.environmentLighting'),
          child: const Text('Open Environment Mixer', style: TextStyle(fontSize: 10)),
        ),
      if (isFolder) ...[
        const MenuDivider(),
        MenuButton(
          leading: const Icon(LucideIcons.chevronsUpDown, size: 14),
          onPressed: (ctx) => vm.expandAllInOutliner(under: node.id),
          child: const Text('Expand All Inside', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.chevronsDownUp, size: 14),
          onPressed: (ctx) => vm.collapseAllInOutliner(under: node.id),
          child: const Text('Collapse All Inside', style: TextStyle(fontSize: 10)),
        ),
      ],
      const MenuDivider(),
      MenuButton(
        leading: const Icon(LucideIcons.trash2, size: 14, color: EditorColors.destructive),
        onPressed: (ctx) {
          if (isFolder) {
            _showFolderDeleteDialog(context, vm, node.id);
          } else {
            vm.deleteActorSubtreeWithTransaction(node.id);
          }
        },
        child: Text(
          isFolder ? 'Delete Folder' : 'Delete Actor',
          style: const TextStyle(fontSize: 10, color: EditorColors.destructive),
        ),
      ),
    ];
  }

  void _showAddActorDialog(BuildContext context, EditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text('Spawn New Actor Into Scene'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final category in EditorActorCatalog.categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  for (final type in EditorActorCatalog.inCategory(category))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: Builder(
                          builder: (context) {
                            final refusal = vm.spawnRefusalFor(type.id);
                            return OutlineButton(
                              key: ValueKey('spawn_actor_${type.id}'),
                              onPressed: refusal != null
                                  ? null
                                  : () {
                                      vm.spawnNewActor(type.id, parentId: vm.selectedActorId);
                                      Navigator.of(context).pop();
                                    },
                              child: Row(
                                children: [
                                  Icon(type.icon, size: 14, color: type.color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(type.label, style: const TextStyle(fontSize: 10)),
                                        Text(
                                          refusal ?? type.description,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: refusal != null ? EditorColors.logWarning : EditorColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _showFolderDeleteDialog(BuildContext context, EditorViewModel vm, String id) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text('Do you want to delete the contents as well, or keep the children?'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 10)),
          ),
          OutlineButton(
            onPressed: () {
              vm.deleteActorSubtreeWithTransaction(id, keepChildren: true);
              Navigator.of(context).pop();
            },
            child: const Text('Keep Children', style: TextStyle(fontSize: 10)),
          ),
          DestructiveButton(
            onPressed: () {
              vm.deleteActorSubtreeWithTransaction(id, keepChildren: false);
              Navigator.of(context).pop();
            },
            child: const Text('Delete Contents', style: TextStyle(fontSize: 10)),
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

class _FlattenedNode {
  final EditorActorNode node;
  final int depth;

  /// Whether the row shows an expand chevron: folders always, other nodes
  /// when they have children.
  final bool expandable;
  final int childCount;
  _FlattenedNode(this.node, this.depth, this.expandable, this.childCount);
}
