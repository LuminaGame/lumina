import 'package:file_picker/file_picker.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaUnits, RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/brush_overlay.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

part 'foliage_sub_editor/foliage_panel.dart';
part 'foliage_sub_editor/left_panel.dart';

/// Landscape / Foliage sub-editor.
///
/// Honest scope: the terrain is a real heightmap turned into tiled
/// `LuminaProceduralMeshComponent` sections, sculpted by real brushes that
/// upload only the touched vertex windows, and foliage is scattered into real
/// `LuminaInstancedStaticMeshComponent` batches. The doc's weight-blended
/// texture `Paint` tab (Grass/Rock/Mud/Snow target layers) is **not** here:
/// no multi-layer terrain material exists in lumina or flutter_filament yet,
/// so shipping those controls would mean shipping dead buttons.
class LandscapeFoliageSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final EditorViewModel? editorViewModel;
  final LandscapeEditorViewModel? viewModel;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  const LandscapeFoliageSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.editorViewModel,
    this.viewModel,
    this.onBind,
    this.onClose,
  });

  @override
  State<LandscapeFoliageSubEditor> createState() => _LandscapeFoliageSubEditorState();
}

class _LandscapeFoliageSubEditorState extends State<LandscapeFoliageSubEditor> {
  late final LandscapeEditorViewModel _vm;
  LandscapePreviewScene? _preview;
  bool _ownsVm = false;

  LandscapeEditorViewModel get viewModelForTest => _vm;

  /// The live preview scene, so smoke tests can assert what actually reached
  /// the Filament scene rather than only what the model counted.
  LandscapePreviewScene? get previewSceneForTest => _preview;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
      // A view model an MCP tool created carries its own
      // preview scene; the viewport attaches it so the terrain still draws.
      final sink = _vm.sink;
      if (sink is LandscapePreviewScene) {
        _preview = sink;
        sink.onChanged = () {
          if (mounted) setState(() {});
        };
      }
    } else {
      final preview = LandscapePreviewScene();
      _preview = preview;
      _vm = LandscapeEditorViewModel(
        editor: widget.editorViewModel,
        assetPath: widget.assetPath,
        sink: preview,
      );
      _ownsVm = true;
      preview.onChanged = () {
        if (mounted) setState(() {});
      };
    }
    _vm.addListener(_onChanged);
    _vm.open();
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _preview?.detach();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _toolbar(),
        // Islands on the ground, resizable: the mode island (Manage /
        // Sculpt / Foliage tabs in its header), the viewport, the foliage.
        Expanded(
          child: EditorIslandGround(
            child: ResizablePanel.horizontal(
              dividerBuilder: EditorIslandDividers.gap,
              children: [
                ResizablePane(
                  initialSize: 270,
                  minSize: 200,
                  child: EditorIsland(
                    key: const ValueKey('landscape_island_tools'),
                    header: EditorIslandTabHeader(
                      tabs: [for (final t in _modeTabs.values) t],
                      tabKeys: {for (final (i, t) in _modeTabs.keys.indexed) i: ValueKey('landscape_tab_${t.name}')},
                      active: _modeTabs.keys.toList().indexOf(_vm.tab),
                      onSelect: (i) => _vm.setTab(_modeTabs.keys.elementAt(i)),
                    ),
                    child: _leftPanel(),
                  ),
                ),
                ResizablePane.flex(
                  child: EditorIsland(
                    key: const ValueKey('landscape_island_viewport'),
                    color: EditorColors.viewportBackdrop,
                    child: _viewport(),
                  ),
                ),
                ResizablePane(
                  initialSize: 270,
                  minSize: 200,
                  child: EditorIsland(
                    key: const ValueKey('landscape_island_foliage'),
                    header: const EditorIslandHeader(title: 'Foliage'),
                    child: _foliagePanel(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The editor's modes, as the tool island's header tabs.
  static const Map<LandscapeEditorTab, String> _modeTabs = {
    LandscapeEditorTab.manage: 'Manage',
    LandscapeEditorTab.sculpt: 'Sculpt',
    LandscapeEditorTab.foliage: 'Foliage',
  };

  // --- Toolbar ---------------------------------------------------------------

  Widget _toolbar() {
    return SubEditorToolbar(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.emerald.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('LANDSCAPE',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.emerald)),
          ),
const SizedBox(width: 8),
Text(widget.assetName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
if (_vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
            ),
          ],
          ])),
          const Spacer(),
          GhostButton(
            key: const ValueKey('landscape_undo'),
            onPressed: _vm.canUndo ? _vm.undo : null,
            child: const Icon(LucideIcons.undo2, size: 13),
          ),
          GhostButton(
            key: const ValueKey('landscape_redo'),
            onPressed: _vm.canRedo ? _vm.redo : null,
            child: const Icon(LucideIcons.redo2, size: 13),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('landscape_save'),
            onPressed: () => _vm.save(),
            child: const Text('Save', style: TextStyle(fontSize: 9)),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            SubEditorToolbarClose(child: GhostButton(onPressed: widget.onClose!, child: const Icon(LucideIcons.x, size: 14))),
          ]
      ],
    );
  }

  // --- Viewport --------------------------------------------------------------

  /// The brush the 3D viewport paints with: the Sculpt tab's sculpt brush or
  /// the Foliage tab's scatter/erase brush; none in Manage, where LMB stays
  /// with the camera.
  ViewportBrushInput? get _brushInput {
    if (_vm.tab == LandscapeEditorTab.manage) return null;
    return ViewportBrushInput(
      onHover: (ray) => _vm.hoverRay(ray.origin, ray.direction),
      onStrokeStart: (ray, {required bool invert}) => _vm.brushDown(ray.origin, ray.direction, invert: invert),
      onStrokeUpdate: (ray) => _vm.brushDrag(ray.origin, ray.direction),
      onStrokeEnd: _vm.brushUp,
    );
  }

  Widget _viewport() {
    return Stack(
      children: [
        Positioned.fill(
          // The cursor leaves the terrain when the mouse leaves the viewport.
          child: MouseRegion(
            onExit: (_) => _vm.clearCursor(),
            child: SubEditor3DViewport(
            title: 'Landscape Viewport',
            yUpCamera: true,
            showShapeSelector: false,
            // The terrain is the ground; the editor grid would z-fight with it.
            showGrid: false,
            statsLabel: _vm.hudLabel,
            initialCameraDistance: _vm.data.worldSize * LandscapeEditorViewModel.unitsPerMetre * 1.3,
            onPreviewWorldReady: (world) {
              final preview = _preview;
              if (preview == null) return;
              preview.attach(world);
              // The scene starts empty; push the current terrain and foliage
              // into it, or the viewport stays bare until the first edit.
              if (preview.isAvailable) _vm.rebuildPreview();
            },
            onPreviewWorldDisposing: (_) => _preview?.detach(),
            // LMB paints on the terrain under the mouse in Sculpt and Foliage;
            // Alt+LMB orbit, RMB look, MMB pan and the wheel keep the camera.
            brushInput: _brushInput,
            // The stats line lives in the viewport's own stats strip
            // ([statsLabel]); no second copy over the viewport.
          ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 8,
          child: LandscapeBrushOverlay(viewModel: _vm),
        ),
        if (!_vm.isPreviewAttached)
          const Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: OutlineBadge(
                key: ValueKey('landscape_engine_badge'),
                child: Text('Engine preview not attached — sculpt map is live',
                    style: TextStyle(fontSize: 8)),
              ),
            ),
          ),
        if (_preview?.foliageError != null)
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: DestructiveBadge(child: Text(_preview!.foliageError!, style: const TextStyle(fontSize: 8))),
            ),
          ),
      ],
    );
  }

  // --- Heightmap import ------------------------------------------------------

  Future<void> _importHeightmap() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      dialogTitle: 'Import heightmap PNG (square, 8/16-bit greyscale, n×64+1 up to 8129²)',
    );
    final path = result?.files.single.path;
    if (path != null && path.isNotEmpty) {
      await _vm.importHeightmapFileAsync(path);
    }
  }

  // --- Small helpers ---------------------------------------------------------

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 2),
        child: Text(text, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
      );
}
