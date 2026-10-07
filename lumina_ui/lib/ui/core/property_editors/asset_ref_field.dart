import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';

/// An asset reference property of a placed actor's component:
/// the shared searchable [AssetPickerSelect] over the project's
/// assets of the property's type, a drop target for Content Browser tiles,
/// and a clear button. The value is an `AssetReference` map
/// `{slot_name, asset_id, asset_path}` with the project-relative path.
class AssetRefField extends StatelessWidget {
  final bool isMixed;
  final Map<String, dynamic>? value; // AssetReference { slot_name, asset_id, asset_path }
  final String slotName;
  final String assetType;
  final ValueChanged<Map<String, dynamic>?> onCommit;
  final EditorViewModel viewModel;

  const AssetRefField({
    this.isMixed = false,
    super.key,
    required this.value,
    required this.slotName,
    required this.assetType,
    required this.onCommit,
    required this.viewModel,
  });

  /// The asset types a property of [assetType] (the descriptor's `type`)
  /// named [slotName] accepts; null for any asset.
  static Set<AssetType>? acceptedTypes(String assetType, String slotName) {
    switch (assetType) {
      case 'LuminaMaterial':
        return {AssetType.filamat};
      case 'LuminaStaticMesh':
        return {AssetType.filamesh};
      case 'LuminaSkeletalMesh':
        return {AssetType.filameshSk};
      case 'LuminaSound':
        return {AssetType.audio};
      case 'Texture':
      case 'LuminaTexture':
        return {AssetType.texture};
    }
    switch (slotName) {
      case 'skeletalMeshAsset':
        return {AssetType.filameshSk};
      case 'animClass':
        return {AssetType.animBlueprint};
    }
    return null;
  }

  Map<String, dynamic> _reference(RealAssetInfo asset) => {
        'slot_name': slotName,
        'asset_id': asset.assetId ?? '',
        'asset_path': asset.relativePath,
      };

  @override
  Widget build(BuildContext context) {
    final accepted = acceptedTypes(assetType, slotName);
    final path = value?['asset_path'] as String?;
    final hasValue = path != null && path.isNotEmpty;
    final assets = [
      for (final a in viewModel.realAssets)
        if (accepted == null || accepted.contains(a.type)) a,
    ];

    return DragTarget<RealAssetInfo>(
      onWillAcceptWithDetails: (details) => accepted == null || accepted.contains(details.data.type),
      onAcceptWithDetails: (details) => onCommit(_reference(details.data)),
      builder: (context, candidateData, rejectedData) {
        return Row(
          children: [
            Expanded(
              child: AssetPickerSelect(
                keyPrefix: 'asset_ref_$slotName',
                assets: assets,
                selectedPath: isMixed ? null : path,
                placeholder: isMixed ? '— multiple values —' : 'None',
                onSelected: (asset) => onCommit(_reference(asset)),
                onCleared: () => onCommit(null),
              ),
            ),
            if (hasValue && !isMixed)
              GhostButton(
                key: ValueKey('asset_ref_${slotName}_reset'),
                density: ButtonDensity.icon,
                onPressed: () => onCommit(null),
                child: const Icon(LucideIcons.x, size: 10),
              ),
          ],
        );
      },
    );
  }
}
