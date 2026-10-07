import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/components/camera/spring_arm_component.dart';
import 'package:lumina/src/components/audio/audio_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/box_component.dart';
import 'package:lumina/src/components/collision/cone_component.dart';
import 'package:lumina/src/components/collision/convex_component.dart';
import 'package:lumina/src/components/collision/cylinder_component.dart';
import 'package:lumina/src/components/collision/sphere_component.dart';
import 'package:lumina/src/components/light/directional_light_component.dart';
import 'package:lumina/src/components/light/light_component.dart';
import 'package:lumina/src/components/light/point_light_component.dart';
import 'package:lumina/src/components/light/spot_light_component.dart';
import 'package:lumina/src/components/particles/particle_system_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/math/axes.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/character.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_runtime.dart';
import 'package:lumina/src/blueprint/blueprint_validator.dart';

/// Turns a stored mesh asset reference (a project `.lmas` path, a `.glb`) into
/// what a mesh component loads; null to skip the mesh.
typedef LuminaBlueprintAssetResolver = String? Function(String storedPath);

/// What a mesh component loads for a stored mesh reference when no resolver
/// maps it: a mesh asset's `.lmas` is loaded through the `.entity.glb` the
/// import writes next to it; anything else as stored.
String luminaBlueprintMeshPath(String stored) =>
    stored.toLowerCase().endsWith('.lmas') ? '${stored.substring(0, stored.length - 5)}.entity.glb' : stored;

/// Builds a Blueprint's component tree on an actor (its construction
/// script). The VM and generated code
/// both call it, so a Blueprint has the same components either
/// way. Transforms are converted from authoring space with [LuminaAxes].
abstract final class LuminaBlueprintComponents {
  /// Component types that exist only in the editor (drawn there, nothing at
  /// run time), or that the VM replaces (input is bound from the graph).
  static const Set<String> editorOnly = {'LuminaArrowComponent', 'LuminaPlayerComponent', 'LuminaInputComponent'};

  /// Constructs [components] on [actor] and returns them by component id.
  /// A Character's capsule and movement are its own fields, configured rather
  /// than created twice. Unknown types are reported in [diagnostics] and skipped.
  static Map<String, LuminaActorComponent> construct(
    LuminaActor actor,
    List<LuminaBlueprintComponent> components, {
    Map<String, LuminaActorComponent>? parentComponents,
    LuminaBlueprintAssetResolver? resolveAsset,
    Future<Uint8List> Function(String path)? assetProvider,
    List<LuminaBlueprintDiagnostic>? diagnostics,
    LuminaAnimBlueprintFactory? Function(String animClass)? animBlueprints,
  }) {
    final existing = actor is LuminaBlueprintRuntime ? actor.blueprintComponents : const <String, LuminaActorComponent>{};
    final built = <String, LuminaActorComponent>{...existing, ...?parentComponents};
    final pending = [...components];
    // Parents first; a parent missing from the list attaches to the root.
    var progressed = true;
    while (pending.isNotEmpty && progressed) {
      progressed = false;
      for (final c in List.of(pending)) {
        final parentReady = c.parentId == null ||
            built.containsKey(c.parentId) ||
            !components.any((o) => o.id == c.parentId) ||
            editorOnly.contains(components.firstWhere((o) => o.id == c.parentId).type);
        if (!parentReady) continue;
        pending.remove(c);
        progressed = true;
        final existingComp = built[c.id];
        if (existingComp != null) {
          if (existingComp is LuminaSceneComponent) {
            existingComp.detachFromParent();
          }
          actor.removeComponent(existingComp);
          built.remove(c.id);
        }
        final component = _build(actor, c, resolveAsset, assetProvider, diagnostics);
        if (component == null) continue;
        built[c.id] = component;
        if (component is LuminaSceneComponent && component != actor.rootComponent && !_isOwnField(actor, component)) {
          var parent = c.parentId == null ? null : built[c.parentId];
          // The capsule is not a Character's root: it is
          // a child of the actor root at its origin, so children of the
          // capsule attach to the root itself, as LuminaTemplateCharacter's
          // do (the capsule's world transform updates a step later).
          if (actor is LuminaCharacter && identical(parent, actor.capsuleComponent)) parent = actor.rootComponent;
          component.attachToComponent(parent is LuminaSceneComponent ? parent : actor.rootComponent);
        }
        // A Skeletal Mesh using an Animation Blueprint: the instance ticks
        // before the mesh, so each frame's pose is chosen before it is applied.
        if (component is LuminaAnimatedMeshComponent && c.properties['animMode'] == 'Use Animation Blueprint') {
          final animClass = c.properties['animClass'] as String? ?? '';
          // An unresolved class is reported when the Blueprint compiles.
          final factory = animClass.isEmpty ? null : animBlueprints?.call(animClass);
          if (factory != null) {
            final anim = factory(component);
            built['${c.id}.anim'] = anim;
            actor.addComponent(anim);
          }
        }
        if (!_isOwnField(actor, component) && component != actor.rootComponent) actor.addComponent(component);
      }
    }
    _inheritMeshPhysics(components, built);
    return built;
  }

  /// Resolves a static mesh asset's `metadata.physics` (`{massKg,
  /// centerOfMassOffset}`) from its stored `.lmas` path: the
  /// editor / PIE sets it to lumina's mesh physics service; a generated game
  /// has none and uses the values the editor baked into each component's
  /// `physics.meshPhysics`.
  static LuminaMeshPhysics? Function(String storedMeshAsset)? meshPhysicsResolver;

  /// A collision component with a Physics section inherits its static mesh's
  /// physics: the nearest static mesh component in the tree (a
  /// parent, then a child, then any), resolved fresh when a resolver is set.
  static void _inheritMeshPhysics(List<LuminaBlueprintComponent> docs, Map<String, LuminaActorComponent> built) {
    final resolver = meshPhysicsResolver;
    if (resolver == null) return;
    final byId = {for (final d in docs) d.id: d};
    String? meshOf(LuminaBlueprintComponent d) =>
        d.type == 'LuminaStaticMeshComponent' && (d.properties['staticMeshAsset'] as String? ?? '').isNotEmpty
            ? d.properties['staticMeshAsset'] as String
            : null;
    String? childMesh(String id) {
      for (final d in docs.where((d) => d.parentId == id)) {
        final m = meshOf(d) ?? childMesh(d.id);
        if (m != null) return m;
      }
      return null;
    }

    for (final d in docs) {
      final c = built[d.id];
      if (c is! LuminaCollisionComponent || d.properties['physics'] is! Map) continue;
      String? mesh;
      for (var p = d.parentId == null ? null : byId[d.parentId]; p != null && mesh == null; p = p.parentId == null ? null : byId[p.parentId]) {
        mesh = meshOf(p);
      }
      mesh ??= childMesh(d.id);
      for (final o in docs) {
        if (mesh != null) break;
        mesh = meshOf(o);
      }
      final fresh = mesh == null ? null : resolver(mesh);
      if (fresh != null) c.meshPhysics = fresh;
    }
  }

  /// The registry class name of a live component (the
  /// `Component:<class>` type): the document type it was built from, never
  /// `runtimeType` (minified on the web). A skeletal mesh reports
  /// `LuminaSkeletalMeshComponent`, its document type.
  static String classNameOf(LuminaActorComponent c) {
    if (c is LuminaSpringArmComponent) return 'LuminaSpringArmComponent';
    if (c is LuminaCameraComponent) return 'LuminaCameraComponent';
    if (c is LuminaAnimBlueprintInstance) return 'LuminaAnimBlueprintInstance';
    if (c is LuminaPointLightComponent) return 'LuminaPointLightComponent';
    if (c is LuminaSpotLightComponent) return 'LuminaSpotLightComponent';
    if (c is LuminaDirectionalLightComponent) return 'LuminaDirectionalLightComponent';
    if (c is LuminaLightComponent) return 'LuminaLightComponent';
    if (c is LuminaAudioComponent) return 'LuminaAudioComponent';
    if (c is LuminaParticleSystemComponent) return 'LuminaParticleSystemComponent';
    if (c is LuminaCapsuleComponent) return 'LuminaCapsuleComponent';
    if (c is LuminaBoxComponent) return 'LuminaBoxComponent';
    if (c is LuminaSphereComponent) return 'LuminaSphereComponent';
    if (c is LuminaCylinderComponent) return 'LuminaCylinderComponent';
    if (c is LuminaConeComponent) return 'LuminaConeComponent';
    if (c is LuminaConvexComponent) return 'LuminaConvexComponent';
    if (c is LuminaCollisionComponent) return 'LuminaCollisionComponent';
    if (c is LuminaAnimatedMeshComponent) return 'LuminaSkeletalMeshComponent';
    if (c is LuminaStaticMeshComponent) return 'LuminaStaticMeshComponent';
    if (c is LuminaCharacterMovementComponent) return 'LuminaCharacterMovementComponent';
    if (c is LuminaSceneComponent) return 'LuminaSceneComponent';
    return 'LuminaActorComponent';
  }

  /// Whether [c] is a [componentClass] or a subclass of it, by the engine's
  /// class chain.
  static bool isA(LuminaActorComponent c, String componentClass) {
    if (componentClass.isEmpty || componentClass == 'LuminaActorComponent') return true;
    final own = classNameOf(c);
    if (own == componentClass) return true;
    return LuminaBlueprintObjectClass.ancestors(LuminaBlueprintObjectClass.component(own))
        .contains(LuminaBlueprintObjectClass.component(componentClass));
  }

  /// Resolves a convex component's `hullAsset` (a mesh asset's `.lmas`
  /// path) to its hull points in the component's local frame (world units):
  /// the editor / PIE sets it to the mesh collision service; generated games
  /// carry the points in the component's `hullPoints` instead. A hull no
  /// resolver and no points provide degrades to the component's box.
  static List<Vector3>? Function(String hullAsset)? hullResolver;

  static int _added = 0;

  /// A fresh id for a component added at run time.
  static String nextDynamicId() => 'added_${_added++}';

  /// Adds a new component of document type [type] to [actor] at run time
  /// (Add Component): built by the same table as the
  /// construction script, attached to the actor root, registered. Null when
  /// the type has no runtime counterpart.
  static LuminaActorComponent? addDynamic(LuminaActor actor, String type,
      {String? name, Map<String, dynamic>? properties, String? id}) {
    final c = LuminaBlueprintComponent(
        id: id ?? nextDynamicId(),
        name: name ?? type.replaceAll('Lumina', ''),
        type: type,
        parentId: 'root',
        properties: properties);
    final component = _build(actor, c, null, null, null);
    if (component == null) return null;
    if (component is LuminaSceneComponent && component != actor.rootComponent && !_isOwnField(actor, component)) {
      component.attachToComponent(actor.rootComponent);
    }
    if (!_isOwnField(actor, component) && component != actor.rootComponent) actor.addComponent(component);
    return component;
  }

  static bool _isOwnField(LuminaActor actor, LuminaActorComponent c) =>
      actor is LuminaCharacter && (identical(c, actor.capsuleComponent) || identical(c, actor.characterMovement));

  static double? _num(Map<String, dynamic> p, String key) => (p[key] as num?)?.toDouble();
  static bool? _bool(Map<String, dynamic> p, String key) => p[key] is bool ? p[key] as bool : null;

  /// The collision JSON keys (`preset`, `objectType`, `responses`,
  /// `generateOverlapEvents`, `collisionEnabled`) of any collision component.
  static void _collision(LuminaCollisionComponent c, Map<String, dynamic> p) {
    if (LuminaCollisionProfile.hasCollisionKeys(p)) c.applyCollisionJson(p);
    _physics(c, p);
  }

  /// The `physics` JSON of a collision or static mesh component (see
  /// [LuminaPrimitivePhysics.applyPhysicsJson]).
  static void _physics(LuminaPrimitivePhysics c, Map<String, dynamic> p) {
    final physics = p['physics'];
    if (physics is Map) c.applyPhysicsJson(Map<String, dynamic>.from(physics));
  }

  static Vector3? _vec(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v is List && v.length >= 3 && v.every((e) => e is num)) return LuminaAxes.scale(v.cast<num>());
    if (v is num) return Vector3.all(v.toDouble());
    return null;
  }

  static List<Vector3>? _points(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v is! List || v.isEmpty) return null;
    final out = <Vector3>[];
    for (final e in v) {
      if (e is List && e.length >= 3 && e.every((n) => n is num)) {
        out.add(Vector3((e[0] as num).toDouble(), (e[1] as num).toDouble(), (e[2] as num).toDouble()));
      }
    }
    return out.length >= 4 ? out : null;
  }

  /// A light's colour (`color`, linear RGB, or `colorHex`, the sRGB
  /// `#RRGGBB` the editor's colour picker and level lights store), shadows
  /// and visibility.
  static void _light(LuminaLightComponent light, Map<String, dynamic> p) {
    final color = p['color'];
    if (color is List && color.length >= 3 && color.every((e) => e is num)) {
      light.color = Vector3((color[0] as num).toDouble(), (color[1] as num).toDouble(), (color[2] as num).toDouble());
    } else if (p['colorHex'] is String) {
      light.color = luminaLightColorFromHex(p['colorHex'] as String, fallback: light.color);
    }
    light.castShadows = _bool(p, 'castShadows') ?? light.castShadows;
    light.visible = _bool(p, 'visible') ?? true;
  }

  static void _transform(LuminaSceneComponent s, Map<String, dynamic> p) {
    final loc = p['location'];
    final rot = p['rotation'];
    final scl = p['scale'];
    if (loc is List) s.relativeLocation = LuminaAxes.location(loc.cast<num>());
    if (rot is List) s.relativeRotation = LuminaAxes.rotation(rot.cast<num>());
    if (scl is List) s.relativeScale = LuminaAxes.scale(scl.cast<num>());
  }

  static LuminaActorComponent? _build(
    LuminaActor actor,
    LuminaBlueprintComponent c,
    LuminaBlueprintAssetResolver? resolveAsset,
    Future<Uint8List> Function(String path)? assetProvider,
    List<LuminaBlueprintDiagnostic>? diagnostics,
  ) {
    final p = c.properties;
    switch (c.type) {
      case 'LuminaSceneComponent':
        // The root of an Actor/Pawn Blueprint is the actor's own root.
        if (c.parentId == null) return actor.rootComponent;
        return LuminaSceneComponent().._applyTransform(p);
      case 'LuminaCapsuleComponent':
        final capsule = actor is LuminaCharacter ? actor.capsuleComponent : LuminaCapsuleComponent();
        final radius = _num(p, 'capsuleRadius');
        final halfHeight = _num(p, 'capsuleHalfHeight');
        if (radius != null) capsule.capsuleRadius = radius;
        if (halfHeight != null) capsule.capsuleHalfHeight = halfHeight;
        if (actor is! LuminaCharacter) _transform(capsule, p);
        _collision(capsule, p);
        return capsule;
      case 'LuminaBoxComponent':
        final box = LuminaBoxComponent(boxExtent: _vec(p, 'boxExtent'));
        _transform(box, p);
        _collision(box, p);
        return box;
      case 'LuminaSphereComponent':
        final sphere = LuminaSphereComponent(radius: _num(p, 'radius') ?? 50.0);
        _transform(sphere, p);
        _collision(sphere, p);
        return sphere;
      case 'LuminaCylinderComponent':
        final cylinder = LuminaCylinderComponent(radius: _num(p, 'radius') ?? 50.0, halfHeight: _num(p, 'halfHeight') ?? 80.0);
        _transform(cylinder, p);
        _collision(cylinder, p);
        return cylinder;
      case 'LuminaConeComponent':
        final cone = LuminaConeComponent(radius: _num(p, 'radius') ?? 50.0, halfHeight: _num(p, 'halfHeight') ?? 80.0);
        _transform(cone, p);
        _collision(cone, p);
        return cone;
      case 'LuminaConvexComponent':
        final hullAsset = p['hullAsset'] as String? ?? '';
        final points = _points(p, 'hullPoints') ?? (hullAsset.isEmpty ? null : hullResolver?.call(hullAsset));
        final LuminaCollisionComponent convex;
        if (points != null) {
          convex = LuminaConvexComponent(points: points, hullAsset: hullAsset.isEmpty ? null : hullAsset);
        } else {
          diagnostics?.add(LuminaBlueprintDiagnostic(
            LuminaBlueprintSeverity.warning,
            "Convex component '${c.name}' has no resolvable hull${hullAsset.isEmpty ? '' : " ($hullAsset)"}; it collides as its box.",
          ));
          convex = LuminaBoxComponent(boxExtent: _vec(p, 'boxExtent'));
        }
        _transform(convex, p);
        _collision(convex, p);
        return convex;
      case 'LuminaCharacterMovementComponent':
        final movement = actor is LuminaCharacter ? actor.characterMovement : LuminaCharacterMovementComponent();
        movement.maxWalkSpeed = _num(p, 'maxWalkSpeed') ?? movement.maxWalkSpeed;
        movement.jumpZVelocity = _num(p, 'jumpZVelocity') ?? movement.jumpZVelocity;
        movement.airControl = _num(p, 'airControl') ?? movement.airControl;
        movement.jumpCutMultiplier = _num(p, 'jumpCutMultiplier') ?? movement.jumpCutMultiplier;
        movement.gravityScale = _num(p, 'gravityScale') ?? movement.gravityScale;
        movement.brakingDeceleration = _num(p, 'brakingDecelerationWalking') ?? movement.brakingDeceleration;
        return movement;
      case 'LuminaSpringArmComponent':
        // Through the constructor: it also starts the arm's current length
        // (its lag state) at the target, as a hand-written component does.
        final arm = LuminaSpringArmComponent(targetArmLength: _num(p, 'targetArmLength') ?? 300.0);
        _transform(arm, p);
        arm.bUsePawnControlRotation = _bool(p, 'usePawnControlRotation') ?? arm.bUsePawnControlRotation;
        arm.bInheritPitch = _bool(p, 'inheritPitch') ?? arm.bInheritPitch;
        arm.bInheritYaw = _bool(p, 'inheritYaw') ?? arm.bInheritYaw;
        arm.bInheritRoll = _bool(p, 'inheritRoll') ?? arm.bInheritRoll;
        arm.bEnableCameraLag = _bool(p, 'enableCameraLag') ?? arm.bEnableCameraLag;
        arm.cameraLagSpeed = _num(p, 'cameraLagSpeed') ?? arm.cameraLagSpeed;
        arm.bEnableCameraRotationLag = _bool(p, 'enableCameraRotationLag') ?? arm.bEnableCameraRotationLag;
        arm.cameraRotationLagSpeed = _num(p, 'cameraRotationLagSpeed') ?? arm.cameraRotationLagSpeed;
        arm.bDoCollisionTest = _bool(p, 'doCollisionTest') ?? arm.bDoCollisionTest;
        arm.probeSize = _num(p, 'probeSize') ?? arm.probeSize;
        return arm;
      case 'LuminaCameraComponent':
        // The level Camera's property names and units.
        final camera = LuminaCameraComponent();
        LuminaCameraSettings.fromProperties(p).applyTo(camera);
        _transform(camera, p);
        // A Blueprint's camera auto-activates by default.
        camera.isActive = _bool(p, 'autoActivate') ?? true;
        return camera;
      case 'LuminaSkeletalMeshComponent':
      case 'LuminaAnimatedMeshComponent':
        final stored = p['skeletalMeshAsset'] as String? ?? '';
        final path = stored.isEmpty ? null : (resolveAsset?.call(stored) ?? luminaBlueprintMeshPath(stored));
        if (path == null) {
          final placeholder = LuminaSceneComponent();
          _transform(placeholder, p);
          return placeholder;
        }
        final mesh = LuminaAnimatedMeshComponent(
          meshAssetPath: path,
          castShadows: _bool(p, 'castShadows') ?? true,
          receiveShadows: _bool(p, 'receiveShadows') ?? true,
          assetProvider: assetProvider,
        );
        _transform(mesh, p);
        return mesh;
      case 'PointLightComponent':
      case 'LuminaPointLightComponent':
        final light = LuminaPointLightComponent(intensity: _num(p, 'intensity') ?? 1000.0);
        _transform(light, p);
        _light(light, p);
        final radius = _num(p, 'attenuationRadius') ?? _num(p, 'falloffRadius');
        if (radius != null) light.falloffRadius = radius;
        return light;
      case 'DirectionalLightComponent':
      case 'LuminaDirectionalLightComponent':
        final light = LuminaDirectionalLightComponent(
          intensity: _num(p, 'intensity') ?? 100000.0,
          isSun: _bool(p, 'isSun') ?? true,
          sunAngularRadius: _num(p, 'sunAngularRadius') ?? 0.545,
          sunHaloSize: _num(p, 'sunHaloSize') ?? 10.0,
          sunHaloFalloff: _num(p, 'sunHaloFalloff') ?? 80.0,
        );
        _transform(light, p);
        _light(light, p);
        return light;
      case 'SpotLightComponent':
      case 'LuminaSpotLightComponent':
        final inner = _num(p, 'innerConeAngle') ?? _num(p, 'innerConeAngleDegrees') ?? 30.0;
        final outer = _num(p, 'outerConeAngle') ?? _num(p, 'outerConeAngleDegrees') ?? 45.0;
        final safeOuter = outer.clamp(0.01, 90.0);
        final safeInner = inner.clamp(0.0, safeOuter);
        final light = LuminaSpotLightComponent(
          intensity: _num(p, 'intensity') ?? 10000.0,
          innerConeAngleDegrees: safeInner,
          outerConeAngleDegrees: safeOuter,
        );
        _transform(light, p);
        _light(light, p);
        final radius = _num(p, 'attenuationRadius') ?? _num(p, 'falloffRadius');
        if (radius != null) light.falloffRadius = radius;
        return light;
      case 'LuminaStaticMeshComponent':
        final stored = p['staticMeshAsset'] as String? ?? '';
        final path = stored.isEmpty ? null : (resolveAsset?.call(stored) ?? luminaBlueprintMeshPath(stored));
        if (path == null) {
          final placeholder = LuminaSceneComponent();
          _transform(placeholder, p);
          return placeholder;
        }
        final mesh = LuminaStaticMeshComponent(
          meshAssetPath: path,
          castShadows: _bool(p, 'castShadows') ?? true,
          receiveShadows: _bool(p, 'receiveShadows') ?? true,
          assetProvider: assetProvider,
          materialOverrideAsset: (p['materialOverride'] as String? ?? '').isEmpty ? null : p['materialOverride'] as String,
        );
        _transform(mesh, p);
        _physics(mesh, p);
        final meshPhysics = meshPhysicsResolver?.call(stored);
        if (meshPhysics != null) mesh.meshPhysics = meshPhysics;
        return mesh;
    }
    if (editorOnly.contains(c.type)) {
      // Keep the hierarchy: an arrow can parent other components.
      return c.type == 'LuminaArrowComponent' ? (LuminaSceneComponent().._applyTransform(p)) : null;
    }
    diagnostics?.add(LuminaBlueprintDiagnostic(
      LuminaBlueprintSeverity.warning,
      "Component '${c.name}' of type ${c.type} has no runtime counterpart and is skipped.",
    ));
    return null;
  }
}

extension on LuminaSceneComponent {
  void _applyTransform(Map<String, dynamic> p) => LuminaBlueprintComponents._transform(this, p);
}
