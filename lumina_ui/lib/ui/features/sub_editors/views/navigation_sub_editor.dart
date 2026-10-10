import 'dart:async';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaUnits;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/navigation_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

part 'navigation_sub_editor/left_panel.dart';
part 'navigation_sub_editor/right_panel.dart';

/// Navigation sub-editor: bounds volumes, agent / grid parameters,
/// a real `LuminaNavigationSystem` bake with a walkable-cell overlay and a
/// click-driven A* path tester. The backend is a uniform walkable grid with
/// 8-connected A* — not Recast — and the UI says so.
class NavigationSubEditor extends StatefulWidget {
  final String assetName;
  final EditorViewModel? editorViewModel;
  final NavigationEditorViewModel? viewModel;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  const NavigationSubEditor({
    super.key,
    required this.assetName,
    this.editorViewModel,
    this.viewModel,
    this.onBind,
    this.onClose,
  });

  @override
  State<NavigationSubEditor> createState() => _NavigationSubEditorState();
}

class _NavigationSubEditorState extends State<NavigationSubEditor> {
  NavigationEditorViewModel? _vm;
  bool _ownsVm = false;
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _maskController = TextEditingController();
  final FocusNode _maskFocus = FocusNode(debugLabel: 'nav_layer_mask');

  @override
  void initState() {
    super.initState();
    final editor = widget.editorViewModel ?? widget.viewModel?.editor;
    if (widget.viewModel != null) {
      _vm = widget.viewModel;
    } else if (editor != null) {
      _vm = NavigationEditorViewModel(editor: editor);
      _ownsVm = true;
    }
    final vm = _vm;
    if (vm != null) {
      vm.addListener(_onVmChanged);
      widget.onBind?.call(vm, vm.save, () => vm.isDirty);
      _maskController.text = vm.walkableLayerMaskHex;
      if (!vm.isOpened) {
        // open() may run a build and touch editor state: defer past this build.
        scheduleMicrotask(() {
          if (mounted) vm.open();
        });
      }
    }
  }

  /// The view model (tests / smoke reach the live instance through the state).
  @visibleForTesting
  NavigationEditorViewModel? get viewModelForTest => _vm;

  void _onVmChanged() {
    if (!mounted) return;
    final vm = _vm;
    if (vm != null && !_maskFocus.hasFocus && _maskController.text != vm.walkableLayerMaskHex) {
      _maskController.text = vm.walkableLayerMaskHex;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    _filterController.dispose();
    _maskController.dispose();
    _maskFocus.dispose();
    if (_ownsVm) _vm?.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    final vm = _vm;
    if (vm != null && vm.isDirty) {
      showOverlay(
        context,
        const DialogConfiguration(),
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsaved Navigation Changes'),
          content: Text('Save the navigation settings of "${vm.editor.activeLevelName}" before closing?'),
          actions: [
            GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
            DestructiveButton(
              child: const Text('Discard'),
              onPressed: () {
                closeOverlay(dialogContext);
                widget.onClose?.call();
              },
            ),
            PrimaryButton(
              child: const Text('Save'),
              onPressed: () async {
                closeOverlay(dialogContext);
                await vm.save();
                widget.onClose?.call();
              },
            ),
          ],
        ),
      );
      return;
    }
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return Column(
        children: [
          _toolbar(null),
          const Expanded(
            child: Center(
              child: Text(
                'The Navigation editor bakes the open level — open a project first.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _toolbar(vm),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final leftWidth = wide ? 230.0 : 190.0;
              final rightWidth = wide ? 280.0 : 230.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: leftWidth, child: _LeftPanel(vm: vm, filterController: _filterController)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _viewport(vm)),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: rightWidth,
                    child: _RightPanel(vm: vm, maskController: _maskController, maskFocus: _maskFocus),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        _bottomBar(vm),
      ],
    );
  }

  // ---------------------------------------------------------------- toolbar

  Widget _toolbar(NavigationEditorViewModel? vm) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('NAVIGATION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          const SizedBox(width: 8),
          Text(
            vm != null ? '${vm.editor.activeLevelName} — Navigation' : widget.assetName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          if (vm != null && vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('nav_dirty_indicator'),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
            ),
          ],
          const SizedBox(width: 10),
          const OutlineBadge(
            child: Text(NavigationEditorViewModel.backendLabel, style: TextStyle(fontSize: 8)),
          ),
          const Spacer(),
          if (vm != null) ...[
            Text(
              vm.isPreviewAttached ? 'Preview: live lumina world' : 'Preview: waiting for renderer',
              key: const ValueKey('nav_preview_status'),
              style: TextStyle(fontSize: 8, color: vm.isPreviewAttached ? EditorColors.logSuccess : EditorColors.mutedForeground),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              key: const ValueKey('nav_save'),
              onPressed: () => vm.save(),
              child: const Text('Save', style: TextStyle(fontSize: 9)),
            ),
          ],
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GhostButton(onPressed: _handleClose, child: const Icon(LucideIcons.x, size: 14)),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- viewport

  Widget _viewport(NavigationEditorViewModel vm) {
    final build = vm.lastBuild;
    final badge = vm.hudPathBadge;
    return SubEditor3DViewport(
      title: 'Navigation',
      showShapeSelector: false,
      yUpCamera: true,
      initialCameraDistance: 1600.0,
      statsLabel: vm.isPreviewAttached
          ? 'Level meshes: ${vm.preview.meshActorCount}  ·  Overlay quads: ${vm.preview.walkableQuadCount + vm.preview.blockedQuadCount}  ·  Renderer: Filament C++ via lumina'
          : 'Renderer: Filament C++ via lumina (starting)',
      onPreviewWorldReady: vm.attachPreview,
      onPreviewWorldDisposing: vm.detachPreview,
      floorTapPlaneY: vm.floorTapPlaneCm,
      onFloorTap: vm.pathTesterMode ? (p) => vm.placePathPoint(Vector3(p.x, p.y, p.z)) : null,
      overlayHUD: Positioned.fill(
        child: Stack(
          children: [
            // Real values only: hidden until a build exists.
            if (build != null)
              Positioned(
                top: 40,
                left: 8,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('nav_hud'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EditorColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(vm.hudWalkableLabel, style: const TextStyle(fontSize: 9, color: EditorColors.logSuccess, fontWeight: FontWeight.bold)),
                        Text(vm.hudGridLabel, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
                        if (vm.hudPathLabel.isNotEmpty)
                          Text(vm.hudPathLabel, style: const TextStyle(fontSize: 9, color: EditorColors.axisZ)),
                        if (vm.isStale)
                          const Text('Grid stale — rebuild', style: TextStyle(fontSize: 8, color: EditorColors.logWarning)),
                      ],
                    ),
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: badge == 'No path'
                        ? DestructiveBadge(key: const ValueKey('nav_path_badge'), child: Text(badge))
                        : SecondaryBadge(key: const ValueKey('nav_path_badge'), child: Text(badge)),
                  ),
                ),
              ),
            Positioned(
              top: 40,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Walkable grid', style: TextStyle(fontSize: 9)),
                    const SizedBox(width: 6),
                    Switch(
                      key: const ValueKey('nav_overlay_switch'),
                      value: vm.overlayVisible,
                      onChanged: vm.setOverlayVisible,
                    ),
                    const SizedBox(width: 10),
                    Toggle(
                      key: const ValueKey('nav_path_mode'),
                      value: vm.pathTesterMode,
                      onChanged: vm.setPathTesterMode,
                      child: const Text('Path Tester', style: TextStyle(fontSize: 9)),
                    ),
                    const SizedBox(width: 6),
                    GhostButton(
                      key: const ValueKey('nav_clear_path'),
                      onPressed: vm.pathStart == null ? null : vm.clearPath,
                      child: const Text('Clear Path', style: TextStyle(fontSize: 9)),
                    ),
                  ],
                ),
              ),
            ),
            if (vm.pathTesterMode)
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      vm.pathStart == null
                          ? 'Path tester: click the floor to drop the Start flag'
                          : vm.pathGoal == null
                              ? 'Click the floor to drop the Goal flag'
                              : 'Click again to move the nearer flag',
                      style: const TextStyle(fontSize: 9, color: EditorColors.logInfo),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bottom bar

  Widget _bottomBar(NavigationEditorViewModel vm) {
    final progress = vm.isBuilding ? null : (vm.lastBuild == null ? 0.0 : 1.0);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          SizedBox(width: 90, child: LinearProgressIndicator(value: progress, minHeight: 4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vm.lastBuildLabel,
              key: const ValueKey('nav_status_line'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8.5, color: vm.buildError != null ? EditorColors.logError : EditorColors.mutedForeground),
            ),
          ),
          if (vm.pathDebugLine.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                vm.pathDebugLine,
                key: const ValueKey('nav_path_debug'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.5, color: EditorColors.axisZ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
