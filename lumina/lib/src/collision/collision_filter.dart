import '../components/collision/collision_component.dart';

/// Semantic object-type channel for collision interaction.
enum CollisionObjectType { worldStatic, worldDynamic, pawn }

/// Interaction response between two colliding objects.
enum CollisionResponse { ignore, overlap, block }

/// 32-bit layer bitmask helpers and layer constant definitions.
class CollisionLayers {
  static const int all = 0xFFFFFFFF;
  static const int none = 0;

  static const int layer1 = 1 << 0;
  static const int layer2 = 1 << 1;
  static const int layer3 = 1 << 2;
  static const int layer4 = 1 << 3;
  static const int layer5 = 1 << 4;
  static const int layer6 = 1 << 5;
  static const int layer7 = 1 << 6;
  static const int layer8 = 1 << 7;
  static const int layer9 = 1 << 8;
  static const int layer10 = 1 << 9;
  static const int layer11 = 1 << 10;
  static const int layer12 = 1 << 11;
  static const int layer13 = 1 << 12;
  static const int layer14 = 1 << 13;
  static const int layer15 = 1 << 14;
  static const int layer16 = 1 << 15;
  static const int layer17 = 1 << 16;
  static const int layer18 = 1 << 17;
  static const int layer19 = 1 << 18;
  static const int layer20 = 1 << 19;
  static const int layer21 = 1 << 20;
  static const int layer22 = 1 << 21;
  static const int layer23 = 1 << 22;
  static const int layer24 = 1 << 23;
  static const int layer25 = 1 << 24;
  static const int layer26 = 1 << 25;
  static const int layer27 = 1 << 26;
  static const int layer28 = 1 << 27;
  static const int layer29 = 1 << 28;
  static const int layer30 = 1 << 29;
  static const int layer31 = 1 << 30;
  static const int layer32 = (1 << 31) & 0xFFFFFFFF;

  /// Returns the single-bit mask for 1-based [layerIndex] (1 to 32).
  static int layer(int layerIndex) {
    if (layerIndex < 1 || layerIndex > 32) {
      throw RangeError.range(layerIndex, 1, 32, 'layerIndex');
    }
    return (1 << (layerIndex - 1)) & 0xFFFFFFFF;
  }

  /// Combines multiple 1-based layer indices into a single 32-bit mask.
  static int maskOf(Iterable<int> layerIndices) {
    int mask = 0;
    for (final i in layerIndices) {
      mask |= layer(i);
    }
    return mask & 0xFFFFFFFF;
  }
}

/// Resolves the effective mutual response between components [a] and [b].
CollisionResponse effectiveResponse(LuminaCollisionComponent a, LuminaCollisionComponent b) {
  if (!a.collisionEnabled || !b.collisionEnabled) {
    return CollisionResponse.ignore;
  }
  if (!a.canInteractWith(b)) {
    return CollisionResponse.ignore;
  }

  final respA = a.getResponse(b.objectType);
  final respB = b.getResponse(a.objectType);

  // Min-wins resolution (Ignore < Overlap < Block)
  if (respA == CollisionResponse.ignore || respB == CollisionResponse.ignore) {
    return CollisionResponse.ignore;
  }
  if (respA == CollisionResponse.overlap || respB == CollisionResponse.overlap) {
    return CollisionResponse.overlap;
  }
  return CollisionResponse.block;
}

/// Standard preset configurations for collision components.
class CollisionProfile {
  /// Profile that blocks all channels.
  static void applyBlockAll(LuminaCollisionComponent c) {
    c.collisionEnabled = true;
    c.objectType = CollisionObjectType.worldDynamic;
    c.setResponseToAll(CollisionResponse.block);
  }

  /// Profile that overlaps all channels.
  static void applyOverlapAll(LuminaCollisionComponent c) {
    c.collisionEnabled = true;
    c.objectType = CollisionObjectType.worldDynamic;
    c.setResponseToAll(CollisionResponse.overlap);
  }

  /// Standard Pawn profile: blocks static & dynamic geometry, overlaps other pawns.
  static void applyPawn(LuminaCollisionComponent c) {
    c.collisionEnabled = true;
    c.objectType = CollisionObjectType.pawn;
    c.setResponse(CollisionObjectType.worldStatic, CollisionResponse.block);
    c.setResponse(CollisionObjectType.worldDynamic, CollisionResponse.block);
    c.setResponse(CollisionObjectType.pawn, CollisionResponse.overlap);
  }

  /// Disables collision completely.
  static void applyNoCollision(LuminaCollisionComponent c) {
    c.collisionEnabled = false;
    c.setResponseToAll(CollisionResponse.ignore);
  }
}
