import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart' show EditorAssets;

/// Turns a project's icon into the square master PNG that
/// [AppIconService] resamples for every platform.
///
/// SVG icons are drawn by a real vector renderer (flutter_svg's picture,
/// rasterized by `Picture.toImage`), so every size is sharp; raster icons
/// (PNG, JPG, WebP) are decoded by the engine's codecs. Either way the
/// drawing is fitted and centred on a transparent square. A project with no
/// icon of its own uses the editor's Lumina logo.
class ProjectIconRasterizer {
  ProjectIconRasterizer._();

  /// The Lumina logo the editor ships (Project Settings shows it as the
  /// default Project Icon).
  static const String defaultIconAsset = 'assets/logo_color.png';

  /// Extensions Project Settings accepts as a project icon.
  static const List<String> supportedExtensions = ['svg', 'png', 'jpg', 'jpeg', 'webp'];

  /// The side of the master PNG: the largest platform icon (macOS, iOS).
  static const int masterSize = 1024;

  /// The project's icon file, or null when it uses the default logo.
  static File? iconFile(String projectDir, ProjectBrandingSettings branding) =>
      branding.usesDefaultIcon ? null : File('$projectDir/${branding.icon}');

  /// The square master PNG of the project's icon (or the default logo).
  /// Throws a [FormatException] when the file is missing or unreadable.
  static Future<Uint8List> masterPng(String projectDir, ProjectBrandingSettings branding, {int size = masterSize}) async {
    final file = iconFile(projectDir, branding);
    if (file == null) {
      return rasterizeImage(await loadDefaultPngBytes(), size: size);
    }
    if (!file.existsSync()) throw FormatException('the project icon ${file.path} does not exist');
    return rasterizeFile(file, size: size);
  }

  /// The bytes of the default Lumina logo PNG ([defaultIconAsset]): from the
  /// asset bundle, else from the editor's `assets/` folder on disk (tests and
  /// tools that run without a bundle).
  static Future<Uint8List> loadDefaultPngBytes() async {
    try {
      final data = await EditorAssets.load(defaultIconAsset);
      if (data.lengthInBytes > 0) return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {}
    try {
      final data = await rootBundle.load('packages/lumina_ui/$defaultIconAsset');
      if (data.lengthInBytes > 0) return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {}
    for (final path in [defaultIconAsset, 'lumina_ui/$defaultIconAsset', '../lumina_ui/$defaultIconAsset']) {
      final f = File(path);
      if (f.existsSync()) return f.readAsBytes();
    }
    throw const FormatException('the default Lumina logo could not be loaded');
  }

  /// [file] as a square PNG, by its extension.
  static Future<Uint8List> rasterizeFile(File file, {int size = masterSize}) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw FormatException('${file.path}: icons can be ${supportedExtensions.join(', ')} files');
    }
    return ext == 'svg' ? rasterizeSvg(await file.readAsString(), size: size) : rasterizeImage(await file.readAsBytes(), size: size);
  }

  /// Renders [svg] fitted into a transparent [size] square.
  static Future<Uint8List> rasterizeSvg(String svg, {int size = masterSize}) async {
    final PictureInfo info;
    try {
      info = await vg.loadPicture(SvgStringLoader(svg), null);
    } catch (e) {
      throw FormatException('the SVG could not be parsed: $e');
    }
    try {
      final w = info.size.width;
      final h = info.size.height;
      if (w <= 0 || h <= 0) throw const FormatException('the SVG has no size (width/height or viewBox)');
      return await _encodeSquare(size, (canvas, rect) {
        canvas.translate(rect.left, rect.top);
        canvas.scale(rect.width / w, rect.height / h);
        canvas.drawPicture(info.picture);
      }, w, h);
    } finally {
      info.picture.dispose();
    }
  }

  /// Decodes a PNG/JPG/WebP and draws it fitted into a transparent [size]
  /// square.
  static Future<Uint8List> rasterizeImage(Uint8List bytes, {int size = masterSize}) async {
    final ui.Codec codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
    } catch (e) {
      throw FormatException('the image could not be decoded: $e');
    }
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      return await _encodeSquare(size, (canvas, rect) {
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(0, 0, w, h),
          rect,
          ui.Paint()
            ..filterQuality = ui.FilterQuality.high
            ..isAntiAlias = true,
        );
      }, w, h);
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// Draws [paint] into the rect that fits a [w] × [h] drawing, centred, in
  /// a transparent [size] square, and encodes the square as PNG.
  static Future<Uint8List> _encodeSquare(int size, void Function(ui.Canvas canvas, ui.Rect rect) paint, double w, double h) async {
    final scale = size / (w > h ? w : h);
    final dw = w * scale;
    final dh = h * scale;
    final rect = ui.Rect.fromLTWH((size - dw) / 2, (size - dh) / 2, dw, dh);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    paint(canvas, rect);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const FormatException('the icon could not be encoded as PNG');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
