part of '../slot_inspector.dart';

/// The Slot section: anchors, position/size/alignment or box padding.
extension _UmgSlotInspectorSlot on UmgSlotInspector {
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
}
