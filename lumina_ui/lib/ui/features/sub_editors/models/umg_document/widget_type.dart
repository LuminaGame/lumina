import 'dart:ui';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaComboBoxOptions, LuminaWidgetEvents;
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/node.dart';

/// Palette categories of the UMG designer; [shadcn] shows
/// only for projects whose widget library is shadcn_flutter, [editor] only
/// in an editor panel Widget Blueprint.
enum UmgWidgetCategory { panels, common, threeD, shadcn, editor }

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
  // A Filament preview scene inside the widget (UMG Viewport).
  viewport('Viewport', UmgWidgetCategory.threeD, UmgChildCapacity.none),
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
  shadcnLinkButton('Link Button', UmgWidgetCategory.shadcn, UmgChildCapacity.none),
  // The editor widget set (editor panels only; never in a game).
  editorSection('Editor Section', UmgWidgetCategory.editor, UmgChildCapacity.many),
  propertyRow('Property Row', UmgWidgetCategory.editor, UmgChildCapacity.one),
  treeView('Tree View', UmgWidgetCategory.editor, UmgChildCapacity.none),
  listView('List View', UmgWidgetCategory.editor, UmgChildCapacity.none),
  assetPicker('Asset Picker', UmgWidgetCategory.editor, UmgChildCapacity.none),
  resizableSplit('Resizable Split', UmgWidgetCategory.editor, UmgChildCapacity.many),
  editorToolbar('Editor Toolbar', UmgWidgetCategory.editor, UmgChildCapacity.many),
  statusLine('Status Line', UmgWidgetCategory.editor, UmgChildCapacity.none),
  // The native timeline, table and canvas (editor panels only).
  editorTimeline('Timeline', UmgWidgetCategory.editor, UmgChildCapacity.none),
  editorTable('Table', UmgWidgetCategory.editor, UmgChildCapacity.none),
  editorCanvas('Canvas', UmgWidgetCategory.editor, UmgChildCapacity.none);

  const UmgWidgetType(this.displayName, this.category, this.capacity);

  final String displayName;
  final UmgWidgetCategory category;
  final UmgChildCapacity capacity;

  bool get isPanel => capacity != UmgChildCapacity.none;

  /// A shadcn_flutter component: rendered and generated as the real shadcn
  /// widget, so it needs a project on the shadcn widget library.
  bool get isShadcn => category == UmgWidgetCategory.shadcn;

  /// An editor widget: rendered by the editor panel host, never generated
  /// into a game.
  bool get isEditor => category == UmgWidgetCategory.editor;

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
      case UmgWidgetType.editorSection:
      case UmgWidgetType.resizableSplit:
      case UmgWidgetType.editorToolbar:
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
      case UmgWidgetType.propertyRow:
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

  /// A Viewport's Details: background (`sky` / `color` / `transparent`),
  /// grid, camera preset, interaction toggles, auto-rotation (deg/s),
  /// render scale (0.25–1), max FPS, and the design-time preview content
  /// (a mesh or skeletal mesh and an animation, shown in the designer only).
  static const Map<String, dynamic> viewportDefaults = {
    'background': 'sky',
    'grid': true,
    'cameraPreset': 'perspective',
    'orbit': true,
    'pan': true,
    'zoom': true,
    'pick': true,
    'autoRotate': 0.0,
    'renderScale': 1.0,
    'maxFps': 60,
    'previewMesh': '',
    'previewAnimation': '',
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
        return {'options': LuminaComboBoxOptions.migrateDesignerOptions('Option A,Option B,Option C'), 'selected': 'Option A', 'fontSize': 12.0};
      case UmgWidgetType.viewport:
        return Map<String, dynamic>.of(viewportDefaults);
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
      case UmgWidgetType.editorSection:
        return {'title': 'Section', 'expanded': true};
      case UmgWidgetType.propertyRow:
        return {'label': 'Property'};
      case UmgWidgetType.treeView:
        return {'items': <Object?>[], 'selected': <Object?>[], 'expanded': <Object?>[]};
      case UmgWidgetType.listView:
        return {'items': <Object?>[], 'selected': <Object?>[], 'multiSelect': true};
      case UmgWidgetType.assetPicker:
        return {'value': '', 'typeFilter': '', 'placeholder': 'None', 'allowClear': true};
      case UmgWidgetType.resizableSplit:
        return {'orientation': 'horizontal', 'split': 0.5, 'minFirst': 120.0, 'minSecond': 120.0};
      case UmgWidgetType.editorToolbar:
        return {};
      case UmgWidgetType.statusLine:
        return {'text': 'Ready', 'tone': 'info'};
      case UmgWidgetType.editorTimeline:
        return {
          'fps': 30,
          'length': 300,
          'snap': 1,
          'tracks': <Object?>[
            {'id': 'clips', 'label': 'Clips', 'icon': 'film', 'kind': 'clips'},
            {'id': 'keys', 'label': 'Keys', 'icon': 'diamond', 'kind': 'keys'},
          ],
          'clips': <Object?>[],
          'keys': <Object?>[],
        };
      case UmgWidgetType.editorTable:
        return {
          'columns': <Object?>[
            {'id': 'name', 'label': 'Name', 'kind': 'text'},
            {'id': 'value', 'label': 'Value', 'kind': 'number', 'editable': true},
          ],
          'rows': <Object?>[],
          'selection': 'single',
          'filter': false,
        };
      case UmgWidgetType.editorCanvas:
        return {'space': 'local', 'background': '#151519', 'items': <Object?>[]};
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
      case UmgWidgetType.viewport:
        return const Size(320, 320);
      case UmgWidgetType.editorSection:
      case UmgWidgetType.treeView:
      case UmgWidgetType.listView:
      case UmgWidgetType.resizableSplit:
        return const Size(300, 220);
      case UmgWidgetType.propertyRow:
      case UmgWidgetType.assetPicker:
        return const Size(280, 28);
      case UmgWidgetType.editorToolbar:
      case UmgWidgetType.statusLine:
        return const Size(320, 28);
      case UmgWidgetType.editorTimeline:
        return const Size(520, 220);
      case UmgWidgetType.editorTable:
        return const Size(360, 220);
      case UmgWidgetType.editorCanvas:
        return const Size(300, 200);
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
