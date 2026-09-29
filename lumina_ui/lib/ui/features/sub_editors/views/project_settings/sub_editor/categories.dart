part of '../../project_settings_sub_editor.dart';

/// Engine & Graphics, Maps & Modes, Physics & Collision and User
/// Interface categories.
mixin _ProjectSettingsCategories on _ProjectSettingsSubEditorStateBase {

  @override
  Widget _buildGraphics() {
    final s = _vm.project.settings;
    final preset = s.qualityPreset.toLowerCase();
    return Column(children: [
      _section('Quality Preset', [
        _row(
          'Quality Preset',
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final name in kQualityPresets)
                (preset == name.toLowerCase() ? PrimaryButton.new : SecondaryButton.new)(
                  key: ValueKey('project_settings_preset_$name'),
                  onPressed: () => _vm.setQualityPreset(name),
                  child: Text(name, style: const TextStyle(fontSize: 10)),
                ),
              if (preset == 'custom') const OutlineBadge(child: Text('Custom', style: TextStyle(fontSize: 9))),
            ],
          ),
          help: 'Expands every category below instantly; Apply commits',
        ),
        _row('View Distance', _select(s.scalability.viewDistance, _tiers, (v) => _vm.setScalabilityField('viewDistance', v))),
        _row('Shadow Quality', _select(s.scalability.shadowQuality, _tiers, (v) => _vm.setScalabilityField('shadowQuality', v))),
        _row('Anti-Aliasing', _select(s.scalability.antiAliasing, _aaModes, (v) => _vm.setScalabilityField('antiAliasing', v), label: (v) => v.toUpperCase())),
        _row('Post Processing', _select(s.scalability.postProcessing, _tiers, (v) => _vm.setScalabilityField('postProcessing', v))),
        _row('Texture Quality', _select(s.scalability.textureQuality, _tiers, (v) => _vm.setScalabilityField('textureQuality', v))),
        _row('Shading Quality', _select(s.scalability.shadingQuality, _tiers, (v) => _vm.setScalabilityField('shadingQuality', v))),
      ]),
      _section('Frame Rate', [
        _row(
          'Target FPS',
          Row(children: [
            Expanded(
              child: SliderField(
                key: const ValueKey('project_settings_target_fps'),
                value: s.targetFps.toDouble(),
                defaultValue: 60,
                min: 0,
                max: 240,
                unit: 'FPS',
                fractionDigits: 0,
                onChanged: (v) => _vm.setTargetFps(v.round()),
                onCommit: (v) => _vm.setTargetFps(v.round()),
                onReset: () => _vm.setTargetFps(60),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Text(
                s.targetFps == 0 ? 'Unlimited (0 FPS)' : '${s.targetFps} FPS',
                key: const ValueKey('project_settings_target_fps_label'),
                style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
              ),
            ),
          ]),
          help: '0 = unlimited',
        ),
        _row(
          'VSync',
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(key: const ValueKey('project_settings_vsync'), value: s.vsyncEnabled, onChanged: _vm.setVSync),
          ),
          help: 'Default off',
        ),
      ]),
    ]);
  }

  // Maps & Modes
  @override
  Widget _buildMapsAndModes() {
    final mm = _vm.project.mapsAndModes;
    final levelPaths = ['', ..._vm.levels.map((l) => l.relativePath)];
    String levelLabel(String p) => p.isEmpty ? '(none)' : _vm.levels.firstWhere((l) => l.relativePath == p, orElse: () => LevelChoice(relativePath: p, displayName: p)).displayName;
    return _section('Maps & Modes', [
      _row('Editor Startup Map', _select(mm.editorStartupMap, {...levelPaths, mm.editorStartupMap}.toList(), _vm.setEditorStartupMap, label: levelLabel),
          help: 'LEVEL assets under contents/levels'),
      _row('Game Default Map', _select(mm.gameDefaultMap, {...levelPaths, mm.gameDefaultMap}.toList(), _vm.setGameDefaultMap, label: levelLabel),
          help: 'First level the shipped game loads'),
      _row(
          'Default Game Mode',
          _select(mm.defaultGameMode, {..._vm.gameModeClasses, mm.defaultGameMode}.toList(), _vm.setDefaultGameMode,
              label: (v) => v.endsWith('.lmas') ? '${v.split('/').last.replaceAll('.lmas', '')} (Blueprint)' : v),
          help: 'A Dart game mode, or a GameMode Blueprint'),
      _row(
          'Default Pawn Class',
          _select(mm.defaultPawnClass, {..._vm.pawnClasses, mm.defaultPawnClass}.toList(), _vm.setDefaultPawnClass,
              label: (v) => v.isEmpty ? '(from game mode)' : v.split('/').last.replaceAll('.lmas', '')),
          help: 'Overrides the game mode\'s pawn: a Pawn or Character Blueprint'),
      if (_vm.levels.isEmpty)
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Text('No LEVEL assets found in this project yet.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ),
    ]);
  }

  // Physics & Collision
  @override
  Widget _buildPhysics() {
    final ph = _vm.project.physics;
    return _section('Physics & Collision', [
      _row(
        'Gravity Z',
        TextField(
          key: const ValueKey('project_settings_gravity'),
          controller: _controllerFor('gravity', ph.gravityZ.toString()),
          focusNode: _focusFor('gravity'),
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null) _vm.setGravityZ(d);
          },
        ),
        help: 'cm/s², default -980',
      ),
      _row(
        'Fixed Timestep',
        TextField(
          key: const ValueKey('project_settings_timestep'),
          controller: _controllerFor('timestep', ph.fixedTimestep.toStringAsFixed(4)),
          focusNode: _focusFor('timestep'),
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null) _vm.setFixedTimestep(d);
          },
        ),
        help: 'seconds per physics step',
      ),
    ]);
  }

  // Packaging & Target
  // User Interface
  @override
  Widget _buildUserInterface() {
    final library = _vm.project.ui.widgetLibrary;
    return _section('User Interface', [
      _row(
        'UMG Widget Library',
        KeyedSubtree(
          key: const ValueKey('project_settings_widget_library'),
          child: _select(library, kUmgWidgetLibraries, _vm.setWidgetLibrary, label: ProjectSettingsViewModel.widgetLibraryLabel),
        ),
        help: library == kUmgWidgetLibraryFlutter
            ? "Generated widgets use Flutter's own widgets and the engine's LuminaUmg set; the game needs no extra dependency and its web build is smaller."
            : 'Generated widgets use shadcn_flutter (the look of the editor); the game depends on shadcn_flutter $kGameShadcnFlutterVersion.',
      ),
      // What a switch to plain Flutter leaves without a widget.
      if (_vm.shadcnWidgetsBlockingPlain case final blocking when blocking.isNotEmpty)
        Padding(
          key: const ValueKey('project_settings_shadcn_widgets'),
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'These shadcn components need the shadcn widget library and will not compile with plain Flutter widgets:\n${blocking.map((w) => '• $w').join('\n')}',
            style: const TextStyle(fontSize: 9.5, color: EditorColors.logWarning),
          ),
        ),
      if (_vm.widgetLibraryStatus != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_vm.widgetLibraryStatus!, key: const ValueKey('project_settings_widget_library_status'), style: const TextStyle(fontSize: 9.5)),
        ),
      if (_vm.widgetLibraryError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_vm.widgetLibraryError!, style: const TextStyle(fontSize: 9.5, color: EditorColors.logError)),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Apply & Save updates pubspec.yaml, runs flutter pub get and regenerates every UMG widget in lib/widgets/.',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ),
    ]);
  }
}

// Engine & Graphics
const _tiers = ['low', 'medium', 'high', 'epic', 'cinematic'];

const _aaModes = ['none', 'fxaa', 'msaa', 'taa'];
