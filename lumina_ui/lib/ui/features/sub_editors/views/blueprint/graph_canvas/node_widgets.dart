// design-token-exempt: node-graph painter colours (grid, node bodies, pin types, the debugger's executed-node amber) follow node-graph conventions, not the editor chrome palette.
part of '../graph_canvas.dart';

/// Widgets for comments, reroutes and nodes, with their pins and the
/// input action picker.
mixin _BlueprintGraphCanvasNodeWidgets on _BlueprintGraphCanvasStateBase {

  /// The nodes a move of [ids] takes along: for each selected comment, the
  /// nodes inside its box (a comment's contents move with it).
  Set<String> _withCommentContents(Set<String> ids) {
    final out = {...ids};
    for (final id in ids) {
      final n = editor.node(id);
      if (n == null || !BlueprintEditorNodes.isComment(n)) continue;
      for (final inside in BlueprintEditorNodes.nodesInside(n, editor.nodes, sizeOf: (x) {
        final l = BlueprintNodeLayout.of(editor, x);
        return (width: l.width, height: l.height);
      })) {
        out.add(inside.id);
      }
    }
    return out;
  }

  /// A comment box: translucent fill, a draggable title bar (drag moves the
  /// box and the nodes inside it) and a resize grip; the body lets clicks
  /// through to the nodes and canvas beneath.
  Widget _commentWidget(BlueprintNodeLayout layout, {required bool selected}) {
    final node = layout.node;
    final screen = toScreen(Offset(node.x, node.y));
    final color = Color(BlueprintEditorNodes.commentColor(node));
    final title = node.literals['title']?.toString() ?? node.title;
    return Positioned(
      key: ValueKey('comment_${node.id}'),
      left: screen.dx,
      top: screen.dy,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: layout.width,
          height: layout.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: selected ? EditorColors.primary : color.withValues(alpha: 0.8), width: selected ? 2 : 1),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: BlueprintNodeLayout.commentTitleHeight,
                child: GestureDetector(
                  key: ValueKey('comment_title_${node.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _focus.requestFocus();
                    if (_isDoubleTap('comment:${node.id}')) {
                      _promptName('Comment', title, (t) => editor.setComment(node.id, title: t));
                      return;
                    }
                    editor.select(node.id, additive: HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed);
                  },
                  onSecondaryTapUp: (d) => _showNodeMenu(node, d.globalPosition),
                  onPanStart: (_) {
                    if (!editor.selectedNodeIds.contains(node.id)) editor.select(node.id);
                    editor.beginMove();
                  },
                  onPanUpdate: (d) => editor.moveNodes(_withCommentContents(editor.selectedNodeIds), d.delta),
                  onPanEnd: (_) => editor.endMove(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                    ),
                    child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  key: ValueKey('comment_resize_${node.id}'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => editor.host.beginInteraction('Resize comment'),
                  onPanUpdate: (d) {
                    final n = editor.node(node.id);
                    if (n == null) return;
                    n.literals['width'] = (BlueprintEditorNodes.commentWidth(n) + d.delta.dx).clamp(80.0, 4000.0);
                    n.literals['height'] = (BlueprintEditorNodes.commentHeight(n) + d.delta.dy).clamp(40.0, 4000.0);
                    editor.documentChanged();
                  },
                  onPanEnd: (_) => editor.host.endInteraction(layoutOnly: true),
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: Icon(LucideIcons.moveDiagonal2, size: 10, color: Color(0xB3FFFFFF)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A reroute dot: one anchor that is both its input and its output.
  Widget _rerouteWidget(BlueprintNodeLayout layout, {required bool selected}) {
    final node = layout.node;
    final screen = toScreen(Offset(node.x, node.y));
    final pin = layout.pins.outputs.single;
    final color = editor.pinColor(node, pin, output: true);
    final ref = BlueprintPinRef.of(node.id, pin, isOutput: true);
    return Positioned(
      key: ValueKey('node_${node.id}'),
      left: screen.dx,
      top: screen.dy,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          key: ValueKey('reroute_${node.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focus.requestFocus();
            editor.select(node.id, additive: HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed);
          },
          onSecondaryTapUp: (d) => _showNodeMenu(node, d.globalPosition),
          onPanStart: (d) {
            if (HardwareKeyboard.instance.isControlPressed) {
              _startWire(ref, d.globalPosition);
              return;
            }
            if (!editor.selectedNodeIds.contains(node.id)) editor.select(node.id);
            editor.beginMove();
          },
          onPanUpdate: (d) => _dragFrom != null ? _updateWire(d.globalPosition) : editor.moveNodes(editor.selectedNodeIds, d.delta),
          onPanEnd: (_) => _dragFrom != null ? _endWire() : editor.endMove(),
          child: SizedBox(
            width: BlueprintNodeLayout.rerouteSize,
            height: BlueprintNodeLayout.rerouteSize,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? EditorColors.primary : const Color(0xDD000000), width: selected ? 2 : 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nodeWidget(BlueprintNodeLayout layout, {required bool selected, required bool failed, double executed = 0}) {
    final node = layout.node;
    final screen = toScreen(Offset(node.x, node.y));
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    final header = Color(node.headerColor ?? spec?.headerColor ?? 0xFF455A64);
    final isEvent = spec?.kind == LuminaBlueprintNodeKind.event;
    final isPure = spec?.kind == LuminaBlueprintNodeKind.pure;
    final problem = layout.problems.isEmpty ? null : layout.problems.first;

    return Positioned(
      key: ValueKey('node_${node.id}'),
      left: screen.dx,
      top: screen.dy,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: () {
            _focus.requestFocus();
            if (_isDoubleTap('node:${node.id}')) {
              // Double-click opens a Timeline's curve tab or a call's graph.
              if (node.registryId == LuminaBlueprintNodeLibrary.timeline) widget.actions.onOpenTimeline?.call(node.id);
              if (node.registryId == LuminaBlueprintNodeLibrary.callMacro) {
                widget.actions.onOpenGraph?.call('${node.literals['macro'] ?? ''}', isMacro: true);
              }
              if (node.registryId == LuminaBlueprintNodeLibrary.callFunction || node.registryId == LuminaBlueprintNodeLibrary.callFunctionPure) {
                widget.actions.onOpenGraph?.call('${node.literals['function'] ?? ''}', isMacro: false);
              }
              return;
            }
            if (HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed) {
              editor.toggle(node.id);
            } else {
              editor.select(node.id);
            }
          },
          onSecondaryTapUp: (d) => _showNodeMenu(node, d.globalPosition),
          onPanStart: (_) {
            if (!editor.selectedNodeIds.contains(node.id)) editor.select(node.id);
            editor.beginMove();
          },
          onPanUpdate: (d) => editor.moveNodes(_withCommentContents(editor.selectedNodeIds), d.delta),
          onPanEnd: (_) => editor.endMove(),
          child: Container(
            width: layout.width,
            decoration: BoxDecoration(
              color: const Color(0xF0202226), // node body: near-opaque graph node fill
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                // a drop shadow/scrim: black at 45%, not a surface
                const BoxShadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 4)),
                // Blueprint debugger: the node just ran (fades over 0.5 s).
                if (executed > 0) BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.8 * executed), blurRadius: 16),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: failed
                    ? EditorColors.destructive
                    : executed > 0
                        ? Color.lerp(const Color(0xDD000000), const Color(0xFFFFB300), executed)! // exec wire, lerped to the debugger amber while it runs
                        : selected
                            ? EditorColors.primary
                            // a drop shadow/scrim: black at 87%, not a surface
                            : const Color(0xDD000000),
                width: selected || failed || executed > 0 ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: BlueprintNodeLayout.headerHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [header, header.withValues(alpha: isPure ? 0.55 : 0.8)]),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEvent
                            ? LucideIcons.diamond
                            : isPure
                                ? LucideIcons.sigma
                                : LucideIcons.squareFunction,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          node.title,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (problem != null)
                  Container(
                    key: ValueKey('node_banner_${node.id}'),
                    height: BlueprintNodeLayout.bannerHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    color: problem.isError ? const Color(0xFFB71C1C) : const Color(0xFF8D6E00), // compile error red / warning amber node banners
                    alignment: Alignment.centerLeft,
                    child: Text(
                      problem.message,
                      style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (layout.hasSettings)
                  SizedBox(
                    height: BlueprintNodeLayout.settingsHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: _actionSelect(node),
                    ),
                  ),
                if (layout.bodyHeight > 0)
                  SizedBox(height: layout.bodyHeight, child: editor.nodeBody(context, node)),
                const SizedBox(height: BlueprintNodeLayout.padTop),
                for (var i = 0; i < layout.rows; i++)
                  SizedBox(
                    height: BlueprintNodeLayout.rowHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: i < layout.pins.inputs.length
                              ? _inputPin(layout, layout.pins.inputs[i])
                              : const SizedBox.shrink(),
                        ),
                        if (i < layout.pins.outputs.length) _outputPin(layout, layout.pins.outputs[i]),
                      ],
                    ),
                  ),
                const SizedBox(height: BlueprintNodeLayout.padBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionSelect(LuminaBlueprintNode node) {
    final actions = editor.context.inputActions;
    final current = node.literals['action'] as String?;
    final known = actions.any((a) => a.name == current);
    return Select<String>(
      key: ValueKey('node_action_select_${node.id}'),
      value: known ? current : null,
      placeholder: Text(current == null || current.isEmpty ? 'Pick an input action' : current,
          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
      onChanged: (v) {
        if (v != null) editor.setNodeAction(node.id, v);
      },
      popup: SelectPopup(
        items: SelectItemList(
          children: [
            for (final a in actions)
              SelectItemButton(
                key: ValueKey('action_item_${a.name}'),
                value: a.name,
                child: Text('${a.name}  ·  ${_valueTypeLabel(a.valueType)}', style: const TextStyle(fontSize: 10)),
              ),
          ],
        ),
      ).call,
    );
  }

  Widget _anchor(BlueprintNodeLayout layout, LuminaBlueprintPinSpec pin, {required bool output}) {
    final node = layout.node;
    final color = editor.pinColor(node, pin, output: output);
    final connected = editor.isConnected(node.id, pin.id, output: output);
    final ref = BlueprintPinRef.of(node.id, pin, isOutput: output);
    final anchor = GestureDetector(
      key: ValueKey('pin_${node.id}_${pin.id}_${output ? 'out' : 'in'}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (HardwareKeyboard.instance.isAltPressed) editor.breakLinks(node.id, pin.id, output: output);
      },
      onPanStart: (d) => _startWire(ref, d.globalPosition),
      onPanUpdate: (d) => _updateWire(d.globalPosition),
      onPanEnd: (_) => _endWire(),
      child: SizedBox(
        width: 14,
        height: 14,
        child: Center(
          child: pin.type == LuminaPinType.exec
              // The exec arrow: an outline while unwired, filled once a
              // wire is attached, like the data pins' circles.
              ? CustomPaint(
                  key: ValueKey('pin_exec_${node.id}_${pin.id}_${output ? 'out' : 'in'}_${connected ? 'filled' : 'hollow'}'),
                  size: const Size(10, 11),
                  painter: BlueprintExecPinPainter(
                    filled: connected,
                    // the prototype's `white/60` idiom: translucent so it keeps its weight on any surface
                    color: connected ? Colors.white : const Color(0x99FFFFFF),
                  ),
                )
              : pin.type == LuminaPinType.array
                  // A grid icon for an array pin.
                  ? Icon(LucideIcons.grid3x3, key: ValueKey('pin_array_${node.id}_${pin.id}'), size: 10, color: color)
                  : Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: connected ? color : Colors.transparent,
                    border: Border.all(color: color, width: 1.6),
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
    if (pin.type == LuminaPinType.exec) return anchor;
    // The pin's type — with its class for object pins (`Widget (WBP_HUD)`,
    // `Text Block`, `Spring Arm`) — on hover.
    final typed = Tooltip(
      key: ValueKey('pin_tooltip_${node.id}_${pin.id}_${output ? 'out' : 'in'}'),
      tooltip: (context) => TooltipContainer(
        child: Text('${pin.name}: ${editor.pinTypeLabel(node, pin, output: output)}', style: const TextStyle(fontSize: 10)),
      ),
      child: anchor,
    );
    if (editor.debug == null) return typed;
    // During Play, hovering a data pin shows the value it last carried.
    return MouseRegion(
      onEnter: (e) => setState(() {
        _hoverPin = (nodeId: node.id, pinId: pin.id);
        _hoverAt = _localFromGlobal(e.position);
      }),
      onExit: (_) => setState(() => _hoverPin = null),
      child: typed,
    );
  }

  Widget _inputPin(BlueprintNodeLayout layout, LuminaBlueprintPinSpec pin) {
    final node = layout.node;
    final showEditor = !layout.connectedInputs.contains(pin.id) &&
        pin.type != LuminaPinType.exec &&
        BlueprintPinLiteralEditor.supports(pin.type) &&
        editor.showsInlineLiteral(node, pin);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          _anchor(layout, pin, output: false),
          const SizedBox(width: 4),
          if (BlueprintNodeLayout.showsLabel(pin))
            Flexible(
              child: Text(pin.name,
                  overflow: TextOverflow.ellipsis,
                  // the prototype's `white/70` idiom: translucent so it keeps its weight on any surface
                  style: const TextStyle(fontSize: 9, color: Color(0xB3FFFFFF))),
            ),
          if (showEditor) ...[
            const SizedBox(width: 4),
            BlueprintPinLiteralEditor(
              keyPrefix: 'literal_${node.id}_${pin.id}',
              type: pin.type,
              value: node.literals[pin.id] ?? pin.defaultValue,
              options: editor.pinOptions(node, pin),
              onCommit: (v) => editor.setLiteral(node.id, pin.id, v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outputPin(BlueprintNodeLayout layout, LuminaBlueprintPinSpec pin) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (BlueprintNodeLayout.showsLabel(pin))
            // the prototype's `white/70` idiom: translucent so it keeps its weight on any surface
            Text(pin.name, style: const TextStyle(fontSize: 9, color: Color(0xB3FFFFFF))),
          const SizedBox(width: 4),
          _anchor(layout, pin, output: true),
        ],
      ),
    );
  }
}

String _valueTypeLabel(InputValueType t) => switch (t) {
      InputValueType.digitalBool => 'Digital (bool)',
      InputValueType.axis1D => 'Axis1D (float)',
      InputValueType.axis2D => 'Axis2D (Vector2D)',
      InputValueType.axis3D => 'Axis3D (Vector)',
    };
