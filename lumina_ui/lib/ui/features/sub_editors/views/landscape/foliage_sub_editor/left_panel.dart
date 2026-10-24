part of '../foliage_sub_editor.dart';

/// The left panel: Manage / Sculpt tool settings and the stats card.
extension _LandscapeFoliageLeftPanel on _LandscapeFoliageSubEditorState {
  // --- Left panel ------------------------------------------------------------

  Widget _leftPanel() {
    return Padding(
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
}
