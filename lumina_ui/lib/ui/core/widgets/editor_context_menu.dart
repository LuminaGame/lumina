import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A right-click menu over [child], used instead of shadcn's `ContextMenu`.
///
/// shadcn's `ContextMenu` opens on `onSecondaryTapDown`, which Flutter calls
/// for every tap recognizer under the pointer once the press timeout passes,
/// before the gesture arena picks a winner — so nested menus (an asset tile
/// inside the content browser's background) opened both menus stacked on top
/// of each other.
///
/// This widget listens to raw pointer events instead, outside the gesture
/// arena: pointer events reach the innermost listener first, and the first
/// [EditorContextMenu] to see a right-button press claims that pointer, so
/// outer menus ignore it. The claiming menu opens on release, at the release
/// point. Gesture detectors inside [child] (a tile's own `onSecondaryTap`
/// selecting it) keep working, because nothing here enters the arena.
class EditorContextMenu extends StatefulWidget {
  final Widget child;
  final List<MenuItem> items;
  final bool enabled;
  final HitTestBehavior behavior;

  const EditorContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.enabled = true,
    this.behavior = HitTestBehavior.translucent,
  });

  /// Pointers a menu has claimed for the current press.
  static final Set<int> _claimed = <int>{};

  /// Opens [items] with the menu's top-left corner at [globalPosition].
  static void show(BuildContext context, Offset globalPosition, List<MenuItem> items) {
    if (items.isEmpty) return;
    showDropdown(
      context: context,
      position: globalPosition,
      // An explicit position is where the menu opens; following the anchor
      // would drag it to the anchor's bottom centre.
      follow: false,
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      builder: (context) => DropdownMenu(children: items),
    );
  }

  @override
  State<EditorContextMenu> createState() => _EditorContextMenuState();
}

class _EditorContextMenuState extends State<EditorContextMenu> {
  int? _armedPointer;

  bool get _active => widget.enabled && widget.items.isNotEmpty;

  void _down(PointerDownEvent e) {
    if (!_active || (e.buttons & kSecondaryMouseButton) == 0) return;
    if (EditorContextMenu._claimed.add(e.pointer)) _armedPointer = e.pointer;
  }

  void _up(PointerUpEvent e) {
    if (_armedPointer != e.pointer) return;
    _armedPointer = null;
    EditorContextMenu._claimed.remove(e.pointer);
    if (mounted && _active) EditorContextMenu.show(context, e.position, widget.items);
  }

  void _cancel(PointerCancelEvent e) {
    if (_armedPointer != e.pointer) return;
    _armedPointer = null;
    EditorContextMenu._claimed.remove(e.pointer);
  }

  @override
  void dispose() {
    final p = _armedPointer;
    if (p != null) EditorContextMenu._claimed.remove(p);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
