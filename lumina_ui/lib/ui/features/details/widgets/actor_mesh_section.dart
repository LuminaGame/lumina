import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Details panel's Static Mesh (or Skeletal Mesh) section of a placed
/// mesh actor: the
/// mesh it renders, picked with the shared searchable [AssetPickerSelect];
/// a pick swaps the geometry as one undo step.
class ActorMeshSection extends StatelessWidget {
  const ActorMeshSection({super.key, required this.viewModel, required this.actor});

  final EditorViewModel viewModel;
  final EditorActorNode actor;

  /// A placed mesh: it renders a mesh asset of the project (not a Blueprint,
  /// primitive or landscape, which draw something else).
  static bool appliesTo(EditorActorNode actor) =>
      actor.meshAssetPath != null &&
      actor.blueprintClass == null &&
      actor.type != 'Primitive' &&
      actor.type != 'Landscape' &&
      actor.meshAssetPath!.endsWith('.lmas');

  @override
  Widget build(BuildContext context) {
    final current = viewModel.realAssets.where((a) => a.lmasPath == actor.meshAssetPath).firstOrNull;
    final skeletal = current?.type == AssetType.filameshSk;
    final type = skeletal ? AssetType.filameshSk : AssetType.filamesh;
    final title = skeletal ? 'Skeletal Mesh' : 'Static Mesh';
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
            Text(title.toUpperCase(), style: EditorTypography.panelHeading),
          ]),
        ),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(title, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
              ),
              Expanded(
                child: AssetPickerSelect(
                  key: const ValueKey('details_mesh_select'),
                  keyPrefix: 'details_mesh',
                  assets: viewModel.realAssets.where((a) => a.type == type).toList(),
                  selectedPath: actor.meshAssetPath,
                  placeholder: 'None',
                  allowClear: false,
                  onSelected: (mesh) => viewModel.setActorMeshAsset(actor.id, mesh),
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
