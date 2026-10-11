import 'dart:convert';

import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/umg/viewport/viewport_scene.dart';
import 'package:lumina/src/world/subsystem/widget_subsystem.dart';

/// What the Viewport element's Blueprint nodes do, written once: the VM
/// calls these through the function library and generated code calls them
/// directly, so both edit the description identically.
///
/// [target] is a Viewport element's state map (`Get <Viewport>`); every
/// call edits the [LuminaViewportScene] stored in it and tells the widget
/// layer the element changed. Anything that is not an element map is
/// ignored (calls that return an id return ''). Transforms, vectors and
/// colours are authoring values (Z up, centimetres, `[r, g, b, a]`).
abstract final class LuminaViewportNodes {
  /// The element type name a Viewport element has.
  static const String elementType = 'viewport';

  /// The engine enums of the Viewport nodes and their values.
  static const String lightTypeEnum = 'EViewportLightType';
  static const String environmentEnum = 'EViewportEnvironment';
  static const String cameraPresetEnum = 'EViewportCameraPreset';
  static const String gizmoModeEnum = 'EViewportGizmoMode';
  static const String gizmoSpaceEnum = 'EViewportGizmoSpace';
  static const String markerKindEnum = 'EViewportMarkerKind';

  /// The values of enum [name], or null when it is not a Viewport enum.
  static List<String>? enumValues(String? name) => switch (name) {
        lightTypeEnum => LuminaViewportLightType.values,
        environmentEnum => LuminaViewportEnvironmentMode.values,
        cameraPresetEnum => LuminaViewportCameraPreset.values,
        gizmoModeEnum => const ['translate', 'rotate', 'scale'],
        gizmoSpaceEnum => const ['world', 'local'],
        markerKindEnum => const ['point', 'line', 'arrow'],
        _ => null,
      };

  /// Node ids of nodes that only an editor-scope graph runs (a game's
  /// Viewport refuses the file they name).
  static const Set<String> editorOnlyNodes = {'viewport_play_animation_file'};

  /// The scene of [target], or null when it is not an element state map.
  static LuminaViewportScene? sceneOf(Object? target) => target is Map<String, Object?> ? LuminaViewportScene.of(target) : null;

  static T _edit<T>(LuminaActor self, Object? target, T fallback, T Function(LuminaViewportScene scene) change) {
    final scene = sceneOf(target);
    if (scene == null) return fallback;
    final result = change(scene);
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
    return result;
  }

  static List<double> _vec(Object? v) {
    final p = LuminaViewportScene.plain(v);
    if (p is List) return [for (var i = 0; i < 3; i++) i < p.length && p[i] is num ? (p[i] as num).toDouble() : 0.0];
    return const [0.0, 0.0, 0.0];
  }

  static List<double> _color(Object? v) {
    final p = LuminaViewportScene.plain(v);
    if (p is List && p.length >= 3) {
      return [for (var i = 0; i < 4; i++) i < p.length && p[i] is num ? (p[i] as num).toDouble() : 1.0];
    }
    return const [1.0, 1.0, 1.0, 1.0];
  }

  // --- Scene -----------------------------------------------------------------

  /// Viewport Add Static Mesh → the node id.
  static String addStaticMesh(LuminaActor self, Object? target, String mesh, Object? transform) =>
      _edit(self, target, '', (s) => s.addNode(LuminaViewportNodeKind.staticMesh, asset: mesh, transform: transform));

  /// Viewport Add Skeletal Mesh → the node id.
  static String addSkeletalMesh(LuminaActor self, Object? target, String skeletalMesh, Object? transform) =>
      _edit(self, target, '', (s) => s.addNode(LuminaViewportNodeKind.skeletalMesh, asset: skeletalMesh, transform: transform));

  static void removeNode(LuminaActor self, Object? target, String nodeId) => _edit(self, target, null, (s) => s.removeNode(nodeId));

  static void clear(LuminaActor self, Object? target) => _edit(self, target, null, (s) => s.clear());

  static void setNodeTransform(LuminaActor self, Object? target, String nodeId, Object? transform) =>
      _edit(self, target, null, (s) => s.setNodeTransform(nodeId, transform));

  static void setNodeVisible(LuminaActor self, Object? target, String nodeId, bool visible) =>
      _edit(self, target, null, (s) => s.setNodeVisible(nodeId, visible));

  /// Viewport Set Node Mesh: swaps the mesh a node shows (a part swap).
  static void setNodeMesh(LuminaActor self, Object? target, String nodeId, String mesh) =>
      _edit(self, target, null, (s) => s.setNodeAsset(nodeId, mesh));

  static void attachToSocket(LuminaActor self, Object? target, String nodeId, String parent, String socket) =>
      _edit(self, target, null, (s) => s.attachToSocket(nodeId, parent, socket));

  /// Viewport Set Material Parameter: a colour, a scalar or a texture asset.
  static void setMaterialParameter(LuminaActor self, Object? target, String nodeId, String slot, String parameter, Object? value) =>
      _edit(self, target, null, (s) => s.setMaterialParameter(nodeId, slot, parameter, value));

  static void setMorphTargetWeight(LuminaActor self, Object? target, String nodeId, String morph, double weight) =>
      _edit(self, target, null, (s) => s.setMorphTargetWeight(nodeId, morph, weight));

  // --- Animation -------------------------------------------------------------

  /// Viewport Play Animation: an animation asset (`.lmas`) or a clip name of
  /// the node's mesh.
  static void playAnimation(LuminaActor self, Object? target, String nodeId, String animation, bool loop, double playRate) =>
      _edit(self, target, null, (s) => s.playAnimation(nodeId, animation, loop: loop, rate: playRate));

  static void stopAnimation(LuminaActor self, Object? target, String nodeId) => _edit(self, target, null, (s) => s.stopAnimation(nodeId));

  static void setAnimationTime(LuminaActor self, Object? target, String nodeId, double seconds) =>
      _edit(self, target, null, (s) => s.setAnimationTime(nodeId, seconds));

  /// Viewport Play Animation File (editor scope only).
  static void playAnimationFile(LuminaActor self, Object? target, String nodeId, String path) =>
      _edit(self, target, null, (s) => s.playAnimationFile(nodeId, path));

  // --- Lights and environment ------------------------------------------------

  static String addLight(LuminaActor self, Object? target, String type, Object? color, double intensity, Object? transform) =>
      _edit(self, target, '', (s) => s.addLight(type, _color(color), intensity, transform));

  static void setEnvironment(LuminaActor self, Object? target, String mode, String ibl, double intensity) =>
      _edit(self, target, null, (s) => s.setEnvironment(mode, ibl: ibl, intensity: intensity));

  static void setGridVisible(LuminaActor self, Object? target, bool visible) => _edit(self, target, null, (s) => s.gridVisible = visible);

  // --- Camera ----------------------------------------------------------------

  static void setCameraPreset(LuminaActor self, Object? target, String preset, bool fit) =>
      _edit(self, target, null, (s) => s.setCameraPreset(preset, fit: fit));

  static void frameNode(LuminaActor self, Object? target, String nodeId) => _edit(self, target, null, (s) => s.frameNode(nodeId));

  static void setOrbit(LuminaActor self, Object? target, double yaw, double pitch, double distance) =>
      _edit(self, target, null, (s) => s.setOrbit(yaw, pitch, distance));

  /// Viewport Get Camera: the orbit the Viewport shows (the player's last
  /// orbit, written back on release).
  static ({double yaw, double pitch, double distance}) getCamera(Object? target) {
    final s = sceneOf(target);
    if (s == null) return (yaw: 0.0, pitch: 0.0, distance: 0.0);
    return (yaw: s.yaw, pitch: s.pitch, distance: s.distance);
  }

  static void setInteraction(LuminaActor self, Object? target, bool orbit, bool pan, bool zoom, bool pick, double autoRotate) =>
      _edit(self, target, null, (s) => s.setInteraction(orbit: orbit, pan: pan, zoom: zoom, pick: pick, autoRotate: autoRotate));

  // --- Overlays --------------------------------------------------------------

  static void showSkeleton(LuminaActor self, Object? target, String nodeId, Object? color, bool joints) =>
      _edit(self, target, null, (s) => s.showSkeleton(nodeId, _color(color), joints: joints));

  /// Viewport Show Ghost Pose: [poseJson] (`{joint: [x, y, z, qx, qy, qz,
  /// qw]}`) when set, else [animation] at [time].
  static void showGhostPose(
      LuminaActor self, Object? target, String nodeId, String poseJson, String animation, double time, Object? color, String label) {
    Map<String, Object?>? pose;
    if (poseJson.trim().isNotEmpty) {
      try {
        final decoded = LuminaViewportScene.plain(jsonDecode(poseJson));
        if (decoded is Map<String, Object?>) pose = decoded;
      } catch (_) {}
    }
    _edit(self, target, null,
        (s) => s.showGhostPose(nodeId, pose: pose, animation: pose == null ? animation : null, time: time, color: _color(color), label: label));
  }

  static void hideSkeleton(LuminaActor self, Object? target, String nodeId) => _edit(self, target, null, (s) => s.hideSkeleton(nodeId));

  static void setGizmo(LuminaActor self, Object? target, String nodeId, String bone, String mode, String space, double snap) =>
      _edit(self, target, null, (s) => s.setGizmo(nodeId, bone: bone, mode: mode, space: space, snap: snap));

  static void hideGizmo(LuminaActor self, Object? target) => _edit(self, target, null, (s) => s.hideGizmo());

  /// Viewport Add Marker → the marker id.
  static String addMarker(LuminaActor self, Object? target, String label, String kind, Object? from, Object? to, Object? color) =>
      _edit(self, target, '', (s) => s.addMarker(label, kind, _vec(from), _vec(to), _color(color)));

  static void removeMarker(LuminaActor self, Object? target, String markerId) => _edit(self, target, null, (s) => s.removeMarker(markerId));
}
