// The web build's asset preload (LuminaWebLoading): native builds skip it, and
// on the web every bundled asset under a prefix is read once up front and
// handed out once.
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LuminaWebLoading', () {
    test('native builds skip the web preparation', () async {
      final before = LuminaAssets.defaultProvider;
      await LuminaWebLoading.prepareGame();
      expect(LuminaWebLoading.isWeb, isFalse);
      expect(identical(LuminaAssets.defaultProvider, before), isTrue);
    });

    test('preloadAssets reads every bundled asset under a prefix, reports the count and serves the bytes once', () async {
      final previous = LuminaAssets.defaultProvider;
      addTearDown(() => LuminaAssets.defaultProvider = previous);
      final requested = <String>[];
      LuminaAssets.defaultProvider = (path) async {
        requested.add(path);
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      };
      final reports = <(int, int)>[];
      final count = await LuminaWebLoading.preloadAssets(rootBundle, prefix: 'packages/lumina/assets/sky/', onProgress: (d, t) => reports.add((d, t)), keepFor: null);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final sky = manifest.listAssets().where((a) => a.startsWith('packages/lumina/assets/sky/')).toList();
      expect(sky, isNotEmpty);
      expect(count, sky.length);
      expect(reports.first, (0, sky.length));
      expect(reports.last, (sky.length, sky.length));
      expect(LuminaWebLoading.preloadedCount, sky.length);

      final moon = sky.firstWhere((a) => a.endsWith('moon_disk.png'));
      final expected = await rootBundle.load(moon);
      final bytes = await LuminaAssets.resolve(null)(moon);
      expect(bytes, expected.buffer.asUint8List(expected.offsetInBytes, expected.lengthInBytes));
      expect(requested, isEmpty, reason: 'the first load is served from the preload');
      await LuminaAssets.resolve(null)(moon);
      expect(requested, [moon], reason: 'a preloaded asset is handed out once, then read from the bundle again');
      LuminaWebLoading.releasePreloaded();
      expect(LuminaWebLoading.preloadedCount, 0);
    });
  });
}
