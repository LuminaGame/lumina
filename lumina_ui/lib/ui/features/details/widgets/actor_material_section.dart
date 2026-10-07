import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Details panel's Material section of a placed mesh or basic shape: the
/// material asset drawn on every section of it — in the level viewport, in
/// Play and in the built game — picked with the shared searchable
/// [AssetPickerSelect]; clearing it gives the mesh its own materials back.
/// One undo step per pick.
class ActorMaterialSection extends StatelessWidget {
  const ActorMaterialSection({super.key, required this.viewModel, required this.actor});

  final EditorViewModel viewModel;
  final EditorActorNode actor;

  /// A placed mesh or basic shape (a Blueprint sets its components' materials
  /// in its own editor).
  static bool appliesTo(EditorActorNode actor) =>
      actor.blueprintClass == null && LuminaLevelActorMaterial.actorTypes.contains(actor.type);

  @override
  Widget build(BuildContext context) {
    final assigned = LuminaLevelActorMaterial.pathOf(actor.toMap());
    final problem = assigned == null ? null : LuminaLevelActorMaterial.problem(assigned, projectDir: viewModel.projectDirPath);
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
            Text('MATERIAL', style: EditorTypography.panelHeading),
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
                    child: Text('Material', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  ),
                  Expanded(
                    child: AssetPickerSelect(
                      key: const ValueKey('details_material_select'),
                      keyPrefix: 'details_material',
                      assets: viewModel.realAssets.where((a) => a.type == AssetType.filamat).toList(),
                      selectedPath: assigned,
                      placeholder: 'None (the mesh\'s own)',
                      onSelected: (material) {
                        viewModel.selectActor(actor);
                        viewModel.updateActorMaterial(material.relativePath);
                      },
                      onCleared: () {
                        viewModel.selectActor(actor);
                        viewModel.updateActorMaterial(null);
                      },
                    ),
                  ),
                ],
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$problem; the mesh draws its own materials.',
                    key: const ValueKey('details_material_problem'),
                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
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
