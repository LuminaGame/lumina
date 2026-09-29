import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/editor_theme.dart';
import 'lumina_window.dart';

/// Lumina's own window buttons at the right end of the menu bar row (and of
/// the launcher header): minimize, maximize ⇄ restore (the
/// icon follows the window's real state), fullscreen and close (red on hover;
/// it goes through [LuminaWindow.requestClose], so the editor's
/// unsaved-changes prompt runs first).
///
/// macOS keeps its system traffic lights at the left, so there this draws
/// nothing ([LuminaWindow.drawsOwnControls]).
class LuminaWindowControls extends StatelessWidget {
  const LuminaWindowControls({super.key, this.height = 30, this.showFullScreen = true});

  final double height;
  final bool showFullScreen;

  @override
  Widget build(BuildContext context) {
    if (!LuminaWindow.drawsOwnControls) return const SizedBox.shrink();
    final window = LuminaWindowScope.of(context);
    final maximized = window.isMaximized;
    final full = window.isFullScreen;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFullScreen)
            _WindowButton(
              key: const ValueKey('window_control_fullscreen'),
              tooltip: full ? 'Exit Full Screen (F11)' : 'Full Screen (F11)',
              icon: Icon(full ? LucideIcons.minimize : LucideIcons.maximize, size: 12),
              onPressed: window.toggleFullScreen,
            ),
          _WindowButton(
            key: const ValueKey('window_control_minimize'),
            tooltip: 'Minimize',
            icon: const Icon(LucideIcons.minus, size: 14),
            onPressed: window.minimize,
          ),
          _WindowButton(
            key: const ValueKey('window_control_maximize'),
            tooltip: maximized ? 'Restore Down' : 'Maximize',
            icon: maximized
                ? const Icon(LucideIcons.copy, key: ValueKey('window_control_restore_icon'), size: 12)
                : const Icon(LucideIcons.square, key: ValueKey('window_control_maximize_icon'), size: 12),
            onPressed: window.toggleMaximize,
          ),
          _WindowButton(
            key: const ValueKey('window_control_close'),
            tooltip: 'Close',
            icon: const Icon(LucideIcons.x, size: 14),
            destructive: true,
            onPressed: window.requestClose,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({super.key, required this.tooltip, required this.icon, required this.onPressed, this.destructive = false});

  final String tooltip;
  final Widget icon;
  final Future<Object?> Function() onPressed;
  final bool destructive;

  /// Wide enough to hit, like the system's own caption buttons.
  static const double width = 40;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fill = !_hover
        ? Colors.transparent
        : widget.destructive
            ? EditorColors.destructive
            : EditorColors.rowHover;
    final Color fg = _hover && widget.destructive ? EditorColors.accentForeground : EditorColors.foreground;
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(widget.tooltip)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPressed(),
          child: Container(
            width: _WindowButton.width,
            color: fill,
            alignment: Alignment.center,
            child: IconTheme.merge(data: IconThemeData(color: fg), child: widget.icon),
          ),
        ),
      ),
    );
  }
}

/// The part of a title bar that moves the window: drag to move it,
/// double-click to maximize / restore.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, this.child = const SizedBox.expand()});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final window = LuminaWindowScope.read(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => window.startDragging(),
      onDoubleTap: window.toggleMaximize,
      child: child,
    );
  }
}

/// The app's window frame, above every route: puts [window] in scope, gives
/// F11 (fullscreen) to screens that have no shortcut layer of their own (the
/// editor maps it to View ▸ Full Screen), and — where the native border is
/// gone (Linux) — lays a thin resize border along every edge and corner,
/// which drives `gtk_window_begin_resize_drag` through the plugin. The border
/// steps aside while the window is maximized or fullscreen.
class LuminaWindowFrame extends StatelessWidget {
  const LuminaWindowFrame({super.key, required this.window, required this.child});

  final LuminaWindow window;
  final Widget child;

  /// The border's thickness; corners take twice that along each side.
  static const double edge = 5;

  @override
  Widget build(BuildContext context) {
    return LuminaWindowScope(
      window: window,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.f11): () => window.toggleFullScreen()},
        child: Focus(
          autofocus: true,
          child: ListenableBuilder(
            listenable: window,
            builder: (context, _) {
              final resizable = LuminaWindow.needsResizeBorder && !window.isMaximized && !window.isFullScreen;
              if (!resizable) return child;
              return Stack(
                children: [
                  Positioned.fill(child: child),
                  ..._edges(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _edges() {
    const c = edge * 2;
    Widget grip(ResizeEdge e, MouseCursor cursor) => MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            key: ValueKey('window_resize_${e.name}'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => window.startResizing(e),
          ),
        );
    return [
      Positioned(left: c, right: c, top: 0, height: edge, child: grip(ResizeEdge.top, SystemMouseCursors.resizeUp)),
      Positioned(left: c, right: c, bottom: 0, height: edge, child: grip(ResizeEdge.bottom, SystemMouseCursors.resizeDown)),
      Positioned(top: c, bottom: c, left: 0, width: edge, child: grip(ResizeEdge.left, SystemMouseCursors.resizeLeft)),
      Positioned(top: c, bottom: c, right: 0, width: edge, child: grip(ResizeEdge.right, SystemMouseCursors.resizeRight)),
      Positioned(left: 0, top: 0, width: c, height: c, child: grip(ResizeEdge.topLeft, SystemMouseCursors.resizeUpLeft)),
      Positioned(right: 0, top: 0, width: c, height: c, child: grip(ResizeEdge.topRight, SystemMouseCursors.resizeUpRight)),
      Positioned(left: 0, bottom: 0, width: c, height: c, child: grip(ResizeEdge.bottomLeft, SystemMouseCursors.resizeDownLeft)),
      Positioned(right: 0, bottom: 0, width: c, height: c, child: grip(ResizeEdge.bottomRight, SystemMouseCursors.resizeDownRight)),
    ];
  }
}
