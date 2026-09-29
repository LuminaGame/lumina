// The WebAssembly module of Filament + flutter_filament's C wrapper.
// Runs under Node (no GPU): exports, heap, and ABI parity with the desktop
// library (test/web/abi_golden.json, written by abi_golden_test.dart).
//   node --test test/web/module_test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { nativeSymbols } from '../../tool/web/exported_symbols.mjs';

const require = createRequire(import.meta.url);
const modulePath = fileURLToPath(new URL('../../web/flutter_filament.js', import.meta.url));

test('the module is built', () => {
  assert.ok(existsSync(modulePath), `${modulePath} missing: run tool/web/build_module.sh`);
});

const mod = existsSync(modulePath) ? await require(modulePath)() : null;

test('it exports every filament_* function the Dart bindings call', () => {
  const symbols = nativeSymbols();
  assert.equal(symbols.length > 1000, true);
  const missing = symbols.filter((n) => typeof mod[`_${n}`] !== 'function');
  assert.deepEqual(missing, []);
});

test('malloc / free round-trip 1 MiB through the heap', () => {
  const size = 1 << 20;
  const ptr = mod._malloc(size);
  assert.notEqual(ptr, 0);
  for (let i = 0; i < size; i += 4096) mod.HEAPU8[ptr + i] = (i >> 12) & 0xff;
  for (let i = 0; i < size; i += 4096) assert.equal(mod.HEAPU8[ptr + i], (i >> 12) & 0xff);
  mod._free(ptr);
});

test('struct sizes and enum values match the desktop library', () => {
  const golden = JSON.parse(readFileSync(new URL('./abi_golden.json', import.meta.url), 'utf8'));
  for (const [name, expected] of Object.entries(golden)) {
    const fn = mod[`_${name}`];
    assert.equal(typeof fn, 'function', name);
    if (Array.isArray(expected)) {
      // Enum probes: unsigned results come back signed from wasm; compare as uint32.
      const actual = expected.map((_, i) => fn(i));
      assert.deepEqual(actual.map((v) => v >>> 0), expected.map((v) => v >>> 0), name);
    } else {
      assert.equal(fn(), expected, name);
    }
  }
});
