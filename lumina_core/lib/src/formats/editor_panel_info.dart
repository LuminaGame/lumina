import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Where an editor panel docks: a side or bottom panel, a workspace tab, a
/// modal dialog another panel of the same owner opens, or the owning plugin's
/// section in Project Settings.
enum LuminaEditorPanelDock {
  left,
  right,
  bottom,
  tab,
  dialog,
  projectSettings;

  /// Whether the panel is listed in a menu (dialogs and settings sections are not).
  bool get listedInMenu => this != dialog && this != projectSettings;

  /// The dock named [value] (`left`, `right`, `bottom`, `tab`), or null.
  static LuminaEditorPanelDock? tryParse(Object? value) {
    for (final d in values) {
      if (d.name == value) return d;
    }
    return null;
  }
}

/// What an editor panel's graph may do beyond reading: a node that needs an
/// undeclared capability is a validator error, so the declared list is
/// exactly what the panel can do.
enum LuminaEditorPanelCapability {
  /// Edit level actors through the level proxy.
  level,

  /// Write project assets (rename, move, duplicate, delete, save).
  assets,

  /// Call the owning plugin's process and receive its events.
  process,

  /// Expose custom events as MCP tools.
  mcp;

  /// The capability named [value], or null.
  static LuminaEditorPanelCapability? tryParse(Object? value) {
    for (final c in values) {
      if (c.name == value) return c;
    }
    return null;
  }
}

/// The `editorPanel` block of a Widget Blueprint `.lmas` payload: present,
/// the asset is an editor panel the editor docks and runs in its Blueprint VM
/// (never a game widget).
///
/// Only the fields an author wrote are written back, so a block round-trips
/// byte for byte.
class LuminaEditorPanelInfo {
  /// The payload key of the block.
  static const String payloadKey = 'editorPanel';

  /// The minimum width and height a panel docks at when the asset gives none.
  static const double defaultMinSize = 200;

  /// The menu folder project panels are listed under.
  static const String projectMenuFolder = 'Window/Editor Panels';

  final String title;

  /// A Lucide icon name (`pencil`, `box`), or null.
  final String? icon;

  final LuminaEditorPanelDock dock;
  final bool? _defaultAlwaysVisible;
  final bool? _contentDroppable;
  final bool? _contentBrowserOpened;
  final String? menuPath;
  final double? _minWidth;
  final double? _minHeight;

  /// The declared capabilities, in declaration order.
  final Set<LuminaEditorPanelCapability> capabilities;

  /// Whether the block listed `capabilities` (written back only then).
  final bool _hasCapabilities;

  /// Whether the block named its dock (written back only then).
  final bool _hasDock;

  LuminaEditorPanelInfo({
    required this.title,
    this.icon,
    LuminaEditorPanelDock? dock,
    this._defaultAlwaysVisible,
    this._contentDroppable,
    this._contentBrowserOpened,
    this.menuPath,
    this._minWidth,
    this._minHeight,
    Set<LuminaEditorPanelCapability>? capabilities,
  })  : dock = dock ?? LuminaEditorPanelDock.right,
        _hasDock = dock != null,
        capabilities = Set.unmodifiable(capabilities ?? const <LuminaEditorPanelCapability>{}),
        _hasCapabilities = capabilities != null;

  /// Whether the panel is shown in every editor tab by default.
  bool get defaultAlwaysVisible => _defaultAlwaysVisible ?? false;

  /// Whether elements flagged "Accepts Asset Drops" take Content Browser drops.
  bool get contentDroppable => _contentDroppable ?? false;

  /// Whether a `tab` panel opens with the Content Browser docked at its bottom.
  bool get contentBrowserOpened => _contentBrowserOpened ?? false;

  double get minWidth => _minWidth ?? defaultMinSize;
  double get minHeight => _minHeight ?? defaultMinSize;

  bool allows(LuminaEditorPanelCapability capability) => capabilities.contains(capability);

  /// The menu entry path: [menuPath] when given, else
  /// `Plugins/<plugin>/<title>` for a plugin's panel and
  /// `Window/Editor Panels/<title>` for a project's.
  String menuPathFor({String? pluginFriendlyName}) {
    final explicit = menuPath;
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    if (pluginFriendlyName != null && pluginFriendlyName.isNotEmpty) return 'Plugins/$pluginFriendlyName/$title';
    return '$projectMenuFolder/$title';
  }

  /// A short stable hash of the sorted capability list: the trust store keys
  /// a project panel's decision on it, so a panel whose capabilities grow asks
  /// again.
  String get capabilityHash {
    final names = [for (final c in capabilities) c.name]..sort();
    return sha256.convert(utf8.encode(names.join(','))).toString().substring(0, 16);
  }

  /// Parses and validates a block; a bad field throws a [FormatException]
  /// naming it.
  factory LuminaEditorPanelInfo.fromJson(Map<String, dynamic> map) {
    final title = map['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException("Editor panel field 'title' must be a non-empty string.");
    }
    final rawDock = map['dock'];
    LuminaEditorPanelDock? dock;
    if (rawDock != null) {
      dock = LuminaEditorPanelDock.tryParse(rawDock);
      if (dock == null) {
        throw FormatException("Editor panel field 'dock' must be left, right, bottom, tab, dialog or projectSettings (got '$rawDock').");
      }
    }
    final rawCaps = map['capabilities'];
    Set<LuminaEditorPanelCapability>? caps;
    if (rawCaps != null) {
      if (rawCaps is! List) throw const FormatException("Editor panel field 'capabilities' must be a list.");
      caps = <LuminaEditorPanelCapability>{};
      for (final c in rawCaps) {
        final cap = LuminaEditorPanelCapability.tryParse(c);
        if (cap == null) {
          throw FormatException("Editor panel field 'capabilities' has an unknown capability '$c' "
              '(known: ${LuminaEditorPanelCapability.values.map((v) => v.name).join(', ')}).');
        }
        caps.add(cap);
      }
    }
    bool? flag(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is! bool) throw FormatException("Editor panel field '$key' must be true or false.");
      return v;
    }

    double? size(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is! num || v <= 0) throw FormatException("Editor panel field '$key' must be a positive number.");
      return v.toDouble();
    }

    final icon = map['icon'];
    final menuPath = map['menuPath'];
    return LuminaEditorPanelInfo(
      title: title,
      icon: icon is String && icon.isNotEmpty ? icon : null,
      dock: dock,
      defaultAlwaysVisible: flag('defaultAlwaysVisible'),
      contentDroppable: flag('contentDroppable'),
      contentBrowserOpened: flag('contentBrowserOpened'),
      menuPath: menuPath is String && menuPath.isNotEmpty ? menuPath : null,
      minWidth: size('minWidth'),
      minHeight: size('minHeight'),
      capabilities: caps,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'icon': ?icon,
        if (_hasDock) 'dock': dock.name,
        'defaultAlwaysVisible': ?_defaultAlwaysVisible,
        'contentDroppable': ?_contentDroppable,
        'contentBrowserOpened': ?_contentBrowserOpened,
        'menuPath': ?menuPath,
        'minWidth': ?_jsonNumber(_minWidth),
        'minHeight': ?_jsonNumber(_minHeight),
        if (_hasCapabilities) 'capabilities': [for (final c in capabilities) c.name],
      };

  static num? _jsonNumber(double? v) => v == null ? null : (v == v.roundToDouble() ? v.toInt() : v);

  /// The block of a Widget Blueprint payload, or null when the asset is not
  /// an editor panel. A malformed block throws a [FormatException].
  static LuminaEditorPanelInfo? ofPayload(Map<String, dynamic>? payload) {
    final block = payload?[payloadKey];
    if (block is! Map) return null;
    return LuminaEditorPanelInfo.fromJson(Map<String, dynamic>.from(block));
  }

  /// Whether [payload] carries an `editorPanel` block (valid or not): such an
  /// asset is never a game widget.
  static bool isEditorPanelPayload(Map<String, dynamic>? payload) => payload?[payloadKey] is Map;

  /// A copy with the given fields replaced.
  LuminaEditorPanelInfo copyWith({
    String? title,
    String? icon,
    LuminaEditorPanelDock? dock,
    bool? defaultAlwaysVisible,
    bool? contentDroppable,
    bool? contentBrowserOpened,
    String? menuPath,
    double? minWidth,
    double? minHeight,
    Set<LuminaEditorPanelCapability>? capabilities,
  }) =>
      LuminaEditorPanelInfo(
        title: title ?? this.title,
        icon: icon ?? this.icon,
        dock: dock ?? (_hasDock ? this.dock : null),
        defaultAlwaysVisible: defaultAlwaysVisible ?? _defaultAlwaysVisible,
        contentDroppable: contentDroppable ?? _contentDroppable,
        contentBrowserOpened: contentBrowserOpened ?? _contentBrowserOpened,
        menuPath: menuPath ?? this.menuPath,
        minWidth: minWidth ?? _minWidth,
        minHeight: minHeight ?? _minHeight,
        capabilities: capabilities ?? (_hasCapabilities ? this.capabilities : null),
      );

  @override
  bool operator ==(Object other) =>
      other is LuminaEditorPanelInfo && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'LuminaEditorPanelInfo(${jsonEncode(toJson())})';
}
