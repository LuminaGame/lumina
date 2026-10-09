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
        _row('View Distance', _select(s.scalability.viewDistance, _tiers, (v) => _vm.setScalabilityField('viewDistance', v)), help: _viewDistanceHelp(s.scalability.viewDistance)),
        _row('Shadow Quality', _select(s.scalability.shadowQuality, _tiers, (v) => _vm.setScalabilityField('shadowQuality', v)), help: _shadowQualityHelp(s.scalability.shadowQuality)),
        _row('Anti-Aliasing', _select(s.scalability.antiAliasing, _aaModes, (v) => _vm.setScalabilityField('antiAliasing', v), label: (v) => v.toUpperCase()), help: _antiAliasingHelp(s.scalability.antiAliasing)),
        _row('Post Processing', _select(s.scalability.postProcessing, _tiers, (v) => _vm.setScalabilityField('postProcessing', v)), help: _postProcessingHelp(s.scalability.postProcessing)),
        _row('Texture Quality', _select(s.scalability.textureQuality, _tiers, (v) => _vm.setScalabilityField('textureQuality', v)), help: _textureQualityHelp(s.scalability.textureQuality)),
        _row('Shading Quality', _select(s.scalability.shadingQuality, _tiers, (v) => _vm.setScalabilityField('shadingQuality', v)), help: _shadingQualityHelp(s.scalability.shadingQuality)),
        _buildPresetTechnicalSpecsCard(preset),
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
        _row(
          'Start Fullscreen',
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              key: const ValueKey('project_settings_start_fullscreen'),
              value: s.startFullscreen,
              onChanged: _vm.setStartFullscreen,
            ),
          ),
          help: 'Borderless fullscreen over the whole monitor (taskbar included) at native resolution; Alt+Enter / F11 toggle',
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

  Widget _buildPresetTechnicalSpecsCard(String currentPreset) {
    const specs = [
      (
        name: 'Low',
        dist: '250 m (25k cm)',
        shadows: '512px PCF, 1 cascade',
        aa: 'None',
        post: 'Low HDR',
        tex: '1/4 Res (+2 LOD)',
        shading: 'Simple PBR (50% Min Res)',
      ),
      (
        name: 'Medium',
        dist: '500 m (50k cm)',
        shadows: '1024px PCF, 2 cascades',
        aa: 'FXAA',
        post: 'Med HDR (Bloom)',
        tex: '1/2 Res (+1 LOD)',
        shading: 'Standard PBR (75% Min Res)',
      ),
      (
        name: 'High',
        dist: '1,000 m (100k cm)',
        shadows: '2048px VSM, 3 cascades (2x aniso)',
        aa: 'FXAA',
        post: 'High HDR (Bloom, Vignette)',
        tex: 'Full Res (4x aniso)',
        shading: 'Full PBR (100% Native, SSR)',
      ),
      (
        name: 'Epic',
        dist: '2,000 m (200k cm)',
        shadows: '4096px PCSS, 4 cascades (8-step contact)',
        aa: 'TAA',
        post: 'Ultra HDR (ACES grading)',
        tex: 'Full Res (8x aniso)',
        shading: 'Ultra PBR (SSR + AO)',
      ),
      (
        name: 'Cinematic',
        dist: '4,000 m (400k cm)',
        shadows: '4096px PCSS, 4 cascades (16-step contact, lambda 0.4)',
        aa: '4x MSAA + TAA',
        post: 'Ultra HDR (DoF + Cinematic Stack)',
        tex: 'Uncompressed (16x aniso)',
        shading: 'Ultra PBR (Max SSR & Sample Fidelity)',
      ),
    ];

    return Container(
      key: const ValueKey('project_settings_preset_specs_card'),
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.info, size: 13, color: EditorColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Preset Technical Specifications / Preset Teknik Karşılıkları',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorColors.foreground),
              ),
              const Spacer(),
              if (currentPreset.isNotEmpty)
                OutlineBadge(
                  child: Text(
                    'Active: ${currentPreset[0].toUpperCase()}${currentPreset.substring(1)}',
                    style: const TextStyle(fontSize: 8.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: EditorColors.border.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSpecCell('Preset', width: 75, isHeader: true),
                      _buildSpecCell('View Distance', width: 120, isHeader: true),
                      _buildSpecCell('Shadows', width: 220, isHeader: true),
                      _buildSpecCell('Anti-Aliasing', width: 100, isHeader: true),
                      _buildSpecCell('Post Processing', width: 180, isHeader: true),
                      _buildSpecCell('Textures', width: 160, isHeader: true),
                      _buildSpecCell('Shading', width: 180, isHeader: true),
                    ],
                  ),
                ),
                for (final row in specs)
                  Container(
                    decoration: BoxDecoration(
                      color: row.name.toLowerCase() == currentPreset.toLowerCase()
                          ? EditorColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSpecCell(
                          row.name,
                          width: 75,
                          isHighlighted: row.name.toLowerCase() == currentPreset.toLowerCase(),
                        ),
                        _buildSpecCell(row.dist, width: 120),
                        _buildSpecCell(row.shadows, width: 220),
                        _buildSpecCell(row.aa, width: 100),
                        _buildSpecCell(row.post, width: 180),
                        _buildSpecCell(row.tex, width: 160),
                        _buildSpecCell(row.shading, width: 180),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '• Cinematic: Tasarlanmış en yüksek kalite modu; 4,000 m (4 km) görüş mesafesi, 4096px PCSS gölgeler (16 adımlı temas gölgesi, lambda 0.4), 4x MSAA + TAA ve tam doku kalitesi sağlar. Oyun içi yüksek kare hızları için Epic veya High önerilir.',
            style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static Widget _buildSpecCell(
    String text, {
    required double width,
    bool isHeader = false,
    bool isHighlighted = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader
              ? FontWeight.bold
              : (isHighlighted ? FontWeight.bold : FontWeight.normal),
          color: isHeader
              ? EditorColors.foreground
              : (isHighlighted ? EditorColors.primary : EditorColors.mutedForeground),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Engine & Graphics
const _tiers = ['low', 'medium', 'high', 'epic', 'cinematic'];

const _aaModes = ['none', 'fxaa', 'msaa', 'taa'];

String _viewDistanceHelp(String tier) {
  switch (tier.toLowerCase()) {
    case 'low': return '250 m (25,000 cm) far clip plane';
    case 'medium': return '500 m (50,000 cm) far clip plane';
    case 'high': return '1,000 m (100,000 cm) far clip plane';
    case 'epic': return '2,000 m (200,000 cm) far clip plane';
    case 'cinematic': return '4,000 m (400,000 cm) far clip plane';
    default: return 'Camera far clip plane and cull distance';
  }
}

String _shadowQualityHelp(String tier) {
  switch (tier.toLowerCase()) {
    case 'low': return '512×512 map, 1 cascade (PCF filtering)';
    case 'medium': return '1024×1024 map, 2 cascades (PCF, practical split 0.5)';
    case 'high': return '2048×2048 map, 3 cascades (VSM, 2x aniso, stable splits)';
    case 'epic': return '4096×4096 map, 4 cascades (PCSS soft shadows, 8-step contact)';
    case 'cinematic': return '4096×4096 map, 4 cascades (PCSS, 16-step contact, lambda 0.4)';
    default: return 'Shadow map resolution, cascade count and filtering';
  }
}

String _antiAliasingHelp(String mode) {
  switch (mode.toLowerCase()) {
    case 'none': return 'No anti-aliasing (lowest overhead)';
    case 'fxaa': return 'Fast Approximate AA (screen-space blur pass)';
    case 'msaa': return 'Hardware Multi-Sample AA (4x sample count)';
    case 'taa': return 'Temporal Anti-Aliasing (sub-pixel jitter history buffer)';
    default: return 'Edge smoothing and temporal stability';
  }
}

String _postProcessingHelp(String tier) {
  switch (tier.toLowerCase()) {
    case 'low': return 'Low HDR buffer, simple tonemapping, minimal bloom';
    case 'medium': return 'Medium HDR buffer, bloom, standard tonemapping';
    case 'high': return 'High HDR buffer, bloom, vignette, chromatic aberration';
    case 'epic': return 'Ultra HDR buffer, full HDR bloom, ACES tonemap & grading';
    case 'cinematic': return 'Ultra HDR buffer, full depth of field & cinematic grading';
    default: return 'HDR color buffer precision and camera post-process stack';
  }
}

String _textureQualityHelp(String tier) {
  switch (tier.toLowerCase()) {
    case 'low': return '1/4 texture resolution (MIP LOD bias +2, 1x bilinear)';
    case 'medium': return '1/2 texture resolution (MIP LOD bias +1, 2x trilinear)';
    case 'high': return 'Full texture resolution (MIP LOD bias 0, 4x anisotropic)';
    case 'epic': return 'Full texture resolution (8x anisotropic filtering)';
    case 'cinematic': return 'Full uncompressed resolution (16x anisotropic filtering)';
    default: return 'Texture mipmap resolution limit and anisotropic filtering';
  }
}

String _shadingQualityHelp(String tier) {
  switch (tier.toLowerCase()) {
    case 'low': return 'Simple PBR, dynamic resolution scaling (50% min scale), no SSR';
    case 'medium': return 'Standard PBR, dynamic resolution scaling (75% min scale)';
    case 'high': return 'Full PBR, native 100% resolution, screen-space reflections (SSR)';
    case 'epic': return 'Ultra PBR, ultra HDR buffer, SSR & screen-space reflections, AO';
    case 'cinematic': return 'Ultra PBR, 4x MSAA + TAA + max quality SSR and reflections';
    default: return 'PBR lighting model, dynamic resolution scaling, and SSR';
  }
}
