import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueKey, debugPrint;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../main_editor/view_models/editor_view_model.dart' show EditorActorNode;
import '../view_models/environment_lighting_view_model.dart';

/// Drives the Environment Lighting mixer's live viewport through lumina.
///
/// The sub-editor viewport hands over a [LuminaWorld] bound to its Filament
/// engine/scene/view; this scene spawns the open level's mesh actors plus a
/// real `LuminaDirectionalLightComponent` (the sun) and `LuminaSkyComponent`
/// into it and applies fog/post-process through `world.postProcess`. Every
/// slider edit lands here via [apply] and is visible on the next frame. No
/// raw flutter_filament calls are made from the editor side.
class EnvironmentPreviewScene {
  LuminaWorld? _world;
  LuminaActor? _sunActor;
  LuminaDirectionalLightComponent? _sun;
  LuminaActor? _skyActor;
  LuminaSkyComponent? _sky;
  EnvironmentState? _applied;
  EnvironmentState? _skyBuiltFrom;
  String _projectDirPath = '';
  Timer? _ticker;
  int _meshActorCount = 0;

  static const double _tickSeconds = 1.0 / 30.0;
  static const Set<String> meshActorTypes = {'Mesh', 'StaticMesh', 'SkeletalMesh'};

  bool get isAttached => _world != null && !_world!.isCleanedUp;
  LuminaWorld? get world => _world;
  LuminaDirectionalLightComponent? get sun => _sun;
  LuminaSkyComponent? get sky => _sky;
  EnvironmentState? get applied => _applied;

  /// Number of level mesh actors mounted into the preview world.
  int get meshActorCount => _meshActorCount;

  /// Binds [world] (already carrying a native context) and mounts the level.
  void attach(
    LuminaWorld world, {
    required List<EditorActorNode> levelActors,
    required String projectDirPath,
    required EnvironmentState state,
  }) {
    detach();
    if (world.isCleanedUp || !world.hasNativeContext) return;
    _world = world;
    _projectDirPath = projectDirPath;
    _meshActorCount = 0;

    try {
      for (final actor in levelActors) {
        if (!meshActorTypes.contains(actor.type)) continue;
        final path = actor.meshAssetPath;
        if (path == null || !actor.isVisible) continue;
        final mesh = LuminaStaticMeshComponent(
          // Stored Z-up cm → runtime, as the viewport and PIE place it.
          location: LuminaAxes.location(actor.location),
          rotation: LuminaAxes.rotation(actor.rotation),
          scale: LuminaAxes.scale(actor.scale),
          meshAssetPath: path,
          castShadows: actor.castShadows,
          assetProvider: _readMeshBytes,
        );
        // Surface load failures in the log instead of as unhandled async errors.
        mesh.loaded.catchError((Object e) {
          debugPrint('[EnvironmentPreviewScene] mesh ${actor.name} failed to load: $e');
        });
        _register(LuminaActor(key: ValueKey('env_preview_${actor.id}'), root: mesh));
        _meshActorCount++;
      }
      _spawnSun(state);
      _spawnSky(state);
      world.tick(_tickSeconds);
      _applyPostProcess(state);
      _applied = state;
    } catch (e, st) {
      debugPrint('[EnvironmentPreviewScene] attach failed: $e\n$st');
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  /// Releases every reference; the viewport owns the world's cleanup.
  void detach() {
    _ticker?.cancel();
    _ticker = null;
    _world = null;
    _sunActor = null;
    _sun = null;
    _skyActor = null;
    _sky = null;
    _applied = null;
    _skyBuiltFrom = null;
    _meshActorCount = 0;
  }

  /// Pushes [state] into the live components. Cheap fields update in place;
  /// a sky whose mode/asset/intensity changed is rebuilt (the lumina sky
  /// component owns its skybox + IBL immutably).
  void apply(EnvironmentState state) {
    final w = _world;
    if (w == null || w.isCleanedUp || !w.hasNativeContext) return;
    try {
      final sun = _sun;
      if (sun != null) {
        final prev = _applied;
        if (prev == null || prev.effectiveSunColor != state.effectiveSunColor) {
          sun.color = state.effectiveSunColor;
        }
        if (prev == null || prev.sunIntensityLux != state.sunIntensityLux) {
          sun.intensity = state.sunIntensityLux;
        }
        if (prev == null || prev.castShadows != state.castShadows) {
          sun.castShadows = state.castShadows;
        }
        sun.rotation = LuminaAxes.rotation(state.sunEuler);
        sun.visible = state.sunElevationDeg > -90.0;
      }

      if (_needsSkyRebuild(state)) {
        _respawnSky(state);
      } else if (_sky != null) {
        final sky = _sky!;
        if (sky.isColorMode) {
          final c = SolarMathColor.hexToVector4(state.skyColorHex);
          if (sky.color != c) sky.color = c;
        }
        if (sky.iblIntensity != state.iblIntensity) sky.iblIntensity = state.iblIntensity;
        sky.rotationDegrees = state.skyRotationDeg;
      }

      _applyPostProcess(state);
      w.tick(_tickSeconds);
      _applied = state;
    } catch (e, st) {
      debugPrint('[EnvironmentPreviewScene] apply failed: $e\n$st');
    }
  }

  void _tick() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      w.tick(_tickSeconds);
    } catch (e) {
      debugPrint('[EnvironmentPreviewScene] tick failed: $e');
    }
  }

  void _applyPostProcess(EnvironmentState state) {
    final w = _world;
    if (w == null || w.filamentViewOrNull == null) return;
    w.postProcess.apply(state.toPostProcessSettings(base: w.postProcess.applied));
  }

  void _spawnSun(EnvironmentState state) {
    _sun = LuminaDirectionalLightComponent(
      rotation: LuminaAxes.rotation(state.sunEuler),
      color: state.effectiveSunColor,
      intensity: state.sunIntensityLux,
      castShadows: state.castShadows,
      isSun: true,
    );
    _sunActor = LuminaActor(key: const ValueKey('env_preview_sun'), root: _sun!);
    _register(_sunActor!);
  }

  bool _needsSkyRebuild(EnvironmentState state) {
    final b = _skyBuiltFrom;
    if (b == null || _sky == null) return true;
    return b.skyMode != state.skyMode ||
        b.skyEnvironmentAssetPath != state.skyEnvironmentAssetPath ||
        b.skyIntensity != state.skyIntensity ||
        b.sunDiscVisible != state.sunDiscVisible;
  }

  void _respawnSky(EnvironmentState state) {
    final w = _world!;
    if (_skyActor != null) {
      // Synchronous unregister frees the scene's skybox/IBL slots at once.
      w.persistentLevel.unregisterActor(_skyActor!);
      _skyActor = null;
      _sky = null;
    }
    _spawnSky(state);
    w.tick(_tickSeconds);
  }

  void _spawnSky(EnvironmentState state) {
    LuminaSkyComponent sky;
    final envPath = state.skyEnvironmentAssetPath;
    if (state.skyMode == EnvironmentSkyMode.environment && envPath != null && envPath.isNotEmpty) {
      final absolute = envPath.startsWith('/') ? envPath : '$_projectDirPath/$envPath';
      sky = LuminaSkyComponent.environment(
        environmentAssetPath: absolute,
        showSun: state.sunDiscVisible,
        skyIntensity: state.skyIntensity,
        iblIntensity: state.iblIntensity,
      );
      sky.loaded.catchError((Object e) {
        debugPrint('[EnvironmentPreviewScene] HDRI $absolute failed to load: $e');
      });
    } else {
      sky = LuminaSkyComponent.color(
        color: SolarMathColor.hexToVector4(state.skyColorHex),
        skyIntensity: state.skyIntensity,
        iblIntensity: state.iblIntensity,
      );
    }
    sky.rotationDegrees = state.skyRotationDeg;
    _sky = sky;
    _skyActor = LuminaActor(key: const ValueKey('env_preview_sky'), root: sky);
    _register(_skyActor!);
    _skyBuiltFrom = state;
  }

  /// Registers synchronously through the persistent level. `world.spawnActor`
  /// is avoided on purpose: its deferred drain registers the actor twice,
  /// which throws for a sky component and double-loads meshes.
  void _register(LuminaActor actor) {
    _world!.persistentLevel.registerActor(actor);
  }

  /// Mesh bytes for a level actor: raw GLB/glTF files are read as-is, `.lmas`
  /// containers yield their embedded payload.
  static Future<Uint8List> _readMeshBytes(String path) async {
    final bytes = await File(path).readAsBytes();
    if (!path.toLowerCase().endsWith('.lmas')) return bytes;
    final asset = LuminaAsset.fromBytes(bytes);
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) {
      throw StateError('$path carries no mesh payload');
    }
    return payload;
  }
}

/// Hex → RGBA helper shared with the sky component (opaque alpha).
class SolarMathColor {
  const SolarMathColor._();

  static Vector4 hexToVector4(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 8) h = h.substring(2);
    final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
    if (v == null) return Vector4(1.0, 1.0, 1.0, 1.0);
    return Vector4(((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0, 1.0);
  }
}
