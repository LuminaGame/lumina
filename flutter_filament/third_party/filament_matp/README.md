# filament_matp

Filament's material definition parser (`matp`), the library Filament's `matc` tool uses to read a `.mat` file
(`material { … }` header, `vertex { … }` / `fragment { … }` / `compute { … }` blocks, `#include`) and drive
`filamat::MaterialBuilder` with it.

- Source: Google Filament **1.77.2**, `libs/filament-matp/` (`include/filament-matp/*.h`, `src/*`), copied unmodified.
- Licence: Apache License 2.0 (`LICENSE`, Filament's own).
- Used by `src/matc_c.cpp` (`filament_matc_compile`). The native-assets hook (`hook/build.dart`) compiles these
  sources into the flutter_filament library, against the Filament headers and static libraries it links.

The prebuilt Filament archives Lumina publishes carry the public headers and static libraries only, not `matp`, so
the parser travels with flutter_filament instead.

**When Filament is upgraded, replace every file here with the same folder of the new Filament version** (the parser
compiles against that version's filamat headers and links its `filamat` library; a stale copy is an ABI mismatch).
