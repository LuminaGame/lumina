// design-token-exempt: node-graph painter colours (grid, node bodies, pin types, the debugger's executed-node amber) follow node-graph conventions, not the editor chrome palette.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/node_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';

part 'graph_canvas/state.dart';
part 'graph_canvas/view_controls.dart';
part 'graph_canvas/interactions.dart';
part 'graph_canvas/node_widgets.dart';
part 'graph_canvas/painters.dart';

/// What a My Blueprint variable row carries when dragged onto a graph.
/// A My Blueprint component dragged onto the graph: drops a `Get <name>`.
class BlueprintComponentDrag {
  final String name;
  const BlueprintComponentDrag(this.name);
}

/// A widget variable's element dragged onto the graph: drops `Get <variable>`
/// → `Get <element>`, wired.
class BlueprintElementDrag {
  final String variable;
  final String element;
  const BlueprintElementDrag(this.variable, this.element);
}

class BlueprintVariableDrag {
  final String name;
  const BlueprintVariableDrag(this.name);
}

/// A My Blueprint event dispatcher dragged onto the graph: offers Call /
/// Bind / Unbind / Unbind All / Assign.
class BlueprintDispatcherDrag {
  final String name;
  const BlueprintDispatcherDrag(this.name);
}

/// A function's local variable dragged onto its graph: Get or Set.
class BlueprintLocalVariableDrag {
  final String name;
  const BlueprintLocalVariableDrag(this.name);
}

/// A placed actor of the level dragged onto a Level Blueprint's graph
/// (the Level Actors list, the outliner's actors):
/// drops a reference to it, `Get <Actor>`.
class BlueprintLevelActorDrag {
  final String name;
  const BlueprintLevelActorDrag(this.name);
}

/// A widget's `Is Variable` element dragged onto its graph (My Blueprint's
/// Widgets): drops `Get <Element>`.
class BlueprintWidgetVariableDrag {
  final String name;
  const BlueprintWidgetVariableDrag(this.name);
}

/// A My Blueprint function or macro dragged onto a graph: drops its call.
class BlueprintGraphCallDrag {
  final String name;
  final bool isMacro;
  const BlueprintGraphCallDrag(this.name, {this.isMacro = false});
}

/// Graph actions a [BlueprintGraphCanvas] hands to its host editor:
/// collapsing the selection, expanding a call node,
/// opening a Timeline's curve tab, opening a called function's / macro's
/// graph. Null callbacks hide the actions.
class BlueprintGraphCanvasActions {
  final void Function({required bool toMacro, required bool named})? onCollapse;
  final void Function(String nodeId)? onExpand;
  final void Function(String nodeId)? onOpenTimeline;
  final void Function(String name, {required bool isMacro})? onOpenGraph;

  const BlueprintGraphCanvasActions({this.onCollapse, this.onExpand, this.onOpenTimeline, this.onOpenGraph});
}

/// Where a node's parts sit, in canvas units. One deterministic layout is
/// shared by the node widgets, the wire painter and pin hit-testing, so a
/// wire always starts exactly on its pin.
class BlueprintNodeLayout {
  static const double headerHeight = 26;
  static const double bannerHeight = 18;
  static const double settingsHeight = 30;
  static const double padTop = 6;
  static const double padBottom = 8;
  static const double rowHeight = 26;
  static const double anchorInset = 9;

  final LuminaBlueprintNode node;
  final BlueprintResolvedPins pins;
  final List<BlueprintNodeProblem> problems;
  final bool hasSettings;
  final Set<String> connectedInputs;
  final double width;

  /// Height of the editor's [BlueprintGraphEditor.nodeBody] widget.
  final double bodyHeight;

  BlueprintNodeLayout._(this.node, this.pins, this.problems, this.hasSettings, this.connectedInputs, this.width, this.bodyHeight);

  static const double rerouteSize = 16;
  static const double commentTitleHeight = 24;

  bool get isComment => BlueprintEditorNodes.isComment(node);
  bool get isReroute => BlueprintEditorNodes.isReroute(node);

  factory BlueprintNodeLayout.of(BlueprintGraphEditor editor, LuminaBlueprintNode node) {
    if (BlueprintEditorNodes.isComment(node)) {
      return BlueprintNodeLayout._(node, (inputs: const [], outputs: const []), const [], false, const {},
          BlueprintEditorNodes.commentWidth(node), 0);
    }
    if (BlueprintEditorNodes.isReroute(node)) {
      return BlueprintNodeLayout._(node, editor.pinsOf(node), const [], false, {
        for (final w in editor.wires)
          if (w.toNodeId == node.id) w.toPinId,
      }, rerouteSize, 0);
    }
    final pins = editor.pinsOf(node);
    final problems = editor.problems(node);
    final hasSettings = node.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction;
    final connected = {
      for (final w in editor.wires)
        if (w.toNodeId == node.id) w.toPinId,
    };
    double text(String s, double c) => s.length * c;
    var inputs = 0.0;
    for (final p in pins.inputs) {
      final opts = editor.pinOptions(node, p);
      final editorWidth = !connected.contains(p.id) && BlueprintPinLiteralEditor.supports(p.type) && editor.showsInlineLiteral(node, p)
          ? 6 + BlueprintPinLiteralEditor.inlineWidth(p.type, opts)
          : 0.0;
      inputs = math.max(inputs, 20 + text(showsLabel(p) ? p.name : '', 5.4) + editorWidth);
    }
    var outputs = 0.0;
    for (final p in pins.outputs) {
      outputs = math.max(outputs, 20 + text(showsLabel(p) ? p.name : '', 5.4));
    }
    final title = text(node.title, 6.6) + 44;
    var width = math.max(math.max(inputs + outputs + 24, title), hasSettings ? 210.0 : 160.0);
    width = width.clamp(160.0, 520.0).toDouble();
    return BlueprintNodeLayout._(node, pins, problems, hasSettings, connected, width, editor.nodeBodyHeight(node));
  }

  /// Plain exec pins are unlabelled.
  static bool showsLabel(LuminaBlueprintPinSpec p) =>
      !(p.type == LuminaPinType.exec && (p.name == 'Exec In' || p.name == 'Exec Out'));

  bool get hasBanner => problems.isNotEmpty;
  int get rows => math.max(pins.inputs.length, pins.outputs.length);
  double get bodyTop => headerHeight + (hasBanner ? bannerHeight : 0) + (hasSettings ? settingsHeight : 0) + bodyHeight + padTop;
  double get height => isComment
      ? BlueprintEditorNodes.commentHeight(node)
      : isReroute
          ? rerouteSize
          : bodyTop + rows * rowHeight + padBottom;
  Rect get rect => Rect.fromLTWH(node.x, node.y, width, height);

  /// The comment's draggable title bar, in canvas units.
  Rect get commentTitleRect => Rect.fromLTWH(node.x, node.y, width, commentTitleHeight);

  Offset? pinCenter(String pinId, {required bool output}) {
    if (isReroute) return Offset(node.x + rerouteSize / 2, node.y + rerouteSize / 2);
    final list = output ? pins.outputs : pins.inputs;
    final index = list.indexWhere((p) => p.id == pinId);
    if (index < 0) return null;
    return Offset(
      node.x + (output ? width - anchorInset : anchorInset),
      node.y + bodyTop + index * rowHeight + rowHeight / 2,
    );
  }
}

/// The Blueprint graph canvas: nodes from lumina's
/// library, colour-coded typed pins, Bezier wires, pan / zoom /
/// marquee, drag-to-wire with a context-sensitive palette on empty space,
/// inline literals, My Blueprint variable drops (Ctrl: Get, Alt: Set), node
/// banners for missing actions and deprecated nodes, and Compiler Results
/// navigation. The Blueprint editor's event graph and the Animation Blueprint
/// editor's event and rule graphs all use this one widget.
class BlueprintGraphCanvas extends StatefulWidget {
  final BlueprintGraphEditor editor;

  /// Shown faintly in the corner (`EventGraph`, `Rule: Idle → Walk`).
  final String? graphLabel;

  /// Collapse / expand / open-tab actions the host editor provides.
  final BlueprintGraphCanvasActions actions;

  const BlueprintGraphCanvas({super.key, required this.editor, this.graphLabel, this.actions = const BlueprintGraphCanvasActions()});

  @override
  State<BlueprintGraphCanvas> createState() => BlueprintGraphCanvasState();
}

class BlueprintGraphCanvasState extends _BlueprintGraphCanvasStateBase
    with
        _BlueprintGraphCanvasViewControls,
        _BlueprintGraphCanvasInteractions,
        _BlueprintGraphCanvasNodeWidgets {

  @override
  BlueprintGraphEditor get editor => widget.editor;
  Offset get panOffset => _pan;
  double get zoom => _zoom;

  @override
  void initState() {
    super.initState();
    editor.focusRequest.addListener(_onFocusRequest);
  }

  @override
  void didUpdateWidget(covariant BlueprintGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.editor, widget.editor)) {
      oldWidget.editor.focusRequest.removeListener(_onFocusRequest);
      widget.editor.focusRequest.addListener(_onFocusRequest);
    }
  }

  @override
  void dispose() {
    editor.focusRequest.removeListener(_onFocusRequest);
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([editor, editor.host, ?editor.debug]),
      builder: (context, _) {
        // Comments are laid out first so nodes draw above them.
        final layouts = [
          for (final n in editor.nodes) if (BlueprintEditorNodes.isComment(n)) BlueprintNodeLayout.of(editor, n),
          for (final n in editor.nodes) if (!BlueprintEditorNodes.isComment(n)) BlueprintNodeLayout.of(editor, n),
        ];
        final byId = {for (final l in layouts) l.node.id: l};
        final errorNodes = editor.errorNodeIds;
        final selected = editor.selectedNodeIds;
        final debug = editor.debug;
        Offset? dragStart;
        if (_dragFrom != null) {
          dragStart = byId[_dragFrom!.nodeId]?.pinCenter(_dragFrom!.pinId, output: _dragFrom!.isOutput);
        }

        return LayoutBuilder(builder: (context, constraints) {
          _size = constraints.biggest;
          return DragTarget<Object>(
            // pointerDragAnchorStrategy: the feedback's origin is the pointer.
            onWillAcceptWithDetails: (d) =>
                d.data is BlueprintVariableDrag ||
                d.data is BlueprintComponentDrag ||
                d.data is BlueprintElementDrag ||
                d.data is BlueprintDispatcherDrag ||
                d.data is BlueprintLocalVariableDrag ||
                d.data is BlueprintGraphCallDrag ||
                (d.data is BlueprintLevelActorDrag && editor.context.levelActor((d.data as BlueprintLevelActorDrag).name) != null) ||
                (d.data is BlueprintWidgetVariableDrag && editor.context.widgetVariable((d.data as BlueprintWidgetVariableDrag).name) != null),
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data is BlueprintVariableDrag) _dropVariable(data.name, details.offset);
              if (data is BlueprintDispatcherDrag) _dropDispatcher(data.name, details.offset);
              if (data is BlueprintLocalVariableDrag) _dropLocalVariable(data.name, details.offset);
              if (data is BlueprintGraphCallDrag) _dropGraphCall(data, details.offset);
              if (data is BlueprintComponentDrag) {
                editor.placeComponent(data.name, position: _toCanvas(_localFromGlobal(details.offset)));
              }
              if (data is BlueprintLevelActorDrag) {
                final placed = editor.placeLevelActor(data.name, position: _toCanvas(_localFromGlobal(details.offset)));
                if (placed != null) editor.select(placed.id);
              }
              if (data is BlueprintWidgetVariableDrag) {
                final placed = editor.addNode(LuminaBlueprintNodeLibrary.getWidgetVariable, _toCanvas(_localFromGlobal(details.offset)),
                    literals: {'element': data.name});
                if (placed != null) editor.select(placed.id);
              }
              if (data is BlueprintElementDrag) {
                editor.placeElementGet(data.variable, data.element, position: _toCanvas(_localFromGlobal(details.offset)));
              }
            },
            builder: (context, candidate, rejected) => Focus(
              focusNode: _focus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace)) {
                  if (editor.removeSelected()) return KeyEventResult.handled;
                }
                // C: a comment around the selection.
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyC && !HardwareKeyboard.instance.isControlPressed) {
                  if (addCommentAroundSelection() != null) return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Listener(
                onPointerDown: (e) {
                  _buttons = e.buttons;
                  _rightDragged = false;
                },
                onPointerMove: (e) {
                  if (e.buttons & (kSecondaryMouseButton | kMiddleMouseButton) != 0) {
                    if (e.delta.distance > 0) _rightDragged = true;
                    setState(() => _pan += e.delta);
                  }
                },
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    final local = _localFromGlobal(signal.position);
                    final canvasPos = _toCanvas(local);
                    setState(() {
                      _zoom = (_zoom + (signal.scrollDelta.dy < 0 ? 0.1 : -0.1)).clamp(0.25, 2.0).toDouble();
                      _pan = local - canvasPos * _zoom;
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    _focus.requestFocus();
                    // Double-clicking a wire splits it with a reroute dot.
                    final canvasPos = _toCanvas(d.localPosition);
                    final w = wireAt(canvasPos, byId);
                    if (w != null && _isDoubleTap('wire:${w.id}')) {
                      final dot = editor.insertReroute(w.id, canvasPos);
                      if (dot != null) editor.select(dot.id);
                      return;
                    }
                    editor.clearSelection();
                  },
                  onSecondaryTapUp: (d) {
                    if (!_rightDragged) openNodePalette(d.localPosition);
                  },
                  onPanStart: (d) {
                    if (_buttons == kPrimaryMouseButton || _buttons == 0) {
                      setState(() {
                        _marqueeStart = _toCanvas(d.localPosition);
                        _marqueeEnd = _marqueeStart;
                      });
                    }
                  },
                  onPanUpdate: (d) {
                    if (_marqueeStart == null) return;
                    setState(() => _marqueeEnd = _toCanvas(d.localPosition));
                    final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
                    editor.selectMany({
                      for (final l in layouts)
                        if (rect.overlaps(l.rect)) l.node.id,
                    });
                  },
                  onPanEnd: (_) => setState(() {
                    _marqueeStart = null;
                    _marqueeEnd = null;
                  }),
                  child: ClipRect(
                    child: Stack(
                      key: _stackKey,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GraphPainter(
                              editor: editor,
                              layouts: byId,
                              pan: _pan,
                              zoom: _zoom,
                              dragStart: dragStart,
                              dragEnd: _dragPointer,
                              dragType: _dragFrom?.type,
                              dragFromOutput: _dragFrom?.isOutput ?? true,
                              dragRefused: _dragRefusal != null,
                              marqueeStart: _marqueeStart,
                              marqueeEnd: _marqueeEnd,
                              dropHighlight: candidate.isNotEmpty,
                              debug: debug,
                            ),
                          ),
                        ),
                        for (final l in layouts)
                          l.isComment
                              ? _commentWidget(l, selected: selected.contains(l.node.id))
                              : l.isReroute
                                  ? _rerouteWidget(l, selected: selected.contains(l.node.id))
                                  : _nodeWidget(l,
                                      selected: selected.contains(l.node.id),
                                      failed: errorNodes.contains(l.node.id),
                                      executed: debug?.intensity(l.node.id) ?? 0),
                        if (_hoverPin != null && debug != null && debug.hasValue(_hoverPin!.nodeId, _hoverPin!.pinId))
                          Positioned(
                            key: const ValueKey('pin_value_tooltip'),
                            left: _hoverAt.dx + 12,
                            top: _hoverAt.dy - 26,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: EditorColors.card,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFFFB300)), // the debugger amber, as the executed-node glow
                                ),
                                child: Text(
                                  '${_hoverPin!.pinId}: ${_formatValue(debug.lastValue(_hoverPin!.nodeId, _hoverPin!.pinId))}',
                                  style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily),
                                ),
                              ),
                            ),
                          ),
                        if (_dragRefusal != null && _dragPointer != null)
                          Positioned(
                            left: toScreen(_dragPointer!).dx + 14,
                            top: toScreen(_dragPointer!).dy + 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: EditorColors.card,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: EditorColors.destructive),
                              ),
                              child: Text(_dragRefusal!,
                                  style: const TextStyle(fontSize: 9, color: EditorColors.destructive)),
                            ),
                          ),
                        if (widget.graphLabel != null)
                          Positioned(
                            right: 14,
                            top: 10,
                            child: IgnorePointer(
                              child: Text(
                                widget.graphLabel!.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900, color: Color(0x22FFFFFF), letterSpacing: 1.5), // the faint graph watermark painted under the grid
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                // a drop shadow/scrim: black at 60%, not a surface
                                color: const Color(0x99000000),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: EditorColors.border),
                              ),
                              child: Text('Zoom ${(_zoom * 100).round()}%',
                                  style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  static String _formatValue(Object? v) {
    if (v is double) return v.toStringAsFixed(3);
    if (v is LuminaRotator) return 'P ${v.pitch.toStringAsFixed(1)} R ${v.roll.toStringAsFixed(1)} Y ${v.yaw.toStringAsFixed(1)}';
    final s = '$v';
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
}
