import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

/// Filament logs this (and nothing more) when a material's stereo shaders
/// were compiled for another stereoscopic type than the engine renders with.
/// The material still builds, but its stereo variants draw nothing: an XR
/// headset running a multiview engine showed no editor lines at all while the
/// desktop drew them.
const _stereoMismatch = 'stereoscopic type in the compiled material';

/// The `MAT_STER` chunk of a compiled material package (Filament stores the
/// tag as a little-endian 64-bit number, so the bytes read reversed), or null
/// when the package has none.
int? stereoscopicTypeOf(Uint8List package) {
  final tag = 'RETS_TAM'.codeUnits;
  final data = ByteData.sublistView(package);
  var offset = 0;
  while (offset + 12 <= package.length) {
    var match = true;
    for (var i = 0; i < 8; i++) {
      if (package[offset + i] != tag[i]) {
        match = false;
        break;
      }
    }
    final size = data.getUint32(offset + 8, Endian.little);
    if (match) return package[offset + 12];
    offset += 12 + size;
  }
  return null;
}

/// The bytes of a `.filamat` embedded as a C++ byte array by
/// `tool/embed_material.py`.
Uint8List embeddedPackage(String headerPath) {
  final text = File(headerPath).readAsStringSync();
  final body = text.substring(text.indexOf('[] = {'));
  return Uint8List.fromList(
      RegExp(r'0x([0-9a-f]{2})').allMatches(body).map((m) => int.parse(m.group(1)!, radix: 16)).toList());
}

List<List<String>> manifestRows() => File('tool/materials.txt')
    .readAsLinesSync()
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty && !l.startsWith('#'))
    .map((l) => l.split('|'))
    .toList();

void main() {
  group('engine materials on a multiview engine', () {
    late FilamentEngine engine;
    final logs = <FilamentLogRecord>[];
    StreamSubscription<FilamentLogRecord>? subscription;

    setUp(() {
      FilamentDiagnostics.installLogHandler();
      logs.clear();
      subscription = FilamentDiagnostics.onLog.listen(logs.add);
      engine = FilamentEngine.create(
        backend: FilamentBackend.noop,
        config: const EngineConfig(stereoscopicType: StereoscopicType.multiview, stereoscopicEyeCount: 2),
      )!;
      expect(engine.config.stereoscopicType, StereoscopicType.multiview);
    });

    tearDown(() async {
      engine.dispose();
      await subscription?.cancel();
      FilamentDiagnostics.clearLogHandler();
    });

    /// The log bridge delivers asynchronously; give it a moment.
    Future<List<String>> mismatches() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return logs.map((r) => r.message).where((m) => m.contains(_stereoMismatch)).toList();
    }

    test('an instanced-only material is reported, so the check below can fail', () async {
      // The example gallery's sky is compiled with the default (instanced)
      // stereo shaders; it proves the warning reaches this test at all.
      final bytes = File('example/assets/sky/simulated_skybox.filamat').readAsBytesSync();
      final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: bytes);
      material.dispose();
      expect(await mismatches(), isNotEmpty);
    });

    test('the line material of wireframes and line segments matches the engine', () async {
      final lines = FilamentWireframeMesh.createLineSegments(
        engine: engine,
        positions: [0, 0, 0, 1, 0, 0, 0, 1, 0],
        lineIndices: [0, 1, 1, 2],
      );
      expect(lines, isNotNull);
      expect(lines!.hasMaterial, isTrue);
      lines.dispose();
      expect(await mismatches(), isEmpty);
    });

    test('the UI overlay material matches the engine', () async {
      final overlay = FilamentUiOverlay.create(engine);
      expect(overlay, isNotNull);
      overlay!.dispose();
      expect(await mismatches(), isEmpty);
    });
  });

  test('every engine material ships both an instanced and a multiview package', () {
    // Materials this package draws itself (embedded headers) can end up in a
    // stereo view, so each source is compiled once per stereoscopic type and
    // the engine's type picks the package.
    final rows = manifestRows().where((r) => r[0].endsWith('.h')).toList();
    expect(rows, isNotEmpty);
    final bySource = <String, Map<int, String>>{};
    for (final row in rows) {
      final type = stereoscopicTypeOf(embeddedPackage(row[0]));
      expect(type, isNotNull, reason: '${row[0]} has no stereoscopic type chunk');
      bySource.putIfAbsent(row[1], () => {})[type!] = row[0];
    }
    for (final entry in bySource.entries) {
      expect(entry.value.keys.toSet(), {StereoscopicType.instanced.value, StereoscopicType.multiview.value},
          reason: '${entry.key} is compiled for stereoscopic types ${entry.value}');
    }
  });

  test('every embedded material package covers the mobile feature level', () {
    // A headset runs the mobile (feature level 1+) shader models; a package
    // compiled for desktop only is refused there.
    for (final row in manifestRows().where((r) => r[0].endsWith('.h'))) {
      expect(row[2], contains('-p all'), reason: '${row[0]} is compiled with "${row[2]}"');
      final header = File(row[0]).readAsStringSync();
      expect(header.contains('-p desktop'), isFalse, reason: '${row[0]} documents a desktop-only build');
    }
  });
}
