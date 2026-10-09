part of '../slot_inspector.dart';

/// shadcn component fields, the prop rows they use, and Widget Events.
extension _UmgSlotInspectorComponents on UmgSlotInspector {
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
}
