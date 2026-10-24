import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/widgets/lumina_logo.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_controls.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_command.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorMenuPlacement;
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart' show PluginMenuEntry, PluginMenu;
import 'package:lumina_ui/ui/features/main_editor/shortcuts/editor_shortcuts_scope.dart' show DispatchCommandIntent;
import 'package:lumina_ui/ui/features/main_editor/views/menu_tree_builder.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/views/init_repo_prompt.dart';
import 'package:lumina_ui/ui/features/main_editor/views/legacy_units_banner.dart';

/// The editor's menu bar, which is also the window's title bar: the Aurora
/// 48 px row on the rail with the Prism L lockup at the left, the nine menus
/// (File Edit View Build Debug Tools Plugins Window Help, plus the menus
/// plugins add), the Ctrl K command field in the middle, and at the right
/// source control, undo, redo, the project · level chip (an amber dot while
/// the level is unsaved), then the editor's own window controls
/// (fullscreen, minimize, maximize, close). The empty stretch drags the
/// window; double-click maximizes.
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

  /// The row's height on the canvas.
  static const double height = 48;

  /// The empty title-bar stretch kept on each side of the command field.
  static const double dragMargin = 24;

  /// The project · level chip never grows past this; long names ellipsize.
  static const double chipMaxWidth = 240;

  /// The menus' order; plugin menus slot in before Window or before Help.
  static const List<String> menuTitles = ['File', 'Edit', 'View', 'Build', 'Debug', 'Tools', 'Plugins', 'Window', 'Help'];

  static TextStyle get _menuStyle =>
      EditorTypography.ui(fontSize: EditorTypography.bodySize, fontWeight: FontWeight.w600, color: EditorColors.foreground);

  static TextStyle get _itemStyle => EditorTypography.ui(fontSize: EditorTypography.bodySize);

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
              style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
            )
          : null,
      enabled: canExec,
      onPressed: canExec ? (ctx) => viewModel?.commands.execute(id, commandContext ?? ctx) : null,
      child: Text(displayLabel, style: _itemStyle),
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
    final showHint = entries.any((e) => e.tooltip == SourceControlViewModel.installHint);
    return [
      if (showHint)
        MenuLabel(
          child: SizedBox(
            width: 220,
            child: Text(
              SourceControlViewModel.installHint,
              style: EditorTypography.ui(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground),
            ),
          ),
        ),
      for (final e in entries) _buildMenuButton(context, e.id),
    ];
  }

  /// A registry item: the shared [menuTreeButton] (disabled, with the
  /// reason on hover, while its plugin's process is not running).
  MenuButton _buildCommandMenuButton(BuildContext context, EditorCommand cmd, {BuildContext? commandContext}) =>
      menuTreeButton(cmd, commandContext: commandContext);

  MenuItem _buildToolItem(BuildContext context, EditorCommand cmd, {BuildContext? commandContext}) {
    if (viewModel?.commands.byId(cmd.id) != null) {
      return _buildMenuButton(context, cmd.id, commandContext: commandContext);
    }
    return _buildCommandMenuButton(context, cmd, commandContext: commandContext);
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
    final entries = _entriesUnder('Plugins')
      ..sort((a, b) => a.path.first.toLowerCase().compareTo(b.path.first.toLowerCase()));
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
      child: Text('Plugins', style: _menuStyle),
    );
  }

  /// The plugin-owned top-level menus placed at [placement].
  List<MenuButton> _buildPluginMenus(BuildContext context, EditorMenuPlacement placement) => [
        for (final m in viewModel?.extensionRegistry.pluginMenus ?? const <PluginMenu>[])
          if (m.menu.placement == placement)
            MenuButton(
              key: ValueKey('plugin_menu_${m.menu.id}'),
              subMenu: _registryItems(context, m.menu.title),
              child: Text(m.menu.title, style: _menuStyle),
            ),
      ];

  /// Built-in registry items appended to a fixed menu (Window, Help), after
  /// a divider.
  List<MenuItem> _extensionTail(BuildContext context, String root) {
    final items = _registryItems(context, root);
    return items.isEmpty ? const [] : [const MenuDivider(), ...items];
  }

  List<MenuButton> _menus(BuildContext context) => [
        MenuButton(
          subMenu: [
            _buildMenuButton(context, 'file.newLevel'),
            _buildMenuButton(context, 'file.openLevel'),
            _buildMenuButton(context, 'file.saveLevel'),
            _buildMenuButton(context, 'file.saveAll'),
            _buildMenuButton(context, 'file.newAsset'),
            // The picker and summary dialog open after the menu has closed.
            _buildMenuButton(context, 'file.importAssetFolder', commandContext: context),
            const MenuDivider(),
            _buildMenuButton(context, 'file.exitStudio'),
          ],
          child: Text('File', style: _menuStyle),
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
          child: Text('Edit', style: _menuStyle),
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
          child: Text('View', style: _menuStyle),
        ),
        MenuButton(
          subMenu: [
            _buildMenuButton(context, 'build.generateDartCode'),
            _buildMenuButton(context, 'build.buildManager'),
            _buildMenuButton(context, 'build.buildNavigation'),
            _buildMenuButton(context, 'build.buildAll'),
            _buildMenuButton(context, 'build.cookAndPackage'),
          ],
          child: Text('Build', style: _menuStyle),
        ),
        MenuButton(
          subMenu: [
            _buildMenuButton(context, 'debug.togglePie'),
            _buildMenuButton(context, 'debug.playStandalone'),
            _buildMenuButton(context, 'debug.pausePie'),
            _buildMenuButton(context, 'debug.stepPie'),
            _buildMenuButton(context, 'debug.stopPie'),
          ],
          child: Text('Debug', style: _menuStyle),
        ),
        MenuButton(
          subMenu: [
            ..._buildToolsMenuCommands(context),
            const MenuDivider(),
            // The editor's MCP server for AI agents.
            _buildMenuButton(context, 'tools.aiAgentAccess'),
            // Skills + AGENTS.md / CLAUDE.md for AI agents; asks before
            // replacing edited files, after the menu closed.
            _buildMenuButton(context, 'tools.aiAgentFiles', commandContext: context),
            const MenuDivider(),
            // Empties the project's DerivedDataCache/.
            _buildMenuButton(context, 'tools.clearDerivedDataCache'),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(LucideIcons.gitBranch, size: 14),
              subMenu: _sourceControlSubMenu(context),
              child: Text('Source Control', style: _itemStyle),
            ),
          ],
          child: Text('Tools', style: _menuStyle),
        ),
        // Everything plugin-related, then the menus plugins own.
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
            // One checked entry per plugin panel; a right-dock panel's is
            // followed by its "Show in Every Editor" row.
            if (viewModel != null)
              for (final panel in viewModel!.allPluginPanels)
                if (EditorPanelDocking.panelIdOf(panel.id) == null) ...[
                  if (viewModel!.commands.byId('window.panel.${panel.id}') case final command?)
                    menuCheckboxItem(command, viewModel!.panelsController.visibility(panel.id), commandContext: context),
                  if (viewModel!.commands.byId('window.panelAlways.${panel.id}') case final command?)
                    menuCheckboxItem(command, viewModel!.panelsController.alwaysVisibility(panel.id),
                        commandContext: context),
                ],
            // Window ▸ Editor Panels: the project's and plugins' editor
            // panel Widget Blueprints.
            if (viewModel != null && viewModel!.editorPanelDocking.menuPanels.isNotEmpty)
              MenuButton(
                key: const ValueKey('window_editor_panels'),
                leading: const Icon(LucideIcons.panelsTopLeft, size: 14),
                subMenu: [
                  for (final rt in viewModel!.editorPanelDocking.menuPanels)
                    if (viewModel!.commands.byId(EditorPanelDocking.commandId(rt.id)) case final command?)
                      menuCheckboxItem(
                          command, viewModel!.panelsController.visibility(EditorPanelDocking.descriptorId(rt.id)),
                          commandContext: context),
                ],
                child: Text('Editor Panels', style: _itemStyle),
              ),
            const MenuDivider(),
            _buildMenuButton(context, 'window.resetLayout'),
            ..._extensionTail(context, 'Window'),
          ],
          child: Text('Window', style: _menuStyle),
        ),
        ..._buildPluginMenus(context, EditorMenuPlacement.beforeHelp),
        MenuButton(
          subMenu: [
            _buildMenuButton(context, 'help.about'),
            ..._extensionTail(context, 'Help'),
          ],
          child: Text('Help', style: _menuStyle),
        ),
      ];

  /// The source-control button: the branch icon with a dot in the status
  /// colour, opening the Source Control entries in a dropdown.
  Widget _sourceControlButton(BuildContext context) {
    final sc = viewModel?.sourceControl;
    final dirty = sc?.isLevelDirty(activeLevelName) ?? false;
    return Tooltip(
      tooltip: (_) => const TooltipContainer(child: Text('Source Control')),
      child: GhostButton(
        key: const ValueKey('menu_bar_source_control'),
        density: ButtonDensity.icon,
        onPressed: sc == null
            ? null
            : () => showDropdown(
                  context: context,
                  builder: (ctx) => DropdownMenu(children: _sourceControlSubMenu(ctx)),
                ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(LucideIcons.gitBranch, size: 14, color: EditorColors.foreground),
            if (dirty)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  key: const ValueKey('sc_level_dirty'),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: EditorColors.warning, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _historyButton(BuildContext context, {required String id, required IconData icon, required String fallback}) {
    final can = viewModel?.commands.byId(id)?.canExecute() ?? false;
    final label = id == 'edit.undo' ? viewModel?.transactions.undoLabel : viewModel?.transactions.redoLabel;
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(label ?? fallback)),
      child: GhostButton(
        key: ValueKey('menu_bar_$id'),
        density: ButtonDensity.icon,
        onPressed: can ? () => viewModel?.commands.execute(id, context) : null,
        child: Icon(icon, size: 14, color: can ? EditorColors.foreground : EditorColors.mutedForeground),
      ),
    );
  }

  /// `Project · Level` with the amber dot while the level has unsaved
  /// changes; Save on click.
  Widget _projectChip(BuildContext context) {
    final project = viewModel?.project.projectName;
    final unsaved = viewModel?.project.isDirty ?? false;
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(unsaved ? 'Unsaved changes · Save (Ctrl S)' : 'Save (Ctrl S)')),
      child: GestureDetector(
        key: const ValueKey('menu_bar_project_chip'),
        behavior: HitTestBehavior.opaque,
        onTap: () => viewModel?.commands.execute('file.saveLevel', context),
        child: Container(
          height: 28,
          constraints: const BoxConstraints(maxWidth: chipMaxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: EditorColors.sidebar,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EditorColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  [
                    if (project != null && project.isNotEmpty) project,
                    activeLevelName.endsWith('.lmas') ? activeLevelName.substring(0, activeLevelName.length - 5) : activeLevelName,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EditorTypography.ui(
                      fontSize: EditorTypography.labelSize, fontWeight: FontWeight.w600, color: EditorColors.foreground),
                ),
              ),
              if (unsaved) ...[
                const SizedBox(width: 6),
                Container(
                  key: const ValueKey('menu_bar_unsaved_dot'),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return ListenableBuilder(
      // Plugin (re)registration changes the Plugins menu and the plugin menus.
      listenable: vm == null ? ChangeNotifier() : Listenable.merge([vm.commands, vm.extensionRegistry]),
      builder: (context, _) {
        final bar = Container(
          height: height,
          // This row is the window's title bar. The window buttons sit flush
          // at its right end; macOS keeps room for its traffic lights at the
          // left.
          padding: EdgeInsets.only(left: 12 + LuminaWindow.leadingInset),
          decoration: const BoxDecoration(
            color: EditorColors.rail,
            border: Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Row(
            children: [
              // The Prism L lockup: the mark beside LUMINA / Studio.
              const LuminaLockup(markSize: 26),
              const SizedBox(width: 16),
              // Plain menu titles on the rail, as on the canvas: no box around them.
              Menubar(border: false, children: _menus(context)),
              // The empty stretch of the title bar: drag to move the window,
              // double-click to maximize / restore. The command field floats
              // in its middle and reacts to the raw pointer, so its tap never
              // waits for the double-click gesture to time out.
              Expanded(
                child: WindowDragArea(
                  key: const ValueKey('window_title_drag_area'),
                  // The margin keeps an empty stretch to drag on either side
                  // of the field, however narrow the window.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: dragMargin),
                    child: Center(child: EditorCommandField(enabled: vm != null)),
                  ),
                ),
              ),
              _sourceControlButton(context),
              const SizedBox(width: 2),
              _historyButton(context, id: 'edit.undo', icon: LucideIcons.undo, fallback: 'Undo'),
              _historyButton(context, id: 'edit.redo', icon: LucideIcons.redo, fallback: 'Redo'),
              const SizedBox(width: 8),
              _projectChip(context),
              const SizedBox(width: 8),
              // Fullscreen, minimize, maximize ⇄ restore, close.
              const LuminaWindowControls(height: height),
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

/// The command field in the middle of the menu bar: a search-shaped button
/// that opens the quick-open palette (assets and commands), the same one
/// Ctrl K and Ctrl P open from the keyboard. It listens to the raw pointer
/// (down and up inside its bounds), not to a tap gesture: it sits inside the
/// title bar's drag area, whose double-click recognizer would otherwise hold
/// every tap in the gesture arena for the double-click timeout.
class EditorCommandField extends StatefulWidget {
  const EditorCommandField({super.key, this.enabled = true, this.width = 260});

  final bool enabled;
  final double width;

  @override
  State<EditorCommandField> createState() => _EditorCommandFieldState();
}

class _EditorCommandFieldState extends State<EditorCommandField> {
  int? _pointer;

  void _open() => Actions.maybeInvoke(context, const DispatchCommandIntent('shell.quickOpen'));

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final width = widget.width;
    return Listener(
      key: const ValueKey('menu_bar_command_field'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (e) => _pointer = e.pointer : null,
      onPointerCancel: (e) => _pointer = null,
      onPointerUp: enabled
          ? (e) {
              if (_pointer != e.pointer) return;
              _pointer = null;
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.paintBounds.contains(box.globalToLocal(e.position))) _open();
            }
          : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: BoxConstraints(maxWidth: width),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: EditorColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EditorColors.fieldBorder),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 13, color: EditorColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search assets and commands',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EditorTypography.ui(fontSize: EditorTypography.bodySize, color: EditorColors.mutedForeground),
                ),
              ),
              Text('Ctrl K',
                  style: EditorTypography.mono(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
