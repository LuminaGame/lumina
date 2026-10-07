import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

class QualitySettingsPopover extends StatelessWidget {
  final EditorViewModel viewModel;
  final VoidCallback onClose;

  const QualitySettingsPopover({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final currentPresetLower = viewModel.qualityPreset.toLowerCase();

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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: EditorColors.cardHeader,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EDITOR QUALITY SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: EditorColors.foreground,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EditorColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: EditorColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        viewModel.qualityPreset.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERALL PRESET',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['low', 'medium', 'high', 'epic', 'cinematic'].map((preset) {
                        final selected = currentPresetLower == preset;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Button(
                              key: ValueKey('quality_preset_${preset[0].toUpperCase()}${preset.substring(1, 3)}'),
                              style: selected
                                  ? const ButtonStyle.primary()
                                  : const ButtonStyle.secondary(),
                              onPressed: () => viewModel.updateQualityPreset(preset),
                              child: Text(
                                preset[0].toUpperCase() + preset.substring(1, 3),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Colors.black : EditorColors.foreground,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Resolution Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Resolution Scale',
                          style: TextStyle(fontSize: 10, color: EditorColors.foreground),
                        ),
                        Text(
                          '${viewModel.resolutionScale.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: EditorColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderField(
                      key: const ValueKey('quality_resolution_scale'),
                      value: viewModel.resolutionScale,
                      defaultValue: 100,
                      min: 50,
                      max: 200,
                      unit: '%',
                      fractionDigits: 0,
                      onChanged: viewModel.updateResolutionScale,
                      onCommit: viewModel.updateResolutionScale,
                      onReset: () => viewModel.updateResolutionScale(100),
                    ),

                    const SizedBox(height: 12),

                    // Feature Switches
                    const Text(
                      'RENDERING FEATURES',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _FeatureBtn(
                          key: const ValueKey('quality_feature_ssao'),
                          label: 'SSAO',
                          active: viewModel.ssaoEnabled,
                          onTap: () => viewModel.toggleSsao(),
                        ),
                        const SizedBox(width: 4),
                        _FeatureBtn(
                          key: const ValueKey('quality_feature_bloom'),
                          label: 'Bloom',
                          active: viewModel.bloomEnabled,
                          onTap: () => viewModel.toggleBloom(),
                        ),
                        const SizedBox(width: 4),
                        _FeatureBtn(
                          key: const ValueKey('quality_feature_ssr'),
                          label: 'SSR',
                          active: viewModel.screenSpaceReflectionsEnabled,
                          onTap: () => viewModel.toggleScreenSpaceReflections(),
                        ),
                        const SizedBox(width: 4),
                        _FeatureBtn(
                          key: const ValueKey('quality_feature_vsync'),
                          label: 'VSync',
                          active: viewModel.vsyncEnabled,
                          onTap: () => viewModel.toggleVSync(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(8),
                color: EditorColors.cardHeader,
                child: Row(
                  children: [
                    Expanded(
                      child: Button(
                        style: const ButtonStyle.outline(),
                        onPressed: () => viewModel.updateQualityPreset('epic'),
                        child: const Text('Reset Default', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        style: const ButtonStyle.primary(),
                        onPressed: onClose,
                        child: const Text('Apply & Close', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
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

class _FeatureBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FeatureBtn({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Button(
        style: active ? const ButtonStyle.primary() : const ButtonStyle.secondary(),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
