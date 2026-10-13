import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/character_slots.dart';
import 'package:lumina/src/components/mesh/spring_morph_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/lumina_object_key.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// Follows the pose of another actor's skeletal mesh: the actor whose key
/// is [actorId] (a level actor's id). Its owner's skeletal mesh takes that
/// mesh's pose by bone name; the link is made as soon as the other actor is
/// in the world (it may stream in later) and the check then stops.
class LuminaPoseFromActorComponent extends LuminaActorComponent {
  LuminaPoseFromActorComponent(this.actorId);

  final String actorId;

  /// The leader once linked.
  LuminaAnimatedMeshComponent? get leader => _leader;
  LuminaAnimatedMeshComponent? _leader;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _link();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (_leader == null) _link();
  }

  void _link() {
    final self = owner;
    final world = self?.world;
    if (self == null || world == null || actorId.isEmpty) return;
    final mine = self.components.whereType<LuminaAnimatedMeshComponent>().firstOrNull;
    if (mine == null) return;
    for (final actor in world.actors) {
      if (identical(actor, self) || actor.key != LuminaObjectKey(actorId)) continue;
      final theirs = actor.components.whereType<LuminaAnimatedMeshComponent>().firstOrNull;
      if (theirs == null) return;
      try {
        mine.poseLeader = theirs;
        _leader = theirs;
      } on StateError {
        // A cycle: the other actor already follows this one; stay unlinked.
        _leader = null;
      }
      return;
    }
  }
}

/// A skeletal mesh placed in a level, as Play-In-Editor and the generated
/// game build it from the level's row and its Mesh Component Details: an
/// animated skeletal mesh (it can play, follow and be followed), with
/// - `castShadow` (Details) over the actor's cast shadows,
/// - the material assigned in the level ([materialOverrideAsset]),
/// - `slot`: the actor's character slot of that name holds the mesh,
/// - `poseFrom`: the id of another level actor whose skeletal mesh it
///   follows by bone name,
/// - [springs]: a `LuminaSpringMorphComponent` (jiggle), after the mesh,
/// - [animBlueprint]: the instance of the Anim Class (Details), which
///   drives the mesh's pose every frame.
abstract final class LuminaLevelSkeletalMesh {
  /// The project path of the Animation Blueprint the Details' Anim Class
  /// names (an asset reference or a path), or null for none.
  static String? animClassPath(Map<String, Object?> details) {
    final value = details['animClass'];
    var path = value is Map ? value['asset_path'] : value;
    if (path is! String) return null;
    path = path.replaceAll(r'\', '/');
    final contents = path.indexOf('/contents/');
    if (!path.startsWith('contents/') && contents >= 0) path = path.substring(contents + 1);
    return path.isEmpty || path == 'None' || !path.endsWith('.lmas') ? null : path;
  }

  static LuminaActor build({
    LuminaObjectKey? key,
    required String meshAssetPath,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    bool castShadows = true,
    bool visible = true,
    String? materialOverrideAsset,
    Map<String, Object?> details = const {},
    Map<String, Object?>? springs,
    LuminaAssetProvider? assetProvider,
    LuminaAnimBlueprintFactory? animBlueprint,
  }) {
    final shadow = details['castShadow'];
    final mesh = LuminaAnimatedMeshComponent(
      location: location,
      rotation: rotation,
      scale: scale,
      meshAssetPath: meshAssetPath,
      castShadows: shadow is bool ? shadow : castShadows,
      visible: visible,
      materialOverrideAsset: materialOverrideAsset,
      assetProvider: assetProvider,
    );
    final actor = LuminaActor(key: key, root: mesh);
    if (animBlueprint != null) actor.addComponent(animBlueprint(mesh));
    if (springs != null) actor.addComponent(LuminaSpringMorphComponent.fromProperties(Map<String, Object?>.of(springs)));
    final from = details['poseFrom'];
    if (from is String && from.isNotEmpty && from != 'None' && from != key?.value) {
      actor.addComponent(LuminaPoseFromActorComponent(from));
    }
    final slot = details['slot'];
    if (slot is String && slot.isNotEmpty) {
      LuminaCharacterSlots.of(actor).register(slot, mesh, mesh: meshAssetPath, properties: {'castShadows': mesh.castShadows});
    }
    return actor;
  }
}
