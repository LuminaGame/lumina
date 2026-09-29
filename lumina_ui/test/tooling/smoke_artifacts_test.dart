// Studio's SmokeArtifacts: lumina_smoke's (tested there) plus the widget
// captures, sharing one state with it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_smoke/lumina_smoke.dart' as smoke;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('smoke_artifacts_test_');
    SmokeArtifacts.outputDirOverride = tempDir.path;
  });

  tearDown(() {
    SmokeArtifacts.outputDirOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('saveScreenshot writes the PNG and a sidecar with the exact test name into the shared directory', () {
    expect(smoke.SmokeArtifacts.dir.path, tempDir.path, reason: 'one state with lumina_smoke');
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
    final file = SmokeArtifacts.saveScreenshot('launcher: hub renders recents', png, usedAssets: ['Props/Barrels']);
    expect(file.path, endsWith('launcher_hub_renders_recents.png'));
    final json = jsonDecode(File('${tempDir.path}/launcher_hub_renders_recents.json').readAsStringSync()) as Map<String, dynamic>;
    expect(json['test'], 'launcher: hub renders recents');
    expect(json['file'], 'launcher_hub_renders_recents.png');
    expect(json['usedAssets'], ['Props/Barrels']);
  });

  test('clear works in an owned directory and refuses the shared one', () {
    SmokeArtifacts.saveScreenshot('test1', Uint8List.fromList([1, 2, 3]));
    SmokeArtifacts.clear();
    expect(tempDir.listSync(), isEmpty);
    SmokeArtifacts.outputDirOverride = null;
    addTearDown(() => SmokeArtifacts.outputDirOverride = tempDir.path);
    expect(SmokeArtifacts.clear, throwsA(isA<StateError>().having((e) => e.message, 'message', contains('shared'))));
  });

  test('saveVideo refuses bytes that cannot be shown to meet the smoke-video rules', () {
    expect(() => SmokeArtifacts.saveVideo('viewport: 10s rotation demo', Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('viewport: 10s rotation demo'))));
    expect(tempDir.listSync(), isEmpty);
  });

  test('testAssetsDir points to the shared 3D assets', () {
    final assetsDir = SmokeArtifacts.testAssetsDir;
    if (!assetsDir.existsSync()) return markTestSkipped('no test-assets checkout next to this workspace');
    expect(Directory('${assetsDir.path}/Props').existsSync(), isTrue);
  });

  test('encodeRgbaToPng encodes RGBA and BGRA buffers', () {
    final rgba = Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]);
    for (final bgra in [false, true]) {
      final png = SmokeArtifacts.encodeRgbaToPng(rgba, 2, 2, bgra: bgra);
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(SmokeArtifacts.pngSize(png), (2, 2));
    }
  });

  testWidgets('captureWidgetPng captures a ShadcnApp widget wrapped in a RepaintBoundary', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Smoke Test Card'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });
}
