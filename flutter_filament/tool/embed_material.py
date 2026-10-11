#!/usr/bin/env python3
"""Embeds a compiled .filamat package as a C++ byte array header.

Usage: embed_material.py <input.filamat> <output.h> [<source.mat> <matc flags>]

The source and flags, when given, are written into the header's comment, so
it documents the build that actually produced the bytes.
"""
import os
import re
import sys

# Notes kept in a header's comment, by material.
NOTES = {
    'wireframe': [
        '// Ahead-of-time compilation replaces a filamat::MaterialBuilder call that',
        '// failed at runtime on this workspace, which left every editor wireframe',
        '// with no material instance and therefore permanently white.',
    ],
}

def main() -> int:
    if len(sys.argv) not in (3, 5):
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, 'rb').read()
    # <name>_filamat.h -> kNameMaterialPackage (wireframe -> kWireframeMaterialPackage,
    # wireframe_multiview -> kWireframeMultiviewMaterialPackage).
    name = re.sub(r'_filamat$', '', os.path.splitext(os.path.basename(dst))[0])
    symbol = 'k' + ''.join(part.capitalize() for part in name.split('_')) + 'MaterialPackage'
    if len(sys.argv) == 5:
        source, flags = sys.argv[3], sys.argv[4]
    else:
        source, flags = 'src/materials/%s.mat' % name, '(see tool/materials.txt)'
    out = [
        '// GENERATED FILE - DO NOT EDIT BY HAND',
        '//',
        '// Compiled from %s by tool/build_materials.sh:' % source,
        '//   matc %s -o %s.filamat %s' % (flags, name, os.path.basename(source)),
    ]
    note = NOTES.get(os.path.splitext(os.path.basename(source))[0])
    if note:
        out += ['//'] + note
    out += [
        '#pragma once',
        '#include <cstddef>',
        '#include <cstdint>',
        '',
        'namespace flutter_filament {',
        '',
        'inline constexpr uint8_t %s[] = {' % symbol,
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
        'inline constexpr size_t %sSize = sizeof(%s);' % (symbol, symbol),
        '',
        '} // namespace flutter_filament',
        '',
    ]
    # LF on every platform (Windows' text mode would write CRLF).
    open(dst, 'w', newline='\n').write('\n'.join(out))
    print('embedded %d bytes into %s' % (len(data), dst))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
