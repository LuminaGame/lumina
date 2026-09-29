// The C symbols the WebAssembly module must export: exactly the functions the
// Dart bindings call. Read from the ffigen output (lib/src/third_party/
// filament_c.g.dart), so the web exports can never drift from the native ones.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const packageRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export function nativeSymbols() {
  const src = readFileSync(join(packageRoot, 'lib/src/third_party/filament_c.g.dart'), 'utf8');
  const re = /@ffi\.Native<[\s\S]*?>\([^)]*\)\s*external\s+[\s\S]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  const names = [];
  for (let m; (m = re.exec(src));) names.push(m[1]);
  return names;
}

// `node tool/web/exported_symbols.mjs <out.json>` writes the emcc
// EXPORTED_FUNCTIONS list (C symbols carry a leading underscore).
if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv[2]) {
  const list = [...nativeSymbols().map((n) => `_${n}`), '_malloc', '_free'];
  (await import('node:fs')).writeFileSync(process.argv[2], JSON.stringify(list));
  console.log(`${list.length} exported symbols -> ${process.argv[2]}`);
}
