part of '../environment_lighting_sub_editor.dart';

// ---------------------------------------------------------------------------
// Right panel: Sky & Ambient / Height Fog / Post Process
// ---------------------------------------------------------------------------

class _RightPanel extends StatelessWidget {
  final EnvironmentLightingViewModel vm;
  const _RightPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Accordion(
          items: [
            AccordionItem(
              expanded: true,
              trigger: const AccordionTrigger(child: Text('Sky & Ambient', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: _skySection(context),
            ),
            AccordionItem(
              trigger: const AccordionTrigger(child: Text('Height Fog', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: _fogSection(),
            ),
            AccordionItem(
              trigger: const AccordionTrigger(child: Text('Post Process', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: _postProcessSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skySection(BuildContext context) {
    final s = vm.state;
    final hdri = vm.hdriAssets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Mode'),
        const SizedBox(height: 4),
        Select<EnvironmentSkyMode>(
          key: const ValueKey('env_sky_mode'),
          value: s.skyMode,
          onChanged: (m) {
            if (m != null) vm.setSkyMode(m);
          },
          itemBuilder: (context, m) => Text(_skyModeLabel(m), style: const TextStyle(fontSize: 9.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: EnvironmentSkyMode.values
                  .map((m) => SelectItemButton(value: m, child: Text(_skyModeLabel(m))))
                  .toList(),
            ),
          ).call,
        ),
        const SizedBox(height: 8),
        if (s.skyMode == EnvironmentSkyMode.color) ...[
          _label('Sky Color'),
          ColorField(
            key: const ValueKey('env_sky_color'),
            value: s.skyColorHex,
            defaultValue: EnvironmentState.defaultSkyColorHex,
            onChanged: (h) => vm.setSkyColorHex(h, commit: false),
            onCommit: vm.setSkyColorHex,
            onReset: () => vm.setSkyColorHex(EnvironmentState.defaultSkyColorHex),
          ),
        ] else ...[
          _label('HDRI Environment (.ktx)'),
          const SizedBox(height: 4),
          if (hdri.isEmpty)
            const Text(
              'No .ktx / .ktx2 environment maps under contents/ — import one to light the level with an HDRI.',
              key: ValueKey('env_sky_asset_empty'),
              style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
            )
          else
            AssetPickerSelect(
              key: const ValueKey('env_sky_asset'),
              keyPrefix: 'env_sky_asset',
              // The .ktx / .ktx2 maps are files, not .lmas assets: each is
              // offered as a texture under its project path.
              assets: [
                for (final p in hdri)
                  RealAssetInfo(fileName: p.split('/').last, relativePath: p, type: AssetType.texture, bytes: 0),
              ],
              selectedPath: hdri.contains(s.skyEnvironmentAssetPath) ? s.skyEnvironmentAssetPath : null,
              placeholder: 'Pick an environment map',
              allowClear: false,
              onSelected: (a) => vm.setSkyEnvironmentAsset(a.relativePath),
            ),
        ],
        const SizedBox(height: 8),
        _label('Sky Intensity (lux)'),
        SliderField(
          key: const ValueKey('env_sky_intensity'),
          value: s.skyIntensity,
          defaultValue: EnvironmentState.defaultSkyIntensity,
          min: 0.0,
          max: 100000.0,
          onChanged: (v) => vm.setSkyIntensity(v, commit: false),
          onCommit: vm.setSkyIntensity,
          onReset: () => vm.setSkyIntensity(EnvironmentState.defaultSkyIntensity),
        ),
        const SizedBox(height: 6),
        _label('IBL Intensity (lux)'),
        SliderField(
          key: const ValueKey('env_ibl_intensity'),
          value: s.iblIntensity,
          defaultValue: EnvironmentState.defaultIblIntensity,
          min: 0.0,
          max: 100000.0,
          onChanged: (v) => vm.setIblIntensity(v, commit: false),
          onCommit: vm.setIblIntensity,
          onReset: () => vm.setIblIntensity(EnvironmentState.defaultIblIntensity),
        ),
        const SizedBox(height: 6),
        _label('Rotation (°)'),
        SliderField(
          key: const ValueKey('env_sky_rotation'),
          value: s.skyRotationDeg,
          defaultValue: 0.0,
          min: 0.0,
          max: 360.0,
          unit: '°',
          onChanged: (v) => vm.setSkyRotation(v, commit: false),
          onCommit: vm.setSkyRotation,
          onReset: () => vm.setSkyRotation(0.0),
        ),
        const SizedBox(height: 6),
        _switchRow('Follow Time of Day', s.followTimeOfDay, vm.setFollowTimeOfDay, const ValueKey('env_follow_tod')),
      ],
    );
  }

  Widget _fogSection() {
    final s = vm.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A placed Exponential Height Fog wins; this
        // section is only the fallback while one is in the level.
        ListenableBuilder(
          listenable: vm.editor,
          builder: (context, _) {
            final editor = vm.editor;
            final fogActor = EnvironmentActorProperties.heightFogActorOf(editor.actors, isVisible: editor.isEffectivelyVisible);
            if (fogActor == null) return const SizedBox.shrink();
            return const Padding(
              key: ValueKey('env_fog_fallback_note'),
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Fallback only — the level\'s Exponential Height Fog actor overrides this section.',
                style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
              ),
            );
          },
        ),
        _switchRow('Height Fog Enabled', s.fogEnabled, vm.setFogEnabled, const ValueKey('env_fog_enabled')),
        const SizedBox(height: 6),
        _label('Fog Density'),
        SliderField(
          key: const ValueKey('env_fog_density'),
          value: s.fogDensity,
          defaultValue: 0.0,
          min: 0.0,
          max: 0.05,
          onChanged: (v) => vm.setFogDensity(v, commit: false),
          onCommit: vm.setFogDensity,
          onReset: () => vm.setFogDensity(0.0),
        ),
        const SizedBox(height: 6),
        _label('Height Falloff'),
        SliderField(
          key: const ValueKey('env_fog_falloff'),
          value: s.fogHeightFalloff,
          defaultValue: 1.0,
          min: 0.0,
          max: 5.0,
          onChanged: (v) => vm.setFogHeightFalloff(v, commit: false),
          onCommit: vm.setFogHeightFalloff,
          onReset: () => vm.setFogHeightFalloff(1.0),
        ),
        const SizedBox(height: 6),
        _label('Inscattering Color'),
        ColorField(
          key: const ValueKey('env_fog_color'),
          value: s.fogColorHex,
          defaultValue: EnvironmentState.defaultFogColorHex,
          onChanged: (h) => vm.setFogColorHex(h, commit: false),
          onCommit: vm.setFogColorHex,
          onReset: () => vm.setFogColorHex(EnvironmentState.defaultFogColorHex),
        ),
        const SizedBox(height: 4),
        const Text(
          'Maps onto Filament FogOptions (density / height falloff / colour).',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _postProcessSection() {
    final s = vm.state;
    final d = EnvironmentState.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Exposure (EV)'),
        SliderField(
          key: const ValueKey('env_exposure'),
          value: s.exposure,
          defaultValue: d.exposure,
          min: -4.0,
          max: 4.0,
          onChanged: (v) => vm.setExposure(v, commit: false),
          onCommit: vm.setExposure,
          onReset: () => vm.setExposure(d.exposure),
        ),
        const SizedBox(height: 6),
        _label('Bloom Intensity'),
        SliderField(
          key: const ValueKey('env_bloom_intensity'),
          value: s.bloomIntensity,
          defaultValue: d.bloomIntensity,
          min: 0.0,
          max: EnvironmentState.bloomIntensityMax,
          onChanged: (v) => vm.setBloomIntensity(v, commit: false),
          onCommit: vm.setBloomIntensity,
          onReset: () => vm.setBloomIntensity(d.bloomIntensity),
        ),
        const SizedBox(height: 6),
        _label('Bloom Threshold (highlight, lux)'),
        SliderField(
          key: const ValueKey('env_bloom_threshold'),
          value: s.bloomThreshold,
          defaultValue: d.bloomThreshold,
          min: 1.0,
          max: 10000.0,
          onChanged: (v) => vm.setBloomThreshold(v, commit: false),
          onCommit: vm.setBloomThreshold,
          onReset: () => vm.setBloomThreshold(d.bloomThreshold),
        ),
        const SizedBox(height: 6),
        _label('Vignette'),
        SliderField(
          key: const ValueKey('env_vignette'),
          value: s.vignette,
          defaultValue: d.vignette,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => vm.setVignette(v, commit: false),
          onCommit: vm.setVignette,
          onReset: () => vm.setVignette(d.vignette),
        ),
        const SizedBox(height: 6),
        _label('Saturation'),
        SliderField(
          key: const ValueKey('env_saturation'),
          value: s.saturation,
          defaultValue: d.saturation,
          min: 0.0,
          max: 2.0,
          onChanged: (v) => vm.setSaturation(v, commit: false),
          onCommit: vm.setSaturation,
          onReset: () => vm.setSaturation(d.saturation),
        ),
        const SizedBox(height: 6),
        _label('Contrast'),
        SliderField(
          key: const ValueKey('env_contrast'),
          value: s.contrast,
          defaultValue: d.contrast,
          min: 0.5,
          max: 2.0,
          onChanged: (v) => vm.setContrast(v, commit: false),
          onCommit: vm.setContrast,
          onReset: () => vm.setContrast(d.contrast),
        ),
        const SizedBox(height: 6),
        _label('Gamma'),
        SliderField(
          key: const ValueKey('env_gamma'),
          value: s.gamma,
          defaultValue: d.gamma,
          min: 0.2,
          max: 3.0,
          onChanged: (v) => vm.setGamma(v, commit: false),
          onCommit: vm.setGamma,
          onReset: () => vm.setGamma(d.gamma),
        ),
      ],
    );
  }

  static String _skyModeLabel(EnvironmentSkyMode m) => m == EnvironmentSkyMode.color ? 'Color' : 'HDRI Environment';
}
