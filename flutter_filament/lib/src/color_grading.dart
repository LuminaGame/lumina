import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Available tone-mapping operator types in Filament.
enum ToneMapperType {
  linear(0),
  aces(1),
  acesLegacy(2),
  filmic(3),
  pbrNeutral(4),
  gt7(5),
  agx(6),
  generic(7),
  displayRange(8);

  final int value;
  const ToneMapperType(this.value);
}

/// Creative adjustment look for AgX tone mapper.
enum AgxLook {
  none(0),
  punchy(1),
  golden(2);

  final int value;
  const AgxLook(this.value);
}

/// A tone mapping operator in Filament.
///
/// ToneMapper instances are plain heap objects used during [ColorGradingBuilder.build]
/// to bake the 3D LUT. They are NOT engine-owned and must be kept alive until [ColorGradingBuilder.build] completes.
class ToneMapper {
  ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  ffi.Pointer<ffi.Void> get nativePointer => _ptr;
  bool get isDisposed => _disposed;

  /// Creates a standard tone mapper of the specified [type].
  factory ToneMapper(ToneMapperType type) {
    final ptr = c.filament_tone_mapper_create(type.value);
    return ToneMapper._(ptr);
  }

  /// Creates a linear tone mapper.
  factory ToneMapper.linear() => ToneMapper(ToneMapperType.linear);

  /// Creates an ACES tone mapper.
  factory ToneMapper.aces() => ToneMapper(ToneMapperType.aces);

  /// Creates an ACES Legacy tone mapper.
  factory ToneMapper.acesLegacy() => ToneMapper(ToneMapperType.acesLegacy);

  /// Creates a filmic tone mapper.
  factory ToneMapper.filmic() => ToneMapper(ToneMapperType.filmic);

  /// Creates a PBR Neutral tone mapper.
  factory ToneMapper.pbrNeutral() => ToneMapper(ToneMapperType.pbrNeutral);

  /// Creates a Gran Turismo 7 tone mapper.
  factory ToneMapper.gt7() => ToneMapper(ToneMapperType.gt7);

  /// Creates an AgX tone mapper with the optional creative [look].
  factory ToneMapper.agx({AgxLook look = AgxLook.none}) {
    final ptr = c.filament_tone_mapper_create_agx(look.value);
    return ToneMapper._(ptr);
  }

  /// Creates a configurable generic tone mapper.
  factory ToneMapper.generic({
    double contrast = 1.55,
    double midGrayIn = 0.18,
    double midGrayOut = 0.215,
    double hdrMax = 10.0,
  }) {
    final ptr = c.filament_tone_mapper_create_generic(
      contrast,
      midGrayIn,
      midGrayOut,
      hdrMax,
    );
    return ToneMapper._(ptr);
  }

  ToneMapper._(this._ptr);

  /// Frees the ToneMapper instance.
  void destroy() {
    if (!_disposed) {
      c.filament_tone_mapper_destroy(_ptr);
      _ptr = ffi.nullptr;
      _disposed = true;
    }
  }
}

/// Quality level of the ColorGrading 3D LUT.
///
/// Distinct from View QualityLevel.
enum ColorGradingQuality {
  low(0),
  medium(1),
  high(2),
  ultra(3);

  final int value;
  const ColorGradingQuality(this.value);
}

/// Storage format for the 3D LUT backing texture.
enum LutFormat {
  integer(0),
  float(1);

  final int value;
  const LutFormat(this.value);
}

/// ColorGrading transforms the colors of the HDR buffer rendered by Filament.
///
/// Created via [ColorGradingBuilder] and destroyed via [destroy].
class ColorGrading {
  ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  ffi.Pointer<ffi.Void> get nativePointer => _ptr;
  bool get isDisposed => _disposed;

  ColorGrading._(this._ptr, this._engine);

  /// Destroys this ColorGrading resource in the Filament engine.
  void destroy() {
    if (!_disposed) {
      c.filament_engine_destroy_color_grading(_engine.nativePointer, _ptr);
      _ptr = ffi.nullptr;
      _disposed = true;
    }
  }
}

/// Fluent builder for creating a [ColorGrading] object.
class ColorGradingBuilder {
  ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  ffi.Pointer<ffi.Void> get nativePointer => _ptr;

  ColorGradingBuilder() : _ptr = c.filament_color_grading_builder_create();

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('ColorGradingBuilder is already disposed or built');
    }
  }

  /// Sets the quality level of the color grading LUT.
  ColorGradingBuilder quality(ColorGradingQuality quality) {
    _checkDisposed();
    c.filament_color_grading_builder_quality(_ptr, quality.value);
    return this;
  }

  /// Sets the format of the 3D LUT texture.
  ColorGradingBuilder format(LutFormat lutFormat) {
    _checkDisposed();
    c.filament_color_grading_builder_format(_ptr, lutFormat.value);
    return this;
  }

  /// Sets the dimension of the 3D LUT (valid range: 16..64).
  ColorGradingBuilder dimensions(int dim) {
    _checkDisposed();
    if (dim < 16 || dim > 64) {
      throw RangeError.range(dim, 16, 64, 'dim', 'LUT dimensions must be between 16 and 64');
    }
    c.filament_color_grading_builder_dimensions(_ptr, dim);
    return this;
  }

  /// Selects the tone mapping operator to apply.
  ColorGradingBuilder toneMapper(ToneMapper toneMapper) {
    _checkDisposed();
    if (toneMapper.isDisposed) {
      throw StateError('Cannot use a disposed ToneMapper in ColorGradingBuilder');
    }
    c.filament_color_grading_builder_tone_mapper(_ptr, toneMapper.nativePointer);
    return this;
  }

  /// Adjusts the exposure of the image in EV stops.
  ColorGradingBuilder exposure(double exposure) {
    _checkDisposed();
    c.filament_color_grading_builder_exposure(_ptr, exposure);
    return this;
  }

  /// Controls night adaptation amount (0.0 to 1.0).
  ColorGradingBuilder nightAdaptation(double adaptation) {
    _checkDisposed();
    c.filament_color_grading_builder_night_adaptation(_ptr, adaptation);
    return this;
  }

  /// Adjusts white balance with temperature [-1.0..+1.0] and tint [-1.0..+1.0].
  ColorGradingBuilder whiteBalance(double temperature, double tint) {
    _checkDisposed();
    c.filament_color_grading_builder_white_balance(_ptr, temperature, tint);
    return this;
  }

  /// Adjusts output color channels using source channel mixes.
  ColorGradingBuilder channelMixer({
    required Vector3 outRed,
    required Vector3 outGreen,
    required Vector3 outBlue,
  }) {
    _checkDisposed();
    final r = calloc<ffi.Float>(3);
    final g = calloc<ffi.Float>(3);
    final b = calloc<ffi.Float>(3);
    r[0] = outRed.x; r[1] = outRed.y; r[2] = outRed.z;
    g[0] = outGreen.x; g[1] = outGreen.y; g[2] = outGreen.z;
    b[0] = outBlue.x; b[1] = outBlue.y; b[2] = outBlue.z;

    c.filament_color_grading_builder_channel_mixer(_ptr, r, g, b);

    calloc.free(r);
    calloc.free(g);
    calloc.free(b);
    return this;
  }

  /// Adjusts colors across tonal zones: shadows, midtones, highlights.
  ColorGradingBuilder shadowsMidtonesHighlights({
    required Vector4 shadows,
    required Vector4 midtones,
    required Vector4 highlights,
    required Vector4 ranges,
  }) {
    _checkDisposed();
    final sh = calloc<ffi.Float>(4);
    final mid = calloc<ffi.Float>(4);
    final hi = calloc<ffi.Float>(4);
    final rg = calloc<ffi.Float>(4);

    sh[0] = shadows.x; sh[1] = shadows.y; sh[2] = shadows.z; sh[3] = shadows.w;
    mid[0] = midtones.x; mid[1] = midtones.y; mid[2] = midtones.z; mid[3] = midtones.w;
    hi[0] = highlights.x; hi[1] = highlights.y; hi[2] = highlights.z; hi[3] = highlights.w;
    rg[0] = ranges.x; rg[1] = ranges.y; rg[2] = ranges.z; rg[3] = ranges.w;

    c.filament_color_grading_builder_shadows_midtones_highlights(_ptr, sh, mid, hi, rg);

    calloc.free(sh);
    calloc.free(mid);
    calloc.free(hi);
    calloc.free(rg);
    return this;
  }

  /// Applies ASC CDL slope, offset, and power.
  ColorGradingBuilder slopeOffsetPower({
    required Vector3 slope,
    required Vector3 offset,
    required Vector3 power,
  }) {
    _checkDisposed();
    final sl = calloc<ffi.Float>(3);
    final of = calloc<ffi.Float>(3);
    final pw = calloc<ffi.Float>(3);

    sl[0] = slope.x; sl[1] = slope.y; sl[2] = slope.z;
    of[0] = offset.x; of[1] = offset.y; of[2] = offset.z;
    pw[0] = power.x; pw[1] = power.y; pw[2] = power.z;

    c.filament_color_grading_builder_slope_offset_power(_ptr, sl, of, pw);

    calloc.free(sl);
    calloc.free(of);
    calloc.free(pw);
    return this;
  }

  /// Adjusts image contrast [0.0..2.0].
  ColorGradingBuilder contrast(double contrast) {
    _checkDisposed();
    c.filament_color_grading_builder_contrast(_ptr, contrast);
    return this;
  }

  /// Adjusts color vibrance [0.0..2.0].
  ColorGradingBuilder vibrance(double vibrance) {
    _checkDisposed();
    c.filament_color_grading_builder_vibrance(_ptr, vibrance);
    return this;
  }

  /// Adjusts color saturation [0.0..2.0].
  ColorGradingBuilder saturation(double saturation) {
    _checkDisposed();
    c.filament_color_grading_builder_saturation(_ptr, saturation);
    return this;
  }

  /// Applies channel curves defined by shadowGamma, midPoint, and highlightScale.
  ColorGradingBuilder curves({
    required Vector3 shadowGamma,
    required Vector3 midPoint,
    required Vector3 highlightScale,
  }) {
    _checkDisposed();
    final sg = calloc<ffi.Float>(3);
    final mp = calloc<ffi.Float>(3);
    final hs = calloc<ffi.Float>(3);

    sg[0] = shadowGamma.x; sg[1] = shadowGamma.y; sg[2] = shadowGamma.z;
    mp[0] = midPoint.x; mp[1] = midPoint.y; mp[2] = midPoint.z;
    hs[0] = highlightScale.x; hs[1] = highlightScale.y; hs[2] = highlightScale.z;

    c.filament_color_grading_builder_curves(_ptr, sg, mp, hs);

    calloc.free(sg);
    calloc.free(mp);
    calloc.free(hs);
    return this;
  }

  /// Enables or disables EVILS luminance scaling.
  ColorGradingBuilder luminanceScaling(bool enabled) {
    _checkDisposed();
    c.filament_color_grading_builder_luminance_scaling(_ptr, enabled);
    return this;
  }

  /// Enables or disables gamut mapping to the destination color space.
  ColorGradingBuilder gamutMapping(bool enabled) {
    _checkDisposed();
    c.filament_color_grading_builder_gamut_mapping(_ptr, enabled);
    return this;
  }

  /// Builds the [ColorGrading] object for the given [engine].
  ColorGrading build(FilamentEngine engine) {
    _checkDisposed();
    final cgPtr = c.filament_color_grading_builder_build(_ptr, engine.nativePointer);
    _ptr = ffi.nullptr;
    _disposed = true;
    if (cgPtr.address == 0) {
      throw StateError('Failed to build ColorGrading');
    }
    return ColorGrading._(cgPtr, engine);
  }

  /// Destroys this builder without building.
  void destroy() {
    if (!_disposed) {
      c.filament_color_grading_builder_destroy(_ptr);
      _ptr = ffi.nullptr;
      _disposed = true;
    }
  }
}
