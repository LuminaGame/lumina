import 'package:flutter_filament/ffi.dart' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import '../world/world.dart';
import 'post_process_settings.dart';
import 'shadow_settings.dart';

/// World-owned controller that diffs and applies [LuminaPostProcessSettings] and [LuminaShadowSettings] to a bound [FilamentView].
///
/// Diffs option families to minimize native FFI traffic and avoids rebuilding the expensive
/// 3D LUT [ColorGrading] object unless color grading properties actually changed.
class LuminaPostProcessController {
  final LuminaWorld world;
  final FilamentEngine engine;
  final FilamentView view;

  LuminaPostProcessSettings? _applied;
  LuminaShadowSettings? _appliedShadowSettings;
  ColorGrading? _currentColorGrading;

  // Retain strong references to native texture pointers if used in options
  ffi.Pointer<ffi.Void>? _dirtTextureRef;
  ffi.Pointer<ffi.Void>? _skyColorTextureRef;

  /// Retained native texture pointer for bloom dirt texture.
  ffi.Pointer<ffi.Void>? get dirtTextureRef => _dirtTextureRef;

  /// Retained native texture pointer for fog sky color texture.
  ffi.Pointer<ffi.Void>? get skyColorTextureRef => _skyColorTextureRef;

  LuminaPostProcessController({
    required this.world,
    required this.engine,
    required this.view,
  });

  /// The currently applied post-process settings, or standard defaults if not yet explicitly applied.
  LuminaPostProcessSettings get applied => _applied ?? LuminaPostProcessSettings.standard();

  /// The settings the world's [LuminaPostProcessBlender] blends from: what
  /// was last applied directly (game code, scalability, the editor), as
  /// opposed to [applied], which may be a blended state.
  LuminaPostProcessSettings get baseline => world.postProcessBlender.baseline;

  /// The currently applied shadow settings, or default shadow settings if not yet explicitly applied.
  LuminaShadowSettings get appliedShadows => _appliedShadowSettings ?? const LuminaShadowSettings.defaults();

  /// Applies directional shadow configuration to the view and world directional lights.
  void applyShadowSettings(
    LuminaShadowSettings shadowSettings, {
    double? cameraNear,
    double? cameraFar,
  }) {
    final prev = _appliedShadowSettings;
    if (prev == null || prev.shadowType != shadowSettings.shadowType) {
      view.shadowType = shadowSettings.shadowType;
    }
    if (prev == null || prev.vsm != shadowSettings.vsm) {
      view.vsmShadowOptions = shadowSettings.vsm;
    }
    if (prev == null || prev.soft != shadowSettings.soft) {
      view.softShadowOptions = shadowSettings.soft;
    }

    final near = cameraNear ?? world.activeCamera?.nearClipPlane ?? 10.0;
    final far = cameraFar ?? world.activeCamera?.farClipPlane ?? 10000.0;
    final shadowOpts = shadowSettings.toShadowOptions(
      cameraNear: near,
      cameraFar: far,
    );

    world.updateDirectionalLightShadows(shadowOpts);
    _appliedShadowSettings = shadowSettings;
  }

  /// Applies the given [settings] to the view, diffing each option family against the previous state.
  ///
  /// A direct call is a **baseline** change (the blender re-resolves from it
  /// next tick); the blender's own per-tick apply passes `asBaseline: false`.
  void apply(LuminaPostProcessSettings settings, {bool asBaseline = true}) {
    if (asBaseline) world.postProcessBlender.baseline = settings;
    final prev = _applied;

    if (prev == null || prev.postProcessingEnabled != settings.postProcessingEnabled) {
      view.postProcessingEnabled = settings.postProcessingEnabled;
    }

    if (prev == null || prev.antiAliasing != settings.antiAliasing) {
      view.antiAliasing = settings.antiAliasing.toNative();
    }

    if (prev == null || prev.dithering != settings.dithering) {
      view.dithering = settings.dithering;
    }

    if (prev == null || prev.bloom != settings.bloom) {
      view.bloomOptions = settings.bloom;
      _dirtTextureRef = settings.bloom.dirt;
    }

    if (prev == null || prev.fog != settings.fog) {
      view.fogOptions = settings.fog;
      _skyColorTextureRef = settings.fog.skyColor;
    }

    if (prev == null || prev.depthOfField != settings.depthOfField) {
      view.depthOfFieldOptions = settings.depthOfField;
    }

    if (prev == null || prev.vignette != settings.vignette) {
      view.vignetteOptions = settings.vignette;
    }

    if (prev == null || prev.ambientOcclusion != settings.ambientOcclusion) {
      view.ambientOcclusionOptions = settings.ambientOcclusion;
    }

    if (prev == null || prev.taa != settings.taa) {
      view.temporalAntiAliasingOptions = settings.taa;
    }

    if (prev == null || prev.msaa != settings.msaa) {
      view.multiSampleAntiAliasingOptions = settings.msaa;
    }

    if (prev == null || prev.screenSpaceReflections != settings.screenSpaceReflections) {
      view.screenSpaceReflectionsOptions = settings.screenSpaceReflections;
    }

    if (prev == null || prev.guardBand != settings.guardBand) {
      view.guardBandOptions = settings.guardBand;
    }

    if (prev == null || prev.dynamicResolution != settings.dynamicResolution) {
      view.dynamicResolutionOptions = settings.dynamicResolution;
    }

    if (prev == null || prev.renderQuality != settings.renderQuality) {
      view.renderQuality = settings.renderQuality;
    }

    if (prev == null || prev.colorGrade != settings.colorGrade) {
      _applyColorGrading(settings.colorGrade);
    }

    _applied = settings;
  }

  void _applyColorGrading(LuminaColorGradeSettings grade) {
    late final ToneMapper toneMapper;
    if (grade.toneMapper == ToneMapperType.agx) {
      toneMapper = ToneMapper.agx(look: grade.agxLook);
    } else if (grade.toneMapper == ToneMapperType.generic) {
      toneMapper = ToneMapper.generic(
        contrast: grade.genericContrast,
        midGrayIn: grade.genericMidGrayIn,
        midGrayOut: grade.genericMidGrayOut,
        hdrMax: grade.genericHdrMax,
      );
    } else {
      toneMapper = ToneMapper(grade.toneMapper);
    }

    final builder = ColorGradingBuilder()
      ..quality(grade.quality)
      ..format(grade.format)
      ..dimensions(grade.lutDimensions)
      ..toneMapper(toneMapper)
      ..exposure(grade.exposure)
      ..nightAdaptation(grade.nightAdaptation)
      ..whiteBalance(grade.whiteBalance.$1, grade.whiteBalance.$2)
      ..contrast(grade.contrast)
      ..vibrance(grade.vibrance)
      ..saturation(grade.saturation)
      ..luminanceScaling(grade.luminanceScaling)
      ..gamutMapping(grade.gamutMapping);

    if (grade.channelMixer != null) {
      final cm = grade.channelMixer!;
      builder.channelMixer(outRed: cm.$1, outGreen: cm.$2, outBlue: cm.$3);
    }

    if (grade.shadowsMidtonesHighlights != null) {
      final smh = grade.shadowsMidtonesHighlights!;
      builder.shadowsMidtonesHighlights(
        shadows: smh.$1,
        midtones: smh.$2,
        highlights: smh.$3,
        ranges: smh.$4,
      );
    }

    if (grade.slopeOffsetPower != null) {
      final sop = grade.slopeOffsetPower!;
      builder.slopeOffsetPower(slope: sop.$1, offset: sop.$2, power: sop.$3);
    }

    if (grade.curves != null) {
      final c = grade.curves!;
      builder.curves(
        shadowGamma: c.$1,
        midPoint: c.$2,
        highlightScale: c.$3,
      );
    }

    final newCg = builder.build(engine);
    toneMapper.destroy();

    final oldCg = _currentColorGrading;
    view.colorGrading = newCg;
    _currentColorGrading = newCg;
    oldCg?.destroy();
  }

  /// Reconstructs a [LuminaPostProcessSettings] object by querying the live [FilamentView] getters.
  LuminaPostProcessSettings readBack() {
    return LuminaPostProcessSettings(
      bloom: view.bloomOptions,
      fog: view.fogOptions,
      depthOfField: view.depthOfFieldOptions,
      vignette: view.vignetteOptions,
      ambientOcclusion: view.ambientOcclusionOptions,
      taa: view.temporalAntiAliasingOptions,
      msaa: view.multiSampleAntiAliasingOptions,
      screenSpaceReflections: view.screenSpaceReflectionsOptions,
      guardBand: view.guardBandOptions,
      dynamicResolution: view.dynamicResolutionOptions,
      renderQuality: view.renderQuality,
      dithering: view.dithering,
      antiAliasing: AntiAliasing.fromNative(view.antiAliasing),
      postProcessingEnabled: view.postProcessingEnabled,
      colorGrade: _applied?.colorGrade ?? const LuminaColorGradeSettings.defaults(),
    );
  }

  /// The latest dynamic resolution scaling factors (X, Y) computed by Filament.
  (double, double) get lastDynamicResolutionScale => view.lastDynamicResolutionScale;

  /// Clears temporal anti-aliasing and SSR frame history (e.g. upon camera teleportation).
  void notifyCameraCut() {
    view.clearFrameHistory(engine);
  }

  /// Releases resources held by this controller.
  void dispose() {
    if (_currentColorGrading != null) {
      view.colorGrading = null;
      _currentColorGrading!.destroy();
      _currentColorGrading = null;
    }
    _dirtTextureRef = null;
    _skyColorTextureRef = null;
  }
}
