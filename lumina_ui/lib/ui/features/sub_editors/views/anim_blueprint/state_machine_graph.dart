// design-token-exempt: state-machine painter colours (state bodies, transition arrows, the active-state and blend highlights) follow node-graph conventions, not the editor chrome palette.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';

/// Geometry of the state machine canvas, shared by the painter, the widgets
/// and hit-testing.
abstract final class AnimStateLayout {
  static const Size stateSize = Size(150, 46);
  static const Size entrySize = Size(64, 28);

  static Rect stateRect(LuminaAnimState s) => Offset(s.x, s.y) & stateSize;

  static Rect entryRect(LuminaAnimStateMachine m) {
    final entry = m.state(m.entryState);
    final anchor = entry == null ? Offset.zero : Offset(entry.x, entry.y);
    return (anchor + const Offset(-150, 9)) & entrySize;
  }

  /// Where the arrow of [t] runs: centre to centre, shifted sideways when the
  /// opposite transition exists so both arrows show, clipped to the rects.
  static (Offset, Offset)? arrow(LuminaAnimStateMachine m, LuminaAnimTransition t) {
    final a = m.state(t.from);
    final b = m.state(t.to);
    if (a == null || b == null) return null;
    final ra = stateRect(a);
    final rb = stateRect(b);
    var p = ra.center;
    var q = rb.center;
    final dir = q - p;
    if (dir.distance < 1) return null;
    final unit = dir / dir.distance;
    final normal = Offset(-unit.dy, unit.dx);
    if (m.transitions.any((o) => o.from == t.to && o.to == t.from)) {
      p += normal * 8;
      q += normal * 8;
    }
    return (_clip(ra, p, q), _clip(rb, q, p));
  }

  /// The point where the segment from [inside] toward [outside] leaves [r].
  static Offset _clip(Rect r, Offset inside, Offset outside) {
    final d = outside - inside;
    var t = 1.0;
    if (d.dx != 0) {
      final tx = ((d.dx > 0 ? r.right : r.left) - inside.dx) / d.dx;
      if (tx > 0) t = math.min(t, tx);
    }
    if (d.dy != 0) {
      final ty = ((d.dy > 0 ? r.bottom : r.top) - inside.dy) / d.dy;
      if (ty > 0) t = math.min(t, ty);
    }
    return inside + d * t;
  }
}

/// A state machine graph (e.g. a "Locomotion" graph): states, the Entry
/// node, transition arrows with rule markers, the preview's active state
/// highlighted. Right-click adds a state; dragging from a state's handle to
/// another state adds a transition; double-clicking a state opens its pose
/// and a marker opens its rule.
class AnimStateMachineGraph extends StatefulWidget {
  final AnimBlueprintEditorViewModel viewModel;

  const AnimStateMachineGraph({super.key, required this.viewModel});

  @override
  State<AnimStateMachineGraph> createState() => AnimStateMachineGraphState();
}

class AnimStateMachineGraphState extends State<AnimStateMachineGraph> {
  Offset _pan = const Offset(260, 140);
  double _zoom = 1.0;
  final GlobalKey _stackKey = GlobalKey();
  final FocusNode _focus = FocusNode(debugLabel: 'AnimStateMachineGraph');

  String? _dragFrom;
  bool _dragFromEntry = false;
  Offset? _dragPointer;
  bool _moving = false;

  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastTapTarget;
  bool _framed = false;
  Size _size = Size.zero;

  /// Centres the Entry node and every state in the view (on open, and F).
  void frameAll() {
    final m = vm.machine;
    if (m == null || _size.isEmpty) return;
    var bounds = AnimStateLayout.entryRect(m);
    for (final s in m.states) {
      bounds = bounds.expandToInclude(AnimStateLayout.stateRect(s));
    }
    _pan = Offset(_size.width / 2, _size.height / 2) - bounds.center * _zoom;
  }

  AnimBlueprintEditorViewModel get vm => widget.viewModel;

  Offset toScreen(Offset canvas) => canvas * _zoom + _pan;
  Offset _toCanvas(Offset local) => (local - _pan) / _zoom;

  Offset _local(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// Screen (widget-local) centre of state [name], for tests and drags.
  Offset? stateCenter(String name) {
    final s = vm.machine?.state(name);
    return s == null ? null : toScreen(AnimStateLayout.stateRect(s).center);
  }

  /// Screen position of state [name]'s transition handle.
  Offset? handleCenter(String name) {
    final s = vm.machine?.state(name);
    return s == null ? null : toScreen(AnimStateLayout.stateRect(s).centerRight + const Offset(-8, 0));
  }

  /// Screen position of transition [id]'s rule marker.
  Offset? transitionMarker(String id) {
    final m = vm.machine;
    final t = vm.transition(id);
    if (m == null || t == null) return null;
    final a = AnimStateLayout.arrow(m, t);
    return a == null ? null : toScreen((a.$1 + a.$2) / 2);
  }

  bool _isDoubleTap(String target) {
    final now = DateTime.now();
    final doubleTap = _lastTapTarget == target && now.difference(_lastTap) < const Duration(milliseconds: 400);
    _lastTap = now;
    _lastTapTarget = target;
    return doubleTap;
  }

  String? _stateAt(Offset canvas) {
    for (final s in (vm.machine?.states ?? const <LuminaAnimState>[]).reversed) {
      if (AnimStateLayout.stateRect(s).inflate(4).contains(canvas)) return s.name;
    }
    return null;
  }

  void _openState(String name) => vm.open(AnimGraphLocation.state(vm.machine!.name, name));
  void _openRule(String id) => vm.open(AnimGraphLocation.transition(vm.machine!.name, id));

  void _canvasMenu(Offset global) {
    final canvas = _toCanvas(_local(global));
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('sm_menu_add_state'),
            leading: const Icon(LucideIcons.squarePlus, size: 12),
            child: const Text('Add State', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) =>
                vm.addState(canvas - Offset(AnimStateLayout.stateSize.width / 2, AnimStateLayout.stateSize.height / 2)),
          ),
        ],
      ),
    );
  }

  void _stateMenu(String name, Offset global) {
    vm.selectState(name);
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('state_menu_open'),
            leading: const Icon(LucideIcons.squareArrowOutUpRight, size: 12),
            child: const Text('Open Pose', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => _openState(name),
          ),
          MenuButton(
            key: const ValueKey('state_menu_entry'),
            leading: const Icon(LucideIcons.logIn, size: 12),
            child: const Text('Set as Entry State', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => vm.setEntryState(name),
          ),
          MenuButton(
            key: const ValueKey('state_menu_rename'),
            leading: const Icon(LucideIcons.pencil, size: 12),
            child: const Text('Rename', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => showRenameState(context, vm, name),
          ),
          MenuButton(
            key: const ValueKey('state_menu_delete'),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Delete', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => vm.deleteState(name),
          ),
        ],
      ),
    );
  }

  void _transitionMenu(String id, Offset global) {
    vm.selectTransition(id);
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('transition_menu_open'),
            leading: const Icon(LucideIcons.squareArrowOutUpRight, size: 12),
            child: const Text('Open Rule', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => _openRule(id),
          ),
          MenuButton(
            key: const ValueKey('transition_menu_delete'),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Delete', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => vm.deleteTransition(id),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final m = vm.machine;
        final active = vm.previewState;
        return Focus(
          focusNode: _focus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyF) {
              setState(frameAll);
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace)) {
              if (vm.selectedTransition != null && vm.deleteTransition(vm.selectedTransition!)) {
                return KeyEventResult.handled;
              }
              if (vm.selectedState != null && vm.deleteState(vm.selectedState!)) return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerMove: (e) {
              if (e.buttons & (kSecondaryMouseButton | kMiddleMouseButton) != 0) setState(() => _pan += e.delta);
            },
            onPointerSignal: (s) {
              if (s is PointerScrollEvent) {
                final local = _local(s.position);
                final c = _toCanvas(local);
                setState(() {
                  _zoom = (_zoom + (s.scrollDelta.dy < 0 ? 0.1 : -0.1)).clamp(0.4, 2.0).toDouble();
                  _pan = local - c * _zoom;
                });
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focus.requestFocus();
                vm.selectState(null);
              },
              onSecondaryTapUp: (d) => _canvasMenu(d.globalPosition),
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _size = constraints.biggest;
                    if (!_framed && m != null && !_size.isEmpty) {
                      frameAll();
                      _framed = true;
                    }
                    return Stack(
                      key: _stackKey,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _StateMachinePainter(
                              machine: m,
                              pan: _pan,
                              zoom: _zoom,
                              selectedTransition: vm.selectedTransition,
                              dragStart: _dragFrom == null
                                  ? (_dragFromEntry && m != null ? AnimStateLayout.entryRect(m).centerRight : null)
                                  : m?.state(_dragFrom!) == null
                                  ? null
                                  : AnimStateLayout.stateRect(m!.state(_dragFrom!)!).centerRight,
                              dragEnd: _dragPointer,
                            ),
                          ),
                        ),
                        if (m == null)
                          const Center(
                            child: Text(
                              'No state machine. Right-click → Add State.',
                              style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
                            ),
                          ),
                        if (m != null) _entryNode(m),
                        if (m != null)
                          for (final s in m.states) _stateNode(m, s, active: s.name == active),
                        if (m != null)
                          for (final t in m.transitions) ?_transitionMarker(m, t),
                        Positioned(
                          left: 12,
                          bottom: 10,
                          child: IgnorePointer(
                            child: Text(
                              active == null ? 'Preview: —' : 'Preview: $active  ·  ${vm.previewClip ?? 'no clip'}',
                              key: const ValueKey('sm_preview_status'),
                              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 10,
                          child: IgnorePointer(
                            child: Text(
                              (m?.name ?? 'State Machine').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0x22FFFFFF),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _entryNode(LuminaAnimStateMachine m) {
    final r = AnimStateLayout.entryRect(m);
    final p = toScreen(r.topLeft);
    return Positioned(
      key: const ValueKey('state_machine_entry'),
      left: p.dx,
      top: p.dy,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onPanStart: (d) => setState(() {
            _dragFromEntry = true;
            _dragPointer = _toCanvas(_local(d.globalPosition));
          }),
          onPanUpdate: (d) => setState(() => _dragPointer = _toCanvas(_local(d.globalPosition))),
          onPanEnd: (_) {
            final target = _dragPointer == null ? null : _stateAt(_dragPointer!);
            setState(() {
              _dragFromEntry = false;
              _dragPointer = null;
            });
            if (target != null) vm.setEntryState(target);
          },
          child: Container(
            width: AnimStateLayout.entrySize.width,
            height: AnimStateLayout.entrySize.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2E3B2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF66BB6A)),
            ),
            child: const Text(
              'Entry',
              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateNode(LuminaAnimStateMachine m, LuminaAnimState s, {required bool active}) {
    final selected = vm.selectedState == s.name;
    final entry = m.entryState == s.name;
    final p = toScreen(Offset(s.x, s.y));
    final poseLabel = switch (s.pose.kind) {
      LuminaAnimPoseKind.clip => s.pose.clip ?? '',
      LuminaAnimPoseKind.blendSpace => (s.pose.blendSpace ?? '').split('/').last.replaceAll('.lmas', ''),
      LuminaAnimPoseKind.hold => 'Hold pose',
      LuminaAnimPoseKind.motionMatching => 'Motion matching: ${(s.pose.database ?? '').split('/').last.replaceAll('.lmas', '')}',
    };
    return Positioned(
      key: ValueKey('anim_state_${s.name}'),
      left: p.dx,
      top: p.dy,
      child: Transform.scale(
        scale: _zoom,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: () {
            _focus.requestFocus();
            if (_isDoubleTap('state:${s.name}')) {
              _openState(s.name);
            } else {
              vm.selectState(s.name);
            }
          },
          onSecondaryTapUp: (d) => _stateMenu(s.name, d.globalPosition),
          onPanStart: (_) {
            vm.selectState(s.name);
            vm.beginInteraction('Move state ${s.name}');
            _moving = true;
          },
          onPanUpdate: (d) => vm.moveState(s.name, d.delta),
          onPanEnd: (_) {
            if (_moving) vm.endInteraction(layoutOnly: true);
            _moving = false;
          },
          child: Container(
            width: AnimStateLayout.stateSize.width,
            height: AnimStateLayout.stateSize.height,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF4A3A12) : const Color(0xFF26292E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? const Color(0xFFFFB300)
                    : selected
                    ? EditorColors.primary
                    : const Color(0xFF50555C),
                width: active || selected ? 2.2 : 1.2,
              ),
              boxShadow: active ? const [BoxShadow(color: Color(0x88FFB300), blurRadius: 14)] : const [],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 22, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (entry) const Icon(LucideIcons.logIn, size: 10, color: Color(0xFF66BB6A)),
                          if (entry) const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        poseLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Positioned(
                    key: ValueKey('anim_state_active_marker'),
                    right: 22,
                    top: 4,
                    child: Icon(LucideIcons.play, size: 9, color: Color(0xFFFFB300)),
                  ),
                Positioned(
                  right: 1,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: ValueKey('state_handle_${s.name}'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => setState(() {
                      _dragFrom = s.name;
                      _dragPointer = _toCanvas(_local(d.globalPosition));
                    }),
                    onPanUpdate: (d) => setState(() => _dragPointer = _toCanvas(_local(d.globalPosition))),
                    onPanEnd: (_) {
                      final from = _dragFrom;
                      final target = _dragPointer == null ? null : _stateAt(_dragPointer!);
                      setState(() {
                        _dragFrom = null;
                        _dragPointer = null;
                      });
                      if (from != null && target != null && target != from) vm.addTransition(from, target);
                    },
                    child: const SizedBox(
                      width: 16,
                      child: Center(
                        child: Icon(LucideIcons.circleArrowRight, size: 12, color: EditorColors.mutedForeground),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _transitionMarker(LuminaAnimStateMachine m, LuminaAnimTransition t) {
    final a = AnimStateLayout.arrow(m, t);
    if (a == null) return null;
    final c = toScreen((a.$1 + a.$2) / 2);
    final selected = vm.selectedTransition == t.id;
    return Positioned(
      key: ValueKey('transition_${t.id}'),
      left: c.dx - 9,
      top: c.dy - 9,
      child: GestureDetector(
        onTap: () {
          _focus.requestFocus();
          if (_isDoubleTap('transition:${t.id}')) {
            _openRule(t.id);
          } else {
            vm.selectTransition(t.id);
          }
        },
        onSecondaryTapUp: (d) => _transitionMenu(t.id, d.globalPosition),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? EditorColors.primary : const Color(0xFF383C42),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Icon(LucideIcons.arrowLeftRight, size: 10, color: Colors.white),
        ),
      ),
    );
  }
}

/// Renames a state from a dialog.
void showRenameState(BuildContext context, AnimBlueprintEditorViewModel vm, String name) {
  final controller = TextEditingController(text: name);
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => AlertDialog(
      title: Text('Rename state $name'),
      content: SizedBox(
        width: 260,
        child: TextField(key: const ValueKey('state_rename_field'), controller: controller, autofocus: true),
      ),
      actions: [
        GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
        PrimaryButton(
          key: const ValueKey('state_rename_ok'),
          onPressed: () {
            if (vm.renameState(name, controller.text)) closeOverlay(dialogContext);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

class _StateMachinePainter extends CustomPainter {
  final LuminaAnimStateMachine? machine;
  final Offset pan;
  final double zoom;
  final String? selectedTransition;
  final Offset? dragStart;
  final Offset? dragEnd;

  _StateMachinePainter({
    required this.machine,
    required this.pan,
    required this.zoom,
    required this.selectedTransition,
    required this.dragStart,
    required this.dragEnd,
  });

  Offset _s(Offset c) => c * zoom + pan;

  void _arrow(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(a, b, paint);
    final d = b - a;
    if (d.distance < 1) return;
    final u = d / d.distance;
    final n = Offset(-u.dy, u.dx);
    final head = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo((b - u * 10 + n * 5).dx, (b - u * 10 + n * 5).dy)
      ..lineTo((b - u * 10 - n * 5).dx, (b - u * 10 - n * 5).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = paint.color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF17181B));
    final grid = Paint()..color = const Color(0xFF22252A);
    final step = 20.0 * zoom;
    for (var x = pan.dx % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = pan.dy % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final m = machine;
    if (m == null) return;
    final entry = m.state(m.entryState);
    if (entry != null) {
      final r = AnimStateLayout.entryRect(m);
      _arrow(
        canvas,
        _s(r.centerRight),
        _s(AnimStateLayout.stateRect(entry).centerLeft),
        Paint()
          ..color = const Color(0xFF66BB6A)
          ..strokeWidth = 2 * zoom,
      );
    }
    for (final t in m.transitions) {
      final a = AnimStateLayout.arrow(m, t);
      if (a == null) continue;
      _arrow(
        canvas,
        _s(a.$1),
        _s(a.$2),
        Paint()
          ..color = t.id == selectedTransition ? EditorColors.primary : const Color(0xFFCFD3D8)
          ..strokeWidth = (t.id == selectedTransition ? 2.6 : 1.8) * zoom,
      );
    }
    if (dragStart != null && dragEnd != null) {
      _arrow(
        canvas,
        _s(dragStart!),
        _s(dragEnd!),
        Paint()
          ..color = EditorColors.primary.withValues(alpha: 0.8)
          ..strokeWidth = 2 * zoom,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StateMachinePainter oldDelegate) => true;
}
