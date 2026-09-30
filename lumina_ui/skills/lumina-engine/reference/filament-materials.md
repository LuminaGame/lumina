# Filament materials: writing a material's source

Upstream reference: https://google.github.io/filament/main/materials.html (Filament v1.77.0).
Condensed from the Filament Materials Guide, Copyright (C) Google LLC, Apache License 2.0.

## The workflow in Lumina

1. `get_material_source {asset}` returns the `.mat` text, parsed header settings, `parameters` and `issues`.
2. `set_material_source {asset, source}` replaces the whole text in the editor tab, which counts as one undo step. It does not compile or save. The node graph re-parses from the new source the next time it is read. A fragment it cannot map becomes one Custom (Fragment) node (`sync.fallback_reason`).
3. `compile_material {asset, save: true}` compiles the current source and, when `save` is true, writes the `.lmas` (source, parameter values, compiled package). Leave out `save: true` and nothing reaches disk.
4. `set_material_parameter {asset, name, value}` sets a value for a float, float4/colour or bool parameter. `set_material_texture {asset, parameter, texture}` binds a texture asset to a sampler. `set_material_settings` changes the header's shading model, blending and `doubleSided`, then recompiles.

Lumina compiles the whole source with Filament's own `.mat` parser, the one `matc` v1.77.0 runs, in process: every header key matc knows (`shadingModel`, `blending`, `transparency`, `maskThreshold`, `culling`, `colorWrite`, `depthWrite`, `depthCulling`, `doubleSided`, `requires`, `variables`, `vertexDomain`, `refractionMode`/`refractionType`, `specularAntiAliasing`, `quality`, `featureLevel`, `constants`, …), the `vertex` and `fragment` blocks in any order, and `#include "file"` resolved from the material's own folder. A source matc accepts compiles with the same meaning; one it rejects does not. Lumina only adds two things: the package targets every graphics API, and a header without `name` takes the asset's name.

Errors: `compile_material` / `get_material_issues` return matc's own messages verbatim, each with the `.mat` line it names (`line` 0 when it names none): header syntax errors (`Syntax error, … at line:3 position:18`), invalid values (`Value 'bogus' is invalid. Valid values are: …`), glslang errors in either block (`ERROR: 0:14: 'x' : undeclared identifier`, where 14 is the `.mat` line), `prepareMaterial() is not called`. Unknown header keys compile with a warning (`Ignoring config entry (unknown key): "…"`). While the text is being typed the editor also shows quick brace/block hints; they never stop a compile.

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

Rules for the text (matc's, nothing Lumina-specific):

- Blocks can come in any order; a `vertex { … }` block is optional.
- matc counts braces inside a block without skipping comments, so keep `{` / `}` out of comments.
- Header values may be quoted or not (`shadingModel : unlit`). Lumina's header bar reads them for display only.

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

Every Filament parameter type compiles as declared (`bool`–`bool4`, `float`–`float4`, `int`–`int4`, `uint`–`uint4`, `mat3`, `mat4`, arrays such as `float[4]`, `sampler2d`, `samplerCubemap`, `sampler2dArray`, `samplerExternal`, `subpassInput`), with `precision` and `format`. The editor's parameter panel (and `set_material_parameter`) sets values for these:

| Declared type | Value format |
|---|---|
| `float` | number |
| `float3`, `float4` | `[r, g, b(, a)]` (shown as a colour) |
| `bool` | `true`/`false` |
| `sampler2d` | a texture binding |

Other types compile but have no panel row; give them values in the shader or through a Blueprint.

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

`requires : [ uv0 ]` enables `getUV0()`; `uv1` enables `getUV1()`, `color` enables `getColor()` (`float4`); `tangents`, `custom0`–`7` work as in Filament. A getter without its entry fails to compile. Position is always present, and tangents are automatic except for `unlit` (write `requires : [ tangents ]` to read `material.worldNormal` in an unlit vertex block).

## Blending and transparency

| Blending | Behaviour |
|---|---|
| `opaque` | Alpha is ignored. |
| `transparent` | Porter-Duff source-over with **pre-multiplied** alpha. Alpha only fades the diffuse term. |
| `masked` | Fragments with alpha below `maskThreshold` (default 0.4) are discarded; the rest are opaque. |
| `add` | Output is added to the target. Good for glows. |

`fade` (alpha fades the whole colour, specular included), `multiply`, `screen` and `custom` (with `blendFunction`) work as in Filament; `transparency : twoPassesOneSide` / `twoPassesTwoSides` fix sorting artefacts of transparent meshes.

For `transparent`, pre-multiply the colour yourself:

```glsl
material.baseColor = vec4(col.rgb * col.a, col.a);
```

Filament disables depth writes for transparent materials by default.

`doubleSided : true` draws back faces and flips their normals so both sides light correctly. Without it back faces are culled (`culling : back`, Filament's default; `culling : none` draws them without the normal flip).

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

The optional `vertex { void materialVertex(inout MaterialVertexInputs material) { … } }` block runs per vertex before the fragment. It can move vertices (`material.worldPosition.xyz += material.worldNormal * offset;`), change `color`, `uv0`, `uv1`, and fill the interpolants declared in the header's `variables : [ tint ]`: write `material.tint = vec4(…);` in the vertex block and read it in the fragment as `variable_` + its name (variable_tint). `getUserTime().x` animates it; `getPosition()` is the object-space position. At most 5 variables (4 with `requires : [ color ]`), each a `float4`. The vertex block reads `material.uv0` / `material.color`, not `getUV0()` / `getColor()`; `material.worldPosition` is camera-relative, `getUserWorldPosition()` is the level's world position in the fragment.

Node graph: `mat_set_vertex_variable` computes its `value` per vertex (no texture samples; `mat_world_position` works) and `mat_vertex_variable` reads it in the fragment; the graph writes `variables` and the vertex block. A vertex block that moves vertices stays as written.

## Pitfalls

- A missing `prepareMaterial(material)` call is a compile error (`prepareMaterial() is not called`); post-process materials have none.
- `material.normal` written after `prepareMaterial` has no effect.
- `baseColor` is a `float4`. Assigning a `vec3` to it fails; write `material.baseColor.rgb = …` or `vec4(c, 1.0)`.
- With `transparent`, the RGB must already be multiplied by alpha. With `opaque`, alpha does nothing.
- `unlit` ignores lights; assigning `roughness` etc. fails to compile.
- Emissive is in nits; with alpha 1 small values vanish under camera exposure.
- Samplers are `materialParams_name`; scalars are `materialParams.name`. `getUV0()` needs `requires : [ uv0 ]`.
- Colours in parameters and literals are linear, not sRGB.
- Lumina compiles what matc compiles; read the issue's message and its `.mat` line, fix, recompile.
