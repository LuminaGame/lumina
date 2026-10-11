import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// Features a build or a device lacks (ray queries, ReSTIR, motion vectors on
/// a GLES device, the JIT glTF materials on Android and the web) keep their
/// Dart API and report "unsupported" instead of throwing: `false`, zero, an
/// empty list, a ray that misses. Android builds rely on this, and so does
/// any engine that cannot do the feature; the noop backend is such an engine.
void main() {
  late FilamentEngine engine;
  late FilamentScene scene;
  late FilamentView view;
  late FilamentRenderer renderer;

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    scene = engine.createScene();
    view = engine.createView();
    view.scene = scene;
    renderer = engine.createRenderer();
  });

  tearDown(() {
    renderer.dispose();
    view.dispose();
    scene.dispose();
    engine.dispose();
  });

  test('ray queries are reported as unsupported and a visibility ray misses', () async {
    expect(engine.supportsRayQuery, isFalse);
    scene.rayTracingEnabled = true;
    expect(scene.tlasInstanceCount, 0);
    expect(await scene.traceVisibility(0, 0, 5, 0, 0, -1), isNull);
  });

  test('ReSTIR is reported as unsupported, its options round-trip and its stats are zero', () {
    expect(view.restirSupported, isFalse);
    view.restirOptions = const RestirOptions(enabled: true);
    expect(view.restirOptions.enabled, isTrue);
    view.resetRestirHistory();
    final stats = view.restirStats;
    expect(stats.lightCount, 0);
    expect(stats.raysPerFrame, 0);
  });

  test('motion vectors are reported as unsupported without a GPU', () {
    expect(view.motionVectorsSupported, isFalse);
  });

  test('a renderer without presents reports no present times', () {
    expect(renderer.getPresentTimes(), isEmpty);
  });

  test('the platform query names this build', () {
    expect(FilamentPlatformInfo.isWeb, isFalse);
    expect(FilamentPlatformInfo.isAndroid, isFalse);
    expect(FilamentPlatformInfo.hasJitMaterialProvider, isTrue);
  });
}
