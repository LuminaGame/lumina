import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/rotation_row.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';

/// Unified Engine-Wide Transform Property Editor.
///
/// Provides a consistent, state-of-the-art UI for Location, Rotation, and Scale
/// transforms across the entire engine (Main Editor Details, Blueprint Component Details,
/// Animation Keyframes, etc.).
class LuminaTransformWidget extends StatelessWidget {
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;
  final ValueChanged<List<double>>? onLocationChanged;
  final ValueChanged<List<double>>? onLocationCommit;
  final VoidCallback? onLocationReset;
  final ValueChanged<List<double>>? onRotationChanged;
  final ValueChanged<List<double>>? onRotationCommit;
  final VoidCallback? onRotationReset;
  final ValueChanged<List<double>>? onScaleChanged;
  final ValueChanged<List<double>>? onScaleCommit;
  final VoidCallback? onScaleReset;

  /// Optional per-axis multi-selection mixed states
  final List<bool>? isLocationMixed;
  final List<bool>? isRotationMixed;
  final List<bool>? isScaleMixed;

  final void Function(int axis, double value)? onLocationAxisCommit;
  final void Function(int axis, double delta, bool end)? onLocationAxisScrub;
  final void Function(int axis, double value)? onScaleAxisCommit;
  final void Function(int axis, double delta, bool end)? onScaleAxisScrub;

  /// Optional Quaternion to display under Euler angles (e.g. keyframe inspection)
  final List<double>? rotationQuat;

  /// Whether to show individual section headers with icons (Location, Rotation, Scale)
  final bool showHeaders;

  /// Custom section header titles
  final String locationTitle;
  final String rotationTitle;
  final String scaleTitle;

  /// Whether to use Euler angle labels (P, Y, R) or Cartesian (X, Y, Z)
  final bool useEulerLabels;

  /// Whether to display a degree symbol on rotation values
  final bool showRotationUnit;

  /// Optional extra action buttons or widgets in the header (e.g. World/Local toggle, reset all)
  final Widget? trailingHeader;

  final String? keyPrefix;
  final int? revision;

  const LuminaTransformWidget({
    super.key,
    required this.location,
    required this.rotation,
    required this.scale,
    this.onLocationChanged,
    this.onLocationCommit,
    this.onLocationReset,
    this.onRotationChanged,
    this.onRotationCommit,
    this.onRotationReset,
    this.onScaleChanged,
    this.onScaleCommit,
    this.onScaleReset,
    this.isLocationMixed,
    this.isRotationMixed,
    this.isScaleMixed,
    this.onLocationAxisCommit,
    this.onLocationAxisScrub,
    this.onScaleAxisCommit,
    this.onScaleAxisScrub,
    this.rotationQuat,
    this.showHeaders = true,
    this.locationTitle = 'LOCATION / TRANSLATION',
    this.rotationTitle = 'ROTATION (EULER DEGREES)',
    this.scaleTitle = 'SCALE',
    this.useEulerLabels = false,
    this.showRotationUnit = false,
    this.trailingHeader,
    this.keyPrefix,
    this.revision,
  });

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onReset}) {
    return Row(
      children: [
        Icon(icon, size: 12, color: EditorColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: EditorColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        if (onReset != null) ...[
          const Spacer(),
          GhostButton(
            density: ButtonDensity.compact,
            size: ButtonSize.xSmall,
            onPressed: onReset,
            child: const Icon(LucideIcons.rotateCcw, size: 10),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Location / Translation
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeaders) ...[
                _buildSectionHeader(locationTitle, LucideIcons.move, onReset: onLocationReset),
                const SizedBox(height: 6),
              ],
              VectorRow(
                value: location,
                defaultValue: const [0.0, 0.0, 0.0],
                isMixedPerAxis: isLocationMixed,
                onChanged: onLocationChanged ?? (_) {},
                onCommit: onLocationCommit ?? (_) {},
                onReset: onLocationReset ?? () {},
                onAxisCommit: onLocationAxisCommit,
                onAxisScrub: onLocationAxisScrub,
                labelColors: const [EditorColors.axisX, EditorColors.axisY, EditorColors.axisZ],
                labels: const ['X', 'Y', 'Z'],
                keyPrefix: keyPrefix != null ? '$keyPrefix.location' : null,
                revision: revision,
              ),
            ],
          ),
        ),

        // Rotation
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeaders) ...[
                _buildSectionHeader(rotationTitle, LucideIcons.rotate3d, onReset: onRotationReset),
                const SizedBox(height: 6),
              ],
              RotationRow(
                value: rotation,
                onChanged: onRotationChanged ?? (_) {},
                onCommit: onRotationCommit ?? (_) {},
                onReset: onRotationReset ?? () {},
                labelColors: const [EditorColors.axisX, EditorColors.axisY, EditorColors.axisZ],
                labels: useEulerLabels ? const ['P', 'Y', 'R'] : const ['X', 'Y', 'Z'],
                unit: showRotationUnit ? '°' : null,
                keyPrefix: keyPrefix != null ? '$keyPrefix.rotation' : null,
                revision: revision,
              ),
              if (rotationQuat != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EditorColors.card,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text('Quaternion: ', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                      Expanded(
                        child: Text(
                          '[${rotationQuat!.map((v) => v.toStringAsFixed(3)).join(', ')}]',
                          style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Scale
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeaders) ...[
                _buildSectionHeader(scaleTitle, LucideIcons.maximize2, onReset: onScaleReset),
                const SizedBox(height: 6),
              ],
              VectorRow(
                value: scale,
                defaultValue: const [1.0, 1.0, 1.0],
                isMixedPerAxis: isScaleMixed,
                onChanged: onScaleChanged ?? (_) {},
                onCommit: onScaleCommit ?? (_) {},
                onReset: onScaleReset ?? () {},
                onAxisCommit: onScaleAxisCommit,
                onAxisScrub: onScaleAxisScrub,
                labelColors: const [EditorColors.axisX, EditorColors.axisY, EditorColors.axisZ],
                labels: const ['X', 'Y', 'Z'],
                keyPrefix: keyPrefix != null ? '$keyPrefix.scale' : null,
                revision: revision,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
