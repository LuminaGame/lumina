import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/widgets.dart' as widgets show Table, TableRow;
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaUmgBorder, LuminaUmgButton, LuminaUmgButtonStyle, LuminaUmgCheckbox, LuminaUmgComboBox, LuminaUmgProgressBar, LuminaUmgSlider, LuminaUmgTextField, kUmgWidgetLibraryFlutter;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_components.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_text_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

part 'designer_canvas/painters.dart';
part 'designer_canvas/runtime_tree.dart';

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
