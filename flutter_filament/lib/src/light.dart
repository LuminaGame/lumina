/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/exceptions.dart';
import 'package:flutter_filament/src/instance.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

export 'package:flutter_filament/src/instance.dart' show LightInstance;

/// Types of lights supported by Filament.
enum LightType {
  sun(0),
  directional(1),
  point(2),
  focusedSpot(3),
  spot(4);

  final int value;
  const LightType(this.value);
}

/// Fluent builder for constructing and configuring a Filament light component.
class LightBuilder {
  ffi.Pointer<ffi.Void>? _ptr;

  /// Creates a builder for the specified [type].
  LightBuilder(LightType type) {
    _ptr = c.filament_light_builder_create(type.value);
  }

  void _checkValid() {
    if (_ptr == null || _ptr == ffi.nullptr) {
      throw StateError('LightBuilder has already been built or destroyed');
    }
  }

  /// Sets the initial position of the light in world space.
  LightBuilder position(double x, double y, double z) {
    _checkValid();
    c.filament_light_builder_position(_ptr!, x, y, z);
    return this;
  }

  /// Sets the initial direction of the light in world space.
  LightBuilder direction(double x, double y, double z) {
    _checkValid();
    c.filament_light_builder_direction(_ptr!, x, y, z);
    return this;
  }

  /// Sets the initial linear sRGB color of the light.
  LightBuilder color(double r, double g, double b) {
    _checkValid();
    c.filament_light_builder_color(_ptr!, r, g, b);
    return this;
  }

  /// Sets the initial intensity in lux (directional/sun) or lumen (point/spot).
  LightBuilder intensity(double intensity) {
    _checkValid();
    c.filament_light_builder_intensity(_ptr!, intensity);
    return this;
  }

  /// Sets the luminous intensity in candela (cd).
  LightBuilder intensityCandela(double intensity) {
    _checkValid();
    c.filament_light_builder_intensity_candela(_ptr!, intensity);
    return this;
  }

  /// Sets the intensity in watts using bulb energy consumption and efficiency.
  LightBuilder intensityWatts(double watts, double efficiency) {
    _checkValid();
    c.filament_light_builder_intensity_watts(_ptr!, watts, efficiency);
    return this;
  }

  /// Sets the falloff distance (sphere of influence radius) for point/spot lights.
  LightBuilder falloff(double radius) {
    _checkValid();
    c.filament_light_builder_falloff(_ptr!, radius);
    return this;
  }

  /// Sets the inner and outer cone angles in radians for spot lights.
  LightBuilder spotLightCone(double inner, double outer) {
    _checkValid();
    c.filament_light_builder_spot_light_cone(_ptr!, inner, outer);
    return this;
  }

  /// Defines the angular radius of the sun in degrees (between 0.25° and 20.0°).
  LightBuilder sunAngularRadius(double radiusDeg) {
    _checkValid();
    c.filament_light_builder_sun_angular_radius(_ptr!, radiusDeg);
    return this;
  }

  /// Defines the sun's halo size (multiplier of sun angular radius, >= 1.0).
  LightBuilder sunHaloSize(double size) {
    _checkValid();
    c.filament_light_builder_sun_halo_size(_ptr!, size);
    return this;
  }

  /// Defines the sun's halo falloff exponent (>= 1.0).
  LightBuilder sunHaloFalloff(double falloff) {
    _checkValid();
    c.filament_light_builder_sun_halo_falloff(_ptr!, falloff);
    return this;
  }

  /// Sets the shadow options for this light.
  LightBuilder shadowOptions(ShadowOptions options) {
    _checkValid();
    final ptr = calloc<c.FilamentShadowOptions>();
    options._writeToNative(ptr);
    c.filament_light_builder_shadow_options(_ptr!, ptr);
    calloc.free(ptr);
    return this;
  }

  /// Enables or disables shadow casting.
  LightBuilder castShadows(bool enabled) {
    _checkValid();
    c.filament_light_builder_cast_shadows(_ptr!, enabled);
    return this;
  }

  /// Enables or disables illumination from this light (can cast shadows without emitting light).
  LightBuilder castLight(bool enabled) {
    _checkValid();
    c.filament_light_builder_cast_light(_ptr!, enabled);
    return this;
  }

  /// Enables or disables a specific light channel (0 to 7).
  LightBuilder lightChannel(int channel, {bool enable = true}) {
    _checkValid();
    c.filament_light_builder_light_channel(_ptr!, channel, enable);
    return this;
  }

  /// Adds the Light component to [entity] in [engine].
  ///
  /// Consumes and frees this builder. Throws [FilamentException] on failure.
  void build(FilamentEngine engine, int entity) {
    _checkValid();
    final ptr = _ptr!;
    _ptr = null;
    final res = c.filament_light_builder_build(ptr, engine.nativePointer, entity);
    if (res != 0) {
      throw FilamentException('Failed to build Light component on entity $entity (code: $res)');
    }
  }

  /// Cancels and destroys this builder without attaching to an entity.
  void destroy() {
    if (_ptr != null && _ptr != ffi.nullptr) {
      c.filament_light_builder_destroy(_ptr!);
      _ptr = null;
    }
  }
}

/// Alias for [LightBuilder].
typedef FilamentLightBuilder = LightBuilder;

/// Helper for managing and querying light components on entities.
class FilamentLightManager {
  final FilamentEngine engine;

  /// Creates a light manager wrapper.
  const FilamentLightManager(this.engine);

  /// Resolves an entity ID to its cached [LightInstance] handle.
  LightInstance getInstance(int entity) {
    final handle = c.filament_light_manager_get_instance(
      engine.nativePointer,
      entity,
    );
    return LightInstance(handle);
  }

  /// Whether [entity] has a light component.
  bool hasComponent(int entity) {
    return c.filament_light_has_component(
      engine.nativePointer,
      entity,
    );
  }

  /// Gets the [LightType] of [entity]'s light component, or null if no component exists.
  LightType? getType(int entity) {
    final typeVal = c.filament_light_get_type(engine.nativePointer, entity);
    if (typeVal < 0 || typeVal >= LightType.values.length) return null;
    return LightType.values[typeVal];
  }

  /// The total number of active light components managed by the engine.
  int get componentCount => c.filament_light_get_component_count(engine.nativePointer);

  /// The list of entity IDs that currently have a light component.
  List<int> get entities {
    final count = componentCount;
    if (count == 0) return const [];
    final ptr = calloc<ffi.Uint32>(count);
    c.filament_light_get_entities(engine.nativePointer, ptr, count);
    final result = [for (int i = 0; i < count; i++) ptr[i]];
    calloc.free(ptr);
    return result;
  }

  /// Whether [entity]'s light is directional (directional or sun).
  bool isDirectional(int entity) {
    final type = getType(entity);
    return type == LightType.directional || type == LightType.sun;
  }

  /// Whether [entity]'s light is an omnidirectional point light.
  bool isPoint(int entity) {
    return getType(entity) == LightType.point;
  }

  /// Whether [entity]'s light is a spot light (spot or focusedSpot).
  bool isSpot(int entity) {
    final type = getType(entity);
    return type == LightType.spot || type == LightType.focusedSpot;
  }

  /// Attaches a light component to [entity].
  void createLight({
    required int entity,
    required LightType type,
    double colorR = 1.0,
    double colorG = 1.0,
    double colorB = 1.0,
    double intensity = 100000.0,
    double dirX = 0.0,
    double dirY = -1.0,
    double dirZ = 0.0,
    bool castShadows = false,
  }) {
    LightBuilder(type)
      .color(colorR, colorG, colorB)
      .intensity(intensity)
      .direction(dirX, dirY, dirZ)
      .castShadows(castShadows)
      .build(engine, entity);
  }

  /// Destroys the light component on [entity].
  void destroy(int entity) {
    c.filament_light_destroy(engine.nativePointer, entity);
  }

  /// Sets the linear sRGB color of [entity]'s light component.
  void setColor(int entity, double r, double g, double b) {
    c.filament_light_set_color(engine.nativePointer, entity, r, g, b);
  }

  /// Gets the linear sRGB color of [entity]'s light component as [r, g, b].
  List<double> getColor(int entity) {
    final ptr = calloc<ffi.Float>(3);
    c.filament_light_get_color(engine.nativePointer, entity, ptr);
    final result = [ptr[0], ptr[1], ptr[2]];
    calloc.free(ptr);
    return result;
  }

  /// Sets the light intensity in lux (directional/sun) or lumen (point/spot).
  void setIntensity(int entity, double intensity) {
    c.filament_light_set_intensity(engine.nativePointer, entity, intensity);
  }

  /// Sets the luminous intensity in candela (cd).
  void setIntensityCandela(int entity, double intensity) {
    c.filament_light_set_intensity_candela(engine.nativePointer, entity, intensity);
  }

  /// Sets the light intensity in watts with luminous efficacy.
  void setIntensityWatts(int entity, double watts, double efficiency) {
    c.filament_light_set_intensity_watts(engine.nativePointer, entity, watts, efficiency);
  }

  /// Gets the luminous intensity in candela (cd).
  double getIntensity(int entity) {
    return c.filament_light_get_intensity(engine.nativePointer, entity);
  }

  /// Sets the direction in world space.
  void setDirection(int entity, double x, double y, double z) {
    c.filament_light_set_direction(engine.nativePointer, entity, x, y, z);
  }

  /// Gets the direction in world space as [x, y, z].
  List<double> getDirection(int entity) {
    final ptr = calloc<ffi.Float>(3);
    c.filament_light_get_direction(engine.nativePointer, entity, ptr);
    final result = [ptr[0], ptr[1], ptr[2]];
    calloc.free(ptr);
    return result;
  }

  /// Sets the position in world space.
  void setPosition(int entity, double x, double y, double z) {
    c.filament_light_set_position(engine.nativePointer, entity, x, y, z);
  }

  /// Gets the position in world space as [x, y, z].
  List<double> getPosition(int entity) {
    final ptr = calloc<ffi.Float>(3);
    c.filament_light_get_position(engine.nativePointer, entity, ptr);
    final result = [ptr[0], ptr[1], ptr[2]];
    calloc.free(ptr);
    return result;
  }

  /// Sets the falloff distance (sphere of influence radius) for point/spot lights.
  void setFalloff(int entity, double radius) {
    c.filament_light_set_falloff(engine.nativePointer, entity, radius);
  }

  /// Gets the falloff distance of this light.
  double getFalloff(int entity) {
    return c.filament_light_get_falloff(engine.nativePointer, entity);
  }

  /// Sets the inner and outer cone angles in radians for spot lights.
  void setSpotLightCone(int entity, double inner, double outer) {
    c.filament_light_set_spot_light_cone(engine.nativePointer, entity, inner, outer);
  }

  /// Gets the inner cone angle in radians.
  double getSpotLightInnerCone(int entity) {
    return c.filament_light_get_spot_light_inner_cone(engine.nativePointer, entity);
  }

  /// Gets the outer cone angle in radians.
  double getSpotLightOuterCone(int entity) {
    return c.filament_light_get_spot_light_outer_cone(engine.nativePointer, entity);
  }

  /// Enables or disables shadow casting.
  void setShadowCaster(int entity, bool enabled) {
    c.filament_light_set_shadow_caster(engine.nativePointer, entity, enabled);
  }

  /// Whether this light is configured to cast shadows.
  bool isShadowCaster(int entity) {
    return c.filament_light_is_shadow_caster(engine.nativePointer, entity);
  }

  /// Enables or disables a specific light channel (0 to 7).
  void setLightChannel(int entity, int channel, {bool enable = true}) {
    c.filament_light_set_light_channel(engine.nativePointer, entity, channel, enable);
  }

  /// Whether a specific light channel (0 to 7) is enabled.
  bool getLightChannel(int entity, int channel) {
    return c.filament_light_get_light_channel(engine.nativePointer, entity, channel);
  }

  /// Sets the shadow options for [entity].
  void setShadowOptions(int entity, ShadowOptions options) {
    final ptr = calloc<c.FilamentShadowOptions>();
    options._writeToNative(ptr);
    c.filament_light_set_shadow_options(engine.nativePointer, entity, ptr);
    calloc.free(ptr);
  }

  /// Gets the shadow options for [entity].
  ShadowOptions getShadowOptions(int entity) {
    final ptr = calloc<c.FilamentShadowOptions>();
    c.filament_light_get_shadow_options(engine.nativePointer, entity, ptr);
    final result = ShadowOptions._fromNative(ptr.ref);
    calloc.free(ptr);
    return result;
  }
}

/// Configuration options for shadow-map generation and cascaded shadow maps (CSM).
class ShadowOptions {
  int mapSize;
  int shadowCascades;
  List<double> cascadeSplitPositions;
  double constantBias;
  double normalBias;
  double shadowFar;
  double shadowNearHint;
  double shadowFarHint;
  bool stable;
  bool lispsm;
  double polygonOffsetConstant;
  double polygonOffsetSlope;
  bool screenSpaceContactShadows;
  int stepCount;
  double maxShadowDistance;
  bool elvsm;
  double blurWidth;
  double shadowBulbRadius;
  List<double> transform;
  double penumbraScale;
  double penumbraRatioScale;
  double maxPenumbraRatio;

  /// Trace hard shadows against the ray tracing acceleration structures of the
  /// scene instead of rendering cascaded shadow maps. Directional lights only;
  /// needs [FilamentEngine.supportsRayQuery] and
  /// [FilamentScene.rayTracingEnabled], and falls back to the shadow maps
  /// otherwise. Default false.
  bool rayTraced;

  ShadowOptions({
    this.mapSize = 1024,
    this.shadowCascades = 1,
    this.cascadeSplitPositions = const [0.125, 0.25, 0.50],
    this.constantBias = 0.001,
    this.normalBias = 1.0,
    this.shadowFar = 0.0,
    this.shadowNearHint = 1.0,
    this.shadowFarHint = 100.0,
    this.stable = false,
    this.lispsm = true,
    this.polygonOffsetConstant = 0.5,
    this.polygonOffsetSlope = 2.0,
    this.screenSpaceContactShadows = false,
    this.stepCount = 8,
    this.maxShadowDistance = 0.3,
    this.elvsm = false,
    this.blurWidth = 0.0,
    this.shadowBulbRadius = -1.0,
    this.transform = const [0.0, 0.0, 0.0, 1.0],
    this.penumbraScale = 1.0,
    this.penumbraRatioScale = 1.0,
    this.maxPenumbraRatio = 0.0,
    this.rayTraced = false,
  });

  void _writeToNative(ffi.Pointer<c.FilamentShadowOptions> ptr) {
    final ref = ptr.ref;
    ref.map_size = mapSize;
    ref.shadow_cascades = shadowCascades;
    for (int i = 0; i < 3; i++) {
      ref.cascade_split_positions[i] = i < cascadeSplitPositions.length ? cascadeSplitPositions[i] : 0.0;
    }
    ref.constant_bias = constantBias;
    ref.normal_bias = normalBias;
    ref.shadow_far = shadowFar;
    ref.shadow_near_hint = shadowNearHint;
    ref.shadow_far_hint = shadowFarHint;
    ref.stable = stable;
    ref.lispsm = lispsm;
    ref.polygon_offset_constant = polygonOffsetConstant;
    ref.polygon_offset_slope = polygonOffsetSlope;
    ref.screen_space_contact_shadows = screenSpaceContactShadows;
    ref.step_count = stepCount;
    ref.max_shadow_distance = maxShadowDistance;
    ref.elvsm = elvsm;
    ref.blur_width = blurWidth;
    ref.shadow_bulb_radius = shadowBulbRadius;
    for (int i = 0; i < 4; i++) {
      ref.transform[i] = i < transform.length ? transform[i] : (i == 3 ? 1.0 : 0.0);
    }
    ref.penumbra_scale = penumbraScale;
    ref.penumbra_ratio_scale = penumbraRatioScale;
    ref.max_penumbra_ratio = maxPenumbraRatio;
    ref.ray_traced = rayTraced;
  }

  static ShadowOptions _fromNative(c.FilamentShadowOptions ref) {
    return ShadowOptions(
      mapSize: ref.map_size,
      shadowCascades: ref.shadow_cascades,
      cascadeSplitPositions: [
        ref.cascade_split_positions[0],
        ref.cascade_split_positions[1],
        ref.cascade_split_positions[2],
      ],
      constantBias: ref.constant_bias,
      normalBias: ref.normal_bias,
      shadowFar: ref.shadow_far,
      shadowNearHint: ref.shadow_near_hint,
      shadowFarHint: ref.shadow_far_hint,
      stable: ref.stable,
      lispsm: ref.lispsm,
      polygonOffsetConstant: ref.polygon_offset_constant,
      polygonOffsetSlope: ref.polygon_offset_slope,
      screenSpaceContactShadows: ref.screen_space_contact_shadows,
      stepCount: ref.step_count,
      maxShadowDistance: ref.max_shadow_distance,
      elvsm: ref.elvsm,
      blurWidth: ref.blur_width,
      shadowBulbRadius: ref.shadow_bulb_radius,
      transform: [
        ref.transform[0],
        ref.transform[1],
        ref.transform[2],
        ref.transform[3],
      ],
      penumbraScale: ref.penumbra_scale,
      penumbraRatioScale: ref.penumbra_ratio_scale,
      maxPenumbraRatio: ref.max_penumbra_ratio,
      rayTraced: ref.ray_traced,
    );
  }
}

/// Utility methods for computing cascaded shadow map (CSM) split schemes.
abstract final class ShadowCascades {
  /// Computes split positions for [cascades] using a uniform split scheme.
  static List<double> computeUniformSplits(int cascades) {
    if (cascades <= 1) return [];
    final count = cascades - 1;
    final ptr = calloc<ffi.Float>(count);
    c.filament_shadow_cascades_compute_uniform_splits(ptr, cascades);
    final result = [for (int i = 0; i < count; i++) ptr[i]];
    calloc.free(ptr);
    return result;
  }

  /// Computes split positions for [cascades] using a logarithmic split scheme.
  static List<double> computeLogSplits(
    int cascades, {
    required double nearPlane,
    required double farPlane,
  }) {
    if (cascades <= 1) return [];
    final count = cascades - 1;
    final ptr = calloc<ffi.Float>(count);
    c.filament_shadow_cascades_compute_log_splits(ptr, cascades, nearPlane, farPlane);
    final result = [for (int i = 0; i < count; i++) ptr[i]];
    calloc.free(ptr);
    return result;
  }

  /// Computes split positions for [cascades] using a practical split scheme interpolating
  /// between uniform and logarithmic distributions with [lambda] in [0, 1].
  static List<double> computePracticalSplits(
    int cascades, {
    required double nearPlane,
    required double farPlane,
    double lambda = 0.5,
  }) {
    if (cascades <= 1) return [];
    final count = cascades - 1;
    final ptr = calloc<ffi.Float>(count);
    c.filament_shadow_cascades_compute_practical_splits(ptr, cascades, nearPlane, farPlane, lambda);
    final result = [for (int i = 0; i < count; i++) ptr[i]];
    calloc.free(ptr);
    return result;
  }
}

/// Standard luminous efficacy constants matching Filament's `EFFICIENCY_*` values.
abstract final class LightEfficiency {
  /// Typical efficiency of an incandescent light bulb (2.2%).
  static const double incandescent = 0.0220;

  /// Typical efficiency of a halogen light bulb (7.0%).
  static const double halogen = 0.0707;

  /// Typical efficiency of a fluorescent light bulb (8.7%).
  static const double fluorescent = 0.0878;

  /// Typical efficiency of an LED light bulb (11.7%).
  static const double led = 0.1171;
}
