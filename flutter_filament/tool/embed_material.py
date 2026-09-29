#!/usr/bin/env python3
"""Embeds a compiled .filamat package as a C++ byte array header.

Usage: embed_material.py <input.filamat> <output.h>
"""
import sys

def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, 'rb').read()
    out = [
        '// GENERATED FILE - DO NOT EDIT BY HAND',
        '//',
        '// Compiled from src/materials/wireframe.mat by tool/build_materials.sh:',
        '//   matc -a opengl -a vulkan -p desktop -o wireframe.filamat wireframe.mat',
        '//',
        '// Ahead-of-time compilation replaces a filamat::MaterialBuilder call that',
        '// failed at runtime on this workspace, which left every editor wireframe',
        '// with no material instance and therefore permanently white.',
        '#pragma once',
        '#include <cstddef>',
        '#include <cstdint>',
        '',
        'namespace flutter_filament {',
        '',
        'inline constexpr uint8_t kWireframeMaterialPackage[] = {',
    ]
    line = []
    for b in data:
        line.append('0x%02x,' % b)
        if len(line) == 16:
            out.append('    ' + ''.join(line))
            line = []
    if line:
        out.append('    ' + ''.join(line))
    out += [
        '};',
        '',
        'inline constexpr size_t kWireframeMaterialPackageSize = sizeof(kWireframeMaterialPackage);',
        '',
        '} // namespace flutter_filament',
        '',
    ]
    open(dst, 'w').write('\n'.join(out))
    print('embedded %d bytes into %s' % (len(data), dst))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
