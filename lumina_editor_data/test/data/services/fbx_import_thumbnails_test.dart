// Importing an FBX renders a thumbnail for each asset it writes (its
// materials, then its mesh) on the shared Filament engine.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

final _chair = File('${Directory.current.parent.path}/test-assets/FBX/StaticMeshes/SM_Casino_Chair.FBX');

void main() {
  test('an imported FBX gets a rendered thumbnail for its materials and its mesh', () async {
    final lease = FilamentEngineHost.acquire(owner: 'fbx_import_thumbnails_test')!;
    addTearDown(() {
      if (!lease.isReleased) lease.release();
    });
    final project = await Directory.systemTemp.createTemp('lm_fbx_thumb_');
    addTearDown(() => project.delete(recursive: true));
    await Directory('${project.path}/contents').create(recursive: true);

    final repo = AssetRepository();
    await repo.importExternalFile(projectPath: project.path, sourceFilePath: _chair.path);

    final written = await Directory('${project.path}/contents')
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.lmas'))
        .map((e) => e.path)
        .toList();
    // The editor's queue renders the materials first, then the mesh.
    written.sort((a, b) => (a.contains('materials') ? 0 : 1).compareTo(b.contains('materials') ? 0 : 1));
    expect(written.where((p) => p.contains('materials')), isNotEmpty);
    expect(written.where((p) => p.contains('meshes')), isNotEmpty);

    final service = ThumbnailService(assetRepository: repo);
    for (final path in written) {
      final result = await service.generate(path, force: true);
      expect(result, isNotNull, reason: path);
      expect(result!.source, ThumbnailService.sourceFilament, reason: path);
    }
    await service.releaseCaches();
  }, skip: _chair.existsSync() ? false : 'test-assets missing', timeout: const Timeout(Duration(minutes: 3)));
}
