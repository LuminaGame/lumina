import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:lumina/lumina.dart' show LuminaBlueprintDocument, LuminaWidgetBlueprintDocument, LuminaWidgetEvents;
import 'package:lumina/data/services/dart_identifiers.dart';

/// Palette categories of the UMG designer; [shadcn] shows
/// only for projects whose widget library is shadcn_flutter.
enum UmgWidgetCategory { panels, common, shadcn }

/// Every widget type the designer can place. The order here is the palette
/// order; `displayName` is what the palette/hierarchy show and `dartWidget`
/// the shadcn_flutter class the runtime renderer and the code generator map
/// it to.
enum UmgWidgetType {
  canvasPanel('Canvas Panel', UmgWidgetCategory.panels, UmgChildCapacity.many),
  overlay('Overlay', UmgWidgetCategory.panels, UmgChildCapacity.many),
  horizontalBox('Horizontal Box', UmgWidgetCategory.panels, UmgChildCapacity.many),
  verticalBox('Vertical Box', UmgWidgetCategory.panels, UmgChildCapacity.many),
  gridPanel('Grid Panel', UmgWidgetCategory.panels, UmgChildCapacity.many),
  scrollBox('Scroll Box', UmgWidgetCategory.panels, UmgChildCapacity.many),
  widgetSwitcher('Widget Switcher', UmgWidgetCategory.panels, UmgChildCapacity.many),
  sizeBox('Size Box', UmgWidgetCategory.panels, UmgChildCapacity.one),
  border('Border', UmgWidgetCategory.panels, UmgChildCapacity.one),
  container('Container', UmgWidgetCategory.panels, UmgChildCapacity.one),
  button('Button', UmgWidgetCategory.common, UmgChildCapacity.none),
  text('Text', UmgWidgetCategory.common, UmgChildCapacity.none),
  image('Image', UmgWidgetCategory.common, UmgChildCapacity.none),
  progressBar('Progress Bar', UmgWidgetCategory.common, UmgChildCapacity.none),
  slider('Slider', UmgWidgetCategory.common, UmgChildCapacity.none),
  checkBox('CheckBox', UmgWidgetCategory.common, UmgChildCapacity.none),
  editableText('Editable Text', UmgWidgetCategory.common, UmgChildCapacity.none),
  comboBox('Combo Box', UmgWidgetCategory.common, UmgChildCapacity.none),
  // shadcn_flutter's ready-made components.
  shadcnCard('Card', UmgWidgetCategory.shadcn, UmgChildCapacity.one),
  shadcnBadge('Badge', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnAvatar('Avatar', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnAlert('Alert', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSeparator('Separator', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnProgress('Progress', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSwitch('Switch', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnToggle('Toggle', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnTabs('Tabs', UmgWidgetCategory.shadcn, UmgChildCapacity.many),
  shadcnAccordion('Accordion', UmgWidgetCategory.shadcn, UmgChildCapacity.many),
  shadcnTooltip('Tooltip', UmgWidgetCategory.shadcn, UmgChildCapacity.one),
  shadcnChip('Chip', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnKbd('Kbd', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSkeleton('Skeleton', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnTextField('Text Field', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnTextArea('Text Area', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSelect('Select', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnRadioGroup('Radio Group', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSlider('Slider', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnCheckbox('Checkbox', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnPrimaryButton('Primary Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnSecondaryButton('Secondary Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnOutlineButton('Outline Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnGhostButton('Ghost Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnDestructiveButton('Destructive Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  shadcnLinkButton('Link Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none);

  const UmgWidgetType(this.displayName, this.category, this.capacity);

  final String displayName;
  final UmgWidgetCategory category;
  final UmgChildCapacity capacity;

  bool get isPanel => capacity != UmgChildCapacity.none;

  /// A shadcn_flutter component: rendered and generated as the real shadcn
  /// widget, so it needs a project on the shadcn widget library.
  bool get isShadcn => category == UmgWidgetCategory.shadcn;

  /// The shadcn button variants.
  bool get isShadcnButton =>
      this == UmgWidgetType.shadcnPrimaryButton ||
      this == UmgWidgetType.shadcnSecondaryButton ||
      this == UmgWidgetType.shadcnOutlineButton ||
      this == UmgWidgetType.shadcnGhostButton ||
      this == UmgWidgetType.shadcnDestructiveButton ||
      this == UmgWidgetType.shadcnLinkButton;
  bool get isCanvas => this == UmgWidgetType.canvasPanel;
  bool get isBox => this == UmgWidgetType.horizontalBox || this == UmgWidgetType.verticalBox;

  /// Which slot kind children of this type carry.
  UmgSlotKind get childSlotKind {
    switch (this) {
      case UmgWidgetType.canvasPanel:
        return UmgSlotKind.canvas;
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
      case UmgWidgetType.gridPanel:
      case UmgWidgetType.scrollBox:
        return UmgSlotKind.box;
      case UmgWidgetType.overlay:
      case UmgWidgetType.widgetSwitcher:
      case UmgWidgetType.shadcnTabs:
      case UmgWidgetType.shadcnAccordion:
        return UmgSlotKind.overlay;
      case UmgWidgetType.sizeBox:
      case UmgWidgetType.border:
      case UmgWidgetType.container:
      case UmgWidgetType.shadcnCard:
      case UmgWidgetType.shadcnTooltip:
        return UmgSlotKind.single;
      default:
        return UmgSlotKind.none;
    }
  }

  /// Events the designer offers for this type (Widget Events):
  /// lumina's table, the one the Widget Blueprint graph checks.
  List<String> get availableEvents => LuminaWidgetEvents.forType(name);

  /// Whether a new element of this type is a graph variable (`Is
  /// Variable`): the leaves a graph reads or scripts; panels
  /// are not.
  bool get isVariableByDefault => !isPanel && this != UmgWidgetType.shadcnSeparator && this != UmgWidgetType.shadcnSkeleton;

  /// Whether the runtime widget carries user-mutable state (needs a
  /// StatefulWidget in generated code even without events).
  bool get isInteractive =>
      this == UmgWidgetType.slider ||
      this == UmgWidgetType.checkBox ||
      this == UmgWidgetType.editableText ||
      this == UmgWidgetType.comboBox ||
      this == UmgWidgetType.shadcnSwitch ||
      this == UmgWidgetType.shadcnToggle ||
      this == UmgWidgetType.shadcnCheckbox ||
      this == UmgWidgetType.shadcnSelect ||
      this == UmgWidgetType.shadcnRadioGroup ||
      this == UmgWidgetType.shadcnTabs ||
      this == UmgWidgetType.shadcnSlider ||
      this == UmgWidgetType.shadcnTextField ||
      this == UmgWidgetType.shadcnTextArea;

  /// Whether this type renders text (a Text, or the label of a Button, Check
  /// Box, Editable Text or Combo Box) and so carries the text shadow and
  /// outline.
  bool get isTextBearing =>
      this == UmgWidgetType.text ||
      this == UmgWidgetType.button ||
      this == UmgWidgetType.checkBox ||
      this == UmgWidgetType.editableText ||
      this == UmgWidgetType.comboBox;

  /// The text shadow and outline props of every text-bearing type (Shadow
  /// Offset / Shadow Color and Font Outline Settings). Colours are
  /// `#RRGGBBAA`; an outline size of 0 is no outline.
  static const Map<String, dynamic> textEffectDefaults = {
    'shadowEnabled': false,
    'shadowColor': '#000000B3',
    'shadowOffsetX': 1.0,
    'shadowOffsetY': 1.0,
    'shadowBlur': 0.0,
    'outlineSize': 0.0,
    'outlineColor': '#000000FF',
  };

  /// Default props for a freshly placed widget of this type.
  Map<String, dynamic> defaultProps() => {
        ..._baseProps(),
        if (isTextBearing) ...textEffectDefaults,
      };

  Map<String, dynamic> _baseProps() {
    switch (this) {
      case UmgWidgetType.text:
        return {'text': 'Text Block', 'fontSize': 16.0, 'color': '#FFFFFF'};
      case UmgWidgetType.button:
        return {'label': 'Button', 'style': 'primary', 'fontSize': 14.0, 'color': '#FFFFFF'};
      case UmgWidgetType.image:
        return {'texture': '', 'drawAs': 'image', 'color': '#FFFFFF'};
      case UmgWidgetType.progressBar:
        return {'percent': 0.5, 'color': '#4ADE80'};
      case UmgWidgetType.slider:
        return {'value': 0.5, 'color': '#FF8C00'};
      case UmgWidgetType.checkBox:
        return {'checked': false, 'label': 'CheckBox', 'fontSize': 12.0, 'color': '#FFFFFF'};
      case UmgWidgetType.editableText:
        return {'text': '', 'hint': 'Enter text', 'fontSize': 14.0, 'color': '#FFFFFF'};
      case UmgWidgetType.comboBox:
        return {'options': 'Option A,Option B,Option C', 'selected': 'Option A', 'fontSize': 12.0};
      case UmgWidgetType.border:
        return {'color': '#1B1B22', 'padding': 8.0};
      case UmgWidgetType.container:
        return Map<String, dynamic>.of(containerDefaults);
      case UmgWidgetType.shadcnCard:
        return {'title': 'Card Title', 'description': 'Card description', 'padding': 16.0};
      case UmgWidgetType.shadcnBadge:
        return {'text': 'Badge', 'variant': 'primary'};
      case UmgWidgetType.shadcnAvatar:
        return {'initials': 'LM', 'size': 40.0};
      case UmgWidgetType.shadcnAlert:
        return {'title': 'Heads up!', 'description': 'You can add components to your HUD.', 'destructive': false};
      case UmgWidgetType.shadcnSeparator:
        return {'orientation': 'horizontal', 'label': ''};
      case UmgWidgetType.shadcnProgress:
        return {'percent': 0.6};
      case UmgWidgetType.shadcnSwitch:
        return {'checked': false, 'label': 'Airplane Mode'};
      case UmgWidgetType.shadcnToggle:
        return {'checked': false, 'label': 'Bold'};
      case UmgWidgetType.shadcnTabs:
        return {'items': 'Account,Password', 'activeIndex': 0};
      case UmgWidgetType.shadcnAccordion:
        return {'items': 'Is it accessible?,Is it styled?', 'expandedIndex': 0};
      case UmgWidgetType.shadcnTooltip:
        return {'tooltip': 'Add to library'};
      case UmgWidgetType.shadcnChip:
        return {'text': 'Chip'};
      case UmgWidgetType.shadcnKbd:
        return {'text': 'Ctrl+S'};
      case UmgWidgetType.shadcnSkeleton:
        return {'lines': 3};
      case UmgWidgetType.shadcnTextField:
        return {'text': '', 'hint': 'Email'};
      case UmgWidgetType.shadcnTextArea:
        return {'text': '', 'hint': 'Type your message here.'};
      case UmgWidgetType.shadcnSelect:
        return {'options': 'Apple,Banana,Blueberry', 'selected': 'Apple'};
      case UmgWidgetType.shadcnRadioGroup:
        return {'options': 'Default,Comfortable,Compact', 'selected': 'Default'};
      case UmgWidgetType.shadcnSlider:
        return {'value': 0.5};
      case UmgWidgetType.shadcnCheckbox:
        return {'checked': false, 'label': 'Accept terms and conditions'};
      case UmgWidgetType.shadcnPrimaryButton:
      case UmgWidgetType.shadcnSecondaryButton:
      case UmgWidgetType.shadcnOutlineButton:
      case UmgWidgetType.shadcnGhostButton:
      case UmgWidgetType.shadcnDestructiveButton:
      case UmgWidgetType.shadcnLinkButton:
        return {'label': displayName.replaceAll(' Button', '')};
      case UmgWidgetType.sizeBox:
        return {'width': 200.0, 'height': 100.0};
      case UmgWidgetType.gridPanel:
        return {'columns': 2};
      case UmgWidgetType.widgetSwitcher:
        return {'activeIndex': 0};
      case UmgWidgetType.scrollBox:
        return {'orientation': 'vertical'};
      case UmgWidgetType.canvasPanel:
      case UmgWidgetType.overlay:
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
        return {};
    }
  }

  /// The props of a new Container, Flutter `Container`'s
  /// styling: colours `#RRGGBBAA`, `gradient` null or `{type, colors, begin,
  /// end | center, radius}`, `padding` / `margin` `[l, t, r, b]`,
  /// `cornerRadius` a number or `[tl, tr, br, bl]`, `borderSides` `[top,
  /// right, bottom, left]`, `shadows` `[{color, offsetX, offsetY, blur,
  /// spread}]`, sizes null for "auto", `alignment` null (fill) or one of
  /// the nine names.
  static const Map<String, dynamic> containerDefaults = {
    'backgroundColor': '#1B1B22FF',
    'gradient': null,
    'backgroundImage': '',
    'backgroundFit': 'cover',
    'borderColor': '#FFFFFF33',
    'borderWidth': 0.0,
    'borderSides': [true, true, true, true],
    'cornerRadius': 0.0,
    'padding': [0.0, 0.0, 0.0, 0.0],
    'margin': [0.0, 0.0, 0.0, 0.0],
    'shadows': <Map<String, dynamic>>[],
    'width': null,
    'height': null,
    'minWidth': null,
    'maxWidth': null,
    'minHeight': null,
    'maxHeight': null,
    'alignment': null,
  };

  /// Default size of a newly dropped canvas slot for this type.
  Size get defaultCanvasSize {
    if (isShadcn) return _shadcnCanvasSize;
    switch (this) {
      case UmgWidgetType.canvasPanel:
      case UmgWidgetType.overlay:
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
      case UmgWidgetType.gridPanel:
      case UmgWidgetType.scrollBox:
      case UmgWidgetType.widgetSwitcher:
        return const Size(400, 240);
      case UmgWidgetType.sizeBox:
        return const Size(200, 100);
      case UmgWidgetType.border:
      case UmgWidgetType.container:
        return const Size(300, 160);
      case UmgWidgetType.button:
        return const Size(160, 44);
      case UmgWidgetType.text:
        return const Size(200, 32);
      case UmgWidgetType.image:
        return const Size(128, 128);
      case UmgWidgetType.progressBar:
        return const Size(300, 20);
      case UmgWidgetType.slider:
        return const Size(300, 32);
      case UmgWidgetType.checkBox:
        return const Size(160, 28);
      case UmgWidgetType.editableText:
        return const Size(260, 36);
      case UmgWidgetType.comboBox:
        return const Size(200, 36);
      default:
        return _shadcnCanvasSize;
    }
  }

  Size get _shadcnCanvasSize {
    switch (this) {
      case UmgWidgetType.shadcnCard:
      case UmgWidgetType.shadcnAlert:
        return const Size(320, 140);
      case UmgWidgetType.shadcnTabs:
      case UmgWidgetType.shadcnAccordion:
        return const Size(360, 200);
      case UmgWidgetType.shadcnTextArea:
        return const Size(280, 96);
      case UmgWidgetType.shadcnRadioGroup:
      case UmgWidgetType.shadcnSkeleton:
        return const Size(220, 96);
      case UmgWidgetType.shadcnAvatar:
        return const Size(48, 48);
      case UmgWidgetType.shadcnSeparator:
      case UmgWidgetType.shadcnProgress:
      case UmgWidgetType.shadcnSlider:
        return const Size(300, 24);
      case UmgWidgetType.shadcnBadge:
      case UmgWidgetType.shadcnChip:
      case UmgWidgetType.shadcnKbd:
        return const Size(96, 28);
      default:
        return const Size(200, 40);
    }
  }

  static UmgWidgetType fromName(String name) {
    return UmgWidgetType.values.firstWhere((t) => t.name == name, orElse: () => UmgWidgetType.canvasPanel);
  }
}

enum UmgChildCapacity { none, one, many }

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
    bool? isVariable,
  })  : props = props ?? {},
        events = events ?? [],
        children = children ?? [],
        _isVariable = isVariable;

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

/// Anchor presets of the 3×3 + stretch matrix.
enum UmgAnchorPreset {
  topLeft(Offset(0, 0), Offset(0, 0)),
  topCenter(Offset(0.5, 0), Offset(0.5, 0)),
  topRight(Offset(1, 0), Offset(1, 0)),
  centerLeft(Offset(0, 0.5), Offset(0, 0.5)),
  center(Offset(0.5, 0.5), Offset(0.5, 0.5)),
  centerRight(Offset(1, 0.5), Offset(1, 0.5)),
  bottomLeft(Offset(0, 1), Offset(0, 1)),
  bottomCenter(Offset(0.5, 1), Offset(0.5, 1)),
  bottomRight(Offset(1, 1), Offset(1, 1)),
  stretchTop(Offset(0, 0), Offset(1, 0)),
  stretchMiddle(Offset(0, 0.5), Offset(1, 0.5)),
  stretchBottom(Offset(0, 1), Offset(1, 1)),
  stretchLeft(Offset(0, 0), Offset(0, 1)),
  stretchCenter(Offset(0.5, 0), Offset(0.5, 1)),
  stretchRight(Offset(1, 0), Offset(1, 1)),
  fullStretch(Offset(0, 0), Offset(1, 1));

  const UmgAnchorPreset(this.min, this.max);
  final Offset min;
  final Offset max;

  /// Alignment that keeps the pivot on the anchored corner/edge.
  Offset get alignment => Offset(min.dx == max.dx ? min.dx : 0, min.dy == max.dy ? min.dy : 0);

  String get label {
    switch (this) {
      case UmgAnchorPreset.topLeft:
        return 'Top-Left';
      case UmgAnchorPreset.topCenter:
        return 'Top-Center';
      case UmgAnchorPreset.topRight:
        return 'Top-Right';
      case UmgAnchorPreset.centerLeft:
        return 'Center-Left';
      case UmgAnchorPreset.center:
        return 'Center';
      case UmgAnchorPreset.centerRight:
        return 'Center-Right';
      case UmgAnchorPreset.bottomLeft:
        return 'Bottom-Left';
      case UmgAnchorPreset.bottomCenter:
        return 'Bottom-Center';
      case UmgAnchorPreset.bottomRight:
        return 'Bottom-Right';
      case UmgAnchorPreset.stretchTop:
        return 'Stretch Top';
      case UmgAnchorPreset.stretchMiddle:
        return 'Stretch Middle';
      case UmgAnchorPreset.stretchBottom:
        return 'Stretch Bottom';
      case UmgAnchorPreset.stretchLeft:
        return 'Stretch Left';
      case UmgAnchorPreset.stretchCenter:
        return 'Stretch Center';
      case UmgAnchorPreset.stretchRight:
        return 'Stretch Right';
      case UmgAnchorPreset.fullStretch:
        return 'Full Stretch';
    }
  }
}

/// Screen Resolution Simulator entries.
class UmgResolution {
  final String label;
  final int width;
  final int height;
  final bool isCustom;

  const UmgResolution(this.label, this.width, this.height, {this.isCustom = false});

  static const List<UmgResolution> presets = [
    UmgResolution('1920x1080 Full HD', 1920, 1080),
    UmgResolution('2560x1440 2K', 2560, 1440),
    UmgResolution('3840x2160 4K UHD', 3840, 2160),
    UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852),
  ];

  UmgResolution copyWith({int? width, int? height}) =>
      UmgResolution('Custom ${width ?? this.width}x${height ?? this.height}', width ?? this.width, height ?? this.height, isCustom: true);

  String get key => '${width}x$height';

  @override
  bool operator ==(Object other) => other is UmgResolution && other.width == width && other.height == height && other.isCustom == isCustom;

  @override
  int get hashCode => Object.hash(width, height, isCustom);
}

/// Canvas-slot layout math shared by the designer canvas, the inspector and
/// (as emitted source) the generated widget. Semantics: when an axis is
/// not stretched, `position` is the pivot offset from the anchor point and
/// `size` the extent; when stretched, `position` is the near margin and
/// `size` the far margin.
class UmgLayout {
  static Rect resolveCanvasRect(UmgSlot slot, Size parent) {
    final w = parent.width;
    final h = parent.height;
    double left;
    double width;
    if (slot.anchorMin.dx == slot.anchorMax.dx) {
      width = slot.size.width;
      left = slot.anchorMin.dx * w + slot.position.dx - slot.alignment.dx * width;
    } else {
      left = slot.anchorMin.dx * w + slot.position.dx;
      final right = slot.anchorMax.dx * w - slot.size.width;
      width = math.max(0, right - left);
    }
    double top;
    double height;
    if (slot.anchorMin.dy == slot.anchorMax.dy) {
      height = slot.size.height;
      top = slot.anchorMin.dy * h + slot.position.dy - slot.alignment.dy * height;
    } else {
      top = slot.anchorMin.dy * h + slot.position.dy;
      final bottom = slot.anchorMax.dy * h - slot.size.height;
      height = math.max(0, bottom - top);
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Rewrites `position`/`size` of [slot] so that it resolves to [rect] at
  /// [parent] with its current anchors/alignment.
  static void fitSlotToRect(UmgSlot slot, Rect rect, Size parent) {
    final w = parent.width;
    final h = parent.height;
    double px;
    double sx;
    if (slot.anchorMin.dx == slot.anchorMax.dx) {
      sx = rect.width;
      px = rect.left + slot.alignment.dx * rect.width - slot.anchorMin.dx * w;
    } else {
      px = rect.left - slot.anchorMin.dx * w;
      sx = slot.anchorMax.dx * w - rect.right;
    }
    double py;
    double sy;
    if (slot.anchorMin.dy == slot.anchorMax.dy) {
      sy = rect.height;
      py = rect.top + slot.alignment.dy * rect.height - slot.anchorMin.dy * h;
    } else {
      py = rect.top - slot.anchorMin.dy * h;
      sy = slot.anchorMax.dy * h - rect.bottom;
    }
    slot.position = Offset(px, py);
    slot.size = Size(sx, sy);
  }

  /// Applies [preset] to [slot] keeping its resolved rect at [parent] unchanged.
  static void applyPreset(UmgSlot slot, UmgAnchorPreset preset, Size parent) {
    final rect = resolveCanvasRect(slot, parent);
    slot.anchorMin = preset.min;
    slot.anchorMax = preset.max;
    slot.alignment = preset.alignment;
    fitSlotToRect(slot, rect, parent);
  }

  static double snap(double v, double grid) => grid <= 0 ? v : (v / grid).roundToDouble() * grid;
}

/// The persisted designer document (`rawPayload` UTF-8 JSON of the WIDGET `.lmas`).
class UmgDocument {
  UmgNode root;
  UmgResolution designResolution;
  double dpiScale;

  /// The widget's own Blueprint graph, stored
  /// under `blueprint`; null for a widget that never had one.
  LuminaBlueprintDocument? blueprint;

  UmgDocument({
    required this.root,
    this.designResolution = const UmgResolution('1920x1080 Full HD', 1920, 1080),
    this.dpiScale = 1.0,
    this.blueprint,
  });

  /// A new widget: one root Canvas Panel.
  factory UmgDocument.createDefault() {
    final root = UmgNode.create(UmgWidgetType.canvasPanel, name: 'Root Canvas', id: 'umg_root');
    return UmgDocument(root: root);
  }

  Size get logicalSize => Size(designResolution.width / dpiScale, designResolution.height / dpiScale);

  /// [includeBlueprint] false leaves the graph out: the designer's own undo
  /// snapshots and dirty check, which the graph editor has its own of.
  Map<String, dynamic> toJson({bool includeBlueprint = true}) => {
        'version': 1,
        'designResolution': {'width': designResolution.width, 'height': designResolution.height},
        'dpiScale': dpiScale,
        'root': root.toJson(),
        if (includeBlueprint && blueprint != null) LuminaWidgetBlueprintDocument.payloadKey: blueprint!.toJson(),
      };

  String toFormattedJson({bool includeBlueprint = true}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(includeBlueprint: includeBlueprint));

  /// The elements marked `Is Variable`, in tree order (the root is never one).
  List<UmgNode> get variableNodes => [for (final n in allNodes) if (!identical(n, root) && n.isVariable && n.name.isNotEmpty) n];

  factory UmgDocument.fromJson(Map<String, dynamic> map) {
    final res = map['designResolution'];
    UmgResolution resolution = UmgResolution.presets.first;
    if (res is Map) {
      final w = (res['width'] as num?)?.toInt() ?? 1920;
      final h = (res['height'] as num?)?.toInt() ?? 1080;
      resolution = UmgResolution.presets.firstWhere((p) => p.width == w && p.height == h, orElse: () => UmgResolution('Custom ${w}x$h', w, h, isCustom: true));
    }
    final rootMap = map['root'];
    final graph = map[LuminaWidgetBlueprintDocument.payloadKey];
    return UmgDocument(
      root: rootMap is Map ? UmgNode.fromJson(Map<String, dynamic>.from(rootMap)) : UmgDocument.createDefault().root,
      designResolution: resolution,
      dpiScale: (map['dpiScale'] as num?)?.toDouble() ?? 1.0,
      blueprint: graph is Map ? LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(graph)) : null,
    );
  }

  UmgDocument deepCopy() => UmgDocument.fromJson(toJson());

  UmgNode? findNode(String id) {
    UmgNode? found;
    root.visit((n, _) {
      if (n.id == id) found = n;
    });
    return found;
  }

  UmgNode? parentOf(String id) {
    UmgNode? found;
    root.visit((n, p) {
      if (n.id == id) found = p;
    });
    return found;
  }

  List<UmgNode> get allNodes {
    final out = <UmgNode>[];
    root.visit((n, _) => out.add(n));
    return out;
  }

  bool isDescendant(String ancestorId, String id) {
    final a = findNode(ancestorId);
    if (a == null) return false;
    var found = false;
    a.visit((n, _) {
      if (n.id == id && n.id != ancestorId) found = true;
    });
    return found;
  }

  /// Why [parent] cannot take another child, or null when it can.
  String? rejectionReasonFor(UmgNode parent, {int extra = 1}) {
    switch (parent.type.capacity) {
      case UmgChildCapacity.none:
        return '${parent.type.displayName} "${parent.name}" is a leaf widget and cannot contain children';
      case UmgChildCapacity.one:
        if (parent.children.length + extra > 1) {
          return '${parent.type.displayName} "${parent.name}" accepts exactly one child';
        }
        return null;
      case UmgChildCapacity.many:
        return null;
    }
  }

  /// Gives [node] a slot matching [parent]'s child slot kind, keeping any
  /// fields that still apply.
  void assignSlotFor(UmgNode node, UmgNode parent, {Offset? canvasPosition}) {
    final kind = parent.type.childSlotKind;
    final slot = node.slot;
    slot.kind = kind;
    if (kind == UmgSlotKind.canvas) {
      if (canvasPosition != null) slot.position = canvasPosition;
      if (slot.size.isEmpty) slot.size = node.type.defaultCanvasSize;
    }
  }

  /// Attaches a detached [node] under [parentId]; returns the node, or null
  /// (with a reason in [lastRejectionReason]) when the parent cannot take it.
  String? lastRejectionReason;

  UmgNode? addChild(String parentId, UmgNode node, {Offset? canvasPosition, int? index}) {
    final parent = findNode(parentId);
    if (parent == null) {
      lastRejectionReason = 'Parent not found';
      return null;
    }
    final reason = rejectionReasonFor(parent);
    if (reason != null) {
      lastRejectionReason = reason;
      return null;
    }
    lastRejectionReason = null;
    if (node.slot.size.isEmpty) node.slot.size = node.type.defaultCanvasSize;
    node.fieldName = uniqueFieldName(node.fieldName.isEmpty ? UmgNaming.toFieldName(node.type.displayName) : node.fieldName, exclude: node.id);
    assignSlotFor(node, parent, canvasPosition: canvasPosition);
    if (index == null || index < 0 || index > parent.children.length) {
      parent.children.add(node);
    } else {
      parent.children.insert(index, node);
    }
    return node;
  }

  bool removeNode(String id) {
    final parent = parentOf(id);
    if (parent == null) return false;
    parent.children.removeWhere((c) => c.id == id);
    return true;
  }

  /// Makes [base] unique across the tree by appending a number.
  String uniqueFieldName(String base, {String? exclude}) {
    final taken = <String>{};
    root.visit((n, _) {
      if (n.id != exclude) taken.add(n.fieldName);
    });
    var candidate = base.isEmpty ? 'widget' : base;
    var i = 2;
    while (taken.contains(candidate)) {
      candidate = '$base${i++}';
    }
    return candidate;
  }

  bool isFieldNameTaken(String fieldName, {String? exclude}) {
    var taken = false;
    root.visit((n, _) {
      if (n.id != exclude && n.fieldName == fieldName) taken = true;
    });
    return taken;
  }
}
