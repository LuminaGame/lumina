import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/import_jobs_view_model.dart';

/// The background import's progress, as a
/// bottom-right import notification: `Importing 12 / 51 · file`, the batch's
/// bar, elapsed and remaining time, Cancel, an expandable per-file list and,
/// once finished, the outcome with "Show errors". Collapses to
/// [ImportProgressChip] in the status bar; a batch that imported everything
/// dismisses itself after [ImportJobsViewModel.autoDismissAfter].
class ImportProgressPanel extends StatelessWidget {
  const ImportProgressPanel({super.key, required this.jobs, required this.onShowErrors});

  final ImportJobsViewModel jobs;

  /// Opens the Output Log filtered to errors.
  final VoidCallback onShowErrors;

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: jobs,
      builder: (context, _) {
        if (!jobs.visible || jobs.collapsed) return const SizedBox.shrink();
        final running = jobs.isRunning;
        return SizedBox(
          key: const ValueKey('import_progress_panel'),
          width: width,
          child: Card(
            padding: const EdgeInsets.all(10),
            borderRadius: BorderRadius.circular(6),
            borderColor: EditorColors.borderSolid,
            fillColor: EditorColors.popover,
            filled: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      running
                          ? LucideIcons.download
                          : jobs.failed > 0
                              ? LucideIcons.circleAlert
                              : LucideIcons.circleCheck,
                      size: 13,
                      color: running
                          ? EditorColors.primary
                          : jobs.failed > 0
                              ? EditorColors.logError
                              : EditorColors.logSuccess,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        jobs.headline,
                        key: const ValueKey('import_progress_headline'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                      ),
                    ),
                    _iconButton(
                      key: const ValueKey('import_progress_collapse'),
                      icon: running ? LucideIcons.chevronDown : LucideIcons.x,
                      tooltip: running ? 'Minimize to the status bar' : 'Dismiss',
                      onPressed: running ? jobs.collapse : jobs.dismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Progress(key: const ValueKey('import_progress_bar'), progress: jobs.overallFraction.clamp(0.0, 1.0)),
                const SizedBox(height: 6),
                Text(
                  _timing(),
                  key: const ValueKey('import_progress_timing'),
                  style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
                ),
                if (running && jobs.current != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    jobs.current!.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                  ),
                ],
                if (jobs.showDetails) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: ListView(
                        key: const ValueKey('import_progress_files'),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [for (final row in jobs.rows) _fileRow(row)],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    GhostButton(
                      key: const ValueKey('import_progress_details'),
                      density: ButtonDensity.compact,
                      onPressed: jobs.toggleDetails,
                      child: Text(jobs.showDetails ? 'Hide files' : 'Show files (${jobs.total})',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    const Spacer(),
                    if (jobs.failed > 0) ...[
                      OutlineButton(
                        key: const ValueKey('import_progress_show_errors'),
                        density: ButtonDensity.compact,
                        onPressed: onShowErrors,
                        child: Text('Show errors (${jobs.failed})', style: const TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (running)
                      DestructiveButton(
                        key: const ValueKey('import_progress_cancel'),
                        density: ButtonDensity.compact,
                        onPressed: jobs.isCancelling ? null : jobs.cancel,
                        child: Text(jobs.isCancelling ? 'Cancelling…' : 'Cancel', style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timing() {
    final parts = <String>['${jobs.finished} / ${jobs.total} finished', 'elapsed ${_duration(jobs.elapsed)}'];
    final remaining = jobs.remaining;
    if (remaining != null) parts.add('~${_duration(remaining)} left');
    if (!jobs.isRunning && jobs.cancelled > 0) parts.add('${jobs.cancelled} cancelled');
    return parts.join('  ·  ');
  }

  static String _duration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '${(d.inMilliseconds / 1000).toStringAsFixed(s < 10 ? 1 : 0)} s';
    return '${s ~/ 60} min ${(s % 60).toString().padLeft(2, '0')} s';
  }

  Widget _fileRow(ImportProgress row) {
    final (IconData icon, Color color) = switch (row.stage) {
      ImportStage.queued => (LucideIcons.clock, EditorColors.mutedForeground),
      ImportStage.converting => (LucideIcons.cog, EditorColors.primary),
      ImportStage.writing => (LucideIcons.hardDriveDownload, EditorColors.primary),
      ImportStage.thumbnail => (LucideIcons.image, EditorColors.accent),
      ImportStage.done => (LucideIcons.circleCheck, EditorColors.logSuccess),
      ImportStage.failed => (LucideIcons.circleX, EditorColors.logError),
      ImportStage.cancelled => (LucideIcons.ban, EditorColors.mutedForeground),
    };
    final status = row.stage == ImportStage.failed ? 'failed: ${row.error ?? ''}' : row.stage.name;
    return Padding(
      key: ValueKey('import_progress_file_${row.index}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(row.fileName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: color)),
          ),
        ],
      ),
    );
  }

  static Widget _iconButton({required Key key, required IconData icon, required String tooltip, required VoidCallback onPressed}) {
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
}

/// The status-bar chip a collapsed [ImportProgressPanel] leaves behind
/// (`Importing 12/51`, with a small bar); clicking it opens the panel.
class ImportProgressChip extends StatelessWidget {
  const ImportProgressChip({super.key, required this.jobs});

  final ImportJobsViewModel jobs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: jobs,
      builder: (context, _) {
        final show = jobs.isRunning ? jobs.collapsed || !jobs.visible : jobs.visible && jobs.collapsed;
        if (!show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            key: const ValueKey('status_bar_import_chip'),
            behavior: HitTestBehavior.opaque,
            onTap: jobs.expand,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(jobs.isRunning ? LucideIcons.download : LucideIcons.circleCheck,
                    size: 10, color: jobs.failed > 0 ? EditorColors.logError : EditorColors.primary),
                const SizedBox(width: 4),
                Text(jobs.chipLabel,
                    style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
                if (jobs.isRunning) ...[
                  const SizedBox(width: 6),
                  SizedBox(width: 60, child: Progress(progress: jobs.overallFraction.clamp(0.0, 1.0))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
