
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart' show LuminaBlueprintComponent, LuminaBlueprintDocument, LuminaMeshPhysics, MeshPhysicsService;
import 'package:lumina_ui/ui/features/details/services/multi_edit_service.dart';

import '../../../core/property_editors/vector_row.dart';
import '../../../core/property_editors/lumina_transform_widget.dart';
import '../../../core/property_editors/scrub_numeric_field.dart';
import '../../../core/property_editors/color_field.dart';
import '../../../core/property_editors/slider_field.dart';
import '../../../core/property_editors/enum_field.dart';
import '../../../core/property_editors/asset_ref_field.dart';
import '../../details/widgets/actor_mesh_section.dart';
import '../../details/widgets/actor_material_section.dart';
import '../../details/widgets/actor_shape_section.dart';
import '../../details/widgets/actor_camera_section.dart';
import '../../../core/property_editors/collision_section_editor.dart';
import '../../../core/property_editors/physics_section_editor.dart';
import '../../details/services/blueprint_collision_overrides.dart';
import '../../sub_editors/models/blueprint_component_registry.dart';

import '../../../core/theme/editor_theme.dart';
import '../../../core/editor_level_access.dart';
import '../../../core/services/editor_scene_environment.dart';
import '../services/camera_actor_properties.dart';
import '../services/light_actor_properties.dart';
import '../view_models/editor_view_model.dart';
import 'play_blocked_dialog.dart' show openBlueprintAtNode;
import '../../details/models/component_property_registry.dart';
import '../../details/models/editor_component_node.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show DetailsTarget;

part 'details_widget/state.dart';
part 'details_widget/level_and_blueprint_sections.dart';
part 'details_widget/single_selection.dart';
part 'details_widget/multi_selection.dart';
part 'details_widget/widgets.dart';

class DetailsWidget extends StatefulWidget {
  final EditorViewModel viewModel;

  const DetailsWidget({super.key, required this.viewModel});

  @override
  State<DetailsWidget> createState() => _DetailsWidgetState();
}

class _DetailsWidgetState extends _DetailsWidgetStateBase
    with
        _DetailsLevelAndBlueprintSections,
        _DetailsSingleSelection,
        _DetailsMultiSelection {

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final actor = widget.viewModel.selectedActors.isEmpty ? null : widget.viewModel.selectedActors.first;
        
        return Column(
          children: [
            // Details Header
            Container(
              // `h-7 px-2 bg-[oklch(0.105 0 0)]` in the prototype's
              // DetailsPanel header.
              height: EditorDensity.panelHeaderHeight,
              padding: const EdgeInsets.symmetric(
                  horizontal: EditorDensity.gutter),
              color: EditorColors.cardHeader,
              child: Row(
                children: [
                  const Icon(LucideIcons.listFilter, size: 14, color: EditorColors.primary),
                  const SizedBox(width: 8),
                  // `text-[11px] font-semibold` on the selected actor's name.
                  const Text('Details',
                      style: TextStyle(
                          fontSize: EditorTypography.bodySize,
                          fontWeight: EditorTypography.panelTitleWeight)),
                  const Spacer(),
                  const Icon(LucideIcons.lock, size: 12, color: EditorColors.mutedForeground),
                ],
              ),
            ),
            
            // Search Bar & Component Add Button
            if (actor != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: EditorColors.background,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        placeholder: const Text('Search Properties'),
                        style: const TextStyle(fontSize: 10),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      size: ButtonSize.small,
                      onPressed: () {
                        _showAddComponentPopover(context, actor.id);
                      },
                      child: const Row(
                        children: [
                          Icon(LucideIcons.plus, size: 12, color: EditorColors.primary),
                          SizedBox(width: 4),
                          Text('Add', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: widget.viewModel.selectedActors.isEmpty
                  ? _buildLevelSettings(context)
                  : (widget.viewModel.selectedActors.length > 1)
                      ? _buildMultiEditPanel(context)
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            // A placed Blueprint: its class.
                            if (actor!.blueprintClass != null) ...[
                              _buildBlueprintClassBlock(actor),
                              const SizedBox(height: 8),
                            ],
                            // Transform block (built-in)
                            _buildTransformBlock(actor),
                            const SizedBox(height: 8),
                            // The mesh a placed mesh actor renders.
                            if (ActorMeshSection.appliesTo(actor)) ActorMeshSection(viewModel: widget.viewModel, actor: actor),
                            // A basic shape's shape, size (cm, Z up) and colour.
                            if (ActorShapeSection.appliesTo(actor)) ActorShapeSection(viewModel: widget.viewModel, actor: actor),
                            // The material drawn on it.
                            if (ActorMaterialSection.appliesTo(actor)) ActorMaterialSection(viewModel: widget.viewModel, actor: actor),
                            // A placed camera's lens and exposure.
                            if (ActorCameraSection.appliesTo(actor)) ActorCameraSection(viewModel: widget.viewModel, actor: actor),
                            
                            // A placed Blueprint's collision components:
                            // per-instance Collision.
                            if (actor.blueprintClass != null) ..._buildBlueprintCollisionBlocks(actor),
                            // Components from registry
                            ...actor.components.map((comp) => _buildComponentBlock(actor, comp)),
                            // An older light actor has no Light
                            // component yet: give it one, then show it.
                            if (LightActorProperties.isLightActor(actor) && LightActorProperties.componentOf(actor) == null)
                              _LightComponentSeeder(viewModel: widget.viewModel, actorId: actor.id),
                            // A Camera from an older level has no camera
                            // component yet: give it one, then show it.
                            if (CameraActorProperties.isCameraActor(actor) && CameraActorProperties.componentOf(actor) == null)
                              _CameraComponentSeeder(viewModel: widget.viewModel, actorId: actor.id),
                            if (EditorSceneEnvironment.isEnvironmentActor(actor.type) && EditorSceneEnvironment.componentOf(actor) == null)
                              _SkyComponentSeeder(viewModel: widget.viewModel, actorId: actor.id),
                            // Plugin sections for this actor type (a plugin's
                            // registerDetailsCustomization, routed here).
                            ..._buildPluginSections(context, actor),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  /// A vector that is [v] on [axis] and zero elsewhere: one axis of a
  /// multi-select edit, written to each actor's own vector.
  static List<double> _onAxis(int axis, double v) => [for (var i = 0; i < 3; i++) i == axis ? v : 0.0];
}
