part of '../asset_repository.dart';

/// Thumbnail bytes per asset type: rendered meshes and materials, and the
/// drawn icons of the other types.
mixin _AssetThumbnails on _AssetRepositoryState {

  Future<Uint8List?> generateThumbnailBytes(AssetType type, {Uint8List? rawPayload}) async {
    return _generateThumbnailBytes(type, rawPayload: rawPayload);
  }

  /// [geometryResolved]: the payload's mesh was already parsed and projected
  /// (off the UI isolate) into [geometry] — null when it holds no mesh — so
  /// it is not parsed again here.
  @override
  Future<Uint8List?> _generateThumbnailBytes(
    AssetType type, {
    Uint8List? rawPayload,
    MeshThumbnailGeometry? geometry,
    bool geometryResolved = false,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 128, 128));

      // 1. Card frame. A neutral grey, mirroring the editor's palette, which
      // this package sits below and cannot import: every surface there is
      // `oklch(L 0 0)`, so this carries no hue either. Asserted by
      // `test/asset_test.dart`.
      final bgPaint = ui.Paint()..color = const ui.Color(0xFF141414);
      final bgRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(4, 4, 120, 120), const ui.Radius.circular(12));
      canvas.drawRRect(bgRect, bgPaint);

      // Border Outline
      final borderPaint = ui.Paint()
        ..color = const ui.Color(0xFF2E2E2E)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(bgRect, borderPaint);

      final meshGeometry = geometryResolved ? geometry : await MeshThumbnailGeometry.forPayload(type, rawPayload);

      if (type == AssetType.texture && rawPayload != null && rawPayload.isNotEmpty) {
        try {
          final codec = await ui.instantiateImageCodec(rawPayload);
          final frame = await codec.getNextFrame();
          final img = frame.image;
          final srcRect = ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
          final dstRect = const ui.Rect.fromLTWH(8, 8, 112, 112);
          canvas.drawImageRect(img, srcRect, dstRect, ui.Paint());
        } catch (_) {
          _drawTextureThumbnail(canvas);
        }
      } else if (meshGeometry != null) {
        _paintMeshThumbnail(canvas, meshGeometry);
      } else {
        switch (type) {
          case AssetType.filamesh:
          case AssetType.filameshSk:
            _drawDefaultMeshThumbnail(canvas);
            break;
          case AssetType.filamat:
            _drawMaterialThumbnail(canvas);
            break;
          case AssetType.texture:
            _drawTextureThumbnail(canvas);
            break;
          case AssetType.actor:
            _drawBlueprintThumbnail(canvas);
            break;
          case AssetType.level:
            _drawLevelThumbnail(canvas);
            break;
          case AssetType.sequencer:
            _drawSequencerThumbnail(canvas);
            break;
          case AssetType.widget:
            _drawWidgetThumbnail(canvas);
            break;
          case AssetType.animation:
            _drawAnimationThumbnail(canvas);
            break;
          case AssetType.audio:
            _drawAudioThumbnail(canvas);
            break;
          case AssetType.particle:
            _drawParticleThumbnail(canvas);
            break;
          case AssetType.physicsAsset:
            _drawPhysicsThumbnail(canvas);
            break;
          case AssetType.landscape:
            _drawLandscapeThumbnail(canvas);
            break;
          default:
            final center = const ui.Offset(64, 64);
            canvas.drawCircle(center, 32, ui.Paint()..color = const ui.Color(0xFF00B0FF));
            break;
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(128, 128);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      _logger.log('Thumbnail generation exception for type $type: $e', level: 'warning', source: 'AssetRepository');
    }
    return AssetRepository._fallbackPngBytes;
  }

  void _drawBlueprintThumbnail(ui.Canvas canvas) {
    // Blueprint graph grid background
    final gridPaint = ui.Paint()
      ..color = const ui.Color(0x2200B0FF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double i = 16; i <= 112; i += 16) {
      canvas.drawLine(ui.Offset(16, i), ui.Offset(112, i), gridPaint);
      canvas.drawLine(ui.Offset(i, 16), ui.Offset(i, 112), gridPaint);
    }
    // Blueprint Node Box
    final nodeRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(24, 32, 80, 64), const ui.Radius.circular(6));
    canvas.drawRRect(nodeRect, ui.Paint()..color = const ui.Color(0xFF282828));
    canvas.drawRRect(nodeRect, ui.Paint()..color = const ui.Color(0xFF00B0FF)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);
    // Node Header Bar
    final headerRect = ui.RRect.fromRectAndCorners(const ui.Rect.fromLTWH(24, 32, 80, 18), topLeft: const ui.Radius.circular(6), topRight: const ui.Radius.circular(6));
    canvas.drawRRect(headerRect, ui.Paint()..color = const ui.Color(0xFF0288D1));
    // Pins
    canvas.drawCircle(const ui.Offset(24, 62), 4, ui.Paint()..color = const ui.Color(0xFF00E5FF));
    canvas.drawCircle(const ui.Offset(24, 78), 4, ui.Paint()..color = const ui.Color(0xFFFFD600));
    canvas.drawCircle(const ui.Offset(104, 62), 4, ui.Paint()..color = const ui.Color(0xFF00E676));
    canvas.drawCircle(const ui.Offset(104, 78), 4, ui.Paint()..color = const ui.Color(0xFFFF3D00));
  }

  void _drawLevelThumbnail(ui.Canvas canvas) {
    // Level Horizon & Ground Floor
    final groundPath = ui.Path()
      ..moveTo(16, 72)
      ..lineTo(112, 72)
      ..lineTo(112, 112)
      ..lineTo(16, 112)
      ..close();
    canvas.drawPath(groundPath, ui.Paint()..color = const ui.Color(0xFF242424));
    // Grid Lines on Floor
    final floorPaint = ui.Paint()..color = const ui.Color(0x44FFB300)..strokeWidth = 1.0;
    canvas.drawLine(const ui.Offset(16, 92), const ui.Offset(112, 92), floorPaint);
    canvas.drawLine(const ui.Offset(64, 72), const ui.Offset(64, 112), floorPaint);
    canvas.drawLine(const ui.Offset(36, 72), const ui.Offset(24, 112), floorPaint);
    canvas.drawLine(const ui.Offset(92, 72), const ui.Offset(104, 112), floorPaint);
    // Sun / Atmosphere Sphere
    canvas.drawCircle(const ui.Offset(64, 46), 18, ui.Paint()..color = const ui.Color(0xFFFFB300));
    canvas.drawCircle(const ui.Offset(64, 46), 22, ui.Paint()..color = const ui.Color(0x33FFB300));
    // Axis gizmo indicator
    canvas.drawLine(const ui.Offset(64, 72), const ui.Offset(64, 58), ui.Paint()..color = const ui.Color(0xFF00E676)..strokeWidth = 2);
    canvas.drawLine(const ui.Offset(64, 72), const ui.Offset(80, 72), ui.Paint()..color = const ui.Color(0xFFFF1744)..strokeWidth = 2);
  }

  void _drawSequencerThumbnail(ui.Canvas canvas) {
    // Clapperboard & Filmstrip Timeline
    final clapperRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(20, 24, 88, 80), const ui.Radius.circular(8));
    canvas.drawRRect(clapperRect, ui.Paint()..color = const ui.Color(0xFF282828));
    canvas.drawRRect(clapperRect, ui.Paint()..color = const ui.Color(0xFFFF5722)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);
    // Clapper Top Bar
    final topBar = ui.RRect.fromRectAndCorners(const ui.Rect.fromLTWH(20, 24, 88, 20), topLeft: const ui.Radius.circular(8), topRight: const ui.Radius.circular(8));
    canvas.drawRRect(topBar, ui.Paint()..color = const ui.Color(0xFFFF3D00));
    // Timeline Lanes
    canvas.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(26, 52, 76, 12), const ui.Radius.circular(3)), ui.Paint()..color = const ui.Color(0xFF171717));
    canvas.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(26, 70, 76, 12), const ui.Radius.circular(3)), ui.Paint()..color = const ui.Color(0xFF171717));
    // Diamonds (Keyframes)
    final dPaint = ui.Paint()..color = const ui.Color(0xFFFFAB00);
    _drawDiamond(canvas, const ui.Offset(40, 58), 4, dPaint);
    _drawDiamond(canvas, const ui.Offset(76, 58), 4, dPaint);
    _drawDiamond(canvas, const ui.Offset(56, 76), 4, dPaint);
    // Scrubber Line
    canvas.drawLine(const ui.Offset(56, 48), const ui.Offset(56, 92), ui.Paint()..color = const ui.Color(0xFFFF1744)..strokeWidth = 2);
  }

  void _drawDiamond(ui.Canvas canvas, ui.Offset center, double radius, ui.Paint paint) {
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawWidgetThumbnail(ui.Canvas canvas) {
    // UI Layout Window
    final winRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(20, 24, 88, 80), const ui.Radius.circular(6));
    canvas.drawRRect(winRect, ui.Paint()..color = const ui.Color(0xFF282828));
    canvas.drawRRect(winRect, ui.Paint()..color = const ui.Color(0xFF00E676)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);
    // Header Bar
    final hRect = ui.RRect.fromRectAndCorners(const ui.Rect.fromLTWH(20, 24, 88, 16), topLeft: const ui.Radius.circular(6), topRight: const ui.Radius.circular(6));
    canvas.drawRRect(hRect, ui.Paint()..color = const ui.Color(0xFF00C853));
    // Header Dots
    // Punched out of the header bar in the same neutral as the card.
    canvas.drawCircle(const ui.Offset(28, 32), 2.5, ui.Paint()..color = const ui.Color(0xFF141414));
    canvas.drawCircle(const ui.Offset(36, 32), 2.5, ui.Paint()..color = const ui.Color(0xFF141414));
    // Nested UI Widgets (Button, Input, Card)
    canvas.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(28, 48, 72, 14), const ui.Radius.circular(3)), ui.Paint()..color = const ui.Color(0xFF3F3F3F));
    canvas.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(28, 68, 44, 24), const ui.Radius.circular(3)), ui.Paint()..color = const ui.Color(0xFF00E676));
    canvas.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(76, 68, 24, 24), const ui.Radius.circular(3)), ui.Paint()..color = const ui.Color(0xFF3F3F3F));
  }

  void _drawAnimationThumbnail(ui.Canvas canvas) {
    // Skeletal motion curve / Pose
    final bgRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(20, 24, 88, 80), const ui.Radius.circular(6));
    canvas.drawRRect(bgRect, ui.Paint()..color = const ui.Color(0xFF282828));
    canvas.drawRRect(bgRect, ui.Paint()..color = const ui.Color(0xFFE040FB)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);
    // Motion Curve Path
    final path = ui.Path()
      ..moveTo(28, 84)
      ..cubicTo(44, 84, 52, 40, 68, 40)
      ..cubicTo(84, 40, 92, 70, 100, 70);
    canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFFE040FB)..style = ui.PaintingStyle.stroke..strokeWidth = 2.5);
    // Keyframe Nodes
    canvas.drawCircle(const ui.Offset(28, 84), 4, ui.Paint()..color = const ui.Color(0xFFEA80FC));
    canvas.drawCircle(const ui.Offset(68, 40), 4, ui.Paint()..color = const ui.Color(0xFFEA80FC));
    canvas.drawCircle(const ui.Offset(100, 70), 4, ui.Paint()..color = const ui.Color(0xFFEA80FC));
  }

  void _drawAudioThumbnail(ui.Canvas canvas) {
    // Waveform / EQ bars
    final bgRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(20, 24, 88, 80), const ui.Radius.circular(6));
    canvas.drawRRect(bgRect, ui.Paint()..color = const ui.Color(0xFF282828));
    canvas.drawRRect(bgRect, ui.Paint()..color = const ui.Color(0xFF00E5FF)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);
    // EQ Spectrum Bars
    final barHeights = [16.0, 32.0, 48.0, 28.0, 56.0, 42.0, 20.0];
    final barPaint = ui.Paint()..color = const ui.Color(0xFF00E5FF);
    for (int i = 0; i < barHeights.length; i++) {
      final x = 32.0 + i * 10.0;
      final h = barHeights[i];
      final r = ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(x, 64 - h / 2, 6, h), const ui.Radius.circular(2));
      canvas.drawRRect(r, barPaint);
    }
  }

  void _drawParticleThumbnail(ui.Canvas canvas) {
    // Particle Burst / Sparks
    final center = const ui.Offset(64, 64);
    canvas.drawCircle(center, 12, ui.Paint()..color = const ui.Color(0xFFFF6D00));
    canvas.drawCircle(center, 18, ui.Paint()..color = const ui.Color(0x44FF6D00));
    // Radial spark points
    final sparkOffsets = [
      const ui.Offset(64, 32), const ui.Offset(88, 44), const ui.Offset(94, 68),
      const ui.Offset(82, 92), const ui.Offset(64, 98), const ui.Offset(42, 90),
      const ui.Offset(34, 64), const ui.Offset(40, 40),
    ];
    for (final s in sparkOffsets) {
      canvas.drawCircle(s, 3.5, ui.Paint()..color = const ui.Color(0xFFFFD180));
    }
  }

  void _drawPhysicsThumbnail(ui.Canvas canvas) {
    // Physics Rigid Body Capsule & Joint
    final capRect = ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(48, 32, 32, 64), const ui.Radius.circular(16));
    canvas.drawRRect(capRect, ui.Paint()..color = const ui.Color(0x33AEEA00));
    canvas.drawRRect(capRect, ui.Paint()..color = const ui.Color(0xFFAEEA00)..style = ui.PaintingStyle.stroke..strokeWidth = 2.0);
    // Center Axis & Joints
    canvas.drawLine(const ui.Offset(64, 32), const ui.Offset(64, 96), ui.Paint()..color = const ui.Color(0x88AEEA00)..strokeWidth = 1.5);
    canvas.drawCircle(const ui.Offset(64, 48), 5, ui.Paint()..color = const ui.Color(0xFFC6FF00));
    canvas.drawCircle(const ui.Offset(64, 80), 5, ui.Paint()..color = const ui.Color(0xFFC6FF00));
  }

  void _drawLandscapeThumbnail(ui.Canvas canvas) {
    // Mountain Peaks & Terrain Contours
    final mtnPath1 = ui.Path()
      ..moveTo(24, 96)
      ..lineTo(54, 42)
      ..lineTo(84, 96)
      ..close();
    canvas.drawPath(mtnPath1, ui.Paint()..color = const ui.Color(0xFF2E7D32));
    final mtnPath2 = ui.Path()
      ..moveTo(60, 96)
      ..lineTo(86, 52)
      ..lineTo(108, 96)
      ..close();
    canvas.drawPath(mtnPath2, ui.Paint()..color = const ui.Color(0xFF388E3C));
    // Contour lines
    canvas.drawLine(const ui.Offset(20, 100), const ui.Offset(108, 100), ui.Paint()..color = const ui.Color(0xFF81C784)..strokeWidth = 2);
    canvas.drawLine(const ui.Offset(28, 106), const ui.Offset(100, 106), ui.Paint()..color = const ui.Color(0xFF81C784)..strokeWidth = 1.5);
  }

  void _drawGlbMeshOnThumbnail(ui.Canvas canvas, GlbMeshData glb) =>
      _paintMeshThumbnail(canvas, MeshThumbnailGeometry.fromMesh(glb));

  /// Fills [geometry]'s triangles, back to front.
  void _paintMeshThumbnail(ui.Canvas canvas, MeshThumbnailGeometry geometry) {
    final points = geometry.points;
    final colors = geometry.colors;
    for (var t = 0; t < colors.length; t++) {
      final o = t * 6;
      final fillPaint = ui.Paint()
        ..color = ui.Color(colors[t])
        ..style = ui.PaintingStyle.fill;

      final path = ui.Path()
        ..moveTo(points[o], points[o + 1])
        ..lineTo(points[o + 2], points[o + 3])
        ..lineTo(points[o + 4], points[o + 5])
        ..close();

      canvas.drawPath(path, fillPaint);
    }
  }

  void _drawDefaultMeshThumbnail(ui.Canvas canvas) {
    final topPath = ui.Path()..moveTo(64, 24)..lineTo(102, 46)..lineTo(64, 68)..lineTo(26, 46)..close();
    final leftPath = ui.Path()..moveTo(26, 46)..lineTo(64, 68)..lineTo(64, 106)..lineTo(26, 84)..close();
    final rightPath = ui.Path()..moveTo(64, 68)..lineTo(102, 46)..lineTo(102, 84)..lineTo(64, 106)..close();

    canvas.drawPath(topPath, ui.Paint()..color = const ui.Color(0xFF80DEEA));
    canvas.drawPath(leftPath, ui.Paint()..color = const ui.Color(0xFF00ACC1));
    canvas.drawPath(rightPath, ui.Paint()..color = const ui.Color(0xFF00838F));
  }

  void _drawMaterialThumbnail(ui.Canvas canvas) {
    if (AssetRepository._cachedMaterialSphereMesh == null) {
      final sphereFile = File([LuminaWorkspace.root, 'filament', 'assets', 'models', 'material_sphere', 'material_sphere.obj']
          .join(Platform.pathSeparator));
      if (sphereFile.existsSync()) {
        try {
          final content = sphereFile.readAsStringSync();
          AssetRepository._cachedMaterialSphereMesh = ObjParserService.parseObj(content);
        } catch (_) {}
      }
    }

    if (AssetRepository._cachedMaterialSphereMesh != null && AssetRepository._cachedMaterialSphereMesh!.positions.isNotEmpty) {
      _drawGlbMeshOnThumbnail(canvas, AssetRepository._cachedMaterialSphereMesh!);
    } else {
      final center = const ui.Offset(64, 64);
      canvas.drawCircle(center, 36, ui.Paint()..color = const ui.Color(0xFF00E676));
      canvas.drawCircle(const ui.Offset(50, 50), 10, ui.Paint()..color = const ui.Color(0xB3FFFFFF));
    }
  }

  void _drawTextureThumbnail(ui.Canvas canvas) {
    final rect = const ui.Rect.fromLTWH(20, 20, 88, 88);
    canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF282828));

    final linePaint = ui.Paint()
      ..color = const ui.Color(0x5500E5FF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (double x = 20; x <= 108; x += 22) {
      canvas.drawLine(ui.Offset(x, 20), ui.Offset(x, 108), linePaint);
    }
    for (double y = 20; y <= 108; y += 22) {
      canvas.drawLine(ui.Offset(20, y), ui.Offset(108, y), linePaint);
    }

    final borderPaint = ui.Paint()
      ..color = const ui.Color(0xFF00E5FF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);
  }
}
