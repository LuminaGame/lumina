import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/widgets.dart' as widgets show Table, TableRow;
import 'package:lumina/lumina.dart'
    show LuminaUmgBorder, LuminaUmgButton, LuminaUmgButtonStyle, LuminaUmgCheckbox, LuminaUmgComboBox, LuminaUmgProgressBar, LuminaUmgSlider, LuminaUmgTextField, kUmgWidgetLibraryFlutter;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_components.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_text_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

/// Visual Designer Canvas: renders the document with the real
/// shadcn_flutter widgets (wrapped in [IgnorePointer]) under a design-time
/// overlay that does hit-testing, selection, drag-move, 8-handle resize,
/// snap-to-grid, alignment guides and the resolution/DPI frame.
class UmgDesignerCanvas extends StatefulWidget {
  final UmgEditorViewModel vm;

  const UmgDesignerCanvas({super.key, required this.vm});

  @override
  State<UmgDesignerCanvas> createState() => UmgDesignerCanvasState();
}

class UmgDesignerCanvasState extends State<UmgDesignerCanvas> {
  final GlobalKey _surfaceKey = GlobalKey();
  final Map<String, GlobalKey> _nodeKeys = {};
  Map<String, Rect> _rects = {};
  String? _hoverId;
  String? _dragId;
  Rect? _dragStartRect;
  Size? _dragParentSize;
  Offset _dragDelta = Offset.zero;
  int? _resizeHandle;
  List<_Guide> _guides = const [];

  /// How many times a design-time runtime widget received a real interaction
  /// (must stay 0: the overlay owns input).
  int runtimeInteractionCount = 0;

  UmgEditorViewModel get vm => widget.vm;

  /// Last measured rect of [id] in canvas (logical design) coordinates.
  Rect? rectFor(String id) => _rects[id];

  @override
  void initState() {
    super.initState();
    vm.addListener(_onVmChanged);
  }

  @override
  void didUpdateWidget(covariant UmgDesignerCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm != widget.vm) {
      oldWidget.vm.removeListener(_onVmChanged);
      widget.vm.addListener(_onVmChanged);
    }
  }

  @override
  void dispose() {
    vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  GlobalKey _keyFor(String id) => _nodeKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'umg_$id'));

  // ---------------------------------------------------------------------------
  // Measurement
  // ---------------------------------------------------------------------------

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final surface = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
      if (surface == null || !surface.hasSize) return;
      final next = <String, Rect>{};
      next[vm.document.root.id] = Offset.zero & surface.size;
      final live = vm.document.allNodes.map((n) => n.id).toSet();
      _nodeKeys.removeWhere((id, _) => !live.contains(id));
      for (final entry in _nodeKeys.entries) {
        if (entry.key == vm.document.root.id) continue;
        final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || !box.attached) continue;
        try {
          final topLeft = box.localToGlobal(Offset.zero, ancestor: surface);
          next[entry.key] = topLeft & box.size;
        } catch (_) {}
      }
      if (!_sameRects(next, _rects)) {
        setState(() => _rects = next);
      }
    });
  }

  static bool _sameRects(Map<String, Rect> a, Map<String, Rect> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null) return false;
      if ((o.left - e.value.left).abs() > 0.01 ||
          (o.top - e.value.top).abs() > 0.01 ||
          (o.width - e.value.width).abs() > 0.01 ||
          (o.height - e.value.height).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  UmgNode? _deepestAt(UmgNode node, Offset point) {
    final rect = _rects[node.id];
    if (rect == null || !rect.contains(point)) return null;
    final children = List<UmgNode>.from(node.children);
    if (node.type.isCanvas) {
      children.sort((a, b) => a.slot.zOrder.compareTo(b.slot.zOrder));
    }
    for (final child in children.reversed) {
      final hit = _deepestAt(child, point);
      if (hit != null) return hit;
    }
    return node;
  }

  UmgNode? _hit(Offset local) => _deepestAt(vm.document.root, local);

  Size _parentSizeOf(String id) {
    final parent = vm.document.parentOf(id);
    if (parent == null) return vm.logicalSize;
    return _rects[parent.id]?.size ?? vm.logicalSize;
  }

  Offset _parentOriginOf(String id) {
    final parent = vm.document.parentOf(id);
    if (parent == null) return Offset.zero;
    return _rects[parent.id]?.topLeft ?? Offset.zero;
  }

  // ---------------------------------------------------------------------------
  // Drop
  // ---------------------------------------------------------------------------

  void _handleDrop(UmgWidgetType type, Offset globalPointer) {
    final surface = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (surface == null) return;
    final local = surface.globalToLocal(globalPointer);
    final target = _hit(local) ?? vm.document.root;
    if (target.type.isCanvas) {
      final origin = _rects[target.id]?.topLeft ?? Offset.zero;
      vm.addWidget(type, parentId: target.id, canvasPosition: local - origin);
    } else {
      vm.addWidget(type, parentId: target.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails d) {
    final hit = _hit(d.localPosition);
    vm.select(hit?.id ?? vm.document.root.id);
  }

  void _onPanStart(DragStartDetails d) {
    final hit = _hit(d.localPosition);
    if (hit == null || hit.slot.kind != UmgSlotKind.canvas) {
      if (hit != null) vm.select(hit.id);
      _dragId = null;
      return;
    }
    vm.select(hit.id);
    _beginDrag(hit.id, handle: null);
  }

  void _beginDrag(String id, {required int? handle}) {
    _dragId = id;
    _resizeHandle = handle;
    _dragStartRect = _rects[id];
    _dragParentSize = _parentSizeOf(id);
    _dragDelta = Offset.zero;
    vm.beginInteraction(handle == null ? 'Move ${vm.document.findNode(id)?.name ?? ''}' : 'Resize ${vm.document.findNode(id)?.name ?? ''}');
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final id = _dragId;
    final start = _dragStartRect;
    if (id == null || start == null) return;
    _dragDelta += d.delta;
    _applyDrag(id, start);
  }

  void _applyDrag(String id, Rect start) {
    final origin = _parentOriginOf(id);
    Rect next;
    final h = _resizeHandle;
    if (h == null) {
      next = start.shift(_dragDelta);
    } else {
      var left = start.left;
      var top = start.top;
      var right = start.right;
      var bottom = start.bottom;
      // Handle indices: 0 TL, 1 T, 2 TR, 3 R, 4 BR, 5 B, 6 BL, 7 L.
      if (h == 0 || h == 6 || h == 7) left += _dragDelta.dx;
      if (h == 2 || h == 3 || h == 4) right += _dragDelta.dx;
      if (h == 0 || h == 1 || h == 2) top += _dragDelta.dy;
      if (h == 4 || h == 5 || h == 6) bottom += _dragDelta.dy;
      if (right - left < 8) {
        if (h == 0 || h == 6 || h == 7) {
          left = right - 8;
        } else {
          right = left + 8;
        }
      }
      if (bottom - top < 8) {
        if (h == 0 || h == 1 || h == 2) {
          top = bottom - 8;
        } else {
          bottom = top + 8;
        }
      }
      next = Rect.fromLTRB(left, top, right, bottom);
    }
    final parentLocal = next.shift(-origin);
    final parentSize = _dragParentSize ?? vm.logicalSize;
    vm.previewCanvasRect(id, parentLocal, parentSize);
    _guides = _computeGuides(id, next);
  }

  void _onPanEnd(DragEndDetails d) => _finishDrag();

  void _finishDrag() {
    if (_dragId != null) vm.endInteraction();
    _dragId = null;
    _resizeHandle = null;
    _dragStartRect = null;
    _guides = const [];
    if (mounted) setState(() {});
  }

  List<_Guide> _computeGuides(String id, Rect moving) {
    const threshold = 4.0;
    final parent = vm.document.parentOf(id);
    final parentRect = parent == null ? null : _rects[parent.id];
    final guides = <_Guide>[];
    if (parentRect == null) return guides;
    final xs = <double>[parentRect.center.dx];
    final ys = <double>[parentRect.center.dy];
    for (final sibling in parent!.children) {
      if (sibling.id == id) continue;
      final r = _rects[sibling.id];
      if (r == null) continue;
      xs.addAll([r.left, r.center.dx, r.right]);
      ys.addAll([r.top, r.center.dy, r.bottom]);
    }
    for (final mx in [moving.left, moving.center.dx, moving.right]) {
      for (final x in xs) {
        if ((mx - x).abs() <= threshold) guides.add(_Guide(vertical: true, at: x, from: parentRect.top, to: parentRect.bottom));
      }
    }
    for (final my in [moving.top, moving.center.dy, moving.bottom]) {
      for (final y in ys) {
        if ((my - y).abs() <= threshold) guides.add(_Guide(vertical: false, at: y, from: parentRect.left, to: parentRect.right));
      }
    }
    return guides;
  }

  void _onHover(PointerHoverEvent e) {
    if (_dragId != null) return;
    final hit = _hit(e.localPosition);
    final id = hit?.id;
    if (id != _hoverId) setState(() => _hoverId = id);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final res = vm.resolution;
    final logical = vm.logicalSize;
    return Column(
      children: [
        _simulatorBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availW = math.max(1.0, constraints.maxWidth - 32);
              final availH = math.max(1.0, constraints.maxHeight - 32);
              final scale = math.min(availW / res.width, availH / res.height);
              return Container(
                color: EditorColors.background,
                alignment: Alignment.center,
                child: DragTarget<UmgWidgetType>(
                  onAcceptWithDetails: (d) => _handleDrop(d.data, d.offset),
                  builder: (context, candidates, rejected) {
                    return Container(
                      width: res.width * scale,
                      height: res.height * scale,
                      decoration: BoxDecoration(
                        border: Border.all(color: candidates.isNotEmpty ? EditorColors.primary : EditorColors.primary.withValues(alpha: 0.5), width: 1.5),
                        // a drop shadow/scrim: black at 53%, not a surface
                        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 24)],
                      ),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: res.width.toDouble(),
                          height: res.height.toDouble(),
                          child: Transform.scale(
                            scale: vm.dpiScale,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              key: _surfaceKey,
                              width: logical.width,
                              height: logical.height,
                              child: _surface(scale),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _surface(double screenScale) {
    return ClipRect(
      child: Stack(
        key: const ValueKey('umg_canvas_surface'),
        clipBehavior: Clip.none,
        children: [
          // Background + grid.
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(gridSize: vm.gridSize, enabled: vm.snapToGrid, screenScale: screenScale * vm.dpiScale),
            ),
          ),
          // Runtime widgets: real shadcn_flutter, never receive design input.
          Positioned.fill(
            child: IgnorePointer(
              child: _UmgRuntimeTree(
                // Read once per canvas build; follows a Project Settings switch.
                plainWidgets: widget.vm.widgetLibrary == kUmgWidgetLibraryFlutter,
                vm: vm,
                keyFor: _keyFor,
                onInteraction: () => runtimeInteractionCount++,
              ),
            ),
          ),
          // Design overlay: hit-test, selection, move, guides.
          Positioned.fill(
            child: MouseRegion(
              onHover: _onHover,
              onExit: (_) {
                if (_hoverId != null) setState(() => _hoverId = null);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onTapUp,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _finishDrag,
                child: CustomPaint(
                  painter: _OverlayPainter(
                    rects: _rects,
                    document: vm.document,
                    selectedId: vm.selectedId,
                    hoverId: _hoverId,
                    guides: _guides,
                    screenScale: screenScale * vm.dpiScale,
                  ),
                ),
              ),
            ),
          ),
          ..._handles(screenScale * vm.dpiScale),
          if (vm.lastRejectionReason != null)
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 / screenScale, vertical: 4 / screenScale),
                  decoration: BoxDecoration(color: EditorColors.logWarning.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(3)),
                  // this is the *game* UI being designed, not the editor: the canvas simulates the shipped screen, so it does not follow the editor palette
                  child: Text(vm.lastRejectionReason!, style: TextStyle(fontSize: 10 / screenScale, color: const Color(0xFF111111))),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Eight resize handles for the selected canvas-slot element.
  List<Widget> _handles(double screenScale) {
    final id = vm.selectedId;
    if (id == null) return const [];
    final node = vm.document.findNode(id);
    final rect = _rects[id];
    if (node == null || rect == null || node.slot.kind != UmgSlotKind.canvas) return const [];
    final size = 8 / screenScale;
    final points = [
      rect.topLeft,
      rect.topCenter,
      rect.topRight,
      rect.centerRight,
      rect.bottomRight,
      rect.bottomCenter,
      rect.bottomLeft,
      rect.centerLeft,
    ];
    final cursors = [
      SystemMouseCursors.resizeUpLeft,
      SystemMouseCursors.resizeUp,
      SystemMouseCursors.resizeUpRight,
      SystemMouseCursors.resizeRight,
      SystemMouseCursors.resizeDownRight,
      SystemMouseCursors.resizeDown,
      SystemMouseCursors.resizeDownLeft,
      SystemMouseCursors.resizeLeft,
    ];
    return List.generate(8, (i) {
      final p = points[i];
      return Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        width: size,
        height: size,
        child: MouseRegion(
          cursor: cursors[i],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _beginDrag(id, handle: i),
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _finishDrag,
            child: Container(
              key: ValueKey('umg_handle_$i'),
              decoration: BoxDecoration(
                color: EditorColors.primary,
                // this is the *game* UI being designed, not the editor: the canvas simulates the shipped screen, so it does not follow the editor palette
                border: Border.all(color: const Color(0xFF111111), width: 1 / screenScale),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _simulatorBar() {
    final res = vm.resolution;
    final selectedPreset = UmgResolution.presets.where((p) => p == res).firstOrNull;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          const Icon(LucideIcons.monitor, size: 12, color: EditorColors.logWarning),
          const SizedBox(width: 6),
          const Text('Screen Simulator', style: TextStyle(fontSize: 9, color: EditorColors.logWarning)),
          const SizedBox(width: 8),
          SizedBox(
            width: 230,
            child: Select<String>(
              key: const ValueKey('umg_resolution_select'),
              value: selectedPreset?.key ?? 'custom',
              onChanged: (v) {
                if (v == null) return;
                if (v == 'custom') {
                  _promptCustomResolution();
                  return;
                }
                final preset = UmgResolution.presets.firstWhere((p) => p.key == v);
                vm.setResolution(preset);
              },
              itemBuilder: (context, item) {
                final preset = UmgResolution.presets.where((p) => p.key == item).firstOrNull;
                return Text(preset?.label ?? 'Custom ${res.width}x${res.height}', style: const TextStyle(fontSize: 9));
              },
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    for (final p in UmgResolution.presets) SelectItemButton(value: p.key, child: Text(p.label, style: const TextStyle(fontSize: 9))),
                    const SelectItemButton(value: 'custom', child: Text('Custom Aspect…', style: TextStyle(fontSize: 9))),
                  ],
                ),
              ).call,
            ),
          ),
          const SizedBox(width: 10),
          Text('${res.width} × ${res.height}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 12),
          const Text('DPI Scale', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: TextField(
              key: ValueKey('umg_dpi_${vm.dpiScale}'),
              initialValue: vm.dpiScale.toStringAsFixed(2),
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily),
              onSubmitted: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) vm.setDpiScale(parsed);
              },
            ),
          ),
          const Spacer(),
          const Text('Snap 8 px', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          Switch(
            key: const ValueKey('umg_snap_switch'),
            value: vm.snapToGrid,
            onChanged: (v) => setState(() => vm.snapToGrid = v),
          ),
        ],
      ),
    );
  }

  void _promptCustomResolution() {
    var w = vm.resolution.width;
    var h = vm.resolution.height;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Aspect'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              child: TextField(initialValue: '$w', onChanged: (v) => w = int.tryParse(v) ?? w, placeholder: const Text('Width')),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('×')),
            SizedBox(
              width: 90,
              child: TextField(initialValue: '$h', onChanged: (v) => h = int.tryParse(v) ?? h, placeholder: const Text('Height')),
            ),
          ],
        ),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          PrimaryButton(
            onPressed: () {
              vm.setCustomResolution(w, h);
              closeOverlay(dialogContext);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _Guide {
  final bool vertical;
  final double at;
  final double from;
  final double to;
  const _Guide({required this.vertical, required this.at, required this.from, required this.to});
}

class _GridPainter extends CustomPainter {
  final double gridSize;
  final bool enabled;
  final double screenScale;
  const _GridPainter({required this.gridSize, required this.enabled, required this.screenScale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.card);
    if (!enabled) return;
    final minor = Paint()
      // the prototype's `white/8` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1 / screenScale;
    final major = Paint()
      // the prototype's `white/16` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x28FFFFFF)
      ..strokeWidth = 1 / screenScale;
    final step = screenScale >= 0.9 ? gridSize : gridSize * 8;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x % (gridSize * 8) == 0) ? major : minor);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y % (gridSize * 8) == 0) ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.gridSize != gridSize || old.enabled != enabled || old.screenScale != screenScale;
}

class _OverlayPainter extends CustomPainter {
  final Map<String, Rect> rects;
  final UmgDocument document;
  final String? selectedId;
  final String? hoverId;
  final List<_Guide> guides;
  final double screenScale;

  const _OverlayPainter({
    required this.rects,
    required this.document,
    required this.selectedId,
    required this.hoverId,
    required this.guides,
    required this.screenScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / screenScale;
    // Faint outline of every panel so empty containers stay discoverable.
    final panelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px
      // the prototype's `white/13` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x22FFFFFF);
    document.root.visit((n, _) {
      final r = rects[n.id];
      if (r == null || n.id == document.root.id) return;
      if (n.type.isPanel) canvas.drawRect(r, panelPaint);
    });
    if (hoverId != null && hoverId != selectedId) {
      final r = rects[hoverId!];
      if (r != null) {
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px
            ..color = EditorColors.primary.withValues(alpha: 0.5),
        );
      }
    }
    if (selectedId != null) {
      final r = rects[selectedId!];
      final node = document.findNode(selectedId!);
      if (r != null && node != null) {
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * px
            ..color = EditorColors.primary,
        );
        final label = TextPainter(
          text: TextSpan(
            text: ' ${node.name} · ${node.type.displayName} ',
            // this is the *game* UI being designed, not the editor: the canvas simulates the shipped screen, so it does not follow the editor palette
            style: TextStyle(fontSize: 10 * px, color: const Color(0xFF111111), fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelRect = Rect.fromLTWH(r.left, r.top - label.height - 2 * px, label.width, label.height);
        canvas.drawRect(labelRect, Paint()..color = EditorColors.primary);
        label.paint(canvas, labelRect.topLeft);
      }
    }
    final guidePaint = Paint()
      ..strokeWidth = px
      ..color = EditorColors.accent;
    for (final g in guides) {
      if (g.vertical) {
        canvas.drawLine(Offset(g.at, g.from), Offset(g.at, g.to), guidePaint);
      } else {
        canvas.drawLine(Offset(g.from, g.at), Offset(g.to, g.at), guidePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}

/// Maps document nodes to real shadcn_flutter widgets (same registry as
/// [UmgWidgetCodegen], executed live).
class _UmgRuntimeTree extends StatelessWidget {
  final UmgEditorViewModel vm;
  final GlobalKey Function(String id) keyFor;
  final VoidCallback onInteraction;

  /// A plain-Flutter project previews the runtime's widgets.
  final bool plainWidgets;

  const _UmgRuntimeTree({required this.vm, required this.keyFor, required this.onInteraction, required this.plainWidgets});

  @override
  Widget build(BuildContext context) => Theme(
        data: vm.activeThemeData,
        child: _build(vm.document.root),
      );

  Widget _measured(UmgNode node, Widget child) {
    return KeyedSubtree(
      key: ValueKey('umg_rt_${node.id}'),
      child: SizedBox.expand(key: keyFor(node.id), child: child),
    );
  }

  Widget _measuredTight(UmgNode node, Widget child) {
    return KeyedSubtree(
      key: ValueKey('umg_rt_${node.id}'),
      child: Container(key: keyFor(node.id), child: child),
    );
  }

  Color _color(UmgNode n, String fallback) => UmgWidgetCodegen.parseHexColor(n.props['color']?.toString() ?? '') ?? UmgWidgetCodegen.parseHexColor(fallback)!;

  double _num(dynamic v, double fallback) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? fallback);

  EdgeInsets _padding(UmgSlot s) => EdgeInsets.fromLTRB(s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom);

  Alignment _alignment(UmgSlot s) => Alignment(_alignValue(s.hAlign), _alignValue(s.vAlign));

  double _alignValue(UmgAlign a) {
    switch (a) {
      case UmgAlign.start:
        return -1;
      case UmgAlign.center:
      case UmgAlign.fill:
        return 0;
      case UmgAlign.end:
        return 1;
    }
  }


  Widget _build(UmgNode node) {
    // The Container is Flutter's in both libraries; a shadcn
    // component needs the shadcn library, a plain project shows why not.
    if (node.type == UmgWidgetType.container) {
      final bytes = vm.textureBytesFor(node.id);
      final child = node.children.isEmpty ? null : node.children.first;
      return umgContainer(
        node,
        null,
        image: bytes == null ? null : MemoryImage(bytes),
        child: child == null ? null : Padding(padding: _padding(child.slot), child: _measuredTight(child, _build(child))),
      );
    }
    if (node.type.isShadcn) {
      if (plainWidgets) return umgRequiresShadcn(node);
      return umgShadcnComponent(
        node,
        null,
        children: [for (final c in node.children) Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)))],
        onChanged: (_) => onInteraction(),
        onPressed: onInteraction,
      );
    }
    if (plainWidgets) {
      final plain = _buildPlain(node);
      if (plain != null) return plain;
    }
    switch (node.type) {
      case UmgWidgetType.canvasPanel:
        return _buildCanvas(node);
      case UmgWidgetType.overlay:
        return Stack(children: node.children.map(_overlayChild).toList());
      case UmgWidgetType.widgetSwitcher:
        final idx = (node.props['activeIndex'] as num?)?.toInt() ?? 0;
        return IndexedStack(index: node.children.isEmpty ? 0 : idx.clamp(0, node.children.length - 1), children: node.children.map(_overlayChild).toList());
      case UmgWidgetType.horizontalBox:
      case UmgWidgetType.verticalBox:
        final isRow = node.type == UmgWidgetType.horizontalBox;
        final children = node.children.map((c) => _boxChild(c, isRow)).toList();
        return isRow
            ? Row(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Column(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      case UmgWidgetType.gridPanel:
        final columns = ((node.props['columns'] as num?)?.toInt() ?? 2).clamp(1, 32);
        final rows = <widgets.TableRow>[];
        for (var i = 0; i < node.children.length; i += columns) {
          rows.add(widgets.TableRow(
            children: List.generate(columns, (j) {
              final idx = i + j;
              if (idx >= node.children.length) return const SizedBox.shrink();
              final c = node.children[idx];
              return Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)));
            }),
          ));
        }
        return widgets.Table(children: rows);
      case UmgWidgetType.scrollBox:
        final horizontal = node.props['orientation'] == 'horizontal';
        final children = node.children.map((c) => Padding(padding: _padding(c.slot), child: _measuredTight(c, _build(c)))).toList();
        return SingleChildScrollView(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          child: horizontal ? Row(mainAxisSize: MainAxisSize.min, children: children) : Column(mainAxisSize: MainAxisSize.min, children: children),
        );
      case UmgWidgetType.sizeBox:
        return SizedBox(
          width: _num(node.props['width'], 200),
          height: _num(node.props['height'], 100),
          child: node.children.isEmpty ? null : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.border:
        return Card(
          filled: true,
          fillColor: _color(node, '#1B1B22'),
          padding: EdgeInsets.all(_num(node.props['padding'], 8)),
          child: node.children.isEmpty
              ? const SizedBox.expand()
              : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.button:
        return UmgThemeHelper.buildThemedButton(
          node: node,
          theme: vm.themeForNode(node),
          onPressed: onInteraction,
          child: umgText(node.props['label']?.toString() ?? 'Button', node.props, null),
        );
      case UmgWidgetType.text:
        return umgText(node.props['text']?.toString() ?? '', node.props, null);
      case UmgWidgetType.image:
        final bytes = vm.textureBytesFor(node.id);
        if (bytes == null) {
          return Container(
            // the prototype's `white/7` idiom: translucent so it keeps its weight on any surface
            decoration: BoxDecoration(border: Border.all(color: EditorColors.mutedForeground.withValues(alpha: 0.6)), color: const Color(0x11FFFFFF)),
            child: const Center(child: Icon(LucideIcons.image, size: 20, color: EditorColors.mutedForeground)),
          );
        }
        return Image.memory(
          bytes,
          fit: _drawAsFit(node.props['drawAs']),
          color: _color(node, '#FFFFFF'),
          colorBlendMode: BlendMode.modulate,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(child: Icon(LucideIcons.imageOff, size: 20, color: EditorColors.logError)),
        );
      case UmgWidgetType.progressBar:
        return Progress(progress: _num(node.props['percent'], 0.5).clamp(0.0, 1.0), color: _color(node, '#4ADE80'));
      case UmgWidgetType.slider:
        return Slider(value: SliderValue.single(_num(node.props['value'], 0.5).clamp(0.0, 1.0)), onChanged: (_) => onInteraction());
      case UmgWidgetType.checkBox:
        return Checkbox(
          state: node.props['checked'] == true ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (_) => onInteraction(),
          trailing: umgText(node.props['label']?.toString() ?? '', node.props, null),
        );
      case UmgWidgetType.editableText:
        return TextField(
          key: ValueKey('umg_rt_field_${node.id}_${node.props['text']}_${node.props['hint']}'),
          initialValue: node.props['text']?.toString() ?? '',
          placeholder: Text(node.props['hint']?.toString() ?? ''),
          style: umgTextStyle(node.props, null, outlineRing: true),
          onChanged: (_) => onInteraction(),
        );
      case UmgWidgetType.comboBox:
        final options = (node.props['options']?.toString() ?? '').split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
        final selected = node.props['selected']?.toString();
        return Select<String>(
          value: options.contains(selected) ? selected : null,
          onChanged: (_) => onInteraction(),
          itemBuilder: (context, item) => umgText(item, node.props, null),
          popup: SelectPopup(
            items: SelectItemList(children: [for (final o in options) SelectItemButton(value: o, child: Text(o))]),
          ).call,
        );
      default:
        return const SizedBox.shrink(); // Container and shadcn: handled above
    }
  }

  /// The `LuminaUmg*` twin of each shadcn widget below; null for types that
  /// are the same in both libraries.
  Widget? _buildPlain(UmgNode node) {
    switch (node.type) {
      case UmgWidgetType.border:
        return LuminaUmgBorder(
          color: _color(node, '#1B1B22'),
          padding: EdgeInsets.all(_num(node.props['padding'], 8)),
          child: node.children.isEmpty
              ? const SizedBox.expand()
              : Padding(padding: _padding(node.children.first.slot), child: _measured(node.children.first, _build(node.children.first))),
        );
      case UmgWidgetType.button:
        final style = LuminaUmgButtonStyle.values.where((s) => s.name == node.props['style']?.toString()).firstOrNull;
        return LuminaUmgButton(
          style: style ?? LuminaUmgButtonStyle.primary,
          onPressed: onInteraction,
          child: umgText(node.props['label']?.toString() ?? 'Button', node.props, null),
        );
      case UmgWidgetType.progressBar:
        return LuminaUmgProgressBar(progress: _num(node.props['percent'], 0.5), color: _color(node, '#4ADE80'));
      case UmgWidgetType.slider:
        return LuminaUmgSlider(value: _num(node.props['value'], 0.5).clamp(0.0, 1.0), onChanged: (_) => onInteraction());
      case UmgWidgetType.checkBox:
        return LuminaUmgCheckbox(
          value: node.props['checked'] == true,
          onChanged: (_) => onInteraction(),
          label: umgText(node.props['label']?.toString() ?? '', node.props, null),
        );
      case UmgWidgetType.editableText:
        return LuminaUmgTextField(
          key: ValueKey('umg_rt_field_${node.id}_${node.props['text']}_${node.props['hint']}'),
          initialValue: node.props['text']?.toString() ?? '',
          placeholder: node.props['hint']?.toString() ?? '',
          style: umgTextStyle(node.props, null, outlineRing: true),
          onChanged: (_) => onInteraction(),
        );
      case UmgWidgetType.comboBox:
        final options = (node.props['options']?.toString() ?? '').split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
        final selected = node.props['selected']?.toString();
        return LuminaUmgComboBox(
          value: options.contains(selected) ? selected : null,
          options: options,
          onChanged: (_) => onInteraction(),
          style: umgTextStyle(node.props, null),
          outline: umgTextOutline(node.props, null),
        );
      default:
        return null;
    }
  }

  Widget _buildCanvas(UmgNode node) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : vm.logicalSize.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : vm.logicalSize.height,
        );
        final children = List<UmgNode>.from(node.children)..sort((a, b) => a.slot.zOrder.compareTo(b.slot.zOrder));
        return Stack(
          key: ValueKey('umg_canvas_stack_${node.id}'),
          clipBehavior: Clip.none,
          children: [
            for (final c in children)
              () {
                final r = UmgLayout.resolveCanvasRect(c.slot, size);
                return Positioned(
                  key: ValueKey('umg_canvas_child_${c.id}'),
                  left: r.left,
                  top: r.top,
                  width: c.slot.sizeToContent ? null : r.width,
                  height: c.slot.sizeToContent ? null : r.height,
                  child: c.slot.sizeToContent ? _measuredTight(c, _build(c)) : _measured(c, _build(c)),
                );
              }(),
          ],
        );
      },
    );
  }

  Widget _overlayChild(UmgNode c) {
    final s = c.slot;
    final child = _build(c);
    if (s.hAlign == UmgAlign.fill && s.vAlign == UmgAlign.fill) {
      return Positioned.fill(child: Padding(padding: _padding(s), child: _measured(c, child)));
    }
    final sized = (s.hAlign == UmgAlign.fill || s.vAlign == UmgAlign.fill)
        ? SizedBox(width: s.hAlign == UmgAlign.fill ? double.infinity : null, height: s.vAlign == UmgAlign.fill ? double.infinity : null, child: child)
        : child;
    return Positioned.fill(
      child: Padding(
        padding: _padding(s),
        child: Align(alignment: _alignment(s), child: _measuredTight(c, sized)),
      ),
    );
  }

  Widget _boxChild(UmgNode c, bool isRow) {
    final s = c.slot;
    Widget child = _measuredTight(c, _build(c));
    final cross = isRow ? s.vAlign : s.hAlign;
    if (cross != UmgAlign.fill) {
      child = Align(alignment: isRow ? Alignment(0, _alignValue(cross)) : Alignment(_alignValue(cross), 0), child: child);
    }
    child = Padding(padding: _padding(s), child: child);
    if (s.fill) {
      child = Expanded(flex: (s.flex * 100).round().clamp(1, 100000), child: child);
    }
    return child;
  }



  BoxFit _drawAsFit(dynamic v) {
    switch (v?.toString()) {
      case 'box':
        return BoxFit.fill;
      case 'border':
        return BoxFit.cover;
      default:
        return BoxFit.contain;
    }
  }
}
