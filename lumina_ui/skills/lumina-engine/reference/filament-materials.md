# Filament materials: writing a material's source

Upstream reference: https://google.github.io/filament/main/materials.html (Filament v1.77.0).
Condensed from the Filament Materials Guide, Copyright (C) Google LLC, Apache License 2.0.

## The workflow in Lumina

1. `get_material_source {asset}` returns the `.mat` text, parsed header settings, `parameters` and `issues`.
2. `set_material_source {asset, source}` replaces the whole text in the editor tab, which counts as one undo step. It does not compile or save. The node graph re-parses from the new source the next time it is read. A fragment it cannot map becomes one Custom (Fragment) node (`sync.fallback_reason`).
3. `compile_material {asset, save: true}` compiles the current source and, when `save` is true, writes the `.lmas` (source, parameter values, compiled package). Leave out `save: true` and nothing reaches disk.
4. `set_material_parameter {asset, name, value}` sets a value for a float, float4/colour or bool parameter. `set_material_texture {asset, parameter, texture}` binds a texture asset to a sampler. `set_material_settings` changes the header's shading model, blending and `doubleSided`, then recompiles.

Lumina does not run `matc`. It passes the fragment body and a few header fields to the in-process filamat `MaterialBuilder`, which targets every API and platform with culling `none`. Only these fields are read from the header:

- `shadingModel`: `lit`, `unlit`, `cloth` or `subsurface`
- `blending`: `opaque`, `transparent`, `masked` or `add`
- `doubleSided : true`
- `requires`: `uv0`, `uv1` or `color`
- `parameters`

Every other header key is ignored (`transparency`, `maskThreshold`, `culling`, `depthWrite`, `variables`, …). Unrecognised values fall back silently: `specularGlossiness` becomes `lit`, and `fade`, `multiply` and `screen` become `opaque`. The `name :` field is ignored too, because the asset name is used instead.

Errors: structural checks (unmatched braces, missing `material`/`fragment` block or `prepareMaterial`) give a line. Shader errors return only `filamat backend rejected the source (compile failed)`, with no line or GLSL message; simplify and recompile.

## Structure of a .mat

JSONish syntax: unquoted keys (case-sensitive), strings quoted only when they contain spaces, `//` comments. It has a `material { … }` header and a `fragment { … }` block of GLSL ES 3.0 code. The fragment block must declare the `material` function:

```glsl
fragment {
    void material(inout MaterialInputs material) {
        // material.normal = …;        // only here, before prepareMaterial
        prepareMaterial(material);     // required
        material.baseColor = …;        // everything else after it
    }
}
```

`prepareMaterial(material)` must be called before `material()` returns; `getWorldNormalVector()`, `getWorldReflectedVector()` and `getNdotV()` only work after it. Helper functions may precede `material()`.

Lumina-specific rules for the text:

- Write `fragment {` exactly like that, with one space. Lumina sends everything from that token to the file's last `}` to the compiler, so the fragment block must be the last block.
- Do not write a `vertex { … }` block. It is never passed to the builder, and if it comes after the fragment block it corrupts the fragment.
- Write header values unquoted as `key : value` (for example `shadingModel : unlit` or `blending : transparent`). The reader matches this text literally, so a quoted value such as `"unlit"` falls back to the default.

Minimal working material, based on Lumina's own new-material template, with a texture added:

```
material {
    name : "Painted",
    shadingModel : lit,
    blending : opaque,
    requires : [ uv0 ],
    parameters : [
        { type : float4, name : baseColor, default : [0.8, 0.8, 0.8, 1.0] },
        { type : float, name : roughness, default : 0.5 },
        { type : float, name : metallic, default : 0.0 },
        { type : sampler2d, name : albedoMap }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor * texture(materialParams_albedoMap, getUV0());
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}
```

## Shading models

- **`lit`** (default): standard PBR with metallic/roughness. Use it for almost everything.
- **`unlit`**: no lighting at all. Only `baseColor`, `emissive` and `postLightingColor` exist, so writing `roughness`, `normal` or any other field fails to compile. Use it for UI, debug views and pre-lit content.
- **`cloth`**: fabric. Has no `metallic` or `reflectance`. Adds `sheenColor` (defaults to `sqrt(baseColor)`) and `subsurfaceColor`.
- **`subsurface`**: translucent solids such as skin or wax. Adds `thickness`, `subsurfacePower` and `subsurfaceColor`. Has no sheen or clear coat.
- `specularGlossiness`: legacy; Lumina compiles it as `lit`.

## Parameters

Each entry in `parameters : [ … ]` is `{ type : <t>, name : <identifier> }`, and the name must be a valid GLSL identifier. You read parameters differently depending on type:

- Scalars and vectors: `materialParams.roughness`
- Samplers: the `materialParams_` prefix, as in `texture(materialParams_albedoMap, getUV0())`

Filament supports many more types (`int*`, `uint*`, `bool2`–`4`, matrices, cubemaps, arrays). Lumina maps only these:

| Declared type | What Lumina compiles | Value format |
|---|---|---|
| `float` | `float` | number |
| `float4` | `float4` | `[r, g, b, a]` |
| `float3`, `vec3`, `vec4`, `color` | `float4` (a float3 becomes a float4) | 4 numbers |
| `bool` | `bool` | `true`/`false` |
| `sampler2d` | 2D sampler (any `sampler*` type becomes a 2D sampler) | a texture binding |

Other types break without warning:

- `float2`, `int`, the matrix types and arrays all compile as a scalar `float`, so code that expects a vector fails.
- Because a declared `float3` arrives as a `float4`, read it with `materialParams.tint.rgb`.
- The `precision` and `format` fields are ignored.

**Defaults.** Filament's parameter syntax has no default values. `default : …` is a Lumina extension, and only its editor reads it:

- No default: a float starts at 0.5, a colour at white (missing alpha = 1).
- `compile_material` with `save: true` stores the values in `metadata.parameter_defaults`; the runtime material cache applies them as the material's defaults.

- Change a value with `set_material_parameter`, not by editing `default :`. Once a parameter exists, its saved or panel value wins over the text.
- If a material was never saved through the editor, its uniforms start at Filament's zero.
- Colours are linear RGB, so convert sRGB values first (`pow(c, 2.2)`, or `c * c` as a cheaper approximation).

**Samplers.** Bind textures with `set_material_texture`. In the editor preview and in thumbnails:

- An unbound sampler gets a 1×1 white texture, or a flat normal (0.5, 0.5, 1) when the name contains `normal`.
- A sampler whose name contains `color`, `albedo`, `diffuse` or `emissive` is loaded as sRGB and read back as linear. Any other sampler is loaded as linear data.
- Sampling is linear filtered with repeat wrapping.

So name colour maps `albedoMap`/`baseColorMap` and data maps `normalMap`/`roughnessMap`.

With no `parameters` block the editor invents a PBR set; write `parameters : []` for none.

## Requires / attributes

`requires : [ uv0 ]` enables `getUV0()`; `uv1` enables `getUV1()`, `color` enables `getColor()` (`float4`). A getter without its entry fails to compile. Lumina forwards only these three; `custom0`–`7` are dropped. Position is always present, and tangents are automatic except for `unlit`.

## Blending and transparency

| Blending | Behaviour |
|---|---|
| `opaque` | Alpha is ignored. |
| `transparent` | Porter-Duff source-over with **pre-multiplied** alpha. Alpha only fades the diffuse term. |
| `masked` | Fragments with alpha below the threshold are discarded; the rest are opaque. Filament's default threshold is 0.4, and Lumina cannot change it because `maskThreshold` is ignored. |
| `add` | Output is added to the target. Good for glows. |

Filament's `fade`, `multiply`, `screen` and `custom` compile as `opaque` in Lumina.

For `transparent`, pre-multiply the colour yourself:

```glsl
material.baseColor = vec4(col.rgb * col.a, col.a);
```

Filament disables depth writes for transparent materials by default.

`doubleSided : true` flips back-face normals so both sides light correctly. Lumina always builds with culling `none`, so back faces draw anyway, but lit wrongly without it.

## MaterialInputs

Fields you can set in `material()`, with their unassigned defaults.

| Field | Type, range | Default | Notes |
|---|---|---|---|
| `baseColor` | `float4` [0..1] | `1.0` | Pre-multiplied linear RGB, alpha included. Use `.rgb` to set only the colour. |
| `roughness` | `float` [0..1] | 1.0 | 0 is smooth and glossy. |
| `metallic` | `float` [0..1] | 0.0 | Should be 0 or 1. Not in cloth. |
| `reflectance` | `float` [0..1] | 0.5 | Dielectric F0. Prefer values above 0.35. Not in cloth. |
| `ambientOcclusion` | `float` [0..1] | | Affects only indirect diffuse light. |
| `emissive` | `float4`, rgb nits, a [0..1] | `(0,0,0,1)` | Alpha = exposure weight (1: scaled by camera exposure; 0: not). Lumina's importer writes 0. |
| `normal` | `float3`, tangent space (+Z points out of the surface) | `(0,0,1)` | Set before `prepareMaterial`, as `tex.xyz * 2.0 - 1.0`. Not in unlit. |
| `clearCoat`, `clearCoatRoughness` | `float` | | Second specular layer, doubles cost; leave unassigned if unwanted. |
| `postLightingColor` | `float4` | | Blended after lighting. |

Useful fragment APIs: `getWorldPosition()`, `getWorldViewVector()`, `getUserTime().x` (seconds), `getTime()` (fraction of a second).

## Vertex block

Filament has an optional `vertex { void materialVertex(inout MaterialVertexInputs material) { … } }` block (edits `color`, `uv0`, `uv1`, `worldPosition`). **Lumina does not support it**, so do not write one.

## Pitfalls

- A missing `prepareMaterial(material)` call is rejected before compiling.
- `material.normal` written after `prepareMaterial` has no effect.
- `baseColor` is a `float4`. Assigning a `vec3` to it fails; write `material.baseColor.rgb = …` or `vec4(c, 1.0)`.
- With `transparent`, the RGB must already be multiplied by alpha. With `opaque`, alpha does nothing.
- `unlit` ignores lights; assigning `roughness` etc. fails to compile.
- Emissive is in nits; with alpha 1 small values vanish under camera exposure.
- Samplers are `materialParams_name`; scalars are `materialParams.name`. `getUV0()` needs `requires : [ uv0 ]`.
- Colours in parameters and literals are linear, not sRGB.
- Lumina: fragment block last, no vertex block, only the mapped header values and parameter types; shader errors carry no line.
