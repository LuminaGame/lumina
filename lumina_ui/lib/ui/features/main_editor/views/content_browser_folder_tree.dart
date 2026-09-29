import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart';
import 'package:lumina/lumina.dart' show RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/services/content_folders.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../core/widgets/editor_context_menu.dart';
import '../../source_control/views/source_control_badge.dart';
import '../view_models/editor_view_model.dart';
import 'content_browser_folder_tile.dart';

/// One visible row of the Sources tree.
class FolderTreeRow {
  final String path;
  final int depth;
  final bool hasChildren;
  final bool expanded;

  const FolderTreeRow({required this.path, required this.depth, required this.hasChildren, required this.expanded});
}

/// Flattens [folders] into the rows the Sources tree shows: every root (a
/// folder whose parent is not itself listed — `contents`, plugin content
/// roots) in the given order, then, depth first, the children of each
/// folder in [expanded], sorted by name. Collapsed subtrees are skipped
/// entirely, so the cost follows the visible rows, not the project size.
List<FolderTreeRow> flattenFolderTree(Iterable<String> folders, Set<String> expanded) {
  final all = folders.toList();
  final known = all.toSet();
  final children = <String, List<String>>{};
  final roots = <String>[];
  for (final f in all) {
    final parent = ContentFolders.parentOf(f);
    if (parent.isNotEmpty && parent != f && known.contains(parent)) {
      (children[parent] ??= []).add(f);
    } else if (!roots.contains(f)) {
      roots.add(f);
    }
  }
  String leaf(String p) => p.split('/').last.toLowerCase();
  for (final list in children.values) {
    list.sort((a, b) => leaf(a).compareTo(leaf(b)));
  }
  final rows = <FolderTreeRow>[];
  void visit(String path, int depth) {
    final kids = children[path];
    final open = expanded.contains(path);
    rows.add(FolderTreeRow(path: path, depth: depth, hasChildren: kids != null, expanded: open && kids != null));
    if (open && kids != null) {
      for (final k in kids) {
        visit(k, depth + 1);
      }
    }
  }

  for (final r in roots) {
    visit(r, 0);
  }
  return rows;
}

/// A folder row of the Sources rail: chevron (tree rows only), folder icon,
/// name, the aggregated source-control badge, the shared folder context menu,
/// and a drop target that moves a dragged asset into the folder.
class ContentFolderRow extends StatelessWidget {
  final String path;
  final EditorViewModel? vm;
  final bool selected;
  final VoidCallback onTap;

  /// Tree rows only: indent level and the chevron. [onToggle] is null for a
  /// folder without subfolders (a spacer keeps the names aligned); with
  /// [showChevronSlot] false (Favorites) there is no chevron column at all.
  final int depth;
  final bool showChevronSlot;
  final bool expanded;
  final VoidCallback? onToggle;

  const ContentFolderRow({
    super.key,
    required this.path,
    required this.vm,
    required this.selected,
    required this.onTap,
    this.depth = 0,
    this.showChevronSlot = false,
    this.expanded = false,
    this.onToggle,
  });

  static const double _chevronSize = 11;

  @override
  Widget build(BuildContext context) {
    final vm = this.vm;
    return EditorContextMenu(
      items: vm == null ? const [] : contentFolderMenuItems(context, vm, path),
      child: DragTarget<RealAssetInfo>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) => vm?.moveAssetToFolder(details.data, path),
        builder: (context, candidateData, rejectedData) {
          final isHover = candidateData.isNotEmpty;
          final active = isHover || selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.only(left: 6 + depth * EditorDensity.indentStep, right: 6, top: 3, bottom: 3),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isHover
                    ? EditorColors.primary.withValues(alpha: 0.35)
                    : (selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent),
                borderRadius: BorderRadius.circular(2),
                border: isHover ? Border.all(color: EditorColors.primary) : null,
              ),
              child: Row(
                children: [
                  if (showChevronSlot) ...[
                    if (onToggle != null)
                      GestureDetector(
                        key: ValueKey('source_folder_chevron_$path'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggle,
                        child: Icon(
                          expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                          size: _chevronSize,
                          color: EditorColors.mutedForeground,
                        ),
                      )
                    else
                      const SizedBox(width: _chevronSize),
                    const SizedBox(width: 2),
                  ],
                  Icon(
                    expanded ? LucideIcons.folderOpen : LucideIcons.folder,
                    size: 11,
                    color: active ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      path.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => path),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? EditorColors.primary : EditorColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The folder badge aggregates every descendant's git state,
                  // so a collapsed folder still shows a change inside it.
                  if (vm != null)
                    SourceControlBadge(state: vm.sourceControl.folderState(path), path: 'folder:$path', size: 11),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The Content Browser's Sources rail: the [before]
/// widgets (Favorites, the SOURCES heading), the collapsible folder tree —
/// only its visible rows are built — and the [after] widgets (Collections,
/// Smart Views), in one scroll view. A click on a tree row gives the tree
/// the keyboard: Right expands the selected folder, Left collapses it, and
/// Left on a collapsed folder selects its parent.
class ContentBrowserSourcesRail extends StatefulWidget {
  final EditorViewModel? vm;
  final List<Widget> before;
  final List<Widget> after;

  const ContentBrowserSourcesRail({super.key, required this.vm, this.before = const [], this.after = const []});

  @override
  State<ContentBrowserSourcesRail> createState() => _ContentBrowserSourcesRailState();
}

class _ContentBrowserSourcesRailState extends State<ContentBrowserSourcesRail> {
  final FocusNode _treeFocus = FocusNode(debugLabel: 'ContentBrowserSourcesTree');
  String? _lastTapPath;
  DateTime? _lastTapAt;

  /// The rows of the last build, for the arrow keys.
  List<FolderTreeRow> _rows = const [];

  @override
  void dispose() {
    _treeFocus.dispose();
    super.dispose();
  }

  bool _isSelected(EditorViewModel vm, String path) =>
      vm.selectedFolder == path && !vm.showRecentlyModified && vm.activeCollection == null;

  void _select(EditorViewModel vm, String path) {
    vm.showRecentlyModified = false;
    vm.activeCollection = null;
    vm.selectedFolder = path;
  }

  /// Double-click is detected here rather than with onDoubleTap, which would
  /// hold every single click for the double-tap timeout (as the Outliner).
  void _onRowTap(EditorViewModel vm, FolderTreeRow row) {
    final now = DateTime.now();
    final isDouble = _lastTapPath == row.path && _lastTapAt != null && now.difference(_lastTapAt!) <= kDoubleTapTimeout;
    _lastTapPath = isDouble ? null : row.path;
    _lastTapAt = isDouble ? null : now;
    _treeFocus.requestFocus();
    if (isDouble) {
      if (row.hasChildren) vm.toggleFolderExpanded(row.path);
      return;
    }
    _select(vm, row.path);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final vm = widget.vm;
    if (vm == null || (event is! KeyDownEvent && event is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final left = event.logicalKey == LogicalKeyboardKey.arrowLeft;
    final right = event.logicalKey == LogicalKeyboardKey.arrowRight;
    if (!left && !right) return KeyEventResult.ignored;
    final selected = vm.selectedFolder;
    final row = _rows.where((r) => r.path == selected).firstOrNull;
    if (row == null || vm.activeCollection != null || vm.showRecentlyModified) return KeyEventResult.ignored;
    if (right) {
      if (row.hasChildren && !row.expanded) vm.setFolderExpanded(row.path, true);
      return KeyEventResult.handled;
    }
    if (row.expanded) {
      vm.setFolderExpanded(row.path, false);
    } else {
      final parent = ContentFolders.parentOf(row.path);
      if (_rows.any((r) => r.path == parent)) _select(vm, parent);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    _rows = vm == null ? const [] : flattenFolderTree(vm.sourceFolders, vm.layoutState.expandedFolders);
    final rows = _rows;
    return Focus(
      focusNode: _treeFocus,
      onKeyEvent: _onKey,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 8),
            sliver: SliverList(delegate: SliverChildListDelegate(widget.before)),
          ),
          if (vm != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final row = rows[i];
                    return ContentFolderRow(
                      key: ValueKey('source_folder_row_${row.path}'),
                      path: row.path,
                      vm: vm,
                      selected: _isSelected(vm, row.path),
                      depth: row.depth,
                      showChevronSlot: true,
                      expanded: row.expanded,
                      onToggle: row.hasChildren ? () => vm.toggleFolderExpanded(row.path) : null,
                      onTap: () => _onRowTap(vm, row),
                    );
                  },
                  childCount: rows.length,
                  findChildIndexCallback: (key) {
                    final value = (key as ValueKey<String>).value.substring('source_folder_row_'.length);
                    final i = rows.indexWhere((r) => r.path == value);
                    return i < 0 ? null : i;
                  },
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            sliver: SliverList(delegate: SliverChildListDelegate(widget.after)),
          ),
        ],
      ),
    );
  }
}
