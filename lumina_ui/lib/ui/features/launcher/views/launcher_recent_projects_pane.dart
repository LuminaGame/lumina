import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';

/// The launcher's Recent Projects pane: the searchable project cards with
/// their Open / Locate… actions and context menu (rename, reveal, duplicate,
/// remove from the hub, delete from disk).
class LauncherRecentProjectsPane extends StatefulWidget {
  const LauncherRecentProjectsPane({
    super.key,
    required this.viewModel,
    required this.onOpenProject,
    required this.onNewProject,
  });

  final LauncherViewModel viewModel;

  /// Opens [project] (in [projectDir]) in the editor.
  final void Function(LuminaProject project, String projectDir) onOpenProject;

  /// Opens the Create Project dialog (the empty state's button).
  final VoidCallback onNewProject;

  @override
  State<LauncherRecentProjectsPane> createState() => _LauncherRecentProjectsPaneState();
}

class _LauncherRecentProjectsPaneState extends State<LauncherRecentProjectsPane> {
  String _searchQuery = '';

  LauncherViewModel get _viewModel => widget.viewModel;

  String _formatLastOpened(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = _viewModel.recentProjects;
    final filtered = _searchQuery.isEmpty
        ? allProjects
        : allProjects
              .where(
                (p) => p.project.projectName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Sub-Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Row(
            children: [
              const Text(
                'Recent Projects',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EditorColors.foreground,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: EditorColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Text(
                  '${allProjects.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: EditorColors.mutedForeground,
                  ),
                ),
              ),
              if (_viewModel.missingProjectCount > 0) ...[
                const SizedBox(width: 8),
                // Rows that cannot open are out of the way by default, but the
                // count says so and brings them back — with their Missing badge
                // and Locate… repair action — rather than losing them silently.
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => _viewModel
                      .setShowMissingProjects(!_viewModel.showMissingProjects),
                  child: Text(
                    _viewModel.showMissingProjects
                        ? 'Hide ${_viewModel.missingProjectCount} unreachable'
                        : '${_viewModel.missingProjectCount} hidden — path not found',
                    style: const TextStyle(
                      fontSize: 10,
                      color: EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: 260,
                height: 32,
                child: TextField(
                  placeholder: const Text(
                    'Search projects (Ctrl+F)...',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),

        // Grid Content
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: filtered
                          .map((entry) => _buildProjectCard(context, entry))
                          .toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logo_white.png',
            height: 48,
            errorBuilder: (ctx, _, _) => const Icon(
              LucideIcons.folderOpen,
              size: 48,
              color: EditorColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No projects yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: EditorColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first Lumina 3D game project or open an existing .lmproject file from disk.',
            style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            onPressed: () => widget.onNewProject(),
            child: const Text('Create New Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, RecentProjectEntry entry) {
    final proj = entry.project;
    final isMissing = entry.isMissing;
    // `.lumina/cover.png`, else where older builds kept it.
    final coverFile = ProjectRepository.coverImageFile(entry.projectDir) ?? File(ProjectRepository.coverImagePath(entry.projectDir));
    final hasCover = coverFile.existsSync();

    final contextMenuItems = isMissing
        ? [
            MenuButton(
              leading: const Icon(LucideIcons.search, size: 14),
              onPressed: (ctx) {
                _handleLocateProject(context, entry);
              },
              child: const Text('Locate...'),
            ),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(
                LucideIcons.trash2,
                size: 14,
                color: Colors.red,
              ),
              onPressed: (ctx) {
                _viewModel.removeFromHub(entry);
              },
              child: const Text(
                'Remove from Hub',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ]
        : [
            MenuButton(
              leading: const Icon(
                LucideIcons.folderOpen,
                size: 14,
                color: EditorColors.primary,
              ),
              onPressed: (ctx) async {
                final loaded = await _viewModel.openProject(entry);
                if (loaded != null && context.mounted) {
                  widget.onOpenProject(loaded, entry.projectDir);
                }
              },
              child: const Text('Open'),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.pencil, size: 14),
              onPressed: (ctx) {
                _showRenameDialog(context, entry);
              },
              child: const Text('Rename...'),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.externalLink, size: 14),
              onPressed: (ctx) {
                _viewModel.revealInFileManager(entry);
              },
              child: const Text('Show in File Explorer'),
            ),
            MenuButton(
              leading: const Icon(LucideIcons.copy, size: 14),
              onPressed: (ctx) {
                _viewModel.duplicateProject(entry);
              },
              child: const Text('Duplicate Project'),
            ),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(LucideIcons.minus, size: 14),
              onPressed: (ctx) {
                _viewModel.removeFromHub(entry);
              },
              child: const Text('Remove from Hub'),
            ),
            MenuButton(
              leading: const Icon(
                LucideIcons.trash2,
                size: 14,
                color: Colors.red,
              ),
              onPressed: (ctx) {
                _showDeleteFromDiskConfirmDialog(context, entry);
              },
              child: const Text(
                'Delete from Disk',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ];

    return EditorContextMenu(
      items: contextMenuItems,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMissing
                ? Colors.amber.withValues(alpha: 0.5)
                : EditorColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              // a drop shadow/scrim: black at 13%, not a surface
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Header
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: EditorColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: hasCover
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            child: Image.file(
                              coverFile,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            LucideIcons.box,
                            size: 36,
                            color: EditorColors.mutedForeground,
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (isMissing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: const Text(
                              'Missing',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: EditorColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: EditorColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Text(
                              proj.engineVersion,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: EditorColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proj.projectName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: EditorColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.projectDir,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontFamily: EditorTypography.monoFamily,
                      color: EditorColors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Opened ${_formatLastOpened(entry.lastOpened)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: EditorColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: isMissing
                            ? OutlineButton(
                                density: ButtonDensity.compact,
                                onPressed: () =>
                                    _handleLocateProject(context, entry),
                                child: const Text(
                                  'Locate...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber,
                                  ),
                                ),
                              )
                            : PrimaryButton(
                                density: ButtonDensity.compact,
                                onPressed: () async {
                                  final loaded = await _viewModel.openProject(
                                    entry,
                                  );
                                  if (loaded != null && context.mounted) {
                                    widget.onOpenProject(loaded, entry.projectDir);
                                  }
                                },
                                child: const Text(
                                  'Open',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      // The menu anchors to the "…" button itself, not to the
                      // card grid, so it opens under the button.
                      Builder(
                        builder: (buttonContext) => OutlineButton(
                          density: ButtonDensity.compact,
                          onPressed: () {
                            showDropdown(
                              context: buttonContext,
                              alignment: Alignment.topRight,
                              anchorAlignment: Alignment.bottomRight,
                              builder: (ctx) =>
                                  DropdownMenu(children: contextMenuItems),
                            );
                          },
                          child: const Icon(LucideIcons.ellipsis, size: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLocateProject(
    BuildContext context,
    RecentProjectEntry entry,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lmproject'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await _viewModel.locateProject(entry, path);
    }
  }

  void _showRenameDialog(BuildContext context, RecentProjectEntry entry) {
    final controller = TextEditingController(text: entry.project.projectName);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter new project name:',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(controller: controller),
            ],
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  _viewModel.renameProject(entry, newName);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFromDiskConfirmDialog(
    BuildContext context,
    RecentProjectEntry entry,
  ) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Project from Disk'),
          content: Text(
            'Are you sure you want to permanently delete "${entry.project.projectName}" and all its asset files at:\n${entry.projectDir}?\n\nThis action cannot be undone.',
            style: const TextStyle(fontSize: 11),
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () {
                _viewModel.deleteFromDisk(entry);
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }
}
