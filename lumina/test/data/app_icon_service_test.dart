import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';

import 'app_icon_test_support.dart';

/// Every platform's app-icon files, written into a real
/// `flutter create` project from a master PNG decoded out of a real
/// test-assets GLB texture.
void main() {
  late Directory root;
  late String projectDir;
  late Uint8List master;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_app_icons_');
    projectDir = await flutterCreate(root, 'icon_game');
    master = glbTexturePng(kIconTestGlb);
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  img.Image decoded(String rel) {
    final f = File('$projectDir/$rel');
    expect(f.existsSync(), isTrue, reason: '$rel written');
    return img.decodeImage(f.readAsBytesSync())!;
  }

  void expectSize(String rel, int size) {
    final image = decoded(rel);
    expect((image.width, image.height), (size, size), reason: rel);
  }

  test('writes every platform from one master PNG, in the sizes each platform expects', () {
    final report = AppIconService.write(
      projectDir: projectDir,
      masterPng: master,
      appName: 'Icon Game',
      backgroundArgb: 0xFF1E90FF,
    );
    expect(report.platforms.keys.toSet(), kPackagingPlatforms.toSet());
    expect(report.platforms.values.every((p) => p.written), isTrue, reason: report.summary());

    // linux
    expectSize('linux/runner/resources/app_icon.png', 512);
    // windows: one ICO, seven PNG entries 16…256.
    final ico = File('$projectDir/windows/runner/resources/app_icon.ico').readAsBytesSync();
    final header = ByteData.sublistView(ico);
    expect(header.getUint16(2, Endian.little), 1, reason: 'type 1 = icon');
    expect(header.getUint16(4, Endian.little), 7);
    final sizes = [for (var i = 0; i < 7; i++) ico[6 + i * 16] == 0 ? 256 : ico[6 + i * 16]];
    expect(sizes, [16, 24, 32, 48, 64, 128, 256]);
    // macos
    for (final n in [16, 32, 64, 128, 256, 512, 1024]) {
      expectSize('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$n.png', n);
    }
    final macContents = jsonDecode(File('$projectDir/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').readAsStringSync()) as Map;
    expect((macContents['images'] as List).length, 10);
    // ios: every slot of Flutter's Contents.json, no alpha on the App Store icon.
    const ios = {
      'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final e in ios.entries) {
      expectSize('ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}', e.value);
    }
    final marketing = decoded('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
    expect(marketing.hasAlpha && marketing.any((p) => p.a < 255), isFalse, reason: 'App Store icons have no alpha');
    final iosContents = jsonDecode(File('$projectDir/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').readAsStringSync()) as Map;
    expect((iosContents['images'] as List).map((e) => (e as Map)['filename']).toSet(), ios.keys.toSet());
    // android: legacy + adaptive.
    const res = 'android/app/src/main/res';
    const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in legacy.entries) {
      expectSize('$res/mipmap-${e.key}/ic_launcher.png', e.value);
      expectSize('$res/mipmap-${e.key}/ic_launcher_foreground.png', e.value * 108 ~/ 48);
    }
    final adaptive = File('$projectDir/$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
    expect(File('$projectDir/$res/values/ic_launcher_background.xml').readAsStringSync(), contains('#1E90FF'));
    final foreground = decoded('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
    expect(foreground.getPixel(4, 4).a, 0, reason: 'outside the 66/108 safe zone stays transparent');
    // web
    expectSize('web/favicon.png', 32);
    expectSize('web/icons/Icon-192.png', 192);
    expectSize('web/icons/Icon-512.png', 512);
    expectSize('web/icons/Icon-maskable-192.png', 192);
    expectSize('web/icons/Icon-maskable-512.png', 512);
    final corner = decoded('web/icons/Icon-maskable-512.png').getPixel(1, 1);
    expect([corner.r, corner.g, corner.b, corner.a], [0x1E, 0x90, 0xFF, 255], reason: 'maskable corner is the background');
    final manifest = jsonDecode(File('$projectDir/web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['name'], 'Icon Game');
    expect(manifest['background_color'], '#1E90FF');
    expect((manifest['icons'] as List).length, 4);
    expect(manifest['start_url'], '.', reason: 'other template fields are kept');

    expect(report.writtenFiles, contains('linux/runner/resources/app_icon.png'));
    expect(report.writtenFiles.length, greaterThan(40));
  });

  test('the icon pixels come from the master: the Linux icon matches the master downscaled', () {
    AppIconService.write(projectDir: projectDir, masterPng: master, appName: 'Icon Game', platforms: const ['linux']);
    final source = img.decodePng(master)!;
    final icon = decoded('linux/runner/resources/app_icon.png');
    // Centre pixel of the icon vs the master's centre (the master is square).
    final a = icon.getPixel(icon.width ~/ 2, icon.height ~/ 2);
    final b = source.getPixel(source.width ~/ 2, source.height ~/ 2);
    expect((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(), lessThan(60));
  });

  test('the Linux runner and CMake patches are idempotent', () {
    for (var i = 0; i < 2; i++) {
      AppIconService.write(projectDir: projectDir, masterPng: master, appName: 'Icon Game', platforms: const ['linux']);
    }
    final runner = File('$projectDir/linux/runner/my_application.cc').readAsStringSync();
    expect('gtk_window_set_icon_list'.allMatches(runner).length, 1);
    expect(AppIconService.linuxIconBegin.allMatches(runner).length, 1);
    final cmake = File('$projectDir/linux/CMakeLists.txt').readAsStringSync();
    expect('runner/resources/app_icon.png'.allMatches(cmake).length, 1);
    expect(cmake.indexOf('runner/resources/app_icon.png'), greaterThan(cmake.indexOf('set(INSTALL_BUNDLE_DATA_DIR')),
        reason: 'installed after the data dir is defined');
    expect(AppIconService.linuxApplicationId(projectDir), 'com.example.icon_game');
    expect(AppIconService.linuxBinaryName(projectDir), 'icon_game');
  });

  test('the Linux runner sets a window icon list that fits one X11 request', () {
    AppIconService.write(projectDir: projectDir, masterPng: master, appName: 'Icon Game', platforms: const ['linux']);
    final runner = File('$projectDir/linux/runner/my_application.cc').readAsStringSync();
    expect(runner, contains('gtk_window_set_icon_list(window, icons)'));
    expect(runner, isNot(contains('gtk_window_set_icon_from_file')), reason: 'one 512 px image does not fit in _NET_WM_ICON');
    final sizes = RegExp(r'kIconSizes\[\] = \{([^}]*)\}').firstMatch(runner)!.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    expect(sizes, [16, 32, 48, 64, 128]);
    // _NET_WM_ICON holds width, height and width × height values per image;
    // GDK drops the whole list when it exceeds one X request (65 435 values
    // without BIG-REQUESTS, as under XWayland here).
    expect(sizes.fold<int>(0, (sum, s) => sum + 2 + s * s), lessThan(65435));
  });

  test('a platform folder the project lacks is reported and not created', () {
    final bare = Directory('${root.path}/bare')..createSync();
    final report = AppIconService.write(projectDir: bare.path, masterPng: master, appName: 'Bare', platforms: const ['linux', 'web']);
    expect(report.platforms['linux']!.written, isFalse);
    expect(report.platforms['linux']!.skippedReason, contains('linux/'));
    expect(Directory('${bare.path}/linux').existsSync(), isFalse);
    expect(Directory('${bare.path}/web').existsSync(), isFalse);
  });

  test('LinuxBundleBranding.finish writes a .desktop entry and the file-manager icon', () async {
    final bundle = Directory('${root.path}/bundle')..createSync();
    Directory('${bundle.path}/data').createSync();
    File('${bundle.path}/data/app_icon.png').writeAsBytesSync(File('$projectDir/linux/runner/resources/app_icon.png').existsSync()
        ? File('$projectDir/linux/runner/resources/app_icon.png').readAsBytesSync()
        : master);
    final exe = File('${bundle.path}/icon_game')..writeAsBytesSync(File('/bin/true').readAsBytesSync());
    await Process.run('chmod', ['+x', exe.path]);
    final report = await LinuxBundleBranding.finish(
      bundleDir: bundle.path,
      executableName: 'icon_game',
      appName: 'Icon Game',
      applicationId: 'com.example.icon_game',
    );
    final desktop = File('${bundle.path}/com.example.icon_game.desktop');
    expect(desktop.existsSync(), isTrue, reason: report.messages.join('\n'));
    final entry = desktop.readAsStringSync();
    expect(entry, startsWith('[Desktop Entry]'));
    expect(entry, contains('Name=Icon Game'));
    expect(entry, contains('StartupWMClass=com.example.icon_game'));
    final iconLine = entry.split('\n').firstWhere((l) => l.startsWith('Icon='));
    expect(File(iconLine.substring(5)).existsSync(), isTrue);
    if (report.gioAvailable) {
      expect(report.gioIconSet, isTrue, reason: report.messages.join('\n'));
      final info = await Process.run('gio', ['info', '-a', 'metadata::custom-icon', exe.path]);
      expect(info.stdout as String, contains(Uri.file('${bundle.path}/data/app_icon.png').toString()));
    }
    // A bundle without the icon is reported, not papered over.
    final empty = Directory('${root.path}/empty_bundle')..createSync();
    final missing = await LinuxBundleBranding.finish(
        bundleDir: empty.path, executableName: 'x', appName: 'x', applicationId: 'com.example.x', runGio: false);
    expect(missing.ok, isFalse);
    expect(missing.messages.join(), contains('data/app_icon.png'));
  });
}
