[Türkçe](../../tr/lumina_editor_data/repositories-continued.md)

# Data layer: models and repositories (continued)

Continuation of Data layer: models and repositories: the remaining public files under `lib/src/repositories/`, `lib/src/repositories/asset_repository/`. File paths are relative to the `lumina_editor_data/` package directory.

**On this page:**

- [`lib/src/repositories/asset_repository/file_operations.dart`](#libsrcrepositoriesasset_repositoryfile_operationsdart)
- [`lib/src/repositories/asset_repository/mesh_thumbnail_geometry.dart`](#libsrcrepositoriesasset_repositorymesh_thumbnail_geometrydart)

## `lib/src/repositories/asset_repository/file_operations.dart`

### `class AssetMigrateEntry`

One file of a Migrate: its `contents/`-relative path, size, whether the target already has it, and whether this run copied it.

**Constructors:**

- `const AssetMigrateEntry({required this.relativePath, required this.bytes, required this.conflict, this.copied = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `relativePath` | `final String relativePath` |  |
| `bytes` | `final int bytes` |  |
| `conflict` | `final bool conflict` |  |
| `copied` | `final bool copied` |  |

## `lib/src/repositories/asset_repository/mesh_thumbnail_geometry.dart`

### `class MeshThumbnailGeometry`

A mesh's thumbnail drawing, worked out without `dart:ui` rendering so it can be computed in a background isolate: the triangles of the isometric projection [AssetRepository] draws, already sorted back to front, each as three screen points in a 128 px canvas and one shaded ARGB colour.

**Constructors:**

- `const MeshThumbnailGeometry(this.points, this.colors)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `points` | `final Float64List points` | `x0, y0, x1, y1, x2, y2` per triangle. |
| `colors` | `final Uint32List colors` | One opaque ARGB colour per triangle. |
| `triangleCount` | `int get triangleCount` |  |
| `forPayload` | `static Future<MeshThumbnailGeometry?> forPayload(AssetType type, Uint8List? payload) async` | The geometry of [type]'s thumbnail drawn from [payload] (a GLB, or OBJ text): null when the type does not draw its mesh or the payload holds none, as the thumbnail then falls back to the type's badge. |
| `fromMesh` | `static MeshThumbnailGeometry fromMesh(GlbMeshData glb)` | Projects [glb] isometrically into the thumbnail (at most ~5000 triangles), shades each triangle by a fixed light and colours it from its vertex colours or the mesh's base colour. |

## `lib/src/repositories/asset_repository/imported_material.dart`

### `String buildImportedMaterialSource({name, baseColor, textureSlots, metallic, roughness, emissive, doubleSided, alphaMode, alphaCutoff})`

The Filament `.mat` source of an imported PBR material: the glTF factors baked in as literals, one `sampler2d` per
texture slot (`baseColorMap`, `normalMap`, `metallicRoughnessMap` (roughness G, metallic B), `occlusionMap`,
`emissiveMap`, `specularMap`), the normal written before `prepareMaterial`. The glTF `doubleSided`, `alphaMode` and `alphaCutoff` become header
keys, drawn as gltfio draws the same file: `doubleSided : true` (both faces, culling off); `MASK` → `blending : masked`
with `maskThreshold` = `alphaCutoff` (default 0.5); `BLEND` → `blending : fade`, the straight glTF alpha
(`baseColorFactor.a` × the base colour texture's alpha) premultiplied into the colour in the fragment, and a
double-sided `BLEND` material drawn in two passes (`transparency : twoPassesTwoSides`). `OPAQUE` single-sided
materials keep matc's defaults (opaque, back faces culled). A textured material declares `flipUV : false`: the mesh's
glTF texture coordinates (v = 0 at the image top) are sampled as they are, as gltfio's own materials do; matc's
default `flipUV : true` would draw the texture upside down. lumina's glTF / FBX / OBJ import (Assimp formats are
converted to glTF first) and importer plugins use the same builder, so an imported material is identical whoever made
it. Material assets imported before these keys were written keep their old source; importing the model again writes
the new one. That includes `flipUV`: a material imported without it draws its textures upside down once compiled, and an
FBX / OBJ / Collada / 3DS / PLY / X mesh imported before Assimp's V flip was fixed holds V-up coordinates (its own
textures upside down); import the model again.

### `class ImportedMaterial`

A material an importer made: `name`, `baseColor` (RGBA), `metallic`, `roughness`, `emissive` (RGB), `textures`
(one `AssetReference` per slot, to existing texture assets), `doubleSided`, `alphaMode` (`OPAQUE` / `MASK` / `BLEND`), `alphaCutoff` and extra `metadata`. `materialSource()` returns the
`.mat` source; `toAsset({assetId})` the `filamat` `LuminaAsset` with the metadata keys the glTF import writes
(`baseColor` "r,g,b,a", `metallic`, `roughness`, `emissive` "r,g,b", `doubleSided`, `alphaMode`, `alphaCutoff` for
`MASK`), the texture references and a fresh id unless one
is given. The Unreal Engine importer plugin writes standalone material imports through it.

---

[Previous: Data layer: models and repositories](repositories.md) | [Up: lumina_editor_data (editor data layer)](index.md) | [Next: lumina_editor_api](../lumina_editor_api/index.md)
