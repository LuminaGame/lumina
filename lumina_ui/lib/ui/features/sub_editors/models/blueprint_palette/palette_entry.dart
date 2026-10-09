import 'package:lumina_editor_data/lumina_editor.dart';

/// A palette row that is an editor action rather than a library node, such
/// as the pinned "Promote to Variable".
enum BlueprintPaletteAction { promoteToVariable, addCustomEvent, addComment, collapseNodes, collapseToFunction, collapseToMacro }

/// One row of the graph editor's node palette: a library node, a variable
/// node already bound to one of the document's variables (`Get Speed`), a
/// generated typed-object node (`Get FPSCounter`, `Get CameraBoom`,
/// `Cast To WBP_Menu`) or an editor action (`Promote to Variable`).
class BlueprintPaletteEntry {
  final String registryId;
  final String title;
  final String category;
  final List<String> keywords;
  final int headerColor;
  final LuminaBlueprintNodeKind kind;

  /// Node settings the entry places the node with (`{'variable': 'Speed'}`,
  /// `{'class': 'WBP_HUD', 'element': 'FPSCounter'}`).
  final Map<String, dynamic> literals;

  /// Non-null for a node kept only so old documents load.
  final String? deprecation;

  /// A Dart function of the project exposed with `@BlueprintCallable` /
  /// `@BlueprintPure`, shown with a "Project" badge.
  final bool isProject;

  /// The function's doc comment (or the annotation's tooltip), on hover.
  final String? tooltip;

  /// The object class the entry is about (`Widget:WBP_HUD` for `Get
  /// FPSCounter`, `WidgetElement:text` for `Set Text (Text)`), for the
  /// palette's class headers; null for untyped nodes.
  final String? objectClass;

  /// Non-null for a row that runs an editor action instead of placing a
  /// library node.
  final BlueprintPaletteAction? action;

  /// A key of its own, for a row that places the same node as another row
  /// of the same palette ("Create a Reference to Door_01" beside `Door_01`).
  final String? keyOverride;

  /// Listed first, above the graph actions (the
  /// `Create a Reference to <Actor>` row at the top of the right-click menu).
  final bool pinned;

  const BlueprintPaletteEntry({
    required this.registryId,
    required this.title,
    required this.category,
    required this.keywords,
    required this.headerColor,
    required this.kind,
    this.literals = const {},
    this.deprecation,
    this.isProject = false,
    this.tooltip,
    this.objectClass,
    this.action,
    this.keyOverride,
    this.pinned = false,
  });

  /// A stable key for widgets and tests: the node id, plus the node setting
  /// that makes the row unique (variable, element, component, class).
  String get key {
    if (keyOverride != null) return keyOverride!;
    // A call of another class's custom event: class and event.
    if (literals['event'] != null && literals['class'] != null) return '${registryId}_${literals['class']}_${literals['event']}';
    final tag = literals['variable'] ??
        literals['actor'] ??
        literals['element'] ??
        literals['component'] ??
        literals['class'] ??
        literals['function'] ??
        literals['macro'] ??
        literals['event'] ??
        literals['dispatcher'] ??
        literals['enum'];
    final iface = literals['interface'];
    if (iface != null && tag != null) return '${registryId}_${iface}_$tag';
    return tag == null ? registryId : '${registryId}_$tag';
  }

  /// The top-level category (`Math|Vector` → `Math`).
  String get group => category.split('|').first;

  bool get isAction => action != null;

  /// The lower-cased text a search matches against.
  String get haystack => [title, category, registryId, ...keywords, if (isProject) 'project'].join(' ').toLowerCase();

  bool matches(String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (terms.isEmpty) return true;
    final hay = haystack;
    return terms.every(hay.contains);
  }
}
