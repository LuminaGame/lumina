import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:lumina/data/models/lumina_project.dart';

/// What [AppIconService.write] did for one platform.
class AppIconPlatformResult {
  final String platform;

  /// Project-relative paths of the files written.
  final List<String> files;

  /// Why nothing was written (the project has no folder for the platform).
  final String? skippedReason;

  /// Notes worth logging: a runner patch that could not find its anchor.
  final List<String> warnings;

  const AppIconPlatformResult(this.platform, {this.files = const [], this.skippedReason, this.warnings = const []});

  bool get written => skippedReason == null && files.isNotEmpty;
}

class AppIconReport {
  final Map<String, AppIconPlatformResult> platforms;
  const AppIconReport(this.platforms);

  List<String> get writtenFiles => [for (final p in platforms.values) ...p.files];

  String summary() => platforms.values
      .map((p) => p.written ? '${p.platform}: ${p.files.length} file(s)' : '${p.platform}: ${p.skippedReason ?? 'nothing written'}')
      .join('; ');
}

/// Writes a game project's app-icon files for every platform from one
/// high-resolution master PNG: Windows ICO, macOS and iOS
/// icon sets, Android legacy and adaptive mipmaps, the web favicon, icons and
/// manifest, and the Linux runner icon plus the runner/CMake patches that
/// show it. The master is resampled with `package:image`; rasterizing an
/// SVG into that master is the caller's job (the editor uses flutter_svg).
class AppIconService {
  AppIconService._();

  static const String linuxIconBegin = '// BEGIN LUMINA APP ICON (generated: Project Settings → Project Icon)';
  static const String linuxIconEnd = '// END LUMINA APP ICON';
  static const String cmakeIconBegin = '# BEGIN LUMINA APP ICON (generated: Project Settings → Project Icon)';
  static const String cmakeIconEnd = '# END LUMINA APP ICON';

  /// The Linux runner loads this from the bundle's `data/` at startup.
  static const String linuxBundleIconName = 'app_icon.png';

  static const List<int> windowsIcoSizes = [16, 24, 32, 48, 64, 128, 256];
  static const List<int> macosSizes = [16, 32, 64, 128, 256, 512, 1024];

  /// Flutter's iOS `AppIcon.appiconset` slots: (filename, size, idiom, scale, pixels).
  static const List<(String, String, String, String, int)> iosSlots = [
    ('Icon-App-20x20@2x.png', '20x20', 'iphone', '2x', 40),
    ('Icon-App-20x20@3x.png', '20x20', 'iphone', '3x', 60),
    ('Icon-App-29x29@1x.png', '29x29', 'iphone', '1x', 29),
    ('Icon-App-29x29@2x.png', '29x29', 'iphone', '2x', 58),
    ('Icon-App-29x29@3x.png', '29x29', 'iphone', '3x', 87),
    ('Icon-App-40x40@2x.png', '40x40', 'iphone', '2x', 80),
    ('Icon-App-40x40@3x.png', '40x40', 'iphone', '3x', 120),
    ('Icon-App-60x60@2x.png', '60x60', 'iphone', '2x', 120),
    ('Icon-App-60x60@3x.png', '60x60', 'iphone', '3x', 180),
    ('Icon-App-20x20@1x.png', '20x20', 'ipad', '1x', 20),
    ('Icon-App-20x20@2x.png', '20x20', 'ipad', '2x', 40),
    ('Icon-App-29x29@1x.png', '29x29', 'ipad', '1x', 29),
    ('Icon-App-29x29@2x.png', '29x29', 'ipad', '2x', 58),
    ('Icon-App-40x40@1x.png', '40x40', 'ipad', '1x', 40),
    ('Icon-App-40x40@2x.png', '40x40', 'ipad', '2x', 80),
    ('Icon-App-76x76@1x.png', '76x76', 'ipad', '1x', 76),
    ('Icon-App-76x76@2x.png', '76x76', 'ipad', '2x', 152),
    ('Icon-App-83.5x83.5@2x.png', '83.5x83.5', 'ipad', '2x', 167),
    ('Icon-App-1024x1024@1x.png', '1024x1024', 'ios-marketing', '1x', 1024),
  ];

  /// Android densities and their legacy launcher size (48 dp).
  static const Map<String, int> androidDensities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};

  /// Adaptive icons are 108 dp and masked to about 66 dp: the foreground
  /// keeps the icon inside the middle 66/108.
  static const double androidSafeZone = 66 / 108;

  /// Maskable web icons keep their content inside the central 80 %.
  static const double webMaskableSafeZone = 0.8;

  /// [write] on a background isolate, so the editor's UI keeps running while
  /// ~50 images are resampled.
  static Future<AppIconReport> writeAsync({
    required String projectDir,
    required Uint8List masterPng,
    required String appName,
    int backgroundArgb = 0xFF000000,
    Iterable<String> platforms = kPackagingPlatforms,
  }) {
    final list = platforms.toList();
    return Isolate.run(() => write(
          projectDir: projectDir,
          masterPng: masterPng,
          appName: appName,
          backgroundArgb: backgroundArgb,
          platforms: list,
        ));
  }

  /// Writes the icon files of every platform in [platforms] whose folder the
  /// project has; a missing folder is reported, never created.
  static AppIconReport write({
    required String projectDir,
    required Uint8List masterPng,
    required String appName,
    int backgroundArgb = 0xFF000000,
    Iterable<String> platforms = kPackagingPlatforms,
  }) {
    final decoded = img.decodeImage(masterPng);
    if (decoded == null) throw const FormatException('the master icon is not a decodable image');
    final master = _square(decoded.convert(numChannels: 4));
    final ctx = _Ctx(projectDir, master, appName, backgroundArgb);
    final results = <String, AppIconPlatformResult>{};
    for (final p in platforms) {
      results[p] = switch (p) {
        'linux' => ctx.linux(),
        'windows' => ctx.windows(),
        'macos' => ctx.macos(),
        'ios' => ctx.ios(),
        'android' => ctx.android(),
        'web' => ctx.web(),
        _ => AppIconPlatformResult(p, skippedReason: 'no app-icon layout for "$p"'),
      };
    }
    return AppIconReport(results);
  }

  /// `APPLICATION_ID` from the project's `linux/CMakeLists.txt`.
  static String? linuxApplicationId(String projectDir) => _cmakeVar(projectDir, 'APPLICATION_ID');

  /// `BINARY_NAME` from the project's `linux/CMakeLists.txt`.
  static String? linuxBinaryName(String projectDir) => _cmakeVar(projectDir, 'BINARY_NAME');

  static String? _cmakeVar(String projectDir, String name) {
    final f = File('$projectDir/linux/CMakeLists.txt');
    if (!f.existsSync()) return null;
    return RegExp('set\\($name\\s+"([^"]+)"\\)').firstMatch(f.readAsStringSync())?.group(1);
  }

  /// [image] fitted into a transparent square, centred.
  static img.Image _square(img.Image image) {
    if (image.width == image.height) return image;
    final side = image.width > image.height ? image.width : image.height;
    final canvas = img.Image(width: side, height: side, numChannels: 4);
    img.compositeImage(canvas, image, dstX: (side - image.width) ~/ 2, dstY: (side - image.height) ~/ 2, blend: img.BlendMode.direct);
    return canvas;
  }
}

class _Ctx {
  final String projectDir;
  final img.Image master;
  final String appName;
  final int background;
  _Ctx(this.projectDir, this.master, this.appName, this.background);

  final Map<int, img.Image> _cache = {};

  /// The master resampled to [size] (area average down, cubic up).
  img.Image resized(int size) => _cache.putIfAbsent(
        size,
        () => img.copyResize(
          master,
          width: size,
          height: size,
          interpolation: size < master.width ? img.Interpolation.average : img.Interpolation.cubic,
        ),
      );

  /// A [size] canvas: filled with [fill] (or transparent), the icon scaled to
  /// [scale] of it and centred.
  img.Image framed(int size, double scale, {int? fill}) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    if (fill != null) {
      img.fill(canvas, color: img.ColorRgba8((fill >> 16) & 0xFF, (fill >> 8) & 0xFF, fill & 0xFF, 255));
    }
    final inner = (size * scale).round();
    final icon = resized(inner);
    img.compositeImage(canvas, icon, dstX: (size - inner) ~/ 2, dstY: (size - inner) ~/ 2);
    return canvas;
  }

  String get hex => '#${(background & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Directory? platformDir(String rel) {
    final d = Directory('$projectDir/$rel');
    return d.existsSync() ? d : null;
  }

  String writePng(String rel, img.Image image) {
    final f = File('$projectDir/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(img.encodePng(image), flush: true);
    return rel;
  }

  String writeText(String rel, String text) {
    final f = File('$projectDir/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text, flush: true);
    return rel;
  }

  AppIconPlatformResult missing(String platform, String folder) =>
      AppIconPlatformResult(platform, skippedReason: 'the project has no $folder/ folder (run `flutter create --platforms=$platform .`)');

  // --- linux ------------------------------------------------------------------

  AppIconPlatformResult linux() {
    if (platformDir('linux') == null) return missing('linux', 'linux');
    final files = <String>[writePng('linux/runner/resources/${AppIconService.linuxBundleIconName}', resized(512))];
    final warnings = <String>[];
    final runner = File('$projectDir/linux/runner/my_application.cc');
    if (runner.existsSync()) {
      final patched = _patchRunner(runner.readAsStringSync());
      if (patched == null) {
        warnings.add('linux/runner/my_application.cc: no gtk_window_set_default_size / FlDartProject line to anchor the window icon on');
      } else {
        runner.writeAsStringSync(patched, flush: true);
        files.add('linux/runner/my_application.cc');
      }
    } else {
      warnings.add('linux/runner/my_application.cc is missing: the window icon is not set');
    }
    final cmake = File('$projectDir/linux/CMakeLists.txt');
    if (cmake.existsSync()) {
      final patched = _patchCmake(cmake.readAsStringSync());
      if (patched == null) {
        warnings.add('linux/CMakeLists.txt: no INSTALL_BUNDLE_DATA_DIR to install the icon into');
      } else {
        cmake.writeAsStringSync(patched, flush: true);
        files.add('linux/CMakeLists.txt');
      }
    } else {
      warnings.add('linux/CMakeLists.txt is missing: the icon is not installed into the bundle');
    }
    return AppIconPlatformResult('linux', files: files, warnings: warnings);
  }

  static String _stripBlock(String source, String begin, String end) {
    final start = source.indexOf(begin);
    if (start < 0) return source;
    final stop = source.indexOf(end, start);
    if (stop < 0) return source;
    var lineStart = source.lastIndexOf('\n', start) + 1;
    var lineEnd = source.indexOf('\n', stop);
    lineEnd = lineEnd < 0 ? source.length : lineEnd + 1;
    return source.substring(0, lineStart) + source.substring(lineEnd);
  }

  static const String _runnerBlock = '''
  ${AppIconService.linuxIconBegin}
  // The bundle's data/${AppIconService.linuxBundleIconName} is the window icon (X11/XWayland
  // _NET_WM_ICON). GNOME on Wayland takes the dock icon from the installed
  // .desktop entry named after APPLICATION_ID instead.
  // A list of small sizes, not the 512 px file: GDK drops an icon list that
  // does not fit in one X request (about 65 435 values without BIG-REQUESTS).
  {
    g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
    if (exe_path != nullptr) {
      g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
      g_autofree gchar* icon_path =
          g_build_filename(exe_dir, "data", "${AppIconService.linuxBundleIconName}", nullptr);
      g_autoptr(GdkPixbuf) icon = gdk_pixbuf_new_from_file(icon_path, nullptr);
      if (icon != nullptr) {
        static const int kIconSizes[] = {16, 32, 48, 64, 128};
        GList* icons = nullptr;
        for (int size : kIconSizes) {
          icons = g_list_append(
              icons, gdk_pixbuf_scale_simple(icon, size, size, GDK_INTERP_BILINEAR));
        }
        gtk_window_set_icon_list(window, icons);
        g_list_free_full(icons, g_object_unref);
      }
    }
  }
  ${AppIconService.linuxIconEnd}
''';

  /// Inserts the window-icon block after `gtk_window_set_default_size`
  /// (Flutter's template), else before the `FlDartProject` line; null when
  /// neither exists.
  static String? _patchRunner(String source) {
    final clean = _stripBlock(source, AppIconService.linuxIconBegin, AppIconService.linuxIconEnd);
    final anchor = RegExp(r'^.*gtk_window_set_default_size\(window[^\n]*\n', multiLine: true).firstMatch(clean);
    if (anchor != null) return clean.substring(0, anchor.end) + _runnerBlock + clean.substring(anchor.end);
    final before = RegExp(r'^.*FlDartProject\) project[^\n]*\n', multiLine: true).firstMatch(clean);
    if (before != null) return clean.substring(0, before.start) + _runnerBlock + clean.substring(before.start);
    return null;
  }

  static const String _cmakeBlock = '''
${AppIconService.cmakeIconBegin}
install(FILES "\${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/${AppIconService.linuxBundleIconName}"
  DESTINATION "\${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
${AppIconService.cmakeIconEnd}
''';

  /// Installs the icon into the bundle's `data/`, after the data dir is
  /// defined; null when the file does not define it.
  static String? _patchCmake(String source) {
    final clean = _stripBlock(source, AppIconService.cmakeIconBegin, AppIconService.cmakeIconEnd);
    final anchor = RegExp(r'^set\(INSTALL_BUNDLE_LIB_DIR[^\n]*\n', multiLine: true).firstMatch(clean) ??
        RegExp(r'^set\(INSTALL_BUNDLE_DATA_DIR[^\n]*\n', multiLine: true).firstMatch(clean);
    if (anchor == null) return null;
    return '${clean.substring(0, anchor.end)}\n$_cmakeBlock${clean.substring(anchor.end)}';
  }

  // --- windows ------------------------------------------------------------------

  AppIconPlatformResult windows() {
    if (platformDir('windows') == null) return missing('windows', 'windows');
    const rel = 'windows/runner/resources/app_icon.ico';
    final f = File('$projectDir/$rel')..parent.createSync(recursive: true);
    f.writeAsBytesSync(img.IcoEncoder().encodeImages([for (final s in AppIconService.windowsIcoSizes) resized(s)]), flush: true);
    return const AppIconPlatformResult('windows', files: [rel]);
  }

  // --- macos --------------------------------------------------------------------

  AppIconPlatformResult macos() {
    if (platformDir('macos') == null) return missing('macos', 'macos');
    const set = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
    final files = [for (final s in AppIconService.macosSizes) writePng('$set/app_icon_$s.png', resized(s))];
    Map<String, String> entry(String size, String scale, int px) =>
        {'size': size, 'idiom': 'mac', 'filename': 'app_icon_$px.png', 'scale': scale};
    files.add(writeText(
      '$set/Contents.json',
      const JsonEncoder.withIndent('  ').convert({
        'images': [
          entry('16x16', '1x', 16), entry('16x16', '2x', 32),
          entry('32x32', '1x', 32), entry('32x32', '2x', 64),
          entry('128x128', '1x', 128), entry('128x128', '2x', 256),
          entry('256x256', '1x', 256), entry('256x256', '2x', 512),
          entry('512x512', '1x', 512), entry('512x512', '2x', 1024),
        ],
        'info': {'version': 1, 'author': 'xcode'},
      }),
    ));
    return AppIconPlatformResult('macos', files: files);
  }

  // --- ios --------------------------------------------------------------------------

  AppIconPlatformResult ios() {
    if (platformDir('ios') == null) return missing('ios', 'ios');
    const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final files = <String>[];
    final written = <String>{};
    for (final (name, _, _, _, px) in AppIconService.iosSlots) {
      // App Store icons have no alpha: every size is flattened onto the background.
      if (written.add(name)) files.add(writePng('$set/$name', framed(px, 1.0, fill: background).convert(numChannels: 3)));
    }
    files.add(writeText(
      '$set/Contents.json',
      const JsonEncoder.withIndent('  ').convert({
        'images': [
          for (final (name, size, idiom, scale, _) in AppIconService.iosSlots)
            {'size': size, 'idiom': idiom, 'filename': name, 'scale': scale},
        ],
        'info': {'version': 1, 'author': 'xcode'},
      }),
    ));
    return AppIconPlatformResult('ios', files: files);
  }

  // --- android ------------------------------------------------------------------

  AppIconPlatformResult android() {
    const res = 'android/app/src/main/res';
    if (platformDir(res) == null) return missing('android', 'android');
    final files = <String>[];
    for (final e in AppIconService.androidDensities.entries) {
      files.add(writePng('$res/mipmap-${e.key}/ic_launcher.png', resized(e.value)));
      final adaptive = e.value * 108 ~/ 48;
      files.add(writePng('$res/mipmap-${e.key}/ic_launcher_foreground.png', framed(adaptive, AppIconService.androidSafeZone)));
    }
    files.add(writeText('$res/mipmap-anydpi-v26/ic_launcher.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by Lumina Studio from the project icon (Project Settings → Project Icon). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''));
    files.add(writeText('$res/values/ic_launcher_background.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by Lumina Studio: Project Settings → Icon Background. -->
<resources>
    <color name="ic_launcher_background">$hex</color>
</resources>
'''));
    return AppIconPlatformResult('android', files: files);
  }

  // --- web ------------------------------------------------------------------------

  AppIconPlatformResult web() {
    if (platformDir('web') == null) return missing('web', 'web');
    final files = <String>[
      writePng('web/favicon.png', resized(32)),
      writePng('web/icons/Icon-192.png', resized(192)),
      writePng('web/icons/Icon-512.png', resized(512)),
      writePng('web/icons/Icon-maskable-192.png', framed(192, AppIconService.webMaskableSafeZone, fill: background)),
      writePng('web/icons/Icon-maskable-512.png', framed(512, AppIconService.webMaskableSafeZone, fill: background)),
    ];
    final manifestFile = File('$projectDir/web/manifest.json');
    Map<String, dynamic> manifest = {};
    if (manifestFile.existsSync()) {
      try {
        manifest = Map<String, dynamic>.from(jsonDecode(manifestFile.readAsStringSync()) as Map);
      } catch (_) {
        manifest = {};
      }
    }
    manifest
      ..['name'] = appName
      ..['short_name'] = appName
      ..putIfAbsent('start_url', () => '.')
      ..putIfAbsent('display', () => 'standalone')
      ..['background_color'] = hex
      ..['theme_color'] = hex
      ..['icons'] = [
        {'src': 'icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
        {'src': 'icons/Icon-512.png', 'sizes': '512x512', 'type': 'image/png'},
        {'src': 'icons/Icon-maskable-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
        {'src': 'icons/Icon-maskable-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'},
      ];
    files.add(writeText('web/manifest.json', '${const JsonEncoder.withIndent('    ').convert(manifest)}\n'));
    return AppIconPlatformResult('web', files: files);
  }
}

/// What [LinuxBundleBranding.finish] did to a packaged Linux bundle.
class LinuxBundleReport {
  final bool ok;
  final String? desktopFile;
  final bool gioAvailable;
  final bool gioIconSet;
  final List<String> messages;
  const LinuxBundleReport({required this.ok, this.desktopFile, this.gioAvailable = false, this.gioIconSet = false, this.messages = const []});
}

/// Finishes a built Linux bundle so it presents the project icon outside the
/// running window too: a `.desktop` entry in the bundle, and the executable's
/// file-manager icon on this host. An ELF file carries no icon of its own;
/// the file manager reads GIO metadata (`metadata::custom-icon`), which is
/// stored per user on this machine and does not travel with a copy.
class LinuxBundleBranding {
  LinuxBundleBranding._();

  static Future<LinuxBundleReport> finish({
    required String bundleDir,
    required String executableName,
    required String appName,
    required String applicationId,
    bool runGio = true,
  }) async {
    final dir = Directory(bundleDir).absolute.path;
    final icon = File('$dir/data/${AppIconService.linuxBundleIconName}');
    final exe = File('$dir/$executableName');
    if (!icon.existsSync()) {
      return LinuxBundleReport(ok: false, messages: [
        '$dir has no data/${AppIconService.linuxBundleIconName}: the project was built before its runner and CMakeLists installed the icon',
      ]);
    }
    final messages = <String>[];
    String quoted(String path) => path.contains(RegExp(r'[\s"`$\\]')) ? '"${path.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}')}"' : path;
    final desktop = File('$dir/$applicationId.desktop');
    desktop.writeAsStringSync([
      '[Desktop Entry]',
      'Type=Application',
      'Name=$appName',
      'Exec=${quoted(exe.path)}',
      'Path=$dir',
      'Icon=${icon.path}',
      'Terminal=false',
      'Categories=Game;',
      'StartupWMClass=$applicationId',
      '',
    ].join('\n'), flush: true);
    messages.add('Wrote ${desktop.path}');
    var gioAvailable = false;
    var gioSet = false;
    if (runGio && exe.existsSync()) {
      try {
        final set = await Process.run('gio', ['set', exe.path, 'metadata::custom-icon', Uri.file(icon.path).toString()]);
        gioAvailable = true;
        if (set.exitCode == 0) {
          gioSet = true;
          messages.add('Set the file-manager icon of ${exe.path} (gio metadata::custom-icon)');
        } else {
          messages.add('gio set failed (exit ${set.exitCode}): ${(set.stderr as String).trim()}');
        }
      } on ProcessException catch (e) {
        messages.add('gio is not available, so the executable keeps the generic file-manager icon: ${e.message}');
      }
    } else if (runGio) {
      messages.add('${exe.path} does not exist: no file-manager icon set');
    }
    return LinuxBundleReport(ok: true, desktopFile: desktop.path, gioAvailable: gioAvailable, gioIconSet: gioSet, messages: messages);
  }
}
