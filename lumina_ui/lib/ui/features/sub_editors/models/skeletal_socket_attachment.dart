import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart' show GlbMeshData, GlbNode;
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3;

import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';

/// A mesh previewed on a skeletal socket:
/// the Skeletal Mesh editor's viewport draws [mesh] at
/// `entityWorld × G_bone × offset`, the engine's socket chain, so an
/// attachment follows its bone.
class SkeletalSocketAttachment {
  const SkeletalSocketAttachment({
    required this.socketName,
    required this.boneName,
    required this.assetPath,
    required this.mesh,
    required this.localOffset,
    required this.restWorld,
  });

  final String socketName;
  final String boneName;

  /// The previewed mesh's `.lmas` on disk.
  final String assetPath;
  final GlbMeshData mesh;

  /// The socket's offset in its bone's frame, in the viewport's units
  /// (metres): the right-hand factor of the chain.
  final Matrix4 localOffset;

  /// `entityWorld × G_bone × offset` with the bone at its rest pose and the
  /// preview mesh at the origin: where the attachment is drawn when the
  /// viewport cannot parent it to the live joint.
  final Matrix4 restWorld;

  /// What the viewport compares to know an attachment changed.
  String get signature => '$socketName|$boneName|$assetPath|${localOffset.storage.join(',')}';
}

/// The socket transform chain shared by the viewport's attachments and its
/// socket markers.
abstract final class SkeletalSocketMath {
  /// Socket locations are authored in centimetres (like joint deltas and
  /// the collision / physics editors); the preview's GLB is in metres.
  static const double cmToViewport = 0.01;

  /// `T · R · S` of [socket] in its bone's frame, in metres. A 3-element
  /// rotation is X, Y, Z degrees about the bone's axes, applied X then Y
  /// then Z (`R = Rz · Ry · Rx`); a 4-element one is a quaternion `[x, y, z, w]`.
  static Matrix4 localOffset(SkeletalMeshSocket socket) {
    final t = socket.relativeLocation;
    final translation = Vector3(
      (t.isNotEmpty ? t[0] : 0.0) * cmToViewport,
      (t.length > 1 ? t[1] : 0.0) * cmToViewport,
      (t.length > 2 ? t[2] : 0.0) * cmToViewport,
    );
    final r = socket.relativeRotation;
    Quaternion rotation;
    if (r.length >= 4) {
      final q = Quaternion(r[0], r[1], r[2], r[3]);
      rotation = q.length > 1e-12 && q.length.isFinite ? q.normalized() : Quaternion.identity();
    } else {
      double deg(int i) => (r.length > i ? r[i] : 0.0) * math.pi / 180.0;
      rotation = Quaternion.axisAngle(Vector3(0, 0, 1), deg(2)) *
          Quaternion.axisAngle(Vector3(0, 1, 0), deg(1)) *
          Quaternion.axisAngle(Vector3(1, 0, 0), deg(0));
    }
    final s = socket.relativeScale;
    final scale = Vector3(
      s.isNotEmpty ? s[0] : 1.0,
      s.length > 1 ? s[1] : 1.0,
      s.length > 2 ? s[2] : 1.0,
    );
    return Matrix4.compose(translation, rotation, scale);
  }

  /// The rest-pose global transform of the node named [bone] in [mesh]
  /// (`G_bone`, the GLB's frame), or null when the mesh has no such node.
  static Matrix4? boneGlobal(GlbMeshData mesh, String bone) {
    Matrix4? found;
    void walk(GlbNode node, Matrix4 parent) {
      if (found != null) return;
      final global = parent.multiplied(nodeLocal(node));
      if (node.name == bone) {
        found = global;
        return;
      }
      for (final child in node.children) {
        walk(child, global);
      }
    }

    for (final root in mesh.rootNodes) {
      walk(root, Matrix4.identity());
    }
    return found;
  }

  /// A node's local `T · R · S`; a degenerate quaternion is the identity
  /// (as in the skeleton painter).
  static Matrix4 nodeLocal(GlbNode node) {
    final t = node.translation;
    final r = node.rotation;
    final s = node.scale;
    var rotation = Quaternion.identity();
    if (r != null && r.length >= 4) {
      final q = Quaternion(r[0], r[1], r[2], r[3]);
      if (q.length.isFinite && q.length > 1e-12) rotation = q.normalized();
    }
    return Matrix4.compose(
      Vector3(
        t != null && t.isNotEmpty ? t[0] : 0.0,
        t != null && t.length > 1 ? t[1] : 0.0,
        t != null && t.length > 2 ? t[2] : 0.0,
      ),
      rotation,
      Vector3(
        s != null && s.isNotEmpty ? s[0] : 1.0,
        s != null && s.length > 1 ? s[1] : 1.0,
        s != null && s.length > 2 ? s[2] : 1.0,
      ),
    );
  }

  /// `entityWorld × G_bone × offset` for [socket] on [mesh] at rest; the
  /// entity sits at the origin in the preview. Null when the bone is missing.
  static Matrix4? worldTransform(GlbMeshData mesh, SkeletalMeshSocket socket, {Matrix4? entityWorld}) {
    final bone = boneGlobal(mesh, socket.parentBone);
    if (bone == null) return null;
    return (entityWorld ?? Matrix4.identity()).multiplied(bone).multiplied(localOffset(socket));
  }
}
