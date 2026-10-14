import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart'
    show AssetType, LuminaAsset, LuminaBodyMask, LuminaGarmentDocument, LuminaGarmentFitReport, LuminaSkinnedMeshData;
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/assets/glb_loader.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/garment_cache.dart';
import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/cloth/skinned_cloth_component.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

part 'character_slots/body_masks.dart';

/// Maps a stored mesh reference (a Blueprint's `contents/…/X.lmas`) to the
/// path a mesh component loads.
typedef LuminaSlotMeshResolver = String Function(String storedPath);

/// One named slot of a character: the component in it now (a skeletal
/// mesh, a skinned cloth, or an empty scene component while the slot holds
/// nothing), the stored mesh reference, and the slot whose component leads
/// its pose.
class LuminaCharacterSlot {
  LuminaCharacterSlot._(this.name, this.component, this.mesh, this.leaderSlot, this.properties);

  final String name;

  /// The component holding the slot now.
  LuminaSceneComponent component;

  /// The stored mesh reference ('' while empty).
  String mesh;

  /// The slot leading this one's pose (null: none, it animates on its own).
  final String? leaderSlot;

  /// The properties the slot was built from (shadows, cloth settings).
  final Map<String, dynamic> properties;

  /// Whether a garment in this slot hides the body under it (default for
  /// the `Torso`, `Legs` and `Feet` slots; `masksBody` overrides).
  bool get masksBody => properties['masksBody'] as bool? ?? const {'torso', 'legs', 'feet'}.contains(name.toLowerCase());

  bool get isEmpty => mesh.isEmpty;

  /// The garment in the slot (when its mesh is a Garment asset), fitted to
  /// the leader slot's body, and how its latest fit went.
  LuminaGarmentDocument? garment;
  LuminaGarmentFitReport? lastFit;
}

/// The named slots of an actor's swappable parts (a character's `Body`,
/// `Face`, `Hair`, `Torso`, …): listed, read, filled and cleared at run
/// time. Filling a slot replaces its component with a new one of the mesh,
/// at the same place in the hierarchy (same parent, transform, children)
/// and following the same leader; the components following the old one
/// follow the new one. A Blueprint's components carrying a `slot` property
/// are registered when the Blueprint constructs.
class LuminaCharacterSlots {
  LuminaCharacterSlots._(this.actor);

  static final Expando<LuminaCharacterSlots> _of = Expando('character slots');

  /// The slots of [actor] (created empty on first use).
  static LuminaCharacterSlots of(LuminaActor actor) => _of[actor] ??= LuminaCharacterSlots._(actor);

  /// The slots of [actor] if any were registered, else null.
  static LuminaCharacterSlots? maybeOf(LuminaActor actor) => _of[actor];

  final LuminaActor actor;
  final Map<String, LuminaCharacterSlot> _slots = {};
  int _maskVersion = 0;

  /// Maps stored mesh references to loadable paths (from the Blueprint's
  /// construction; identity by default).
  LuminaSlotMeshResolver resolve = (stored) => stored;

  /// Reads the meshes (the Blueprint's asset provider; null: the default).
  LuminaAssetProvider? assetProvider;

  Future<void>? _ready;

  /// Completes when what a Blueprint's construction left to do is done
  /// ([applyConstructed]): garments fitted, bodies masked.
  Future<void> get ready => _ready ?? Future.value();

  /// After a Blueprint's construction: a slot whose mesh is a Garment asset
  /// is fitted to the body of the slot it follows (its component's load is
  /// held meanwhile, so the `.lmas` is never loaded as a mesh), then every
  /// body under a non-empty slot that masks it gets its mask, as after
  /// [setMesh]. Runs in the background ([ready]); fits and masks run on
  /// worker isolates and are cached.
  void applyConstructed() {
    final holds = <String, Completer<void>>{};
    for (final s in _slots.values) {
      final c = s.component;
      if (c is LuminaAnimatedMeshComponent && s.mesh.toLowerCase().endsWith('.lmas')) {
        final hold = Completer<void>();
        c.holdLoadUntil(hold.future);
        holds[s.name] = hold;
      }
    }
    _ready = _applyConstructed(holds);
  }

  Future<void> _applyConstructed(Map<String, Completer<void>> holds) async {
    for (final e in holds.entries) {
      final s = _slots[e.key]!;
      try {
        s.garment = await _garmentAt(s.mesh);
        if (s.garment != null) await _fitGarment(s);
      } catch (err) {
        developer.log('slot ${s.name}: cannot fit its garment: $err', name: 'LuminaCharacterSlots', level: 900);
        // Nothing to draw rather than the garment's asset as a mesh.
        if (s.garment != null && s.component is LuminaAnimatedMeshComponent) _replace(s, LuminaSceneComponent());
      } finally {
        if (!e.value.isCompleted) e.value.complete();
      }
    }
    final bodies = {
      for (final s in _slots.values)
        if (s.masksBody && !s.isEmpty && s.leaderSlot != null) s.leaderSlot!,
    };
    for (final body in bodies) {
      try {
        await refreshBodyMask(body);
      } catch (err) {
        developer.log('slot $body: cannot mask the body: $err', name: 'LuminaCharacterSlots', level: 900);
      }
    }
  }

  /// Changes whenever a slot's component is replaced.
  final StreamController<String> _changes = StreamController.broadcast(sync: true);
  Stream<String> get changes => _changes.stream;

  /// The slot names, in registration order.
  List<String> get names => List.unmodifiable(_slots.keys);

  LuminaCharacterSlot? slot(String name) => _slots[name];

  /// The component in [name] now (null for an unknown slot).
  LuminaSceneComponent? component(String name) => _slots[name]?.component;

  /// The stored mesh reference of [name] ('' when empty; null when unknown).
  String? meshOf(String name) => _slots[name]?.mesh;

  /// Registers [component] as slot [name] holding [mesh] (stored form);
  /// [leaderSlot] names the slot whose component leads its pose.
  LuminaCharacterSlot register(
    String name,
    LuminaSceneComponent component, {
    String mesh = '',
    String? leaderSlot,
    Map<String, dynamic> properties = const {},
  }) {
    final slot = LuminaCharacterSlot._(name, component, mesh, leaderSlot, Map.of(properties));
    _slots[name] = slot;
    return slot;
  }

  /// Fills [name] with the mesh at [mesh] (stored form, resolved through
  /// [resolve]); completes with false for an unknown slot. A skeletal mesh
  /// slot swaps its mesh in place (its animation, followers and children
  /// stay); an empty slot gets a new skeletal mesh component; a skinned
  /// cloth slot is rebuilt on the new garment. A garment slot that masks
  /// the body recomputes the body's mask. Completes once loaded (or failed).
  Future<bool> setMesh(String name, String mesh) async {
    final slot = _slots[name];
    if (slot == null) return false;
    if (mesh.isEmpty) return clear(name);
    final old = slot.component;
    slot.mesh = mesh;
    slot.garment = await _garmentAt(mesh);
    try {
      if (slot.garment != null) {
        await _fitGarment(slot);
      } else if (old is LuminaAnimatedMeshComponent) {
        old.slotMaterialSource = null;
        await old.setMeshAsset(resolve(mesh), assetProvider: assetProvider);
        _changes.add(name);
      } else if (old is LuminaSkinnedClothComponent) {
        final cloth = LuminaSkinnedClothComponent.fromProperties(
          {...slot.properties, ...old.toProperties(), 'meshAsset': resolve(mesh)},
          assetProvider: assetProvider,
        )..mesh = _leaderMesh(slot);
        _replace(slot, cloth);
      } else {
        final next = LuminaAnimatedMeshComponent(
          meshAssetPath: resolve(mesh),
          castShadows: slot.properties['castShadows'] as bool? ?? true,
          receiveShadows: slot.properties['receiveShadows'] as bool? ?? true,
          assetProvider: assetProvider,
        );
        _replace(slot, next);
        await next.loaded;
      }
    } catch (e) {
      developer.log('slot $name: cannot load $mesh: $e', name: 'LuminaCharacterSlots', level: 900);
    }
    // A new body: the garments on it are fitted to it again.
    for (final other in _slots.values.toList()) {
      if (other.leaderSlot == name && other.garment != null) {
        try {
          await _fitGarment(other);
        } catch (e) {
          developer.log('slot ${other.name}: cannot refit its garment: $e', name: 'LuminaCharacterSlots', level: 900);
        }
      }
    }
    await _afterChange(slot);
    return true;
  }

  /// Fits the Garment asset [garment] (stored path of its `.lmas`) into
  /// slot [name] on the body of the slot it follows; the fit report, or null
  /// for an unknown slot or an asset that is not a garment.
  Future<LuminaGarmentFitReport?> fitGarment(String name, String garment) async {
    final slot = _slots[name];
    if (slot == null || await _garmentAt(garment) == null) return null;
    await setMesh(name, garment);
    return slot.lastFit;
  }

  /// The garment document of the `.lmas` at [stored], or null when it is not
  /// a Garment asset (or cannot be read).
  Future<LuminaGarmentDocument?> _garmentAt(String stored) async {
    if (!stored.toLowerCase().endsWith('.lmas')) return null;
    final read = LuminaAssets.resolve(assetProvider);
    try {
      final asset = LuminaAsset.fromBytes(await read(stored));
      return asset.type == AssetType.garment ? LuminaGarmentDocument.fromAsset(asset) : null;
    } catch (_) {
      return null;
    }
  }

  /// Fits [slot]'s garment to its leader's body (unmasked) on a worker
  /// isolate (cached) and shows it: a skinned mesh following the body, or a
  /// skinned cloth worn on it when the garment simulates as cloth.
  Future<void> _fitGarment(LuminaCharacterSlot slot) async {
    final doc = slot.garment!;
    final body = slot.leaderSlot == null ? null : _slots[slot.leaderSlot!];
    if (body == null || body.isEmpty) {
      throw StateError('slot ${slot.name} follows no body to fit its garment to');
    }
    final read = LuminaAssets.resolve(assetProvider);
    final bytes = await Future.wait([
      LuminaMeshAssetCache.meshBytes(read, resolve(doc.sourceMesh)),
      LuminaMeshAssetCache.meshBytes(read, resolve(doc.referenceBody)),
      LuminaMeshAssetCache.meshBytes(read, resolve(body.mesh)),
    ]);
    final fitted = await LuminaGarmentCache.instance.fit(
      document: doc,
      source: bytes[0],
      reference: bytes[1],
      target: bytes[2],
      name: slot.name,
    );
    slot.lastFit = fitted.report;
    final provider = providerWith(fitted.path, fitted.bytes);
    final current = slot.component;
    if (doc.simulateAsCloth) {
      final cloth = LuminaSkinnedClothComponent.fromProperties({
        ...slot.properties,
        'meshAsset': fitted.path,
        if (doc.clothSettingsAsset.isNotEmpty) 'clothSettingsAsset': doc.clothSettingsAsset,
      }, assetProvider: provider)
        ..mesh = _leaderMesh(slot);
      _replace(slot, cloth);
    } else if (current is LuminaAnimatedMeshComponent) {
      // The source mesh's slot materials, on the fitted sections.
      current.slotMaterialSource = resolve(doc.sourceMesh);
      await current.setMeshAsset(fitted.path, assetProvider: provider);
      _changes.add(slot.name);
    } else {
      final next = LuminaAnimatedMeshComponent(
        meshAssetPath: fitted.path,
        castShadows: slot.properties['castShadows'] as bool? ?? true,
        receiveShadows: slot.properties['receiveShadows'] as bool? ?? true,
        assetProvider: provider,
      )..slotMaterialSource = resolve(doc.sourceMesh);
      _replace(slot, next);
      // Not in a world yet (a Blueprint still constructing): it loads there.
      if (actor.world != null) await next.loaded;
    }
  }

  Future<void> _afterChange(LuminaCharacterSlot slot) async {
    final body = slot.leaderSlot;
    if (slot.masksBody && body != null) {
      await refreshBodyMask(body);
    } else if (_slots.values.any((s) => s.leaderSlot == slot.name && s.masksBody && !s.isEmpty)) {
      // A new body: its garments mask it again.
      await refreshBodyMask(slot.name);
    }
  }

  /// Replaces [name]'s component with [next] (an already built component,
  /// e.g. a masked body loading its own bytes), keeping the stored mesh
  /// reference unless [mesh] is given.
  void replaceComponent(String name, LuminaSceneComponent next, {String? mesh}) {
    final slot = _slots[name];
    if (slot == null) throw ArgumentError.value(name, 'name', 'no such slot');
    if (mesh != null) slot.mesh = mesh;
    _replace(slot, next);
  }

  /// Empties [name] (its children stay, under an empty component); false
  /// for an unknown slot. A garment slot unmasks the body.
  Future<bool> clear(String name) async {
    final slot = _slots[name];
    if (slot == null) return false;
    slot.mesh = '';
    if (slot.component is LuminaAnimatedMeshComponent || slot.component is LuminaSkinnedClothComponent) {
      _replace(slot, LuminaSceneComponent());
    }
    await _afterChange(slot);
    return true;
  }

  LuminaAnimatedMeshComponent? _leaderMesh(LuminaCharacterSlot slot) {
    final leader = slot.leaderSlot == null ? null : _slots[slot.leaderSlot!]?.component;
    return leader is LuminaAnimatedMeshComponent ? leader : null;
  }

  void _replace(LuminaCharacterSlot slot, LuminaSceneComponent next) {
    final old = slot.component;
    final parent = old.parentComponent;
    next
      ..relativeLocation = Vector3.copy(old.relativeLocation)
      ..relativeRotation = Quaternion.copy(old.relativeRotation)
      ..relativeScale = Vector3.copy(old.relativeScale);
    if (parent != null) next.attachToComponent(parent);
    // Children move under the new component.
    for (final child in old.childComponents.toList()) {
      child.detachFromParent();
      child.attachToComponent(next);
    }
    if (next is LuminaAnimatedMeshComponent) {
      final leader = _leaderMesh(slot);
      if (leader != null && !identical(leader, old)) next.poseLeader = leader;
    }
    // Whoever followed the old component follows the new one; a garment
    // bound to it is rebuilt on the new one afterwards.
    final worn = <LuminaCharacterSlot>[];
    if (old is LuminaAnimatedMeshComponent) {
      for (final follower in old.poseFollowers.toList()) {
        follower.poseLeader = next is LuminaAnimatedMeshComponent ? next : null;
      }
      for (final other in _slots.values) {
        final c = other.component;
        if (!identical(other, slot) && c is LuminaSkinnedClothComponent && identical(c.mesh, old)) worn.add(other);
      }
      old.poseLeader = null;
    }
    old.detachFromParent();
    actor.removeComponent(old);
    slot.component = next;
    actor.addComponent(next);
    _changes.add(slot.name);
    for (final other in worn) {
      final c = other.component as LuminaSkinnedClothComponent;
      final cloth = LuminaSkinnedClothComponent.fromProperties(
        {...other.properties, ...c.toProperties()},
        assetProvider: assetProvider,
      )..mesh = next is LuminaAnimatedMeshComponent ? next : null;
      _replace(other, cloth);
    }
  }

  /// Bytes served under a synthetic mesh path (a masked body), through the
  /// slot's asset provider.
  LuminaAssetProvider providerWith(String path, Uint8List bytes) {
    final base = LuminaAssets.resolve(assetProvider);
    return (p) async => p == path ? bytes : base(p);
  }

  /// Disposes the change stream (the actor is gone).
  void dispose() => _changes.close();
}

/// Registers the slotted components a Blueprint built: every component with
/// a non-empty `slot` property (skeletal mesh, skinned cloth, or the empty
/// placeholder of a slot without a mesh), its stored mesh and the slot of
/// the component its `poseFrom` names.
void luminaRegisterBlueprintSlots(
  LuminaActor actor,
  List<({String id, String name, Map<String, dynamic> properties})> docs,
  Map<String, LuminaActorComponent> built, {
  LuminaSlotMeshResolver? resolve,
  LuminaAssetProvider? assetProvider,
}) {
  LuminaCharacterSlots? slots;
  String? slotOfComponent(String ref) {
    for (final d in docs) {
      if (d.id == ref || d.name == ref) {
        final s = d.properties['slot'];
        return s is String && s.isNotEmpty ? s : null;
      }
    }
    return null;
  }

  for (final d in docs) {
    final name = d.properties['slot'];
    if (name is! String || name.isEmpty) continue;
    final component = built[d.id];
    if (component is! LuminaSceneComponent) continue;
    slots ??= LuminaCharacterSlots.of(actor)
      ..resolve = resolve ?? ((s) => s)
      ..assetProvider = assetProvider;
    final from = d.properties['poseFrom'];
    final mesh = (d.properties['skeletalMeshAsset'] ?? d.properties['meshAsset']) as Object?;
    slots.register(
      name,
      component,
      mesh: mesh is String ? mesh : '',
      leaderSlot: from is String && from.isNotEmpty ? slotOfComponent(from) : null,
      properties: d.properties,
    );
  }
  slots?.applyConstructed();
}
