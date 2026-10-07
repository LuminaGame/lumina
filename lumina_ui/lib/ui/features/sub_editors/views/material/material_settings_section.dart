import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The material header's settings (domain, blend mode, shading model, two
/// sided), shown under the Material Editor's 3D preview.
class MaterialSettingsSection extends StatelessWidget {
  final MaterialEditorViewModel viewModel;

  const MaterialSettingsSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return Container(
          color: EditorColors.card,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        SelectItemButton(value: BlendingMode.fade, child: Text('Fade')),
                        SelectItemButton(value: BlendingMode.multiply, child: Text('Multiply')),
                        SelectItemButton(value: BlendingMode.screen, child: Text('Screen')),
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
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ),
        Expanded(child: child),
      ],
    );
  }
}
