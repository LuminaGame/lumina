import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorSlot;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/quality_settings_popover.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart' show AssetType;
import 'package:lumina_ui/ui/features/main_editor/services/standalone_game_runner.dart' show StandaloneState;
import 'package:lumina_ui/ui/features/main_editor/services/android_device_runner.dart' show AndroidRunState;
import 'package:lumina_ui/ui/features/main_editor/views/play_on_device_menu.dart';
import 'package:lumina_ui/ui/features/main_editor/services/snap_service.dart';
import 'package:lumina_ui/ui/features/main_editor/views/editor_slot_bar.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_priority_row.dart';

/// The frame stats the toolbar shows: while Play runs,
/// the frame rate and frame time are the running `LuminaWorld`'s own
/// (`LuminaWorld.frameRate` / `lastFrameTimeMs`, what the `Get Frame Rate`
/// and `Get Frame Time` nodes read), so the editor and a Blueprint's FPS
/// counter agree; otherwise the editor viewport's measured frames.
class ToolbarFrameStats {
  final double fps;
  final double frameMs;
  final double cpuMs;
  final double gpuMs;

  /// True when [fps] and [frameMs] come from the Play world.
  final bool fromWorld;

  const ToolbarFrameStats({required this.fps, required this.frameMs, required this.cpuMs, required this.gpuMs, required this.fromWorld});

  static ToolbarFrameStats of(EditorViewModel vm) {
    final world = vm.pieController.isPlaying ? vm.pieController.game?.world : null;
    if (world != null && world.frameRate > 0) {
      return ToolbarFrameStats(fps: world.frameRate, frameMs: world.lastFrameTimeMs, cpuMs: vm.cpuMs, gpuMs: vm.gpuMs, fromWorld: true);
    }
    return ToolbarFrameStats(fps: vm.fps, frameMs: vm.fps > 0 ? 1000.0 / vm.fps : 0.0, cpuMs: vm.cpuMs, gpuMs: vm.gpuMs, fromWorld: false);
  }

  /// `Tris: 1.2K  GPU: --  CPU: 1.2ms  60 FPS` (the stat strip), with
  /// `Meshes: 12/2000` in front while the level's meshes still stream in.
  String label(int triangles, {int meshesLoaded = 0, int meshesToLoad = 0}) =>
      '${meshesToLoad > meshesLoaded ? 'Meshes: $meshesLoaded/$meshesToLoad  ' : ''}'
      'Tris: $triangles  GPU: ${gpuMs < 0 ? '--' : gpuMs.toStringAsFixed(1)}ms  CPU: ${cpuMs.toStringAsFixed(1)}ms  ${fps.round()} FPS';
}

class ToolbarWidget extends StatefulWidget {
  final EditorViewModel viewModel;

  const ToolbarWidget({super.key, required this.viewModel});

  @override
  State<ToolbarWidget> createState() => _ToolbarWidgetState();
}

class _ToolbarWidgetState extends State<ToolbarWidget> {
  /// The left groups' horizontal scroll (a narrow window).
  final ScrollController _leftScroll = ScrollController();

  @override
  void dispose() {
    _leftScroll.dispose();
    super.dispose();
  }

  final GlobalKey _litKey = GlobalKey();
  final GlobalKey _cameraKey = GlobalKey();
  final GlobalKey _showKey = GlobalKey();
  final GlobalKey _playModeKey = GlobalKey();
  final GlobalKey _blueprintsKey = GlobalKey();

  /// Blueprints ▸ (the level toolbar menu): Open
  /// Level Blueprint, and the project's Blueprint classes to open.
  void _showBlueprintsMenu(EditorViewModel vm) {
    final box = _blueprintsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final classes = [
      for (final a in vm.realAssets)
        if (a.type == AssetType.actor && a.relativePath.endsWith('.lmas')) a,
    ]..sort((a, b) => a.fileName.compareTo(b.fileName));
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: Offset(offset.dx, offset.dy + box.size.height + 2),
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('blueprints_open_level_blueprint'),
            leading: const Icon(LucideIcons.map, size: 12),
            trailing: const Text('Ctrl+Shift+B', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            onPressed: (ctx) => vm.commands.execute('edit.levelBlueprint'),
            child: Text('Open Level Blueprint (${vm.activeLevelName})', style: const TextStyle(fontSize: 10)),
          ),
          const MenuDivider(),
          const MenuLabel(child: Text('Blueprint Classes', style: TextStyle(fontSize: 9))),
          if (classes.isEmpty)
            const MenuButton(enabled: false, child: Text('No Blueprint classes in the project', style: TextStyle(fontSize: 10))),
          for (final a in classes)
            MenuButton(
              key: ValueKey('blueprints_class_${a.relativePath}'),
              leading: const Icon(LucideIcons.fileCode, size: 12),
              onPressed: (ctx) => vm.openSubEditorTab('Blueprint', asset: a),
              child: Text(a.fileName.replaceAll('.lmas', ''), style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  /// Play's modes: in the level viewport (PIE), the
  /// project built and run as its own process, or (with an Android SDK) on an
  /// Android device or emulator, listed afresh each time the menu opens.
  void _showPlayModes(EditorViewModel vm) {
    final box = _playModeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final devices = vm.androidDevices;
    if (devices.available) unawaited(devices.refresh());
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: Offset(offset.dx, offset.dy + box.size.height + 2),
      builder: (context) => ListenableBuilder(
        listenable: devices,
        builder: (context, _) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('play_mode_viewport'),
            enabled: !vm.isPlaying,
            onPressed: (ctx) {
              vm.commands.execute('debug.togglePie');
            },
            child: const Text('Selected Viewport', style: TextStyle(fontSize: 10)),
          ),
          MenuButton(
            key: const ValueKey('play_mode_standalone'),
            enabled: !vm.standalone.isActive,
            onPressed: (ctx) {
              vm.commands.execute('debug.playStandalone');
            },
            child: const Text('Play Standalone', style: TextStyle(fontSize: 10)),
          ),
          ...playOnDeviceMenuItems(
            list: devices,
            runActive: vm.androidRunner?.isActive ?? false,
            onChoose: (device) => unawaited(vm.playOnAndroidDevice(device)),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Container(
      height: 36,
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // The right block (end-slot buttons, Quality) always fits;
      // the frame stats give way first, then the tool groups scroll.
      child: ToolbarPriorityRow(
            // A thin, always-visible bar shows that more tools sit to the
            // right when they do not fit; drag it or Shift+wheel.
            leading: RawScrollbar(
              controller: _leftScroll,
              thumbVisibility: true,
              thickness: 3,
              radius: const Radius.circular(2),
              thumbColor: EditorColors.mutedForeground.withValues(alpha: 0.5),
              child: SingleChildScrollView(
              key: const ValueKey('toolbar_left_scroll'),
              controller: _leftScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Transform Tool Buttons (Select, Translate, Rotate, Scale)
                  _ToolBtn(
                    icon: LucideIcons.mousePointer,
                    active: vm.activeTool == 'select',
                    onTap: () => vm.setActiveTool('select'),
                  ),
                  _ToolBtn(
                    icon: LucideIcons.move,
                    active: vm.activeTool == 'translate',
                    onTap: () => vm.setActiveTool('translate'),
                  ),
                  _ToolBtn(
                    icon: LucideIcons.rotateCcw,
                    active: vm.activeTool == 'rotate',
                    onTap: () => vm.setActiveTool('rotate'),
                  ),
                  _ToolBtn(
                    icon: LucideIcons.maximize2,
                    active: vm.activeTool == 'scale',
                    onTap: () => vm.setActiveTool('scale'),
                  ),

                  const VerticalDivider(width: 16),
                  _SnapCluster(vm),
                  const VerticalDivider(width: 16),

                  // Simulation Control Buttons (Play, Pause, Stop PIE)
                  // Stable keys: the title bar's window controls
                  // draw the same Lucide glyphs (maximize is a square), so finding these
                  // buttons by icon hits the window instead.
                  GhostButton(
                    key: const ValueKey('toolbar_play'),
                    onPressed: () => vm.commands.execute('debug.togglePie'),
                    child: Icon(
                      vm.isPlaying ? LucideIcons.square : LucideIcons.play,
                      size: 14,
                      color: vm.isPlaying ? Colors.red : Colors.green,
                    ),
                  ),
                  KeyedSubtree(
                    key: const ValueKey('play_mode_dropdown'),
                    child: GhostButton(
                      key: _playModeKey,
                      onPressed: () => _showPlayModes(vm),
                      child: const Icon(LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground),
                    ),
                  ),
                  GhostButton(
                    key: const ValueKey('toolbar_pause'),
                    onPressed: (vm.commands.byId('debug.pausePie')?.canExecute() ?? false) ? () => vm.commands.execute('debug.pausePie') : null,
                    child: Icon(
                      LucideIcons.pause,
                      size: 14,
                      color: vm.isPaused ? Colors.amber : EditorColors.foreground,
                    ),
                  ),
                  GhostButton(
                    key: const ValueKey('toolbar_stop'),
                    onPressed: (vm.commands.byId('debug.stopPie')?.canExecute() ?? false) ? () => vm.commands.execute('debug.stopPie') : null,
                    child: Icon(
                      LucideIcons.square,
                      size: 14,
                      color: vm.standalone.isActive || (vm.androidRunner?.isActive ?? false)
                          ? EditorColors.destructive
                          : EditorColors.mutedForeground,
                    ),
                  ),
                  // Play Standalone's state, like PIE's.
                  if (vm.standalone.isActive)
                    Padding(
                      key: const ValueKey('standalone_status'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlineBadge(
                        child: Text(
                          vm.standalone.state == StandaloneState.building ? 'STANDALONE · BUILDING' : 'STANDALONE · RUNNING',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary),
                        ),
                      ),
                    ),
                  // Play on Device's state and device.
                  if (vm.androidRunner?.isActive ?? false)
                    Padding(
                      key: const ValueKey('play_on_device_status'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlineBadge(
                        child: Text(
                          '${vm.androidRunner!.device?.name ?? 'DEVICE'} · ${switch (vm.androidRunner!.state) {
                            AndroidRunState.booting => 'BOOTING',
                            AndroidRunState.building => 'BUILDING',
                            AndroidRunState.installing => 'INSTALLING',
                            AndroidRunState.running => 'RUNNING',
                            AndroidRunState.idle => '',
                          }}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary),
                        ),
                      ),
                    ),
                  // Step and Eject/Possess only mean anything mid-session, so they show
                  // up when there is one. They used to live in a second PIE cluster
                  // further along the toolbar; this is the single group now.
                  if (vm.pieController.isPlaying && vm.pieController.isPaused)
                    GhostButton(
                      onPressed: () => vm.pieController.step(),
                      child: const Icon(
                        LucideIcons.stepForward,
                        size: 14,
                        color: EditorColors.foreground,
                      ),
                    ),
                  if (vm.pieController.isPlaying)
                    GhostButton(
                      onPressed: () => vm.pieController.isEjected
                          ? vm.pieController.possess()
                          : vm.pieController.eject(),
                      child: Icon(
                        LucideIcons.camera,
                        size: 14,
                        color: vm.pieController.isEjected
                            ? Colors.amber
                            : EditorColors.foreground,
                      ),
                    ),

                  const VerticalDivider(width: 16),

                  // Viewport Shading Mode Dropdown Button
                  GestureDetector(
                    key: _litKey,
                    onTap: () {
                      final renderBox = _litKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final offset = renderBox.localToGlobal(Offset.zero);
                        final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
                        showDropdown(
                          context: context,
                          // An explicit position is where the menu opens; following the
                          // anchor widget would drag it to that widget's bottom centre.
                          follow: false,
                          // Top-left corner at the point, as editor context menus open.
                          alignment: Alignment.topLeft,
                          anchorAlignment: Alignment.topLeft,
                          position: position,
                          builder: (context) => DropdownMenu(
                            children: [
                              MenuButton(
                                onPressed: (ctx) { vm.setViewMode('Lit'); },
                                child: const Text('Lit', style: TextStyle(fontSize: 10)),
                              ),
                              MenuButton(
                                onPressed: (ctx) { vm.setViewMode('Unlit'); },
                                child: const Text('Unlit', style: TextStyle(fontSize: 10)),
                              ),
                              MenuButton(
                                onPressed: (ctx) { vm.setViewMode('Wireframe'); },
                                child: const Text('Wireframe', style: TextStyle(fontSize: 10)),
                              ),
                              const MenuDivider(),
                              MenuButton(
                                subMenu: [
                                  'Base Color', 'Opacity', 'Roughness', 'Metallic', 'Emissive', 'Normal'
                                ].map((buffer) => MenuButton(
                                  onPressed: (ctx) { 
                                    vm.setBufferVisualization(buffer); 
                                    vm.setViewMode('Buffer');
                                  },
                                  child: Text(buffer, style: const TextStyle(fontSize: 10)),
                                )).toList(),
                                child: const Text('Buffer Visualization', style: TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: EditorColors.cardHeader,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(vm.viewMode, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                            const SizedBox(width: 6),

                  // Show Flags Dropdown Button
                  GestureDetector(
                    key: _showKey,
                    onTap: () {
                      final renderBox = _showKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final offset = renderBox.localToGlobal(Offset.zero);
                        final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
                        showDropdown(
                          context: context,
                          // An explicit position is where the menu opens; following the
                          // anchor widget would drag it to that widget's bottom centre.
                          follow: false,
                          // Top-left corner at the point, as editor context menus open.
                          alignment: Alignment.topLeft,
                          anchorAlignment: Alignment.topLeft,
                          position: position,
                          builder: (context) => DropdownMenu(
                            children: [
                              'Grid', 'Transform Gizmo', 'Selection Bounds', 
                              'Collision', 'Actor Icons & Labels', 'Ground Drop Shadows'
                            ].map((flag) => MenuButton(
                              onPressed: (ctx) {
                                vm.toggleShowFlag(flag);
                                // don't pop because it's a multi-select
                              },
                              trailing: vm.showFlags[flag] == true ? const Icon(LucideIcons.check, size: 12) : null,
                              child: Text(flag, style: const TextStyle(fontSize: 10)),
                            )).toList(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: EditorColors.cardHeader,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Row(
                        children: [
                          const Text('Show', style: TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),

                  // Camera Projection Dropdown Button
                  GestureDetector(
                    key: _cameraKey,
                    onTap: () {
                      final renderBox = _cameraKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final offset = renderBox.localToGlobal(Offset.zero);
                        final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
                        showDropdown(
                          context: context,
                          // An explicit position is where the menu opens; following the
                          // anchor widget would drag it to that widget's bottom centre.
                          follow: false,
                          // Top-left corner at the point, as editor context menus open.
                          alignment: Alignment.topLeft,
                          anchorAlignment: Alignment.topLeft,
                          position: position,
                          builder: (context) => DropdownMenu(
                            children: ['Perspective', 'Top', 'Bottom', 'Left', 'Right', 'Front', 'Back'].map((mode) => MenuButton(
                              onPressed: (ctx) { vm.setCameraMode(mode); },
                              child: Text(mode, style: const TextStyle(fontSize: 10)),
                            )).toList(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: EditorColors.cardHeader,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(vm.cameraMode, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Blueprints ▸ Open Level Blueprint, right of
                  // the Perspective dropdown.
                  Tooltip(
                    tooltip: (context) => TooltipContainer(child: Text('Blueprints: open the Level Blueprint of ${vm.activeLevelName} or a Blueprint class')),
                    child: GestureDetector(
                      key: _blueprintsKey,
                      onTap: () => _showBlueprintsMenu(vm),
                      child: Container(
                        key: const ValueKey('toolbar_blueprints'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: EditorColors.cardHeader,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: EditorColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.workflow, size: 11, color: EditorColors.primary),
                            SizedBox(width: 4),
                            Text('Blueprints', style: TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Plugin buttons right of Blueprints (MiniAI's ✦ AI).
                  EditorSlotBar(registry: vm.extensionRegistry, slot: EditorSlot.levelToolbarAfterBlueprints, leadingGap: 6),
                ],
              ),
            ),
            ),
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (vm.isImporting) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: EditorColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EditorColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EditorColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vm.importStatusMessage.isNotEmpty ? vm.importStatusMessage : 'Importing...',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Performance Telemetry Counter
            // Updates every rendered frame: its own listenable and its own
            // layer, or each update rebuilds and repaints the editor.
            Flexible(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: vm.frameStats,
                  builder: (context, _) => Text(
                    ToolbarFrameStats.of(vm).label(
                      vm.totalTriangles,
                      meshesLoaded: vm.meshesLoading ? vm.meshesLoaded : 0,
                      meshesToLoad: vm.meshesLoading ? vm.meshesToLoad : 0,
                    ),
                    key: const ValueKey('toolbar_frame_stats'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: EditorTypography.monoFamily,
                      color: EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Plugin buttons of the toolbar-end slot, before Quality.
            EditorSlotBar(registry: vm.extensionRegistry, slot: EditorSlot.levelToolbarEnd, trailingGap: 8),

            // Scalability Quality Settings Trigger Button (Opens on Root Overlay above all viewports)
            GhostButton(
              onPressed: () => _showQualitySettingsModal(context, vm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    Text(
                      'Quality: ${vm.qualityPreset.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(LucideIcons.chevronDown, size: 10, color: Colors.amber),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySettingsModal(BuildContext context, EditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return QualitySettingsPopover(
          viewModel: vm,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GhostButton(
        onPressed: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? EditorColors.primary.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: active ? Border.all(color: EditorColors.primary) : null,
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? EditorColors.primary : EditorColors.foreground,
          ),
        ),
      ),
    );
  }
}


class _SnapCluster extends StatelessWidget {
  final EditorViewModel vm;
  const _SnapCluster(this.vm);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SnapToggleWithMenu(
          key: const Key("toggle_translate_snap"),
          icon: LucideIcons.magnet,
          active: vm.translateSnapEnabled,
          onToggle: () => vm.updateTranslateSnapEnabled(!vm.translateSnapEnabled),
          value: vm.translateSnapStep,
          options: SnapService.translateSteps,
          format: SnapService.formatLength,
          onChanged: vm.updateTranslateSnapStep,
        ),
        _SnapToggleWithMenu(
          key: const Key("toggle_rotate_snap"),
          icon: LucideIcons.rotateCcw,
          active: vm.rotateSnapEnabled,
          onToggle: () => vm.updateRotateSnapEnabled(!vm.rotateSnapEnabled),
          value: vm.rotateSnapStep,
          options: SnapService.rotateSteps,
          onChanged: vm.updateRotateSnapStep,
        ),
        _SnapToggleWithMenu(
          key: const Key("toggle_scale_snap"),
          icon: LucideIcons.maximize2,
          active: vm.scaleSnapEnabled,
          onToggle: () => vm.updateScaleSnapEnabled(!vm.scaleSnapEnabled),
          value: vm.scaleSnapStep,
          options: SnapService.scaleSteps,
          onChanged: vm.updateScaleSnapStep,
        ),
        const VerticalDivider(width: 16),
        _GridPopover(key: const Key("toggle_grid_snap"), vm: vm),
      ],
    );
  }
}

class _SnapToggleWithMenu extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onToggle;
  final double value;
  final List<double> options;
  final ValueChanged<double> onChanged;

  /// How a step reads (e.g. with its unit); plain numbers by default.
  final String Function(double)? format;

  const _SnapToggleWithMenu({super.key,
    this.format,
    required this.icon,
    required this.active,
    required this.onToggle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_SnapToggleWithMenu> createState() => _SnapToggleWithMenuState();
}

class _SnapToggleWithMenuState extends State<_SnapToggleWithMenu> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolBtn(
          icon: widget.icon,
          active: widget.active,
          onTap: widget.onToggle,
        ),
        GestureDetector(
          key: _key,
          onTap: () {
            final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero);
              final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
              showDropdown(
                context: context,
                // An explicit position is where the menu opens; following the
                // anchor widget would drag it to that widget's bottom centre.
                follow: false,
                // Top-left corner at the point, as editor context menus open.
                alignment: Alignment.topLeft,
                anchorAlignment: Alignment.topLeft,
                position: position,
                builder: (context) => DropdownMenu(
                  children: widget.options.map((step) {
                    return MenuButton(
                      onPressed: (ctx) {
                        widget.onChanged(step);
                      },
                      trailing: widget.value == step ? const Icon(LucideIcons.check, size: 12) : null,
                      child: Text(widget.format?.call(step) ?? step.toString(), style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: EditorColors.cardHeader,
            ),
            child: Text(widget.format?.call(widget.value) ?? widget.value.toString(), style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _GridPopover extends StatefulWidget {
  final EditorViewModel vm;
  const _GridPopover({super.key, required this.vm});

  @override
  State<_GridPopover> createState() => _GridPopoverState();
}

class _GridPopoverState extends State<_GridPopover> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolBtn(
          icon: LucideIcons.layoutGrid,
          active: widget.vm.gridVisible,
          onTap: () => widget.vm.updateGridVisible(!widget.vm.gridVisible),
        ),
        GestureDetector(
          key: _key,
          onTap: () {
            final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero);
              final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
              showDropdown(
                context: context,
                // An explicit position is where the menu opens; following the
                // anchor widget would drag it to that widget's bottom centre.
                follow: false,
                // Top-left corner at the point, as editor context menus open.
                alignment: Alignment.topLeft,
                anchorAlignment: Alignment.topLeft,
                position: position,
                builder: (context) => DropdownMenu(
                  children: SnapService.gridSteps.map((step) {
                    return MenuButton(
                      onPressed: (ctx) {
                        widget.vm.updateGridStep(step);
                      },
                      trailing: widget.vm.editorGridStep == step ? const Icon(LucideIcons.check, size: 12) : null,
                      child: Text(SnapService.formatLength(step), style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: EditorColors.cardHeader,
            ),
            child: const Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
          ),
        ),
      ],
    );
  }
}
