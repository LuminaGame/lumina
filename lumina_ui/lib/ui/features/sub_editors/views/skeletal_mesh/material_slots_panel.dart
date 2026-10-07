import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_slot_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';

/// `MATERIAL SLOTS` section of the Skeletal Mesh editor's right inspector.
///
/// One row per geometry section: the material bound to it (pickable from the
/// project's real FILAMAT `.lmas`), Highlight/Isolate toggles, and — once bound
/// — one texture row per sampler the material declares.
class SkeletalMaterialSlotsPanel extends StatelessWidget {
  final SkeletalMeshEditorViewModel viewModel;

  const SkeletalMaterialSlotsPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final slots = viewModel.materialSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.palette, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Text(
              'MATERIAL SLOTS (${slots.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: EditorColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Text(
            'No geometry sections in this mesh.',
            style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
          )
        else ...[
          ...slots.map((slot) => _SlotCard(viewModel: viewModel, slot: slot)),
          const SizedBox(height: 4),
          const Text(
            'Isolate dims the other sections in the software preview; the native '
            'Filament path needs per-primitive control that is not wired yet.',
            style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final SkeletalMeshEditorViewModel viewModel;
  final MaterialSlotBinding slot;

  const _SlotCard({required this.viewModel, required this.slot});

  @override
  Widget build(BuildContext context) {
    final materials = viewModel.availableMaterials;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: slot.isBound ? Colors.cyan : EditorColors.mutedForeground,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Element ${slot.index} (${slot.slotName})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: EditorColors.foreground,
                ),
              ),
              const Spacer(),
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => viewModel.highlightMaterial(slot.index, !slot.isHighlighted),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 11,
                  color: slot.isHighlighted ? Colors.amber : EditorColors.mutedForeground,
                ),
              ),
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => viewModel.isolateMaterial(slot.index, !slot.isIsolated),
                child: Icon(
                  LucideIcons.eyeOff,
                  size: 11,
                  color: slot.isIsolated ? Colors.cyan : EditorColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // What this section renders with *right now* — the picked asset, or the
          // material the mesh itself shipped. An unbound slot is not blank.
          Row(
            children: [
              Text(
                slot.isBound ? 'Bound' : 'From mesh',
                style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slot.effectiveMaterialLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: slot.isBound ? Colors.cyan : EditorColors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (materials.isEmpty)
            const Text(
              'No materials in this project yet.',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
            )
          else
            AssetPickerSelect(
              key: ValueKey('skeletal_material_slot_${slot.index}'),
              keyPrefix: 'skeletal_material_picker_${slot.index}',
              placeholder: slot.sourceMaterialName == null
                  ? '— pick a material —'
                  : 'Override "${slot.sourceMaterialName}"…',
              selectedPath: slot.assignedMaterialPath,
              assets: materials,
              onSelected: (asset) => _bindMaterial(asset),
              onCleared: () async {
                viewModel.clearMaterial(slot.index);
                await viewModel.refreshSlotMaterials();
              },
            ),
          if (slot.isBound) ...[
            const SizedBox(height: 8),
            _TextureRows(viewModel: viewModel, slot: slot),
          ],
        ],
      ),
    );
  }

  Future<void> _bindMaterial(RealAssetInfo asset) async {
    final path = asset.lmasPath;
    if (path == null) return;
    viewModel.assignMaterial(
      slot.index,
      materialAssetPath: path,
      materialAssetId: asset.assetId ?? asset.fileName,
    );
    await viewModel.refreshSlotSamplers();
    await viewModel.refreshSlotMaterials();
  }
}

class _TextureRows extends StatelessWidget {
  final SkeletalMeshEditorViewModel viewModel;
  final MaterialSlotBinding slot;

  const _TextureRows({required this.viewModel, required this.slot});

  @override
  Widget build(BuildContext context) {
    final samplers = slot.samplerNames;
    if (samplers.isEmpty) {
      return const Text(
        'This material declares no texture parameters.',
        style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
      );
    }

    final textures = viewModel.availableTextures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TEXTURES',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: EditorColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        ...samplers.map((name) {
          final bound = slot.textureBindings[name];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 9, color: EditorColors.foreground),
                ),
                const SizedBox(height: 2),
                if (textures.isEmpty)
                  const Text(
                    'No textures in this project yet.',
                    style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                  )
                else
                  AssetPickerSelect(
                    key: ValueKey('skeletal_texture_${slot.index}_$name'),
                    keyPrefix: 'skeletal_texture_picker_${slot.index}_$name',
                    placeholder: '— material default —',
                    selectedPath: bound?.assetPath,
                    assets: textures,
                    onSelected: (asset) {
                      final path = asset.lmasPath;
                      if (path == null) return;
                      viewModel.assignTexture(
                        slot.index,
                        name,
                        textureAssetPath: path,
                        textureAssetId: asset.assetId ?? asset.fileName,
                      );
                    },
                    onCleared: () => viewModel.clearTexture(slot.index, name),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 2),
        const Text(
          'Overrides are written to the asset; the skinned-mesh runtime applies '
          'them once engine support lands.',
          style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }
}
