import 'package:lumina/lumina.dart' show LuminaParticleEmitterConfig;
import 'package:lumina/data/repositories/asset_repository.dart' show RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Vector4;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import '../../sub_editor_binding.dart';
import '../../view_models/particle_editor_view_model.dart';
import '../sub_editor_3d_viewport.dart';
import 'curve_editors.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

/// Particle sub-editor.
///
/// Edits exactly `LuminaParticleEmitterConfig`: the engine's CPU emitter.
/// GPU-compute simulation, a scratch-pad node graph, curl-noise /
/// attraction / collision forces and ribbon / light renderers are **not**
/// built: the engine runs none of them, so no dead controls exist for them.
/// They are future scope.
class ParticleSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final String? projectDirPath;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  /// A view model already bound to the tab (an MCP tool opened the asset
  /// first); the editor adopts it and neither opens nor
  /// disposes it.
  final ParticleEditorViewModel? viewModel;

  const ParticleSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.projectDirPath,
    this.onBind,
    this.onClose,
    this.viewModel,
  });

  @override
  State<ParticleSubEditor> createState() => _ParticleSubEditorState();
}

/// The five stage blocks of the emitter stack.
enum ParticleStage { spawn, lifetime, forces, overLife, render }

extension on ParticleStage {
  String get key => switch (this) {
        ParticleStage.spawn => 'spawn',
        ParticleStage.lifetime => 'lifetime',
        ParticleStage.forces => 'forces',
        ParticleStage.overLife => 'overlife',
        ParticleStage.render => 'render',
      };

  String get title => switch (this) {
        ParticleStage.spawn => 'Spawn',
        ParticleStage.lifetime => 'Lifetime & Velocity',
        ParticleStage.forces => 'Forces',
        ParticleStage.overLife => 'Over-Life',
        ParticleStage.render => 'Render',
      };
}

class _ParticleSubEditorState extends State<ParticleSubEditor> {
  late final ParticleEditorViewModel vm;
  late final bool _ownsViewModel;
  ParticleStage _stage = ParticleStage.spawn;
  int? _selectedColorStop;
  int? _selectedSizePoint;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    vm = widget.viewModel ??
        ParticleEditorViewModel(
          assetPath: widget.assetPath ?? '${widget.assetName}.lmas',
          projectDirPath: widget.projectDirPath,
        );
    if (_ownsViewModel) vm.open();
    vm.addListener(_onVm);
    widget.onBind?.call(vm, vm.save, () => vm.isDirty);
  }

  /// Test/smoke hook: the live view model behind this editor.
  ParticleEditorViewModel get viewModelForTest => vm;

  void _onVm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.removeListener(_onVm);
    if (_ownsViewModel) vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.background,
      child: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: ResizablePanel.horizontal(
              children: [
                ResizablePane(initialSize: 280, minSize: 200, child: _leftPanel()),
                ResizablePane.flex(child: _centerPanel()),
                ResizablePane(initialSize: 300, minSize: 240, child: _rightPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- toolbar

  Widget _toolbar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('PARTICLE VFX',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          const SizedBox(width: 8),
          Text(widget.assetName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          if (vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('particle_dirty_indicator'),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
            ),
          ],
          const SizedBox(width: 10),
          const OutlineBadge(
            child: Text(ParticleEditorViewModel.backendLabel, style: TextStyle(fontSize: 8)),
          ),
          const Spacer(),
          GhostButton(
            key: const ValueKey('particle_reset_sim'),
            onPressed: vm.resetSimulation,
            child: const Text('Reset Sim', style: TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('particle_save'),
            onPressed: vm.canSave && vm.isDirty ? () => vm.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 9)),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GhostButton(onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14)),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- left panel

  Widget _leftPanel() {
    return Container(
      color: EditorColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('EMITTERS', trailing: [
            GhostButton(
              key: const ValueKey('particle_add_emitter'),
              onPressed: () => vm.addEmitter('Emitter ${vm.emitters.length + 1}'),
              child: const Icon(LucideIcons.plus, size: 12),
            ),
          ]),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: vm.emitters.length,
              itemBuilder: (context, i) => _emitterRow(i),
            ),
          ),
          const Divider(height: 1),
          _sectionHeader('EMITTER STACK'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Accordion(
                items: [
                  for (final stage in ParticleStage.values)
                    AccordionItem(
                      expanded: stage == _stage,
                      trigger: AccordionTrigger(
                        child: GestureDetector(
                          onTap: () => setState(() => _stage = stage),
                          child: Text(stage.title.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      content: KeyedSubtree(
                        key: ValueKey('particle_stage_${stage.key}'),
                        child: GestureDetector(
                          onTap: () => setState(() => _stage = stage),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              vm.stageSummary(stage.key),
                              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emitterRow(int index) {
    final entry = vm.emitters[index];
    final selected = index == vm.selectedEmitterIndex;
    return EditorContextMenu(
      items: [
        MenuButton(
          onPressed: (_) => vm.duplicateEmitter(index),
          child: const Text('Duplicate Emitter'),
        ),
        MenuButton(
          onPressed: (_) => _promptRename(index),
          child: const Text('Rename Emitter'),
        ),
        MenuButton(
          onPressed: (_) => _confirmDelete(index),
          enabled: vm.emitters.length > 1,
          child: const Text('Delete Emitter'),
        ),
      ],
      child: GestureDetector(
        onTap: () => vm.selectEmitter(index),
        child: Container(
          key: ValueKey('particle_emitter_row_$index'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: selected ? EditorColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          child: Row(
            children: [
              Checkbox(
                key: ValueKey('particle_emitter_enabled_$index'),
                state: entry.enabled ? CheckboxState.checked : CheckboxState.unchecked,
                onChanged: (s) => vm.setEmitterEnabled(index, s == CheckboxState.checked),
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.sparkles, size: 12, color: EditorColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.enabled ? EditorColors.foreground : EditorColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptRename(int index) {
    final controller = TextEditingController(text: vm.emitters[index].name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
      title: const Text('Rename Emitter'),
      content: TextField(controller: controller, key: const ValueKey('particle_rename_field')),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(
          onPressed: () {
            vm.renameEmitter(index, controller.text);
            Navigator.of(context).pop();
          },
          child: const Text('Rename'),
        ),
      ],
      ),
    );
  }

  void _confirmDelete(int index) {
    final name = vm.emitters[index].name;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
      title: const Text('Delete Emitter'),
      content: Text('Delete "$name" from this particle system?'),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        DestructiveButton(
          key: const ValueKey('particle_delete_confirm'),
          onPressed: () {
            vm.deleteEmitter(index);
            Navigator.of(context).pop();
          },
          child: const Text('Delete'),
        ),
      ],
      ),
    );
  }

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

  // ------------------------------------------------------------ right panel

  Widget _rightPanel() {
    return Container(
      color: EditorColors.card,
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

  // ---------------------------------------------------------------- helpers

  Widget _vector3Row(String keyPrefix, Vector3 v, void Function(Vector3) onCommit) {
    return Row(
      children: [
        for (var axis = 0; axis < 3; axis++) ...[
          Expanded(
            child: _NumField(
              fieldKey: ValueKey('particle_${keyPrefix}_${['x', 'y', 'z'][axis]}'),
              value: v[axis],
              onCommit: (nv) {
                final next = Vector3.copy(v);
                next[axis] = nv;
                onCommit(next);
              },
            ),
          ),
          if (axis < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, {List<Widget> trailing = const []}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 3),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _error(String field) {
    final message = vm.errorFor(field);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        message,
        key: ValueKey('particle_error_$field'),
        style: const TextStyle(fontSize: 8, color: EditorColors.logError),
      ),
    );
  }
}

/// Numeric field committing on Enter / focus loss — `maxParticles` re-allocates
/// the pool, so per-keystroke commits are exactly what we must avoid.
class _NumField extends StatefulWidget {
  final ValueKey<String> fieldKey;
  final double value;
  final bool isInt;
  final void Function(double) onCommit;

  const _NumField({
    required this.fieldKey,
    required this.value,
    required this.onCommit,
    this.isInt = false,
  });

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  String get _formatted => widget.isInt ? widget.value.round().toString() : _trim(widget.value);

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatted);
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus) _commit(_controller.text);
      });
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _controller.text = _formatted;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) {
      _controller.text = _formatted;
      return;
    }
    widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        focusNode: _focus,
        style: const TextStyle(fontSize: 9.5),
        onSubmitted: _commit,
      ),
    );
  }
}

/// Default engine config, re-exported for callers building a fresh document.
LuminaParticleEmitterConfig particleEmitterDefaults() => LuminaParticleEmitterConfig();
