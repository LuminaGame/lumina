// The thumbnail renderer draws on the shared Filament engine (one engine for
// every holder) and leaves it as it found it.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

final _barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/dented_barrel.glb');

void main() {
  final hasAssets = _barrel.existsSync();
  late FilamentEngineLease lease;
  late FilamentEngine engine;

  setUp(() {
    lease = FilamentEngineHost.acquire(owner: 'filament_thumbnail_renderer_shared_engine_test')!;
    engine = lease.engine;
  });

  tearDown(() {
    if (!lease.isReleased) lease.release();
  });

  test('the thumbnail renderer draws on the shared engine and leaves it to the other holders', () async {
    final before = engine.resourceCounts;
    final renderer = FilamentThumbnailRenderer(size: 64, supersample: 1);
    final png = await renderer.renderMesh(_barrel.readAsBytesSync());
    expect(png, isNotNull);
    expect(FilamentEngineHost.liveEngineCount, 1, reason: 'no engine of its own');
    expect(FilamentEngineHost.leaseOwners(engine), contains('FilamentThumbnailRenderer'));
    renderer.dispose();
    expect(engine.isDisposed, isFalse);
    expect(FilamentEngineHost.leaseOwners(engine), isNot(contains('FilamentThumbnailRenderer')));
    final left = engine.resourceCounts - before;
    expect(left.views, 0);
    expect(left.scenes, 0);
    expect(left.swapChains, 0);
    expect(left.lights, 0);
    expect(left.renderables, 0);
  }, skip: hasAssets ? false : 'test-assets missing');
}
