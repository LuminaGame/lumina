part of '../particle_sub_editor.dart';

/// The right panel: the stage tabs and their fields.
mixin _ParticleSubEditorRightPanel on _ParticleSubEditorStateBase {
  // ------------------------------------------------------------ right panel

  Widget _rightPanel() {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('${_stage.title.toUpperCase()} — ${vm.selectedEmitter.name}'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: switch (_stage) {
                ParticleStage.spawn => _spawnStage(),
                ParticleStage.lifetime => _lifetimeStage(),
                ParticleStage.forces => _forcesStage(),
                ParticleStage.overLife => _overLifeStage(),
                ParticleStage.render => _renderStage(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _spawnStage() {
    final c = vm.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('spawnRate (particles / sec)'),
        _NumField(
          fieldKey: const ValueKey('particle_spawn_rate'),
          value: c.spawnRate,
          onCommit: vm.setSpawnRate,
        ),
        _error('spawnRate'),
        const SizedBox(height: 8),
        Row(
          children: [
            _label('maxParticles (pool cap)'),
            const SizedBox(width: 6),
            SecondaryBadge(child: Text('${c.maxParticles}', style: const TextStyle(fontSize: 8))),
          ],
        ),
        _NumField(
          fieldKey: const ValueKey('particle_max_particles'),
          value: c.maxParticles.toDouble(),
          isInt: true,
          onCommit: (v) => vm.setMaxParticles(v.round()),
        ),
        _error('maxParticles'),
        const SizedBox(height: 4),
        const Text(
          'Changing maxParticles re-allocates the instance pool — applied on Enter / blur.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _label('bursts (time, count)'),
            const Spacer(),
            GhostButton(
              key: const ValueKey('particle_add_burst'),
              onPressed: () => vm.addBurst(0.0, 10),
              child: const Icon(LucideIcons.plus, size: 12),
            ),
          ],
        ),
        for (var i = 0; i < c.bursts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: _NumField(
                    fieldKey: ValueKey('particle_burst_time_$i'),
                    value: c.bursts[i].time,
                    onCommit: (v) => vm.setBurstTime(i, v),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _NumField(
                    fieldKey: ValueKey('particle_burst_count_$i'),
                    value: c.bursts[i].count.toDouble(),
                    isInt: true,
                    onCommit: (v) => vm.setBurstCount(i, v.round()),
                  ),
                ),
                GhostButton(
                  key: ValueKey('particle_burst_remove_$i'),
                  onPressed: () => vm.removeBurst(i),
                  child: const Icon(LucideIcons.trash2, size: 11),
                ),
              ],
            ),
          ),
        _error('bursts'),
        const SizedBox(height: 10),
        _label('looping'),
        Switch(
          key: const ValueKey('particle_looping'),
          value: c.looping,
          onChanged: vm.setLooping,
        ),
        const SizedBox(height: 8),
        _label('duration — Loop Duration (s)'),
        _NumField(
          fieldKey: const ValueKey('particle_duration'),
          value: c.duration,
          onCommit: vm.setDuration,
        ),
        _error('duration'),
        const Text(
          'The burst-loop period, not a system lifetime.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _lifetimeStage() {
    final c = vm.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('lifetimeMin (s)'),
        _NumField(fieldKey: const ValueKey('particle_lifetime_min'), value: c.lifetimeMin, onCommit: vm.setLifetimeMin),
        _label('lifetimeMax (s)'),
        _NumField(fieldKey: const ValueKey('particle_lifetime_max'), value: c.lifetimeMax, onCommit: vm.setLifetimeMax),
        _error('lifetime'),
        const SizedBox(height: 10),
        _label('speedMin'),
        _NumField(fieldKey: const ValueKey('particle_speed_min'), value: c.speedMin, onCommit: vm.setSpeedMin),
        _label('speedMax'),
        _NumField(fieldKey: const ValueKey('particle_speed_max'), value: c.speedMax, onCommit: vm.setSpeedMax),
        _error('speed'),
        const SizedBox(height: 10),
        _label('coneAngleDegrees (0–180)'),
        Row(
          children: [
            Expanded(
              child: SliderField(
                key: const ValueKey('particle_cone_angle'),
                value: c.coneAngleDegrees,
                defaultValue: LuminaParticleEmitterConfig().coneAngleDegrees,
                min: 0.0,
                max: 180.0,
                unit: '°',
                fractionDigits: 0,
                // One undo step per drag: the value is written on release.
                onChanged: (_) {},
                onCommit: vm.setConeAngleDegrees,
                onReset: () => vm.setConeAngleDegrees(LuminaParticleEmitterConfig().coneAngleDegrees),
              ),
            ),
            const SizedBox(width: 6),
            Text('${c.coneAngleDegrees.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 9)),
          ],
        ),
        const SizedBox(height: 10),
        _label('inheritVelocityScale (X, Y, Z)'),
        _vector3Row('inherit', c.inheritVelocityScale, vm.setInheritVelocityScale),
      ],
    );
  }

  Widget _forcesStage() {
    final c = vm.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('gravity (X, Y, Z) — default (0, -980, 0) cm/s²'),
        _vector3Row('gravity', c.gravity, vm.setGravity),
        const SizedBox(height: 10),
        _label('drag'),
        _NumField(fieldKey: const ValueKey('particle_drag'), value: c.drag, onCommit: vm.setDrag),
        const SizedBox(height: 8),
        const Text(
          'The engine integrates gravity + linear drag only. Curl noise, point attraction '
          'and collision are features the runtime does not have.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _overLifeStage() {
    final c = vm.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('colorOverLife: ${c.colorOverLife.length} stops',
            style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        for (var i = 0; i < c.colorOverLife.length; i++)
          Text(
            't=${c.colorOverLife[i].t.toStringAsFixed(2)}  rgba=(${c.colorOverLife[i].rgba.x.toStringAsFixed(2)}, '
            '${c.colorOverLife[i].rgba.y.toStringAsFixed(2)}, ${c.colorOverLife[i].rgba.z.toStringAsFixed(2)}, '
            '${c.colorOverLife[i].rgba.w.toStringAsFixed(2)})',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        const SizedBox(height: 10),
        Text('sizeOverLife: ${c.sizeOverLife.length} points',
            style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        for (var i = 0; i < c.sizeOverLife.length; i++)
          Text(
            't=${c.sizeOverLife[i].t.toStringAsFixed(2)}  scale=${c.sizeOverLife[i].scale.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        const SizedBox(height: 8),
        const Text(
          'Edit the stops and points in the gradient / curve editors below the preview. '
          'Empty lists mean white and scale 1.0 — exactly the runtime default.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _renderStage() {
    final c = vm.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('billboard (built-in quad)'),
        Switch(
          key: const ValueKey('particle_billboard'),
          value: c.billboard,
          onChanged: vm.setBillboard,
        ),
        const SizedBox(height: 10),
        _label('meshAssetPath'),
        AssetPickerSelect(
          key: const ValueKey('particle_mesh_select'),
          keyPrefix: 'particle_mesh_picker',
          assets: vm.availableMeshes,
          selectedPath: _selectedMesh()?.relativePath,
          placeholder: 'Built-in Quad',
          clearLabel: '— Built-in Quad —',
          onSelected: vm.setMeshAsset,
          onCleared: () => vm.setMeshAsset(null),
        ),
        const SizedBox(height: 6),
        Text(
          c.meshAssetPath ?? 'null → Built-in Quad',
          style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
        if (vm.availableMeshes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No FILAMESH assets in this project yet — import one to use a mesh renderer.',
                style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          ),
        const SizedBox(height: 10),
        const Text(
          'Renderers: sprite billboard or mesh instances. Ribbon and light renderers, and GPU '
          'simulation, are not implemented by the engine and are tracked as future scope.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  RealAssetInfo? _selectedMesh() {
    final path = vm.config.meshAssetPath;
    if (path == null) return null;
    for (final m in vm.availableMeshes) {
      if (m.relativePath == path) return m;
    }
    return null;
  }
}
