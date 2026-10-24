import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Content Drawer of the Aurora layout, while the bottom panel is not
/// pinned: a 36 px [ContentDrawerBar] along the bottom of the viewport
/// island, and above it the bottom panel ([panel]: Content Browser, Output
/// Log, Blueprint, plugin tabs) sliding up [height] px over the viewport.
/// The viewport keeps the rest of its area and its input; pinning docks the
/// panel into the layout instead.
class ContentDrawer extends StatelessWidget {
  const ContentDrawer({super.key, required this.viewModel, required this.viewport, required this.panel});

  final EditorViewModel viewModel;

  /// The 3D viewport the drawer slides over.
  final Widget viewport;

  /// The bottom panel shown in the open drawer.
  final Widget panel;

  /// The open drawer's height on the canvas.
  static const double height = 322;

  /// How long the slide takes.
  static const Duration slide = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final open = viewModel.layoutState.bottomVisible;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Never taller than the viewport above the bar.
              final drawerHeight = height.clamp(0.0, constraints.maxHeight).toDouble();
              return Stack(
                fit: StackFit.expand,
                children: [
                  viewport,
                  AnimatedPositioned(
                    key: const ValueKey('content_drawer_panel'),
                    duration: slide,
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    height: drawerHeight,
                    bottom: open ? 0 : -drawerHeight,
                    // Closed, the panel is not built: nothing of it stays
                    // focusable or hit-testable under the viewport.
                    child: open ? _DrawerSheet(child: panel) : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
        ContentDrawerBar(viewModel: viewModel),
      ],
    );
  }
}

/// The open drawer: the island fill at near opacity over the viewport, a
/// top border and shadow, and a short grip above the panel.
class _DrawerSheet extends StatelessWidget {
  const _DrawerSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EditorColors.sidebar.withValues(alpha: 0.965),
        border: const Border(top: BorderSide(color: EditorColors.fieldBorder)),
        boxShadow: const [
          // A drop shadow up over the viewport: black at 50 %, not a theme surface.
          BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, -12)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 6,
            child: Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(color: EditorColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The 36 px bar under the viewport: the Content Drawer toggle (open and
/// close; it brings the Content Browser forward), the pin that docks the
/// panel into the layout, the selected folder as a breadcrumb, the Output
/// Log button, and the editor's state (Ready, and whether the MCP server for
/// AI agents is on).
class ContentDrawerBar extends StatelessWidget {
  const ContentDrawerBar({super.key, required this.viewModel});

  final EditorViewModel viewModel;

  static const double height = 36;

  void _toggleContent() {
    final layout = viewModel.layoutState;
    if (layout.bottomVisible && layout.activeBottomTab == EditorLayoutState.contentBrowserTab) {
      layout.bottomVisible = false;
    } else {
      layout.activeBottomTab = EditorLayoutState.contentBrowserTab;
      layout.bottomVisible = true;
    }
    viewModel.saveLayoutState();
  }

  void _toggleOutputLog() {
    final layout = viewModel.layoutState;
    if (layout.isOutputLogOpen) {
      layout.bottomVisible = false;
    } else {
      layout.activeBottomTab = EditorLayoutState.outputLogTab;
      layout.bottomVisible = true;
    }
    viewModel.saveLayoutState();
  }

  /// `Content / Props / Barrels` for `contents/Props/Barrels`.
  static String breadcrumb(String? folder) {
    final parts = (folder ?? 'contents').split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty || parts.first != 'contents') parts.insert(0, 'contents');
    parts[0] = 'Content';
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final layout = viewModel.layoutState;
    final contentOpen = layout.bottomVisible && layout.activeBottomTab == EditorLayoutState.contentBrowserTab;
    final mcp = viewModel.mcpServer;
    return Container(
      key: const ValueKey('content_drawer_bar'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: EditorColors.sidebar,
        border: Border(top: BorderSide(color: EditorColors.border)),
      ),
      child: Row(
        children: [
          _BarButton(
            key: const ValueKey('content_drawer_toggle'),
            highlighted: contentOpen,
            onPressed: _toggleContent,
            children: [
              const Icon(LucideIcons.folderOpen, size: 13, color: EditorColors.foreground),
              const SizedBox(width: 6),
              Text('Content Drawer', style: _label),
              const SizedBox(width: 6),
              Icon(contentOpen ? LucideIcons.chevronDown : LucideIcons.chevronUp, size: 12, color: EditorColors.mutedForeground),
            ],
          ),
          const SizedBox(width: 8),
          Tooltip(
            tooltip: (_) => const TooltipContainer(child: Text('Pin the Content Drawer to the layout')),
            child: _BarButton(
              key: const ValueKey('content_drawer_pin'),
              square: true,
              onPressed: () => viewModel.setBottomPinned(true),
              children: const [Icon(LucideIcons.pin, size: 13, color: EditorColors.mutedForeground)],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              breadcrumb(viewModel.selectedFolder),
              key: const ValueKey('content_drawer_breadcrumb'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
            ),
          ),
          const Spacer(),
          _BarButton(
            key: const ValueKey('content_drawer_output_log'),
            highlighted: layout.isOutputLogOpen,
            onPressed: _toggleOutputLog,
            children: [Text('Output Log', style: _label)],
          ),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: mcp,
            builder: (context, _) => Row(
              key: const ValueKey('content_drawer_status'),
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: EditorColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Ready · MCP ${mcp.isRunning ? 'on' : 'off'}',
                  style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle get _label =>
      EditorTypography.ui(fontSize: EditorTypography.labelSize, fontWeight: FontWeight.w600, color: EditorColors.foreground);
}

/// A 26 px outlined bar button; [highlighted] draws its outline in amber.
class _BarButton extends StatelessWidget {
  const _BarButton({super.key, required this.onPressed, required this.children, this.highlighted = false, this.square = false});

  final VoidCallback onPressed;
  final List<Widget> children;
  final bool highlighted;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 26,
          width: square ? 26 : null,
          padding: square ? null : const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: EditorColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlighted ? EditorColors.primary : EditorColors.fieldBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: children),
        ),
      ),
    );
  }
}
