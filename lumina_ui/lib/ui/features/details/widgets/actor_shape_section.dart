import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/property_editors/color_field.dart';
import '../../../core/property_editors/enum_field.dart';
import '../../../core/property_editors/scrub_numeric_field.dart';
import '../../../core/theme/editor_theme.dart';
import '../../main_editor/view_models/editor_view_model.dart';

/// The Details panel's Shape section of a basic shape (`Primitive`): its
/// shape, its size and its colour, kept on the actor's
/// `LuminaProceduralMeshComponent`. Sizes are centimetres, Z up like the
/// Transform above them: Size Z is the height, Size Y the depth along Y (a
/// plane uses X and Y). Each commit is one undo step and redraws the shape in
/// the viewport.
class ActorShapeSection extends StatelessWidget {
  const ActorShapeSection({super.key, required this.viewModel, required this.actor});

  final EditorViewModel viewModel;
  final EditorActorNode actor;

  static const String componentType = 'LuminaProceduralMeshComponent';
  static const List<String> shapes = ['box', 'plane', 'sphere', 'cylinder'];

  /// A placed basic shape (not a Blueprint).
  static bool appliesTo(EditorActorNode actor) =>
      actor.type == 'Primitive' && actor.blueprintClass == null && actor.components.any((c) => c.type == componentType);

  @override
  Widget build(BuildContext context) {
    final component = actor.components.firstWhere((c) => c.type == componentType);
    final props = component.properties;
    double size(String id) => props[id] is num ? (props[id] as num).toDouble() : 100.0;

    void commit(String id, Object value) {
      viewModel.selectActor(actor);
      viewModel.updateComponentPropertyWithTransaction(actor.id, component.id, id, value);
    }

    Widget sizeRow(String id, String label) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ScrubNumericField(
            key: ValueKey('details_shape_$id'),
            label: label,
            labelWidth: 90,
            value: size(id),
            defaultValue: 100.0,
            min: 0.0,
            unit: 'cm',
            fractionDigits: 1,
            onChanged: (v) => viewModel.updateComponentProperty(actor.id, component.id, id, v),
            onCommit: (v) => commit(id, v),
            onReset: () => commit(id, 100.0),
          ),
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
            Text('SHAPE', style: EditorTypography.panelHeading),
          ]),
        ),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 90,
                    child: Text('Shape', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  ),
                  Expanded(
                    child: EnumField(
                      key: const ValueKey('details_shape_shape'),
                      value: shapes.contains(props['shape']) ? props['shape'] as String : 'box',
                      enumValues: shapes,
                      isRadioGroup: false,
                      onCommit: (v) => commit('shape', v),
                    ),
                  ),
                ],
              ),
              sizeRow('sizeX', 'Size X'),
              sizeRow('sizeY', 'Size Y (depth)'),
              sizeRow('sizeZ', 'Size Z (height)'),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 90,
                      child: Text('Colour', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                    ),
                    Expanded(
                      child: ColorField(
                        key: const ValueKey('details_shape_color'),
                        value: (props['colorHex'] as String?) ?? '#9AA3AE',
                        defaultValue: '#9AA3AE',
                        onChanged: (v) => viewModel.updateComponentProperty(actor.id, component.id, 'colorHex', v),
                        onCommit: (v) => commit('colorHex', v),
                        onReset: () => commit('colorHex', '#9AA3AE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
