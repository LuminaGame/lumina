import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/services/rgba_png_encoder.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/texture_editor_models.dart';

class TextureEditorViewModel extends ChangeNotifier {
  final String assetPath;
  final LuminaAsset? initialAsset;

  LuminaAsset? _asset;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  int _width = 0;
  int _height = 0;
  Uint8List? _rawRgba;
  List<TextureMipLevel> _mipChain = [];
  int _selectedMip = 0;

  // Channel Isolator
  bool _showR = true;
  bool _showG = true;
  bool _showB = true;
  bool _showA = true;
  bool _viewAlphaAsGreyscale = false;

  // Zoom & Pan
  double _zoom = 1.0;
  ui.Offset _pan = ui.Offset.zero;

  // Pixel Inspector Hover
  double? _hoverU;
  double? _hoverV;
  int? _hoverX;
  int? _hoverY;
  (int, int, int, int)? _hoverRgba;
  String? _hoverHex;

  // Settings
  TextureSettings _settings = TextureSettings();
  String? _sourceFilePath;

  // Cached decoded ui.Images for rendering
  ui.Image? _activeMipUiImage;

  TextureEditorViewModel({
    required this.assetPath,
    this.initialAsset,
  });

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  LuminaAsset? get asset => _asset;

  int get width => _width;
  int get height => _height;
  int get selectedMip => _selectedMip;
  List<TextureMipLevel> get mipChain => List.unmodifiable(_mipChain);

  bool get showR => _showR;
  bool get showG => _showG;
  bool get showB => _showB;
  bool get showA => _showA;
  bool get viewAlphaAsGreyscale => _viewAlphaAsGreyscale;

  double get zoom => _zoom;
  ui.Offset get pan => _pan;

  double? get hoverU => _hoverU;
  double? get hoverV => _hoverV;
  int? get hoverX => _hoverX;
  int? get hoverY => _hoverY;
  (int, int, int, int)? get hoverRgba => _hoverRgba;
  String? get hoverHex => _hoverHex;

  TextureSettings get settings => _settings;
  String? get sourceFilePath => _sourceFilePath;
  ui.Image? get activeMipUiImage => _activeMipUiImage;

  String get fileBasename {
    final file = File(assetPath);
    return file.path.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  }

  int get uncompressedSizeBytes => _width * _height * 4;

  String get aspectRatioStr {
    if (_height == 0) return '1:1';
    final gcd = _gcd(_width, _height);
    if (gcd == 0) return '1:1';
    return '${_width ~/ gcd}:${_height ~/ gcd}';
  }

  String get channelMaskStr {
    if (_viewAlphaAsGreyscale) return 'A (Grey)';
    final sb = StringBuffer();
    if (_showR) sb.write('R');
    if (_showG) sb.write('G');
    if (_showB) sb.write('B');
    if (_showA) sb.write('A');
    return sb.isEmpty ? 'None' : sb.toString();
  }

  double get estimatedSizeBytes => computeEstimatedSizeBytes(
        _width,
        _height,
        mipCount: _mipChain.length,
        format: _settings.format,
        quality: _settings.quality,
      );

  String get estimatedSizeStr => formatByteSize(estimatedSizeBytes.round());
  String get uncompressedSizeStr => formatByteSize(uncompressedSizeBytes);

  TextureMipLevel get activeMip =>
      _mipChain.isNotEmpty && _selectedMip < _mipChain.length ? _mipChain[_selectedMip] : TextureMipLevel(level: 0, width: _width, height: _height, pixels: _rawRgba ?? Uint8List(0));

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      if (initialAsset != null) {
        _asset = initialAsset;
      } else {
        final file = File(assetPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            _asset = LuminaAsset.fromBytes(bytes);
          } catch (_) {}
        }
      }

      if (_asset?.rawPayload != null && _asset!.rawPayload!.isNotEmpty) {
        await _decodePayload(_asset!.rawPayload!);
      } else {
        _width = 4;
        _height = 4;
        _rawRgba = Uint8List(4 * 4 * 4);
        _generateMipChain();
      }

      // Restore texture settings from metadata
      final settingsJson = _asset?.metadata['texture_settings'];
      if (settingsJson != null && settingsJson.isNotEmpty) {
        try {
          final map = jsonDecode(settingsJson) as Map<String, dynamic>;
          _settings = TextureSettings.fromJson(map);
        } catch (_) {}
      }

      _sourceFilePath = _asset?.metadata['source_file'];

      _selectedMip = 0;
      await _refreshUiImage();

      _isLoading = false;
      _isDirty = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  Future<void> _decodePayload(Uint8List payload) async {
    final codec = await ui.instantiateImageCodec(payload);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    _width = image.width;
    _height = image.height;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData != null) {
      _rawRgba = byteData.buffer.asUint8List();
    } else {
      _rawRgba = Uint8List(_width * _height * 4);
    }

    _generateMipChain();
  }

  void _generateMipChain() {
    if (_rawRgba == null || _width == 0 || _height == 0) {
      _mipChain = [];
      return;
    }

    final level0 = TextureMipLevel(level: 0, width: _width, height: _height, pixels: _rawRgba!);
    if (_settings.mipGen == 'NoMipmaps') {
      _mipChain = [level0];
      return;
    }

    final List<TextureMipLevel> chain = [level0];
    int curW = _width;
    int curH = _height;
    Uint8List curPixels = _rawRgba!;
    int lvl = 1;

    while (curW > 1 || curH > 1) {
      final nextW = math.max(1, curW ~/ 2);
      final nextH = math.max(1, curH ~/ 2);
      final nextPixels = Uint8List(nextW * nextH * 4);

      for (int ny = 0; ny < nextH; ny++) {
        for (int nx = 0; nx < nextW; nx++) {
          final x0 = nx * 2;
          final x1 = math.min(curW - 1, x0 + 1);
          final y0 = ny * 2;
          final y1 = math.min(curH - 1, y0 + 1);

          final i00 = (y0 * curW + x0) * 4;
          final i10 = (y0 * curW + x1) * 4;
          final i01 = (y1 * curW + x0) * 4;
          final i11 = (y1 * curW + x1) * 4;

          final r = (curPixels[i00] + curPixels[i10] + curPixels[i01] + curPixels[i11]) ~/ 4;
          final g = (curPixels[i00 + 1] + curPixels[i10 + 1] + curPixels[i01 + 1] + curPixels[i11 + 1]) ~/ 4;
          final b = (curPixels[i00 + 2] + curPixels[i10 + 2] + curPixels[i01 + 2] + curPixels[i11 + 2]) ~/ 4;
          final a = (curPixels[i00 + 3] + curPixels[i10 + 3] + curPixels[i01 + 3] + curPixels[i11 + 3]) ~/ 4;

          final outIdx = (ny * nextW + nx) * 4;
          nextPixels[outIdx] = r;
          nextPixels[outIdx + 1] = g;
          nextPixels[outIdx + 2] = b;
          nextPixels[outIdx + 3] = a;
        }
      }

      chain.add(TextureMipLevel(level: lvl, width: nextW, height: nextH, pixels: nextPixels));
      curW = nextW;
      curH = nextH;
      curPixels = nextPixels;
      lvl++;
    }

    _mipChain = chain;
  }

  (int, int, int, int) pixelAt(int mip, int x, int y) {
    if (mip < 0 || mip >= _mipChain.length) return (0, 0, 0, 0);
    return _mipChain[mip].pixelAt(x, y);
  }

  Uint8List getFilteredPixels(int mipLevel) {
    if (mipLevel < 0 || mipLevel >= _mipChain.length) return Uint8List(0);
    final mip = _mipChain[mipLevel];
    final src = mip.pixels;
    final dst = Uint8List(src.length);

    final isSingleChannel = (_showR ? 1 : 0) + (_showG ? 1 : 0) + (_showB ? 1 : 0) + (_showA ? 1 : 0) == 1;

    for (int i = 0; i < src.length; i += 4) {
      if (_viewAlphaAsGreyscale) {
        final a = src[i + 3];
        dst[i] = a;
        dst[i + 1] = a;
        dst[i + 2] = a;
        dst[i + 3] = 255;
      } else if (isSingleChannel) {
        final val = _showR
            ? src[i]
            : _showG
                ? src[i + 1]
                : _showB
                    ? src[i + 2]
                    : src[i + 3];
        dst[i] = val;
        dst[i + 1] = val;
        dst[i + 2] = val;
        dst[i + 3] = 255;
      } else {
        dst[i] = _showR ? src[i] : 0;
        dst[i + 1] = _showG ? src[i + 1] : 0;
        dst[i + 2] = _showB ? src[i + 2] : 0;
        dst[i + 3] = _showA ? src[i + 3] : 255;
      }
    }
    return dst;
  }

  Future<void> _refreshUiImage() async {
    if (_mipChain.isEmpty) return;
    final mip = activeMip;
    final filtered = getFilteredPixels(_selectedMip);

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      filtered,
      mip.width,
      mip.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    _activeMipUiImage = await completer.future;
  }

  void selectMip(int level) {
    if (level >= 0 && level < _mipChain.length) {
      _selectedMip = level;
      _refreshUiImage().then((_) => notifyListeners());
    }
  }

  void setChannelMask({bool? r, bool? g, bool? b, bool? a, bool? alphaAsGreyscale}) {
    if (r != null) _showR = r;
    if (g != null) _showG = g;
    if (b != null) _showB = b;
    if (a != null) _showA = a;
    if (alphaAsGreyscale != null) _viewAlphaAsGreyscale = alphaAsGreyscale;
    _refreshUiImage().then((_) => notifyListeners());
  }

  void setZoom(double z) {
    _zoom = z.clamp(0.1, 32.0);
    notifyListeners();
  }

  void setPan(ui.Offset p) {
    _pan = p;
    notifyListeners();
  }

  void resetZoom() {
    _zoom = 1.0;
    _pan = ui.Offset.zero;
    notifyListeners();
  }

  void setHover(double u, double v, int x, int y) {
    _hoverU = u;
    _hoverV = v;
    _hoverX = x;
    _hoverY = y;
    final (r, g, b, a) = activeMip.pixelAt(x, y);
    _hoverRgba = (r, g, b, a);
    _hoverHex = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}${a.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
    notifyListeners();
  }

  void clearHover() {
    _hoverU = null;
    _hoverV = null;
    _hoverX = null;
    _hoverY = null;
    _hoverRgba = null;
    _hoverHex = null;
    notifyListeners();
  }

  // --- Settings Mutators ---
  void setSrgb(bool s) {
    _settings.srgb = s;
    _isDirty = true;
    notifyListeners();
  }

  void setTextureGroup(String group) {
    _settings.group = group;
    if (group == 'Normalmap' && _settings.srgb) {
      _settings.srgb = false;
    }
    _isDirty = true;
    notifyListeners();
  }

  void setCompressionFormat(String format) {
    _settings.format = format;
    _isDirty = true;
    notifyListeners();
  }

  void setCompressionQuality(String quality) {
    _settings.quality = quality;
    _isDirty = true;
    notifyListeners();
  }

  void setMipGenSettings(String mipGen) {
    _settings.mipGen = mipGen;
    _generateMipChain();
    _selectedMip = 0;
    _isDirty = true;
    _refreshUiImage().then((_) => notifyListeners());
  }

  void setFilter(String filter) {
    _settings.filter = filter;
    _isDirty = true;
    notifyListeners();
  }

  void setAddressModeX(String mode) {
    _settings.addressX = mode;
    _isDirty = true;
    notifyListeners();
  }

  void setAddressModeY(String mode) {
    _settings.addressY = mode;
    _isDirty = true;
    notifyListeners();
  }

  void setSourceFilePath(String path) {
    _sourceFilePath = path;
    _isDirty = true;
    notifyListeners();
  }

  double computeEstimatedSizeBytes(
    int w,
    int h, {
    required int mipCount,
    required String format,
    required String quality,
  }) {
    // Total pixels including mips is ~ 4/3 of base if full chain, else sum
    double totalPixels = 0.0;
    int curW = w;
    int curH = h;
    for (int i = 0; i < mipCount; i++) {
      totalPixels += (curW * curH);
      curW = math.max(1, curW ~/ 2);
      curH = math.max(1, curH ~/ 2);
    }

    double bpp = 32.0; // RGBA8
    if (format == 'ETC2') {
      bpp = 8.0;
    } else if (format == 'ASTC') {
      bpp = 3.56;
    } else if (format == 'KTX2 / Basis Universal') {
      bpp = 4.0;
    }

    if (quality == 'High Quality / Lossless') {
      bpp *= 1.5;
    } else if (quality == 'Fast Compression') {
      bpp *= 0.8;
    }

    return (totalPixels * bpp) / 8.0;
  }

  static String formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
    return '${(bytes / (1024.0 * 1024.0)).toStringAsFixed(2)} MB';
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});

    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['texture_settings'] = jsonEncode(_settings.toJson());
    if (_sourceFilePath != null) {
      updatedMetadata['source_file'] = _sourceFilePath!;
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.texture,
      rawPayload: _asset?.rawPayload,
      thumbnailPng: _asset?.thumbnailPng,
      metadata: updatedMetadata,
      references: _asset?.references ?? [],
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;
      EngineLoggerService().log('Saved Texture asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save Texture asset: $e\n$st', level: 'error');
      return false;
    }
  }

  Future<bool> reimport() async {
    final src = _sourceFilePath;
    if (src == null || !File(src).existsSync()) {
      EngineLoggerService().log('Cannot reimport: source file "$src" does not exist', level: 'warning');
      return false;
    }

    try {
      // The import's conversion (TGA and WebP become PNG), not
      // the raw source bytes.
      final newBytes = await ImportImageConversion.importBytes(File(src));
      await _decodePayload(newBytes);

      final thumbMipIdx = math.min(2, _mipChain.length - 1);
      final thumbMip = _mipChain[thumbMipIdx];
      final thumbPng = RgbaPngEncoder.encode(
        thumbMip.width,
        thumbMip.height,
        getFilteredPixels(thumbMipIdx),
      );

      final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});
      updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
      updatedMetadata['texture_settings'] = jsonEncode(_settings.toJson());
      updatedMetadata['source_file'] = src;

      final updatedAsset = LuminaAsset(
        assetId: _asset?.assetId ?? fileBasename,
        name: _asset?.name ?? fileBasename,
        type: AssetType.texture,
        rawPayload: newBytes,
        thumbnailPng: thumbPng,
        metadata: updatedMetadata,
        references: _asset?.references ?? [],
      );

      final file = File(assetPath);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;

      _selectedMip = 0;
      await _refreshUiImage();

      EngineLoggerService().log('Reimported Texture asset from $src', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to reimport Texture: $e\n$st', level: 'error');
      return false;
    }
  }
}
