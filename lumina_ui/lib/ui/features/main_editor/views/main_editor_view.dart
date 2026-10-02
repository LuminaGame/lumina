import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse, AppExitType;
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorSlot, MinimizedPluginDialogsBar;
import '../../../core/theme/editor_theme.dart';
import '../../../core/window/lumina_window.dart';
import '../../../core/property_editors/asset_picker_select.dart';
import '../view_models/editor_view_model.dart';
import '../../sub_editors/views/sub_editor_modal.dart';
import 'menu_bar_widget.dart';
import 'toolbar_widget.dart';
import 'outliner_widget.dart';
import 'viewport_widget.dart';
import 'details_widget.dart';
import 'content_browser_widget.dart';
import 'output_log_widget.dart';
import 'pie_blueprint_debug_panel.dart';
import 'restart_required_banner.dart';
import 'import_progress_panel.dart';
import 'quit_progress_overlay.dart';
import '../shortcuts/editor_shortcuts_scope.dart';
import 'about_dialog.dart' show rhiLabel;
import 'status_bar_engine_segment.dart';
import 'right_dock_widget.dart';
import '../view_models/editor_layout_state.dart';
import 'editor_slot_bar.dart';

/// The status bar's left-hand text segments.
const TextStyle _statusText = TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground);

class MainEditorView extends StatefulWidget {
  final LuminaProject? project;
  final String? projectLocation;
  final EditorViewModel? viewModel;

  /// Shown as a toast and logged as a warning once the editor is
  /// up (e.g. the code plugins that are inactive after "Open without
  /// plugins").
  final String? startupWarning;

  const MainEditorView({super.key, this.project, this.projectLocation, this.viewModel, this.startupWarning});

  @override
  State<MainEditorView> createState() => _MainEditorViewState();
}

class _MainEditorViewState extends State<MainEditorView> {
  late final EditorViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel ?? EditorViewModel(
      initialProject: widget.project,
      projectDirPath: widget.projectLocation,
    );
    // The editor the launcher opened offers its MCP server to
    // AI agents when the user's settings allow it. A test passes its own view
    // model (and starts its own server on an ephemeral port), so no test ever
    // binds the user's port.
    if (widget.viewModel == null && Platform.environment['FLUTTER_TEST'] != 'true') {
      unawaited(viewModel.mcpServer.applySettings());
    }
    viewModel.onLevelBlueprintSavePrompt = _promptLevelBlueprintSave;
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    final warning = widget.startupWarning;
    if (warning != null) {
      viewModel.logger.log(warning, level: 'warning', source: 'Plugins');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showToast(
          context: context,
          location: ToastLocation.bottomRight,
          showDuration: const Duration(seconds: 8),
          builder: (toastCtx, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('Opened without plugins'),
              content: Text(warning, key: const Key('startup_warning_toast')),
            ),
          ),
        );
      });
    }
  }

  late final AppLifecycleListener _lifecycle;

  /// The window this editor guards; closing it (the close
  /// button in the menu row, or the window manager) asks about unsaved work.
  LuminaWindow? _window;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final window = LuminaWindowScope.read(context);
    if (!identical(window, _window)) {
      _window?.removeCloseGuard(_confirmWindowClose);
      _window = window..addCloseGuard(_confirmWindowClose);
    }
  }

  /// The window's close: the unsaved-changes prompt, then the quit
  /// sequence (saves, plugin hooks), each step under the quit notice.
  Future<bool> _confirmWindowClose() async {
    if (!mounted) return true;
    if (!await viewModel.confirmQuit(context)) return false;
    await viewModel.prepareQuit();
    return true;
  }

  /// Quitting while a batch import runs asks to wait for
  /// it or cancel it first.
  Future<AppExitResponse> _onExitRequested() async {
    if (!mounted || !viewModel.isBatchImporting) {
      // Plugins stop their child processes before the window goes.
      await viewModel.shutdownPlugins(exiting: true);
      return AppExitResponse.exit;
    }
    viewModel.showImportRunningPrompt(
      context,
      then: () => ServicesBinding.instance.exitApplication(AppExitType.cancelable),
    );
    return AppExitResponse.cancel;
  }

  /// Switching levels closes the previous level's
  /// Blueprint tab; with unsaved changes the user saves or discards them.
  Future<bool> _promptLevelBlueprintSave(String title) {
    final answer = Completer<bool>();
    if (!mounted) return Future.value(true);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        key: const ValueKey('level_blueprint_save_prompt'),
        title: const Text('Save Level Blueprint?'),
        content: Text('$title has unsaved changes and closes with its level. Save them into the level first?'),
        actions: [
          OutlineButton(
            key: const ValueKey('level_blueprint_save_prompt_discard'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!answer.isCompleted) answer.complete(false);
            },
            child: const Text('Discard'),
          ),
          PrimaryButton(
            key: const ValueKey('level_blueprint_save_prompt_save'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!answer.isCompleted) answer.complete(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return answer.future;
  }

  @override
  void dispose() {
    _window?.removeCloseGuard(_confirmWindowClose);
    _lifecycle.dispose();
    if (viewModel.onLevelBlueprintSavePrompt == _promptLevelBlueprintSave) viewModel.onLevelBlueprintSavePrompt = null;
    if (widget.viewModel == null) {
      viewModel.dispose();
    }
    super.dispose();
  }

  void _requestCloseTab(int index) {
    if (index == 0) return;
    final tab = viewModel.openTabs[index];
    if (viewModel.isTabDirty(index)) {
      showOverlay(
        context,
        const DialogConfiguration(),
        builder: (ctx) => AlertDialog(
          title: const Text('Save Changes?'),
          content: Text('${tab.title} has unsaved changes. Do you want to save them before closing?'),
          actions: [
            OutlineButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                viewModel.closeTab(index);
              },
              child: const Text('Discard'),
            ),
            PrimaryButton(
              onPressed: () async {
                final saved = await viewModel.saveTab(index);
                if (!ctx.mounted) return;
                if (saved) {
                  Navigator.of(ctx).pop();
                  viewModel.closeTab(index);
                } else {
                  showToast(
                    context: ctx,
                    builder: (toastCtx, overlay) => SurfaceCard(
                      child: Basic(
                        title: const Text('Save failed'),
                        content: Text('${tab.title} could not be saved; the tab stays open.'),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      viewModel.closeTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The shell's keyboard shortcuts cover the whole editor,
    // menu bar and sub-editor tabs included; the scope itself decides which
    // keys stand down for text fields, RMB fly, Play and sub-editor tabs.
    // An agent's viewport_screenshot captures these boundaries
    // (the whole editor here, the level viewport below).
    return RepaintBoundary(
      key: viewModel.mcpServer.editorBoundaryKey,
      // The background import's progress floats over the
      // editor's bottom-right corner.
      child: Stack(
      children: [
      Positioned.fill(
      // Every asset picker in the editor (Details panel and
      // sub-editor tabs) shows live thumbnails and can browse to its asset.
      child: AssetPickerScope(
      changes: viewModel,
      latest: viewModel.latestAsset,
      requestThumbnail: viewModel.requestAssetThumbnail,
      browse: viewModel.browseToAsset,
      child: EditorShortcutsScope(
      viewModel: viewModel,
      child: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          child: Column(
            children: [
              // 1. Top Menu Bar
              MenuBarWidget(
                engineVersion: viewModel.engineVersion,
                activeLevelName: viewModel.activeLevelName,
                onSave: () => viewModel.clearDirtyFlag(),
                viewModel: viewModel,
              ),

              if (viewModel.pluginRestartRequired)
                RestartRequiredBanner(
                  onDismiss: () => viewModel.dismissPluginRestart(),
                  onRestart: () => viewModel.commands.execute('editor.restart'),
                ),

              // 2. Main Workspace Tab Bar (window tabs).
              // The active tab is attached to the toolbar
              // under it (same fill, no bottom edge); the strip's bottom line
              // runs under the inactive tabs only.
              Container(
                height: 28,
                color: EditorColors.sidebar,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EditorTabStyle.stripBottomLine(),
                    Positioned.fill(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: viewModel.openTabs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final tab = entry.value;
                            final active = viewModel.activeTabIndex == index;

                            final rawTitle = tab.title;
                            final cleanTitle = rawTitle.endsWith('.lmas')
                                ? rawTitle.substring(0, rawTitle.length - 5)
                                : rawTitle;
                            final displayTitle = tab.isDirty ? '$cleanTitle*' : cleanTitle;

                            return Tooltip(
                              tooltip: (context) => TooltipContainer(child: Text(cleanTitle)),
                              child: Listener(
                                onPointerDown: (event) {
                                  if (event.buttons == 4 && index > 0) { // kMiddleMouseButton
                                    _requestCloseTab(index);
                                  }
                                },
                                child: GestureDetector(
                                  onTap: () => viewModel.selectTab(index),
                                  child: Container(
                                    key: ValueKey('workspace_tab_$index'),
                                    height: 24,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    margin: const EdgeInsets.only(right: 2),
                                    // The toolbar right under the strip is cardHeader.
                                    decoration: EditorTabStyle.decoration(active: active, content: EditorColors.cardHeader),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          tab.category == 'level'
                                              ? LucideIcons.map
                                              : (viewModel.extensionRegistry.findTab(tab.category)?.icon ?? LucideIcons.fileCode),
                                          size: 11,
                                          color: active ? EditorColors.primary : EditorColors.mutedForeground,
                                        ),
                                        const SizedBox(width: 6),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 160),
                                          child: Text(
                                            displayTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                              color: active ? EditorColors.primary : EditorColors.foreground,
                                            ),
                                          ),
                                        ),
                                        if (index > 0) ...[
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => _requestCloseTab(index),
                                            child: const Icon(LucideIcons.x, size: 10, color: EditorColors.mutedForeground),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. The level viewport's toolbar, only while the level tab is
              // active: document tabs (Plugins, the sub-editors) carry their
              // own tools.
              if (viewModel.currentTab.id == EditorViewModel.kLevelTabId) ToolbarWidget(viewModel: viewModel),

              const Divider(height: 1),

              // 4. Main Workspace (3D Viewport or Full-Screen Sub-Editor
              // Workspace Tab), with the plugin right dock beside it.
              Expanded(child: _buildWorkspace()),

              const Divider(height: 1),

              // 5. Bottom Status Bar
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: EditorColors.cardHeader,
                child: Row(
                  children: [
                    // The Content Drawer's button, only
                    // while the bottom panel is unpinned.
                    if (!viewModel.layoutState.bottomPinned) ...[
                      Tooltip(
                        tooltip: (context) => TooltipContainer(child: const Text('Content Drawer')),
                        child: GhostButton(
                          key: const ValueKey('status_bar_content_drawer'),
                          density: ButtonDensity.compact,
                          onPressed: () => viewModel.toggleContentDrawer(),
                          child: Icon(
                            viewModel.layoutState.bottomVisible ? LucideIcons.folderOpen : LucideIcons.folder,
                            size: 11,
                            color: viewModel.layoutState.bottomVisible ? EditorColors.primary : EditorColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
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
                    const Spacer(),
                    EditorSlotBar(registry: viewModel.extensionRegistry, slot: EditorSlot.statusBarRight, compact: true, trailingGap: 8),
                    ImportProgressChip(jobs: viewModel.importJobs),
                    Row(
                      children: [
                        const Icon(LucideIcons.circleCheck, size: 10, color: EditorColors.logSuccess),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<String?>(
                          valueListenable: LuminaGraphicsDevices.inUse,
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
              ),
            ],
          ),
        );
      },
      ),
      ),
      ),
      ),
      Positioned(
        right: 12,
        bottom: 28,
        child: ImportProgressPanel(jobs: viewModel.importJobs, onShowErrors: viewModel.showImportErrors),
      ),
      // While the editor quits: what it is doing, over an editor that
      // takes no more input.
      Positioned.fill(child: QuitProgressOverlay(status: viewModel.quitStatus)),
      ],
      ),
    );
  }

  /// Keeps the right dock's subtree (and its plugin panels' state) when the
  /// dock moves between its pane and the offstage parking spot.
  final GlobalKey _rightDockKey = GlobalKey(debugLabel: 'right_dock');

  /// The document tabs (the level editor, then one per sub-editor) with the
  /// plugin right dock beside them. The dock is one subtree for every tab:
  /// it shows every open panel on the level tab and the "Always" ones on the
  /// others, at one shared width. While panels are open but the active tab
  /// shows none of them, it is parked offstage so they keep their state.
  Widget _buildWorkspace() {
    final panels = viewModel.panelsController;
    final levelTab = viewModel.currentTab.id == EditorViewModel.kLevelTabId;
    final dockOpen = panels.openRightPanels.isNotEmpty;
    final dockShown = panels.shownRightPanels(levelTab: levelTab).isNotEmpty;
    final dock = KeyedSubtree(
      key: _rightDockKey,
      child: RightDockWidget(key: const ValueKey('right_dock'), controller: panels, levelTab: levelTab),
    );
    final tabs = IndexedStack(
      index: viewModel.activeTabIndex.clamp(0, math.max(0, viewModel.openTabs.length - 1)),
      children: [
        // Tab 0: Main Editor Workspace: the
        // Outliner over the Details inspector in one left column,
        // the viewport in the centre with the bottom panel under
        // it. Every absolute pane reports its dragged size back
        // into the layout state, one disk write per drag.
        ResizablePanel.horizontal(
          draggerBuilder: (context) => const HorizontalResizableDragger(),
          children: [
            // Left Column: World Outliner over Details
            if (viewModel.layoutState.outlinerVisible || viewModel.layoutState.detailsVisible)
              ResizablePane(
                // Keyed: hiding the left column must not hand its
                // absolute-size pane state to the centre column.
                key: const ValueKey('workspace_left_column'),
                initialSize: viewModel.layoutState.outlinerWidth,
                minSize: EditorLayoutState.minOutlinerWidth,
                onSizeChangeEnd: (size) => viewModel.setPaneSize(outlinerWidth: size),
                child: _buildLeftColumn(),
              ),

            // Center Column: 3D Viewport & Bottom Tabs
            ResizablePane.flex(
              key: const ValueKey('workspace_centre_column'),
              child: ResizablePanel.vertical(
                draggerBuilder: (context) => const VerticalResizableDragger(),
                children: [
                  // 3D Viewport Screen
                  ResizablePane.flex(
                    child: RepaintBoundary(
                      key: viewModel.mcpServer.viewportBoundaryKey,
                      child: ViewportWidget(viewModel: viewModel),
                    ),
                  ),

                  // Bottom Panel (Tabs): docked while pinned, a
                  // Content Drawer opened from the status bar
                  // while unpinned.
                  if (viewModel.layoutState.bottomVisible)
                    ResizablePane(
                      initialSize: viewModel.layoutState.bottomHeight,
                      minSize: 100,
                      onSizeChangeEnd: (size) => viewModel.setPaneSize(bottomHeight: size),
                      child: _buildBottomPanel(),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Tabs 1..N: Sub-Editor Workspaces
        // each tab in its own boundary, what
        // asset_editor_screenshot captures.
        for (int i = 1; i < viewModel.openTabs.length; i++)
          RepaintBoundary(
            key: viewModel.mcpServer.subEditorBoundaryKeyFor(viewModel.openTabs[i].id),
            child: SubEditorWorkspaceWidget(
              key: ValueKey(viewModel.openTabs[i].id),
              assetName: viewModel.openTabs[i].asset?.fileName ?? viewModel.openTabs[i].title,
              assetType: viewModel.openTabs[i].category,
              asset: viewModel.openTabs[i].asset,
              editorViewModel: viewModel,
              tabId: viewModel.openTabs[i].id,
              onClose: () => _requestCloseTab(i),
            ),
          ),
      ],
    );
    return ResizablePanel.horizontal(
      draggerBuilder: (context) => const HorizontalResizableDragger(),
      children: [
        ResizablePane.flex(
          key: const ValueKey('workspace_documents'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              tabs,
              Offstage(child: dockOpen && !dockShown ? dock : null),
            ],
          ),
        ),
        // Keyed like the left column, so opening it hands no pane state around.
        if (dockShown)
          ResizablePane(
            key: const ValueKey('workspace_right_dock'),
            initialSize: viewModel.layoutState.rightWidth,
            minSize: EditorLayoutState.minRightWidth,
            onSizeChangeEnd: (size) => viewModel.setPaneSize(rightWidth: size),
            child: dock,
          ),
      ],
    );
  }

  /// The left column: the Outliner over the Details inspector, each hideable
  /// from the Window menu; one alone fills the column.
  Widget _buildLeftColumn() {
    final layout = viewModel.layoutState;
    if (!layout.detailsVisible) return OutlinerWidget(viewModel: viewModel);
    if (!layout.outlinerVisible) return DetailsWidget(viewModel: viewModel);
    return ResizablePanel.vertical(
      draggerBuilder: (context) => const VerticalResizableDragger(),
      children: [
        ResizablePane.flex(
          child: OutlinerWidget(viewModel: viewModel),
        ),
        ResizablePane(
          initialSize: layout.detailsHeight,
          minSize: 120,
          onSizeChangeEnd: (size) => viewModel.setPaneSize(detailsHeight: size),
          child: DetailsWidget(viewModel: viewModel),
        ),
      ],
    );
  }

  /// The bottom panel: its tab bar with the pin button at the right end, and
  /// the active tab's content.
  Widget _buildBottomPanel() {
    final pinned = viewModel.layoutState.bottomPinned;
    return Container(
      color: EditorColors.card,
      child: Column(
        children: [
          // Tab Bar (the active tab joins its content).
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: EditorColors.sidebar,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EditorTabStyle.stripBottomLine(),
                Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Each tab's fill is the colour of its content's top row: the
                // Content Browser's toolbar is the rail, the Output Log's and
                // the Blueprint debugger's headers are cardHeader.
                _buildTabHeader(0, LucideIcons.folder, 'Content Browser', content: EditorColors.rail),
                _buildTabHeader(1, LucideIcons.terminal, 'Output Log', content: EditorColors.cardHeader),
                _buildTabHeader(2, LucideIcons.code, 'Blueprint', content: EditorColors.cardHeader),
                // Plugin panels as further tabs.
                for (final (i, panel) in viewModel.pluginPanels.indexed)
                  _buildTabHeader(kBuiltInBottomTabs + i, panel.icon, panel.title,
                      content: EditorColors.card, key: ValueKey('bottom_tab_plugin_${panel.id}')),
                const Spacer(),
                Tooltip(
                  tooltip: (context) => TooltipContainer(child: Text(pinned ? 'Unpin: turn into a Content Drawer' : 'Pin to the layout')),
                  child: GhostButton(
                    key: const ValueKey('bottom_panel_pin'),
                    density: ButtonDensity.compact,
                    onPressed: () => viewModel.setBottomPinned(!pinned),
                    child: Icon(
                      pinned ? LucideIcons.pin : LucideIcons.pinOff,
                      size: 11,
                      color: pinned ? EditorColors.primary : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: IndexedStack(
              // A saved tab of a plugin that is gone falls back to the Content Browser.
              index: viewModel.layoutState.activeBottomTab < kBuiltInBottomTabs + viewModel.pluginPanels.length
                  ? viewModel.layoutState.activeBottomTab
                  : 0,
              children: [
                ContentBrowserWidget(viewModel: viewModel),
                OutputLogWidget(viewModel: viewModel),
                // The running Blueprint, docked.
                PieBlueprintDebugPanel(viewModel: viewModel),
                for (final panel in viewModel.pluginPanels)
                  KeyedSubtree(key: ValueKey('bottom_panel_plugin_${panel.id}'), child: Builder(builder: panel.builder)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(int index, IconData icon, String label, {required Color content, Key? key}) {
    final selected = viewModel.layoutState.activeBottomTab == index;
    return GestureDetector(
      key: key ?? ValueKey('bottom_tab_$index'),
      onTap: () {
        viewModel.layoutState.activeBottomTab = index;
        viewModel.saveLayoutState();
        setState(() {});
      },
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: EditorTabStyle.decoration(active: selected, content: content),
        child: Row(
          children: [
            Icon(icon, size: 11, color: selected ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? EditorColors.primary : EditorColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
