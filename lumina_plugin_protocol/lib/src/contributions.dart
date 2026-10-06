import 'view_spec.dart';

/// An icon as data: the fields of Flutter's `IconData`.
class PluginIconSpec {
  const PluginIconSpec(this.codePoint, {this.fontFamily, this.fontPackage, this.matchTextDirection = false});

  final int codePoint;
  final String? fontFamily;
  final String? fontPackage;
  final bool matchTextDirection;

  Map<String, Object?> toJson() => {
        'codePoint': codePoint,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontPackage != null) 'fontPackage': fontPackage,
        if (matchTextDirection) 'matchTextDirection': true,
      };

  static PluginIconSpec? fromJson(Object? json) {
    if (json is! Map || json['codePoint'] is! int) return null;
    return PluginIconSpec(
      json['codePoint'] as int,
      fontFamily: json['fontFamily'] as String?,
      fontPackage: json['fontPackage'] as String?,
      matchTextDirection: json['matchTextDirection'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PluginIconSpec &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage &&
      other.matchTextDirection == matchTextDirection;

  @override
  int get hashCode => Object.hash(codePoint, fontFamily, fontPackage, matchTextDirection);
}

/// A command the host shows (menu item, slot button, slot menu entry) and
/// runs in the plugin process (`core.command`).
class PluginCommandSpec {
  const PluginCommandSpec({
    required this.id,
    required this.label,
    this.icon,
    this.shortcutLabel = '',
    this.dynamicEnablement = false,
  });

  final String id;
  final String label;
  final PluginIconSpec? icon;
  final String shortcutLabel;

  /// When true the host asks `core.canExecute` before showing the command
  /// enabled (answers are cached briefly); otherwise it is always enabled.
  final bool dynamicEnablement;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        if (icon != null) 'icon': icon!.toJson(),
        if (shortcutLabel.isNotEmpty) 'shortcutLabel': shortcutLabel,
        if (dynamicEnablement) 'dynamicEnablement': true,
      };

  static PluginCommandSpec fromJson(Map<String, Object?> json) => PluginCommandSpec(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        icon: PluginIconSpec.fromJson(json['icon']),
        shortcutLabel: json['shortcutLabel'] as String? ?? '',
        dynamicEnablement: json['dynamicEnablement'] == true,
      );
}

/// `LuminaEditorContext.registerMenuItem` as data.
class PluginMenuItemSpec {
  const PluginMenuItemSpec({required this.path, required this.command, this.order = 0, this.section, this.checked});

  final String path;
  final PluginCommandSpec command;
  final int order;
  final String? section;

  /// Null: no check mark. Otherwise the initial state; later states arrive
  /// with `host.menuChecked`.
  final bool? checked;

  Map<String, Object?> toJson() => {
        'path': path,
        'command': command.toJson(),
        if (order != 0) 'order': order,
        if (section != null) 'section': section,
        if (checked != null) 'checked': checked,
      };

  static PluginMenuItemSpec fromJson(Map<String, Object?> json) => PluginMenuItemSpec(
        path: json['path'] as String,
        command: PluginCommandSpec.fromJson((json['command'] as Map).cast()),
        order: json['order'] as int? ?? 0,
        section: json['section'] as String?,
        checked: json['checked'] as bool?,
      );
}

/// `EditorMenuDescriptor` as data.
class PluginMenuSpec {
  const PluginMenuSpec({required this.id, required this.title, this.placement = 'beforeWindow', this.order = 0});

  final String id;
  final String title;

  /// `EditorMenuPlacement.name`.
  final String placement;
  final int order;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'placement': placement, 'order': order};

  static PluginMenuSpec fromJson(Map<String, Object?> json) => PluginMenuSpec(
        id: json['id'] as String,
        title: json['title'] as String,
        placement: json['placement'] as String? ?? 'beforeWindow',
        order: json['order'] as int? ?? 0,
      );
}

/// `EditorButtonState` as data (tone = `EditorTone.name`).
class PluginButtonStateSpec {
  const PluginButtonStateSpec({
    required this.icon,
    required this.tooltip,
    this.label,
    this.tone = 'neutral',
    this.enabled = true,
    this.active = false,
    this.badge,
    this.busy = false,
  });

  final PluginIconSpec icon;
  final String tooltip;
  final String? label;
  final String tone;
  final bool enabled;
  final bool active;
  final String? badge;
  final bool busy;

  Map<String, Object?> toJson() => {
        'icon': icon.toJson(),
        'tooltip': tooltip,
        if (label != null) 'label': label,
        'tone': tone,
        'enabled': enabled,
        'active': active,
        if (badge != null) 'badge': badge,
        'busy': busy,
      };

  static PluginButtonStateSpec fromJson(Map<String, Object?> json) => PluginButtonStateSpec(
        icon: PluginIconSpec.fromJson(json['icon']) ?? const PluginIconSpec(0xe000),
        tooltip: json['tooltip'] as String? ?? '',
        label: json['label'] as String?,
        tone: json['tone'] as String? ?? 'neutral',
        enabled: json['enabled'] != false,
        active: json['active'] == true,
        badge: json['badge'] as String?,
        busy: json['busy'] == true,
      );
}

/// `EditorSlotButton` as data (slot = `EditorSlot.name`); state changes
/// arrive with `host.slotState`.
class PluginSlotButtonSpec {
  const PluginSlotButtonSpec({
    required this.id,
    required this.slot,
    required this.state,
    required this.command,
    this.order = 0,
    this.menu,
  });

  final String id;
  final String slot;
  final PluginButtonStateSpec state;
  final PluginCommandSpec command;
  final int order;
  final List<PluginCommandSpec>? menu;

  Map<String, Object?> toJson() => {
        'id': id,
        'slot': slot,
        'state': state.toJson(),
        'command': command.toJson(),
        if (order != 0) 'order': order,
        if (menu != null) 'menu': [for (final c in menu!) c.toJson()],
      };

  static PluginSlotButtonSpec fromJson(Map<String, Object?> json) => PluginSlotButtonSpec(
        id: json['id'] as String,
        slot: json['slot'] as String,
        state: PluginButtonStateSpec.fromJson((json['state'] as Map).cast()),
        command: PluginCommandSpec.fromJson((json['command'] as Map).cast()),
        order: json['order'] as int? ?? 0,
        menu: (json['menu'] as List?)?.map((e) => PluginCommandSpec.fromJson((e as Map).cast())).toList(),
      );
}

/// An MCP tool as data; calls run in the plugin process (`core.mcpTool`).
/// The fields mirror `McpTool` (risk = `McpToolRisk.name`).
class PluginMcpToolSpec {
  const PluginMcpToolSpec({
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    this.risk = 'read',
    this.groups = const [],
    this.idempotent = false,
    this.openWorld = false,
    this.removesContent = false,
  });

  final String name;
  final String title;
  final String description;
  final Map<String, Object?> inputSchema;
  final String risk;
  final List<String> groups;
  final bool idempotent;
  final bool openWorld;
  final bool removesContent;

  Map<String, Object?> toJson() => {
        'name': name,
        'title': title,
        'description': description,
        'inputSchema': inputSchema,
        'risk': risk,
        'groups': groups,
        'idempotent': idempotent,
        'openWorld': openWorld,
        'removesContent': removesContent,
      };

  static PluginMcpToolSpec fromJson(Map<String, Object?> json) => PluginMcpToolSpec(
        name: json['name'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        inputSchema: (json['inputSchema'] as Map?)?.cast<String, Object?>() ?? const {'type': 'object'},
        risk: json['risk'] as String? ?? 'read',
        groups: (json['groups'] as List?)?.cast<String>() ?? const [],
        idempotent: json['idempotent'] == true,
        openWorld: json['openWorld'] == true,
        removesContent: json['removesContent'] == true,
      );
}

/// `EditorImporter` as data; imports run in the plugin process (`core.import`).
class PluginImporterSpec {
  const PluginImporterSpec({required this.id, required this.extensions, required this.description});

  final String id;
  final List<String> extensions;
  final String description;

  Map<String, Object?> toJson() => {'id': id, 'extensions': extensions, 'description': description};

  static PluginImporterSpec fromJson(Map<String, Object?> json) => PluginImporterSpec(
        id: json['id'] as String,
        extensions: (json['extensions'] as List).cast<String>(),
        description: json['description'] as String? ?? '',
      );
}

/// A console command; runs in the plugin process (`core.console`).
class PluginConsoleCommandSpec {
  const PluginConsoleCommandSpec({required this.name, required this.help});

  final String name;
  final String help;

  Map<String, Object?> toJson() => {'name': name, 'help': help};

  static PluginConsoleCommandSpec fromJson(Map<String, Object?> json) =>
      PluginConsoleCommandSpec(name: json['name'] as String, help: json['help'] as String? ?? '');
}

/// A panel whose content is a [PluginViewSpec] the host renders; events go
/// to the plugin process (`core.viewEvent`), updates come back with
/// `host.view`. (dock = `PanelDefaultDock.name`)
class PluginViewPanelSpec {
  const PluginViewPanelSpec({
    required this.id,
    required this.title,
    required this.view,
    this.icon,
    this.dock = 'left',
    this.defaultAlwaysVisible = false,
  });

  final String id;
  final String title;
  final PluginIconSpec? icon;
  final String dock;
  final bool defaultAlwaysVisible;
  final PluginViewSpec view;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        if (icon != null) 'icon': icon!.toJson(),
        'dock': dock,
        if (defaultAlwaysVisible) 'defaultAlwaysVisible': true,
        'view': view.toJson(),
      };

  static PluginViewPanelSpec fromJson(Map<String, Object?> json) => PluginViewPanelSpec(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        icon: PluginIconSpec.fromJson(json['icon']),
        dock: json['dock'] as String? ?? 'left',
        defaultAlwaysVisible: json['defaultAlwaysVisible'] == true,
        view: PluginViewSpec.fromJson((json['view'] as Map).cast()),
      );
}

/// Everything an isolated plugin registers, sent once with `host.register`.
class PluginContributions {
  const PluginContributions({
    this.menus = const [],
    this.menuItems = const [],
    this.slotButtons = const [],
    this.mcpTools = const [],
    this.importers = const [],
    this.consoleCommands = const [],
    this.panels = const [],
  });

  final List<PluginMenuSpec> menus;
  final List<PluginMenuItemSpec> menuItems;
  final List<PluginSlotButtonSpec> slotButtons;
  final List<PluginMcpToolSpec> mcpTools;
  final List<PluginImporterSpec> importers;
  final List<PluginConsoleCommandSpec> consoleCommands;
  final List<PluginViewPanelSpec> panels;

  bool get isEmpty =>
      menus.isEmpty &&
      menuItems.isEmpty &&
      slotButtons.isEmpty &&
      mcpTools.isEmpty &&
      importers.isEmpty &&
      consoleCommands.isEmpty &&
      panels.isEmpty;

  Map<String, Object?> toJson() => {
        'menus': [for (final x in menus) x.toJson()],
        'menuItems': [for (final x in menuItems) x.toJson()],
        'slotButtons': [for (final x in slotButtons) x.toJson()],
        'mcpTools': [for (final x in mcpTools) x.toJson()],
        'importers': [for (final x in importers) x.toJson()],
        'consoleCommands': [for (final x in consoleCommands) x.toJson()],
        'panels': [for (final x in panels) x.toJson()],
      };

  static PluginContributions fromJson(Map<String, Object?> json) {
    List<T> list<T>(String key, T Function(Map<String, Object?>) f) =>
        [for (final e in (json[key] as List?) ?? const []) f((e as Map).cast())];
    return PluginContributions(
      menus: list('menus', PluginMenuSpec.fromJson),
      menuItems: list('menuItems', PluginMenuItemSpec.fromJson),
      slotButtons: list('slotButtons', PluginSlotButtonSpec.fromJson),
      mcpTools: list('mcpTools', PluginMcpToolSpec.fromJson),
      importers: list('importers', PluginImporterSpec.fromJson),
      consoleCommands: list('consoleCommands', PluginConsoleCommandSpec.fromJson),
      panels: list('panels', PluginViewPanelSpec.fromJson),
    );
  }
}
