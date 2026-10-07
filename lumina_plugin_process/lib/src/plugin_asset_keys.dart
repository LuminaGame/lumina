/// `LuminaAsset.metadata` key a plugin asset type carries its custom type id
/// under (`EditorAssetTypeHandler.customTypeId` in `lumina_editor_api`): an
/// `.lmas` of `AssetType.unknown` with `metadata[kCustomAssetTypeKey] ==
/// customTypeId` is that plugin's asset, and the Content Browser opens it
/// with the handler's `editorFactory`. A process part writes it on the assets
/// it creates.
const String kCustomAssetTypeKey = 'custom_type';

/// `LuminaAsset.metadata` key the host sets on the asset it passes to
/// `EditorAssetTypeHandler.editorFactory`: the absolute path of the `.lmas`,
/// so the editor can write the asset back.
const String kAssetPathMetadataKey = 'asset_path';
