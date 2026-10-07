import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/property_editors/collision_section_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/physics_section_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';

/// A placed Blueprint actor's per-instance collision,
/// as the level Details edits it: instance overrides of a
/// component's Collision section.
///
/// The class's collision components come from its Blueprint document; an
/// edit stores an [EditorComponentNode] in the actor's `components` (saved in
/// the level `.lmas` `metadata.actors[]`) with the component's type and name,
/// [componentIdKey] naming the Blueprint component, and the collision JSON
/// keys. Play-In-Editor applies it to the instance's built component
/// ([applyTo]); keys an override lacks keep the class's values.
abstract final class BlueprintCollisionOverrides {
  /// The override node property naming the Blueprint component it overrides.
  static const String componentIdKey = 'blueprintComponentId';

  /// The id of [actorId]'s override of Blueprint component [componentId].
  static String overrideId(String actorId, String componentId) => '$actorId.collision.$componentId';

  /// Whether [node] is an instance override (not a component of its own).
  static bool isOverride(EditorComponentNode node) => node.properties[componentIdKey] is String;

  static final Map<String, ({DateTime modified, LuminaBlueprintDocument doc})> _cache = {};

  /// The Blueprint document at [path] (project-relative) in [projectDir];
  /// cached until the file changes. Null when it cannot be read.
  static LuminaBlueprintDocument? documentOf(String projectDir, String path) {
    final file = File(path.startsWith('/') ? path : '$projectDir/$path');
    if (!file.existsSync()) return null;
    final modified = file.lastModifiedSync();
    final cached = _cache[file.path];
    if (cached != null && cached.modified == modified) return cached.doc;
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null || payload.isEmpty) return null;
      final doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
      _cache[file.path] = (modified: modified, doc: doc);
      return doc;
    } catch (_) {
      return null;
    }
  }

  /// The collision components of placed Blueprint [actor]'s class, in
  /// document order; empty for any other actor.
  static List<LuminaBlueprintComponent> collisionComponentsOf(EditorActorNode actor, String projectDir) {
    final path = actor.blueprintClass;
    if (path == null || path.isEmpty) return const [];
    final doc = documentOf(projectDir, path);
    if (doc == null) return const [];
    return [
      for (final c in doc.components)
        if (BlueprintComponentRegistry.isCollisionCapable(c.type)) c,
    ];
  }

  /// [actor]'s override of Blueprint component [componentId], if any.
  static EditorComponentNode? overrideOf(EditorActorNode actor, String componentId) =>
      actor.components.where((c) => c.properties[componentIdKey] == componentId).firstOrNull;

  /// The collision JSON the level Details shows for [component] of [actor]:
  /// the class's keys with the instance override on top.
  static Map<String, dynamic> collisionOf(EditorActorNode actor, LuminaBlueprintComponent component) {
    final override = overrideOf(actor, component.id);
    return {
      ...CollisionJson.of(component.properties),
      if (override != null) ...CollisionJson.of(override.properties),
    };
  }

  /// The components of placed Blueprint [actor]'s class with a Physics
  /// section: collision shapes and static meshes.
  static List<LuminaBlueprintComponent> physicsComponentsOf(EditorActorNode actor, String projectDir) {
    final path = actor.blueprintClass;
    if (path == null || path.isEmpty) return const [];
    final doc = documentOf(projectDir, path);
    if (doc == null) return const [];
    return [
      for (final c in doc.components)
        if (BlueprintComponentRegistry.isCollisionCapable(c.type) || c.type == 'LuminaStaticMeshComponent') c,
    ];
  }

  /// The physics JSON the level Details shows for [component] of [actor]:
  /// the class's `physics` map with the instance override's keys on top.
  static Map<String, dynamic> physicsOf(EditorActorNode actor, LuminaBlueprintComponent component) {
    final override = overrideOf(actor, component.id);
    return {
      ...PhysicsJson.of(component.properties),
      if (override != null) ...PhysicsJson.of(override.properties),
    };
  }

  /// [component]'s built-in setup in [doc]: a Character's root capsule is
  /// Pawn, anything else lumina's default.
  static LuminaCollisionProfile baseOf(LuminaBlueprintDocument? doc, LuminaBlueprintComponent component) {
    final isRoot = component.parentId == null;
    if (doc?.parentClass == 'LuminaCharacter' && component.type == 'LuminaCapsuleComponent' && isRoot) {
      return LuminaCollisionProfile.forPreset(LuminaCollisionPreset.pawn);
    }
    return LuminaCollisionProfile();
  }

  /// Applies [actor]'s overrides to [instance]'s built collision components
  /// (Play-In-Editor, before the actor is registered).
  static int applyTo(LuminaBlueprintInstance instance, EditorActorNode actor) {
    var applied = 0;
    for (final node in actor.components) {
      final id = node.properties[componentIdKey];
      if (id is! String) continue;
      final built = instance.blueprintComponents[id];
      final json = CollisionJson.of(node.properties);
      if (built is LuminaCollisionComponent && json.isNotEmpty) {
        built.applyCollisionJson(json);
        applied++;
      }
      // This placement's Physics section.
      final physics = PhysicsJson.of(node.properties);
      if (built is LuminaPrimitivePhysics && physics.isNotEmpty) {
        built.applyPhysicsJson(physics);
        if (json.isEmpty || built is! LuminaCollisionComponent) applied++;
      }
    }
    return applied;
  }
}
