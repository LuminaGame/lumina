import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';

void showHistoryDialog(BuildContext context, SourceControlViewModel viewModel, String path) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (c) => AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.history, size: 14, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('History · $path', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(width: 680, height: 380, child: HistoryDialog(viewModel: viewModel, path: path)),
      actions: [OutlineButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close'))],
    ),
  );
}

/// Human-readable "3 minutes ago" style label.
String relativeDateLabel(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
  return '${(diff.inDays / 365).floor()} y ago';
}

/// Per-asset commit list from `git log --follow` (renames followed).
class HistoryDialog extends StatefulWidget {
  final SourceControlViewModel viewModel;
  final String path;

  const HistoryDialog({super.key, required this.viewModel, required this.path});

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  late Future<List<GitLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.viewModel.history(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GitLogEntry>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: Text('Loading history…', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)));
        }
        final entries = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: EditorColors.card,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border),
                ),
                child: entries.isEmpty
                    ? const Center(
                        child: Text('No commits touch this file yet.',
                            style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(6),
                        itemCount: entries.length,
                        itemBuilder: (context, i) => _HistoryRow(entry: entries[i], index: i),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.gitBranch, size: 11, color: EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  '${entries.length} commit(s) · renames are followed (git log --follow)',
                  style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final GitLogEntry entry;
  final int index;

  const _HistoryRow({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('sc_history_row_$index'),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: EditorColors.border))),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              entry.abbrevHash,
              style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.primary),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(entry.author, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 90,
            child: Tooltip(
              tooltip: (_) => TooltipContainer(child: Text(entry.date.toIso8601String())),
              child: Text(
                relativeDateLabel(entry.date),
                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
            ),
          ),
          Expanded(
            child: Text(entry.subject, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
