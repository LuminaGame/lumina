part of '../foliage_sub_editor.dart';

/// The foliage panel: brush settings, the mesh palette and the layer cards.
extension _LandscapeFoliagePanel on _LandscapeFoliageSubEditorState {
  // --- Foliage panel ---------------------------------------------------------

  Widget _foliagePanel() {
    final layers = _vm.data.layers;
    final palette = _vm.meshPalette;
    return Padding(
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
              child: Text(AssetPickerCatalog.defaultLabel(asset), style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
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
}
