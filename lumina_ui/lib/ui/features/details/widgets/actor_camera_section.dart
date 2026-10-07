import 'package:lumina_editor_data/lumina_editor.dart' show CameraProjectionMode, LuminaCameraSettings;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Details panel's Camera section of a placed `Camera` actor: the
/// settings of its `LuminaCameraComponent`, under [LuminaCameraSettings]'
/// names and units (vertical field of view in degrees, clip planes and ortho
/// width in cm, aperture in f-stops, shutter speed in seconds — edited here
/// as its 1/x denominator — and ISO). Each commit is one undo step; the
/// Sequencer camera lock, Play and the generated game look through these
/// values.
class ActorCameraSection extends StatelessWidget {
  const ActorCameraSection({super.key, required this.viewModel, required this.actor});

  final EditorViewModel viewModel;
  final EditorActorNode actor;

  /// A placed camera with its camera component.
  static bool appliesTo(EditorActorNode actor) =>
      CameraActorProperties.isCameraActor(actor) && CameraActorProperties.componentOf(actor) != null;

  static const double _labelWidth = 100;

  @override
  Widget build(BuildContext context) {
    final component = CameraActorProperties.componentOf(actor)!;
    final settings = LuminaCameraSettings.fromProperties(component.properties);
    const defaults = LuminaCameraSettings();
    final orthographic = settings.projectionMode == CameraProjectionMode.orthographic;

    void commit(String id, Object value) {
      viewModel.selectActor(actor);
      viewModel.updateComponentPropertyWithTransaction(actor.id, component.id, id, value);
    }

    Widget label(String text) => SizedBox(
          width: _labelWidth,
          child: Text(text, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        );

    Widget number(
      String id,
      String text, {
      required double value,
      required double defaultValue,
      required String unit,
      double? min,
      double? max,
      int fractionDigits = 1,
      Object Function(double v)? toStored,
    }) {
      Object stored(double v) => toStored == null ? v : toStored(v);
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ScrubNumericField(
          key: ValueKey('details_camera_$id'),
          label: text,
          labelWidth: _labelWidth,
          value: value,
          defaultValue: defaultValue,
          min: min,
          max: max,
          unit: unit,
          fractionDigits: fractionDigits,
          onChanged: (v) => viewModel.updateComponentProperty(actor.id, component.id, id, stored(v)),
          onCommit: (v) => commit(id, stored(v)),
          onReset: () => commit(id, stored(defaultValue)),
        ),
      );
    }

    Widget check(String id, String text, bool value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            label(text),
            Checkbox(
              key: ValueKey('details_camera_$id'),
              state: value ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: (v) => commit(id, v == CheckboxState.checked),
            ),
          ]),
        );

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: EditorDensity.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
          color: EditorColors.cardHeader,
          child: Row(children: [
            const Icon(LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Text('CAMERA', style: EditorTypography.panelHeading),
          ]),
        ),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                label('Projection'),
                Expanded(
                  child: EnumField(
                    key: const ValueKey('details_camera_projectionMode'),
                    value: orthographic ? 'Orthographic' : 'Perspective',
                    enumValues: LuminaCameraSettings.projectionModes,
                    isRadioGroup: false,
                    onCommit: (v) => commit('projectionMode', v),
                  ),
                ),
              ]),
              if (!orthographic)
                number('fieldOfView', 'Field of View (vertical)',
                    value: settings.fieldOfView,
                    defaultValue: defaults.fieldOfView,
                    unit: '°',
                    min: LuminaCameraSettings.minFieldOfView,
                    max: LuminaCameraSettings.maxFieldOfView),
              if (orthographic)
                number('orthoWidth', 'Ortho Width',
                    value: settings.orthoWidth, defaultValue: defaults.orthoWidth, unit: 'cm', min: 1.0),
              number('nearClipPlane', 'Near Clip Plane',
                  value: settings.nearClipPlane, defaultValue: defaults.nearClipPlane, unit: 'cm', min: 0.01, fractionDigits: 2),
              number('farClipPlane', 'Far Clip Plane',
                  value: settings.farClipPlane, defaultValue: defaults.farClipPlane, unit: 'cm', min: 1.0, fractionDigits: 0),
              check('autoActivateForPlayer', 'Auto Activate for Player', settings.autoActivateForPlayer),
              heading('Exposure'),
              check('autoExposure', 'Auto Exposure', settings.autoExposure),
              if (settings.autoExposure)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Metered from the level\'s lights; turn off to set aperture, shutter speed and ISO by hand.',
                    style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
                  ),
                ),
              number('aperture', 'Aperture (f/)',
                  value: settings.aperture, defaultValue: defaults.aperture, unit: 'f', min: 0.5, max: 64.0),
              number('shutterSpeed', 'Shutter Speed (1/s)',
                  value: 1.0 / settings.shutterSpeed,
                  defaultValue: 1.0 / defaults.shutterSpeed,
                  unit: '1/s',
                  min: 1.0,
                  max: 32000.0,
                  fractionDigits: 0,
                  toStored: (v) => 1.0 / v.clamp(1.0, 32000.0)),
              number('sensitivity', 'ISO',
                  value: settings.sensitivity, defaultValue: defaults.sensitivity, unit: 'ISO', min: 1.0, max: 409600.0, fractionDigits: 0),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
