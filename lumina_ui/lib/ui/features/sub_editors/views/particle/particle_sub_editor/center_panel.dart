part of '../particle_sub_editor.dart';

/// The center panel: viewport, playback bar and the curve editors.
mixin _ParticleSubEditorCenterPanel on _ParticleSubEditorStateBase {
  // ----------------------------------------------------------- center panel

  Widget _centerPanel() {
    return Column(
      children: [
        Expanded(child: _viewport()),
        const Divider(height: 1),
        SizedBox(height: 236, child: _bottomEditors()),
      ],
    );
  }

  Widget _viewport() {
    return SubEditor3DViewport(
      title: 'Particle Preview',
      showShapeSelector: false,
      yUpCamera: true,
      initialCameraDistance: 6.0,
      statsLabel: vm.isPreviewAttached
          ? 'Drawn: ${vm.preview.liveSpriteCount} / ${vm.preview.spriteCapacity} sprites  ·  Renderer: Filament C++ via lumina'
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
                  key: const ValueKey('particle_stats_overlay'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Text(
                    vm.statsLabel,
                    style: const TextStyle(fontSize: 9, color: EditorColors.logSuccess, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(child: _playbackBar()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playbackBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GhostButton(
            key: const ValueKey('particle_play'),
            onPressed: vm.togglePlay,
            child: Icon(vm.isPlaying ? LucideIcons.pause : LucideIcons.play, size: 13),
          ),
          GhostButton(
            key: const ValueKey('particle_step'),
            onPressed: vm.stepFrame,
            child: const Icon(LucideIcons.stepForward, size: 13),
          ),
          GhostButton(
            key: const ValueKey('particle_reset'),
            onPressed: vm.resetSimulation,
            child: const Icon(LucideIcons.rotateCcw, size: 13),
          ),
          const SizedBox(width: 10),
          const Text('Sim Speed', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 6),
          SizedBox(
            width: 190,
            child: SliderField(
              key: const ValueKey('particle_sim_speed'),
              value: vm.simSpeed,
              defaultValue: 1.0,
              min: ParticleEditorViewModel.minSimSpeed,
              max: ParticleEditorViewModel.maxSimSpeed,
              unit: '×',
              onChanged: vm.setSimSpeed,
              onCommit: vm.setSimSpeed,
              onReset: () => vm.setSimSpeed(1.0),
            ),
          ),
          const SizedBox(width: 6),
          Text('${vm.simSpeed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _bottomEditors() {
    final c = vm.config;
    return Container(
      color: EditorColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('colorOverLife',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                const SizedBox(width: 8),
                Text('click to add a stop · drag to move · right-click to delete (${c.colorOverLife.length} stops)',
                    style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                const Spacer(),
                if (_selectedColorStop != null && _selectedColorStop! < c.colorOverLife.length)
                  _colorStopEditor(c.colorOverLife[_selectedColorStop!].rgba),
              ],
            ),
            const SizedBox(height: 4),
            ParticleGradientEditor(
              stops: c.colorOverLife,
              selectedIndex: _selectedColorStop,
              sample: vm.sampleColorAt,
              onAdd: (t) {
                vm.addColorStop(t, vm.sampleColorAt(t));
                setState(() => _selectedColorStop = null);
              },
              onMove: vm.moveColorStop,
              onSelect: (i) => setState(() => _selectedColorStop = i),
              onRemove: (i) {
                vm.removeColorStop(i);
                setState(() => _selectedColorStop = null);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('sizeOverLife',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                const SizedBox(width: 8),
                Text('(t, scale) linear segments — ${c.sizeOverLife.length} points',
                    style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
              ],
            ),
            const SizedBox(height: 4),
            ParticleCurveEditor(
              points: c.sizeOverLife,
              selectedIndex: _selectedSizePoint,
              sample: vm.sampleSizeAt,
              onAdd: (t, s) {
                vm.addSizePoint(t, s);
                setState(() => _selectedSizePoint = null);
              },
              onMove: vm.moveSizePoint,
              onSelect: (i) => setState(() => _selectedSizePoint = i),
              onRemove: (i) {
                vm.removeSizePoint(i);
                setState(() => _selectedSizePoint = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorStopEditor(Vector4 rgba) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Stop RGBA', style: TextStyle(fontSize: 9)),
        const SizedBox(width: 6),
        for (var ch = 0; ch < 4; ch++) ...[
          SizedBox(
            width: 52,
            child: _NumField(
              fieldKey: ValueKey('particle_color_stop_$ch'),
              value: [rgba.x, rgba.y, rgba.z, rgba.w][ch],
              onCommit: (v) {
                final next = Vector4.copy(rgba);
                next[ch] = v.clamp(0.0, 1.0);
                vm.setColorStopRgba(_selectedColorStop!, next);
              },
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }
}
