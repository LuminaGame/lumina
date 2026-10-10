import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

part 'outliner_widget/state.dart';
part 'outliner_widget/rename_and_drop.dart';
part 'outliner_widget/rows.dart';
part 'outliner_widget/row_menu.dart';

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

class _OutlinerWidgetState extends _OutlinerWidgetStateBase with _OutlinerRenameAndDrop, _OutlinerRowMenu, _OutlinerRows {
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
