@TestOn('browser')
library;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/web_ffi/module.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dart:ffi / package:ffi layer over the WebAssembly heap.
/// Run: flutter test --platform chrome test/web_browser/
void main() {
  setUpAll(() => FilamentWeb.ensureInitialized(moduleUrl: '/web/module/flutter_filament.js'));

  test('calloc<Float>(16): pointer writes read back through asTypedList', () {
    final p = calloc<ffi.Float>(16);
    addTearDown(() => calloc.free(p));
    for (var i = 0; i < 16; i++) {
      expect(p[i], 0.0, reason: 'calloc zero-fills');
      p[i] = i * 1.5;
    }
    final view = p.asTypedList(16);
    expect(view.length, 16);
    for (var i = 0; i < 16; i++) {
      expect(view[i], i * 1.5);
    }
    view[3] = -7.25;
    expect(p[3], -7.25);
  });

  test('memory written before a 64 MiB heap growth survives it; views re-derive', () {
    final p = calloc<ffi.Uint32>(4);
    addTearDown(() => calloc.free(p));
    p[0] = 0xDEADBEEF;
    p[3] = 42;
    final before = FlutterFilamentModule.heapBytes.lengthInBytes;
    final big = malloc<ffi.Uint8>(64 << 20);
    addTearDown(() => malloc.free(big));
    expect(FlutterFilamentModule.heapBytes.lengthInBytes, greaterThan(before), reason: 'the heap grew');
    expect(p[0], 0xDEADBEEF);
    expect(p.asTypedList(4)[3], 42, reason: 'a view taken after the growth sees the data');
    big[(64 << 20) - 1] = 7;
    expect(big[(64 << 20) - 1], 7);
  });

  test('64-bit values cross the boundary as BigInt and come back as Dart ints', () {
    for (final v in [0, 42, 1 << 40, (1 << 53) - 1, -5]) {
      expect(FlutterFilamentModule.fromBigInt(FlutterFilamentModule.toBigInt(v)), v);
    }
    // A real uint64_t return: the frame-info sentinels.
    expect(c.filament_frame_info_invalid_sentinel(), isNot(0));
  });

  test('UTF-8 strings round-trip through the heap', () {
    const text = 'Ğüşçöı — dünya ✓';
    final p = text.toNativeUtf8();
    addTearDown(() => malloc.free(p));
    expect(p.toDartString(), text);
    expect(p.length, text.runes.fold<int>(0, (n, r) => n + (r < 0x80 ? 1 : r < 0x800 ? 2 : r < 0x10000 ? 3 : 4)));
  });

  test('freed memory is reused by the allocator', () {
    final a = malloc<ffi.Uint8>(4096);
    final address = a.address;
    malloc.free(a);
    final b = malloc<ffi.Uint8>(4096);
    addTearDown(() => malloc.free(b));
    expect(b.address, address);
  });

  test('struct views sit at the wasm32 offsets; sizeOf matches the desktop ABI', () {
    expect(ffi.sizeOf<Float3>(), 12);
    expect(ffi.sizeOf<Mat4f>(), 64);
    expect(ffi.sizeOf<Mat4d>(), 128);
    expect(ffi.sizeOf<ffi.Pointer<ffi.Void>>(), 4, reason: 'wasm32');
    final v = calloc<Float3>();
    addTearDown(() => calloc.free(v));
    v.ref
      ..x = 1
      ..y = 2
      ..z = 3;
    expect(v.cast<ffi.Float>().asTypedList(3), [1.0, 2.0, 3.0]);
    final m = calloc<Mat4f>();
    addTearDown(() => calloc.free(m));
    m.ref.setFromList([for (var i = 0; i < 16; i++) i.toDouble()]);
    expect(Mat4f.asFloat32List(m)[15], 15.0);
  });

  test('LinearImage (NativeFinalizer + Native.addressOf) keeps its pixels across a heap growth', () {
    final image = LinearImage(8, 8, 3);
    addTearDown(image.destroy);
    image.data[5] = 0.5;
    final heapBefore = FlutterFilamentModule.heapBytes.lengthInBytes;
    final big = malloc<ffi.Uint8>(128 << 20);
    addTearDown(() => malloc.free(big));
    expect(FlutterFilamentModule.heapBytes.lengthInBytes, greaterThan(heapBefore));
    expect(image.data.length, 8 * 8 * 3, reason: 'the cached view is re-derived after the growth');
    expect(image.data[5], 0.5);
  });
}
