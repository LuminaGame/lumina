import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// A bone's world frame: position (world units) and rotation (no scale).
typedef LuminaBoneFrame = ({Vector3 position, Quaternion rotation});

/// A subset of a skinned mesh's nodes on the CPU, closed under parents (every
/// listed node's ancestors are listed before it), with their rest pose:
/// what a ragdoll reads and writes through a pose modifier.
///
/// Poses are flat TRS arrays in [nodeNames] order (10 doubles per node, the
/// mesh's local transforms); world affines (12 doubles per node) are in the
/// frame of the mesh's render transform, so world positions are world units.
class LuminaRagdollSkeleton {
  final LuminaGlbAnimationSampler sampler;

  /// Sampler node index per entry, parents first.
  final List<int> nodes;
  final List<String> nodeNames;

  /// Entry index of each entry's parent (−1 for a root of the asset).
  final Int32List parents;
  final Float64List restPose;
  final Map<int, int> _slotOfNode;

  LuminaRagdollSkeleton._(this.sampler, this.nodes, this.nodeNames, this.parents, this.restPose, this._slotOfNode);

  /// The nodes [bones] (sampler indices) need: themselves and their
  /// ancestors; with [allNodes] every node of the mesh.
  factory LuminaRagdollSkeleton(LuminaGlbAnimationSampler sampler, {Iterable<int> bones = const [], bool allNodes = false}) {
    final keep = <int>{};
    if (allNodes) {
      for (var i = 0; i < sampler.nodeCount; i++) {
        keep.add(i);
      }
    } else {
      for (final b in bones) {
        for (var n = b; n >= 0 && keep.add(n); n = sampler.parents[n]) {}
      }
    }
    final nodes = [for (final n in sampler.order) if (keep.contains(n)) n];
    final slot = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    final parents = Int32List.fromList([for (final n in nodes) sampler.parents[n] < 0 ? -1 : slot[sampler.parents[n]]!]);
    final rest = Float64List(nodes.length * LuminaPoseMath.trsStride);
    for (var i = 0; i < nodes.length; i++) {
      rest.setRange(i * 10, i * 10 + 10, sampler.rest, nodes[i] * 10);
    }
    return LuminaRagdollSkeleton._(sampler, nodes, [for (final n in nodes) sampler.nodeNames[n]], parents, rest, slot);
  }

  int get length => nodes.length;

  /// The entry of sampler node [node], or −1.
  int slotOf(int node) => _slotOfNode[node] ?? -1;

  /// The entry named [name], or −1.
  int slotNamed(String name) {
    final node = sampler.indexOfNode(name);
    return node < 0 ? -1 : slotOf(node);
  }

  /// [m] as an affine.
  static Float64List affineOf(Matrix4 m) {
    final s = m.storage;
    return Float64List.fromList([s[0], s[1], s[2], s[4], s[5], s[6], s[8], s[9], s[10], s[12], s[13], s[14]]);
  }

  /// World affines of [pose] under [meshAffine] into [out] (`length * 12`).
  void world(Float64List pose, Float64List meshAffine, Float64List out) {
    final tmp = _tmp;
    for (var i = 0; i < nodes.length; i++) {
      LuminaPoseMath.composeTrs(pose, i * 10, tmp, 0);
      final p = parents[i];
      if (p < 0) {
        LuminaPoseMath.multiplyAffine(meshAffine, 0, tmp, 0, out, i * 12);
      } else {
        LuminaPoseMath.multiplyAffine(out, p * 12, tmp, 0, out, i * 12);
      }
    }
  }

  final Float64List _tmp = Float64List(12);

  /// The frame of entry [slot] in the world affines [world].
  static LuminaBoneFrame frameOf(Float64List world, int slot) {
    final o = slot * 12;
    final q = Float64List(4);
    LuminaPoseMath.affineRotation(world, o, q, 0);
    return (position: Vector3(world[o + 9], world[o + 10], world[o + 11]), rotation: Quaternion(q[0], q[1], q[2], q[3]));
  }

  /// The uniform scale of entry [slot]'s world affine (its X column length).
  static double scaleOf(Float64List world, int slot) {
    final o = slot * 12;
    return math.sqrt(world[o] * world[o] + world[o + 1] * world[o + 1] + world[o + 2] * world[o + 2]);
  }

  /// Writes the world affine of a [frame] with uniform [scale] at [slot].
  static void setFrame(Float64List world, int slot, LuminaBoneFrame frame, double scale) {
    final m = frame.rotation.asRotationMatrix().storage;
    final o = slot * 12;
    for (var k = 0; k < 9; k++) {
      world[o + k] = m[k] * scale;
    }
    world[o + 9] = frame.position.x;
    world[o + 10] = frame.position.y;
    world[o + 11] = frame.position.z;
  }

  /// The local TRS at [slot] (into [pose]) that gives entry [slot] the world
  /// affine at [world]/[slot] under its parent's world affine.
  void localFromWorld(Float64List world, int slot, Float64List meshAffine, Float64List pose) {
    final p = parents[slot];
    final inv = _inv, local = _local;
    if (p < 0) {
      LuminaPoseMath.invertAffine(meshAffine, 0, inv, 0);
    } else {
      LuminaPoseMath.invertAffine(world, p * 12, inv, 0);
    }
    LuminaPoseMath.multiplyAffine(inv, 0, world, slot * 12, local, 0);
    LuminaPoseMath.decomposeAffine(local, 0, pose, slot * 10);
  }

  final Float64List _inv = Float64List(12);
  final Float64List _local = Float64List(12);

  /// World frames of every entry of the rest pose under [meshAffine].
  Float64List restWorld(Float64List meshAffine) {
    final out = Float64List(length * 12);
    world(restPose, meshAffine, out);
    return out;
  }
}
