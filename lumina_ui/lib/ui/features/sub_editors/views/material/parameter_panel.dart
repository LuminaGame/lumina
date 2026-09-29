import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import '../../../../core/property_editors/asset_picker_select.dart';

/// Reflection-driven inspector panel for Material settings, PBR parameters, and texture slots.
class MaterialParameterPanel extends StatefulWidget {
  final MaterialEditorViewModel viewModel;

  const MaterialParameterPanel({
    super.key,
    required this.viewModel,
  });

  @override
  State<MaterialParameterPanel> createState() => _MaterialParameterPanelState();
}

class _MaterialParameterPanelState extends State<MaterialParameterPanel> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        return Container(
          color: EditorColors.card,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // Header
              const Row(
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 14, color: EditorColors.mutedForeground),
                  SizedBox(width: 8),
                  Text('MATERIAL SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                ],
              ),
              const SizedBox(height: 12),

              // Material Domain
              _buildSettingRow(
                label: 'Domain',
                child: Select<String>(
                  value: 'Surface',
                  onChanged: (val) {},
                  itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
                  popup: SelectPopup(
                    items: SelectItemList(
                      children: const [
                        SelectItemButton(value: 'Surface', child: Text('Surface')),
                        SelectItemButton(value: 'Deferred', child: Text('Deferred')),
                        SelectItemButton(value: 'Decal', child: Text('Decal')),
                        SelectItemButton(value: 'PostProcess', child: Text('Post Process')),
                        SelectItemButton(value: 'UI', child: Text('User Interface')),
                      ],
                    ),
                  ).call,
                ),
              ),
              const SizedBox(height: 8),

              // Blend Mode
              _buildSettingRow(
                label: 'Blend Mode',
                child: Select<BlendingMode>(
                  value: vm.blending,
                  onChanged: (val) {
                    if (val != null) {
                      vm.updateHeaderSettings(blending: val);
                    }
                  },
                  itemBuilder: (context, item) => Text(item.name, style: const TextStyle(fontSize: 11)),
                  popup: SelectPopup(
                    items: SelectItemList(
                      children: const [
                        SelectItemButton(value: BlendingMode.opaque, child: Text('Opaque')),
                        SelectItemButton(value: BlendingMode.masked, child: Text('Masked')),
                        SelectItemButton(value: BlendingMode.transparent, child: Text('Translucent')),
                        SelectItemButton(value: BlendingMode.add, child: Text('Additive')),
                      ],
                    ),
                  ).call,
                ),
              ),
              const SizedBox(height: 8),

              // Shading Model
              _buildSettingRow(
                label: 'Shading',
                child: Select<FilamatShading>(
                  value: vm.shading,
                  onChanged: (val) {
                    if (val != null) {
                      vm.updateHeaderSettings(shading: val);
                    }
                  },
                  itemBuilder: (context, item) => Text(item.name, style: const TextStyle(fontSize: 11)),
                  popup: SelectPopup(
                    items: SelectItemList(
                      children: const [
                        SelectItemButton(value: FilamatShading.lit, child: Text('Lit')),
                        SelectItemButton(value: FilamatShading.unlit, child: Text('Unlit')),
                        SelectItemButton(value: FilamatShading.cloth, child: Text('Cloth')),
                        SelectItemButton(value: FilamatShading.subsurface, child: Text('Subsurface')),
                      ],
                    ),
                  ).call,
                ),
              ),
              const SizedBox(height: 8),

              // Two Sided Switch
              _buildSettingRow(
                label: 'Two Sided',
                child: Switch(
                  value: vm.doubleSided,
                  onChanged: (val) => vm.updateHeaderSettings(doubleSided: val),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Parameters Section Header
              Row(
                children: [
                  const Icon(LucideIcons.variable, size: 14, color: EditorColors.mutedForeground),
                  const SizedBox(width: 8),
                  const Text('PARAMETERS & UNIFORMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                  const Spacer(),
                  OutlineBadge(
                    child: Text('${vm.parameters.length}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (vm.parameters.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EditorColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: const Center(
                    child: Text('No declared parameters in material header', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                  ),
                )
              else
                ...vm.parameters.map((param) => _buildParamEditor(param, vm)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({required String label, required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// A texture parameter: the bound texture's thumbnail
  /// and name, and a picker over the project's real TEXTURE assets.
  Widget _textureRow(MaterialParamModel param, MaterialEditorViewModel vm) {
    final ref = param.textureRef;
    final texture = vm.textureAssetFor(param);
    final name = vm.textureDisplayName(param);
    final textures = vm.availableTextures;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EditorColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            param.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground),
          ),
          const SizedBox(height: 6),
          Tooltip(
            tooltip: (_) => TooltipContainer(
              child: Text(ref?.assetPath ?? 'No texture assigned', style: const TextStyle(fontSize: 10)),
            ),
            child: KeyedSubtree(
              key: ValueKey('texture_thumbnail_${param.name}'),
              child: textures.isEmpty
                  ? Row(children: [
                      AssetThumbnail(asset: texture, size: 40),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))),
                    ])
                  : AssetPickerSelect(
                      key: ValueKey('texture_picker_${param.name}'),
                      keyPrefix: 'texture_picker',
                      assets: textures,
                      selectedPath: texture?.lmasPath ?? ref?.assetPath,
                      placeholder: name ?? 'Unassigned',
                      thumbnailSize: 32,
                      valueThumbnailSize: 40,
                      onSelected: (asset) => vm.graph.bindTexture(param.name, asset),
                      onCleared: () => vm.graph.bindTexture(param.name, null),
                    ),
            ),
          ),
          if (ref != null && texture == null)
            const Text('missing from the project', style: TextStyle(fontSize: 9, color: EditorColors.destructive)),
          if (textures.isEmpty)
            const Text('No textures in this project yet.', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildParamEditor(MaterialParamModel param, MaterialEditorViewModel vm) {
    switch (param.type) {
      case MaterialParamType.floatType:
        final currentVal = (param.value is num) ? (param.value as num).toDouble() : 0.5;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EditorColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EditorColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.hash, size: 12, color: EditorColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(param.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                  const Spacer(),
                  Text(currentVal.toStringAsFixed(2), style: const TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 11, color: EditorColors.foreground)),
                ],
              ),
              const SizedBox(height: 6),
              SliderField(
                key: ValueKey('material_param_${param.name}'),
                value: currentVal,
                defaultValue: (param.min + param.max) / 2,
                min: param.min,
                max: param.max,
                onChanged: (v) => vm.setParam(param.name, v),
                onCommit: (v) => vm.setParam(param.name, v),
                onReset: () => vm.setParam(param.name, (param.min + param.max) / 2),
              ),
            ],
          ),
        );

      case MaterialParamType.colorType:
        List<double> colorFloats = [1.0, 1.0, 1.0, 1.0];
        if (param.value is List) {
          colorFloats = (param.value as List).map((e) => (e as num).toDouble()).toList();
          while (colorFloats.length < 4) {
            colorFloats.add(1.0);
          }
        }
        final colorObj = Color.fromARGB(
          (colorFloats[3] * 255).clamp(0, 255).toInt(),
          (colorFloats[0] * 255).clamp(0, 255).toInt(),
          (colorFloats[1] * 255).clamp(0, 255).toInt(),
          (colorFloats[2] * 255).clamp(0, 255).toInt(),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EditorColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EditorColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.palette, size: 12, color: EditorColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(param.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorObj,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: EditorColors.border),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'R:${colorFloats[0].toStringAsFixed(2)} G:${colorFloats[1].toStringAsFixed(2)} B:${colorFloats[2].toStringAsFixed(2)}',
                      style: const TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 10, color: EditorColors.foreground),
                    ),
                  ),
                  OutlineButton(
                    onPressed: () {
                      final nextRed = colorFloats[0] > 0.5 ? 0.1 : 1.0;
                      vm.setParam(param.name, [nextRed, colorFloats[1], colorFloats[2], 1.0]);
                    },
                    child: const Text('Edit Color', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        );

      case MaterialParamType.sampler2dType:
        return _textureRow(param, vm);

      case MaterialParamType.boolType:
        final boolVal = param.value == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EditorColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EditorColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.toggleRight, size: 12, color: EditorColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(param.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                ],
              ),
              Switch(
                value: boolVal,
                onChanged: (val) => vm.setParam(param.name, val),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
