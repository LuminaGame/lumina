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

// ---------------------------------------------------------------------------
// Left panel: bounds volumes
// ---------------------------------------------------------------------------

class _LeftPanel extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final TextEditingController filterController;
  const _LeftPanel({required this.vm, required this.filterController});

  @override
  Widget build(BuildContext context) {
    final selected = vm.selectedVolume;
    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text('NAV BOUNDS VOLUMES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              key: const ValueKey('nav_volume_filter'),
              controller: filterController,
              placeholder: const Text('Filter volumes…', style: TextStyle(fontSize: 9)),
              style: const TextStyle(fontSize: 9),
              onChanged: vm.setVolumeFilter,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Button.secondary(
              key: const ValueKey('nav_add_volume'),
              onPressed: vm.addBoundsVolume,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 11),
                  SizedBox(width: 4),
                  Text('Add Bounds Volume', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: vm.volumes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No NavMeshBoundsVolume in this level. Add one to define where the walkable grid is baked.',
                      style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                    ),
                  )
                : ListView(
                    children: [
                      for (final v in vm.filteredVolumes) _VolumeRow(vm: vm, volume: v, selected: selected?.id == v.id),
                    ],
                  ),
          ),
          if (selected != null) ...[
            const Divider(height: 1),
            _VolumeInspector(vm: vm, volume: selected),
          ],
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final EditorActorNode volume;
  final bool selected;
  const _VolumeRow({required this.vm, required this.volume, required this.selected});

  @override
  Widget build(BuildContext context) {
    final extent = NavMeshBoundsVolume.extentMetresOf(volume);
    return EditorContextMenu(
      items: [
        MenuButton(
          leading: const Icon(LucideIcons.locate, size: 14, color: EditorColors.accent),
          onPressed: (ctx) => vm.focusVolume(volume.id),
          child: const Text('Focus in Viewport', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.pencil, size: 14),
          onPressed: (ctx) => _showRename(context),
          child: const Text('Rename', style: TextStyle(fontSize: 10)),
        ),
        const MenuDivider(),
        MenuButton(
          leading: const Icon(LucideIcons.trash2, size: 14, color: EditorColors.destructive),
          onPressed: (ctx) => _confirmDelete(context),
          child: const Text('Delete', style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
        ),
      ],
      child: GestureDetector(
        key: ValueKey('nav_volume_row_${volume.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => vm.selectVolume(volume.id),
        onDoubleTap: () => vm.focusVolume(volume.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: selected ? EditorColors.selectionBg : null,
          child: Row(
            children: [
              const Icon(LucideIcons.box, size: 12, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  volume.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: EditorColors.foreground),
                ),
              ),
              // Compact summary in metres (the stored scale); the inspector
              // below edits the same size in cm.
              Text(
                '${_m(extent[0])}×${_m(extent[1])}×${_m(extent[2])} m',
                key: ValueKey('nav_volume_size_${volume.id}'),
                style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _m(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _showRename(BuildContext context) {
    final controller = TextEditingController(text: volume.name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Bounds Volume'),
        content: TextField(
          key: const ValueKey('nav_rename_field'),
          controller: controller,
          autofocus: true,
          onSubmitted: (v) {
            vm.renameVolume(volume.id, v);
            closeOverlay(dialogContext);
          },
        ),
        actions: [
          GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
          PrimaryButton(
            key: const ValueKey('nav_rename_confirm'),
            child: const Text('Rename'),
            onPressed: () {
              vm.renameVolume(volume.id, controller.text);
              closeOverlay(dialogContext);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bounds Volume'),
        content: Text('Delete "${volume.name}" from the level? The grid inside it will no longer be baked. (Undo restores it.)'),
        actions: [
          GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
          DestructiveButton(
            key: const ValueKey('nav_delete_confirm'),
            child: const Text('Delete'),
            onPressed: () {
              vm.deleteVolume(volume.id);
              closeOverlay(dialogContext);
            },
          ),
        ],
      ),
    );
  }
}

/// Centre / extent inputs of the selected volume, in cm along the authoring
/// X / Y / Z axes (Z up) — the same axes and numbers as the Details panel's
/// Location. Centre writes the actor location; extent writes the actor
/// scale (size in metres).
class _VolumeInspector extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final EditorActorNode volume;
  const _VolumeInspector({required this.vm, required this.volume});

  @override
  Widget build(BuildContext context) {
    final centre = volume.location;
    final extent = NavMeshBoundsVolume.extentCmOf(volume);
    const axes = ['X', 'Y', 'Z'];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(volume.name, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          const SizedBox(height: 4),
          const Text('Center (cm, Z up)', style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
          for (var i = 0; i < 3; i++)
            KeyedSubtree(
              key: ValueKey('nav_vol_center_${axes[i].toLowerCase()}'),
              child: ScrubNumericField(
                value: centre.length > i ? centre[i] : 0.0,
                defaultValue: 0.0,
                label: axes[i],
                unit: 'cm',
                fractionDigits: 1,
                onChanged: (v) => vm.setVolumeCenter(volume.id, i, v, commit: false),
                onCommit: (v) => vm.setVolumeCenter(volume.id, i, v),
                onReset: () => vm.setVolumeCenter(volume.id, i, 0.0),
              ),
            ),
          const SizedBox(height: 4),
          const Text('Extent (cm, Z up)', style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
          for (var i = 0; i < 3; i++)
            KeyedSubtree(
              key: ValueKey('nav_vol_extent_${axes[i].toLowerCase()}'),
              child: ScrubNumericField(
                value: extent.length > i ? extent[i] : 0.0,
                defaultValue: LuminaUnits.metres(NavMeshBoundsVolume.defaultExtentMetres[i]),
                label: axes[i],
                unit: 'cm',
                fractionDigits: 1,
                min: NavMeshBoundsVolume.minExtentCm,
                onChanged: (v) => vm.setVolumeExtent(volume.id, i, v, commit: false),
                onCommit: (v) => vm.setVolumeExtent(volume.id, i, v),
                onReset: () => vm.setVolumeExtent(volume.id, i, LuminaUnits.metres(NavMeshBoundsVolume.defaultExtentMetres[i])),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right panel: Agent / Grid Generation / Build
// ---------------------------------------------------------------------------

class _RightPanel extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final TextEditingController maskController;
  final FocusNode maskFocus;
  const _RightPanel({required this.vm, required this.maskController, required this.maskFocus});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text('AGENT & GRID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Accordion(
                items: [
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Agent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _agentSection(),
                  ),
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Grid Generation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _gridSection(),
                  ),
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Build', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _buildSection(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _agentSection() {
    final c = vm.config;
    final d = NavigationEditorConfig.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Agent Radius (cm) — inflates every obstacle at bake time'),
        KeyedSubtree(
          key: const ValueKey('nav_agent_radius'),
          child: SliderField(
            value: c.agentRadius,
            defaultValue: d.agentRadius,
            min: 0.0,
            max: 200.0,
            unit: 'cm',
            onChanged: (v) => vm.setAgentRadius(v, commit: false),
            onCommit: vm.setAgentRadius,
            onReset: () => vm.setAgentRadius(d.agentRadius),
          ),
        ),
        _label('Agent Height (cm) — geometry above this is overhead'),
        KeyedSubtree(
          key: const ValueKey('nav_agent_height'),
          child: SliderField(
            value: c.agentHeight,
            defaultValue: d.agentHeight,
            min: 50.0,
            max: 400.0,
            unit: 'cm',
            onChanged: (v) => vm.setAgentHeight(v, commit: false),
            onCommit: vm.setAgentHeight,
            onReset: () => vm.setAgentHeight(d.agentHeight),
          ),
        ),
        _label('Max Step Height (cm) — geometry below this is floor'),
        KeyedSubtree(
          key: const ValueKey('nav_step_height'),
          child: SliderField(
            value: c.maxStepHeight,
            defaultValue: d.maxStepHeight,
            min: 0.0,
            max: 150.0,
            unit: 'cm',
            onChanged: (v) => vm.setMaxStepHeight(v, commit: false),
            onCommit: vm.setMaxStepHeight,
            onReset: () => vm.setMaxStepHeight(d.maxStepHeight),
          ),
        ),
      ],
    );
  }

  Widget _gridSection() {
    final c = vm.config;
    final d = NavigationEditorConfig.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          'Cell Size (cm, ${NavigationEditorViewModel.formatCm(NavigationEditorConfig.minCellSize)}–'
          '${NavigationEditorViewModel.formatCm(NavigationEditorConfig.maxCellSize)})',
        ),
        KeyedSubtree(
          key: const ValueKey('nav_cell_size'),
          child: SliderField(
            value: c.cellSize,
            defaultValue: d.cellSize,
            min: NavigationEditorConfig.minCellSize,
            max: NavigationEditorConfig.maxCellSize,
            unit: 'cm',
            onChanged: (v) => vm.setCellSize(v, commit: false),
            onCommit: vm.setCellSize,
            onReset: () => vm.setCellSize(d.cellSize),
          ),
        ),
        _label('Walkable Layer Mask (hex)'),
        TextField(
          key: const ValueKey('nav_layer_mask'),
          controller: maskController,
          focusNode: maskFocus,
          style: const TextStyle(fontSize: 9.5),
          onSubmitted: (text) {
            if (!vm.setWalkableLayerMaskText(text)) {
              maskController.text = vm.walkableLayerMaskHex;
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Backend: uniform walkable grid rasterized from collision AABBs, 8-connected A* with string pulling. '
            'No Recast tiles, polygons, area costs or nav links exist in the engine.',
            style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context) {
    final can = vm.canBuild;
    final button = PrimaryButton(
      key: const ValueKey('nav_build'),
      onPressed: can ? () => vm.build() : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.hammer, size: 11),
          const SizedBox(width: 4),
          Text(vm.isBuilding ? 'Building…' : 'Build Navigation', style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        can ? button : Tooltip(tooltip: (ctx) => TooltipContainer(child: Text(vm.buildDisabledReason)), child: button),
        if (!can)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(vm.buildDisabledReason, key: const ValueKey('nav_build_reason'), style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning)),
          ),
        const SizedBox(height: 6),
        Text(vm.lastBuildLabel, key: const ValueKey('nav_last_build'), style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
        if (vm.isStale)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: OutlineBadge(child: Text('Stale — scene or settings changed', style: TextStyle(fontSize: 8))),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
              key: const ValueKey('nav_auto_rebuild'),
              value: vm.config.autoRebuild,
              onChanged: vm.setAutoRebuild,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Auto-rebuild on change (500 ms debounce)', style: TextStyle(fontSize: 9))),
          ],
        ),
      ],
    );
  }
}
