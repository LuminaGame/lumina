import 'package:flutter_filament/flutter_filament.dart' show DlssQuality;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaFsr3Quality;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Which of the three viewport HUD controls opened the popover.
enum RtxSettingsKind { dlss, fsr3, rayTracing }

/// The settings behind the viewport's DLSS, FSR3 and RTX HUD buttons: the
/// arrow next to each button opens this popover for its [kind]. Every control changes the
/// editor's per-user [EditorQualitySettings] through the view model, which the
/// live viewport re-applies at once.
class RtxSettingsPopover extends StatelessWidget {
  final EditorViewModel viewModel;
  final RtxSettingsKind kind;
  final VoidCallback onClose;

  /// Whether the engine behind the viewport can do what this popover sets.
  final bool supported;

  const RtxSettingsPopover({
    super.key,
    required this.viewModel,
    required this.kind,
    required this.onClose,
    required this.supported,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final title = switch (kind) {
          RtxSettingsKind.dlss => 'DLSS SUPER RESOLUTION',
          RtxSettingsKind.fsr3 => 'FSR3 UPSCALING',
          RtxSettingsKind.rayTracing => 'RTX RAY TRACING',
        };
        final enabled = switch (kind) {
          RtxSettingsKind.dlss => viewModel.dlssSettings.enabled,
          RtxSettingsKind.fsr3 => viewModel.fsr3Settings.enabled,
          RtxSettingsKind.rayTracing => viewModel.rayTracingSettings.enabled,
        };
        return Container(
          width: 340,
          decoration: BoxDecoration(
            color: EditorColors.card,
            border: Border.all(color: EditorColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: EditorColors.cardHeader,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EditorColors.foreground),
                    ),
                    _Badge(
                      text: !supported ? 'UNAVAILABLE' : (enabled ? 'ON' : 'OFF'),
                      color: !supported ? EditorColors.mutedForeground : (enabled ? EditorColors.primary : EditorColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!supported) ...[
                      Text(
                        switch (kind) {
                          RtxSettingsKind.dlss =>
                            'The NGX runtime was not found or this GPU has no DLSS. Fetch the SDK (dart run tool/dlss/fetch_sdk.dart in flutter_filament) and start the editor again from source: the native library rebuilds with DLSS on the next run. Needs an NVIDIA RTX GPU; the choices below are kept for when it is.',
                          RtxSettingsKind.fsr3 =>
                            'This engine renders no motion vectors (feature level 0), which FSR3 needs. The choices below are kept for a machine that has them.',
                          RtxSettingsKind.rayTracing =>
                            'This GPU or driver has no Vulkan ray query support, or the editor engine was created without it. The choices below are kept for a machine that has it.',
                        },
                        style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                      ),
                      const SizedBox(height: 10),
                    ],
                    switch (kind) {
                      RtxSettingsKind.dlss => _DlssBody(viewModel: viewModel),
                      RtxSettingsKind.fsr3 => _Fsr3Body(viewModel: viewModel),
                      RtxSettingsKind.rayTracing => _RayTracingBody(viewModel: viewModel),
                    },
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Button(
                          key: const ValueKey('rtx_popover_close'),
                          style: const ButtonStyle.primary(),
                          onPressed: onClose,
                          child: const Text('Close', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DlssBody extends StatelessWidget {
  final EditorViewModel viewModel;
  const _DlssBody({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final settings = viewModel.dlssSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          key: const ValueKey('dlss_enabled'),
          label: 'DLSS Super Resolution',
          help: 'Render smaller and let DLSS reconstruct the viewport (TAA with motion vectors is switched on for it).',
          value: settings.enabled,
          onChanged: (_) => viewModel.toggleDlss(),
        ),
        const SizedBox(height: 10),
        const _SectionLabel('QUALITY MODE'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (quality, label) in const [
              (DlssQuality.ultraPerformance, 'Ultra'),
              (DlssQuality.maxPerformance, 'Perf'),
              (DlssQuality.balanced, 'Bal'),
              (DlssQuality.maxQuality, 'Qual'),
              (DlssQuality.dlaa, 'DLAA'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Button(
                    key: ValueKey('dlss_quality_${quality.name}'),
                    style: settings.quality == quality ? const ButtonStyle.primary() : const ButtonStyle.secondary(),
                    onPressed: () => viewModel.setDlssSettings(settings.copyWith(quality: quality)),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: settings.quality == quality ? Colors.black : EditorColors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Ultra Performance renders at about a third of the viewport per axis, Balanced at 58%, Quality at 67%; DLAA keeps the full resolution and only anti-aliases.',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }
}

class _Fsr3Body extends StatelessWidget {
  final EditorViewModel viewModel;
  const _Fsr3Body({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final settings = viewModel.fsr3Settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          key: const ValueKey('fsr3_enabled'),
          label: 'FSR3 upscaling',
          help: 'Render smaller and let FidelityFX Super Resolution 3 reconstruct the viewport on any GPU. DLSS takes precedence while it is on.',
          value: settings.enabled,
          onChanged: (_) => viewModel.toggleFsr3(),
        ),
        const SizedBox(height: 10),
        const _SectionLabel('QUALITY PRESET'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (quality, label) in const [
              (LuminaFsr3Quality.ultraPerformance, 'Ultra'),
              (LuminaFsr3Quality.performance, 'Perf'),
              (LuminaFsr3Quality.balanced, 'Bal'),
              (LuminaFsr3Quality.quality, 'Qual'),
              (LuminaFsr3Quality.nativeAA, 'Native'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Button(
                    key: ValueKey('fsr3_quality_${quality.name}'),
                    style: settings.quality == quality ? const ButtonStyle.primary() : const ButtonStyle.secondary(),
                    onPressed: () => viewModel.setFsr3Settings(settings.copyWith(quality: quality)),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: settings.quality == quality ? Colors.black : EditorColors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Ultra Performance renders at a third of the viewport per axis, Performance at half, Balanced at 59%, Quality at 67%; Native AA keeps the full resolution and only anti-aliases.',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 10),
        const Text('Sharpness', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 2),
        SliderField(
          key: const ValueKey('fsr3_sharpness'),
          fractionDigits: 2,
          value: settings.sharpness,
          defaultValue: 0.5,
          min: 0,
          max: 1,
          onChanged: (v) => viewModel.setFsr3Settings(settings.copyWith(sharpness: v)),
          onCommit: (v) => viewModel.setFsr3Settings(settings.copyWith(sharpness: v)),
          onReset: () => viewModel.setFsr3Settings(settings.copyWith(sharpness: 0.5)),
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          key: const ValueKey('fsr3_frame_generation'),
          label: 'Frame generation',
          help: 'Present an interpolated frame before each rendered one: double the presented rate at half a frame of latency.',
          value: settings.frameGeneration,
          onChanged: (v) => viewModel.setFsr3Settings(settings.copyWith(frameGeneration: v)),
        ),
      ],
    );
  }
}

class _RayTracingBody extends StatelessWidget {
  final EditorViewModel viewModel;
  const _RayTracingBody({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final settings = viewModel.rayTracingSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          key: const ValueKey('rtx_enabled'),
          label: 'Ray Tracing',
          help: 'Keep acceleration structures of the level; the features below need it.',
          value: settings.enabled,
          onChanged: (_) => viewModel.toggleRayTracing(),
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          key: const ValueKey('rtx_sun_shadows'),
          label: 'Ray-traced sun shadows',
          help: 'Hard shadows traced from every surface to the directional light instead of cascaded shadow maps.',
          value: settings.sunShadows,
          onChanged: (v) => viewModel.setRayTracingSettings(settings.copyWith(sunShadows: v)),
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          key: const ValueKey('rtx_restir'),
          label: 'ReSTIR direct lighting',
          help: 'Shade the point and spot lights by reservoir resampling with a ray-traced shadow for each; the cost no longer grows with the light count.',
          value: settings.restir,
          onChanged: (v) => viewModel.setRayTracingSettings(settings.copyWith(restir: v)),
        ),
        const SizedBox(height: 10),
        const Text('ReSTIR candidates / frame', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 2),
        SliderField(
          key: const ValueKey('rtx_restir_candidates'),
          fractionDigits: 0,
          value: settings.restirCandidates.toDouble(),
          defaultValue: 8,
          min: 1,
          max: 32,
          onChanged: (v) => viewModel.setRayTracingSettings(settings.copyWith(restirCandidates: v.round())),
          onCommit: (v) => viewModel.setRayTracingSettings(settings.copyWith(restirCandidates: v.round())),
          onReset: () => viewModel.setRayTracingSettings(settings.copyWith(restirCandidates: 8)),
        ),
        const SizedBox(height: 6),
        const Text('ReSTIR spatial samples', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 2),
        SliderField(
          key: const ValueKey('rtx_restir_spatial'),
          fractionDigits: 0,
          value: settings.restirSpatialSamples.toDouble(),
          defaultValue: 2,
          min: 0,
          max: 8,
          onChanged: (v) => viewModel.setRayTracingSettings(settings.copyWith(restirSpatialSamples: v.round())),
          onCommit: (v) => viewModel.setRayTracingSettings(settings.copyWith(restirSpatialSamples: v.round())),
          onReset: () => viewModel.setRayTracingSettings(settings.copyWith(restirSpatialSamples: 2)),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String help;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({super.key, required this.label, required this.help, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
              const SizedBox(height: 2),
              Text(help, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground, letterSpacing: 0.5),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
