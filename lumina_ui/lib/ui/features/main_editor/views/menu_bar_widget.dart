import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../core/window/lumina_window.dart';
import '../../../core/window/window_controls.dart';
import '../view_models/editor_view_model.dart';
import '../commands/editor_command.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorMenuPlacement;
import '../../../core/plugin_extension_registry.dart' show PluginMenuEntry, PluginMenu;
import 'menu_tree_builder.dart';
import '../../source_control/view_models/source_control_view_model.dart';
import '../../source_control/views/init_repo_prompt.dart';
import 'legacy_units_banner.dart';

class MenuBarWidget extends StatelessWidget {
  final String engineVersion;
  final String activeLevelName;
  final VoidCallback onSave;
  final EditorViewModel? viewModel;

  const MenuBarWidget({
    super.key,
    required this.engineVersion,
    required this.activeLevelName,
    required this.onSave,
    this.viewModel,
  });

  /// [commandContext] replaces the menu item's context for commands that use
  /// it after the menu has closed.
  MenuButton _buildMenuButton(
    BuildContext context,
    String id, {
    BuildContext? commandContext,
  }) {
    final cmd = viewModel?.commands.byId(id);
    if (cmd == null) return MenuButton(child: Text('Unknown: $id'));

    final bool canExec = cmd.canExecute();

    String displayLabel = cmd.label;
    if (id == 'edit.undo' && viewModel != null) {
      displayLabel = viewModel!.transactions.undoLabel;
    } else if (id == 'edit.redo' && viewModel != null) {
      displayLabel = viewModel!.transactions.redoLabel;
    }

    return MenuButton(
      leading: cmd.icon != null ? Icon(cmd.icon, size: 14) : null,
      trailing: cmd.shortcutLabel.isNotEmpty
          ? Text(
              cmd.shortcutLabel,
              style: const TextStyle(
                fontSize: 10,
                color: EditorColors.mutedForeground,
              ),
            )
          : null,
      enabled: canExec,
      onPressed: canExec
          ? (ctx) => viewModel?.commands.execute(id, commandContext ?? ctx)
          : null,
      child: Text(displayLabel, style: const TextStyle(fontSize: 10)),
    );
  }

  /// A Window row checked while [open] (the plugin panels'
  /// checkbox row, [menuCheckboxItem]); a plain button without a view model.
  MenuItem _buildPanelCheckRow(BuildContext context, String id, ValueListenable<bool>? open) {
    final cmd = viewModel?.commands.byId(id);
    if (cmd == null || open == null) return _buildMenuButton(context, id, commandContext: context);
    return menuCheckboxItem(cmd, open, commandContext: context);
  }

  /// `Tools → Source Control` submenu from the view model's entry model; when
  /// git is absent the entries are disabled and the install hint is shown.
  List<MenuItem> _sourceControlSubMenu(BuildContext context) {
    final sc = viewModel?.sourceControl;
    if (sc == null) return const [];
    final entries = sc.menuEntries;
    final showHint = entries.any(
      (e) => e.tooltip == SourceControlViewModel.installHint,
    );
    return [
      if (showHint)
        MenuLabel(
          child: SizedBox(
            width: 220,
            child: Text(
              SourceControlViewModel.installHint,
              style: const TextStyle(
                fontSize: 9,
                color: EditorColors.mutedForeground,
              ),
            ),
          ),
        ),
      for (final e in entries) _buildMenuButton(context, e.id),
    ];
  }

  /// A registry item: the shared [menuTreeButton] (disabled, with the
  /// reason on hover, while its plugin's process is not running).
  MenuButton _buildCommandMenuButton(
    BuildContext context,
    EditorCommand cmd, {
    BuildContext? commandContext,
  }) =>
      menuTreeButton(cmd, commandContext: commandContext);

  MenuItem _buildToolItem(
    BuildContext context,
    EditorCommand cmd, {
    BuildContext? commandContext,
  }) {
    if (viewModel?.commands.byId(cmd.id) != null) {
      return _buildMenuButton(context, cmd.id, commandContext: commandContext);
    }
    return _buildCommandMenuButton(
      context,
      cmd,
      commandContext: commandContext,
    );
  }

  /// The extension-registry items under the top-level menu [root], as tree
  /// entries relative to that menu (only built-in items reach
  /// Tools, Window and Help; plugin items live under Plugins or their own
  /// menus).
  List<MenuTreeEntry> _entriesUnder(String root) => [
    for (final e in viewModel?.extensionRegistry.menuEntriesUnder(root) ?? const <PluginMenuEntry>[])
      MenuTreeEntry(path: e.segments.sublist(1), command: e.command, options: e.options),
  ];

  /// Registry items of the menu [root], built by the shared tree builder.
  List<MenuItem> _registryItems(BuildContext context, String root, {List<MenuTreeEntry>? entries}) => buildMenuTree(
    entries ?? _entriesUnder(root),
    commandContext: context,
    itemBuilder: (e) => _buildToolItem(context, e.command, commandContext: context),
  );

  /// Tools: the built-in tools the registry holds (Material
  /// Editor, …).
  List<MenuItem> _buildToolsMenuCommands(BuildContext context) {
    final items = _registryItems(context, 'Tools');
    return items.isEmpty ? [_buildMenuButton(context, 'tools.materialEditor')] : items;
  }

  /// Plugin Manager…, New Plugin… and one submenu per plugin
  /// group (`Plugins/<Group>/…`), sorted by name.
  MenuButton _buildPluginsMenu(BuildContext context) {
    final entries = _entriesUnder('Plugins')..sort((a, b) => a.path.first.toLowerCase().compareTo(b.path.first.toLowerCase()));
    return MenuButton(
      subMenu: [
        _buildMenuButton(context, 'tools.plugins'),
        // The wizard offers "Enable now" on this context once the plugin is
        // generated, long after the menu item's own context is gone.
        _buildMenuButton(context, 'tools.plugins.new', commandContext: context),
        if (entries.isNotEmpty) ...[
          const MenuDivider(),
          ..._registryItems(context, 'Plugins', entries: entries),
        ],
      ],
      child: const Text('Plugins', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  /// The plugin-owned top-level menus placed at [placement].
  List<MenuButton> _buildPluginMenus(BuildContext context, EditorMenuPlacement placement) => [
    for (final m in viewModel?.extensionRegistry.pluginMenus ?? const <PluginMenu>[])
      if (m.menu.placement == placement)
        MenuButton(
          key: ValueKey('plugin_menu_${m.menu.id}'),
          subMenu: _registryItems(context, m.menu.title),
          child: Text(m.menu.title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        ),
  ];

  /// Built-in registry items appended to a fixed menu (Window, Help), after
  /// a divider.
  List<MenuItem> _extensionTail(BuildContext context, String root) {
    final items = _registryItems(context, root);
    return items.isEmpty ? const [] : [const MenuDivider(), ...items];
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in commands
    final vm = viewModel;
    return ListenableBuilder(
      // Plugin (re)registration changes the Plugins menu and the plugin menus.
      listenable: vm == null ? ChangeNotifier() : Listenable.merge([vm.commands, vm.extensionRegistry]),
      builder: (context, _) {
        final bar = Container(
          height: 65,
          // This row is the window's title bar. The window
          // buttons sit flush at its right end; macOS keeps room for its
          // traffic lights at the left.
          padding: EdgeInsets.only(left: 8 + LuminaWindow.leadingInset),
          color: EditorColors.cardHeader,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Engine Color SVG Logo & Title
              Column(
                children: [
                  Image.asset('assets/logo_color.png', height: 48),
                  const SizedBox(width: 6),
                  Row(
                    children: [
                      const Text(
                        'Studio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Native shadcn_flutter Menubar
              Menubar(
                children: [
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'file.newLevel'),
                      _buildMenuButton(context, 'file.openLevel'),
                      _buildMenuButton(context, 'file.saveLevel'),
                      _buildMenuButton(context, 'file.saveAll'),
                      _buildMenuButton(context, 'file.newAsset'),
                      // The picker and summary
                      // dialog open after the menu has closed.
                      _buildMenuButton(
                        context,
                        'file.importAssetFolder',
                        commandContext: context,
                      ),
                      const MenuDivider(),
                      _buildMenuButton(context, 'file.exitStudio'),
                    ],
                    child: const Text(
                      'File',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'edit.undo'),
                      _buildMenuButton(context, 'edit.redo'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'edit.duplicate'),
                      _buildMenuButton(context, 'edit.delete'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'edit.projectSettings'),
                      _buildMenuButton(context, 'edit.editorPreferences'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'edit.levelBlueprint'),
                    ],
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'view.resetCamera'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'view.viewportMode.lit'),
                      _buildMenuButton(context, 'view.viewportMode.unlit'),
                      _buildMenuButton(context, 'view.viewportMode.wireframe'),
                      _buildMenuButton(context, 'view.viewportMode.buffer'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'view.cameraMode.perspective'),
                      _buildMenuButton(context, 'view.cameraMode.top'),
                      _buildMenuButton(context, 'view.cameraMode.front'),
                      _buildMenuButton(context, 'view.cameraMode.right'),
                      const MenuDivider(),
                      _buildMenuButton(context, 'view.fullscreen'),
                    ],
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'build.generateDartCode'),
                      _buildMenuButton(context, 'build.buildManager'),
                      _buildMenuButton(context, 'build.buildNavigation'),
                      _buildMenuButton(context, 'build.buildAll'),
                      _buildMenuButton(context, 'build.cookAndPackage'),
                    ],
                    child: const Text(
                      'Build',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'debug.togglePie'),
                      _buildMenuButton(context, 'debug.playStandalone'),
                      _buildMenuButton(context, 'debug.pausePie'),
                      _buildMenuButton(context, 'debug.stepPie'),
                      _buildMenuButton(context, 'debug.stopPie'),
                    ],
                    child: const Text(
                      'Debug',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  MenuButton(
                    subMenu: [
                      ..._buildToolsMenuCommands(context),
                      const MenuDivider(),
                      // The editor's MCP server for AI agents.
                      _buildMenuButton(context, 'tools.aiAgentAccess'),
                      // Skills + AGENTS.md / CLAUDE.md for AI agents; asks
                      // before replacing edited files, after the menu closed.
                      _buildMenuButton(context, 'tools.aiAgentFiles', commandContext: context),
                      const MenuDivider(),
                      // Empties the project's DerivedDataCache/.
                      _buildMenuButton(context, 'tools.clearDerivedDataCache'),
                      const MenuDivider(),
                      MenuButton(
                        leading: const Icon(LucideIcons.gitBranch, size: 14),
                        subMenu: _sourceControlSubMenu(context),
                        child: const Text(
                          'Source Control',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                    child: const Text(
                      'Tools',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Everything plugin-related, then the menus
                  // plugins own.
                  _buildPluginsMenu(context),
                  ..._buildPluginMenus(context, EditorMenuPlacement.beforeWindow),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'window.marketplace'),
                      const MenuDivider(),
                      // Checked while their panel is open.
                      _buildPanelCheckRow(context, 'window.toggleOutliner', viewModel?.outlinerOpen),
                      _buildPanelCheckRow(context, 'window.toggleDetails', viewModel?.detailsOpen),
                      _buildPanelCheckRow(context, 'window.toggleBottomPanel', viewModel?.bottomPanelOpen),
                      _buildPanelCheckRow(context, 'window.showOutputLog', viewModel?.outputLogOpen),
                      // One checked entry per plugin panel; a right-dock
                      // panel's is followed by its "Show in Every Editor" row.
                      if (viewModel != null)
                        for (final panel in viewModel!.allPluginPanels) ...[
                          if (viewModel!.commands.byId('window.panel.${panel.id}') case final command?)
                            menuCheckboxItem(command, viewModel!.panelsController.visibility(panel.id), commandContext: context),
                          if (viewModel!.commands.byId('window.panelAlways.${panel.id}') case final command?)
                            menuCheckboxItem(command, viewModel!.panelsController.alwaysVisibility(panel.id), commandContext: context),
                        ],
                      const MenuDivider(),
                      _buildMenuButton(context, 'window.resetLayout'),
                      ..._extensionTail(context, 'Window'),
                    ],
                    child: const Text(
                      'Window',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ..._buildPluginMenus(context, EditorMenuPlacement.beforeHelp),
                  MenuButton(
                    subMenu: [
                      _buildMenuButton(context, 'help.about'),
                      ..._extensionTail(context, 'Help'),
                    ],
                    child: const Text(
                      'Help',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // The empty stretch of the title bar: drag to move the
              // window, double-click to maximize / restore.
              const Expanded(
                child: WindowDragArea(key: ValueKey('window_title_drag_area')),
              ),

              // Save & Quick Actions
              GhostButton(
                onPressed: () =>
                    viewModel?.commands.execute('file.saveLevel', context),
                child: const Icon(
                  LucideIcons.save,
                  size: 12,
                  color: EditorColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                tooltip: (context) => TooltipContainer(
                  child: Text(viewModel?.transactions.undoLabel ?? 'Undo'),
                ),
                child: GhostButton(
                  onPressed:
                      (viewModel?.commands.byId('edit.undo')?.canExecute() ??
                          false)
                      ? () => viewModel?.commands.execute('edit.undo', context)
                      : null,
                  child: Icon(
                    LucideIcons.undo,
                    size: 12,
                    color:
                        (viewModel?.commands.byId('edit.undo')?.canExecute() ??
                            false)
                        ? EditorColors.foreground
                        : EditorColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                tooltip: (context) => TooltipContainer(
                  child: Text(viewModel?.transactions.redoLabel ?? 'Redo'),
                ),
                child: GhostButton(
                  onPressed:
                      (viewModel?.commands.byId('edit.redo')?.canExecute() ??
                          false)
                      ? () => viewModel?.commands.execute('edit.redo', context)
                      : null,
                  child: Icon(
                    LucideIcons.redo,
                    size: 12,
                    color:
                        (viewModel?.commands.byId('edit.redo')?.canExecute() ??
                            false)
                        ? EditorColors.foreground
                        : EditorColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: EditorColors.background,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.map,
                      size: 10,
                      color: EditorColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeLevelName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.foreground,
                      ),
                    ),
                    // Source control dirty marker: level .lmas or generated
                    // L_*.dart differs from HEAD.
                    if (viewModel?.sourceControl.isLevelDirty(
                          activeLevelName,
                        ) ??
                        false) ...[
                      const SizedBox(width: 5),
                      Tooltip(
                        tooltip: (_) => TooltipContainer(
                          child: const Text('Level has uncommitted changes'),
                        ),
                        child: Container(
                          key: const ValueKey('sc_level_dirty'),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: EditorColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Minimize, maximize ⇄ restore, fullscreen, close.
              const LuminaWindowControls(height: 30),
            ],
          ),
        );
        final sc = viewModel?.sourceControl;
        final promptInit = sc != null && sc.shouldPromptInit;
        final legacyUnits = viewModel?.project.isLegacyMetreProject ?? false;
        if (!promptInit && !legacyUnits) return bar;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            if (legacyUnits) const LegacyUnitsBanner(),
            if (promptInit) InitRepoPrompt(viewModel: sc),
          ],
        );
      },
    );
  }
}
