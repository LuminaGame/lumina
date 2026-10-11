# basisu_transcoder

The public headers of the Basis Universal transcoder (`basist::ktx2_transcoder`), which
`src/ktx2_reader_c.cpp` (`filament_ktx2_decode_rgba8`) uses to transcode a KTX2 / Basis Universal image to RGBA8
pixels on the CPU, without an engine: the editor's thumbnails, previews and material textures read KTX2 textures
(`KHR_texture_basisu`) this way.

- Source: Google Filament **1.77.2**, `third_party/basisu/transcoder/` (`basisu.h`, `basisu_containers.h`,
  `basisu_file_headers.h`, `basisu_transcoder.h`, `basisu_transcoder_internal.h`, `basisu_transcoder_uastc.h`,
  `basisu_astc_helpers.h`), copied unmodified.
- Licence: Apache License 2.0 (`LICENSE`, Basis Universal's own).
- The code is not compiled here: the native-assets hook (`hook/build.dart`) links Filament's `basis_transcoder`
  static library, built from the same sources, and adds `include/` to the include path.

The prebuilt Filament archives Lumina publishes carry Filament's public headers and static libraries only, not the
Basis Universal headers, so they travel with flutter_filament instead.

**When Filament is upgraded, replace every file here with the same files of the new Filament version** (the
headers declare the classes the linked `basis_transcoder` library implements; a stale copy is an ABI mismatch).
