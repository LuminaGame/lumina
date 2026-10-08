import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/pose_search_database_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_fields.dart';

/// The target mesh's clips as a tree grouped by movement (Walk, Run, Stand,
/// …): a click adds a clip to the database or removes it, a group's "+"
/// adds the whole group, the filter narrows the tree and "Add matching"
/// adds every clip it shows.
class PoseSearchClipTree extends StatelessWidget {
  final PoseSearchDatabaseEditorViewModel viewModel;

  const PoseSearchClipTree({super.key, required this.viewModel});

  static const double rowHeight = 22;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final groups = vm.clipGroups;
    final rows = <Widget>[];
    for (final g in groups.entries) {
      final collapsed = vm.isCollapsed(g.key);
      final inDb = g.value.where(vm.contains).length;
      rows.add(_Row(
        key: ValueKey('psd_group_${g.key}'),
        depth: 0,
        onTap: () => vm.toggleGroup(g.key),
        children: [
          Icon(collapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 4),
          Icon(collapsed ? LucideIcons.folder : LucideIcons.folderOpen, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${g.key} ($inDb/${g.value.length})',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
          ),
          GhostButton(
            key: ValueKey('psd_group_add_${g.key}'),
            size: ButtonSize.small,
            density: ButtonDensity.icon,
            onPressed: inDb == g.value.length ? null : () => vm.addClips(g.value),
            child: const Icon(LucideIcons.plus, size: 11),
          ),
        ],
      ));
      if (collapsed) continue;
      for (final clip in g.value) {
        final added = vm.contains(clip);
        rows.add(_Row(
          key: ValueKey('psd_mesh_clip_$clip'),
          depth: 1,
          active: added,
          onTap: () => vm.toggleClip(clip),
          children: [
            Icon(added ? LucideIcons.squareCheck : LucideIcons.square,
                size: 12, color: added ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            const Icon(LucideIcons.clapperboard, size: 11, color: EditorColors.assetTypeAnimation),
            const SizedBox(width: 6),
            Expanded(
              child: Text(clip,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: added ? EditorColors.foreground : EditorColors.mutedForeground)),
            ),
          ],
        ));
      }
    }

    return Container(
      color: EditorColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: EditorColors.cardHeader,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('CLIPS OF ${vm.document.targetMesh.split('/').last.replaceAll('.lmas', '').toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                const SizedBox(height: 6),
                PoseSearchTextField(
                  key: const ValueKey('psd_filter'),
                  value: vm.filter,
                  placeholder: 'Filter clips (e.g. Walk_Start)',
                  onCommit: vm.setFilter,
                ),
                const SizedBox(height: 6),
                OutlineButton(
                  key: const ValueKey('psd_add_matching'),
                  size: ButtonSize.small,
                  onPressed: vm.filter.trim().isEmpty ? () => vm.addClips(vm.meshClips) : () => vm.addMatching(vm.filter),
                  child: Text(vm.filter.trim().isEmpty ? 'Add all clips' : 'Add matching', style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: vm.meshClips.isEmpty
                ? Center(
                    child: Text(vm.isLoading ? 'Reading clips…' : 'The target mesh has no clips',
                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)))
                : ListView(children: rows),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final int depth;
  final bool active;
  final VoidCallback onTap;
  final List<Widget> children;

  const _Row({super.key, required this.depth, required this.onTap, required this.children, this.active = false});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: PoseSearchClipTree.rowHeight,
            padding: EdgeInsets.only(left: 6.0 + widget.depth * 14.0, right: 4),
            color: widget.active ? EditorColors.selectionBg : (_hover ? EditorColors.rowHover : null),
            child: Row(children: widget.children),
          ),
        ),
      );
}
