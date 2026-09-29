[English](../../../en/lumina_ui/sub-editors/texture.md)

# Texture editörü

Texture editörü: texture önizlemesi, mip seviyeleri ve texture ayarları. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/texture_sub_editor.dart`](#libuifeaturessub_editorsviewstexture_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/texture_editor_view_model.dart`](#libuifeaturessub_editorsview_modelstexture_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/texture_editor_models.dart`](#libuifeaturessub_editorsmodelstexture_editor_modelsdart)

## `lib/ui/features/sub_editors/views/texture_sub_editor.dart`

### `class TextureSubEditor`

`TextureSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `TextureEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<TextureSubEditor> createState() => _TextureSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _TextureSubEditorState`

`_TextureSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _TextureCanvasPainter`

`_TextureCanvasPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `zoom` | `double zoom` | `zoom` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipWidth` | `int mipWidth` | `mipWidth` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipHeight` | `int mipHeight` | `mipHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _TextureCanvasPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/view_models/texture_editor_view_model.dart`

### `class TextureEditorViewModel`

`TextureEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialAsset` | `LuminaAsset? initialAsset` | `initialAsset` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `width` | `int get width` | `width` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `height` | `int get height` | `height` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedMip` | `int get selectedMip` | İlgili aktör veya varlığı seçili duruma getirir. |
| `mipChain` | `List<TextureMipLevel> get mipChain` | `mipChain` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showR` | `bool get showR` | `showR` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showG` | `bool get showG` | `showG` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showB` | `bool get showB` | `showB` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showA` | `bool get showA` | `showA` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `viewAlphaAsGreyscale` | `bool get viewAlphaAsGreyscale` | `viewAlphaAsGreyscale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `zoom` | `double get zoom` | `zoom` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hoverU` | `double? get hoverU` | `hoverU` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hoverV` | `double? get hoverV` | `hoverV` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hoverX` | `int? get hoverX` | `hoverX` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hoverY` | `int? get hoverY` | `hoverY` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hoverHex` | `String? get hoverHex` | `hoverHex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `settings` | `TextureSettings get settings` | `settings` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sourceFilePath` | `String? get sourceFilePath` | `sourceFilePath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `uncompressedSizeBytes` | `int get uncompressedSizeBytes` | `uncompressedSizeBytes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `aspectRatioStr` | `String get aspectRatioStr` | `aspectRatioStr` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `channelMaskStr` | `String get channelMaskStr` | `channelMaskStr` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `estimatedSizeBytes` | `double get estimatedSizeBytes` | `estimatedSizeBytes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `estimatedSizeStr` | `String get estimatedSizeStr` | `estimatedSizeStr` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `uncompressedSizeStr` | `String get uncompressedSizeStr` | `uncompressedSizeStr` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeMip` | `TextureMipLevel get activeMip` | `activeMip` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `getFilteredPixels` | `Uint8List getFilteredPixels(int mipLevel)` | `FilteredPixels` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `selectMip` | `void selectMip(int level)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `setZoom` | `void setZoom(double z)` | `Zoom` parametresini günceller ve sisteme uygular. |
| `setPan` | `void setPan(ui.Offset p)` | `Pan` parametresini günceller ve sisteme uygular. |
| `resetZoom` | `void resetZoom()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `setHover` | `void setHover(double u, double v, int x, int y)` | `Hover` parametresini günceller ve sisteme uygular. |
| `clearHover` | `void clearHover()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `setSrgb` | `void setSrgb(bool s)` | `Srgb` parametresini günceller ve sisteme uygular. |
| `setTextureGroup` | `void setTextureGroup(String group)` | `TextureGroup` parametresini günceller ve sisteme uygular. |
| `setCompressionFormat` | `void setCompressionFormat(String format)` | `CompressionFormat` parametresini günceller ve sisteme uygular. |
| `setCompressionQuality` | `void setCompressionQuality(String quality)` | `CompressionQuality` parametresini günceller ve sisteme uygular. |
| `setMipGenSettings` | `void setMipGenSettings(String mipGen)` | `MipGenSettings` parametresini günceller ve sisteme uygular. |
| `setFilter` | `void setFilter(String filter)` | `Filter` parametresini günceller ve sisteme uygular. |
| `setAddressModeX` | `void setAddressModeX(String mode)` | `AddressModeX` parametresini günceller ve sisteme uygular. |
| `setAddressModeY` | `void setAddressModeY(String mode)` | `AddressModeY` parametresini günceller ve sisteme uygular. |
| `setSourceFilePath` | `void setSourceFilePath(String path)` | `SourceFilePath` parametresini günceller ve sisteme uygular. |
| `formatByteSize` | `static String formatByteSize(int bytes)` | `formatByteSize` işlemini gerçekleştirir. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `reimport` | `Future<bool> reimport()` | `reimport` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/models/texture_editor_models.dart`

### `class TextureMipLevel`

`TextureMipLevel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `level` | `int level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `pixels` | `Uint8List pixels` | `pixels` alanını (field/property) ve ilişkili veriyi saklar. |

### `class TextureSettings`

`TextureSettings`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `TextureSettings.fromJson(Map<String, dynamic> json)`: `TextureSettings.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `srgb` | `bool srgb` | `srgb` alanını (field/property) ve ilişkili veriyi saklar. |
| `group` | `String group` | `group` alanını (field/property) ve ilişkili veriyi saklar. |
| `format` | `String format` | `format` alanını (field/property) ve ilişkili veriyi saklar. |
| `quality` | `String quality` | `quality` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipGen` | `String mipGen` | `mipGen` alanını (field/property) ve ilişkili veriyi saklar. |
| `filter` | `String filter` | `filter` alanını (field/property) ve ilişkili veriyi saklar. |
| `addressX` | `String addressX` | `addressX` alanını (field/property) ve ilişkili veriyi saklar. |
| `addressY` | `String addressY` | `addressY` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

---

[Önceki: Static ve skeletal mesh editörleri](meshes.md) | [Üst: Alt editörler](index.md) | [Sonraki: Widget (UMG) tasarımcısı](umg.md)
