import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

import '../data/app_icon_test_support.dart';

/// Packaging smoke — a real `flutter create`d game project:
/// 1. its legacy single-target manifest is migrated through the repository;
/// 2. every platform's app-icon files are written from a real test-assets
///    GLB texture;
/// 3. the files are read back from disk into a contact sheet (PNG) and a
///    ≥ 10 s video that walks through the platforms.
const _name = 'packaging: app icons for every platform';
const _w = 1366;
const _h = 768;

/// Every icon file of a platform (project-relative), in display order.
Map<String, List<String>> _iconFiles() => {
      'linux': ['linux/runner/resources/app_icon.png'],
      'windows': ['windows/runner/resources/app_icon.ico'],
      'macos': [for (final s in AppIconService.macosSizes) 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$s.png'],
      'android': [
        for (final d in AppIconService.androidDensities.keys) 'android/app/src/main/res/mipmap-$d/ic_launcher.png',
        for (final d in AppIconService.androidDensities.keys) 'android/app/src/main/res/mipmap-$d/ic_launcher_foreground.png',
      ],
      'ios': [
        for (final name in {for (final s in AppIconService.iosSlots) s.$1}) 'ios/Runner/Assets.xcassets/AppIcon.appiconset/$name',
      ],
      'web': ['web/favicon.png', 'web/icons/Icon-192.png', 'web/icons/Icon-512.png', 'web/icons/Icon-maskable-192.png', 'web/icons/Icon-maskable-512.png'],
    };

/// The images inside [file]: one for a PNG, every entry for an ICO.
List<img.Image> _decode(File file) {
  final bytes = file.readAsBytesSync();
  if (file.path.endsWith('.ico')) {
    final ico = img.IcoDecoder();
    ico.startDecode(bytes);
    return [for (var i = 0; i < ico.numFrames(); i++) ico.decodeFrame(i)!];
  }
  return [img.decodeImage(bytes)!];
}

img.Color _rgb(int argb) => img.ColorRgba8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, 255);

/// One frame: a column per platform with its icons as read from disk, the
/// [focus] platform highlighted and its largest icon drawn at [zoom].
img.Image _frame(String projectDir, Map<String, List<img.Image>> icons, String focus, double zoom) {
  final canvas = img.Image(width: _w, height: _h, numChannels: 4);
  img.fill(canvas, color: _rgb(0xFF101014));
  img.drawString(canvas, 'Lumina packaging: app icons written into ${projectDir.split('/').last} (read back from disk)',
      font: img.arial24, x: 24, y: 16, color: _rgb(0xFFE4E4E7));
  const colW = 138;
  for (var c = 0; c < kPackagingPlatforms.length; c++) {
    final p = kPackagingPlatforms[c];
    final x = 24 + c * (colW + 8);
    final selected = p == focus;
    img.fillRect(canvas, x1: x, y1: 56, x2: x + colW, y2: 740, color: _rgb(selected ? 0xFF1E3A5F : 0xFF1A1A1F), radius: 6);
    img.drawString(canvas, packagingPlatformLabel(p), font: img.arial24, x: x + 8, y: 64, color: _rgb(selected ? 0xFF7DD3FC : 0xFFA1A1AA));
    var y = 100;
    for (final icon in icons[p]!) {
      if (y > 700) break;
      final side = icon.width.clamp(16, 64);
      img.compositeImage(canvas, img.copyResize(icon, width: side, height: side), dstX: x + 8, dstY: y);
      img.drawString(canvas, '${icon.width}', font: img.arial14, x: x + 12 + side, y: y + side ~/ 2 - 7, color: _rgb(0xFF71717A));
      y += side + 6;
    }
  }
  // The focused platform's largest icon, zooming in.
  final largest = icons[focus]!.reduce((a, b) => a.width >= b.width ? a : b);
  final side = (300 * zoom).round();
  final big = img.copyResize(largest, width: side, height: side, interpolation: img.Interpolation.average);
  const bx = 24 + 6 * 146 + 20;
  img.fillRect(canvas, x1: bx, y1: 56, x2: _w - 24, y2: 740, color: _rgb(0xFF1A1A1F), radius: 6);
  img.drawString(canvas, '${packagingPlatformLabel(focus)}: ${largest.width} x ${largest.height}', font: img.arial24, x: bx + 16, y: 64, color: _rgb(0xFF7DD3FC));
  img.compositeImage(canvas, big, dstX: bx + (_w - 24 - bx - side) ~/ 2, dstY: 110 + (300 - side) ~/ 2);
  img.drawString(canvas, '${icons[focus]!.length} image(s)', font: img.arial14, x: bx + 16, y: 430, color: _rgb(0xFFA1A1AA));
  return canvas;
}

void main() {
  test(_name, () async {
    final root = Directory.systemTemp.createTempSync('lumina_packaging_smoke_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = await flutterCreate(root, 'icon_smoke_game');

    // 1. A legacy single-target manifest migrates through the repository.
    File('$projectDir/icon_smoke_game.lmproject').writeAsStringSync(jsonEncode({
      'project_name': 'icon_smoke_game',
      'active_level': 'contents/levels/L_DefaultLevel.lmas',
      'packaging': {'target_os': 'Android APK', 'output_dir': 'build'},
    }));
    // Its own config dir: the user's recent-projects list is left alone.
    final repo = ProjectRepository(configDir: Directory('${root.path}/config')..createSync());
    final loaded = (await repo.loadProject('$projectDir/icon_smoke_game.lmproject'))!;
    expect(loaded.packaging.targets, ['android']);
    final ticked = loaded.copyWith(
      packaging: loaded.packaging.withTarget('linux', true).withTarget('web', true),
      branding: const ProjectBrandingSettings(iconBackground: '#1E90FF'),
    );
    await repo.saveProject(ticked, projectDir);
    final raw = jsonDecode(File('$projectDir/icon_smoke_game.lmproject').readAsStringSync()) as Map<String, dynamic>;
    expect((raw['packaging'] as Map)['targets'], ['linux', 'android', 'web']);
    expect((raw['packaging'] as Map).containsKey('target_os'), isFalse);
    expect((raw['branding'] as Map)['icon_background'], '#1E90FF');

    // 2. Every platform's icons from a real GLB texture.
    final report = await AppIconService.writeAsync(
      projectDir: projectDir,
      masterPng: glbTexturePng(kIconTestGlb),
      appName: 'icon_smoke_game',
      backgroundArgb: ticked.branding.iconBackgroundArgb!,
    );
    expect(report.platforms.values.every((p) => p.written), isTrue, reason: report.summary());

    // 3. Read back from disk.
    final files = _iconFiles();
    final icons = {
      for (final e in files.entries) e.key: [for (final rel in e.value) ..._decode(File('$projectDir/$rel'))],
    };
    expect(icons['windows']!.map((i) => i.width), AppIconService.windowsIcoSizes);
    expect(icons['ios']!.map((i) => i.width).reduce((a, b) => a > b ? a : b), 1024);
    expect(icons['web']!.length, 5);

    final sheet = _frame(projectDir, icons, 'linux', 1.0);
    SmokeArtifacts.saveScreenshot(_name, img.encodePng(sheet), usedAssets: [kIconTestGlb]);

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: _name);
    addTearDown(video.discard);
    const perPlatform = 52; // 6 × 52 frames at 30 fps = 10.4 s
    for (final p in kPackagingPlatforms) {
      for (var f = 0; f < perPlatform; f++) {
        final frame = _frame(projectDir, icons, p, 0.55 + 0.45 * f / (perPlatform - 1));
        video.addFrame(Uint8List.fromList(frame.getBytes(order: img.ChannelOrder.rgba)));
      }
    }
    SmokeArtifacts.saveVideo(_name, video.finish(), usedAssets: [kIconTestGlb]);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
