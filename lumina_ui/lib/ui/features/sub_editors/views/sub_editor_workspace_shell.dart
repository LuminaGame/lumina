import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_content_drawer.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';

/// Workspace shell for Sub-Editors and Plugin Editor Tabs.
///
/// Provides uniform panel framing, asset drag-and-drop (`contentDroppable`),
/// and integrated bottom Content Browser / Content Drawer (`contentBrowserOpened`).
class SubEditorWorkspaceShell extends StatefulWidget {
  final Widget child;
  final String assetType;
  final String assetName;
  final EditorViewModel? editorViewModel;
  final bool? contentDroppable;
  final bool? contentBrowserOpened;
  final void Function(RealAssetInfo asset)? onAssetDropped;

  /// The tab the shell is in: the editor's status bar toggles its Content
  /// Drawer. Without one the shell shows its own drawer button.
  final String? tabId;

  const SubEditorWorkspaceShell({
    super.key,
    required this.child,
    required this.assetType,
    required this.assetName,
    this.editorViewModel,
    this.contentDroppable,
    this.contentBrowserOpened,
    this.onAssetDropped,
    this.tabId,
  });

  @override
  State<SubEditorWorkspaceShell> createState() => _SubEditorWorkspaceShellState();
}

class _SubEditorWorkspaceShellState extends State<SubEditorWorkspaceShell> {
  late final SubEditorContentDrawer _drawer;
  late final bool _ownsDrawer;
  double _bottomHeight = 240.0;

  bool get _pinned => _drawer.pinned;
  bool get _drawerOpen => _drawer.open;

  @override
  void initState() {
    super.initState();
    final tabId = widget.tabId, editor = widget.editorViewModel;
    if (tabId != null && editor != null) {
      _ownsDrawer = false;
      _drawer = editor.subEditorDrawer(tabId, pinned: _resolveContentBrowserOpened());
    } else {
      _ownsDrawer = true;
      _drawer = SubEditorContentDrawer(pinned: _resolveContentBrowserOpened());
    }
    _drawer.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _drawer.removeListener(_changed);
    if (_ownsDrawer) _drawer.dispose();
    super.dispose();
  }

  bool _resolveContentBrowserOpened() {
    if (widget.contentBrowserOpened != null) {
      return widget.contentBrowserOpened!;
    }
    final customTab = widget.editorViewModel?.extensionRegistry.findTab(widget.assetType);
    if (customTab != null) {
      return customTab.contentBrowserOpened;
    }
    if (widget.assetType.startsWith(PluginExtensionRegistry.pluginAssetCategoryPrefix)) {
      final customId = widget.assetType.substring(PluginExtensionRegistry.pluginAssetCategoryPrefix.length);
      final handler = widget.editorViewModel?.extensionRegistry.allAssetTypes
          .where((h) => h.customTypeId == customId)
          .firstOrNull;
      if (handler != null) {
        return handler.contentBrowserOpened;
      }
    }
    return false;
  }

  bool _resolveContentDroppable() {
    if (widget.contentDroppable != null) {
      return widget.contentDroppable!;
    }
    final customTab = widget.editorViewModel?.extensionRegistry.findTab(widget.assetType);
    if (customTab != null) {
      return customTab.contentDroppable;
    }
    if (widget.assetType.startsWith(PluginExtensionRegistry.pluginAssetCategoryPrefix)) {
      final customId = widget.assetType.substring(PluginExtensionRegistry.pluginAssetCategoryPrefix.length);
      final handler = widget.editorViewModel?.extensionRegistry.allAssetTypes
          .where((h) => h.customTypeId == customId)
          .firstOrNull;
      if (handler != null) {
        return handler.contentDroppable;
      }
    }
    // Built-in sub-editors that accept project assets
    return const {
      'Material',
      'FILAMAT',
      'Material Editor',
      'Blueprint',
      'ACTOR',
      'BLUEPRINT',
      'Blueprint Editor',
      'UMG',
      'Widget',
      'Widget (UMG)',
      'Skeletal Mesh',
      'SkeletalMesh',
      'Animation',
      'Landscape',
    }.contains(widget.assetType);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editorViewModel == null) {
      return _buildDroppableChild(widget.child);
    }

    if (_pinned) {
      return ResizablePanel.vertical(
        draggerBuilder: (context) => const VerticalResizableDragger(),
        children: [
          ResizablePane.flex(
            key: const ValueKey('sub_editor_main_pane'),
            child: _buildDroppableChild(widget.child),
          ),
          ResizablePane(
            key: const ValueKey('sub_editor_bottom_pane'),
            initialSize: _bottomHeight,
            minSize: 120,
            onSizeChangeEnd: (size) => setState(() => _bottomHeight = size),
            child: _buildBottomPanel(pinned: true),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _buildDroppableChild(widget.child),
        ),
        if (_drawerOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _bottomHeight.clamp(140.0, 500.0),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: _buildBottomPanel(pinned: false),
            ),
          ),
        // In a tab the status bar's button opens it; elsewhere this one.
        if (!_drawerOpen && _ownsDrawer)
          Positioned(
            left: 8,
            bottom: 8,
            child: Tooltip(
              tooltip: (context) => const TooltipContainer(child: Text('Content Drawer')),
              child: Container(
                decoration: BoxDecoration(
                  color: EditorColors.cardHeader.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border, width: 0.8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: GhostButton(
                  key: const ValueKey('sub_editor_content_drawer_btn'),
                  density: ButtonDensity.compact,
                  onPressed: () => _drawer.setOpen(true),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.folder, size: 12, color: EditorColors.primary),
                      SizedBox(width: 4),
                      Text('Content Drawer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDroppableChild(Widget content) {
    if (!_resolveContentDroppable()) return content;

    return DragTarget<RealAssetInfo>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        widget.onAssetDropped?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (candidateData.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: EditorColors.primary.withValues(alpha: 0.6), width: 2),
                      color: EditorColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel({required bool pinned}) {
    return Container(
      color: EditorColors.card,
      child: Column(
        children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: EditorColors.sidebar,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EditorTabStyle.stripBottomLine(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: EditorTabStyle.decoration(active: true, content: EditorColors.rail),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.folder, size: 11, color: EditorColors.primary),
                          SizedBox(width: 5),
                          Text(
                            'Content Browser',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Tooltip(
                      tooltip: (context) => TooltipContainer(
                        child: Text(pinned ? 'Unpin: turn into a Content Drawer' : 'Pin to the layout'),
                      ),
                      child: GhostButton(
                        key: const ValueKey('sub_editor_bottom_panel_pin'),
                        density: ButtonDensity.compact,
                        onPressed: () => _drawer.setPinned(!pinned),
                        child: Icon(
                          pinned ? LucideIcons.pin : LucideIcons.pinOff,
                          size: 11,
                          color: pinned ? EditorColors.primary : EditorColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (!pinned)
                      Tooltip(
                        tooltip: (context) => const TooltipContainer(child: Text('Close Drawer')),
                        child: GhostButton(
                          key: const ValueKey('sub_editor_bottom_drawer_close'),
                          density: ButtonDensity.compact,
                          onPressed: () => _drawer.setOpen(false),
                          child: const Icon(LucideIcons.x, size: 11, color: EditorColors.mutedForeground),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ContentBrowserWidget(
              viewModel: widget.editorViewModel,
            ),
          ),
        ],
      ),
    );
  }
}
