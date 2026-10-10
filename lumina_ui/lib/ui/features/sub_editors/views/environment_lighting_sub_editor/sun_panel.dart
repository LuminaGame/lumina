part of '../environment_lighting_sub_editor.dart';

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
