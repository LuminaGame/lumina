import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/project_icon_rasterizer.dart';

/// The project icon rasterized into the square master
/// PNG every platform's app icon is resampled from. Real files on disk, real
/// renderer (flutter_svg + Picture.toImage), real decoders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_icon_rasterizer_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('an SVG with a 2:1 viewBox becomes a 1024 square with the drawing centred', () async {
    final svg = File('${tempDir.path}/wide.svg')
      ..writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">'
          '<rect x="0" y="0" width="200" height="100" fill="#1E90FF"/></svg>');
    final png = img.decodePng(await ProjectIconRasterizer.rasterizeFile(svg))!;
    expect((png.width, png.height), (1024, 1024));
    // 200×100 fitted into 1024: 1024×512, centred → transparent bands of 256 px.
    expect(png.getPixel(512, 100).a, 0, reason: 'top band transparent');
    expect(png.getPixel(512, 924).a, 0, reason: 'bottom band transparent');
    final mid = png.getPixel(512, 512);
    expect([mid.r, mid.g, mid.b, mid.a], [0x1E, 0x90, 0xFF, 255]);
    expect(png.getPixel(4, 300).a, 255, reason: 'the drawing spans the full width');
  });

  test('a 300×200 PNG becomes a 1024 square, pixels kept', () async {
    final source = img.Image(width: 300, height: 200, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(200, 40, 40, 255));
    final file = File('${tempDir.path}/icon.png')..writeAsBytesSync(img.encodePng(source));
    final png = img.decodePng(await ProjectIconRasterizer.rasterizeFile(file))!;
    expect((png.width, png.height), (1024, 1024));
    final mid = png.getPixel(512, 512);
    expect([mid.r, mid.g, mid.b], [200, 40, 40]);
    expect(png.getPixel(512, 60).a, 0, reason: '3:2 fitted: transparent band on top');
  });

  test('no project icon: the bundled Lumina logo is rendered', () async {
    final png = img.decodePng(await ProjectIconRasterizer.masterPng(tempDir.path, const ProjectBrandingSettings()))!;
    expect((png.width, png.height), (1024, 1024));
    expect(png.any((p) => p.a > 0 && (p.r + p.g + p.b) > 60), isTrue, reason: 'the logo draws visible pixels');
  });

  test('loadDefaultPngBytes returns the shipped PNG logo and can be rasterized', () async {
    final bytes = await ProjectIconRasterizer.loadDefaultPngBytes();
    expect(bytes.length, greaterThan(1000));
    final png = img.decodePng(await ProjectIconRasterizer.rasterizeImage(bytes))!;
    expect((png.width, png.height), (1024, 1024));
    expect(png.any((p) => p.a > 0 && (p.r + p.g + p.b) > 60), isTrue);
  });

  test('a missing or unreadable icon is an error, not the default logo', () async {
    await expectLater(
      ProjectIconRasterizer.masterPng(tempDir.path, const ProjectBrandingSettings(icon: 'branding/app_icon.png')),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('does not exist'))),
    );
    final bad = File('${tempDir.path}/bad.png')..writeAsStringSync('not an image');
    await expectLater(ProjectIconRasterizer.rasterizeFile(bad), throwsA(isA<FormatException>()));
    final gif = File('${tempDir.path}/icon.gif')..writeAsStringSync('GIF89a');
    await expectLater(ProjectIconRasterizer.rasterizeFile(gif), throwsA(isA<FormatException>()));
  });
}
