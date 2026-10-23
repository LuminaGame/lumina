import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/brand/render_icons.dart';

/// Every app icon the project ships is rendered from the one Prism L source.
void main() {
  const slow = Timeout(Duration(minutes: 3));
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_icons_');
    // The real source SVG and the real icon-set manifests, so the renderer
    // reads what the packaged apps read.
    File('assets/brand/prism_l.svg').copySync('${root.path}/prism_l.svg');
    Directory('${root.path}/macos').createSync(recursive: true);
    Directory('${root.path}/ios').createSync(recursive: true);
    File('macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').copySync('${root.path}/macos/Contents.json');
    File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').copySync('${root.path}/ios/Contents.json');
  });

  tearDown(() => root.deleteSync(recursive: true));

  IconRenderer renderer() => IconRenderer(
        source: File('${root.path}/prism_l.svg'),
        outputs: IconOutputs(
          appIcon: File('${root.path}/app_icon.png'),
          windowsIco: File('${root.path}/app_icon.ico'),
          storeLogo: File('${root.path}/store_logo.png'),
          macosSet: Directory('${root.path}/macos'),
          iosSet: Directory('${root.path}/ios'),
          favicon16: File('${root.path}/favicon-16.png'),
          favicon32: File('${root.path}/favicon-32.png'),
          webFavicon: File('${root.path}/web_favicon.png'),
          linuxIcon: File('${root.path}/icon-512-linux.png'),
        ),
      );

  test('renders every listed file at its size, from the source polygons', timeout: slow, () async {
    final written = await renderer().render();
    expect(written, isNotEmpty);

    img.Image decode(String name) => img.decodePng(File('${root.path}/$name').readAsBytesSync())!;
    expect(decode('app_icon.png').width, 512);
    expect(decode('store_logo.png').width, 300);
    expect(decode('favicon-16.png').width, 16);
    expect(decode('favicon-32.png').width, 32);
    expect(decode('web_favicon.png').width, 32);
    expect(decode('icon-512-linux.png').width, 512);

    // The mark is drawn: the stem's deep blue and the foot's mid blue appear
    // on the dark badge, and the badge corners are transparent.
    final icon = decode('app_icon.png');
    final blues = <int>{};
    for (var y = 0; y < icon.height; y += 4) {
      for (var x = 0; x < icon.width; x += 4) {
        final p = icon.getPixel(x, y);
        blues.add((p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt());
      }
    }
    expect(blues, contains(0x31A5DA));
    expect(blues, contains(0x5DB8E1));
    expect(icon.getPixel(0, 0).a, 0, reason: 'rounded badge corner is transparent');

    // The .ico holds the seven sizes.
    final ico = img.decodeIco(File('${root.path}/app_icon.ico').readAsBytesSync())!;
    expect(ico.numFrames, 7);
    expect(ico.frames.map((f) => f.width).toSet(), {16, 24, 32, 48, 64, 128, 256});

    // The macOS and iOS sets list exactly the files rendered.
    for (final set in ['macos', 'ios']) {
      final manifest = jsonDecode(File('${root.path}/$set/Contents.json').readAsStringSync()) as Map<String, dynamic>;
      final names = (manifest['images'] as List).map((e) => (e as Map)['filename'] as String).toSet();
      for (final name in names) {
        final f = File('${root.path}/$set/$name');
        expect(f.existsSync(), isTrue, reason: '$set/$name');
        final image = img.decodePng(f.readAsBytesSync())!;
        final entry = (manifest['images'] as List).cast<Map>().firstWhere((e) => e['filename'] == name);
        final pt = double.parse((entry['size'] as String).split('x').first);
        final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
        expect(image.width, (pt * scale).round(), reason: '$set/$name');
      }
    }
    // The iOS marketing icon carries no alpha.
    final ios1024 = img.decodePng(File('${root.path}/ios/Icon-App-1024x1024@1x.png').readAsBytesSync())!;
    expect(ios1024.numChannels, 3);
  });

  test('--check passes right after rendering and fails when an output is stale', timeout: slow, () async {
    final r = renderer();
    await r.render();
    expect(await r.check(), isEmpty);
    File('${root.path}/favicon-16.png').writeAsBytesSync([0, 1, 2]);
    expect(await r.check(), ['favicon-16.png']);
  });
}
