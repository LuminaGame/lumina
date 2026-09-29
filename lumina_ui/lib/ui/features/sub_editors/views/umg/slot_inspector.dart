import 'package:lumina/lumina.dart' show kUmgWidgetLibraryShadcn;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../../models/umg_document.dart';
import '../../view_models/umg_editor_view_model.dart';

/// The designer's right panel: Slot (anchors preset matrix, position/size/
/// alignment, size-to-content, Z-order — or the honest box/overlay slot
/// fields), Appearance (color & tint, font size, image brush, per-type
/// content) and Widget Events (`[+] OnClicked` …).
class UmgSlotInspector extends StatelessWidget {
  final UmgEditorViewModel vm;

  const UmgSlotInspector({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final node = vm.selectedNode;
    if (node == null) {
      return const Center(child: Text('Select an element on the canvas or in the hierarchy', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)));
    }
    final parent = vm.document.parentOf(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SecondaryBadge(child: Text(node.type.displayName, style: const TextStyle(fontSize: 8))),
              const SizedBox(width: 6),
              Expanded(child: Text(node.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('field: ${node.fieldName}', style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
        ),
        // Is Variable — a member of the widget's graph.
        if (parent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                Checkbox(
                  key: ValueKey('umg_is_variable_${node.id}'),
                  state: node.isVariable ? CheckboxState.checked : CheckboxState.unchecked,
                  onChanged: (s) => vm.setIsVariable(node.id, s == CheckboxState.checked),
                ),
                const SizedBox(width: 6),
                const Expanded(child: Text('Is Variable', style: TextStyle(fontSize: 9, color: EditorColors.foreground))),
                Tooltip(
                  tooltip: (_) => const TooltipContainer(
                      child: Text('A variable is a member of the widget\'s graph: Get <widget> and bound events', style: TextStyle(fontSize: 9))),
                  child: const Icon(LucideIcons.info, size: 10, color: EditorColors.mutedForeground),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            // One Accordion per group so all three stay open independently
            // (shadcn's Accordion is single-expansion).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: AccordionTrigger(child: Text(_slotTitle(node, parent), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _slotSection(context, node, parent),
                    ),
                  ],
                ),
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: const AccordionTrigger(child: Text('Appearance & Style', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _appearanceSection(context, node),
                    ),
                  ],
                ),
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: const AccordionTrigger(child: Text('Widget Events', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _eventsSection(node),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _slotTitle(UmgNode node, UmgNode? parent) {
    if (parent == null) return 'Slot (root)';
    return 'Slot (${parent.type.displayName} Slot)';
  }

  // ---------------------------------------------------------------------------
  // Slot
  // ---------------------------------------------------------------------------

  Widget _slotSection(BuildContext context, UmgNode node, UmgNode? parent) {
    if (parent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hint('The root panel fills the simulated screen; it has no slot of its own.'),
          const SizedBox(height: 6),
          _anchorMatrix(node, enabled: false),
        ],
      );
    }
    switch (node.slot.kind) {
      case UmgSlotKind.canvas:
        return _canvasSlot(node);
      case UmgSlotKind.box:
        return _boxSlot(node, parent, showFlex: parent.type.isBox);
      case UmgSlotKind.overlay:
      case UmgSlotKind.single:
        return _boxSlot(node, parent, showFlex: false);
      case UmgSlotKind.none:
        return _hint('No slot.');
    }
  }

  Widget _canvasSlot(UmgNode node) {
    final s = node.slot;
    final stretchX = s.isStretchX;
    final stretchY = s.isStretchY;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Anchors Preset'),
        _anchorMatrix(node, enabled: true),
        const SizedBox(height: 6),
        _slotNumber(node, stretchX ? 'Offset Left' : 'Position X', s.position.dx, 0, (slot, v) => slot.position = Offset(v, slot.position.dy)),
        _slotNumber(node, stretchY ? 'Offset Top' : 'Position Y', s.position.dy, 0, (slot, v) => slot.position = Offset(slot.position.dx, v)),
        _slotNumber(node, stretchX ? 'Offset Right' : 'Size X', s.size.width, node.type.defaultCanvasSize.width, (slot, v) => slot.size = Size(v, slot.size.height)),
        _slotNumber(node, stretchY ? 'Offset Bottom' : 'Size Y', s.size.height, node.type.defaultCanvasSize.height, (slot, v) => slot.size = Size(slot.size.width, v)),
        _slotNumber(node, 'Alignment X', s.alignment.dx, 0, (slot, v) => slot.alignment = Offset(v.clamp(0, 1), slot.alignment.dy), min: 0, max: 1),
        _slotNumber(node, 'Alignment Y', s.alignment.dy, 0, (slot, v) => slot.alignment = Offset(slot.alignment.dx, v.clamp(0, 1)), min: 0, max: 1),
        _switchRow('Size to Content', s.sizeToContent, ValueKey('umg_size_to_content_${node.id}'), (v) => vm.setSlot(node.id, (slot) => slot.sizeToContent = v, label: 'Size to Content')),
        _slotNumber(node, 'Z-Order', s.zOrder.toDouble(), 0, (slot, v) => slot.zOrder = v.round(), fractionDigits: 0),
      ],
    );
  }

  Widget _boxSlot(UmgNode node, UmgNode parent, {required bool showFlex}) {
    final s = node.slot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hint('Anchors only exist on Canvas Panel slots — "${node.name}" sits in a ${parent.type.displayName}, so it uses padding and alignment instead.'),
        _anchorMatrix(node, enabled: false),
        const SizedBox(height: 6),
        _slotNumber(node, 'Padding Left', s.paddingLeft, 0, (slot, v) => slot.paddingLeft = v),
        _slotNumber(node, 'Padding Top', s.paddingTop, 0, (slot, v) => slot.paddingTop = v),
        _slotNumber(node, 'Padding Right', s.paddingRight, 0, (slot, v) => slot.paddingRight = v),
        _slotNumber(node, 'Padding Bottom', s.paddingBottom, 0, (slot, v) => slot.paddingBottom = v),
        if (showFlex) ...[
          _switchRow('Fill (Expanded)', s.fill, ValueKey('umg_fill_${node.id}'), (v) => vm.setSlot(node.id, (slot) => slot.fill = v, label: 'Fill')),
          _slotNumber(node, 'Fill Ratio', s.flex, 1, (slot, v) => slot.flex = v <= 0 ? 0.01 : v, min: 0.01),
        ],
        _label('Horizontal Alignment'),
        EnumField(
          value: s.hAlign.name,
          enumValues: UmgAlign.values.map((a) => a.name).toList(),
          onCommit: (v) => vm.setSlot(node.id, (slot) => slot.hAlign = UmgAlign.values.firstWhere((a) => a.name == v), label: 'H Align'),
        ),
        const SizedBox(height: 4),
        _label('Vertical Alignment'),
        EnumField(
          value: s.vAlign.name,
          enumValues: UmgAlign.values.map((a) => a.name).toList(),
          onCommit: (v) => vm.setSlot(node.id, (slot) => slot.vAlign = UmgAlign.values.firstWhere((a) => a.name == v), label: 'V Align'),
        ),
      ],
    );
  }

  /// 4×4 preset matrix: rows top/center/bottom/stretch × columns left/center/right/stretch.
  Widget _anchorMatrix(UmgNode node, {required bool enabled}) {
    const rowsPresets = [
      [UmgAnchorPreset.topLeft, UmgAnchorPreset.topCenter, UmgAnchorPreset.topRight, UmgAnchorPreset.stretchTop],
      [UmgAnchorPreset.centerLeft, UmgAnchorPreset.center, UmgAnchorPreset.centerRight, UmgAnchorPreset.stretchMiddle],
      [UmgAnchorPreset.bottomLeft, UmgAnchorPreset.bottomCenter, UmgAnchorPreset.bottomRight, UmgAnchorPreset.stretchBottom],
      [UmgAnchorPreset.stretchLeft, UmgAnchorPreset.stretchCenter, UmgAnchorPreset.stretchRight, UmgAnchorPreset.fullStretch],
    ];
    final s = node.slot;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rowsPresets)
            Row(
              children: [
                for (final preset in row)
                  Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: Tooltip(
                      tooltip: (_) => TooltipContainer(child: Text(enabled ? preset.label : '${preset.label} (unavailable: not a Canvas Panel slot)', style: const TextStyle(fontSize: 9))),
                      child: SizedBox(
                        width: 34,
                        height: 22,
                        child: Button(
                          key: ValueKey('umg_anchor_${preset.name}'),
                          style: (enabled && s.anchorMin == preset.min && s.anchorMax == preset.max) ? const ButtonStyle.primary(density: ButtonDensity.compact) : const ButtonStyle.outline(density: ButtonDensity.compact),
                          onPressed: enabled ? () => vm.applyAnchorPreset(node.id, preset) : null,
                          child: CustomPaint(size: const Size(16, 12), painter: _AnchorGlyphPainter(preset)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _slotNumber(
    UmgNode node,
    String label,
    double value,
    double defaultValue,
    void Function(UmgSlot slot, double v) apply, {
    int fractionDigits = 1,
    double? min,
    double? max,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ScrubNumericField(
        key: ValueKey('umg_slot_${label}_${node.id}'),
        label: label,
        labelWidth: 64,
        value: value,
        defaultValue: defaultValue,
        fractionDigits: fractionDigits,
        min: min,
        max: max,
        onChanged: (v) {
          vm.beginInteraction('$label ${node.name}');
          vm.previewSlot(node.id, (slot) => apply(slot, v));
        },
        onCommit: (v) {
          vm.beginInteraction('$label ${node.name}');
          vm.previewSlot(node.id, (slot) => apply(slot, v));
          vm.endInteraction();
        },
        onReset: () => vm.setSlot(node.id, (slot) => apply(slot, defaultValue), label: 'Reset $label'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  Widget _appearanceSection(BuildContext context, UmgNode node) {
    final props = node.props;
    final rows = <Widget>[];

    if (props.containsKey('color')) {
      rows.add(_label('Color and Tint'));
      rows.add(_propColor(node, 'Color', 'color', key_: ValueKey('umg_color_${node.id}')));
      rows.add(const SizedBox(height: 4));
    }
    if (props.containsKey('fontSize')) {
      rows.add(_propNumber(node, 'Font Size', 'fontSize', 8, 96, unit: 'pt'));
    }
    if (node.type == UmgWidgetType.text) rows.add(_propText(node, 'Text', 'text'));
    if (node.type == UmgWidgetType.button) {
      rows.add(_propText(node, 'Label', 'label'));
      rows.add(_label('Button Style'));
      rows.add(EnumField(
        value: props['style']?.toString() ?? 'primary',
        enumValues: const ['primary', 'secondary', 'outline', 'ghost', 'destructive'],
        onCommit: (v) => vm.setProp(node.id, 'style', v),
      ));
    }
    if (node.type == UmgWidgetType.checkBox) {
      rows.add(_propText(node, 'Label', 'label'));
      rows.add(_switchRow('Checked', props['checked'] == true, ValueKey('umg_checked_${node.id}'), (v) => vm.setProp(node.id, 'checked', v)));
    }
    if (node.type == UmgWidgetType.editableText) {
      rows.add(_propText(node, 'Text', 'text'));
      rows.add(_propText(node, 'Hint', 'hint'));
    }
    if (node.type == UmgWidgetType.comboBox) {
      rows.add(_propText(node, 'Options (comma separated)', 'options'));
      rows.add(_propText(node, 'Selected', 'selected'));
    }
    if (node.type == UmgWidgetType.progressBar) rows.add(_propNumber(node, 'Percent', 'percent', 0, 1, fractionDigits: 2));
    if (node.type == UmgWidgetType.slider) rows.add(_propNumber(node, 'Value', 'value', 0, 1, fractionDigits: 2));
    if (node.type == UmgWidgetType.border) {
      rows.add(_propNumber(node, 'Padding', 'padding', 0, 200));
      // Border stays for old documents; Container replaces it.
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OutlineButton(
          key: ValueKey('umg_convert_to_container_${node.id}'),
          onPressed: () => vm.convertBorderToContainer(node.id),
          child: const Text('Convert to Container', style: TextStyle(fontSize: 9)),
        ),
      ));
    }
    if (node.type == UmgWidgetType.container) rows.addAll(_containerSections(node));
    if (node.type.isShadcn) rows.addAll(_shadcnFields(node));
    if (node.type == UmgWidgetType.sizeBox) {
      rows.add(_propNumber(node, 'Width', 'width', 1, 8192));
      rows.add(_propNumber(node, 'Height', 'height', 1, 8192));
    }
    if (node.type == UmgWidgetType.gridPanel) rows.add(_propNumber(node, 'Columns', 'columns', 1, 32, fractionDigits: 0, asInt: true));
    if (node.type == UmgWidgetType.widgetSwitcher) rows.add(_propNumber(node, 'Active Index', 'activeIndex', 0, 64, fractionDigits: 0, asInt: true));
    if (node.type == UmgWidgetType.scrollBox) {
      rows.add(_label('Orientation'));
      rows.add(EnumField(
        value: props['orientation']?.toString() ?? 'vertical',
        enumValues: const ['vertical', 'horizontal'],
        onCommit: (v) => vm.setProp(node.id, 'orientation', v),
      ));
    }
    if (node.type == UmgWidgetType.image) {
      rows.add(_label('Image Brush · Draw As'));
      rows.add(EnumField(
        value: props['drawAs']?.toString() ?? 'image',
        enumValues: const ['image', 'box', 'border'],
        onCommit: (v) => vm.setProp(node.id, 'drawAs', v),
      ));
      rows.add(const SizedBox(height: 4));
      rows.add(_label('Texture (TEXTURE .lmas)'));
      final textures = vm.textureAssets;
      final current = props['texture']?.toString() ?? '';
      rows.add(AssetPickerSelect(
        key: ValueKey('umg_texture_select_${node.id}'),
        keyPrefix: 'umg_texture_${node.id}',
        assets: textures,
        selectedPath: current.isEmpty ? null : current,
        placeholder: '(none)',
        onSelected: (t) => vm.bindTexture(node.id, t),
        onCleared: () => vm.bindTexture(node.id, null),
      ));
      if (textures.isEmpty) rows.add(_hint('No TEXTURE assets in this project yet — import one in the Content Browser.'));
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GhostButton(onPressed: vm.refreshTextures, child: const Text('Rescan textures', style: TextStyle(fontSize: 9))),
      ));
    }
    if (node.type.isTextBearing) rows.addAll(_textEffects(node));
    if (rows.isEmpty) rows.add(_hint('${node.type.displayName} has no appearance properties.'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  // ---------------------------------------------------------------------------
  // Container
  // ---------------------------------------------------------------------------

  /// Background / Border / Corners / Spacing / Shadow / Size & Alignment of
  /// a Container; every edit is one undo step.
  List<Widget> _containerSections(UmgNode node) {
    final p = node.props;
    final gradient = p['gradient'] is Map ? Map<String, dynamic>.from(p['gradient'] as Map) : null;
    final gradientType = gradient?['type']?.toString() ?? 'none';
    final gradientColors = (gradient?['colors'] as List?)?.map((c) => c.toString()).toList() ?? const ['#FB7C01FF', '#1B1B22FF'];
    final radius = p['cornerRadius'];
    final perCorner = radius is List;
    final shadows = p['shadows'] is List ? (p['shadows'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
    final shadow = shadows.isEmpty ? null : shadows.first;
    List<double> quad(Object? v) => v is List && v.length >= 4 ? [for (final e in v.take(4)) e is num ? e.toDouble() : 0.0] : (v is num ? List.filled(4, v.toDouble()) : [0.0, 0.0, 0.0, 0.0]);
    final textures = vm.textureAssets;
    final image = p['backgroundImage']?.toString() ?? '';

    void setGradient(Map<String, dynamic>? g) => vm.setProp(node.id, 'gradient', g);
    Map<String, dynamic> gradientWith(String key, Object value) => {
          'type': gradientType == 'none' ? 'linear' : gradientType,
          'colors': gradientColors,
          'begin': gradient?['begin'] ?? 'centerLeft',
          'end': gradient?['end'] ?? 'centerRight',
          'center': gradient?['center'] ?? 'center',
          'radius': gradient?['radius'] ?? 0.5,
          key: value,
        };
    void setShadow(String key, Object value, {bool commit = true}) {
      final next = Map<String, dynamic>.of(shadow ?? const {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0});
      next[key] = value;
      vm.beginInteraction('Shadow ${node.name}');
      vm.previewProp(node.id, 'shadows', [next, ...shadows.skip(1)]);
      if (commit) vm.endInteraction();
    }

    const alignNames = ['fill', ...['topLeft', 'topCenter', 'topRight', 'centerLeft', 'center', 'centerRight', 'bottomLeft', 'bottomCenter', 'bottomRight']];
    return [
      const SizedBox(height: 4),
      _groupHeader('Background', LucideIcons.paintBucket, ValueKey('umg_group_background_${node.id}')),
      _label('Background Color'),
      _propColor(node, 'Background Color', 'backgroundColor', alpha: true),
      const SizedBox(height: 4),
      _label('Gradient'),
      EnumField(
        key: ValueKey('umg_gradient_type_${node.id}'),
        value: gradientType,
        enumValues: const ['none', 'linear', 'radial'],
        onCommit: (v) => setGradient(v == 'none' ? null : gradientWith('type', v)),
      ),
      if (gradient != null) ...[
        _label('Gradient Start'),
        _colorRow(node, 'umg_gradient_start_${node.id}', gradientColors.first, (v) => setGradient(gradientWith('colors', [v, ...gradientColors.skip(1)]))),
        _label('Gradient End'),
        _colorRow(node, 'umg_gradient_end_${node.id}', gradientColors.last, (v) => setGradient(gradientWith('colors', [...gradientColors.take(gradientColors.length - 1), v]))),
        if (gradientType == 'linear') ...[
          _label('Begin'),
          EnumField(value: gradient['begin']?.toString() ?? 'centerLeft', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('begin', v))),
          _label('End'),
          EnumField(value: gradient['end']?.toString() ?? 'centerRight', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('end', v))),
        ] else ...[
          _label('Center'),
          EnumField(value: gradient['center']?.toString() ?? 'center', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('center', v))),
          _numberRow(node, 'Radius', 'gradient_radius', (gradient['radius'] as num?)?.toDouble() ?? 0.5, 0.5, (v) => setGradient(gradientWith('radius', v)), min: 0, max: 2, slider: true),
        ],
      ],
      _label('Background Image (TEXTURE .lmas)'),
      AssetPickerSelect(
        key: ValueKey('umg_bg_texture_select_${node.id}'),
        keyPrefix: 'umg_bg_texture_${node.id}',
        assets: textures,
        selectedPath: image.isEmpty ? null : image,
        placeholder: '(none)',
        onSelected: (t) => vm.bindTexture(node.id, t),
        onCleared: () => vm.bindTexture(node.id, null),
      ),
      _label('Image Fit'),
      EnumField(
        value: p['backgroundFit']?.toString() ?? 'cover',
        enumValues: const ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'none', 'scaleDown'],
        onCommit: (v) => vm.setProp(node.id, 'backgroundFit', v),
      ),
      const SizedBox(height: 4),
      _groupHeader('Border', LucideIcons.square, ValueKey('umg_group_border_${node.id}')),
      _label('Border Color'),
      _propColor(node, 'Border Color', 'borderColor', alpha: true),
      _propSlider(node, 'Width', 'borderWidth', 0, 32, unit: 'px'),
      for (final (i, side) in const ['Top', 'Right', 'Bottom', 'Left'].indexed)
        _switchRow('$side Side', (p['borderSides'] is List && (p['borderSides'] as List).length > i) ? (p['borderSides'] as List)[i] != false : true,
            ValueKey('umg_border_side_${side.toLowerCase()}_${node.id}'), (v) {
          final sides = [for (var j = 0; j < 4; j++) (p['borderSides'] is List && (p['borderSides'] as List).length > j) ? (p['borderSides'] as List)[j] != false : true];
          sides[i] = v;
          vm.setProp(node.id, 'borderSides', sides);
        }),
      const SizedBox(height: 4),
      _groupHeader('Corners', LucideIcons.squareRoundCorner, ValueKey('umg_group_corners_${node.id}')),
      _switchRow('Per Corner', perCorner, ValueKey('umg_corner_per_corner_${node.id}'), (v) {
        final q = quad(radius);
        vm.setProp(node.id, 'cornerRadius', v ? q : q.first);
      }),
      if (!perCorner)
        _propSlider(node, 'Radius', 'cornerRadius', 0, 128, unit: 'px')
      else
        for (final (i, corner) in const ['Top Left', 'Top Right', 'Bottom Right', 'Bottom Left'].indexed)
          _numberRow(node, corner, 'corner_$i', quad(radius)[i], 0, (v) {
            final q = quad(node.props['cornerRadius']);
            q[i] = v;
            return q;
          }.call, min: 0, max: 128, slider: true, listKey: 'cornerRadius'),
      const SizedBox(height: 4),
      _groupHeader('Spacing', LucideIcons.move, ValueKey('umg_group_spacing_${node.id}')),
      for (final key in const ['padding', 'margin'])
        for (final (i, side) in const ['Left', 'Top', 'Right', 'Bottom'].indexed)
          _numberRow(node, '${key == 'padding' ? 'Padding' : 'Margin'} $side', '${key}_$i', quad(p[key])[i], 0, (v) {
            final q = quad(node.props[key]);
            q[i] = v;
            return q;
          }.call, min: 0, max: 512, listKey: key),
      const SizedBox(height: 4),
      _groupHeader('Shadow', LucideIcons.squareStack, ValueKey('umg_group_box_shadow_${node.id}')),
      _switchRow('Drop Shadow', shadow != null, ValueKey('umg_box_shadow_enabled_${node.id}'), (v) {
        vm.setProp(node.id, 'shadows', v ? [const {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0}] : <Map<String, dynamic>>[]);
      }),
      if (shadow != null) ...[
        _label('Shadow Color'),
        _colorRow(node, 'umg_box_shadow_color_${node.id}', shadow['color']?.toString() ?? '#00000066', (v) => setShadow('color', v)),
        for (final (key, label, min, max) in const [('offsetX', 'Offset X', -64.0, 64.0), ('offsetY', 'Offset Y', -64.0, 64.0), ('blur', 'Blur', 0.0, 64.0), ('spread', 'Spread', -32.0, 32.0)])
          _numberRow(node, label, 'box_shadow_$key', (shadow[key] as num?)?.toDouble() ?? 0, 0, (v) => setShadow(key, v, commit: false),
              min: min, max: max, slider: key == 'blur', onCommitOverride: (v) => setShadow(key, v)),
      ],
      const SizedBox(height: 4),
      _groupHeader('Size & Alignment', LucideIcons.scaling, ValueKey('umg_group_size_${node.id}')),
      _hint('0 = automatic size.'),
      for (final (key, label) in const [('width', 'Width'), ('height', 'Height'), ('minWidth', 'Min Width'), ('maxWidth', 'Max Width'), ('minHeight', 'Min Height'), ('maxHeight', 'Max Height')])
        _numberRow(node, label, 'size_$key', (p[key] as num?)?.toDouble() ?? 0, 0, (v) => v <= 0 ? null : v, min: 0, max: 8192, listKey: key),
      _label('Child Alignment'),
      EnumField(
        key: ValueKey('umg_container_alignment_${node.id}'),
        value: p['alignment']?.toString() ?? 'fill',
        enumValues: alignNames,
        onCommit: (v) => vm.setProp(node.id, 'alignment', v == 'fill' ? null : v),
      ),
    ];
  }

  /// A colour field with alpha committing through [onCommit] (one step).
  Widget _colorRow(UmgNode node, String key, String value, void Function(String) onCommit) => ColorField(
        key: ValueKey(key),
        value: value,
        defaultValue: value,
        showAlpha: true,
        onChanged: (_) {},
        onCommit: onCommit,
        onReset: () {},
      );

  /// A number row: [toValue] maps the edited number to the prop value stored
  /// under [listKey] (the whole list for a side / corner, null for "auto");
  /// without [listKey] the caller applies it in [toValue] itself. Scrubbing
  /// previews, release commits one undo step.
  Widget _numberRow(
    UmgNode node,
    String label,
    String id,
    double value,
    double defaultValue,
    Object? Function(double v) toValue, {
    double? min,
    double? max,
    bool slider = false,
    String? listKey,
    void Function(double v)? onCommitOverride,
  }) {
    void preview(double v) {
      final next = toValue(v);
      if (listKey == null) return;
      vm.beginInteraction('$label ${node.name}');
      vm.previewProp(node.id, listKey, next);
    }

    void commit(double v) {
      if (onCommitOverride != null) return onCommitOverride(v);
      preview(v);
      vm.endInteraction();
    }

    final field = slider
        ? SliderField(
            key: ValueKey('umg_prop_${id}_${node.id}'),
            value: value,
            defaultValue: defaultValue,
            min: min ?? 0,
            max: max ?? 100,
            fractionDigits: 1,
            onChanged: preview,
            onCommit: commit,
            onReset: () => commit(defaultValue),
          )
        : ScrubNumericField(
            key: ValueKey('umg_prop_${id}_${node.id}'),
            label: '',
            value: value,
            defaultValue: defaultValue,
            min: min,
            max: max,
            fractionDigits: 1,
            onChanged: preview,
            onCommit: commit,
            onReset: () => commit(defaultValue),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
        Expanded(child: field),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // shadcn components
  // ---------------------------------------------------------------------------

  /// The fields of a shadcn component, from its props.
  List<Widget> _shadcnFields(UmgNode node) {
    final rows = <Widget>[
      const SizedBox(height: 4),
      _groupHeader('shadcn ${node.type.displayName}', LucideIcons.component, ValueKey('umg_group_shadcn_${node.id}')),
    ];
    if (vm.widgetLibrary != kUmgWidgetLibraryShadcn) {
      rows.add(_hint('This project uses plain Flutter widgets: shadcn components need the shadcn widget library (Project Settings > User Interface).'));
    }
    const labels = {
      'title': 'Title', 'description': 'Description', 'text': 'Text', 'label': 'Label', 'initials': 'Initials', 'tooltip': 'Tooltip',
      'hint': 'Placeholder', 'options': 'Options (comma separated)', 'items': 'Items (comma separated)', 'selected': 'Selected',
    };
    for (final entry in node.props.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final k = entry.key;
      final v = entry.value;
      if (labels.containsKey(k)) {
        rows.add(_propText(node, labels[k]!, k));
      } else if (v is bool) {
        rows.add(_switchRow(k == 'checked' ? 'Checked' : 'Destructive', v, ValueKey('umg_prop_${k}_${node.id}'), (b) => vm.setProp(node.id, k, b)));
      } else if (k == 'variant') {
        rows.add(_label('Variant'));
        rows.add(EnumField(value: v?.toString() ?? 'primary', enumValues: const ['primary', 'secondary', 'outline', 'destructive'], onCommit: (x) => vm.setProp(node.id, k, x)));
      } else if (k == 'orientation') {
        rows.add(_label('Orientation'));
        rows.add(EnumField(value: v?.toString() ?? 'horizontal', enumValues: const ['horizontal', 'vertical'], onCommit: (x) => vm.setProp(node.id, k, x)));
      } else if (k == 'percent' || k == 'value') {
        rows.add(_propSlider(node, k == 'percent' ? 'Percent' : 'Value', k, 0, 1));
      } else if (k == 'activeIndex' || k == 'expandedIndex' || k == 'lines') {
        rows.add(_propNumber(node, const {'activeIndex': 'Active Tab', 'expandedIndex': 'Expanded Item', 'lines': 'Lines'}[k]!, k, k == 'expandedIndex' ? -1 : 0, 32,
            fractionDigits: 0, asInt: true));
      } else if (k == 'padding' || k == 'size') {
        rows.add(_propSlider(node, k == 'padding' ? 'Padding' : 'Size', k, 0, 128, unit: 'px'));
      }
    }
    return rows;
  }

  /// The Shadow (enabled, colour with alpha, offset,
  /// blur) and Outline (size, colour) of a text-bearing element; the canvas
  /// previews every edit live and each is one undo step.
  List<Widget> _textEffects(UmgNode node) {
    return [
      const SizedBox(height: 4),
      _groupHeader('Shadow', LucideIcons.squareStack, ValueKey('umg_group_shadow_${node.id}')),
      _switchRow('Shadow Enabled', node.props['shadowEnabled'] == true, ValueKey('umg_shadow_enabled_${node.id}'),
          (v) => vm.setProp(node.id, 'shadowEnabled', v)),
      _label('Shadow Color'),
      _propColor(node, 'Shadow Color', 'shadowColor', alpha: true),
      const SizedBox(height: 4),
      _propNumber(node, 'Offset X', 'shadowOffsetX', -200, 200, unit: 'px'),
      _propNumber(node, 'Offset Y', 'shadowOffsetY', -200, 200, unit: 'px'),
      _propSlider(node, 'Blur', 'shadowBlur', 0, 32, unit: 'px'),
      const SizedBox(height: 4),
      _groupHeader('Outline', LucideIcons.pencilLine, ValueKey('umg_group_outline_${node.id}')),
      _propSlider(node, 'Size', 'outlineSize', 0, 16, unit: 'px'),
      _label('Outline Color'),
      _propColor(node, 'Outline Color', 'outlineColor', alpha: true),
    ];
  }

  Widget _groupHeader(String title, IconData icon, Key key) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(
          children: [
            Icon(icon, size: 10, color: EditorColors.mutedForeground),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  /// A colour prop: live preview while picking, one undo step on commit.
  Widget _propColor(UmgNode node, String label, String key, {bool alpha = false, Key? key_}) {
    final defaults = node.type.defaultProps();
    final fallback = alpha ? '#FFFFFFFF' : '#FFFFFF';
    return ColorField(
      key: key_ ?? ValueKey('umg_prop_${key}_${node.id}'),
      value: node.props[key]?.toString() ?? defaults[key]?.toString() ?? fallback,
      defaultValue: defaults[key]?.toString() ?? fallback,
      showAlpha: alpha,
      onChanged: (v) {
        vm.beginInteraction('$label ${node.name}');
        vm.previewProp(node.id, key, v);
      },
      onCommit: (v) {
        vm.beginInteraction('$label ${node.name}');
        vm.previewProp(node.id, key, v);
        vm.endInteraction();
      },
      onReset: () => vm.setProp(node.id, key, defaults[key]),
    );
  }

  /// A bounded number prop as the shared slider + number field.
  Widget _propSlider(UmgNode node, String label, String key, double min, double max, {String? unit}) {
    final raw = node.props[key];
    final value = raw is num ? raw.toDouble() : (double.tryParse(raw?.toString() ?? '') ?? 0);
    final def = node.type.defaultProps()[key];
    final defaultValue = def is num ? def.toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
          Expanded(
            child: SliderField(
              key: ValueKey('umg_prop_${key}_${node.id}'),
              value: value,
              defaultValue: defaultValue,
              min: min,
              max: max,
              hardMin: 0,
              hardMax: double.infinity,
              unit: unit,
              fractionDigits: 1,
              onChanged: (v) {
                vm.beginInteraction('$label ${node.name}');
                vm.previewProp(node.id, key, v);
              },
              onCommit: (v) {
                vm.beginInteraction('$label ${node.name}');
                vm.previewProp(node.id, key, v);
                vm.endInteraction();
              },
              onReset: () => vm.setProp(node.id, key, defaultValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _propNumber(UmgNode node, String label, String key, double min, double max, {int fractionDigits = 1, bool asInt = false, String? unit}) {
    final defaults = node.type.defaultProps();
    final raw = node.props[key];
    final value = raw is num ? raw.toDouble() : (double.tryParse(raw?.toString() ?? '') ?? 0);
    final def = defaults[key];
    final defaultValue = def is num ? def.toDouble() : 0.0;
    dynamic convert(double v) => asInt ? v.round() : v;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ScrubNumericField(
        key: ValueKey('umg_prop_${key}_${node.id}'),
        label: label,
        labelWidth: 64,
        value: value,
        defaultValue: defaultValue,
        min: min,
        max: max,
        unit: unit,
        fractionDigits: fractionDigits,
        onChanged: (v) {
          vm.beginInteraction('$label ${node.name}');
          vm.previewProp(node.id, key, convert(v));
        },
        onCommit: (v) {
          vm.beginInteraction('$label ${node.name}');
          vm.previewProp(node.id, key, convert(v));
          vm.endInteraction();
        },
        onReset: () => vm.setProp(node.id, key, convert(defaultValue)),
      ),
    );
  }

  Widget _propText(UmgNode node, String label, String key) {
    final current = node.props[key]?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            key: ValueKey('umg_prop_${key}_${node.id}_$current'),
            initialValue: current,
            style: const TextStyle(fontSize: 9.5),
            onSubmitted: (v) => vm.setProp(node.id, key, v),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// The green `+` per event — it creates (or, once
  /// bound, Open focuses) the bound `On <Event> (<element>)` node in the
  /// widget's graph; hand-written USER CODE of a handler is flagged.
  Widget _eventsSection(UmgNode node) {
    final available = node.type.availableEvents;
    if (available.isEmpty) {
      return _hint('${node.type.displayName} exposes no events.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in available)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: vm.isEventBound(node.id, name) ? _boundEventRow(node, name) : _unboundEventRow(node, name),
          ),
        const SizedBox(height: 4),
        _hint('+ adds the event to the widget\'s graph (Graph tab); the generated handler runs it.'),
      ],
    );
  }

  Widget _unboundEventRow(UmgNode node, String name) => Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text('Add $name to the graph', style: const TextStyle(fontSize: 9))),
            child: OutlineButton(
              key: ValueKey('umg_event_add_${name}_${node.id}'),
              size: ButtonSize.small,
              onPressed: () => vm.bindWidgetEvent(node.id, name),
              child: const Icon(LucideIcons.plus, size: 11, color: EditorColors.logSuccess),
            ),
          ),
        ],
      );

  Widget _boundEventRow(UmgNode node, String name) {
    final handWritten = vm.hasHandWrittenCode(node.id, name);
    return Row(
      children: [
        const Icon(LucideIcons.zap, size: 10, color: EditorColors.logSuccess),
        const SizedBox(width: 4),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 9, color: EditorColors.foreground))),
        if (handWritten)
          Tooltip(
            tooltip: (_) => const TooltipContainer(
                child: Text('The generated handler keeps hand-written USER CODE; it runs after the graph', style: TextStyle(fontSize: 9))),
            child: Padding(
              key: ValueKey('umg_event_user_code_${name}_${node.id}'),
              padding: const EdgeInsets.only(right: 4),
              child: const Icon(LucideIcons.code, size: 10, color: EditorColors.logWarning),
            ),
          ),
        GhostButton(
          key: ValueKey('umg_event_open_${name}_${node.id}'),
          size: ButtonSize.small,
          onPressed: () => vm.bindWidgetEvent(node.id, name),
          child: const Text('Open', style: TextStyle(fontSize: 9)),
        ),
        GhostButton(
          key: ValueKey('umg_event_remove_${name}_${node.id}'),
          size: ButtonSize.small,
          onPressed: () => vm.removeEvent(node.id, name),
          child: const Icon(LucideIcons.x, size: 10),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 2),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic)),
      );

  Widget _switchRow(String label, bool value, Key key, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
            Switch(key: key, value: value, onChanged: onChanged),
          ],
        ),
      );
}

/// Draws the little anchor glyph (dot/bar) of a preset.
class _AnchorGlyphPainter extends CustomPainter {
  final UmgAnchorPreset preset;
  const _AnchorGlyphPainter(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = EditorColors.mutedForeground;
    canvas.drawRect(Offset.zero & size, frame);
    final fill = Paint()..color = EditorColors.foreground;
    final stretchX = preset.min.dx != preset.max.dx;
    final stretchY = preset.min.dy != preset.max.dy;
    final w = stretchX ? size.width - 4 : 4.0;
    final h = stretchY ? size.height - 4 : 4.0;
    final x = stretchX ? 2.0 : preset.min.dx * (size.width - 4) ;
    final y = stretchY ? 2.0 : preset.min.dy * (size.height - 4);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), fill);
  }

  @override
  bool shouldRepaint(_AnchorGlyphPainter old) => old.preset != preset;
}
