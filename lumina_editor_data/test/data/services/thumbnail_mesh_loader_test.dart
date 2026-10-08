import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// [ThumbnailMeshLoader]: a big mesh is prepared on a background isolate,
/// and the mesh drawn last is served again (the same bytes) until its files
/// change.
void main() {
  late Directory temp;
  late int threshold;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('thumbnail_mesh_loader_');
    threshold = ThumbnailMeshLoader.workerThreshold;
    ThumbnailMeshLoader.clear();
  });
  tearDown(() {
    ThumbnailMeshLoader.workerThreshold = threshold;
    ThumbnailMeshLoader.clear();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File writeGlb(String name) => File('${temp.path}/$name')
    ..writeAsBytesSync(
      PrimitiveGlbFactory.build(
        shape: 'box',
        sizeX: 100,
        sizeY: 100,
        sizeZ: 100,
      ),
    );

  test(
    'a mesh over the threshold is prepared on a worker isolate, then served from memory',
    () async {
      final file = writeGlb('big.glb');
      ThumbnailMeshLoader.workerThreshold = 1;
      final prepared = ThumbnailMeshLoader.preparedCount;
      final workers = ThumbnailMeshLoader.workerCount;

      final first = await ThumbnailMeshLoader.load(file.path);
      expect(first, isNotNull);
      expect(
        ThumbnailMeshLoader.workerCount - workers,
        1,
        reason: 'read and sanitized off the UI isolate',
      );
      expect(
        first,
        orderedEquals(file.readAsBytesSync()),
        reason: 'an already-sanitized GLB passes through unchanged',
      );

      final second = await ThumbnailMeshLoader.load(file.path);
      expect(
        identical(first, second),
        isTrue,
        reason: 'the next thumbnail of the mesh gets the same bytes',
      );
      expect(
        ThumbnailMeshLoader.preparedCount - prepared,
        1,
        reason: 'no second read',
      );
      expect(ThumbnailMeshLoader.animatesMorphWeights(second!), isFalse);
    },
  );

  test(
    'a saved mesh is prepared again; a small one stays on the calling isolate',
    () async {
      final file = writeGlb('small.glb');
      final workers = ThumbnailMeshLoader.workerCount;
      final first = await ThumbnailMeshLoader.load(file.path);
      expect(
        ThumbnailMeshLoader.workerCount,
        workers,
        reason: 'under the threshold an isolate costs more than the work',
      );

      file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
      final prepared = ThumbnailMeshLoader.preparedCount;
      final again = await ThumbnailMeshLoader.load(file.path);
      expect(
        ThumbnailMeshLoader.preparedCount - prepared,
        1,
        reason: 'a newer file is never served from memory',
      );
      expect(identical(first, again), isFalse);

      ThumbnailMeshLoader.clear();
      expect(
        ThumbnailMeshLoader.animatesMorphWeights(again!),
        isNull,
        reason: 'cleared: nothing is kept',
      );
    },
  );

  test('a GLB whose clips drive morph weights is recognised', () {
    const json =
        '{"animations":[{"channels":[{"sampler":0,"target":{"node":0,"path": "weights"}}]}]}';
    expect(
      ThumbnailMeshLoader.glbAnimatesMorphWeights(
        Uint8List.fromList(json.codeUnits),
      ),
      isTrue,
    );
    expect(
      ThumbnailMeshLoader.glbAnimatesMorphWeights(
        PrimitiveGlbFactory.build(shape: 'box', sizeX: 1, sizeY: 1, sizeZ: 1),
      ),
      isFalse,
    );
  });
}
