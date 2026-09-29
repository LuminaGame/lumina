/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Sampler minification filter matching backend::SamplerMinFilter.
enum SamplerMinFilter {
  nearest(0),
  linear(1),
  nearestMipmapNearest(2),
  linearMipmapNearest(3),
  nearestMipmapLinear(4),
  linearMipmapLinear(5);

  final int value;
  const SamplerMinFilter(this.value);
}

/// Sampler magnification filter matching backend::SamplerMagFilter.
enum SamplerMagFilter {
  nearest(0),
  linear(1);

  final int value;
  const SamplerMagFilter(this.value);
}

/// Sampler wrap mode matching backend::SamplerWrapMode.
enum SamplerWrapMode {
  clampToEdge(0),
  repeat(1),
  mirroredRepeat(2);

  final int value;
  const SamplerWrapMode(this.value);
}

/// Sampler compare mode matching backend::SamplerCompareMode.
enum SamplerCompareMode {
  none(0),
  compareToTexture(1);

  final int value;
  const SamplerCompareMode(this.value);
}

/// Sampler compare function matching backend::SamplerCompareFunc.
enum SamplerCompareFunc {
  le(0),
  ge(1),
  l(2),
  g(3),
  e(4),
  ne(5),
  a(6),
  n(7);

  final int value;
  const SamplerCompareFunc(this.value);
}

/// Defines how a texture is accessed, filtered, wrapped, and compared.
///
/// An immutable, pure-Dart value type that packs directly to Filament's 32-bit `SamplerParams`.
class TextureSampler {
  final SamplerMinFilter filterMin;
  final SamplerMagFilter filterMag;
  final SamplerWrapMode wrapS;
  final SamplerWrapMode wrapT;
  final SamplerWrapMode wrapR;
  final double anisotropy;
  final SamplerCompareMode compareMode;
  final SamplerCompareFunc compareFunc;

  /// The log2 quantized anisotropy value in the range [0, 7].
  int get anisotropyLog2 => _computeAnisotropyLog2(anisotropy);

  /// Creates a [TextureSampler] with custom filter and wrap parameters.
  const TextureSampler({
    this.filterMin = SamplerMinFilter.nearest,
    this.filterMag = SamplerMagFilter.nearest,
    this.wrapS = SamplerWrapMode.clampToEdge,
    this.wrapT = SamplerWrapMode.clampToEdge,
    this.wrapR = SamplerWrapMode.clampToEdge,
    this.anisotropy = 1.0,
    this.compareMode = SamplerCompareMode.none,
    this.compareFunc = SamplerCompareFunc.le,
  });

  /// Shortcut for high-quality trilinear minification and linear magnification with repeating wrap.
  const TextureSampler.trilinear({
    SamplerWrapMode wrap = SamplerWrapMode.repeat,
    this.anisotropy = 1.0,
  }) : filterMin = SamplerMinFilter.linearMipmapLinear,
       filterMag = SamplerMagFilter.linear,
       wrapS = wrap,
       wrapT = wrap,
       wrapR = wrap,
       compareMode = SamplerCompareMode.none,
       compareFunc = SamplerCompareFunc.le;

  /// Shortcut for shadow / depth texture comparison sampling.
  const TextureSampler.compare(
    this.compareFunc, {
    this.filterMin = SamplerMinFilter.linear,
    this.filterMag = SamplerMagFilter.linear,
    this.wrapS = SamplerWrapMode.clampToEdge,
    this.wrapT = SamplerWrapMode.clampToEdge,
    this.wrapR = SamplerWrapMode.clampToEdge,
    this.anisotropy = 1.0,
  }) : compareMode = SamplerCompareMode.compareToTexture;

  static int _computeAnisotropyLog2(double anisotropy) {
    final abs = anisotropy.abs();
    if (abs < 1.0 || abs.isNaN || abs.isInfinite) return 0;
    int log2 = 0;
    double val = 1.0;
    while (val * 2.0 <= abs && log2 < 7) {
      val *= 2.0;
      log2++;
    }
    return log2;
  }

  /// The packed 32-bit `SamplerParams` representation matching Filament's memory layout.
  int get packed {
    int result = 0;
    // Byte 0 (bits 0..7): mag(1), min(3), wrapS(2), wrapT(2)
    result |= (filterMag.value & 0x01);
    result |= (filterMin.value & 0x07) << 1;
    result |= (wrapS.value & 0x03) << 4;
    result |= (wrapT.value & 0x03) << 6;

    // Byte 1 (bits 8..15): wrapR(2), anisotropyLog2(3), compareMode(1), padding0(2)
    result |= (wrapR.value & 0x03) << 8;
    result |= (anisotropyLog2 & 0x07) << 10;
    result |= (compareMode.value & 0x01) << 13;

    // Byte 2 (bits 16..23): compareFunc(3), padding1(5)
    result |= (compareFunc.value & 0x07) << 16;

    // Byte 3 (bits 24..31): padding2(8) is 0
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextureSampler && other.packed == packed;
  }

  @override
  int get hashCode => packed.hashCode;

  @override
  String toString() {
    return 'TextureSampler(min: $filterMin, mag: $filterMag, wrap: [$wrapS, $wrapT, $wrapR], aniso: ${1 << anisotropyLog2}x, compare: $compareMode, func: $compareFunc, packed: 0x${packed.toRadixString(16)})';
  }
}
