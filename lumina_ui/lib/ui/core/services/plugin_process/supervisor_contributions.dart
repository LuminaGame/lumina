part of 'plugin_process_supervisor.dart';

/// The icon of a [PluginIconSpec]: a Lucide icon maps back to its constant
/// (release builds tree-shake icon fonts and refuse non-constant
/// `IconData`); any other font shows the plug icon.
IconData? _iconOf(PluginIconSpec? spec) {
  if (spec == null) return null;
  if (spec.fontFamily == 'LucideIcons') return kLucideIconsByCodePoint[spec.codePoint] ?? LucideIcons.plug;
  return LucideIcons.plug;
}

T _byName<T extends Enum>(List<T> values, String name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;

/// A menu item, slot button or slot menu entry of an isolated plugin: runs
/// in its process (`core.command`) and is disabled, with the reason, while
/// the process is not running.
class ProcessBackedCommand extends EditorCommand {
  ProcessBackedCommand._(this.supervisor, this.spec)
      : super(
          id: spec.id,
          label: spec.label,
          icon: _iconOf(spec.icon),
          shortcutLabel: spec.shortcutLabel,
          canExecute: () => supervisor._canExecute(spec),
          execute: (_) => supervisor._runCommand(spec),
        );

  final PluginProcessSupervisor supervisor;
  final PluginCommandSpec spec;

  /// "`<plugin>` stopped: `<reason>`" while the process is not running.
  String? get unavailableReason => supervisor.unavailableReason;
}

/// The live look of a process slot button: the plugin's last
/// [PluginButtonStateSpec], disabled with the reason as tooltip while the
/// process is not running.
class _SlotState {
  _SlotState(this.spec, EditorButtonState initial) : notifier = ValueNotifier(initial);

  PluginButtonStateSpec spec;
  final ValueNotifier<EditorButtonState> notifier;
}

extension _Contributions on PluginProcessSupervisor {
  void _applyContributions(PluginContributions c) {
    host.registerProcessContributions(pluginName, (context) {
      for (final m in c.menus) {
        context.registerMenu(EditorMenuDescriptor(
          id: m.id,
          title: m.title,
          placement: _byName(EditorMenuPlacement.values, m.placement, EditorMenuPlacement.beforeWindow),
          order: m.order,
        ));
      }
      for (final item in c.menuItems) {
        context.registerMenuItem(
          item.path,
          ProcessBackedCommand._(this, item.command),
          options: EditorMenuItemOptions(
            order: item.order,
            section: item.section,
            checked: item.checked == null ? null : _checkedNotifier(item.path, item.checked!),
          ),
        );
      }
      for (final b in c.slotButtons) {
        context.registerSlotButton(EditorSlotButton(
          id: b.id,
          slot: _byName(EditorSlot.values, b.slot, EditorSlot.levelToolbarEnd),
          state: _slotNotifier(b.id, b.state),
          command: ProcessBackedCommand._(this, b.command),
          order: b.order,
          menu: b.menu == null ? null : [for (final m in b.menu!) ProcessBackedCommand._(this, m)],
        ));
      }
      for (final t in c.mcpTools) {
        final groups = {...t.groups}.intersection(McpToolGroups.known);
        context.mcp.registerTool(McpTool(
          name: t.name,
          title: t.title.isEmpty ? null : t.title,
          description: t.description,
          inputSchema: t.inputSchema,
          handler: (args) => _callTool(t.name, args.raw),
          risk: McpToolRisk.parse(t.risk) ?? McpToolRisk.readOnly,
          groups: groups.isEmpty ? {McpToolGroups.plugin} : groups,
          idempotent: t.idempotent,
          openWorld: t.openWorld,
          removesContent: t.removesContent,
        ));
      }
      for (final i in c.importers) {
        context.registerImporter(EditorImporter(
          extensions: i.extensions,
          description: i.description,
          import: (file, ctx) => _runImport(i.id, file.path, ctx.targetDirectory),
        ));
      }
      for (final cmd in c.consoleCommands) {
        context.registerConsoleCommand(cmd.name, cmd.help, (args) => unawaited(_runConsole(cmd.name, args)));
      }
      for (final panel in c.panels) {
        _viewNotifier(panel.view.id).value = panel.view;
        context.registerPanel(EditorPanelDescriptor(
          id: panel.id,
          title: panel.title,
          icon: _iconOf(panel.icon) ?? LucideIcons.plug,
          defaultDock: _byName(PanelDefaultDock.values, panel.dock, PanelDefaultDock.left),
          defaultAlwaysVisible: panel.defaultAlwaysVisible,
          builder: (BuildContext context) => _panelBody(panel.view.id),
        ));
      }
    });
  }

  Widget _panelBody(String viewId) => PluginProcessPanelView(
        view: _viewNotifier(viewId),
        projectDir: host.projectInfo?.dir,
        onEvent: (event) => unawaited(_sendViewEvent(event)),
      );

  ValueNotifier<PluginViewSpec> _viewNotifier(String viewId) =>
      _views.putIfAbsent(viewId, () => ValueNotifier(PluginViewSpec(id: viewId)));

  ValueNotifier<bool> _checkedNotifier(String path, bool initial) =>
      _checked.putIfAbsent(path, () => ValueNotifier(initial))..value = initial;

  ValueNotifier<EditorButtonState> _slotNotifier(String id, PluginButtonStateSpec spec) {
    final slot = _slots.putIfAbsent(id, () => _SlotState(spec, _buttonState(spec)));
    slot.spec = spec;
    slot.notifier.value = _buttonState(spec);
    return slot.notifier;
  }

  EditorButtonState _buttonState(PluginButtonStateSpec spec) {
    final reason = unavailableReason;
    return EditorButtonState(
      icon: _iconOf(spec.icon) ?? LucideIcons.plug,
      tooltip: reason ?? spec.tooltip,
      label: spec.label,
      tone: _byName(EditorTone.values, spec.tone, EditorTone.neutral),
      enabled: reason == null && spec.enabled,
      active: spec.active,
      badge: spec.badge,
      busy: _state.value.status == PluginProcessStatus.starting || spec.busy,
    );
  }

  void _refreshSlots() {
    for (final s in _slots.values) {
      s.notifier.value = _buttonState(s.spec);
    }
  }

  bool _canExecute(PluginCommandSpec spec) {
    if (!_state.value.isAvailable) return false;
    if (!spec.dynamicEnablement) return true;
    final cached = _canExecuteCache[spec.id];
    final now = DateTime.now();
    if (cached == null || now.difference(cached.$2) > const Duration(seconds: 1)) {
      _canExecuteCache[spec.id] = (cached?.$1 ?? true, now);
      unawaited(_request(PluginMethods.canExecute, {'commandId': spec.id}, const Duration(seconds: 2)).then((v) {
        final can = v == true;
        if (_canExecuteCache[spec.id]?.$1 != can) {
          _canExecuteCache[spec.id] = (can, DateTime.now());
          host.processStateChanged(pluginName);
        }
      }, onError: (_) {}));
    }
    return _canExecuteCache[spec.id]!.$1;
  }

  Future<void> _runCommand(PluginCommandSpec spec) async {
    try {
      await _request(PluginMethods.command, {'commandId': spec.id}, timings.commandTimeout);
    } on PluginRemoteError catch (e) {
      host.logPlugin(pluginName, '${spec.label} failed: ${e.message}', level: 'error');
    }
  }

  Future<McpToolResult> _callTool(String tool, Map<String, Object?> args) async {
    try {
      final r = await _request(PluginMethods.mcpTool, {'tool': tool, 'arguments': args}, timings.mcpToolTimeout);
      return _toolResultOf(r);
    } on PluginRemoteError catch (e) {
      return McpToolResult.error(e.code == PluginErrorCodes.unavailable ? e.message : '$pluginName.$tool failed: ${e.message}');
    }
  }

  static McpToolResult _toolResultOf(Object? json) {
    if (json is! Map) return McpToolResult.json({'result': json});
    final content = [for (final c in (json['content'] as List?) ?? const []) if (c is Map) c.cast<String, Object?>()];
    final structured = json['structuredContent'];
    return McpToolResult(
      content,
      structuredContent: structured is Map ? structured.cast<String, Object?>() : null,
      isError: json['isError'] == true,
    );
  }

  Future<ImportResult> _runImport(String importerId, String sourcePath, String targetDirectory) async {
    try {
      final r = await _request(
        PluginMethods.import,
        {'importerId': importerId, 'sourcePath': sourcePath, 'targetDirectory': targetDirectory},
        timings.importTimeout,
      );
      final map = r is Map ? r : const {};
      return map['success'] == true
          ? ImportResult.success(map['assetPath'] as String?)
          : ImportResult.failure(map['error'] as String? ?? 'the importer failed');
    } on PluginRemoteError catch (e) {
      return ImportResult.failure(e.message);
    }
  }

  Future<void> _runConsole(String name, List<String> args) async {
    try {
      await _request(PluginMethods.console, {'name': name, 'args': args}, timings.commandTimeout);
    } on PluginRemoteError catch (e) {
      host.logPlugin(pluginName, '$name failed: ${e.message}', level: 'error');
    }
  }

  Future<void> _sendViewEvent(PluginViewEvent event) async {
    try {
      await _request(PluginMethods.viewEvent, event.toJson(), timings.commandTimeout);
    } on PluginRemoteError catch (e) {
      host.logPlugin(pluginName, 'panel ${event.viewId}: ${e.message}', level: 'warning');
    }
  }
}
