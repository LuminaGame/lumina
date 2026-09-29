part of '../umg_widget_codegen.dart';

// ---------------------------------------------------------------------------
// Container and shadcn components
// ---------------------------------------------------------------------------

/// The texture path of a Container's background image ('' for none).
String _containerTexture(UmgNode n) =>
    n.type == UmgWidgetType.container ? (n.props['backgroundImage']?.toString() ?? '') : '';

String _colorLit(Color c) => 'Color(0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';

String _alignmentLit(Alignment a) => 'Alignment(${_f(a.x)}, ${_f(a.y)})';

String _insetsLit(EdgeInsets e) => 'EdgeInsets.fromLTRB(${_f(e.left)}, ${_f(e.top)}, ${_f(e.right)}, ${_f(e.bottom)})';

/// The designer's Container style as a `const LuminaUmgContainerStyle(...)`
/// literal, parsed by the engine exactly as the runtime parses it.
String _containerStyleLiteral(UmgNode n) {
  final s = LuminaUmgContainerStyle.fromProps(Map<String, Object?>.from(n.props));
  final r = s.cornerRadius;
  final args = <String>[
    'backgroundColor: ${_colorLit(s.backgroundColor)}',
    if (s.gradient != null)
      'gradient: LuminaUmgGradient(type: ${_str(s.gradient!.type)}, colors: [${s.gradient!.colors.map(_colorLit).join(', ')}]'
          '${s.gradient!.stops == null ? '' : ', stops: [${s.gradient!.stops!.map(_f).join(', ')}]'}'
          ', begin: ${_alignmentLit(s.gradient!.begin)}, end: ${_alignmentLit(s.gradient!.end)}'
          ', center: ${_alignmentLit(s.gradient!.center)}, radius: ${_f(s.gradient!.radius)})',
    'backgroundFit: BoxFit.${s.backgroundFit.name}',
    'borderColor: ${_colorLit(s.borderColor)}',
    'borderWidth: ${_f(s.borderWidth)}',
    'borderTop: ${s.borderTop}',
    'borderRight: ${s.borderRight}',
    'borderBottom: ${s.borderBottom}',
    'borderLeft: ${s.borderLeft}',
    'cornerRadius: BorderRadius.only(topLeft: Radius.circular(${_f(r.topLeft.x)}), topRight: Radius.circular(${_f(r.topRight.x)}), '
        'bottomRight: Radius.circular(${_f(r.bottomRight.x)}), bottomLeft: Radius.circular(${_f(r.bottomLeft.x)}))',
    'padding: ${_insetsLit(s.padding)}',
    'margin: ${_insetsLit(s.margin)}',
    'shadows: [${s.shadows.map((b) => 'BoxShadow(color: ${_colorLit(b.color)}, offset: Offset(${_f(b.offset.dx)}, ${_f(b.offset.dy)}), blurRadius: ${_f(b.blurRadius)}, spreadRadius: ${_f(b.spreadRadius)})').join(', ')}]',
    if (s.width != null) 'width: ${_f(s.width!)}',
    if (s.height != null) 'height: ${_f(s.height!)}',
    if (s.minWidth != null) 'minWidth: ${_f(s.minWidth!)}',
    if (s.maxWidth != null) 'maxWidth: ${_f(s.maxWidth!)}',
    if (s.minHeight != null) 'minHeight: ${_f(s.minHeight!)}',
    if (s.maxHeight != null) 'maxHeight: ${_f(s.maxHeight!)}',
    if (s.alignment != null) 'alignment: ${_alignmentLit(s.alignment!)}',
  ];
  return 'const LuminaUmgContainerStyle(${args.join(', ')})';
}

/// A Container: Flutter's `Container` (through the runtime's
/// `LuminaUmgContainer`) in both libraries, its style read through the
/// binding over the designer's; a background texture loads from the bundle.
String _emitContainer(UmgNode node, UmgDocument doc, String indent, bool stateful, bool plain, String inst) {
  final key = "key: const ValueKey('${node.fieldName}')";
  final inner = '$indent  ';
  final style = 'LuminaUmgElementBinding.containerStyle(e, ${_containerStyleLiteral(node)})';
  final texture = _containerTexture(node);
  String container(String ind, String? image) {
    final i2 = '$ind  ';
    final b = StringBuffer('LuminaUmgContainer(\n');
    if (image == null) b.writeln('$i2$key,');
    b.writeln('${i2}style: $style,');
    if (image != null) b.writeln('${i2}image: $image,');
    if (node.children.isNotEmpty) {
      final c = node.children.first;
      b.writeln('${i2}child: ${_padded(c, _emit(c, doc, i2, stateful, plain, inst))},');
    }
    b.write('$ind)');
    return b.toString();
  }

  if (texture.isEmpty) return container(indent, null);
  final b = StringBuffer();
  b.writeln('FutureBuilder<Uint8List?>(');
  b.writeln('$inner$key,');
  b.writeln("${inner}future: _umgLoadTexture(LuminaUmgElementBinding.value<String>(e, 'backgroundImage', ${_str(texture)})),");
  b.writeln('${inner}builder: (context, snapshot) => ${container(inner, 'snapshot.data == null ? null : MemoryImage(snapshot.data!)')},');
  b.write('$indent)');
  return b.toString();
}

/// A shadcn component as the real shadcn_flutter widget (shadcn library).
String _emitShadcn(UmgNode node, UmgDocument doc, String indent, bool stateful, String inst) {
  final key = "key: const ValueKey('${node.fieldName}')";
  final inner = '$indent  ';
  final p = node.props;
  String str(String k, [String? runtimeKey]) =>
      "LuminaUmgElementBinding.value<String>(e, ${_str(runtimeKey ?? k)}, ${_str(p[k]?.toString() ?? '')})";
  String text(String k, [String? runtimeKey]) => 'Text(${str(k, runtimeKey)})';
  List<String> children(String ind) => [for (final c in node.children) _padded(c, _emit(c, doc, ind, stateful, false, inst))];
  final field = '${node.fieldName}Value';
  final handler = _handlerFor(node, 'OnValueChanged');
  String onChanged(String runtimeKey, String v, {bool set = true}) {
    final b = StringBuffer('(v) {\n');
    b.writeln(set ? '$inner  setState(() => $field = $v);' : '$inner  $field = $v;');
    b.writeln('$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, ${_str(runtimeKey)}, $v);');
    if (handler != null) b.writeln('$inner  $handler($v);');
    b.write('$inner}');
    return b.toString();
  }

  switch (node.type) {
    case UmgWidgetType.shadcnCard:
      final kids = children('$inner    ');
      return 'Card(\n$inner$key,\n${inner}padding: EdgeInsets.all(${_double_(node, 'padding', 16)}),\n'
          '${inner}child: Column(\n$inner  mainAxisSize: MainAxisSize.min,\n$inner  crossAxisAlignment: CrossAxisAlignment.start,\n$inner  children: [\n'
          '$inner    Text(${str('title')}, style: const TextStyle(fontWeight: FontWeight.w600)),\n'
          '$inner    Text(${str('description')}, style: const TextStyle(fontSize: 12)).muted(),\n'
          '${kids.isEmpty ? '' : '$inner    const SizedBox(height: 12),\n$inner    ${kids.first},\n'}'
          '$inner  ],\n$inner),\n$indent)';
    case UmgWidgetType.shadcnBadge:
      final badge = switch (p['variant']?.toString()) {
        'secondary' => 'SecondaryBadge',
        'outline' => 'OutlineBadge',
        'destructive' => 'DestructiveBadge',
        _ => 'PrimaryBadge',
      };
      return '$badge($key, child: ${text('text')})';
    case UmgWidgetType.shadcnAvatar:
      return 'Avatar($key, initials: ${str('initials')}, size: ${_double_(node, 'size', 40)})';
    case UmgWidgetType.shadcnAlert:
      return 'Alert(\n$inner$key,\n${inner}title: ${text('title')},\n${inner}content: ${text('description')},\n'
          "${inner}destructive: LuminaUmgElementBinding.value<bool>(e, 'destructive', ${p['destructive'] == true}),\n$indent)";
    case UmgWidgetType.shadcnSeparator:
      if (p['orientation'] == 'vertical') return 'VerticalDivider($key)';
      final label = p['label']?.toString() ?? '';
      return label.isEmpty ? 'Divider($key)' : 'Divider($key, child: ${text('label')})';
    case UmgWidgetType.shadcnProgress:
      return 'Progress($key, progress: ${_double_(node, 'percent', 0.6)}.clamp(0.0, 1.0))';
    case UmgWidgetType.shadcnSwitch:
      return 'Switch(\n$inner$key,\n'
          "${inner}value: LuminaUmgElementBinding.value<bool>(e, 'isChecked', $field),\n"
          "${inner}onChanged: ${onChanged('isChecked', 'v')},\n${inner}trailing: ${text('label')},\n$indent)";
    case UmgWidgetType.shadcnToggle:
      return 'Toggle(\n$inner$key,\n'
          "${inner}value: LuminaUmgElementBinding.value<bool>(e, 'isChecked', $field),\n"
          "${inner}onChanged: ${onChanged('isChecked', 'v')},\n${inner}child: ${text('label')},\n$indent)";
    case UmgWidgetType.shadcnCheckbox:
      return 'Checkbox(\n$inner$key,\n'
          "${inner}state: LuminaUmgElementBinding.value<bool>(e, 'isChecked', $field) ? CheckboxState.checked : CheckboxState.unchecked,\n"
          "${inner}onChanged: (s) {\n$inner  final v = s == CheckboxState.checked;\n$inner  setState(() => $field = v);\n"
          "$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'isChecked', v);\n"
          '${handler == null ? '' : '$inner  $handler(v);\n'}$inner},\n${inner}trailing: ${text('label')},\n$indent)';
    case UmgWidgetType.shadcnTabs:
      final items = _options(p['items']);
      final last = items.isEmpty ? 0 : items.length - 1;
      final index = "LuminaUmgElementBinding.value<int>(e, 'activeIndex', $field).clamp(0, $last)";
      final pages = children('$inner    ');
      return 'Column(\n$inner$key,\n${inner}mainAxisSize: MainAxisSize.min,\n${inner}crossAxisAlignment: CrossAxisAlignment.stretch,\n${inner}children: [\n'
          '$inner  Tabs(\n$inner    index: $index,\n$inner    onChanged: ${onChanged('activeIndex', 'v').replaceAll('\n$inner', '\n$inner  ')},\n'
          '$inner    children: [${items.map((t) => 'TabItem(child: Text(${_str(t)}))').join(', ')}],\n$inner  ),\n'
          '${pages.isEmpty ? '' : '$inner  IndexedStack(\n$inner    index: $index.clamp(0, ${pages.length - 1}),\n$inner    children: [\n${pages.map((c) => '$inner      $c,\n').join()}$inner    ],\n$inner  ),\n'}'
          '$inner],\n$indent)';
    case UmgWidgetType.shadcnAccordion:
      final items = _options(p['items']);
      final expanded = _int(p['expandedIndex'], -1);
      final kids = children('$inner      ');
      final b = StringBuffer('Accordion(\n$inner$key,\n${inner}items: [\n');
      for (var i = 0; i < items.length; i++) {
        b.writeln('$inner  AccordionItem(');
        b.writeln('$inner    expanded: ${i == expanded},');
        b.writeln('$inner    trigger: AccordionTrigger(child: Text(${_str(items[i])})),');
        b.writeln('$inner    content: ${i < kids.length ? kids[i] : 'const SizedBox.shrink()'},');
        b.writeln('$inner  ),');
      }
      b.write('$inner],\n$indent)');
      return b.toString();
    case UmgWidgetType.shadcnTooltip:
      final kids = children(inner);
      return 'Tooltip(\n$inner$key,\n${inner}tooltip: (context) => TooltipContainer(child: ${text('tooltip')}),\n'
          '${inner}child: ${kids.isEmpty ? 'const SizedBox.shrink()' : kids.first},\n$indent)';
    case UmgWidgetType.shadcnChip:
      return 'Chip($key, child: ${text('text')})';
    case UmgWidgetType.shadcnKbd:
      return 'KeyboardDisplay($key, keys: LuminaUmgStyleJson.keyboardKeys(${str('text')}))';
    case UmgWidgetType.shadcnSkeleton:
      final lines = _int(p['lines'], 3).clamp(1, 12);
      return 'Column(\n$inner$key,\n${inner}mainAxisSize: MainAxisSize.min,\n${inner}crossAxisAlignment: CrossAxisAlignment.stretch,\n'
          "${inner}children: [for (var i = 0; i < $lines; i++) const Text('Loading placeholder text line')],\n$indent).asSkeleton()";
    case UmgWidgetType.shadcnTextField:
    case UmgWidgetType.shadcnTextArea:
      final widget = node.type == UmgWidgetType.shadcnTextArea ? 'TextArea' : 'TextField';
      final committed = _handlerFor(node, 'OnTextCommitted');
      return '$widget(\n$inner$key,\n${inner}initialValue: $field,\n${inner}placeholder: ${text('hint', 'hintText')},\n'
          "${committed == null ? '' : '${inner}onSubmitted: $committed,\n'}"
          "${inner}onChanged: ${onChanged('text', 'v', set: false)},\n$indent)";
    case UmgWidgetType.shadcnSelect:
    case UmgWidgetType.shadcnRadioGroup:
      final options = 'LuminaUmgElementBinding.options(e, const [${_options(p['options']).map(_str).join(', ')}])';
      final value = "LuminaUmgElementBinding.value<String?>(e, 'selectedOption', $field)";
      if (node.type == UmgWidgetType.shadcnRadioGroup) {
        return 'RadioGroup<String>(\n$inner$key,\n${inner}value: $value,\n${inner}onChanged: ${onChanged('selectedOption', 'v')},\n'
            '${inner}child: Column(\n$inner  mainAxisSize: MainAxisSize.min,\n$inner  crossAxisAlignment: CrossAxisAlignment.start,\n'
            '$inner  children: [for (final o in $options) RadioItem<String>(value: o, trailing: Text(o))],\n$inner),\n$indent)';
      }
      return 'Select<String>(\n$inner$key,\n${inner}value: $value,\n${inner}onChanged: ${onChanged('selectedOption', 'v')},\n'
          '${inner}itemBuilder: (context, item) => Text(item),\n'
          '${inner}popup: SelectPopup(\n$inner  items: SelectItemList(\n$inner    children: [\n'
          '$inner      for (final o in $options) SelectItemButton(value: o, child: Text(o)),\n$inner    ],\n$inner  ),\n$inner),\n$indent)';
    case UmgWidgetType.shadcnSlider:
      return 'Slider(\n$inner$key,\n'
          "${inner}value: SliderValue.single(LuminaUmgElementBinding.value<double>(e, 'value', $field).clamp(0.0, 1.0)),\n"
          "${inner}onChanged: ${onChanged('value', 'v.value')},\n$indent)";
    default:
      final button = switch (node.type) {
        UmgWidgetType.shadcnSecondaryButton => 'SecondaryButton',
        UmgWidgetType.shadcnOutlineButton => 'OutlineButton',
        UmgWidgetType.shadcnGhostButton => 'GhostButton',
        UmgWidgetType.shadcnDestructiveButton => 'DestructiveButton',
        UmgWidgetType.shadcnLinkButton => 'LinkButton',
        _ => 'PrimaryButton',
      };
      final clicked = _handlerFor(node, 'OnClicked');
      return '$button(\n$inner$key,\n${inner}onPressed: LuminaUmgElementBinding.isEnabled(e) ? ${clicked ?? '() {}'} : null,\n'
          "${inner}child: ${text('label')},\n$indent)";
  }
}

String _overlayChild(UmgNode c, UmgDocument doc, String indent, bool stateful, bool plain, String inst) {
  final s = c.slot;
  final child = _emit(c, doc, '$indent    ', stateful, plain, inst);
  final padding = 'EdgeInsets.fromLTRB(${_f(s.paddingLeft)}, ${_f(s.paddingTop)}, ${_f(s.paddingRight)}, ${_f(s.paddingBottom)})';
  if (s.hAlign == UmgAlign.fill && s.vAlign == UmgAlign.fill) {
    return 'Positioned.fill(\n$indent  child: Padding(\n$indent    padding: $padding,\n$indent    child: $child,\n$indent  ),\n$indent)';
  }
  final sized = (s.hAlign == UmgAlign.fill || s.vAlign == UmgAlign.fill)
      ? 'SizedBox(\n$indent      width: ${s.hAlign == UmgAlign.fill ? 'double.infinity' : 'null'},\n$indent      height: ${s.vAlign == UmgAlign.fill ? 'double.infinity' : 'null'},\n$indent      child: $child,\n$indent    )'
      : child;
  return 'Positioned.fill(\n$indent  child: Padding(\n$indent    padding: $padding,\n$indent    child: Align(\n$indent      alignment: ${_alignment(s)},\n$indent      child: $sized,\n$indent    ),\n$indent  ),\n$indent)';
}

String _boxChild(UmgNode c, UmgDocument doc, String indent, bool stateful, bool plain, bool isRow, String inst) {
  final s = c.slot;
  var child = _emit(c, doc, '$indent  ', stateful, plain, inst);
  final cross = isRow ? s.vAlign : s.hAlign;
  if (cross != UmgAlign.fill) {
    final a = isRow ? 'Alignment(0.0, ${_f(_alignValue(cross))})' : 'Alignment(${_f(_alignValue(cross))}, 0.0)';
    child = 'Align(alignment: $a, child: $child)';
  }
  child = 'Padding(\n$indent  padding: EdgeInsets.fromLTRB(${_f(s.paddingLeft)}, ${_f(s.paddingTop)}, ${_f(s.paddingRight)}, ${_f(s.paddingBottom)}),\n$indent  child: $child,\n$indent)';
  if (s.fill) {
    child = 'Expanded(flex: ${(s.flex * 100).round().clamp(1, 100000)}, child: $child)';
  }
  return child;
}
