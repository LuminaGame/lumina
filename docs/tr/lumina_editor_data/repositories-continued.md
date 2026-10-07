[English](../../en/lumina_editor_data/repositories-continued.md)

# Veri katmanı: modeller ve repository'ler (devamı)

Veri katmanı: modeller ve repository'ler sayfasının devamı: `lib/src/repositories/`, `lib/src/repositories/asset_repository/` altındaki diğer public dosyalar. Dosya yolları `lumina_editor_data/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/repositories/asset_repository/file_operations.dart`](#libsrcrepositoriesasset_repositoryfile_operationsdart)
- [`lib/src/repositories/asset_repository/mesh_thumbnail_geometry.dart`](#libsrcrepositoriesasset_repositorymesh_thumbnail_geometrydart)

## `lib/src/repositories/asset_repository/file_operations.dart`

### `class AssetMigrateEntry`

One file of a Migrate: its `contents/`-relative path, size, whether the target already has it, and whether this run copied it.

**Yapıcı Metotlar (Constructors):**

- `const AssetMigrateEntry({required this.relativePath, required this.bytes, required this.conflict, this.copied = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` |  |
| `bytes` | `final int bytes` |  |
| `conflict` | `final bool conflict` |  |
| `copied` | `final bool copied` |  |

## `lib/src/repositories/asset_repository/mesh_thumbnail_geometry.dart`

### `class MeshThumbnailGeometry`

A mesh's thumbnail drawing, worked out without `dart:ui` rendering so it can be computed in a background isolate: the triangles of the isometric projection [AssetRepository] draws, already sorted back to front, each as three screen points in a 128 px canvas and one shaded ARGB colour.

**Yapıcı Metotlar (Constructors):**

- `const MeshThumbnailGeometry(this.points, this.colors)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `points` | `final Float64List points` | `x0, y0, x1, y1, x2, y2` per triangle. |
| `colors` | `final Uint32List colors` | One opaque ARGB colour per triangle. |
| `triangleCount` | `int get triangleCount` |  |
| `forPayload` | `static Future<MeshThumbnailGeometry?> forPayload(AssetType type, Uint8List? payload) async` | The geometry of [type]'s thumbnail drawn from [payload] (a GLB, or OBJ text): null when the type does not draw its mesh or the payload holds none, as the thumbnail then falls back to the type's badge. |
| `fromMesh` | `static MeshThumbnailGeometry fromMesh(GlbMeshData glb)` | Projects [glb] isometrically into the thumbnail (at most ~5000 triangles), shades each triangle by a fixed light and colours it from its vertex colours or the mesh's base colour. |

## `lib/src/repositories/asset_repository/imported_material.dart`

### `String buildImportedMaterialSource({name, baseColor, textureSlots, metallic, roughness, emissive, doubleSided, alphaMode, alphaCutoff})`

İçe aktarılmış bir PBR materyalin Filament `.mat` kaynağı: glTF faktörleri sabit olarak gömülür, her doku slotu
(`baseColorMap`, `normalMap`, `metallicRoughnessMap` (roughness G, metallic B), `occlusionMap`, `emissiveMap`,
`specularMap`) için bir `sampler2d`, normal `prepareMaterial`'dan önce yazılır. glTF'in `doubleSided`, `alphaMode` ve
`alphaCutoff` alanları başlık anahtarları olur ve gltfio'nun aynı dosyayı çizdiği gibi çizilir: `doubleSided : true` (iki
yüz, culling kapalı); `MASK` → `blending : masked`, `maskThreshold` = `alphaCutoff` (varsayılan 0.5); `BLEND` →
`blending : fade`, glTF'in düz alfası (`baseColorFactor.a` × base color dokusunun alfası) fragment'ta renge
premultiply edilir, çift yüzlü bir `BLEND` materyal iki geçişte çizilir (`transparency : twoPassesTwoSides`). `OPAQUE`
tek yüzlü materyaller matc varsayılanlarında kalır (opak, arka yüzler cull edilir). Dokulu bir materyal `flipUV : false`
bildirir: mesh'in glTF doku koordinatları (v = 0 görüntünün üstünde) gltfio'nun kendi materyallerindeki gibi olduğu gibi
örneklenir; matc'nin varsayılanı `flipUV : true` dokuyu ters çizerdi. lumina'nın glTF / FBX / OBJ
import'u (Assimp formatları önce glTF'e çevrilir) ve importer eklentileri aynı üreticiyi kullanır; böylece içe aktarılan
bir materyal kimin ürettiğinden bağımsız aynıdır. Bu anahtarlar yazılmadan önce içe aktarılmış materyal asset'leri eski
kaynaklarını korur; modeli yeniden içe aktarmak yenisini yazar. `flipUV` da buna dahildir: onsuz içe aktarılmış bir
materyal derlendiğinde dokularını ters çizer; Assimp'in V çevirmesi düzeltilmeden önce içe aktarılmış bir FBX / OBJ /
Collada / 3DS / PLY / X mesh'i V-yukarı koordinatlar taşır (kendi dokuları ters); modeli yeniden içe aktarın.

### `class ImportedMaterial`

Bir importer'ın ürettiği materyal: `name`, `baseColor` (RGBA), `metallic`, `roughness`, `emissive` (RGB), `textures`
(her slot için mevcut bir doku asset'ine bir `AssetReference`), `doubleSided`, `alphaMode` (`OPAQUE` / `MASK` /
`BLEND`), `alphaCutoff` ve ek `metadata`. `materialSource()` `.mat` kaynağını,
`toAsset({assetId})` glTF import'unun yazdığı metadata anahtarlarıyla (`baseColor` "r,g,b,a", `metallic`,
`roughness`, `emissive` "r,g,b", `doubleSided`, `alphaMode`, `MASK` için `alphaCutoff`), doku referanslarıyla ve verilmezse yeni bir id ile `filamat` `LuminaAsset`'ini
döndürür. Unreal Engine importer eklentisi bağımsız materyal import'larını bununla yazar.

---

[Önceki: Veri katmanı: modeller ve repository'ler](repositories.md) | [Üst: lumina_editor_data (editör veri katmanı)](index.md) | [Sonraki: lumina_editor_api](../lumina_editor_api/index.md)
