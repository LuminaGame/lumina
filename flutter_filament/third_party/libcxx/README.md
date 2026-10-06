# Bundled libc++ 21 (Linux)

The LLVM libc++ 21.1 headers and static libraries the Linux native builds use
(`hook/build.dart` of flutter_filament, flutter_assimp and flutter_riglogic,
`tool/filament/build_prebuilt.sh`, `flutter_riglogic/tool/build_openriglogic.sh`):
the system clang may ship without libc++, and every Lumina binary on Linux
links the same libc++ statically.

| Path | Content | Source |
|---|---|---|
| `usr/lib/llvm-21/include/c++/v1`, `usr/lib/llvm-21/include` | the headers (shared by both architectures; `__config_site` is identical) | `libc++-21-dev` amd64 |
| `usr/lib/x86_64-linux-gnu/libc++.a`, `libc++abi.a` (+ shared objects) | Linux x64 | `libc++-21-dev`, `libc++abi-21-dev` amd64 |
| `usr/lib/aarch64-linux-gnu/libc++.a`, `libc++abi.a` | Linux arm64 | `libc++-21-dev`, `libc++abi-21-dev` arm64 (apt.llvm.org, noble, 21.1.8) |

The builds pick the folder by the target architecture (`x86_64-linux-gnu` or
`aarch64-linux-gnu`). Apache License v2.0 with LLVM Exceptions
(https://llvm.org/LICENSE.txt). The libraries need glibc 2.38 or newer.
