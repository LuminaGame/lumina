# Third-party notices

Lumina is licensed under the GNU General Public License v3 (see `LICENSE`).
This repository also contains the third-party assets and code listed below,
each under its own license.

## Third Person template character and animations

`lumina/assets/templates/third_person/SKM_Superhero_Female.glb`, built by
`lumina/tool/build_third_person_content.dart` from:

| Pack | Author | Source | License |
|---|---|---|---|
| Universal Base Characters [Standard] (`Superhero_Female_FullBody`) | Quaternius | https://quaternius.itch.io/universal-base-characters | CC0 1.0 Universal |
| Universal Animation Library [Standard] (`UAL1_Standard.glb`) | Quaternius | https://quaternius.itch.io/universal-animation-library | CC0 1.0 Universal |
| Universal Animation Library 2 [Standard] (`UAL2_Standard.glb`) | Quaternius | https://quaternius.itch.io/universal-animation-library-2 | CC0 1.0 Universal |

The packs' license text and the list of the clips used are in
`lumina/assets/templates/third_person/LICENSE.txt`.
CC0: https://creativecommons.org/publicdomain/zero/1.0/

## Water Bottle sample model

`flutter_filament/example/assets/models/WaterBottle.glb` is the Khronos glTF
sample model "Water Bottle", downloaded unmodified from
https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/WaterBottle/glTF-Binary/WaterBottle.glb
(model directory:
https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/WaterBottle).

- Author: Microsoft (2017), dedicated to the public domain under Creative Commons
  Zero v1.0 Universal (CC0 1.0, SPDX `CC0-1.0`), as stated by the model's
  `LICENSE.md` and `metadata.json` in that directory.
- CC0: https://creativecommons.org/publicdomain/zero/1.0/legalcode

## Image-based lighting (KTX)

The `.ktx` environments under `flutter_filament/example/assets/ibl/`,
`lumina/example/assets/ibl/` and `lumina_ui/assets/ibl/default_env/` were
produced with Filament's `cmgen` from the HDR images in Filament's
`third_party/environments/`:

| Environment | Source HDR | Author / source | License |
|---|---|---|---|
| `pillars_2k` | `pillars_2k.hdr` | Greg Zaal, Poly Haven (https://polyhaven.com/a/pillars) | CC0 1.0 |
| `venetian_crossroads_2k` | `venetian_crossroads_2k.hdr` | Greg Zaal, Poly Haven (https://polyhaven.com/a/venetian_crossroads) | CC0 1.0 |
| `lightroom_14b`, `default_env` | `lightroom_14b.hdr` | Filament repository, `third_party/environments/` | Distributed there with `CC0.html` and a `URL.txt` naming hdrihaven.com (now Poly Haven); no Poly Haven asset of that name was found |

Poly Haven license: https://polyhaven.com/license (CC0).

## Filament test textures

Copied from the Filament repository (https://github.com/google/filament),
Apache License 2.0:

| File | Filament path |
|---|---|
| `flutter_filament/test/assets/color_grid_uastc_zstd.ktx2` | `libs/ktxreader/tests/color_grid_uastc_zstd.ktx2` |
| `flutter_filament/test/assets/lightroom_ibl.ktx` | `libs/ktxreader/tests/lightroom_ibl.ktx` |
| `flutter_filament/test/assets/conftestimage_R11_EAC.ktx` | `libs/image/tests/reference/conftestimage_R11_EAC.ktx` |
| `flutter_filament/test/assets/roughness.ktx2` | `docs/web/assets/suzanne/roughness.ktx2` |

## Sky textures and material

`milkyway.png`, `moon_disk.png` and `moon_normal.png` under
`lumina/assets/sky/`, `lumina/example/assets/sky/` and
`flutter_filament/example/assets/sky/` are byte-identical to
`docs/web/assets/sky/` in the Filament repository. `simulated_skybox.filamat`
in the same folders is the compiled material of that Filament sample.
Filament is licensed under the Apache License 2.0.

## Filament logo

`lumina_ui/assets/third_party/filament/` holds the Filament logo files with
Filament's Apache License 2.0 text (`LICENSE`). The Apache License does not
grant trademark rights (section 6).

## Filament patches

`third_party/filament/patches/` holds three patches applied to Filament
v1.77.2 (see `third_party/filament/README.md`). They modify files of the
Filament source tree and are provided under the license of the files they
change:

| Patch | Changes | License of the changed file |
|---|---|---|
| `0001-libassimp-gltf2-replacedata-joint-bounds.patch` | `third_party/libassimp/code/glTF2/glTF2Asset.inl` | Assimp: BSD 3-Clause (`third_party/libassimp/LICENSE`) |
| `0002-ssr-skip-skinned-morphed.patch` | `filament/src/RenderPass.cpp` | Filament: Apache License 2.0 |
| `0003-libwebp-wasm-no-webp-js.patch` | `third_party/libwebp/tnt/CMakeLists.txt` | Filament's build file for libwebp; it carries no license header of its own, the Filament repository is Apache License 2.0 |

## LLVM libc++ / libc++abi

`flutter_filament/third_party/libcxx/` contains the Debian packages of LLVM 21
libc++ and libc++abi (headers and libraries) used to build on Linux.
Source: https://github.com/llvm/llvm-project. License: Apache License 2.0
with LLVM Exceptions; the Debian copyright files are included under
`flutter_filament/third_party/libcxx/usr/share/doc/*/copyright`.

## JetBrains Mono

`lumina_ui/assets/fonts/JetBrainsMono-*.ttf`: Copyright 2020 The JetBrains
Mono Project Authors (https://github.com/JetBrains/JetBrainsMono), SIL Open
Font License 1.1. The license text is
`lumina_ui/assets/fonts/JetBrainsMono-OFL.txt`.
