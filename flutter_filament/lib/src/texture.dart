import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/buffer_descriptor.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/exceptions.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Texture internal format matching backend::TextureFormat.
enum TextureFormat {
  // 8-bits per element
  r8(0),
  r8Snorm(1),
  r8ui(2),
  r8i(3),
  stencil8(4),

  // 16-bits per element
  r16f(5),
  r16ui(6),
  r16i(7),
  rg8(8),
  rg8Snorm(9),
  rg8ui(10),
  rg8i(11),
  rgb565(12),
  rgb9E5(13),
  rgb5A1(14),
  rgba4(15),
  depth16(16),

  // 24-bits per element
  rgb8(17),
  srgb8(18),
  rgb8Snorm(19),
  rgb8ui(20),
  rgb8i(21),
  depth24(22),

  // 32-bits per element
  r32f(23),
  r32ui(24),
  r32i(25),
  rg16f(26),
  rg16ui(27),
  rg16i(28),
  r11fG11fB10f(29),
  rgba8(30),
  srgb8A8(31),
  rgba8Snorm(32),
  unused(33),
  rgb10A2(34),
  rgba8ui(35),
  rgba8i(36),
  depth32f(37),
  depth24Stencil8(38),
  depth32fStencil8(39),

  // 48-bits per element
  rgb16f(40),
  rgb16ui(41),
  rgb16i(42),

  // 64-bits per element
  rg32f(43),
  rg32ui(44),
  rg32i(45),
  rgba16f(46),
  rgba16ui(47),
  rgba16i(48),

  // 96-bits per element
  rgb32f(49),
  rgb32ui(50),
  rgb32i(51),

  // 128-bits per element
  rgba32f(52),
  rgba32ui(53),
  rgba32i(54),

  // compressed formats
  eacR11(55),
  eacR11Signed(56),
  eacRg11(57),
  eacRg11Signed(58),
  etc2Rgb8(59),
  etc2Srgb8(60),
  etc2Rgb8A1(61),
  etc2Srgb8A1(62),
  etc2EacRgba8(63),
  etc2EacSrgba8(64),

  dxt1Rgb(65),
  dxt1Rgba(66),
  dxt3Rgba(67),
  dxt5Rgba(68),
  dxt1Srgb(69),
  dxt1Srgba(70),
  dxt3Srgba(71),
  dxt5Srgba(72),

  rgbaAstc4x4(73),
  rgbaAstc5x4(74),
  rgbaAstc5x5(75),
  rgbaAstc6x5(76),
  rgbaAstc6x6(77),
  rgbaAstc8x5(78),
  rgbaAstc8x6(79),
  rgbaAstc8x8(80),
  rgbaAstc10x5(81),
  rgbaAstc10x6(82),
  rgbaAstc10x8(83),
  rgbaAstc10x10(84),
  rgbaAstc12x10(85),
  rgbaAstc12x12(86),
  srgb8Alpha8Astc4x4(87),
  srgb8Alpha8Astc5x4(88),
  srgb8Alpha8Astc5x5(89),
  srgb8Alpha8Astc6x5(90),
  srgb8Alpha8Astc6x6(91),
  srgb8Alpha8Astc8x5(92),
  srgb8Alpha8Astc8x6(93),
  srgb8Alpha8Astc8x8(94),
  srgb8Alpha8Astc10x5(95),
  srgb8Alpha8Astc10x6(96),
  srgb8Alpha8Astc10x8(97),
  srgb8Alpha8Astc10x10(98),
  srgb8Alpha8Astc12x10(99),
  srgb8Alpha8Astc12x12(100),

  redRgtc1(101),
  signedRedRgtc1(102),
  redGreenRgtc2(103),
  signedRedGreenRgtc2(104),

  rgbBptcSignedFloat(105),
  rgbBptcUnsignedFloat(106),
  rgbaBptcUnorm(107),
  srgbAlphaBptcUnorm(108);

  final int value;
  const TextureFormat(this.value);
}

/// Target type of texture sampler matching backend::SamplerType.
enum TextureSamplerType {
  sampler2d(0),
  sampler2dArray(1),
  samplerCubemap(2),
  samplerExternal(3),
  sampler3d(4),
  samplerCubemapArray(5);

  final int value;
  const TextureSamplerType(this.value);
}

/// Swizzle options for texture channels matching backend::TextureSwizzle.
enum TextureSwizzle {
  substituteZero(0),
  substituteOne(1),
  channel0(2),
  channel1(3),
  channel2(4),
  channel3(5);

  final int value;
  const TextureSwizzle(this.value);
}

/// Pixel format of image buffer matching backend::PixelDataFormat.
enum PixelFormat {
  r(0),
  rInteger(1),
  rg(2),
  rgInteger(3),
  rgb(4),
  rgbInteger(5),
  rgba(6),
  rgbaInteger(7),
  unused(8),
  depthComponent(9),
  depthStencil(10),
  alpha(11);

  final int value;
  const PixelFormat(this.value);
}

typedef PixelDataFormat = PixelFormat;

/// Pixel data type of image buffer matching backend::PixelDataType.
enum PixelType {
  ubyte(0),
  byteType(1),
  ushort(2),
  shortType(3),
  uint(4),
  intType(5),
  half(6),
  floatType(7),
  compressed(8),
  uint10f11f11fRev(9),
  ushort565(10),
  uint2101010Rev(11);

  final int value;
  const PixelType(this.value);

  /// Backward-compatible alias for [floatType].
  static const PixelType float = PixelType.floatType;
  static const PixelType byte = PixelType.byteType;
  static const PixelType short = PixelType.shortType;
  static const PixelType int_ = PixelType.intType;
}

typedef PixelDataType = PixelType;

/// Cubemap face target matching backend::TextureCubemapFace.
enum CubemapFace {
  positiveX(0),
  negativeX(1),
  positiveY(2),
  negativeY(3),
  positiveZ(4),
  negativeZ(5);

  final int value;
  const CubemapFace(this.value);
}

/// Encapsulates pixel buffer data and its layout for uploading to textures.
class PixelBuffer {
  final NativeBuffer data;
  final PixelFormat format;
  final PixelType type;
  final int strideInPixels;
  final int alignment;
  final bool autoFree;

  const PixelBuffer({
    required this.data,
    this.format = PixelFormat.rgba,
    this.type = PixelType.ubyte,
    this.strideInPixels = 0,
    this.alignment = 1,
    this.autoFree = false,
  });

  /// Convenience factory creating a [PixelBuffer] from [Uint8List].
  factory PixelBuffer.fromBytes(
    Uint8List bytes, {
    PixelFormat format = PixelFormat.rgba,
    PixelType type = PixelType.ubyte,
    int strideInPixels = 0,
    int alignment = 1,
  }) {
    return PixelBuffer(
      data: NativeBuffer.copy(bytes),
      format: format,
      type: type,
      strideInPixels: strideInPixels,
      alignment: alignment,
      autoFree: true,
    );
  }
}

/// Parameters for creating a texture.
class TextureDescriptor {
  final int width;
  final int height;
  final int depth;
  final int levels;
  final TextureSamplerType samplerType;
  final TextureFormat format;
  final int usage;
  final int samples;
  final List<TextureSwizzle>? swizzle;
  final int importHandle;

  const TextureDescriptor({
    this.width = 1,
    this.height = 1,
    this.depth = 1,
    this.levels = 1,
    this.samplerType = TextureSamplerType.sampler2d,
    this.format = TextureFormat.rgba8,
    this.usage = 0,
    this.samples = 1,
    this.swizzle,
    this.importHandle = 0,
  });
}

/// A 2D, 3D, cubemap, or array texture.
class FilamentTexture {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor.
  FilamentTexture.internal(this._ptr, this._engine);

  /// Creates a texture using a [TextureDescriptor].
  static FilamentTexture create({
    required FilamentEngine engine,
    required TextureDescriptor desc,
  }) {
    final nativeDesc = calloc<c.FilamentTextureDesc>();
    nativeDesc.ref.width = desc.width;
    nativeDesc.ref.height = desc.height;
    nativeDesc.ref.depth = desc.depth;
    nativeDesc.ref.levels = desc.levels;
    nativeDesc.ref.sampler_type = desc.samplerType.value;
    nativeDesc.ref.internal_format = desc.format.value;
    nativeDesc.ref.usage = desc.usage;
    nativeDesc.ref.samples = desc.samples;
    nativeDesc.ref.import_handle = desc.importHandle;

    if (desc.swizzle != null && desc.swizzle!.length >= 4) {
      nativeDesc.ref.has_swizzle = true;
      nativeDesc.ref.swizzle[0] = desc.swizzle![0].value;
      nativeDesc.ref.swizzle[1] = desc.swizzle![1].value;
      nativeDesc.ref.swizzle[2] = desc.swizzle![2].value;
      nativeDesc.ref.swizzle[3] = desc.swizzle![3].value;
    } else {
      nativeDesc.ref.has_swizzle = false;
    }

    final ptr = c.filament_texture_create(engine.nativePointer, nativeDesc);
    calloc.free(nativeDesc);

    if (ptr == ffi.nullptr) {
      throw FilamentException('Failed to create FilamentTexture');
    }
    return FilamentTexture.internal(ptr, engine);
  }

  /// Creates a 2D Texture.
  static FilamentTexture create2D({
    required FilamentEngine engine,
    required int width,
    required int height,
    TextureFormat format = TextureFormat.rgba8,
    int levels = 1,
    int usage = 0,
  }) {
    return create(
      engine: engine,
      desc: TextureDescriptor(
        width: width,
        height: height,
        depth: 1,
        levels: levels,
        samplerType: TextureSamplerType.sampler2d,
        format: format,
        usage: usage,
      ),
    );
  }

  /// Creates a Cubemap Texture.
  static FilamentTexture createCubemap({
    required FilamentEngine engine,
    required int size,
    TextureFormat format = TextureFormat.rgba8,
    int levels = 1,
    int usage = 0,
  }) {
    return create(
      engine: engine,
      desc: TextureDescriptor(
        width: size,
        height: size,
        depth: 1,
        levels: levels,
        samplerType: TextureSamplerType.samplerCubemap,
        format: format,
        usage: usage,
      ),
    );
  }

  /// Creates a 2D Array Texture.
  static FilamentTexture create2DArray({
    required FilamentEngine engine,
    required int width,
    required int height,
    required int layers,
    TextureFormat format = TextureFormat.rgba8,
    int levels = 1,
    int usage = 0,
  }) {
    return create(
      engine: engine,
      desc: TextureDescriptor(
        width: width,
        height: height,
        depth: layers,
        levels: levels,
        samplerType: TextureSamplerType.sampler2dArray,
        format: format,
        usage: usage,
      ),
    );
  }

  /// Creates a 3D Texture.
  static FilamentTexture create3D({
    required FilamentEngine engine,
    required int width,
    required int height,
    required int depth,
    TextureFormat format = TextureFormat.rgba8,
    int levels = 1,
    int usage = 0,
  }) {
    return create(
      engine: engine,
      desc: TextureDescriptor(
        width: width,
        height: height,
        depth: depth,
        levels: levels,
        samplerType: TextureSamplerType.sampler3d,
        format: format,
        usage: usage,
      ),
    );
  }

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Uploads pixel data to this texture.
  ///
  /// Either [buffer] ([PixelBuffer]) or [pixelData] ([Uint8List]) must be provided.
  void setImage({
    PixelBuffer? buffer,
    Uint8List? pixelData,
    int level = 0,
    int xoffset = 0,
    int yoffset = 0,
    int zoffset = 0,
    required int width,
    required int height,
    int depth = 1,
    PixelFormat pixelFormat = PixelFormat.rgba,
    PixelType pixelType = PixelType.ubyte,
    int strideInPixels = 0,
    int alignment = 1,
  }) {
    _checkDisposed();
    if (buffer == null && pixelData == null) {
      throw ArgumentError('Either buffer or pixelData must be provided to setImage');
    }

    final pBuf = buffer ??
        PixelBuffer.fromBytes(
          pixelData!,
          format: pixelFormat,
          type: pixelType,
          strideInPixels: strideInPixels,
          alignment: alignment,
        );

    final nativeBuf = pBuf.data;
    final (user, callback, _) = BufferOwnershipRegistry.instance.register(
      nativeBuf,
      onFree: pBuf.autoFree ? () => nativeBuf.free() : null,
    );

    c.filament_texture_set_image_ex(
      _engine.nativePointer,
      _ptr,
      level,
      xoffset,
      yoffset,
      zoffset,
      width,
      height,
      depth,
      pBuf.format.value,
      pBuf.type.value,
      pBuf.strideInPixels,
      pBuf.alignment,
      nativeBuf.pointer.cast(),
      nativeBuf.sizeInBytes,
      callback,
      user,
    );
  }

  /// Convenience method for uploading a specific face of a cubemap texture.
  void setCubemapFace({
    required CubemapFace face,
    required PixelBuffer buffer,
    required int width,
    required int height,
    int level = 0,
  }) {
    setImage(
      buffer: buffer,
      level: level,
      xoffset: 0,
      yoffset: 0,
      zoffset: face.value,
      width: width,
      height: height,
      depth: 1,
    );
  }

  /// Generates the mipmap chain for this texture using the GPU.
  void generateMipmaps(FilamentEngine engine) {
    _checkDisposed();
    if (levels <= 1) return;
    c.filament_texture_generate_mipmaps(engine.nativePointer, _ptr);
  }

  /// Gets the width in texels at mip [level].
  int width({int level = 0}) {
    _checkDisposed();
    return c.filament_texture_get_width(_ptr, level);
  }

  /// Gets the height in texels at mip [level].
  int height({int level = 0}) {
    _checkDisposed();
    return c.filament_texture_get_height(_ptr, level);
  }

  /// Gets the depth in texels at mip [level].
  int depth({int level = 0}) {
    _checkDisposed();
    return c.filament_texture_get_depth(_ptr, level);
  }

  /// Total number of mip levels.
  int get levels {
    _checkDisposed();
    return c.filament_texture_get_levels(_ptr);
  }

  /// Target sampler type of this texture.
  TextureSamplerType get target {
    _checkDisposed();
    final val = c.filament_texture_get_target(_ptr);
    return TextureSamplerType.values[val];
  }

  /// Internal format of this texture.
  TextureFormat get format {
    _checkDisposed();
    final val = c.filament_texture_get_format(_ptr);
    return TextureFormat.values[val];
  }

  /// Checks whether [format] is supported by [engine].
  static bool isFormatSupported(FilamentEngine engine, TextureFormat format) {
    return c.filament_texture_is_format_supported(engine.nativePointer, format.value);
  }

  /// Checks whether [format] can generate mipmaps on [engine].
  static bool isFormatMipmappable(FilamentEngine engine, TextureFormat format) {
    return c.filament_texture_is_format_mipmappable(engine.nativePointer, format.value);
  }

  /// Checks whether [format] is a compressed format.
  static bool isFormatCompressed(TextureFormat format) {
    return c.filament_texture_is_format_compressed(format.value);
  }

  /// Computes the required byte size for a pixel data buffer.
  static int computeDataSize({
    required PixelFormat format,
    required PixelType type,
    required int strideInPixels,
    required int height,
    int alignment = 1,
  }) {
    return c.filament_texture_compute_data_size(
      format.value,
      type.value,
      strideInPixels,
      height,
      alignment,
    );
  }

  /// Returns the maximum texture dimension in texels for [samplerType].
  static int maxSize(FilamentEngine engine, TextureSamplerType samplerType) {
    return c.filament_texture_get_max_size(engine.nativePointer, samplerType.value);
  }

  /// Returns the maximum number of array layers supported on [engine].
  static int maxArrayLayers(FilamentEngine engine) {
    return c.filament_texture_get_max_array_layers(engine.nativePointer);
  }

  /// Destroys this Texture.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_texture(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentTexture has been disposed');
    }
  }
}

/// Convenience alias for [FilamentTexture].
typedef Texture = FilamentTexture;
