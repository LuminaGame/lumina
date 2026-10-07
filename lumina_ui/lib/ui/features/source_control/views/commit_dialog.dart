import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/views/identity_form.dart';
import 'package:lumina_ui/ui/features/source_control/views/revert_dialog.dart';
import 'package:lumina_ui/ui/features/source_control/views/source_control_badge.dart';

/// Opens the changelist commit dialog. [preChecked] limits the initial
/// selection (Content Browser context-menu invocation pre-checks that asset).
void showCommitDialog(BuildContext context, SourceControlViewModel viewModel, {Set<String>? preChecked}) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (c) => AlertDialog(
      content: SizedBox(
        width: 780,
        height: 520,
        child: CommitDialog(
          viewModel: viewModel,
          preChecked: preChecked,
          onClose: () => Navigator.of(c).pop(),
        ),
      ),
    ),
  );
}

/// Changelist-style commit dialog: every changed file grouped under
/// `Assets (.lmas)` / `Levels` / `Generated code (lib/)` / `Project`, then by
/// folder (a folder with more than [ChangeFolderGroup.collapseThreshold]
/// changes starts collapsed; its header checks or unchecks all of it), a
/// filter field, a checkbox per row (default all checked), status chip,
/// path, diff summary (`+n −m` for text, `binary · old → new` for `.lmas`,
/// `new file · size` untracked; a spinner until it arrives), per-row Revert,
/// a validated commit-message box and a Commit button that stages exactly
/// the checked paths. The list is built lazily, so thousands of changes open
/// at once; a progress bar shows the status refresh, the summaries and the
/// commit.
class CommitDialog extends StatefulWidget {
  final SourceControlViewModel viewModel;
  final Set<String>? preChecked;
  final VoidCallback? onClose;

  const CommitDialog({super.key, required this.viewModel, this.preChecked, this.onClose});

  @override
  State<CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<CommitDialog> {
  final Set<String> _checked = {};
  final TextEditingController _message = TextEditingController();
  final TextEditingController _filter = TextEditingController();
  bool _committing = false;
  bool _seeded = false;

  /// Folder groups the user opened or closed (`<changelist>|<folder>` → open);
  /// the rest follow [ChangeFolderGroup.collapseThreshold].
  final Map<String, bool> _expanded = {};

  /// The flattened, lazily built list (headers + visible rows), rebuilt when
  /// the changes, the filter or a folder's open state change.
  List<_Item> _items = const [];
  int _itemsForChanges = -1;
  String _itemsForFilter = '';

  SourceControlViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.addListener(_onVm);
    _seedSelection();
    _livePaths = vm.changes.map((c) => c.path).toSet();
    _rebuildItems();
    // The dialog is up at once, with a progress bar: the status refresh
    // (indeterminate), then the summaries ("Loading changes 340 / 955") —
    // async git processes, never a wait on the UI isolate.
    vm.loadChanges();
  }

  static String _groupKey(String changelist, String folder) => '$changelist|$folder';

  bool _isOpen(String changelist, ChangeFolderGroup g) =>
      _expanded[_groupKey(changelist, g.folder)] ?? g.entries.length <= ChangeFolderGroup.collapseThreshold;

  void _rebuildItems() {
    final query = _filter.text.trim().toLowerCase();
    final items = <_Item>[];
    for (final changelist in vm.groupedChanges) {
      final entries = query.isEmpty
          ? changelist.entries
          : changelist.entries.where((e) => e.path.toLowerCase().contains(query)).toList();
      if (entries.isEmpty) continue;
      items.add(_Item.changelist(changelist.title, entries.length));
      for (final folder in SourceControlViewModel.foldersOf(entries)) {
        final open = query.isNotEmpty || _isOpen(changelist.title, folder);
        items.add(_Item.folder(changelist.title, folder, open));
        if (open) {
          for (final e in folder.entries) {
            items.add(_Item.file(e));
          }
        }
      }
    }
    _items = items;
    _itemsForChanges = vm.changes.length;
    _itemsForFilter = query;
  }

  void _seedSelection() {
    if (_seeded) return;
    final all = vm.changes.map((c) => c.path).toSet();
    if (all.isEmpty) return;
    final pre = widget.preChecked;
    _checked
      ..clear()
      ..addAll(pre == null ? all : all.where(pre.contains));
    _seeded = true;
  }

  Set<String> _livePaths = const {};

  void _onVm() {
    if (!mounted) return;
    setState(() {
      _seedSelection();
      final live = vm.changes.map((c) => c.path).toSet();
      _checked.removeWhere((p) => !live.contains(p));
      // Summary chunks only repaint rows; a new status rebuilds the list.
      if (live.length != _livePaths.length || !live.containsAll(_livePaths)) {
        _livePaths = live;
        _rebuildItems();
      }
    });
  }

  @override
  void dispose() {
    vm.removeListener(_onVm);
    // Closing mid-load stops the summary work.
    vm.cancelSummaries();
    _message.dispose();
    _filter.dispose();
    super.dispose();
  }

  bool get _canCommit => !_committing && _checked.isNotEmpty && _message.text.trim().isNotEmpty && vm.isRepo;

  Future<void> _commit() async {
    setState(() => _committing = true);
    final hash = await vm.commit(paths: _checked.toList()..sort(), message: _message.text.trim());
    if (!mounted) return;
    setState(() {
      _committing = false;
      if (hash != null) {
        _message.clear();
        _seeded = false;
        _seedSelection();
      }
    });
    if (hash != null) {
      try {
        showToast(
          context: context,
          builder: (toastCtx, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('Committed'),
              content: Text('${hash.substring(0, 7)} · ${vm.changes.length} change(s) remaining'),
            ),
          ),
        );
      } catch (_) {
        // No toast layer (e.g. standalone widget test) — the inline result row covers it.
      }
    }
  }

  Future<void> _refresh() => vm.loadChanges();

  @override
  Widget build(BuildContext context) {
    final total = vm.changes.length;
    if (_itemsForChanges != total || _itemsForFilter != _filter.text.trim().toLowerCase()) {
      _rebuildItems();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.gitCommitHorizontal, size: 14, color: EditorColors.primary),
            const SizedBox(width: 6),
            const Text('Commit Changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SecondaryBadge(child: Text('$total changed · ${_checked.length} selected')),
            const Spacer(),
            OutlineButton(
              key: const ValueKey('sc_commit_refresh'),
              density: ButtonDensity.compact,
              onPressed: vm.isBusy ? null : _refresh,
              leading: const Icon(LucideIcons.refreshCw, size: 12),
              child: const Text('Refresh'),
            ),
            const SizedBox(width: 6),
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () => setState(() {
                if (_checked.length == total) {
                  _checked.clear();
                } else {
                  _checked.addAll(vm.changes.map((c) => c.path));
                }
              }),
              child: Text(_checked.length == total ? 'Uncheck all' : 'Check all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('sc_commit_filter'),
                controller: _filter,
                placeholder: const Text('Filter changes by path'),
                features: const [InputFeature.leading(Icon(LucideIcons.search, size: 12))],
                onChanged: (_) => setState(_rebuildItems),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _progress(),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: total == 0
                ? const Center(
                    child: Text('Working tree clean — nothing to commit.',
                        style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                  )
                : ListView.builder(
                    key: const ValueKey('sc_commit_list'),
                    padding: const EdgeInsets.all(6),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return switch (item.kind) {
                        _ItemKind.changelist => _GroupHeader(title: item.changelist, count: item.count),
                        _ItemKind.folder => _folderHeader(item),
                        _ItemKind.file => _row(item.entry!),
                      };
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextArea(
          key: const ValueKey('sc_commit_message'),
          controller: _message,
          placeholder: const Text('Commit message (required)'),
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
        if (vm.identityRequired) ...[
          const SizedBox(height: 6),
          GitIdentityForm(viewModel: vm),
        ],
        if (vm.lastError != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.circleAlert, size: 12, color: EditorColors.logError),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vm.lastError!,
                  key: const ValueKey('sc_commit_error'),
                  style: const TextStyle(fontSize: 10, color: EditorColors.logError),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (vm.lastCommitHash != null && vm.lastError == null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.check, size: 12, color: EditorColors.logSuccess),
              const SizedBox(width: 4),
              Text(
                'Committed ${vm.lastCommitHash!.substring(0, 7)}',
                key: const ValueKey('sc_commit_result'),
                style: const TextStyle(fontSize: 10, color: EditorColors.logSuccess),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_message.text.trim().isEmpty && total > 0)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('Enter a commit message', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
              ),
            OutlineButton(
              key: const ValueKey('sc_commit_close'),
              onPressed: widget.onClose,
              child: const Text('Close'),
            ),
            const SizedBox(width: 6),
            PrimaryButton(
              key: const ValueKey('sc_commit_button'),
              onPressed: _canCommit ? _commit : null,
              leading: const Icon(LucideIcons.gitCommitHorizontal, size: 12),
              child: Text(_committing ? 'Committing…' : 'Commit ${_checked.length} file(s)'),
            ),
          ],
        ),
      ],
    );
  }

  /// The dialog's progress bar: indeterminate while `git status` runs,
  /// "Loading changes 340 / 955" while summaries arrive, "Committing 955
  /// files…" while a commit runs; an empty strip of the same height otherwise.
  Widget _progress() {
    String? label;
    double? value;
    if (vm.committingCount > 0) {
      label = 'Committing ${vm.committingCount} file${vm.committingCount == 1 ? '' : 's'}… ${vm.commitStep ?? ''}';
      value = vm.commitProgress;
    } else if (vm.statusLoading) {
      label = 'Reading git status…';
    } else if (vm.summariesLoading) {
      label = 'Loading changes ${vm.summariesDone} / ${vm.summariesTotal}';
      value = vm.summariesTotal == 0 ? null : vm.summariesDone / vm.summariesTotal;
    }
    return SizedBox(
      height: 22,
      child: label == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label,
                    key: const ValueKey('sc_commit_progress_label'),
                    style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                LinearProgressIndicator(key: const ValueKey('sc_commit_progress'), value: value),
              ],
            ),
    );
  }

  Widget _folderHeader(_Item item) {
    final group = item.folder!;
    final paths = [for (final e in group.entries) e.path];
    final checkedCount = paths.where(_checked.contains).length;
    final state = checkedCount == 0
        ? CheckboxState.unchecked
        : checkedCount == paths.length
            ? CheckboxState.checked
            : CheckboxState.indeterminate;
    final key = _groupKey(item.changelist, group.folder);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2, left: 4),
      child: Row(
        children: [
          GhostButton(
            key: ValueKey('sc_folder_toggle_$key'),
            density: ButtonDensity.compact,
            onPressed: () => setState(() {
              _expanded[key] = !item.open;
              _rebuildItems();
            }),
            child: Icon(item.open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 12),
          ),
          Checkbox(
            key: ValueKey('sc_folder_check_$key'),
            state: state,
            tristate: true,
            onChanged: (_) => setState(() {
              if (state == CheckboxState.checked) {
                _checked.removeAll(paths);
              } else {
                _checked.addAll(paths);
              }
            }),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.folder, size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 4),
          Expanded(
            child: Text(group.label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorColors.foreground),
                overflow: TextOverflow.ellipsis),
          ),
          Text('$checkedCount / ${paths.length}',
              key: ValueKey('sc_folder_count_$key'),
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }

  Widget _row(GitFileStatus e) {
    final checked = _checked.contains(e.path);
    final summary = vm.summaryFor(e.path);
    final color = sourceControlStateColor(e.state);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2, left: 28),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('sc_row_check_${e.path}'),
            state: checked ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) => setState(() {
              if (s == CheckboxState.checked) {
                _checked.add(e.path);
              } else {
                _checked.remove(e.path);
              }
            }),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color),
            ),
            child: Text(e.state.badgeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.origPath != null ? '${e.origPath} → ${e.path}' : e.path,
              style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 170,
            child: summary == null && e.state != GitFileState.deleted && vm.summariesLoading
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(size: 10)),
                  )
                : Text(
                    summary?.label ?? (e.state == GitFileState.deleted ? 'deleted' : '…'),
                    key: ValueKey('sc_row_summary_${e.path}'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(e.state == GitFileState.untracked ? 'Delete untracked file' : 'Discard working-tree changes')),
            child: GhostButton(
              key: ValueKey('sc_row_revert_${e.path}'),
              density: ButtonDensity.compact,
              onPressed: () => showRevertDialog(context, vm, e.path),
              child: const Icon(LucideIcons.undo2, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;

  const _GroupHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 3),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(width: 6),
          Text('($count)', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

enum _ItemKind { changelist, folder, file }

/// One line of the commit dialog's lazily built list.
class _Item {
  final _ItemKind kind;
  final String changelist;
  final int count;
  final ChangeFolderGroup? folder;
  final bool open;
  final GitFileStatus? entry;

  const _Item._(this.kind, {this.changelist = '', this.count = 0, this.folder, this.open = false, this.entry});

  factory _Item.changelist(String title, int count) => _Item._(_ItemKind.changelist, changelist: title, count: count);
  factory _Item.folder(String changelist, ChangeFolderGroup folder, bool open) =>
      _Item._(_ItemKind.folder, changelist: changelist, folder: folder, open: open, count: folder.entries.length);
  factory _Item.file(GitFileStatus entry) => _Item._(_ItemKind.file, entry: entry);
}
