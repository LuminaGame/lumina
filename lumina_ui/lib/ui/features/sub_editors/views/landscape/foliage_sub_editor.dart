import 'package:file_picker/file_picker.dart';
import 'package:lumina/lumina.dart' show LuminaUnits, RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/brush_overlay.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

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
        Expanded(
          child: Row(
            // The side panels shrink-wrap their scroll views; without stretch
            // the Row centred them vertically.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 270, child: _leftPanel()),
              Expanded(child: _viewport()),
              SizedBox(width: 270, child: _foliagePanel()),
            ],
          ),
        ),
      ],
    );
  }

  // --- Toolbar ---------------------------------------------------------------

  Widget _toolbar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
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
          const Spacer(),
          for (final entry in const {
            LandscapeEditorTab.manage: 'Manage',
            LandscapeEditorTab.sculpt: 'Sculpt',
            LandscapeEditorTab.foliage: 'Foliage',
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Button(
                key: ValueKey('landscape_tab_${entry.key.name}'),
                style: _vm.tab == entry.key ? const ButtonStyle.primary() : const ButtonStyle.ghost(),
                onPressed: () => _vm.setTab(entry.key),
                child: Text(entry.value, style: const TextStyle(fontSize: 9)),
              ),
            ),
          const SizedBox(width: 10),
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
            GhostButton(onPressed: widget.onClose!, child: const Icon(LucideIcons.x, size: 14)),
          ],
        ],
      ),
    );
  }

  // --- Left panel ------------------------------------------------------------

  Widget _leftPanel() {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _vm.tab == LandscapeEditorTab.sculpt ? _sculptPanel() : _managePanel(),
        ),
      ),
    );
  }

  List<Widget> _managePanel() {
    return [
      _sectionTitle('New Terrain'),
      const Text(
        'Above 513² the terrain streams: only tiles near the camera are mounted, '
        'distant tiles are decimated, and the HUD reports what is really resident. '
        'The terrain is a walkable collider: characters sweep against the whole '
        'heightmap, not only the resident tiles, in Play and in the built game. The '
        'terrain is lit by the preview sun: slopes shade by their normals, grass '
        'turns to rock on steep ground, and hills and foliage cast shadows. '
        'Weight-blended paint layers need a multi-layer terrain material that '
        'does not exist yet.',
        style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
      ),
      const SizedBox(height: 6),
      _label('Resolution (verts per side)'),
      Select<int>(
        key: const ValueKey('landscape_resolution'),
        value: _vm.newTerrainResolution,
        onChanged: (v) => v == null ? null : _vm.setNewTerrainResolution(v),
        itemBuilder: (context, v) => Text('$v × $v', style: const TextStyle(fontSize: 9.5)),
        popup: const SelectPopup(
          items: SelectItemList(
            children: [
              SelectItemButton(value: 129, child: Text('129 × 129')),
              SelectItemButton(value: 257, child: Text('257 × 257')),
              SelectItemButton(value: 513, child: Text('513 × 513')),
              SelectItemButton(value: 1025, child: Text('1025 × 1025')),
              SelectItemButton(value: 2049, child: Text('2049 × 2049')),
              SelectItemButton(value: 4097, child: Text('4097 × 4097')),
              SelectItemButton(value: 8129, child: Text('8129 × 8129')),
            ],
          ),
        ).call,
      ),
      const SizedBox(height: 6),
      // Lengths are shown and typed in cm; the payload keeps metres.
      _label('World Size (cm)'),
      SliderField(
        key: const ValueKey('landscape_world_size'),
        value: LuminaUnits.metres(_vm.newTerrainWorldSize),
        defaultValue: LuminaUnits.metres(256.0),
        min: LuminaUnits.metres(16.0),
        max: LuminaUnits.metres(4096.0),
        unit: 'cm',
        fractionDigits: 0,
        onChanged: (cm) => _vm.setNewTerrainWorldSize(LuminaUnits.toMetres(cm)),
        onCommit: (cm) => _vm.setNewTerrainWorldSize(LuminaUnits.toMetres(cm)),
        onReset: () => _vm.setNewTerrainWorldSize(256.0),
      ),
      const SizedBox(height: 4),
      _label('Max Height (cm)'),
      SliderField(
        key: const ValueKey('landscape_max_height'),
        value: LuminaUnits.metres(_vm.newTerrainMaxHeight),
        defaultValue: LuminaUnits.metres(100.0),
        min: LuminaUnits.metres(1.0),
        max: LuminaUnits.metres(2000.0),
        unit: 'cm',
        fractionDigits: 0,
        onChanged: (cm) => _vm.setNewTerrainMaxHeight(LuminaUnits.toMetres(cm)),
        onCommit: (cm) => _vm.setNewTerrainMaxHeight(LuminaUnits.toMetres(cm)),
        onReset: () => _vm.setNewTerrainMaxHeight(100.0),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: PrimaryButton(
              key: const ValueKey('landscape_new_terrain'),
              onPressed: _vm.createTerrainFromForm,
              child: const Text('New Terrain', style: TextStyle(fontSize: 9)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlineButton(
              key: const ValueKey('landscape_import_heightmap'),
              onPressed: _importHeightmap,
              child: const Text('Import Heightmap', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _sectionTitle('Terrain'),
      _statsCard(),
      const SizedBox(height: 10),
      if (_vm.importProgress != null) ...[
        const SizedBox(height: 4),
        Progress(progress: _vm.importProgress!),
      ],
      if (_vm.statusMessage != null)
        Text(_vm.statusMessage!, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
    ];
  }

  List<Widget> _sculptPanel() {
    final tools = {
      LandscapeTool.sculpt: 'Sculpt',
      LandscapeTool.smooth: 'Smooth',
      LandscapeTool.flatten: 'Flatten',
      LandscapeTool.noise: 'Noise',
    };
    return [
      _sectionTitle('Tools'),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in tools.entries)
            Button(
              key: ValueKey('landscape_tool_${entry.key.name}'),
              style: _vm.tool == entry.key ? const ButtonStyle.primary() : const ButtonStyle.outline(),
              onPressed: () => _vm.setTool(entry.key),
              child: Text(entry.value, style: const TextStyle(fontSize: 9)),
            ),
        ],
      ),
      const SizedBox(height: 4),
      _controlsHint('sculpt', 'Sculpt raises, Shift lowers.'),
      const SizedBox(height: 10),
      _label('Brush Size (${LandscapeEditorViewModel.formatCm(_vm.brushRadius)} cm)'),
      SliderField(
        key: const ValueKey('landscape_brush_radius'),
        value: LuminaUnits.metres(_vm.brushRadius),
        defaultValue: LuminaUnits.metres(45.0),
        min: LuminaUnits.metres(1.0),
        max: LuminaUnits.metres(200.0),
        unit: 'cm',
        fractionDigits: 0,
        onChanged: (cm) => _vm.setBrushRadius(LuminaUnits.toMetres(cm)),
        onCommit: (cm) => _vm.setBrushRadius(LuminaUnits.toMetres(cm)),
        onReset: () => _vm.setBrushRadius(45.0),
      ),
      const SizedBox(height: 4),
      _label('Brush Strength (${_vm.brushStrength.toStringAsFixed(2)})'),
      SliderField(
        key: const ValueKey('landscape_brush_strength'),
        value: _vm.brushStrength,
        defaultValue: 0.5,
        min: 0.01,
        max: 1.0,
        onChanged: _vm.setBrushStrength,
        onCommit: _vm.setBrushStrength,
        onReset: () => _vm.setBrushStrength(0.5),
      ),
      const SizedBox(height: 4),
      _label('Brush Falloff (${_vm.brushFalloff.toStringAsFixed(2)})'),
      SliderField(
        key: const ValueKey('landscape_brush_falloff'),
        value: _vm.brushFalloff,
        defaultValue: 0.5,
        min: 0.0,
        max: 1.0,
        onChanged: _vm.setBrushFalloff,
        onCommit: _vm.setBrushFalloff,
        onReset: () => _vm.setBrushFalloff(0.5),
      ),
      const SizedBox(height: 6),
      _label('Falloff Type'),
      Select<LandscapeFalloffType>(
        key: const ValueKey('landscape_falloff_type'),
        value: _vm.falloffType,
        onChanged: (v) => v == null ? null : _vm.setFalloffType(v),
        itemBuilder: (context, v) => Text(_falloffLabel(v), style: const TextStyle(fontSize: 9.5)),
        popup: const SelectPopup(
          items: SelectItemList(
            children: [
              SelectItemButton(value: LandscapeFalloffType.smooth, child: Text('Smooth')),
              SelectItemButton(value: LandscapeFalloffType.linear, child: Text('Linear')),
              SelectItemButton(value: LandscapeFalloffType.spherical, child: Text('Spherical')),
              SelectItemButton(value: LandscapeFalloffType.tip, child: Text('Tip')),
            ],
          ),
        ).call,
      ),
      const SizedBox(height: 12),
      _statsCard(),
    ];
  }

  static String _falloffLabel(LandscapeFalloffType t) {
    switch (t) {
      case LandscapeFalloffType.smooth:
        return 'Smooth';
      case LandscapeFalloffType.linear:
        return 'Linear';
      case LandscapeFalloffType.spherical:
        return 'Spherical';
      case LandscapeFalloffType.tip:
        return 'Tip';
    }
  }

  Widget _statsCard() {
    return Card(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TERRAIN STATS',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(height: 4),
          Text(_vm.statsLabel, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
          const SizedBox(height: 2),
          Text('Mesh sections: ${_vm.sectionCount} · cell ${LandscapeEditorViewModel.formatCm(_vm.data.cellSize)} cm',
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          Text('Foliage instances: ${_vm.foliageInstanceCount}',
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
      ),
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

  // --- Foliage panel ---------------------------------------------------------

  Widget _foliagePanel() {
    final layers = _vm.data.layers;
    final palette = _vm.meshPalette;
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      // One scroll view for the whole panel: the brush, the layer rules and the
      // palette together are taller than a laptop screen.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._foliageBrushSection(),
            const SizedBox(height: 10),
            _sectionTitle('Foliage Layers'),
            Row(
              children: [
                Toggle(
                  key: const ValueKey('landscape_mode_scatter'),
                  value: _vm.paintMode == FoliagePaintMode.paint,
                  onChanged: (_) => _vm.setPaintMode(FoliagePaintMode.paint),
                  child: const Text('Scatter', style: TextStyle(fontSize: 9)),
                ),
                const SizedBox(width: 4),
                Toggle(
                  key: const ValueKey('landscape_mode_erase'),
                  value: _vm.paintMode == FoliagePaintMode.erase,
                  onChanged: (_) => _vm.setPaintMode(FoliagePaintMode.erase),
                  child: const Text('Erase', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _controlsHint('foliage', 'Shift swaps Scatter and Erase.'),
            const SizedBox(height: 6),
            if (layers.isEmpty)
              const Text('No foliage layers yet — add one from a mesh asset below.',
                  style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            for (var i = 0; i < layers.length; i++) _layerCard(i, layers[i]),
            const SizedBox(height: 8),
            _sectionTitle('Mesh Palette'),
            if (palette.isEmpty)
              const Text('No FILAMESH assets in this project yet — import a model first.',
                  style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            for (final asset in palette) _paletteEntry(asset),
          ],
        ),
      ),
    );
  }

  /// The foliage brush: its own size and falloff, and
  /// Paint Density / Erase Density. Laid out like the sculpt brush.
  List<Widget> _foliageBrushSection() {
    return [
      _sectionTitle('Brush'),
      _label('Brush Size (${LandscapeEditorViewModel.formatCm(_vm.foliageBrushRadius)} cm)'),
      SliderField(
        key: const ValueKey('landscape_foliage_brush_size'),
        value: LuminaUnits.metres(_vm.foliageBrushRadius),
        defaultValue: LuminaUnits.metres(10.0),
        min: LuminaUnits.metres(1.0),
        max: LuminaUnits.metres(200.0),
        unit: 'cm',
        fractionDigits: 0,
        onChanged: (cm) => _vm.setFoliageBrushRadius(LuminaUnits.toMetres(cm)),
        onCommit: (cm) => _vm.setFoliageBrushRadius(LuminaUnits.toMetres(cm)),
        onReset: () => _vm.setFoliageBrushRadius(10.0),
      ),
      const SizedBox(height: 4),
      _label('Brush Falloff (${_vm.foliageBrushFalloff.toStringAsFixed(2)})'),
      SliderField(
        key: const ValueKey('landscape_foliage_brush_falloff'),
        value: _vm.foliageBrushFalloff,
        defaultValue: 0.5,
        min: 0.0,
        max: 1.0,
        onChanged: _vm.setFoliageBrushFalloff,
        onCommit: _vm.setFoliageBrushFalloff,
        onReset: () => _vm.setFoliageBrushFalloff(0.5),
      ),
      const SizedBox(height: 4),
      _label('Paint Density (${_vm.paintDensity.toStringAsFixed(2)})'),
      SliderField(
        key: const ValueKey('landscape_foliage_paint_density'),
        value: _vm.paintDensity,
        defaultValue: 0.5,
        min: 0.0,
        max: 1.0,
        onChanged: _vm.setPaintDensity,
        onCommit: _vm.setPaintDensity,
        onReset: () => _vm.setPaintDensity(0.5),
      ),
      const SizedBox(height: 4),
      _label('Erase Density (${_vm.eraseDensity.toStringAsFixed(2)})'),
      SliderField(
        key: const ValueKey('landscape_foliage_erase_density'),
        value: _vm.eraseDensity,
        defaultValue: 0.0,
        min: 0.0,
        max: 1.0,
        onChanged: _vm.setEraseDensity,
        onCommit: _vm.setEraseDensity,
        onReset: () => _vm.setEraseDensity(0.0),
      ),
    ];
  }

  /// The viewport controls, stated where the brush is.
  Widget _controlsHint(String panel, String tool) => Text(
        '$tool LMB paints on the terrain · Shift+LMB inverts · Alt+LMB orbits · '
        'RMB looks · MMB pans · wheel zooms',
        key: ValueKey('landscape_controls_hint_$panel'),
        style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
      );

  Widget _paletteEntry(RealAssetInfo asset) {
    final already = _vm.data.layers.any((l) => l.meshAssetPath == (asset.lmasPath ?? asset.relativePath));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlineButton(
        key: ValueKey('landscape_palette_${asset.fileName}'),
        onPressed: already
            ? null
            : () => _vm.addFoliageLayer(
                  meshAssetId: asset.assetId ?? asset.fileName,
                  meshAssetPath: asset.lmasPath ?? asset.relativePath,
                  name: asset.fileName.replaceAll('.lmas', ''),
                ),
        child: Row(
          children: [
            const Icon(LucideIcons.trees, size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Text(asset.fileName, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layerCard(int index, FoliageLayer layer) {
    final selected = _vm.selectedFoliageLayer == index;
    final rules = layer.rules;
    return GestureDetector(
      key: ValueKey('landscape_layer_$index'),
      onTap: () => _vm.selectFoliageLayer(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? EditorColors.primary.withValues(alpha: 0.16) : EditorColors.cardHeader,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? EditorColors.primary : EditorColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(layer.name,
                      style: TextStyle(fontSize: 9.5, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                ),
                SecondaryBadge(
                  key: ValueKey('landscape_layer_count_$index'),
                  child: Text('${layer.instanceCount}', style: const TextStyle(fontSize: 8)),
                ),
                const SizedBox(width: 4),
                GhostButton(
                  key: ValueKey('landscape_layer_remove_$index'),
                  onPressed: () => _vm.removeFoliageLayer(index),
                  child: const Icon(LucideIcons.trash2, size: 11),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 4),
              // Instances per 1000 × 1000 cm.
              _label('Density (${rules.density.toStringAsFixed(0)} per 1000 × 1000 cm)'),
              SliderField(
                key: ValueKey('landscape_density_$index'),
                value: rules.density,
                defaultValue: 50.0,
                min: 1.0,
                max: 500.0,
                onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(density: v)),
                onCommit: (v) => _vm.setLayerRules(index, rules.copyWith(density: v)),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(density: 50.0)),
              ),
              _label('Min Spacing (${LandscapeEditorViewModel.formatCm(rules.minSpacing)} cm)'),
              SliderField(
                key: ValueKey('landscape_spacing_$index'),
                value: LuminaUnits.metres(rules.minSpacing),
                defaultValue: LuminaUnits.metres(1.5),
                min: LuminaUnits.metres(0.05),
                max: LuminaUnits.metres(20.0),
                unit: 'cm',
                fractionDigits: 0,
                onChanged: (cm) => _vm.setLayerRules(index, rules.copyWith(minSpacing: LuminaUnits.toMetres(cm))),
                onCommit: (cm) => _vm.setLayerRules(index, rules.copyWith(minSpacing: LuminaUnits.toMetres(cm))),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(minSpacing: 1.5)),
              ),
              _label('Scale ${rules.scaleMin.toStringAsFixed(2)} – ${rules.scaleMax.toStringAsFixed(2)}'),
              SliderField(
                key: ValueKey('landscape_scale_min_$index'),
                value: rules.scaleMin,
                defaultValue: 0.8,
                min: 0.05,
                max: 5.0,
                onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(scaleMin: v)),
                onCommit: (v) => _vm.setLayerRules(index, rules.copyWith(scaleMin: v)),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(scaleMin: 0.8)),
              ),
              SliderField(
                key: ValueKey('landscape_scale_max_$index'),
                value: rules.scaleMax,
                defaultValue: 1.2,
                min: 0.05,
                max: 5.0,
                onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(scaleMax: v)),
                onCommit: (v) => _vm.setLayerRules(index, rules.copyWith(scaleMax: v)),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(scaleMax: 1.2)),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Random Yaw', style: TextStyle(fontSize: 9))),
                  Switch(
                    key: ValueKey('landscape_random_yaw_$index'),
                    value: rules.randomYaw,
                    onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(randomYaw: v)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('Align to Normal', style: TextStyle(fontSize: 9))),
                  Switch(
                    key: ValueKey('landscape_align_normal_$index'),
                    value: rules.alignToNormal,
                    onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(alignToNormal: v)),
                  ),
                ],
              ),
              _label('Slope ${rules.slopeMinDegrees.toStringAsFixed(0)}° – ${rules.slopeMaxDegrees.toStringAsFixed(0)}°'),
              SliderField(
                key: ValueKey('landscape_slope_min_$index'),
                value: rules.slopeMinDegrees,
                defaultValue: 0.0,
                min: 0.0,
                max: 90.0,
                unit: '°',
                onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(slopeMinDegrees: v)),
                onCommit: (v) => _vm.setLayerRules(index, rules.copyWith(slopeMinDegrees: v)),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(slopeMinDegrees: 0.0)),
              ),
              SliderField(
                key: ValueKey('landscape_slope_max_$index'),
                value: rules.slopeMaxDegrees,
                defaultValue: 45.0,
                min: 0.0,
                max: 90.0,
                unit: '°',
                onChanged: (v) => _vm.setLayerRules(index, rules.copyWith(slopeMaxDegrees: v)),
                onCommit: (v) => _vm.setLayerRules(index, rules.copyWith(slopeMaxDegrees: v)),
                onReset: () => _vm.setLayerRules(index, rules.copyWith(slopeMaxDegrees: 45.0)),
              ),
              Text('Per-layer instance cap: ${LandscapeEditorViewModel.foliageCapacityPerLayer} '
                  '(the instancing spec has no live capacity grow)',
                  style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
            ],
          ],
        ),
      ),
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
