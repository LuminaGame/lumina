import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/pose_search_database_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/pose_search_database_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_fields.dart';

/// The database's clips (one row each: name, Loop / Mirror / Enabled, tags,
/// remove) above the build state and statistics of its feature cache.
class PoseSearchDatabaseClipList extends StatelessWidget {
  final PoseSearchDatabaseEditorViewModel viewModel;

  const PoseSearchDatabaseClipList({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final clips = vm.document.clips;
    return Container(
      color: EditorColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 26,
            color: EditorColors.cardHeader,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(
                child: Text('DATABASE CLIPS (${clips.length})',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              ),
              const SizedBox(width: 60, child: Text('Loop', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
              const SizedBox(width: 60, child: Text('Mirror', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
              const SizedBox(width: 60, child: Text('Use', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
              const SizedBox(width: 28),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: clips.isEmpty
                ? const Center(
                    child: Text('Add clips from the list on the left.',
                        style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)))
                : ListView.builder(
                    itemCount: clips.length,
                    itemBuilder: (context, i) {
                      final c = clips[i];
                      final selected = vm.selectedClip == i;
                      return GestureDetector(
                        key: ValueKey('psd_clip_$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => vm.selectClip(i),
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          color: selected ? EditorColors.selectionBg : null,
                          child: Row(children: [
                            const Icon(LucideIcons.clapperboard, size: 11, color: EditorColors.assetTypeAnimation),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.tags.isEmpty ? c.clip : '${c.clip}  [${c.tags.join(', ')}]',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: c.enabled && vm.meshClips.contains(c.clip)
                                        ? EditorColors.foreground
                                        : EditorColors.mutedForeground),
                              ),
                            ),
                            SizedBox(
                                width: 60,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: poseSearchCheck('psd_clip_loop_$i', '', c.loop,
                                        (v) => vm.updateClip(i, (x) => x.copyWith(loop: v))))),
                            SizedBox(
                                width: 60,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: poseSearchCheck('psd_clip_mirror_$i', '', c.mirror,
                                        (v) => vm.updateClip(i, (x) => x.copyWith(mirror: v))))),
                            SizedBox(
                                width: 60,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: poseSearchCheck('psd_clip_enabled_$i', '', c.enabled,
                                        (v) => vm.updateClip(i, (x) => x.copyWith(enabled: v))))),
                            GhostButton(
                              key: ValueKey('psd_clip_remove_$i'),
                              size: ButtonSize.small,
                              density: ButtonDensity.icon,
                              onPressed: () => vm.removeClip(i),
                              child: const Icon(LucideIcons.x, size: 11),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _stats(vm),
        ],
      ),
    );
  }

  Widget _stats(PoseSearchDatabaseEditorViewModel vm) {
    final r = vm.report;
    final state = switch (vm.cacheState) {
      PoseSearchCacheState.upToDate => ('Feature cache up to date', const Color(0xFF4CAF50)),
      PoseSearchCacheState.stale => ('Feature cache out of date: Build', const Color(0xFFFFB300)),
      PoseSearchCacheState.missing => ('Not built yet: Build', const Color(0xFFFFB300)),
    };
    const muted = TextStyle(fontSize: 10, color: EditorColors.mutedForeground);
    return Container(
      key: const ValueKey('psd_stats'),
      color: EditorColors.card,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(vm.isBuilding ? LucideIcons.loader : LucideIcons.database, size: 12, color: state.$2),
            const SizedBox(width: 6),
            Text(vm.isBuilding ? 'Building on a background isolate…' : state.$1,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: state.$2)),
          ]),
          if (r != null) ...[
            const SizedBox(height: 4),
            Text(
              key: const ValueKey('psd_stats_line'),
              '${r.stats.clips} clips · ${r.stats.rows} frames (${r.stats.mirroredRows} mirrored) · ${r.stats.dimensions} features · '
              'built in ${(r.stats.buildMicroseconds / 1000).toStringAsFixed(0)} ms · cache ${(r.cacheBytes / 1024).toStringAsFixed(0)} KiB · '
              'search ${r.meanSearchMicroseconds.toStringAsFixed(0)} µs mean, ${r.maxSearchMicroseconds} µs max',
              style: muted,
            ),
            if (r.stats.missingClips.isNotEmpty)
              Text('Not in the mesh: ${r.stats.missingClips.join(', ')}', style: muted),
            if (r.stats.missingBones.isNotEmpty) Text('Bones the mesh lacks: ${r.stats.missingBones.join(', ')}', style: muted),
            if (r.stats.staticRootClips.isNotEmpty)
              Text('No root motion (in place): ${r.stats.staticRootClips.join(', ')}', overflow: TextOverflow.ellipsis, style: muted),
          ],
          if (vm.error != null) Text(vm.error!, style: const TextStyle(fontSize: 10, color: Color(0xFFEF5350))),
        ],
      ),
    );
  }
}
