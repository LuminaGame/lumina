import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorSlot, MinimizedPluginDialogsBar;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/about_dialog.dart' show rhiLabel;
import 'package:lumina_ui/ui/features/main_editor/views/editor_slot_bar.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_progress_panel.dart';
import 'package:lumina_ui/ui/features/main_editor/views/status_bar_engine_segment.dart';
import 'package:lumina_ui/ui/features/main_editor/views/status_bar_web_module_segment.dart';

const TextStyle _statusText = TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground);

/// The editor's bottom status bar, shared by every tab: the Content Drawer
/// button, minimized plugin dialogs, engine and Filament versions, the level
/// and its counts, what Play runs, plugin buttons, the web module download,
/// imports and the renderer.
class EditorStatusBar extends StatelessWidget {
  final EditorViewModel viewModel;

  const EditorStatusBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          // The Content Drawer's button, left of the version: the level
        // tab's while its bottom panel is unpinned, a sub-editor tab's
        // while its own drawer is unpinned.
        _ContentDrawerButton(viewModel: viewModel),
        // Minimized plugin dialogs dock here with their plugin icon and progress.
          const MinimizedPluginDialogsBar(),
          Image.asset('assets/logo_white.png', height: 11),
          const SizedBox(width: 6),
          // Engine · Filament · level · counts;
          // the level and counts truncate first, never a version.
          Text(
            'Lumina Engine ${LuminaRelease.displayVersion}',
            key: const ValueKey('status_engine_version'),
            style: _statusText,
          ),
          const Text('  ·  ', style: _statusText),
          FilamentStatusSegment(onPressed: () => viewModel.commands.execute('help.about', context)),
          const Text('  ·  ', style: _statusText),
          Flexible(
            child: Text(
              viewModel.activeLevelName,
              key: const ValueKey('status_level'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _statusText,
            ),
          ),
          const Text('  ·  ', style: _statusText),
          Flexible(
            child: Text(
              '${viewModel.actorCount} actors · ${viewModel.hiddenActorCount} hidden · ${viewModel.selectedCount} selected',
              key: const ValueKey('status_actor_counts'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _statusText,
            ),
          ),
          // What Play is running.
          if (viewModel.pieController.isPlaying && viewModel.pieController.pawnClassLabel != null) ...[
            const SizedBox(width: 12),
            const Icon(LucideIcons.gamepad2, size: 10, color: EditorColors.logSuccess),
            const SizedBox(width: 4),
            Text(
              'PIE · ${viewModel.pieController.pawnClassLabel}',
              key: const ValueKey('status_pie_pawn'),
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.logSuccess),
            ),
          ],
          // Plugin buttons on both sides of the bar.
          EditorSlotBar(registry: viewModel.extensionRegistry, slot: EditorSlot.statusBarLeft, compact: true, leadingGap: 8),
          // The web module download (first launch or Packaging).
          const WebModuleStatusSegment(),
          const Spacer(),
          EditorSlotBar(registry: viewModel.extensionRegistry, slot: EditorSlot.statusBarRight, compact: true, trailingGap: 8),
          ImportProgressChip(jobs: viewModel.importJobs),
          Row(
            children: [
              const Icon(LucideIcons.circleCheck, size: 10, color: EditorColors.logSuccess),
              const SizedBox(width: 4),
              ValueListenableBuilder<String?>(
                valueListenable: LuminaGraphicsDevices.inUse.asValueListenable(),
                builder: (context, gpu, _) => Text(
                  // What this renderer really is doing, not borrowed
                  // feature names: the quality preset in force, the
                  // shadow technique it implies, the backend and
                  // the GPU it runs on.
                  'Shaders compiled  ·  Quality: ${viewModel.qualityPreset.toUpperCase()}  ·  '
                  'Shadows: ${viewModel.quality.profile.shadows.shadowType.name.toUpperCase()} '
                  '${viewModel.quality.profile.shadows.mapSize}  ·  ${rhiLabel(gpu)}',
                  key: const ValueKey('status_bar_rhi'),
                  style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Content Drawer toggle of the active tab, or nothing while its bottom
/// panel is pinned.
class _ContentDrawerButton extends StatelessWidget {
  final EditorViewModel viewModel;

  const _ContentDrawerButton({required this.viewModel});

  Widget _button({required bool open, required VoidCallback onPressed}) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Tooltip(
      tooltip: (context) => const TooltipContainer(child: Text('Content Drawer')),
      child: GhostButton(
        key: const ValueKey('status_bar_content_drawer'),
        density: ButtonDensity.compact,
        onPressed: onPressed,
        child: Icon(
          open ? LucideIcons.folderOpen : LucideIcons.folder,
          size: 11,
          color: open ? EditorColors.primary : EditorColors.foreground,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final drawer = viewModel.activeSubEditorDrawer;
    if (drawer != null) {
      return ListenableBuilder(
        listenable: drawer,
        builder: (context, _) => drawer.pinned ? const SizedBox.shrink() : _button(open: drawer.open, onPressed: drawer.toggle),
      );
    }
    if (viewModel.layoutState.bottomPinned) return const SizedBox.shrink();
    return _button(open: viewModel.layoutState.bottomVisible, onPressed: viewModel.toggleContentDrawer);
  }
}
