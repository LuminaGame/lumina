[Türkçe](../../../tr/lumina_ui/sub-editors/texture.md)

# Texture editor

The Texture editor: texture preview, mip levels and texture settings. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/texture_sub_editor.dart`](#libuifeaturessub_editorsviewstexture_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/texture_editor_view_model.dart`](#libuifeaturessub_editorsview_modelstexture_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/texture_editor_models.dart`](#libuifeaturessub_editorsmodelstexture_editor_modelsdart)

## `lib/ui/features/sub_editors/views/texture_sub_editor.dart`

### `class TextureSubEditor`

`TextureSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `viewModel` | `TextureEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<TextureSubEditor> createState() => _TextureSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _TextureSubEditorState`

`_TextureSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _TextureCanvasPainter`

`_TextureCanvasPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `zoom` | `double zoom` | Holds the `zoom` property or configuration state. |
| `mipWidth` | `int mipWidth` | Holds the `mipWidth` property or configuration state. |
| `mipHeight` | `int mipHeight` | Holds the `mipHeight` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _TextureCanvasPainter oldDelegate)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/view_models/texture_editor_view_model.dart`

### `class TextureEditorViewModel`

`TextureEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `initialAsset` | `LuminaAsset? initialAsset` | Holds the `initialAsset` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `width` | `int get width` | Getter accessor returning the current value of `width`. |
| `height` | `int get height` | Getter accessor returning the current value of `height`. |
| `selectedMip` | `int get selectedMip` | Selects the target actor or asset. |
| `mipChain` | `List<TextureMipLevel> get mipChain` | Getter accessor returning the current value of `mipChain`. |
| `showR` | `bool get showR` | Getter accessor returning the current value of `showR`. |
| `showG` | `bool get showG` | Getter accessor returning the current value of `showG`. |
| `showB` | `bool get showB` | Getter accessor returning the current value of `showB`. |
| `showA` | `bool get showA` | Getter accessor returning the current value of `showA`. |
| `viewAlphaAsGreyscale` | `bool get viewAlphaAsGreyscale` | Getter accessor returning the current value of `viewAlphaAsGreyscale`. |
| `zoom` | `double get zoom` | Getter accessor returning the current value of `zoom`. |
| `hoverU` | `double? get hoverU` | Getter accessor returning the current value of `hoverU`. |
| `hoverV` | `double? get hoverV` | Getter accessor returning the current value of `hoverV`. |
| `hoverX` | `int? get hoverX` | Getter accessor returning the current value of `hoverX`. |
| `hoverY` | `int? get hoverY` | Getter accessor returning the current value of `hoverY`. |
| `hoverHex` | `String? get hoverHex` | Getter accessor returning the current value of `hoverHex`. |
| `settings` | `TextureSettings get settings` | Getter accessor returning the current value of `settings`. |
| `sourceFilePath` | `String? get sourceFilePath` | Getter accessor returning the current value of `sourceFilePath`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `uncompressedSizeBytes` | `int get uncompressedSizeBytes` | Getter accessor returning the current value of `uncompressedSizeBytes`. |
| `aspectRatioStr` | `String get aspectRatioStr` | Getter accessor returning the current value of `aspectRatioStr`. |
| `channelMaskStr` | `String get channelMaskStr` | Getter accessor returning the current value of `channelMaskStr`. |
| `estimatedSizeBytes` | `double get estimatedSizeBytes` | Getter accessor returning the current value of `estimatedSizeBytes`. |
| `estimatedSizeStr` | `String get estimatedSizeStr` | Getter accessor returning the current value of `estimatedSizeStr`. |
| `uncompressedSizeStr` | `String get uncompressedSizeStr` | Getter accessor returning the current value of `uncompressedSizeStr`. |
| `activeMip` | `TextureMipLevel get activeMip` | Getter accessor returning the current value of `activeMip`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `getFilteredPixels` | `Uint8List getFilteredPixels(int mipLevel)` | Queries and returns the `FilteredPixels` value or child object. |
| `selectMip` | `void selectMip(int level)` | Selects the target actor or asset. |
| `setZoom` | `void setZoom(double z)` | Updates the `Zoom` parameter and applies changes to the system. |
| `setPan` | `void setPan(ui.Offset p)` | Updates the `Pan` parameter and applies changes to the system. |
| `resetZoom` | `void resetZoom()` | Resets values or state back to defaults. |
| `setHover` | `void setHover(double u, double v, int x, int y)` | Updates the `Hover` parameter and applies changes to the system. |
| `clearHover` | `void clearHover()` | Clears all elements from the collection or buffer. |
| `setSrgb` | `void setSrgb(bool s)` | Updates the `Srgb` parameter and applies changes to the system. |
| `setTextureGroup` | `void setTextureGroup(String group)` | Updates the `TextureGroup` parameter and applies changes to the system. |
| `setCompressionFormat` | `void setCompressionFormat(String format)` | Updates the `CompressionFormat` parameter and applies changes to the system. |
| `setCompressionQuality` | `void setCompressionQuality(String quality)` | Updates the `CompressionQuality` parameter and applies changes to the system. |
| `setMipGenSettings` | `void setMipGenSettings(String mipGen)` | Updates the `MipGenSettings` parameter and applies changes to the system. |
| `setFilter` | `void setFilter(String filter)` | Updates the `Filter` parameter and applies changes to the system. |
| `setAddressModeX` | `void setAddressModeX(String mode)` | Updates the `AddressModeX` parameter and applies changes to the system. |
| `setAddressModeY` | `void setAddressModeY(String mode)` | Updates the `AddressModeY` parameter and applies changes to the system. |
| `setSourceFilePath` | `void setSourceFilePath(String path)` | Updates the `SourceFilePath` parameter and applies changes to the system. |
| `formatByteSize` | `static String formatByteSize(int bytes)` | Executes `formatByteSize` operation. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `reimport` | `Future<bool> reimport()` | Executes `reimport` operation. |

## `lib/ui/features/sub_editors/models/texture_editor_models.dart`

### `class TextureMipLevel`

`TextureMipLevel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `level` | `int level` | Holds the `level` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `pixels` | `Uint8List pixels` | Holds the `pixels` property or configuration state. |

### `class TextureSettings`

`TextureSettings`: `class` representing the data model or functionality of the module.

**Constructors:**
- `TextureSettings.fromJson(Map<String, dynamic> json)`: Initializes `TextureSettings.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `srgb` | `bool srgb` | Holds the `srgb` property or configuration state. |
| `group` | `String group` | Holds the `group` property or configuration state. |
| `format` | `String format` | Holds the `format` property or configuration state. |
| `quality` | `String quality` | Holds the `quality` property or configuration state. |
| `mipGen` | `String mipGen` | Holds the `mipGen` property or configuration state. |
| `filter` | `String filter` | Holds the `filter` property or configuration state. |
| `addressX` | `String addressX` | Holds the `addressX` property or configuration state. |
| `addressY` | `String addressY` | Holds the `addressY` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

---

[Previous: Static and skeletal mesh editors](meshes.md) | [Up: Sub-editors](index.md) | [Next: Widget (UMG) designer](umg.md)
