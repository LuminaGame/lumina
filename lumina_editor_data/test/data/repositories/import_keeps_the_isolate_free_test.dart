import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Importing a large mesh never holds the calling isolate: the thumbnail
/// geometry of a 19 MB GLB is parsed and projected on a background isolate,
/// and the asset family's files are written asynchronously. A 2 ms timer
/// watches the event loop; the longest gap it sees is the longest stretch the
/// isolate was held.
void main() {
  final glb = File('${Directory.current.parent.path}/test-assets/fixtures/YVO3D_44368.glb');
  final skip = glb.existsSync() ? null : 'test-assets/fixtures/YVO3D_44368.glb not found';

  Future<(T, int)> longestGapDuring<T>(Future<T> Function() body) async {
    var last = DateTime.now();
    var longest = 0;
    final watchdog = Timer.periodic(const Duration(milliseconds: 2), (_) {
      final now = DateTime.now();
      final gap = now.difference(last).inMilliseconds;
      if (gap > longest) longest = gap;
      last = now;
    });
    try {
      return (await body(), longest);
    } finally {
      watchdog.cancel();
    }
  }

  test('the thumbnail geometry of a 19 MB GLB is computed off the calling isolate', () async {
    final payload = await glb.readAsBytes();
    expect(payload.length, greaterThan(MeshThumbnailGeometry.backgroundThresholdBytes));
    final (geometry, longest) = await longestGapDuring(() => MeshThumbnailGeometry.forPayload(AssetType.filamesh, payload));
    expect(geometry, isNotNull);
    expect(geometry!.triangleCount, greaterThan(100), reason: 'the mesh projected into the thumbnail');
    expect(longest, lessThan(100), reason: 'the parse and projection held the isolate for $longest ms');
    // The worker's parser log reached this isolate's log.
    expect(EngineLoggerService().logs.any((e) => e.message.contains('Parsed GLB model')), isTrue);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('emitting a 19 MB mesh family writes its files without holding the isolate', () async {
    final root = await Directory.systemTemp.createTemp('lumina_import_isolate_free_');
    addTearDown(() => root.delete(recursive: true));
    final project = Directory('${root.path}/P')..createSync(recursive: true);
    final repo = AssetRepository();
    final payload = await glb.readAsBytes();
    final converted = <String, dynamic>{
      'projectPath': project.path,
      'baseName': 'YVO3D_44368',
      'primaryType': AssetType.filamesh,
      'primaryPayload': payload,
      'payloadFormat': 'glb',
      'materials': <Map<String, dynamic>>[],
      'textures': <Map<String, dynamic>>[],
    };
    final (emitted, longest) = await longestGapDuring(() => repo.emitAssetFamily(
          targetPaths: {'primary': 'contents/meshes/YVO3D_44368.lmas'},
          convertedData: converted,
        ));
    expect(emitted.single.name, 'YVO3D_44368');
    expect(File('${project.path}/contents/meshes/YVO3D_44368.lmas').existsSync(), isTrue);
    expect(File('${project.path}/contents/meshes/YVO3D_44368.entity.glb').lengthSync(), payload.length);
    expect(longest, lessThan(150), reason: 'the writes held the isolate for $longest ms');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
