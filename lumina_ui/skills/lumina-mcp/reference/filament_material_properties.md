# Filament Material Properties & PBR Reference

Comprehensive physically-based material value charts, sample lookup tables, parameter rules, and practical presets for Google Filament and Lumina Studio.

---

## 1. Base Color (Albedo / sRGB)

Defines the perceived color of a surface:
- For **dielectrics (non-metals)**: it represents the **diffuse albedo** (light reflected after subsurface absorption).
- For **conductors (metals)**: it represents the **specular reflectance** at normal incidence ($F_0$).

### 1.1 Luminosity Ranges

In physically-based rendering, pure black (`#000000`, 0) and pure white (`#ffffff`, 255) almost never exist in nature.

```
0            50                                  240       255
[---|---------|===================================|---------|]
    Absorbing   Non-metal range (10 - 240 sRGB)    Metal range (170 - 255 sRGB)
```

- **Non-metal range**: `10` to `240` sRGB (typically `50` to `240`). Pure charcoal is ~`50`, fresh snow is ~`240`.
- **Metal range**: `170` to `255` sRGB. Pure polished silver reaches `250`.

---

### 1.2 Real-World Metallic Color Values

Metals have **no diffuse color**; their `baseColor` determines their specular reflection tint. Metals must have `metallic: 1.0`.

| Metal | sRGB Hex | 8-bit sRGB (0-255) | Normalized Float (0.0 - 1.0) | Linear RGB | Notes |
|---|---|---|---|---|---|
| **Silver** | `#faf9f5` | `(250, 249, 245)` | `vec3(0.980, 0.976, 0.961)` | `vec3(0.955, 0.946, 0.913)` | Highest reflectivity in nature (~95%) |
| **Aluminum** | `#faf5f5` | `(244, 245, 245)` | `vec3(0.957, 0.961, 0.961)` | `vec3(0.903, 0.913, 0.913)` | Very bright neutral silver |
| **Platinum** | `#d6d1c8` | `(214, 209, 200)` | `vec3(0.839, 0.820, 0.784)` | `vec3(0.672, 0.638, 0.578)` | Slightly warm muted grey |
| **Iron** | `#c0bdba` | `(192, 189, 186)` | `vec3(0.753, 0.741, 0.729)` | `vec3(0.528, 0.509, 0.490)` | Raw polished steel/iron |
| **Titanium** | `#cec8c2` | `(206, 200, 194)` | `vec3(0.808, 0.784, 0.761)` | `vec3(0.618, 0.578, 0.541)` | Neutral aerospace alloy |
| **Copper** | `#fbd8b8` | `(251, 216, 184)` | `vec3(0.984, 0.847, 0.722)` | `vec3(0.964, 0.686, 0.478)` | Characteristic red-orange specular |
| **Gold** | `#fedc9d` | `(255, 220, 157)` | `vec3(1.000, 0.863, 0.616)` | `vec3(1.000, 0.716, 0.337)` | Rich warm yellow specular |
| **Brass** | `#f4e4ad` | `(244, 228, 173)` | `vec3(0.957, 0.894, 0.678)` | `vec3(0.903, 0.776, 0.419)` | 70% Cu / 30% Zn yellow alloy |
| **Chromium** | `#8a8a8a` | `(138, 138, 138)` | `vec3(0.541, 0.541, 0.541)` | `vec3(0.254, 0.254, 0.254)` | Mirror-like chrome plating |
| **Nickel** | `#cfb89d` | `(207, 184, 157)` | `vec3(0.812, 0.722, 0.616)` | `vec3(0.625, 0.481, 0.337)` | Pale yellowish-bronze |

---

### 1.3 Real-World Non-Metallic (Dielectric) Color Values

Dielectrics have colored diffuse reflections and neutral (uncolored) specular highlights. Dielectrics must have `metallic: 0.0`.

| Material | sRGB Hex | 8-bit sRGB (0-255) | Normalized Float (0.0 - 1.0) | Albedo Reflectance |
|---|---|---|---|---|
| **Coal / Charcoal** | `#323232` | `(50, 50, 50)` | `vec3(0.196, 0.196, 0.196)` | 3% - 5% |
| **Black Rubber** | `#353535` | `(53, 53, 53)` | `vec3(0.208, 0.208, 0.208)` | ~4% |
| **Wet Mud / Soil** | `#553d31` | `(85, 61, 49)` | `vec3(0.333, 0.239, 0.192)` | ~8% |
| **Raw Wood (Oak)** | `#875c3c` | `(135, 92, 60)` | `vec3(0.529, 0.361, 0.235)` | ~15% |
| **Green Foliage** | `#7b824e` | `(123, 130, 78)` | `vec3(0.482, 0.510, 0.306)` | ~18% |
| **Red Brick** | `#947d75` | `(148, 125, 117)` | `vec3(0.580, 0.490, 0.459)` | ~20% |
| **Sand (Desert)** | `#b1a884` | `(177, 168, 132)` | `vec3(0.694, 0.659, 0.518)` | ~35% |
| **Dry Concrete** | `#c0bfbb` | `(192, 191, 187)` | `vec3(0.753, 0.749, 0.733)` | ~50% |
| **White Paint** | `#ededed` | `(237, 237, 237)` | `vec3(0.929, 0.929, 0.929)` | ~80% |
| **Fresh Clean Snow** | `#f5f5f5` | `(245, 245, 245)` | `vec3(0.961, 0.961, 0.961)` | ~88% - 90% |

---

## 2. Metallic Parameter

The `metallic` parameter determines whether the surface is a **dielectric (0.0)** or a **conductor (1.0)**.

- **`0.0` (Dielectric / Non-Metal)**: Plastics, stone, wood, dirt, glass, water, skin, cloth. Specular reflectance is monochromatic (determined by `reflectance`), diffuse is colored.
- **`1.0` (Conductor / Metal)**: Iron, gold, silver, copper, aluminum. Diffuse reflectance is zero, specular reflectance is tinted by `baseColor`.
- **Intermediate values (`0.01 - 0.99`)**: Physically rare. Only valid for:
  - Transition zones on blend masks (e.g. rusted iron where rust is a dielectric $0.0$ and metal is $1.0$).
  - Partially transparent thin metallic dust, greasy fingerprint films, or volcanic soot.

```
0.0           0.2           0.4           0.6           0.8           1.0
+-------------+-------------+-------------+-------------+-------------+
|               NON-METAL               |               METAL         |
+---------------------------------------+-----------------------------+
```

---

## 3. Roughness Parameter

Roughness defines microfacet distribution (perceptual smoothness or roughness of the surface).
Filament uses **perceptual roughness** ($\alpha = roughness^2$):

| Value | Surface Texture | Real-World Analog | Visual Effect |
|---|---|---|---|
| **`0.00 - 0.05`** | Mirror-smooth / polished | Polished chrome, calm clean water, pristine mirror | Sharp, crisp reflections |
| **`0.05 - 0.15`** | Highly glossy | Automotive clear coat, polished marble, glazed ceramic | Slightly softened specular highlight |
| **`0.15 - 0.35`** | Semi-gloss / satin | Varnished wood, plastic phone casing, wet asphalt | Diffused specular shape |
| **`0.35 - 0.60`** | Matte / worn | Brushed metal, weathered wood, unpolished granite | Broad, soft specular sheen |
| **`0.60 - 0.85`** | Rough / coarse | Raw stone, dry clay, cast iron, sand | Almost no visible specular highlight |
| **`0.85 - 1.00`** | Extremely rough | Chalk, unglazed terracotta, charcoal, cotton fabric | Completely diffuse appearance |

---

## 4. Reflectance Parameter (Dielectric $F_0$)

Controls specular intensity for **non-metals** at normal incidence ($0^\circ$).
The formula relates reflectance $R$ to Fresnel reflectance at normal incidence $F_0$:
$$F_0 = 0.16 \times R^2 \quad \iff \quad R = \sqrt{\frac{F_0}{0.16}} = 2.5 \sqrt{F_0}$$

| Material Type | Reflectance ($R$) | Specular $F_0$ | Index of Refraction ($IOR$) | Real-World Examples |
|---|---|---|---|---|
| **No real material** | `0.00 - 0.20` | `0.0% - 0.6%` | $< 1.15$ | Physically impossible (vacuum/aerogel only) |
| **Water** | `0.35` | `2.0%` | `1.33` | Water, ice, eye cornea |
| **Low-index liquids** | `0.35 - 0.45` | `2.0% - 3.2%` | `1.33 - 1.42` | Alcohol, acetone, thin oil |
| **Standard Dielectrics** | **`0.50` (Default)** | **`4.0%`** | **`1.50`** | Plastics, glass, wood, stone, skin, paint |
| **Dense glass / Quartz** | `0.55 - 0.65` | `4.8% - 6.8%` | `1.54 - 1.65` | Flint glass, heavy crown glass |
| **Ruby / Sapphire** | `0.80` | `8.0%` | `1.77` | Corundum gemstones, zircon |
| **Diamond** | `1.00` | `16.0%` | `2.42` | Diamond, moissanite |

> **Rule of Thumb**: Keep `material.reflectance = 0.5` for 98% of everyday non-metallic surfaces. Only change to `0.35` for water/ice, or up to `0.8 - 1.0` for gemstones.

---

## 5. Advanced Layer Parameters

### 5.1 Clear Coat

Simulates a thin, transparent protective lacquer or polyurethane layer over the base material (automotive paint, lacquered furniture, carbon fiber).

- **`material.clearCoat`**: Layer intensity from `0.0` (none) to `1.0` (full clear coat).
- **`material.clearCoatRoughness`**: Smoothness of the lacquer layer (`0.0` = high gloss mirror finish, `0.1` = standard automotive orange-peel).
- **Clear coat IOR**: Fixed at `1.5` ($F_0 = 4.0\%$).

### 5.2 Cloth & Sheen

Simulates microfiber backscattering along glancing angles for fabrics.

- **`material.sheenColor`**: Specular tint at glancing angles (for cotton: `sqrt(baseColor.rgb)`; for velvet: bright contrast color).
- **`material.sheenRoughness`**: Softness of the sheen reflection (`0.3 - 0.7`).
- **`material.subsurfaceColor`**: Light transmission through thin fibers when backlit.

### 5.3 Anisotropy

Simulates directional reflection on surfaces with microscopic grooves:
- **`material.anisotropy`**: Value between `-1.0` and `1.0`.
  - `0.0`: Isotropic (standard uniform reflection).
  - Positive: Highlight elongates along the tangent direction (brushed metal, phonograph vinyl).
  - Negative: Highlight elongates along the bitangent direction.
- **`material.anisotropyDirection`**: Tangent-space vector `(X, Y, 0)` defining groove orientation.

---

## 6. Ready-to-Use Material Presets

### Metal Presets

| Preset | Base Color (Float) | Metallic | Roughness | Reflectance | Anisotropy |
|---|---|---|---|---|---|
| **Polished Chrome** | `vec3(0.54, 0.54, 0.54)` | `1.0` | `0.05` | N/A | `0.0` |
| **Brushed Aluminum** | `vec3(0.96, 0.96, 0.96)` | `1.0` | `0.35` | N/A | `0.8` |
| **Polished Gold** | `vec3(1.00, 0.86, 0.62)` | `1.0` | `0.08` | N/A | `0.0` |
| **Antique Copper** | `vec3(0.98, 0.85, 0.72)` | `1.0` | `0.45` | N/A | `0.0` |
| **Cast Iron** | `vec3(0.75, 0.74, 0.73)` | `1.0` | `0.70` | N/A | `0.0` |
| **Polished Silver** | `vec3(0.98, 0.98, 0.96)` | `1.0` | `0.04` | N/A | `0.0` |
| **Yellow Brass** | `vec3(0.96, 0.89, 0.68)` | `1.0` | `0.20` | N/A | `0.0` |

### Dielectric Presets

| Preset | Base Color (Float) | Metallic | Roughness | Reflectance | Clear Coat |
|---|---|---|---|---|---|
| **Car Paint (Red)** | `vec3(0.80, 0.05, 0.05)` | `0.0` | `0.50` | `0.50` | `1.0` (Roughness `0.04`) |
| **Glazed Ceramic** | `vec3(0.90, 0.90, 0.92)` | `0.0` | `0.10` | `0.50` | `0.0` |
| **Smooth Plastic** | `vec3(0.10, 0.50, 0.85)` | `0.0` | `0.25` | `0.50` | `0.0` |
| **Finished Hardwood** | `vec3(0.53, 0.36, 0.24)` | `0.0` | `0.30` | `0.50` | `0.4` |
| **Rough Concrete** | `vec3(0.75, 0.75, 0.73)` | `0.0` | `0.85` | `0.50` | `0.0` |
| **Tire Rubber** | `vec3(0.21, 0.21, 0.21)` | `0.0` | `0.90` | `0.50` | `0.0` |
| **Pool Water** | `vec3(0.20, 0.70, 0.80)` | `0.0` | `0.02` | `0.35` | `0.0` |
| **Diamond Gem** | `vec3(0.98, 0.98, 0.98)` | `0.0` | `0.02` | `1.00` | `0.0` |

---

## 7. Applying Presets via Lumina MCP Tools

### Setting Material Source in Lumina Studio

```json
{
  "tool": "set_material_source",
  "parameters": {
    "assetPath": "Materials/M_Gold_Polished.lmas",
    "source": "material { name: \"Gold_Polished\", shadingModel: lit } fragment { void material(inout MaterialInputs m) { prepareMaterial(m); m.baseColor = vec4(1.0, 0.863, 0.616, 1.0); m.metallic = 1.0; m.roughness = 0.08; } }"
  }
}
```

### Parameterizing for Live Instance Tuning

Declare parameters in the material definition so designers can adjust values live in the Lumina Details Panel without recompilation:

```json
{
  "tool": "set_material_source",
  "parameters": {
    "assetPath": "Materials/M_DynamicSurface.lmas",
    "source": "material { name: \"DynamicSurface\", shadingModel: lit, parameters: [{ type: float3, name: \"albedoColor\" }, { type: float, name: \"roughness\" }, { type: float, name: \"metallic\" }, { type: float, name: \"reflectance\" }] } fragment { void material(inout MaterialInputs m) { prepareMaterial(m); m.baseColor = vec4(materialParams.albedoColor, 1.0); m.metallic = materialParams.metallic; m.roughness = materialParams.roughness; m.reflectance = materialParams.reflectance; } }"
  }
}
```

Then tweak parameters on actors or material instances via MCP:
```json
{
  "tool": "set_material_parameter",
  "parameters": {
    "assetPath": "Materials/M_DynamicSurface.lmas",
    "parameter": "roughness",
    "value": 0.25
  }
}
```
