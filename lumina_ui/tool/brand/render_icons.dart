// Renders every app icon Lumina Studio ships from the one brand source,
// `assets/brand/prism_l.svg`:
//
//   dart run tool/brand/render_icons.dart          # write every icon
//   dart run tool/brand/render_icons.dart --check  # fail when one is stale
//
// The SVG's five polygons are rasterised with `package:image` (8× supersampled,
// then filtered down), so no browser or vector tool is needed. The outputs:
// the editor's `assets/app_icon.png`, the Windows `.ico` (16–256 px), the
// Microsoft Store logo, the macOS and iOS `AppIcon.appiconset` files named by
// their `Contents.json`, the favicons and the Linux hicolor icon.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The badge behind the mark on app icons (the editor's darkest surface).
const int badgeColor = 0xFF0F1013;

/// Where the rendered files go; the defaults are the repository's.
class IconOutputs {
  const IconOutputs({
    required this.appIcon,
    required this.windowsIco,
    required this.storeLogo,
    required this.macosSet,
    required this.iosSet,
    required this.favicon16,
    required this.favicon32,
    required this.webFavicon,
    required this.linuxIcon,
  });

  factory IconOutputs.repository(String root) => IconOutputs(
        appIcon: File('$root/assets/app_icon.png'),
        windowsIco: File('$root/windows/runner/resources/app_icon.ico'),
        storeLogo: File('$root/assets/brand/store_logo.png'),
        macosSet: Directory('$root/macos/Runner/Assets.xcassets/AppIcon.appiconset'),
        iosSet: Directory('$root/ios/Runner/Assets.xcassets/AppIcon.appiconset'),
        favicon16: File('$root/assets/brand/favicon-16.png'),
        favicon32: File('$root/assets/brand/favicon-32.png'),
        webFavicon: File('$root/web/favicon.png'),
        linuxIcon: File('$root/assets/brand/icon-512-linux.png'),
      );

  final File appIcon;
  final File windowsIco;
  final File storeLogo;
  final Directory macosSet;
  final Directory iosSet;
  final File favicon16;
  final File favicon32;
  final File webFavicon;
  final File linuxIcon;
}

/// One polygon read from the source SVG.
class SvgPolygon {
  const SvgPolygon(this.points, this.rgb, this.opacity);
  final List<img.Point> points;
  final int rgb;
  final double opacity;
}

/// Reads the `<polygon>` elements of the brand SVG (points, fill, fill-opacity).
List<SvgPolygon> parsePolygons(String svg) {
  final out = <SvgPolygon>[];
  for (final m in RegExp(r'<polygon\b([^>]*)/?>').allMatches(svg)) {
    final attrs = m.group(1)!;
    String? attr(String name) => RegExp('$name="([^"]*)"').firstMatch(attrs)?.group(1);
    final pts = attr('points')!.trim().split(RegExp(r'\s+')).map((p) {
      final xy = p.split(',');
      return img.Point(double.parse(xy[0]), double.parse(xy[1]));
    }).toList();
    final fill = attr('fill') ?? '#000000';
    final opacity = double.parse(attr('fill-opacity') ?? '1');
    out.add(SvgPolygon(pts, int.parse(fill.substring(1), radix: 16), opacity));
  }
  if (out.isEmpty) throw StateError('no <polygon> in the brand SVG');
  return out;
}

class IconRenderer {
  IconRenderer({required this.source, required this.outputs});

  final File source;
  final IconOutputs outputs;

  /// Supersampling per size: the small icons need the most edge quality, the
  /// large ones are smooth at 2× and would otherwise raster an 8192² image.
  static int _supersampleFor(int size) => size <= 64 ? 8 : (size <= 256 ? 4 : 2);

  /// Every file as it would be rendered now, keyed by its path.
  Future<Map<String, Uint8List>> renderAll() async {
    final polygons = parsePolygons(await source.readAsString());
    final files = <String, Uint8List>{};

    files[outputs.appIcon.path] = _png(_badge(polygons, 512, radius: 0.22));
    files[outputs.linuxIcon.path] = _png(_badge(polygons, 512, radius: 0.22));
    files[outputs.storeLogo.path] = _png(_badge(polygons, 300, radius: 0, inset: 0.16, opaque: true));
    files[outputs.favicon16.path] = _png(_badge(polygons, 16, radius: 0.22));
    files[outputs.favicon32.path] = _png(_badge(polygons, 32, radius: 0.22));
    files[outputs.webFavicon.path] = _png(_badge(polygons, 32, radius: 0.22));
    files[outputs.windowsIco.path] =
        img.IcoEncoder().encodeImages([for (final s in [16, 24, 32, 48, 64, 128, 256]) _badge(polygons, s, radius: 0.22)]);

    for (final (dir, rounded, stripAlpha) in [(outputs.macosSet, true, false), (outputs.iosSet, false, true)]) {
      final manifest = jsonDecode(await File('${dir.path}/Contents.json').readAsString()) as Map<String, dynamic>;
      for (final e in (manifest['images'] as List).cast<Map<String, dynamic>>()) {
        final name = e['filename'] as String?;
        if (name == null) continue;
        final pt = double.parse((e['size'] as String).split('x').first);
        final scale = int.parse((e['scale'] as String).replaceAll('x', ''));
        final px = (pt * scale).round();
        files['${dir.path}/$name'] = _png(_badge(polygons, px, radius: rounded ? 0.22 : 0, opaque: stripAlpha));
      }
    }
    return files;
  }

  /// Writes every file; returns the paths written.
  Future<List<String>> render() async {
    final files = await renderAll();
    for (final e in files.entries) {
      final f = File(e.key);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(e.value);
    }
    return files.keys.toList();
  }

  /// The files on disk that differ from a fresh render (missing counts).
  Future<List<String>> check() async {
    final files = await renderAll();
    final stale = <String>[];
    for (final e in files.entries) {
      final f = File(e.key);
      if (!await f.exists() || !_same(await f.readAsBytes(), e.value)) stale.add(_name(e.key));
    }
    return stale;
  }

  String _name(String path) => path.split(RegExp(r'[\\/]')).last;

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Uint8List _png(img.Image i) => img.encodePng(i, level: 6);

  /// The mark centred on a badge of [size] px: a rounded square (`radius` as a
  /// fraction of the size, 0 = square) in [badgeColor]; `inset` is the margin
  /// each side as a fraction; `opaque` drops the alpha channel.
  static img.Image _badge(List<SvgPolygon> polygons, int size, {required double radius, double inset = 0.12, bool opaque = false}) {
    final ss = size * _supersampleFor(size);
    final big = img.Image(width: ss, height: ss, numChannels: 4);
    img.fill(big, color: img.ColorRgba8(0, 0, 0, 0));
    final r = (radius * ss).round();
    img.fillRect(big, x1: 0, y1: 0, x2: ss - 1, y2: ss - 1, radius: r, color: _rgb(badgeColor, 1));
    final margin = inset * ss;
    final scale = (ss - 2 * margin) / 100;
    for (final p in polygons) {
      img.fillPolygon(
        big,
        vertices: [for (final v in p.points) img.Point(margin + v.x * scale, margin + v.y * scale)],
        color: _rgb(p.rgb, p.opacity),
      );
    }
    final small = img.copyResize(big, width: size, height: size, interpolation: img.Interpolation.cubic);
    if (!opaque) return small;
    final rgb = img.Image(width: size, height: size, numChannels: 3);
    for (final p in small) {
      rgb.setPixelRgb(p.x, p.y, p.r, p.g, p.b);
    }
    return rgb;
  }

  static img.Color _rgb(int rgb, double opacity) =>
      img.ColorRgba8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, (opacity * 255).round());
}

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final rootIndex = args.indexOf('--root');
  final root = rootIndex >= 0 ? args[rootIndex + 1] : Directory.current.path;
  final renderer = IconRenderer(source: File('$root/assets/brand/prism_l.svg'), outputs: IconOutputs.repository(root));
  if (check) {
    final stale = await renderer.check();
    if (stale.isEmpty) {
      stdout.writeln('icons up to date');
      return;
    }
    stderr.writeln('stale icons (run dart run tool/brand/render_icons.dart): ${stale.join(', ')}');
    exitCode = 1;
    return;
  }
  final written = await renderer.render();
  stdout.writeln('rendered ${written.length} icons from ${renderer.source.path}');
}
