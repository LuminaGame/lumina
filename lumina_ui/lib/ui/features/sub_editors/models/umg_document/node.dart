import 'dart:ui';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaComboBoxOptions;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/widget_type.dart';

/// Slot kinds: a child's slot is decided by its *parent* panel.
enum UmgSlotKind { none, canvas, box, overlay, single }

/// Horizontal/vertical alignment of box/overlay slots.
enum UmgAlign { fill, start, center, end }

/// Per-child slot data. One class carries every field so wrap/replace can
/// migrate slots without loss; only the fields relevant to [kind] are
/// serialized and shown in the inspector.
class UmgSlot {
  UmgSlotKind kind;
  // Canvas Panel slot (anchors in [0,1], offsets in design px, alignment in [0,1]).
  Offset anchorMin;
  Offset anchorMax;
  Offset position;
  Size size;
  Offset alignment;
  bool sizeToContent;
  int zOrder;
  // Box / overlay slot.
  double paddingLeft;
  double paddingTop;
  double paddingRight;
  double paddingBottom;
  bool fill;
  double flex;
  UmgAlign hAlign;
  UmgAlign vAlign;

  UmgSlot({
    this.kind = UmgSlotKind.none,
    this.anchorMin = Offset.zero,
    this.anchorMax = Offset.zero,
    this.position = Offset.zero,
    this.size = const Size(200, 100),
    this.alignment = Offset.zero,
    this.sizeToContent = false,
    this.zOrder = 0,
    this.paddingLeft = 0,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingBottom = 0,
    this.fill = false,
    this.flex = 1,
    this.hAlign = UmgAlign.fill,
    this.vAlign = UmgAlign.fill,
  });

  UmgSlot copy() => UmgSlot.fromJson(toJson());

  bool get isStretchX => anchorMin.dx != anchorMax.dx;
  bool get isStretchY => anchorMin.dy != anchorMax.dy;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'kind': kind.name};
    switch (kind) {
      case UmgSlotKind.canvas:
        map['anchorMin'] = [anchorMin.dx, anchorMin.dy];
        map['anchorMax'] = [anchorMax.dx, anchorMax.dy];
        map['position'] = [position.dx, position.dy];
        map['size'] = [size.width, size.height];
        map['alignment'] = [alignment.dx, alignment.dy];
        map['sizeToContent'] = sizeToContent;
        map['zOrder'] = zOrder;
        break;
      case UmgSlotKind.box:
        map['padding'] = [paddingLeft, paddingTop, paddingRight, paddingBottom];
        map['fill'] = fill;
        map['flex'] = flex;
        map['hAlign'] = hAlign.name;
        map['vAlign'] = vAlign.name;
        break;
      case UmgSlotKind.overlay:
        map['padding'] = [paddingLeft, paddingTop, paddingRight, paddingBottom];
        map['hAlign'] = hAlign.name;
        map['vAlign'] = vAlign.name;
        break;
      case UmgSlotKind.single:
        map['padding'] = [paddingLeft, paddingTop, paddingRight, paddingBottom];
        map['hAlign'] = hAlign.name;
        map['vAlign'] = vAlign.name;
        break;
      case UmgSlotKind.none:
        break;
    }
    return map;
  }

  static Offset _offset(dynamic v, Offset fallback) {
    if (v is List && v.length >= 2) return Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
    return fallback;
  }

  static UmgAlign _align(dynamic v, UmgAlign fallback) {
    if (v is String) return UmgAlign.values.firstWhere((a) => a.name == v, orElse: () => fallback);
    return fallback;
  }

  factory UmgSlot.fromJson(Map<String, dynamic> map) {
    final kind = UmgSlotKind.values.firstWhere((k) => k.name == map['kind'], orElse: () => UmgSlotKind.none);
    final padding = map['padding'];
    final pad = padding is List && padding.length >= 4 ? padding.map((e) => (e as num).toDouble()).toList() : const [0.0, 0.0, 0.0, 0.0];
    final size = map['size'];
    return UmgSlot(
      kind: kind,
      anchorMin: _offset(map['anchorMin'], Offset.zero),
      anchorMax: _offset(map['anchorMax'], Offset.zero),
      position: _offset(map['position'], Offset.zero),
      size: size is List && size.length >= 2 ? Size((size[0] as num).toDouble(), (size[1] as num).toDouble()) : const Size(200, 100),
      alignment: _offset(map['alignment'], Offset.zero),
      sizeToContent: map['sizeToContent'] == true,
      zOrder: (map['zOrder'] as num?)?.toInt() ?? 0,
      paddingLeft: pad[0],
      paddingTop: pad[1],
      paddingRight: pad[2],
      paddingBottom: pad[3],
      fill: map['fill'] == true,
      flex: (map['flex'] as num?)?.toDouble() ?? 1,
      hAlign: _align(map['hAlign'], UmgAlign.fill),
      vAlign: _align(map['vAlign'], UmgAlign.fill),
    );
  }
}

/// A named event handler recorded on a node (`OnClicked` → `onClickedStartButton`).
class UmgEvent {
  final String name;
  final String handler;

  const UmgEvent({required this.name, required this.handler});

  /// Snake-case tag used for the guarded user region in generated code.
  String get regionTag {
    final snake = name.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => '_${m[1]}').toLowerCase();
    return snake;
  }

  Map<String, dynamic> toJson() => {'name': name, 'handler': handler};

  factory UmgEvent.fromJson(Map<String, dynamic> map) =>
      UmgEvent(name: map['name']?.toString() ?? '', handler: map['handler']?.toString() ?? '');
}

/// One element of the widget tree.
class UmgNode {
  final String id;
  UmgWidgetType type;
  String name;
  String fieldName;
  UmgSlot slot;
  final Map<String, dynamic> props;
  final List<UmgEvent> events;
  final List<UmgNode> children;

  /// Whether the element is a member of the widget's graph
  /// (`Get <Element>`, bound events). Null follows [UmgWidgetType.isVariableByDefault].
  bool? _isVariable;

  UmgNode({
    required this.id,
    required this.type,
    required this.name,
    required this.fieldName,
    required this.slot,
    Map<String, dynamic>? props,
    List<UmgEvent>? events,
    List<UmgNode>? children,
    this._isVariable,
  })  : props = props ?? {},
        events = events ?? [],
        children = children ?? [];

  bool get isVariable => _isVariable ?? type.isVariableByDefault;

  set isVariable(bool value) => _isVariable = value == type.isVariableByDefault ? null : value;

  static int _counter = 0;

  /// Creates a detached node with default props; the caller attaches it via
  /// [UmgDocument.addChild] which assigns the slot kind.
  factory UmgNode.create(UmgWidgetType type, {String? name, String? id}) {
    final display = name ?? type.displayName;
    _counter++;
    return UmgNode(
      id: id ?? 'umg_${DateTime.now().microsecondsSinceEpoch}_$_counter',
      type: type,
      name: display,
      fieldName: UmgNaming.toFieldName(display),
      slot: UmgSlot(size: type.defaultCanvasSize),
      props: type.defaultProps(),
    );
  }

  UmgNode deepCopy() => UmgNode.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'fieldName': fieldName,
        'slot': slot.toJson(),
        'props': Map<String, dynamic>.fromEntries(props.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
        'events': events.map((e) => e.toJson()).toList(),
        // Stored only when it differs from the type's default.
        if (_isVariable != null) 'isVariable': _isVariable,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory UmgNode.fromJson(Map<String, dynamic> map) {
    final type = UmgWidgetType.fromName(map['type']?.toString() ?? 'canvasPanel');
    final name = map['name']?.toString() ?? type.displayName;
    final props = Map<String, dynamic>.from(map['props'] as Map? ?? {});
    // Backfill props introduced after the document was written.
    type.defaultProps().forEach((k, v) => props.putIfAbsent(k, () => v));
    // A Combo Box's options were one comma-separated string; now label + value rows.
    if (type == UmgWidgetType.comboBox) props['options'] = LuminaComboBoxOptions.migrateDesignerOptions(props['options']);
    return UmgNode(
      id: map['id']?.toString() ?? 'umg_root',
      type: type,
      name: name,
      fieldName: map['fieldName']?.toString() ?? UmgNaming.toFieldName(name),
      slot: UmgSlot.fromJson(Map<String, dynamic>.from(map['slot'] as Map? ?? {})),
      props: props,
      events: (map['events'] as List? ?? []).map((e) => UmgEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      children: (map['children'] as List? ?? []).map((c) => UmgNode.fromJson(Map<String, dynamic>.from(c as Map))).toList(),
      isVariable: map['isVariable'] is bool && map['isVariable'] != type.isVariableByDefault ? map['isVariable'] as bool : null,
    );
  }

  /// Depth-first walk, parents before children.
  void visit(void Function(UmgNode node, UmgNode? parent) fn, [UmgNode? parent]) {
    fn(this, parent);
    for (final c in children) {
      c.visit(fn, this);
    }
  }
}

/// Dart-identifier naming helpers for element names.
class UmgNaming {
  static final RegExp _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
  static const Set<String> _reserved = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
    'do', 'dynamic', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'implements', 'import', 'in',
    'is', 'late', 'library', 'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var',
    'void', 'while', 'with', 'yield', 'context', 'key', 'widget', 'build', 'setState',
  };

  /// `HealthBar Progress` → `healthBarProgress`, `HP Bar` → `hpBar`
  /// ([dartLowerCamelCase]); returns '' when nothing usable remains.
  static String toFieldName(String display) {
    final candidate = dartLowerCamelCase(display);
    if (!isIdentifier(candidate)) return '';
    return candidate;
  }

  static bool isIdentifier(String s) => _identifier.hasMatch(s) && !_reserved.contains(s);

  /// `WBP_PlayerHUD` → `WbpPlayerHUD` ([dartTypeName], the rule every
  /// generator follows).
  static String toClassName(String assetName) =>
      dartTypeName(assetName.replaceAll('.lmas', ''), fallback: 'GeneratedWidget');
}
