part of '../umg_widget_codegen.dart';

/// Emission: event handler signatures and each widget node's Dart body.

// ---------------------------------------------------------------------------
// Emission
// ---------------------------------------------------------------------------

String _handlerSignature(UmgNode n, UmgEvent e) {
  // On Text Committed hands over the committed text.
  if (e.name == 'OnTextCommitted') return 'String value';
  if (e.name != 'OnValueChanged') return '';
  switch (n.type) {
    case UmgWidgetType.slider:
    case UmgWidgetType.shadcnSlider:
      return 'double value';
    case UmgWidgetType.checkBox:
    case UmgWidgetType.shadcnSwitch:
    case UmgWidgetType.shadcnToggle:
    case UmgWidgetType.shadcnCheckbox:
      return 'bool value';
    case UmgWidgetType.editableText:
    case UmgWidgetType.shadcnTextField:
    case UmgWidgetType.shadcnTextArea:
      return 'String value';
    case UmgWidgetType.comboBox:
    case UmgWidgetType.shadcnSelect:
    case UmgWidgetType.shadcnRadioGroup:
      return 'String? value';
    case UmgWidgetType.shadcnTabs:
      return 'int value';
    default:
      return '';
  }
}

String? _handlerFor(UmgNode n, String eventName) {
  for (final e in n.events) {
    if (e.name == eventName) return '_${e.handler}';
  }
  return null;
}

/// Wraps the emitted [body] of a designer element in a `LuminaUmgElement`
/// bound to the instance: the body reads its state from `e` and is
/// rebuilt only when that element's state changes. The root is the widget
/// itself and stays unwrapped.
String _element(UmgNode node, UmgDocument doc, String indent, String inst, String body) {
  if (identical(node, doc.root)) return body;
  final inner = '$indent  ';
  return 'LuminaUmgElement(\n${inner}instance: $inst,\n${inner}name: ${_str(node.name)},\n${inner}builder: (context, e) => $body,\n$indent)';
}

String _emit(UmgNode node, UmgDocument doc, String indent, bool stateful, bool plain, String inst) {
  // The body sits one level deeper inside the LuminaUmgElement wrapper.
  final bodyIndent = identical(node, doc.root) ? indent : '$indent  ';
  return _element(node, doc, indent, inst, _emitBody(node, doc, bodyIndent, stateful, plain, inst));
}

String _emitBody(UmgNode node, UmgDocument doc, String indent, bool stateful, bool plain, String inst) {
  final key = "key: const ValueKey('${node.fieldName}')";
  final inner = '$indent  ';
  if (node.type == UmgWidgetType.container) return _emitContainer(node, doc, indent, stateful, plain, inst);
  if (node.type.isShadcn) {
    // A plain-Flutter game never imports shadcn_flutter; the
    // validator refuses to compile this, and a stale file shows nothing.
    if (plain) return 'const SizedBox.shrink() /* ${node.type.displayName}: not available with plain Flutter widgets */';
    return _emitShadcn(node, doc, indent, stateful, inst);
  }
  switch (node.type) {
    case UmgWidgetType.canvasPanel:
      final children = List<UmgNode>.from(node.children)..sort((a, b) => a.slot.zOrder.compareTo(b.slot.zOrder));
      final b = StringBuffer();
      b.writeln('LayoutBuilder(');
      b.writeln('$inner$key,');
      b.writeln('${inner}builder: (context, constraints) {');
      b.writeln('$inner  final w = constraints.hasBoundedWidth ? constraints.maxWidth : ${_f(doc.logicalSize.width)};');
      b.writeln('$inner  final h = constraints.hasBoundedHeight ? constraints.maxHeight : ${_f(doc.logicalSize.height)};');
      b.writeln('$inner  return Stack(');
      b.writeln('$inner    clipBehavior: Clip.none,');
      b.writeln('$inner    children: [');
      for (final c in children) {
        final s = c.slot;
        b.writeln('$inner      // ${c.name} (${c.type.displayName})');
        b.writeln('$inner      _umgCanvasSlot(');
        b.writeln('$inner        _umgCanvasRect(w, h, ${_f(s.anchorMin.dx)}, ${_f(s.anchorMin.dy)}, ${_f(s.anchorMax.dx)}, ${_f(s.anchorMax.dy)}, ${_f(s.position.dx)}, ${_f(s.position.dy)}, ${_f(s.size.width)}, ${_f(s.size.height)}, ${_f(s.alignment.dx)}, ${_f(s.alignment.dy)}),');
        b.writeln('$inner        ${s.sizeToContent},');
        b.writeln('$inner        ${_emit(c, doc, '$inner        ', stateful, plain, inst)},');
        b.writeln('$inner      ),');
      }
      b.writeln('$inner    ],');
      b.writeln('$inner  );');
      b.writeln('$inner},');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.overlay:
      final b = StringBuffer();
      b.writeln('Stack(');
      b.writeln('$inner$key,');
      b.writeln('${inner}children: [');
      for (final c in node.children) {
        b.writeln('$inner  ${_overlayChild(c, doc, '$inner  ', stateful, plain, inst)},');
      }
      b.writeln('$inner],');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.widgetSwitcher:
      final b = StringBuffer();
      final count = node.children.length;
      b.writeln('IndexedStack(');
      b.writeln('$inner$key,');
      b.writeln('${inner}index: ${_int_(node, 'activeIndex', _int(node.props['activeIndex'], 0))}.clamp(0, ${count == 0 ? 0 : count - 1}),');
      b.writeln('${inner}children: [');
      for (final c in node.children) {
        b.writeln('$inner  ${_overlayChild(c, doc, '$inner  ', stateful, plain, inst)},');
      }
      b.writeln('$inner],');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.horizontalBox:
    case UmgWidgetType.verticalBox:
      final isRow = node.type == UmgWidgetType.horizontalBox;
      final b = StringBuffer();
      b.writeln('${isRow ? 'Row' : 'Column'}(');
      b.writeln('$inner$key,');
      b.writeln('${inner}mainAxisSize: MainAxisSize.max,');
      b.writeln('${inner}crossAxisAlignment: CrossAxisAlignment.stretch,');
      b.writeln('${inner}children: [');
      for (final c in node.children) {
        b.writeln('$inner  ${_boxChild(c, doc, '$inner  ', stateful, plain, isRow, inst)},');
      }
      b.writeln('$inner],');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.gridPanel:
      final columns = _int(node.props['columns'], 2).clamp(1, 32);
      final b = StringBuffer();
      b.writeln('widgets.Table(');
      b.writeln('$inner$key,');
      b.writeln('${inner}children: [');
      for (var i = 0; i < node.children.length; i += columns) {
        b.writeln('$inner  widgets.TableRow(children: [');
        for (var j = 0; j < columns; j++) {
          final idx = i + j;
          if (idx < node.children.length) {
            final c = node.children[idx];
            b.writeln('$inner    ${_padded(c, _emit(c, doc, '$inner    ', stateful, plain, inst))},');
          } else {
            b.writeln('$inner    const SizedBox.shrink(),');
          }
        }
        b.writeln('$inner  ]),');
      }
      b.writeln('$inner],');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.scrollBox:
      final horizontal = node.props['orientation'] == 'horizontal';
      final b = StringBuffer();
      b.writeln('SingleChildScrollView(');
      b.writeln('$inner$key,');
      b.writeln('${inner}scrollDirection: ${horizontal ? 'Axis.horizontal' : 'Axis.vertical'},');
      b.writeln('${inner}child: ${horizontal ? 'Row' : 'Column'}(');
      b.writeln('$inner  mainAxisSize: MainAxisSize.min,');
      b.writeln('$inner  children: [');
      for (final c in node.children) {
        b.writeln('$inner    ${_padded(c, _emit(c, doc, '$inner    ', stateful, plain, inst))},');
      }
      b.writeln('$inner  ],');
      b.writeln('$inner),');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.sizeBox:
      final child = node.children.isEmpty ? 'null' : _padded(node.children.first, _emit(node.children.first, doc, inner, stateful, plain, inst));
      return 'SizedBox(\n$inner$key,\n${inner}width: ${_double_(node, 'width', 200)},\n${inner}height: ${_double_(node, 'height', 100)},\n${inner}child: $child,\n$indent)';

    case UmgWidgetType.border:
      final child = node.children.isEmpty ? 'const SizedBox.shrink()' : _padded(node.children.first, _emit(node.children.first, doc, inner, stateful, plain, inst));
      if (plain) {
        return 'LuminaUmgBorder(\n$inner$key,\n${inner}color: ${_color_(node, 'color', '#1B1B22')},\n${inner}padding: EdgeInsets.all(${_double_(node, 'padding', 8)}),\n${inner}child: $child,\n$indent)';
      }
      return 'Card(\n$inner$key,\n${inner}filled: true,\n${inner}fillColor: ${_color_(node, 'color', '#1B1B22')},\n${inner}padding: EdgeInsets.all(${_double_(node, 'padding', 8)}),\n${inner}child: $child,\n$indent)';

    case UmgWidgetType.button:
      final clicked = _handlerFor(node, 'OnClicked');
      final hovered = _handlerFor(node, 'OnHovered');
      final unhovered = _handlerFor(node, 'OnUnhovered');
      final b = StringBuffer();
      b.writeln(plain ? 'LuminaUmgButton(' : 'Button(');
      b.writeln('$inner$key,');
      b.writeln(plain
          ? '${inner}style: LuminaUmgButtonStyle.${_buttonStyle(node.props['style'])},'
          : '${inner}style: const ButtonStyle.${_buttonStyle(node.props['style'])}(),');
      // Set Is Enabled false disables the button itself, not only its input.
      b.writeln('${inner}onPressed: LuminaUmgElementBinding.isEnabled(e) ? ${clicked ?? '() {}'} : null,');
      if (hovered != null || unhovered != null) {
        b.writeln(plain ? '${inner}onHovered: (hovering) {' : '${inner}onHover: (hovering) {');
        if (hovered != null) b.writeln('$inner  if (hovering) $hovered();');
        if (unhovered != null) b.writeln('$inner  if (!hovering) $unhovered();');
        b.writeln('$inner},');
      }
      b.writeln('${inner}child: ${_text(node, _string_(node, 'label', 'Button'))},');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.text:
      return 'LuminaUmgText(\n$inner$key,\n$inner${_string_(node, 'text', '')},\n${inner}style: ${_textStyle(node)},\n${inner}outline: ${_outline_(node)},\n$indent)';

    case UmgWidgetType.image:
      final fit = _drawAsFit(node.props['drawAs']);
      final b = StringBuffer();
      b.writeln('FutureBuilder<Uint8List?>(');
      b.writeln('$inner$key,');
      b.writeln('${inner}future: _umgLoadTexture(${_string_(node, 'texture', '')}),');
      b.writeln('${inner}builder: (context, snapshot) => snapshot.data == null');
      b.writeln('$inner    ? const SizedBox.shrink()');
      b.writeln('$inner    : Image.memory(snapshot.data!, fit: $fit, color: ${_color_(node, 'color', '#FFFFFF')}, colorBlendMode: BlendMode.modulate, gaplessPlayback: true),');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.progressBar:
      // Set Fill Color writes `fillColor`; the binding falls back to the designer's `color`.
      if (plain) {
        return 'LuminaUmgProgressBar(\n$inner$key,\n${inner}progress: ${_double_(node, 'percent', 0.5)},\n${inner}color: ${_color_(node, 'fillColor', node.props['color']?.toString() ?? '#4ADE80')},\n$indent)';
      }
      return 'Progress(\n$inner$key,\n${inner}progress: ${_double_(node, 'percent', 0.5)},\n${inner}color: ${_color_(node, 'fillColor', node.props['color']?.toString() ?? '#4ADE80')},\n$indent)';

    case UmgWidgetType.slider:
      final handler = _handlerFor(node, 'OnValueChanged');
      final b = StringBuffer();
      final v = plain ? 'v' : 'v.value';
      final value = "LuminaUmgElementBinding.value<double>(e, 'value', ${node.fieldName}Value)";
      b.writeln(plain ? 'LuminaUmgSlider(' : 'Slider(');
      b.writeln('$inner$key,');
      b.writeln(plain ? '${inner}value: $value,' : '${inner}value: SliderValue.single($value),');
      b.writeln('${inner}onChanged: (v) {');
      b.writeln('$inner  setState(() => ${node.fieldName}Value = $v);');
      b.writeln("$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'value', $v);");
      if (handler != null) b.writeln('$inner  $handler($v);');
      b.writeln('$inner},');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.checkBox:
      final handler = _handlerFor(node, 'OnValueChanged');
      final b = StringBuffer();
      final checked = plain ? 's' : 's == CheckboxState.checked';
      final value = "LuminaUmgElementBinding.value<bool>(e, 'isChecked', ${node.fieldName}Value)";
      b.writeln(plain ? 'LuminaUmgCheckbox(' : 'Checkbox(');
      b.writeln('$inner$key,');
      b.writeln(plain
          ? '${inner}value: $value,'
          : '${inner}state: $value ? CheckboxState.checked : CheckboxState.unchecked,');
      b.writeln('${inner}onChanged: (s) {');
      b.writeln('$inner  setState(() => ${node.fieldName}Value = $checked);');
      b.writeln("$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'isChecked', $checked);");
      if (handler != null) b.writeln('$inner  $handler($checked);');
      b.writeln('$inner},');
      b.writeln('$inner${plain ? 'label' : 'trailing'}: ${_text(node, _string_(node, 'label', ''))},');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.editableText:
      final handler = _handlerFor(node, 'OnValueChanged');
      final committed = _handlerFor(node, 'OnTextCommitted');
      final b = StringBuffer();
      b.writeln(plain ? 'LuminaUmgTextField(' : 'TextField(');
      b.writeln('$inner$key,');
      b.writeln('${inner}initialValue: ${node.fieldName}Value,');
      b.writeln(plain
          ? '${inner}placeholder: ${_string_(node, 'hintText', node.props['hint']?.toString() ?? '')},'
          : '${inner}placeholder: Text(${_string_(node, 'hintText', node.props['hint']?.toString() ?? '')}),');
      b.writeln('${inner}style: ${_textStyle(node, outlineRing: true)},');
      if (committed != null) b.writeln('${inner}onSubmitted: $committed,');
      b.writeln('${inner}onChanged: (v) {');
      b.writeln('$inner  ${node.fieldName}Value = v;');
      b.writeln("$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'text', v);");
      if (handler != null) b.writeln('$inner  $handler(v);');
      b.writeln('$inner},');
      b.write('$indent)');
      return b.toString();

    case UmgWidgetType.comboBox:
      final handler = _handlerFor(node, 'OnValueChanged');
      final options = _options(node.props['options']);
      final optionsExpr = 'LuminaUmgElementBinding.options(e, const [${options.map(_str).join(', ')}])';
      final value = "LuminaUmgElementBinding.value<String?>(e, 'selectedOption', ${node.fieldName}Value)";
      final b = StringBuffer();
      if (plain) {
        b.writeln('LuminaUmgComboBox(');
        b.writeln('$inner$key,');
        b.writeln('${inner}value: $value,');
        b.writeln('${inner}options: $optionsExpr,');
        b.writeln('${inner}style: ${_textStyle(node)},');
        b.writeln('${inner}outline: ${_outline_(node)},');
        b.writeln('${inner}onChanged: (v) {');
        b.writeln('$inner  setState(() => ${node.fieldName}Value = v);');
        b.writeln("$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'selectedOption', v);");
        if (handler != null) b.writeln('$inner  $handler(v);');
        b.writeln('$inner},');
        b.write('$indent)');
        return b.toString();
      }
      b.writeln('Select<String>(');
      b.writeln('$inner$key,');
      b.writeln('${inner}value: $value,');
      b.writeln('${inner}onChanged: (v) {');
      b.writeln('$inner  setState(() => ${node.fieldName}Value = v);');
      b.writeln("$inner  LuminaUmgElementBinding.write($inst, ${_str(node.name)}, 'selectedOption', v);");
      if (handler != null) b.writeln('$inner  $handler(v);');
      b.writeln('$inner},');
      b.writeln('${inner}itemBuilder: (context, item) => ${_text(node, 'item')},');
      b.writeln('${inner}popup: SelectPopup(');
      b.writeln('$inner  items: SelectItemList(');
      b.writeln('$inner    children: [');
      b.writeln('$inner      for (final o in $optionsExpr) SelectItemButton(value: o, child: Text(o)),');
      b.writeln('$inner    ],');
      b.writeln('$inner  ),');
      b.writeln('$inner),');
      b.write('$indent)');
      return b.toString();
    default:
      return 'const SizedBox.shrink()'; // Container and shadcn: emitted above
  }
}
