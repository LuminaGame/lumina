import 'dart:async';
import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina/lumina.dart' show AssetType, RealAssetInfo;

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

/// Environment Lighting mixer: sun + time of day, sky/IBL, height
/// fog and post-process controls that drive a real lumina world in the
/// viewport and persist into the level's environment actors.
class EnvironmentLightingSubEditor extends StatefulWidget {
  final String assetName;
  final EditorViewModel? editorViewModel;
  final EnvironmentLightingViewModel? viewModel;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  const EnvironmentLightingSubEditor({
    super.key,
    required this.assetName,
    this.editorViewModel,
    this.viewModel,
    this.onBind,
    this.onClose,
  });

  @override
  State<EnvironmentLightingSubEditor> createState() => _EnvironmentLightingSubEditorState();
}

class _EnvironmentLightingSubEditorState extends State<EnvironmentLightingSubEditor> {
  EnvironmentLightingViewModel? _vm;
  bool _ownsVm = false;

  @override
  void initState() {
    super.initState();
    final editor = widget.editorViewModel ?? widget.viewModel?.editor;
    if (widget.viewModel != null) {
      _vm = widget.viewModel;
    } else if (editor != null) {
      _vm = EnvironmentLightingViewModel(editor: editor);
      _ownsVm = true;
    }
    final vm = _vm;
    if (vm != null) {
      vm.addListener(_onVmChanged);
      widget.onBind?.call(vm, vm.save, () => vm.isDirty);
      if (vm.isOpened) return;
      // open() creates the level's environment actors and marks the level
      // dirty (EditorViewModel.notifyListeners): defer past this build.
      scheduleMicrotask(() {
        if (mounted) vm.open();
      });
    }
  }

  /// The mixer's view model (tests reach the live instance through the state).
  @visibleForTesting
  EnvironmentLightingViewModel? get viewModelForTest => _vm;

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    if (_ownsVm) _vm?.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    final vm = _vm;
    if (vm != null && vm.isDirty) {
      showOverlay(
        context,
        const DialogConfiguration(),
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsaved Environment Changes'),
          content: Text('Save the environment of "${vm.editor.activeLevelName}" before closing?'),
          actions: [
            GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
            DestructiveButton(
              child: const Text('Discard'),
              onPressed: () {
                closeOverlay(dialogContext);
                widget.onClose?.call();
              },
            ),
            PrimaryButton(
              child: const Text('Save'),
              onPressed: () async {
                closeOverlay(dialogContext);
                await vm.save();
                widget.onClose?.call();
              },
            ),
          ],
        ),
      );
      return;
    }
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return Column(
        children: [
          _toolbar(null),
          const Expanded(
            child: Center(
              child: Text(
                'The Environment mixer edits the open level — open a project first.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _toolbar(vm),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 272, child: _SunPanel(vm: vm)),
              Expanded(child: _viewport(vm)),
              SizedBox(width: 292, child: _RightPanel(vm: vm)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(EnvironmentLightingViewModel? vm) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('ENVIRONMENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
          const SizedBox(width: 8),
          Text(
            vm != null ? '${vm.editor.activeLevelName} — Atmosphere Mixer' : widget.assetName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          if (vm != null && vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('env_dirty_indicator'),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
            ),
          ],
          const SizedBox(width: 10),
          if (vm != null)
            Text(
              vm.isPreviewAttached ? 'Preview: live lumina world' : 'Preview: waiting for renderer',
              key: const ValueKey('env_preview_status'),
              style: TextStyle(
                fontSize: 8,
                color: vm.isPreviewAttached ? EditorColors.logSuccess : EditorColors.mutedForeground,
              ),
            ),
          const Spacer(),
          if (vm != null) ...[
            OutlineButton(
              key: const ValueKey('env_reset'),
              onPressed: vm.resetToDefaults,
              child: const Text('Reset to Defaults', style: TextStyle(fontSize: 9)),
            ),
            const SizedBox(width: 6),
            PrimaryButton(
              key: const ValueKey('env_save'),
              onPressed: () => vm.save(),
              child: const Text('Save', style: TextStyle(fontSize: 9)),
            ),
          ],
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GhostButton(
              onPressed: _handleClose,
              child: const Icon(LucideIcons.x, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _viewport(EnvironmentLightingViewModel vm) {
    final s = vm.state;
    final skyLabel = s.skyMode == EnvironmentSkyMode.color
        ? 'Sky: Color ${s.skyColorHex}'
        : 'Sky: HDRI ${s.skyEnvironmentAssetPath?.split('/').last ?? '(none)'}';
    return SubEditor3DViewport(
      title: 'Environment',
      showShapeSelector: false,
      yUpCamera: true,
      initialCameraDistance: 900.0,
      statsLabel: vm.isPreviewAttached
          ? 'Level meshes: ${vm.preview.meshActorCount}  ·  Sun ${s.sunIntensityLux.round()} lx  ·  Renderer: Filament C++ via lumina'
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
                  key: const ValueKey('env_hud'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Text(
                    '${vm.timeLabel}  ·  Sun ${s.sunElevationDeg.toStringAsFixed(1)}° / ${s.sunAzimuthDeg.toStringAsFixed(1)}°  ·  $skyLabel',
                    style: const TextStyle(fontSize: 9, color: Colors.amber, fontFamily: EditorTypography.monoFamily),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 36,
              child: SunGizmo(
                key: const ValueKey('env_sun_gizmo'),
                elevationDeg: s.sunElevationDeg,
                azimuthDeg: s.sunAzimuthDeg,
                sunColor: vm.effectiveSunColor,
                onDrag: (az, el) => vm.setSunFromGizmo(az, el, commit: false),
                onDragEnd: () => vm.setSunFromGizmo(vm.state.sunAzimuthDeg, vm.state.sunElevationDeg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left panel: Sun & Time of Day
// ---------------------------------------------------------------------------

class _SunPanel extends StatelessWidget {
  final EnvironmentLightingViewModel vm;
  const _SunPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final s = vm.state;
    final kelvinColor = SolarMath.kelvinToRgb(s.sunKelvin);
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Card(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sun & Time of Day', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
              const SizedBox(height: 8),
              Text(
                vm.timeLabel,
                key: const ValueKey('env_time_label'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              SliderField(
                key: const ValueKey('env_time_slider'),
                value: s.timeOfDay,
                defaultValue: EnvironmentState.defaultTimeOfDay,
                min: 0.0,
                max: 24.0,
                unit: 'h',
                onChanged: (v) => vm.setTimeOfDay(v, commit: false),
                onCommit: (v) => vm.setTimeOfDay(v),
                onReset: () => vm.setTimeOfDay(EnvironmentState.defaultTimeOfDay),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SecondaryBadge(
                    key: const ValueKey('env_elevation_badge'),
                    child: Text('Elevation ${s.sunElevationDeg.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 8)),
                  ),
                  const SizedBox(width: 4),
                  SecondaryBadge(
                    key: const ValueKey('env_azimuth_badge'),
                    child: Text('Azimuth ${s.sunAzimuthDeg.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label('Sun Intensity (lux)'),
              SliderField(
                key: const ValueKey('env_sun_intensity'),
                value: s.sunIntensityLux,
                defaultValue: EnvironmentState.defaultSunIntensityLux,
                min: 0.0,
                max: 150000.0,
                unit: 'lx',
                onChanged: (v) => vm.setSunIntensity(v, commit: false),
                onCommit: vm.setSunIntensity,
                onReset: () => vm.setSunIntensity(EnvironmentState.defaultSunIntensityLux),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _label('Temperature (K)'),
                  const Spacer(),
                  Container(
                    key: const ValueKey('env_kelvin_swatch'),
                    width: 34,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _toColor(kelvinColor),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: EditorColors.border),
                    ),
                  ),
                ],
              ),
              SliderField(
                key: const ValueKey('env_sun_kelvin'),
                value: s.sunKelvin,
                defaultValue: EnvironmentState.defaultSunKelvin,
                min: 1500.0,
                max: 15000.0,
                unit: 'K',
                onChanged: (v) => vm.setSunKelvin(v, commit: false),
                onCommit: vm.setSunKelvin,
                onReset: () => vm.setSunKelvin(EnvironmentState.defaultSunKelvin),
              ),
              const SizedBox(height: 8),
              _switchRow('Manual Color Override', s.sunColorOverride, vm.setSunColorOverride, const ValueKey('env_color_override')),
              const SizedBox(height: 4),
              Opacity(
                opacity: s.sunColorOverride ? 1.0 : 0.45,
                child: IgnorePointer(
                  ignoring: !s.sunColorOverride,
                  child: ColorField(
                    key: const ValueKey('env_sun_color'),
                    value: s.sunColorOverride ? s.sunColorHex : s.effectiveSunColorHex,
                    defaultValue: SolarMath.rgbToHex(SolarMath.kelvinToRgb(EnvironmentState.defaultSunKelvin)),
                    onChanged: (h) => vm.setSunColorHex(h, commit: false),
                    onCommit: vm.setSunColorHex,
                    onReset: () => vm.setSunColorHex(SolarMath.rgbToHex(SolarMath.kelvinToRgb(EnvironmentState.defaultSunKelvin))),
                  ),
                ),
              ),
              if (!s.sunColorOverride)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Colour follows the Kelvin ramp', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                ),
              const SizedBox(height: 8),
              _switchRow('Cast Shadows', s.castShadows, vm.setCastShadows, const ValueKey('env_cast_shadows')),
              const SizedBox(height: 4),
              _switchRow('Sun Disc Visible', s.sunDiscVisible, vm.setSunDiscVisible, const ValueKey('env_sun_disc')),
              const SizedBox(height: 8),
              Text(
                'Direction ${vm.sunDirection.x.toStringAsFixed(2)}, ${vm.sunDirection.y.toStringAsFixed(2)}, ${vm.sunDirection.z.toStringAsFixed(2)}',
                key: const ValueKey('env_direction_label'),
                style: const TextStyle(fontSize: 8, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground));

Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, Key key) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
      Switch(key: key, value: value, onChanged: onChanged),
    ],
  );
}

Color _toColor(Vector3 rgb) => Color.fromARGB(
      255,
      (rgb.x.clamp(0.0, 1.0) * 255).round(),
      (rgb.y.clamp(0.0, 1.0) * 255).round(),
      (rgb.z.clamp(0.0, 1.0) * 255).round(),
    );

/// Compass-style sun gizmo drawn over the viewport: the ring is the horizon
/// (N up, E right), the centre is the zenith. Dragging the disc sets azimuth
/// (angle) and elevation (distance from the centre) directly; the time slider
/// follows through the view model.
class SunGizmo extends StatelessWidget {
  final double elevationDeg;
  final double azimuthDeg;
  final Vector3 sunColor;
  final void Function(double azimuthDeg, double elevationDeg) onDrag;
  final VoidCallback onDragEnd;
  final double size;

  const SunGizmo({
    super.key,
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.sunColor,
    required this.onDrag,
    required this.onDragEnd,
    this.size = 132.0,
  });

  double get _ringRadius => size / 2 - 10;

  /// Azimuth/elevation for a pointer position inside the gizmo.
  ({double azimuth, double elevation}) anglesAt(Offset local) {
    final c = Offset(size / 2, size / 2);
    final v = local - c;
    var az = math.atan2(v.dx, -v.dy) * 180.0 / math.pi;
    if (az < 0) az += 360.0;
    final r = (v.distance / _ringRadius).clamp(0.0, 1.0);
    return (azimuth: az, elevation: (1.0 - r) * 90.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        final a = anglesAt(d.localPosition);
        onDrag(a.azimuth, a.elevation);
      },
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SunGizmoPainter(
            elevationDeg: elevationDeg,
            azimuthDeg: azimuthDeg,
            ringRadius: _ringRadius,
            sunColor: _toColor(sunColor),
          ),
        ),
      ),
    );
  }
}

class _SunGizmoPainter extends CustomPainter {
  final double elevationDeg;
  final double azimuthDeg;
  final double ringRadius;
  final Color sunColor;

  _SunGizmoPainter({
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.ringRadius,
    required this.sunColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2, Paint()..color = Colors.black.withValues(alpha: 0.55));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = EditorColors.border;
    canvas.drawCircle(c, ringRadius, ring);
    canvas.drawCircle(c, ringRadius * 0.5, ring..color = EditorColors.border.withValues(alpha: 0.6));
    canvas.drawLine(Offset(c.dx - ringRadius, c.dy), Offset(c.dx + ringRadius, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - ringRadius), Offset(c.dx, c.dy + ringRadius), ring);

    // Day arc: sunrise (E) → zenith → sunset (W).
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.amber.withValues(alpha: 0.35);
    final path = Path();
    for (var h = 6.0; h <= 18.0; h += 0.5) {
      final a = SolarMath.anglesForTime(h);
      final p = _pos(c, a.elevation, a.azimuth);
      if (h == 6.0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, arc);

    for (final (label, angle) in [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final rad = angle * math.pi / 180.0;
      final p = c + Offset(math.sin(rad), -math.cos(rad)) * (ringRadius + 6);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 7, color: EditorColors.mutedForeground)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final below = elevationDeg < 0;
    final sunPos = _pos(c, elevationDeg, azimuthDeg);
    canvas.drawLine(c, sunPos, Paint()..color = sunColor.withValues(alpha: below ? 0.25 : 0.6)..strokeWidth = 1.0);
    canvas.drawCircle(sunPos, below ? 4.0 : 6.5, Paint()..color = sunColor.withValues(alpha: below ? 0.35 : 1.0));
    canvas.drawCircle(sunPos, below ? 4.0 : 6.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.white.withValues(alpha: 0.7));
  }

  Offset _pos(Offset c, double el, double az) {
    final r = (1.0 - el.clamp(0.0, 90.0) / 90.0) * ringRadius;
    final rad = az * math.pi / 180.0;
    return c + Offset(math.sin(rad) * r, -math.cos(rad) * r);
  }

  @override
  bool shouldRepaint(covariant _SunGizmoPainter old) =>
      old.elevationDeg != elevationDeg || old.azimuthDeg != azimuthDeg || old.sunColor != sunColor;
}
