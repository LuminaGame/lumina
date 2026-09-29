import 'package:flutter_filament/flutter_filament.dart';
import '../math/units.dart';

/// Calculation scheme for cascaded shadow map (CSM) split planes.
enum CsmSplitMode {
  uniform,
  logarithmic,
  practical,
}

/// Immutable configuration for directional sun shadows and cascaded shadow maps.
class LuminaShadowSettings {
  final ShadowType shadowType;
  final VsmShadowOptions vsm;
  final SoftShadowOptions soft;
  final int mapSize;
  final int cascades;
  final CsmSplitMode splitMode;
  final double practicalLambda;
  final double shadowFar;
  final bool stable;
  final bool screenSpaceContactShadows;
  final int contactShadowsStepCount;
  final double constantBias;
  final double normalBias;

  const LuminaShadowSettings._({
    this.shadowType = ShadowType.pcf,
    this.vsm = const VsmShadowOptions(),
    this.soft = const SoftShadowOptions(),
    this.mapSize = 1024,
    this.cascades = 1,
    this.splitMode = CsmSplitMode.practical,
    this.practicalLambda = 0.5,
    this.shadowFar = 0.0,
    this.stable = false,
    this.screenSpaceContactShadows = false,
    this.contactShadowsStepCount = 8,
    this.constantBias = 0.1, // cm
    this.normalBias = 1.0,
  });

  const LuminaShadowSettings.defaults() : this._();

  factory LuminaShadowSettings({
    ShadowType shadowType = ShadowType.pcf,
    VsmShadowOptions vsm = const VsmShadowOptions(),
    SoftShadowOptions soft = const SoftShadowOptions(),
    int mapSize = 1024,
    int cascades = 1,
    CsmSplitMode splitMode = CsmSplitMode.practical,
    double practicalLambda = 0.5,
    double shadowFar = 0.0,
    bool stable = false,
    bool screenSpaceContactShadows = false,
    int contactShadowsStepCount = 8,
    double constantBias = 0.1,
    double normalBias = 1.0,
  }) {
    if (mapSize < 256 || mapSize > 4096 || (mapSize & (mapSize - 1)) != 0) {
      throw ArgumentError.value(
        mapSize,
        'mapSize',
        'Shadow mapSize must be a power-of-two between 256 and 4096',
      );
    }
    if (cascades < 1 || cascades > 4) {
      throw ArgumentError.value(
        cascades,
        'cascades',
        'Cascades must be between 1 and 4',
      );
    }
    if (practicalLambda < 0.0 || practicalLambda > 1.0) {
      throw ArgumentError.value(
        practicalLambda,
        'practicalLambda',
        'practicalLambda must be in range [0.0, 1.0]',
      );
    }

    return LuminaShadowSettings._(
      shadowType: shadowType,
      vsm: vsm,
      soft: soft,
      mapSize: mapSize,
      cascades: cascades,
      splitMode: splitMode,
      practicalLambda: practicalLambda,
      shadowFar: shadowFar,
      stable: stable,
      screenSpaceContactShadows: screenSpaceContactShadows,
      contactShadowsStepCount: contactShadowsStepCount,
      constantBias: constantBias,
      normalBias: normalBias,
    );
  }

  LuminaShadowSettings copyWith({
    ShadowType? shadowType,
    VsmShadowOptions? vsm,
    SoftShadowOptions? soft,
    int? mapSize,
    int? cascades,
    CsmSplitMode? splitMode,
    double? practicalLambda,
    double? shadowFar,
    bool? stable,
    bool? screenSpaceContactShadows,
    int? contactShadowsStepCount,
    double? constantBias,
    double? normalBias,
  }) {
    final newMapSize = mapSize ?? this.mapSize;
    final newCascades = cascades ?? this.cascades;
    final newPracticalLambda = practicalLambda ?? this.practicalLambda;

    if (newMapSize < 256 || newMapSize > 4096 || (newMapSize & (newMapSize - 1)) != 0) {
      throw ArgumentError.value(
        newMapSize,
        'mapSize',
        'Shadow mapSize must be a power-of-two between 256 and 4096',
      );
    }
    if (newCascades < 1 || newCascades > 4) {
      throw ArgumentError.value(
        newCascades,
        'cascades',
        'Cascades must be between 1 and 4',
      );
    }
    if (newPracticalLambda < 0.0 || newPracticalLambda > 1.0) {
      throw ArgumentError.value(
        newPracticalLambda,
        'practicalLambda',
        'practicalLambda must be in range [0.0, 1.0]',
      );
    }

    return LuminaShadowSettings._(
      shadowType: shadowType ?? this.shadowType,
      vsm: vsm ?? this.vsm,
      soft: soft ?? this.soft,
      mapSize: newMapSize,
      cascades: newCascades,
      splitMode: splitMode ?? this.splitMode,
      practicalLambda: newPracticalLambda,
      shadowFar: shadowFar ?? this.shadowFar,
      stable: stable ?? this.stable,
      screenSpaceContactShadows: screenSpaceContactShadows ?? this.screenSpaceContactShadows,
      contactShadowsStepCount: contactShadowsStepCount ?? this.contactShadowsStepCount,
      constantBias: constantBias ?? this.constantBias,
      normalBias: normalBias ?? this.normalBias,
    );
  }

  /// Builds a [ShadowOptions] struct suitable for configuring directional sun light components.
  ShadowOptions toShadowOptions({
    required double cameraNear,
    required double cameraFar,
  }) {
    final List<double> splits;
    if (cascades <= 1) {
      splits = const <double>[0.0, 0.0, 0.0];
    } else {
      List<double> rawSplits;
      switch (splitMode) {
        case CsmSplitMode.uniform:
          rawSplits = ShadowCascades.computeUniformSplits(cascades);
          break;
        case CsmSplitMode.logarithmic:
          rawSplits = ShadowCascades.computeLogSplits(
            cascades,
            nearPlane: cameraNear,
            farPlane: cameraFar,
          );
          break;
        case CsmSplitMode.practical:
          rawSplits = ShadowCascades.computePracticalSplits(
            cascades,
            nearPlane: cameraNear,
            farPlane: cameraFar,
            lambda: practicalLambda,
          );
          break;
      }
      splits = [
        rawSplits.isNotEmpty ? rawSplits[0] : 0.0,
        rawSplits.length > 1 ? rawSplits[1] : 0.0,
        rawSplits.length > 2 ? rawSplits[2] : 0.0,
      ];
    }

    return ShadowOptions(
      mapSize: mapSize,
      shadowCascades: cascades,
      cascadeSplitPositions: splits,
      constantBias: constantBias,
      normalBias: normalBias,
      shadowFar: shadowFar,
      // Filament's hints and contact-shadow reach, in cm.
      shadowNearHint: LuminaUnits.metres(1.0),
      shadowFarHint: LuminaUnits.metres(100.0),
      maxShadowDistance: LuminaUnits.metres(0.3),
      stable: stable,
      screenSpaceContactShadows: screenSpaceContactShadows,
      stepCount: contactShadowsStepCount,
      penumbraScale: soft.penumbraScale,
      penumbraRatioScale: soft.penumbraRatioScale,
      maxPenumbraRatio: soft.maxPenumbraRatio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaShadowSettings &&
          runtimeType == other.runtimeType &&
          shadowType == other.shadowType &&
          vsm == other.vsm &&
          soft == other.soft &&
          mapSize == other.mapSize &&
          cascades == other.cascades &&
          splitMode == other.splitMode &&
          practicalLambda == other.practicalLambda &&
          shadowFar == other.shadowFar &&
          stable == other.stable &&
          screenSpaceContactShadows == other.screenSpaceContactShadows &&
          contactShadowsStepCount == other.contactShadowsStepCount &&
          constantBias == other.constantBias &&
          normalBias == other.normalBias;

  @override
  int get hashCode => Object.hashAll([
        shadowType,
        vsm,
        soft,
        mapSize,
        cascades,
        splitMode,
        practicalLambda,
        shadowFar,
        stable,
        screenSpaceContactShadows,
        contactShadowsStepCount,
        constantBias,
        normalBias,
      ]);
}
