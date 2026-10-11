import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorPanelDock;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_dialogs.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Docks the host's panels in the editor like plugin panels: `left` /
/// `bottom` as bottom-panel tabs and `right` in the right dock (Window menu
/// entry, visibility persisted in the layout, the "Always" option), `tab`
/// as a workspace tab restored with the layout, `dialog` modally (opened
/// only by another panel of its owner), `projectSettings` as the owning
/// plugin's Project Settings section. A plugin's panels also get a
/// `Plugins/<Plugin>/<Title>` menu entry.
class EditorPanelDocking implements EditorPanelDockingTarget {
  EditorPanelDocking(this.host, this.vm) {
    host.docking = this;
  }

  final EditorPanelHost host;
  final EditorViewModel vm;
  bool _attached = false;
  final Set<String> _owners = {};
  final Set<String> _visible = {};
  String _signature = '';

  /// The id an editor panel has among plugin panels and tabs.
  static String descriptorId(String panelId) => 'editorPanel:$panelId';

  /// The panel id of a descriptor id, or null for another plugin's panel.
  static String? panelIdOf(String descriptorId) =>
      descriptorId.startsWith('editorPanel:') ? descriptorId.substring('editorPanel:'.length) : null;

  /// The layout key that remembers an open `tab` panel.
  static String tabLayoutKey(String panelId) => 'editorPanelTab:$panelId';

  /// The Window ▸ Editor Panels command of [panelId].
  static String commandId(String panelId) => 'window.editorPanel.$panelId';

  void attach() {
    if (_attached) return;
    _attached = true;
    host.addListener(_sync);
    vm.addListener(_followVisibility);
    _sync();
  }

  void dispose() {
    if (!_attached) return;
    host.removeListener(_sync);
    vm.removeListener(_followVisibility);
  }

  /// The panels the Window menu lists (no dialogs, no settings sections).
  List<EditorPanelRuntime> get menuPanels =>
      [for (final rt in host.panels.values) if (rt.info.dock.listedInMenu) rt]..sort((a, b) => a.title.compareTo(b.title));

  /// Opens [panelId] where it docks.
  @override
  void open(String panelId) {
    final rt = host.panel(panelId);
    if (rt == null) return;
    switch (rt.info.dock) {
      case LuminaEditorPanelDock.tab:
        vm.layoutState.pluginPanelVisible[tabLayoutKey(panelId)] = true;
        vm.saveLayoutState();
        vm.extensionRegistry.openTab(descriptorId(panelId), title: rt.title);
      case LuminaEditorPanelDock.dialog:
        unawaited(showEditorPanelDialog(host, panelId));
      case LuminaEditorPanelDock.projectSettings:
        vm.openSubEditorTab('projectSettings', title: 'Project Settings');
      case LuminaEditorPanelDock.left:
      case LuminaEditorPanelDock.right:
      case LuminaEditorPanelDock.bottom:
        vm.panelsController.show(descriptorId(panelId));
        host.open(panelId);
    }
  }

  /// Closes [panelId] (Destruct) and hides its slot.
  @override
  void close(String panelId) {
    final rt = host.panel(panelId);
    host.close(panelId);
    if (rt == null) return;
    if (rt.info.dock == LuminaEditorPanelDock.tab) {
      vm.layoutState.pluginPanelVisible.remove(tabLayoutKey(panelId));
      vm.saveLayoutState();
    } else if (rt.info.dock.listedInMenu) {
      vm.panelsController.hide(descriptorId(panelId));
    }
  }

  void _sync() {
    final byOwner = <String, List<EditorPanelRuntime>>{};
    for (final rt in host.panels.values) {
      (byOwner[rt.entry.owner] ??= []).add(rt);
    }
    final signature = [
      for (final rt in host.panels.values)
        '${rt.id}|${rt.title}|${rt.info.dock.name}|${rt.info.icon}|${rt.info.menuPath}|${rt.info.defaultAlwaysVisible}',
    ].join(';');
    if (signature != _signature) {
      _signature = signature;
      for (final owner in _owners.difference(byOwner.keys.toSet())) {
        vm.extensionRegistry.removeEditorPanelContributions(owner);
      }
      _owners
        ..clear()
        ..addAll(byOwner.keys);
      for (final e in byOwner.entries) {
        _register(e.key, e.value);
      }
      _restoreTabs();
    }
    _followVisibility();
  }

  void _register(String owner, List<EditorPanelRuntime> panels) {
    final plugin = owner == 'project' ? null : owner;
    final friendly = plugin == null ? null : vm.extensionRegistry.pluginTitle(plugin);
    final sections = <ProjectSettingsSection>[];
    vm.extensionRegistry.setEditorPanelContributions(owner, (ctx) {
      for (final rt in panels) {
        final id = descriptorId(rt.id);
        final icon = editorPanelIcon(rt.info.icon);
        Widget build(BuildContext _) => EditorPanelView(host: host, panelId: rt.id);
        switch (rt.info.dock) {
          case LuminaEditorPanelDock.tab:
            ctx.registerTab(EditorTabDescriptor(
              id: id,
              title: rt.title,
              icon: icon,
              builder: (_) => EditorPanelView(host: host, panelId: rt.id, closeOnDispose: true),
              contentDroppable: rt.info.contentDroppable,
              contentBrowserOpened: rt.info.contentBrowserOpened,
            ));
          case LuminaEditorPanelDock.left:
          case LuminaEditorPanelDock.right:
          case LuminaEditorPanelDock.bottom:
            ctx.registerPanel(EditorPanelDescriptor(
              id: id,
              title: rt.title,
              icon: icon,
              builder: build,
              defaultDock: switch (rt.info.dock) {
                LuminaEditorPanelDock.right => PanelDefaultDock.right,
                LuminaEditorPanelDock.left => PanelDefaultDock.left,
                _ => PanelDefaultDock.bottom,
              },
              defaultAlwaysVisible: rt.info.defaultAlwaysVisible,
            ));
          case LuminaEditorPanelDock.projectSettings:
            if (plugin != null && !sections.any((s) => s.id.startsWith('editorPanel:$owner/'))) {
              sections.add(ProjectSettingsSection(
                id: 'editorPanel:${rt.id}',
                title: rt.title,
                icon: icon,
                keywords: const ['editor panel'],
                builder: (_, settings) => EditorPanelView(host: host, panelId: rt.id, settings: settings, closeOnDispose: true),
              ));
            }
          case LuminaEditorPanelDock.dialog:
            break;
        }
        // A plugin's panel: Plugins/<Plugin>/<Title> (or its menuPath).
        if (plugin != null && rt.info.dock.listedInMenu) {
          ctx.registerMenuItem(
            rt.info.menuPathFor(pluginFriendlyName: friendly),
            EditorCommand(id: 'editorPanel.open.${rt.id}', label: rt.title, icon: icon, canExecute: () => true, execute: (_) => open(rt.id)),
          );
        }
      }
    }, plugin: plugin, settingsSections: sections);
    // Window ▸ Editor Panels lists every docked panel.
    for (final rt in panels) {
      if (!rt.info.dock.listedInMenu || vm.commands.byId(commandId(rt.id)) != null) continue;
      vm.commands.register(EditorCommand(
        id: commandId(rt.id),
        label: rt.title,
        icon: editorPanelIcon(rt.info.icon),
        canExecute: () => host.panel(rt.id) != null,
        execute: (_) => open(rt.id),
      ));
    }
  }

  void _restoreTabs() {
    for (final rt in host.panels.values) {
      if (rt.info.dock != LuminaEditorPanelDock.tab) continue;
      if (vm.layoutState.pluginPanelVisible[tabLayoutKey(rt.id)] != true) continue;
      if (vm.openTabs.any((t) => t.id == 'tab_${descriptorId(rt.id)}')) continue;
      vm.extensionRegistry.openTab(descriptorId(rt.id), title: rt.title);
    }
  }

  /// Side and bottom panels run while their slot is open: a right panel
  /// closed in the dock is Destructed; a bottom tab another tab covers
  /// keeps running without Tick.
  void _followVisibility() {
    for (final rt in host.panels.values) {
      final dock = rt.info.dock;
      if (!dock.listedInMenu || dock == LuminaEditorPanelDock.tab) continue;
      final id = descriptorId(rt.id);
      final visible = vm.panelsController.isVisible(id);
      final wasVisible = visible ? !_visible.add(rt.id) : _visible.remove(rt.id);
      if (dock == LuminaEditorPanelDock.right) {
        // Closed in the dock (it was shown and is not now): Destruct.
        if (!visible && wasVisible && host.isOpen(rt.id)) host.close(rt.id);
        final shownHere = vm.panelsController
            .shownRightPanels(levelTab: vm.currentTab.id == EditorViewModel.kLevelTabId)
            .any((p) => p.id == id);
        if (host.isOpen(rt.id)) host.setShown(rt.id, shownHere);
      } else if (host.isOpen(rt.id)) {
        host.setShown(rt.id, visible);
      }
    }
  }
}

/// A Lucide icon by its name (`pencil`, `box`, …); a panel icon otherwise.
IconData editorPanelIcon(String? name) => _icons[name?.toLowerCase()] ?? LucideIcons.panelRight;

const Map<String, IconData> _icons = {
  'pencil': LucideIcons.pencil,
  'box': LucideIcons.box,
  'boxes': LucideIcons.boxes,
  'wrench': LucideIcons.wrench,
  'settings': LucideIcons.settings,
  'layers': LucideIcons.layers,
  'list': LucideIcons.list,
  'folder': LucideIcons.folder,
  'image': LucideIcons.image,
  'sparkles': LucideIcons.sparkles,
  'wand': LucideIcons.wandSparkles,
  'move': LucideIcons.move,
  'ruler': LucideIcons.ruler,
  'grid': LucideIcons.grid3x3,
  'camera': LucideIcons.camera,
  'film': LucideIcons.film,
  'user': LucideIcons.user,
  'bot': LucideIcons.bot,
  'cpu': LucideIcons.cpu,
  'glasses': LucideIcons.glasses,
  'activity': LucideIcons.activity,
  'palette': LucideIcons.palette,
  'search': LucideIcons.search,
  'terminal': LucideIcons.terminal,
  'package': LucideIcons.package,
};
