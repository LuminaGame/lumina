import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart' show AuthoringRotation, TransformGizmoModel;
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/garment_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/garment_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

part 'garment_details_panel.dart';
part 'garment_landmarks_panel.dart';
part 'garment_viewport.dart';

/// The Garment editor: a garment `.lmas` — a mesh worn on a character. The
/// left panel picks the source mesh, the reference body, a preview body,
/// the slot, the thickness and the cloth options, and edits the placement;
/// the viewport shows the body with the garment, moved, turned and resized
/// by the gizmo, and places the selected landmark with a click on the
/// garment or the body; the right panel lists the landmarks. The toolbar
/// switches the gizmo and pick modes, aligns the garment to its landmarks
/// and saves.
class GarmentSubEditor extends StatefulWidget {
  const GarmentSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
    this.showViewport = true,
  });

  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final GarmentEditorViewModel? viewModel;

  /// False in widget tests without a renderer: the centre shows a summary.
  final bool showViewport;

  @override
  State<GarmentSubEditor> createState() => GarmentSubEditorState();
}

class GarmentSubEditorState extends _GarmentEditorBase with _GarmentDetailsPanel, _GarmentLandmarksPanel, _GarmentViewport {
  @override
  late final GarmentEditorViewModel vm;
  late final bool _ownsVm;

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    vm = widget.viewModel ?? GarmentEditorViewModel(assetPath: widget.assetPath ?? widget.asset?.lmasPath ?? '');
    widget.onBind?.call(vm, vm.save, () => vm.isDirty);
    vm.addListener(_changed);
    if (!vm.isLoaded) vm.load();
  }

  @override
  void dispose() {
    vm.removeListener(_changed);
    scene.detach();
    gizmo.dispose();
    if (_ownsVm) vm.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    syncScene();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          Expanded(
            child: !vm.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : EditorIslandGround(child: ResizablePanel.horizontal(
                  dividerBuilder: EditorIslandDividers.gap,
                    children: [
                      ResizablePane(initialSize: 280, minSize: 200, maxSize: 460, child: EditorIsland(key: const ValueKey('garment_island_details'), child: detailsPanel())),
                      ResizablePane.flex(child: EditorIsland(key: const ValueKey('garment_island_viewport'), color: EditorColors.viewportBackdrop, child: viewport())),
                      ResizablePane(initialSize: 240, minSize: 180, maxSize: 420, child: EditorIsland(key: const ValueKey('garment_island_landmarks'), child: landmarksPanel())),
                    ],
                  )),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final style = AssetTypeStyle.of(AssetType.garment);
    Widget toggle(String key, IconData icon, String tip, bool on, VoidCallback onPressed) => Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(tip)),
      child: on
          ? PrimaryButton(key: ValueKey(key), density: ButtonDensity.iconDense, onPressed: onPressed, child: Icon(icon, size: 13))
          : GhostButton(key: ValueKey(key), density: ButtonDensity.iconDense, onPressed: onPressed, child: Icon(icon, size: 13)),
    );
    final moving = vm.pickMode == GarmentPickMode.none;
    return SubEditorToolbar(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(style.icon, size: 15, color: style.color),
const SizedBox(width: 8),
Text(
            widget.assetName + (vm.isDirty ? ' *' : ''),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditorColors.foreground),
          ),
          ])),
          const SizedBox(width: 8),
          Text(style.displayName, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(width: 16),
          toggle('garment_move', LucideIcons.move, 'Move the garment (W)', moving && gizmo.mode == GizmoMode.translate, () => setGizmo(GizmoMode.translate)),
          toggle('garment_rotate', LucideIcons.rotate3d, 'Rotate the garment (E)', moving && gizmo.mode == GizmoMode.rotate, () => setGizmo(GizmoMode.rotate)),
          toggle('garment_scale', LucideIcons.scale3d, 'Resize the garment (R)', moving && gizmo.mode == GizmoMode.scale, () => setGizmo(GizmoMode.scale)),
          const SizedBox(width: 10),
          toggle('garment_pick_garment', LucideIcons.shirt, 'Click on the garment to place the selected landmark', vm.pickMode == GarmentPickMode.garment,
              () => vm.setPickMode(vm.pickMode == GarmentPickMode.garment ? GarmentPickMode.none : GarmentPickMode.garment)),
          toggle('garment_pick_body', LucideIcons.personStanding, 'Click on the body to place the selected landmark', vm.pickMode == GarmentPickMode.body,
              () => vm.setPickMode(vm.pickMode == GarmentPickMode.body ? GarmentPickMode.none : GarmentPickMode.body)),
          const SizedBox(width: 10),
          OutlineButton(
            key: const ValueKey('garment_align'),
            density: ButtonDensity.compact,
            onPressed: vm.doc.landmarks.any((l) => l.isComplete) ? vm.align : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(LucideIcons.magnet, size: 12), SizedBox(width: 4), Text('Align', style: TextStyle(fontSize: 11))],
            ),
          ),
          if (vm.error != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(vm.error!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
            ),
          ],
          const Spacer(),
          if (vm.isDirty)
            OutlineButton(density: ButtonDensity.compact, onPressed: vm.revert, child: const Text('Revert', style: TextStyle(fontSize: 11))),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('garment_save'),
            density: ButtonDensity.compact,
            onPressed: vm.isDirty ? vm.save : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(LucideIcons.save, size: 12), SizedBox(width: 4), Text('Save', style: TextStyle(fontSize: 11))],
            ),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            SubEditorToolbarClose(child: GhostButton(density: ButtonDensity.iconDense, onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14))),
          ]
      ],
    );
  }

  /// A section header in the Level Editor's panel style.
  @override
  Widget header(String text) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      color: EditorColors.cardHeader,
      border: Border(bottom: BorderSide(color: EditorColors.border)),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
  );
}

/// What the Garment editor's parts share.
abstract class _GarmentEditorBase extends State<GarmentSubEditor> {
  GarmentEditorViewModel get vm;
  Widget header(String text);
  GarmentPreviewScene get scene;
  SubEditorTransformGizmo get gizmo;
  void setGizmo(GizmoMode mode);
  void syncScene();
}
