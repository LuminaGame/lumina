import 'dart:convert';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/blueprint/blueprint_function_library.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_authoring_component.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_library.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/save/save_game.dart';
import 'package:lumina/src/save/save_game_subsystem.dart';

/// The Pose Authoring Blueprint nodes, as the VM calls them and as
/// generated code calls them (locations and rotations in authoring axes:
/// Z-up cm, rotators in degrees). Every node but Add Pose Authoring works on
/// the owner's first pose authoring component and does nothing without one.
abstract final class LuminaPoseAuthoringNodes {
  static LuminaPoseAuthoringComponent? _of(LuminaActor self) => self.getComponent<LuminaPoseAuthoringComponent>();

  static Quaternion _quat(LuminaRotator r) {
    final e = LuminaBlueprintFunctionLibrary.toControlRotation(r);
    return luminaPawnEulerToQuaternion(e.x, e.y, e.z);
  }

  static LuminaRotator _rotator(Quaternion q) =>
      LuminaBlueprintFunctionLibrary.fromControlRotation(luminaPawnQuaternionToEuler(q));

  /// Add Pose Authoring: a pose authoring component on [mesh] (the owner's
  /// first skeletal mesh when null), or the one already there.
  static LuminaPoseAuthoringComponent? addPoseAuthoring(LuminaActor self, Object? mesh) {
    final target = mesh is LuminaAnimatedMeshComponent ? mesh : self.getComponent<LuminaAnimatedMeshComponent>();
    if (target == null) return null;
    for (final c in self.components.whereType<LuminaPoseAuthoringComponent>()) {
      if (identical(c.mesh, target)) return c;
    }
    final component = LuminaPoseAuthoringComponent(mesh: target);
    self.addComponent(component);
    component.attachTo(target);
    return component;
  }

  /// Set Pose Handle Target: [location] (authoring axes); [rotation] when
  /// [useRotation]. False for a handle the rig lacks.
  static bool setHandleTarget(LuminaActor self, String handle, Vector3 location, bool useRotation, LuminaRotator rotation) =>
      _of(self)?.setHandleTarget(handle, LuminaBlueprintFunctionLibrary.toRuntime(location),
          worldRotation: useRotation ? _quat(rotation) : null) ??
      false;

  /// Get Pose Handle Transform: the handle bone's location and rotation
  /// (zero before the rig loads).
  static ({Vector3 location, LuminaRotator rotation}) getHandleTransform(LuminaActor self, String handle) {
    final m = _of(self)?.handleWorldTransform(handle);
    if (m == null) return (location: Vector3.zero(), rotation: const LuminaRotator.zero());
    final r = Quaternion.identity();
    m.decompose(Vector3.zero(), r, Vector3.zero());
    return (location: LuminaBlueprintFunctionLibrary.toAuthoring(m.getTranslation()), rotation: _rotator(r));
  }

  static void clearHandle(LuminaActor self, String handle) => _of(self)?.clearHandle(handle);

  static void resetPose(LuminaActor self) => _of(self)?.resetToReference();

  /// Find Nearest Pose Handle: the handle nearest [location] within
  /// [maxDistance] cm ('' and −1 when none).
  static ({String handle, double distance}) findNearestHandle(LuminaActor self, Vector3 location, double maxDistance) {
    final hit = _of(self)?.findNearestHandle(LuminaBlueprintFunctionLibrary.toRuntime(location), maxDistance: maxDistance);
    return hit == null ? (handle: '', distance: -1.0) : (handle: hit.name, distance: hit.distance);
  }

  /// Capture Pose: the pose shown now as JSON (an `AuthoredPose`).
  static String capturePose(LuminaActor self, String name) =>
      jsonEncode((_of(self)?.toAuthoredPose(name) ?? AuthoredPose(name, const {})).toJson());

  /// Apply Pose: a pose from Capture Pose, blended in over [blendTime] s.
  static bool applyPose(LuminaActor self, String pose, double blendTime) {
    final c = _of(self);
    if (c == null || pose.isEmpty) return false;
    try {
      c.applyAuthoredPose(AuthoredPose.fromJson(Map<String, dynamic>.from(jsonDecode(pose) as Map)), blendSeconds: blendTime);
      return true;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  static LuminaSaveGameSubsystem _saves(LuminaActor self) =>
      self.world?.getSubsystem<LuminaSaveGameSubsystem>() ?? LuminaSaveGameSubsystem();

  /// Save Pose: the pose shown now as [name] in save game slot [slot] (in
  /// Play-In-Editor also into the mesh's pose library, in the background).
  static bool savePose(LuminaActor self, String slot, String name) {
    final c = _of(self);
    if (c == null || slot.isEmpty || name.isEmpty) return false;
    final saves = _saves(self);
    final pose = c.toAuthoredPose(name);
    final existing = saves.loadGameFromSlotSync(slot, 0);
    final save = LuminaPoseLibrary.withPose(existing ?? LuminaSaveGame(saveSlotName: slot), name, pose);
    final ok = saves.saveGameToSlotSync(save, slot, 0);
    final project = LuminaPoseLibrary.editorProjectDir, mesh = c.mesh;
    if (ok && project != null && mesh != null) {
      LuminaPoseLibrary.saveToProject(project, mesh.meshAssetPath, name, pose).ignore();
    }
    return ok;
  }

  /// Load Pose: applies the pose [name] of save game slot [slot]; false
  /// when the slot has none.
  static bool loadPose(LuminaActor self, String slot, String name, double blendTime) {
    final c = _of(self);
    if (c == null || slot.isEmpty) return false;
    final save = _saves(self).loadGameFromSlotSync(slot, 0);
    final pose = save == null ? null : LuminaPoseLibrary.posesIn(save)[name];
    if (pose == null) return false;
    c.applyAuthoredPose(pose, blendSeconds: blendTime);
    return true;
  }
}
