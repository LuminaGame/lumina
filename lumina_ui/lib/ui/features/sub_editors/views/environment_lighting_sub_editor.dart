import 'dart:async';
import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, RealAssetInfo;

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

part 'environment_lighting_sub_editor/right_panel.dart';
part 'environment_lighting_sub_editor/shared.dart';
part 'environment_lighting_sub_editor/sun_gizmo.dart';
part 'environment_lighting_sub_editor/sun_panel.dart';

/// Environment Lighting mixer: sun + time of day, sky/IBL, height
/// fog and post-process controls that drive a real lumina world in the
/// viewport and persist into the level's environment actors.
class EnvironmentLightingSubEditor extends StatefulWidget {
  final String assetName;
  final EditorViewModel? editorViewModel;
  final EnvironmentLightingViewModel? viewModel;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  const EnvironmentLightingSubEditor({
    super.key,
    required this.assetName,
    this.editorViewModel,
    this.viewModel,
    this.onBind,
    this.onClose,
  });

  @override
  State<EnvironmentLightingSubEditor> createState() => _EnvironmentLightingSubEditorState();
}

class _EnvironmentLightingSubEditorState extends State<EnvironmentLightingSubEditor> {
  EnvironmentLightingViewModel? _vm;
  bool _ownsVm = false;

  @override
  void initState() {
    super.initState();
    final editor = widget.editorViewModel ?? widget.viewModel?.editor;
    if (widget.viewModel != null) {
      _vm = widget.viewModel;
    } else if (editor != null) {
      _vm = EnvironmentLightingViewModel(editor: editor);
      _ownsVm = true;
    }
    final vm = _vm;
    if (vm != null) {
      vm.addListener(_onVmChanged);
      widget.onBind?.call(vm, vm.save, () => vm.isDirty);
      if (vm.isOpened) return;
      // open() creates the level's environment actors and marks the level
      // dirty (EditorViewModel.notifyListeners): defer past this build.
      scheduleMicrotask(() {
        if (mounted) vm.open();
      });
    }
  }

  /// The mixer's view model (tests reach the live instance through the state).
  @visibleForTesting
  EnvironmentLightingViewModel? get viewModelForTest => _vm;

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
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
          title: const Text('Unsaved Environment Changes'),
          content: Text('Save the environment of "${vm.editor.activeLevelName}" before closing?'),
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
                'The Environment mixer edits the open level — open a project first.',
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 272, child: _SunPanel(vm: vm)),
              Expanded(child: _viewport(vm)),
              SizedBox(width: 292, child: _RightPanel(vm: vm)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(EnvironmentLightingViewModel? vm) {
    return SubEditorToolbar(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('ENVIRONMENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
const SizedBox(width: 8),
Text(
            vm != null ? '${vm.editor.activeLevelName} — Atmosphere Mixer' : widget.assetName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
if (vm != null && vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('env_dirty_indicator'),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
            ),
          ],
          ])),
          const SizedBox(width: 10),
          if (vm != null)
            Text(
              vm.isPreviewAttached ? 'Preview: live lumina world' : 'Preview: waiting for renderer',
              key: const ValueKey('env_preview_status'),
              style: TextStyle(
                fontSize: 8,
                color: vm.isPreviewAttached ? EditorColors.logSuccess : EditorColors.mutedForeground,
              ),
            ),
          const Spacer(),
          if (vm != null) ...[
            OutlineButton(
              key: const ValueKey('env_reset'),
              onPressed: vm.resetToDefaults,
              child: const Text('Reset to Defaults', style: TextStyle(fontSize: 9)),
            ),
            const SizedBox(width: 6),
            PrimaryButton(
              key: const ValueKey('env_save'),
              onPressed: () => vm.save(),
              child: const Text('Save', style: TextStyle(fontSize: 9)),
            ),
          ],
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            SubEditorToolbarClose(child: GhostButton(
              onPressed: _handleClose,
              child: const Icon(LucideIcons.x, size: 14),
            )),
          ]
      ],
    );
  }

  Widget _viewport(EnvironmentLightingViewModel vm) {
    final s = vm.state;
    final skyLabel = s.skyMode == EnvironmentSkyMode.color
        ? 'Sky: Color ${s.skyColorHex}'
        : 'Sky: HDRI ${s.skyEnvironmentAssetPath?.split('/').last ?? '(none)'}';
    return SubEditor3DViewport(
      title: 'Environment',
      showShapeSelector: false,
      yUpCamera: true,
      initialCameraDistance: 900.0,
      statsLabel: vm.isPreviewAttached
          ? 'Level meshes: ${vm.preview.meshActorCount}  ·  Sun ${s.sunIntensityLux.round()} lx  ·  Renderer: Filament C++ via lumina'
          : 'Renderer: Filament C++ via lumina (starting)',
      onPreviewWorldReady: vm.attachPreview,
      onPreviewWorldDisposing: vm.detachPreview,
      overlayHUD: Positioned.fill(
        child: Stack(
          children: [
            Positioned(
              top: 40,
              left: 8,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('env_hud'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Text(
                    '${vm.timeLabel}  ·  Sun ${s.sunElevationDeg.toStringAsFixed(1)}° / ${s.sunAzimuthDeg.toStringAsFixed(1)}°  ·  $skyLabel',
                    style: const TextStyle(fontSize: 9, color: Colors.amber, fontFamily: EditorTypography.monoFamily),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 36,
              child: SunGizmo(
                key: const ValueKey('env_sun_gizmo'),
                elevationDeg: s.sunElevationDeg,
                azimuthDeg: s.sunAzimuthDeg,
                sunColor: vm.effectiveSunColor,
                onDrag: (az, el) => vm.setSunFromGizmo(az, el, commit: false),
                onDragEnd: () => vm.setSunFromGizmo(vm.state.sunAzimuthDeg, vm.state.sunElevationDeg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
