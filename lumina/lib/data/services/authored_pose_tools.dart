import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../models/lumina_asset.dart';
import 'authored_animation_clip.dart';

Quaternion _rotationOf(Matrix4 m) {
  final t = Vector3.zero();
  final r = Quaternion.identity();
  final s = Vector3.zero();
  m.decompose(t, r, s);
  return r..normalize();
}

/// The shortest rotation turning direction [from] into direction [to].
Quaternion _fromTo(Vector3 from, Vector3 to) {
  final a = from.normalized();
  final b = to.normalized();
  final d = a.dot(b).clamp(-1.0, 1.0);
  if (d > 1 - 1e-12) return Quaternion.identity();
  if (d < -1 + 1e-12) {
    // Half a turn about any axis perpendicular to [a].
    var axis = a.cross(Vector3(1, 0, 0));
    if (axis.length2 < 1e-12) axis = a.cross(Vector3(0, 1, 0));
    return Quaternion.axisAngle(axis.normalized(), math.pi);
  }
  return Quaternion.axisAngle(a.cross(b).normalized(), math.acos(d));
}

/// Left / right bone pairs of a skeleton and the sagittal plane they mirror
/// across, detected from the rest pose: the plane's normal is the mean
/// right-to-left direction of the paired bones, its point their mean
/// midpoint (model space, the GLB frame).
class SkeletonMirror {
  final GlbSkeleton skeleton;

  /// Bone name → its mirror partner, both ways.
  final Map<String, String> pairs;

  /// The plane's unit normal (across the body).
  final Vector3 lateralAxis;

  /// A point on the plane.
  final Vector3 planePoint;

  SkeletonMirror._(this.skeleton, this.pairs, this.lateralAxis, this.planePoint);

  static const List<(String, String)> _suffixes = [('_l', '_r'), ('_L', '_R'), ('.l', '.r'), ('.L', '.R')];
  static const List<(String, String)> _prefixes = [('l_', 'r_'), ('L_', 'R_')];
  static const List<(String, String)> _words = [('Left', 'Right'), ('left', 'right'), ('LEFT', 'RIGHT')];

  /// The name [name] has on the other side by the usual conventions
  /// (`_l`/`_r`, `.L`/`.R`, `l_`/`r_`, `Left`/`Right`), or null for a name
  /// with no side.
  static String? mirroredName(String name) {
    for (final (l, r) in _suffixes) {
      if (name.endsWith(l)) return '${name.substring(0, name.length - l.length)}$r';
      if (name.endsWith(r)) return '${name.substring(0, name.length - r.length)}$l';
    }
    for (final (l, r) in _prefixes) {
      if (name.startsWith(l)) return '$r${name.substring(l.length)}';
      if (name.startsWith(r)) return '$l${name.substring(r.length)}';
    }
    for (final (l, r) in _words) {
      if (name.contains(l)) return name.replaceFirst(l, r);
      if (name.contains(r)) return name.replaceFirst(r, l);
    }
    return null;
  }

  /// The mirror table of [skeleton]: pairs by name (only where both bones
  /// exist), with [overrides] (either direction) taking precedence.
  factory SkeletonMirror.of(GlbSkeleton skeleton, {Map<String, String> overrides = const {}}) {
    final names = {for (final n in skeleton.names) ?n};
    final pairs = <String, String>{};
    for (final n in names) {
      final m = mirroredName(n);
      if (m != null && m != n && names.contains(m)) pairs[n] = m;
    }
    overrides.forEach((a, b) {
      if (!names.contains(a) || !names.contains(b)) return;
      for (final old in [pairs[a], pairs[b]]) {
        if (old != null) pairs.remove(old);
      }
      pairs[a] = b;
      pairs[b] = a;
    });

    final world = skeleton.worldMatrices();
    final sum = Vector3.zero();
    final mid = Vector3.zero();
    var count = 0;
    final seen = <String>{};
    for (final e in pairs.entries) {
      if (!seen.add(e.key) || !seen.add(e.value)) continue;
      final a = world[skeleton.indexOf(e.key)].getTranslation();
      final b = world[skeleton.indexOf(e.value)].getTranslation();
      var d = a - b;
      if (d.length2 < 1e-14) continue;
      if (sum.length2 > 0 && d.dot(sum) < 0) d = -d;
      sum.add(d);
      mid.add((a + b) * 0.5);
      count++;
    }
    final axis = sum.length2 > 1e-14 ? sum.normalized() : Vector3(1, 0, 0);
    return SkeletonMirror._(skeleton, pairs, axis, count == 0 ? Vector3.zero() : mid / count.toDouble());
  }

  /// [bone]'s partner, or [bone] itself for a bone on the plane.
  String partnerOf(String bone) => pairs[bone] ?? bone;

  /// [v] (a direction or offset) reflected across the plane.
  Vector3 mirrorVector(Vector3 v) => v - lateralAxis * (2 * v.dot(lateralAxis));

  /// [p] (a position) reflected across the plane.
  Vector3 mirrorPoint(Vector3 p) => planePoint + mirrorVector(p - planePoint);

  /// A world-space rotation seen in the mirror: `S · R · S` for the
  /// reflection `S`, which turns about the mirrored axis the other way.
  Quaternion mirrorRotation(Quaternion q) {
    final v = mirrorVector(Vector3(q.x, q.y, q.z));
    return Quaternion(-v.x, -v.y, -v.z, q.w)..normalize();
  }

  /// The local transforms that put the mirror image of [bones] as posed in
  /// [source] onto their partners (a bone on the plane onto itself), over the
  /// pose [target]: each partner turns from its rest pose as its source bone
  /// turned, mirrored, in world space; a translated source moves its partner
  /// by the mirrored offset; scale is copied. Parents are solved before their
  /// children, so a mirrored arm stays an arm. Returns the changed nodes.
  Map<int, BoneTrs> mirror({
    required Map<int, BoneTrs> source,
    required Map<int, BoneTrs> target,
    required Iterable<String> bones,
  }) {
    final s = skeleton;
    final restWorld = s.worldMatrices();
    final sourceWorld = s.worldMatrices(source);
    final into = <int, int>{}; // target node → source node
    for (final b in bones) {
      final from = s.indexOf(b);
      final to = s.indexOf(partnerOf(b));
      if (from >= 0 && to >= 0) into[to] = from;
    }
    final result = <int, BoneTrs>{};
    final pose = {for (final e in target.entries) e.key: e.value};
    final world = List<Matrix4>.filled(s.count, Matrix4.identity());
    for (final node in s.order) {
      final parent = s.parent[node];
      final parentWorld = parent < 0 ? Matrix4.identity() : world[parent];
      final from = into[node];
      if (from != null) {
        final base = pose[node] ?? s.rest(node);
        final src = source[from] ?? s.rest(from);
        final srcRest = s.rest(from);
        // Rotation: the source's world turn from rest, mirrored.
        final delta = _rotationOf(sourceWorld[from]) * _rotationOf(restWorld[from]).conjugated();
        final wanted = mirrorRotation(delta) * _rotationOf(restWorld[node]);
        final local = _rotationOf(parentWorld).conjugated() * wanted;
        // Translation: a moved source moves the partner by the mirrored offset.
        var t = base.t;
        if ((src.t - srcRest.t).length > 1e-9) {
          final offset = sourceWorld[from].getTranslation() - restWorld[from].getTranslation();
          final at = restWorld[node].getTranslation() + mirrorVector(offset);
          t = Matrix4.inverted(parentWorld).transformed3(at);
        }
        final out = BoneTrs(t, local..normalize(), src.s);
        result[node] = out;
        pose[node] = out;
      }
      world[node] = parentWorld * (pose[node] ?? s.rest(node)).toMatrix();
    }
    return result;
  }
}

/// Upper bone, lower bone and end effector of a limb (shoulder–elbow–hand,
/// hip–knee–foot), by node index, named after the chain (`LeftArm`, …).
class TwoBoneIkChain {
  final String name;
  final int upper;
  final int lower;
  final int end;

  const TwoBoneIkChain(this.name, this.upper, this.lower, this.end);

  static final RegExp _limb = RegExp(
    r'^(?:(?:[A-Za-z0-9]+:)?(Left|Right)(Hand|Foot)|(hand|foot)[_.](l|r)|(l|r)[_.](hand|foot))$',
    caseSensitive: false,
  );

  /// The arm and leg chains of a humanoid skeleton: an end effector named
  /// like a hand or foot with a side (`hand_l`, `LeftFoot`, `foot.R`, …) whose
  /// parent and grandparent are joints.
  static List<TwoBoneIkChain> detect(GlbSkeleton skeleton) {
    final out = <String, TwoBoneIkChain>{};
    for (final end in skeleton.joints) {
      final name = skeleton.names[end];
      if (name == null) continue;
      final m = _limb.firstMatch(name);
      if (m == null) continue;
      final side = (m.group(1) ?? m.group(4) ?? m.group(5))!.toLowerCase().startsWith('l') ? 'Left' : 'Right';
      final kind = (m.group(2) ?? m.group(3) ?? m.group(6))!.toLowerCase() == 'hand' ? 'Arm' : 'Leg';
      final lower = skeleton.parent[end];
      final upper = lower < 0 ? -1 : skeleton.parent[lower];
      if (upper < 0 || !skeleton.isJoint(lower) || !skeleton.isJoint(upper)) continue;
      out.putIfAbsent('$side$kind', () => TwoBoneIkChain('$side$kind', upper, lower, end));
    }
    const order = ['LeftArm', 'RightArm', 'LeftLeg', 'RightLeg'];
    return [for (final n in order) ?out[n]];
  }
}

/// Two-bone inverse kinematics for posing: the law of cosines places the
/// middle joint in the plane of the target and a pole, and the result is
/// plain local rotations (the clip stays forward kinematics).
abstract final class TwoBoneIkSolver {
  /// The local transforms of [chain]'s bones that put its end effector at
  /// [target] (model space, the GLB frame), clamped to the chain's reach,
  /// with the middle joint bending towards [pole] (the current bend when
  /// null). Only rotations change; [keepEndRotation] keeps the end
  /// effector's world orientation (a planted foot stays flat).
  static Map<int, BoneTrs> solve({
    required GlbSkeleton skeleton,
    required Map<int, BoneTrs> pose,
    required TwoBoneIkChain chain,
    required Vector3 target,
    Vector3? pole,
    bool keepEndRotation = true,
  }) {
    BoneTrs local(int n) => pose[n] ?? skeleton.rest(n);
    final world = skeleton.worldMatrices(pose);
    final a = world[chain.upper].getTranslation();
    final b = world[chain.lower].getTranslation();
    final c = world[chain.end].getTranslation();
    final upperLen = (b - a).length;
    final lowerLen = (c - b).length;
    final toTarget = target - a;
    if (toTarget.length < 1e-9 || upperLen < 1e-9 || lowerLen < 1e-9) return const {};
    final dir = toTarget.normalized();
    final reach = toTarget.length.clamp((upperLen - lowerLen).abs() + 1e-6, (upperLen + lowerLen) * (1 - 1e-6));

    // The bend direction: towards the pole, else the chain's current bend,
    // else any direction across the target line.
    Vector3 across(Vector3 v) => v - dir * v.dot(dir);
    var bend = pole != null ? across(pole - a) : Vector3.zero();
    if (bend.length2 < 1e-12) bend = across(b - a);
    if (bend.length2 < 1e-12) {
      bend = dir.cross(Vector3(0, 1, 0));
      if (bend.length2 < 1e-12) bend = dir.cross(Vector3(1, 0, 0));
    }
    bend.normalize();

    final cosA = ((upperLen * upperLen + reach * reach - lowerLen * lowerLen) / (2 * upperLen * reach)).clamp(-1.0, 1.0);
    final sinA = math.sqrt(1 - cosA * cosA);
    final elbow = a + dir * (upperLen * cosA) + bend * (upperLen * sinA);
    final end = a + dir * reach;

    final turnUpper = _fromTo(b - a, elbow - a);
    // (Quaternion.rotated turns by the conjugate; the matrix turns by q.)
    final movedEnd = a + turnUpper.asRotationMatrix().transformed(c - a);
    final turnLower = _fromTo(movedEnd - elbow, end - elbow);

    final parent = skeleton.parent[chain.upper];
    final parentRot = parent < 0 ? Quaternion.identity() : _rotationOf(world[parent]);
    final upperWorld = turnUpper * _rotationOf(world[chain.upper]);
    final lowerWorld = turnLower * turnUpper * _rotationOf(world[chain.lower]);
    final out = <int, BoneTrs>{
      chain.upper: BoneTrs(local(chain.upper).t, (parentRot.conjugated() * upperWorld)..normalize(), local(chain.upper).s),
      chain.lower: BoneTrs(local(chain.lower).t, (upperWorld.conjugated() * lowerWorld)..normalize(), local(chain.lower).s),
    };
    if (keepEndRotation) {
      final endWorld = _rotationOf(world[chain.end]);
      out[chain.end] = BoneTrs(local(chain.end).t, (lowerWorld.conjugated() * endWorld)..normalize(), local(chain.end).s);
    }
    return out;
  }
}

/// Root motion authoring on a clip: the skeleton root carries the
/// character's travel over the ground, the pelvis the body's motion on top of
/// it. Up is the glTF +Y axis.
abstract final class RootMotionAuthoring {
  static final Vector3 _up = Vector3(0, 1, 0);

  static Vector3 _horizontal(Vector3 v) => v - _up * v.dot(_up);

  /// Moves the pelvis's horizontal travel onto the skeleton root: at every
  /// frame with a root or pelvis translation key, the root is keyed at its
  /// position plus the pelvis's horizontal travel since the first of them,
  /// and the pelvis keeps only its vertical motion over it. The pelvis's
  /// world path does not change. False when the pelvis has no translation
  /// keys.
  static bool extractFromPelvis(AuthoredAnimationClip clip, GlbSkeleton skeleton) {
    final root = skeleton.root;
    final pelvis = skeleton.rootChild;
    if (root == null || pelvis == null) return false;
    final pelvisName = skeleton.names[pelvis]!;
    final rootName = skeleton.names[root]!;
    final pelvisCh = clip.channel(pelvisName, AuthoredChannel.translation);
    if (pelvisCh == null || pelvisCh.keys.isEmpty) return false;
    final frames = <int>{...pelvisCh.keys.keys, ...?clip.channel(rootName, AuthoredChannel.translation)?.keys.keys}.toList()
      ..sort();
    Vector3? start;
    final edits = <int, (List<double>, List<double>)>{};
    for (final f in frames) {
      final pose = clip.samplePose(skeleton, f / clip.frameRate);
      final world = skeleton.worldMatrices(pose);
      final p = world[pelvis].getTranslation();
      start ??= p;
      final travel = _horizontal(p - start);
      final rootParent = skeleton.parent[root];
      final parentWorld = rootParent < 0 ? Matrix4.identity() : world[rootParent];
      final rootAt = world[root].getTranslation() + travel;
      final rootLocal = pose[root]!;
      final rootT = Matrix4.inverted(parentWorld).transformed3(rootAt);
      final newRootWorld = parentWorld * Matrix4.compose(rootT, rootLocal.r, rootLocal.s);
      final pelvisParent = skeleton.parent[pelvis];
      // The pelvis's parent is the root, or a node under it.
      Matrix4 pelvisParentWorld = newRootWorld;
      if (pelvisParent != root) {
        final chain = <int>[];
        for (var n = pelvisParent; n >= 0 && n != root; n = skeleton.parent[n]) {
          chain.insert(0, n);
        }
        for (final n in chain) {
          pelvisParentWorld = pelvisParentWorld * pose[n]!.toMatrix();
        }
      }
      final pelvisT = Matrix4.inverted(pelvisParentWorld).transformed3(p);
      edits[f] = ([rootT.x, rootT.y, rootT.z], [pelvisT.x, pelvisT.y, pelvisT.z]);
    }
    final interpolation = pelvisCh.interpolation;
    for (final e in edits.entries) {
      clip.setKey(rootName, AuthoredChannel.translation, e.key, e.value.$1, interpolation: interpolation);
      clip.setKey(pelvisName, AuthoredChannel.translation, e.key, e.value.$2);
    }
    clip.channel(rootName, AuthoredChannel.translation)!.interpolation = interpolation;
    return true;
  }

  /// Puts the root's travel back into the pelvis: the root's translation
  /// returns to its rest value (one key at frame 0) and, at every frame that
  /// had a root or pelvis translation key, the pelvis is keyed where it was
  /// in the world. False when the root has no translation keys.
  static bool zeroRoot(AuthoredAnimationClip clip, GlbSkeleton skeleton) {
    final root = skeleton.root;
    final pelvis = skeleton.rootChild;
    if (root == null || pelvis == null) return false;
    final rootName = skeleton.names[root]!;
    final pelvisName = skeleton.names[pelvis]!;
    final rootCh = clip.channel(rootName, AuthoredChannel.translation);
    if (rootCh == null || rootCh.keys.isEmpty) return false;
    final frames = <int>{...rootCh.keys.keys, ...?clip.channel(pelvisName, AuthoredChannel.translation)?.keys.keys}.toList()
      ..sort();
    final rest = skeleton.rest(root);
    final edits = <int, List<double>>{};
    for (final f in frames) {
      final pose = clip.samplePose(skeleton, f / clip.frameRate);
      final world = skeleton.worldMatrices(pose);
      final p = world[pelvis].getTranslation();
      final rootParent = skeleton.parent[root];
      final parentWorld = rootParent < 0 ? Matrix4.identity() : world[rootParent];
      final rootLocal = pose[root]!;
      var pelvisParentWorld = parentWorld * Matrix4.compose(rest.t, rootLocal.r, rootLocal.s);
      final chain = <int>[];
      for (var n = skeleton.parent[pelvis]; n >= 0 && n != root; n = skeleton.parent[n]) {
        chain.insert(0, n);
      }
      for (final n in chain) {
        pelvisParentWorld = pelvisParentWorld * pose[n]!.toMatrix();
      }
      final t = Matrix4.inverted(pelvisParentWorld).transformed3(p);
      edits[f] = [t.x, t.y, t.z];
    }
    clip.tracks[rootName]!.remove(AuthoredChannel.translation);
    clip.setKey(rootName, AuthoredChannel.translation, 0, rest.channel(AuthoredChannel.translation));
    edits.forEach((f, v) => clip.setKey(pelvisName, AuthoredChannel.translation, f, v));
    return true;
  }
}

/// A named pose: local transforms by bone name.
class AuthoredPose {
  final String name;
  final Map<String, BoneTrs> bones;

  AuthoredPose(this.name, Map<String, BoneTrs> bones) : bones = {for (final e in bones.entries) e.key: e.value.copy()};

  AuthoredPose renamed(String to) => AuthoredPose(to, bones);

  Map<String, dynamic> toJson() => {
        'name': name,
        'bones': {for (final e in bones.entries) e.key: e.value.toList()},
      };

  factory AuthoredPose.fromJson(Map<String, dynamic> json) => AuthoredPose(
        json['name'] as String,
        {
          for (final e in ((json['bones'] as Map?) ?? const {}).entries)
            e.key as String: BoneTrs.fromList([for (final v in e.value as List) (v as num).toDouble()]),
        },
      );
}

/// The poses saved for one skeletal mesh, with the mirror pairs its user set
/// by hand.
class AuthoredPoseLibrary {
  final String meshRelPath;
  final List<AuthoredPose> poses;
  final Map<String, String> mirrorOverrides;

  AuthoredPoseLibrary({required this.meshRelPath, List<AuthoredPose>? poses, Map<String, String>? mirrorOverrides})
      : poses = poses ?? [],
        mirrorOverrides = {...?mirrorOverrides};

  AuthoredPoseLibrary copy() => AuthoredPoseLibrary(
        meshRelPath: meshRelPath,
        poses: [for (final p in poses) AuthoredPose(p.name, p.bones)],
        mirrorOverrides: mirrorOverrides,
      );

  AuthoredPose? pose(String name) {
    for (final p in poses) {
      if (p.name == name) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'mesh': meshRelPath,
        'poses': [for (final p in poses) p.toJson()],
        'mirror_overrides': mirrorOverrides,
      };

  factory AuthoredPoseLibrary.fromJson(Map<String, dynamic> json, {String? meshRelPath}) => AuthoredPoseLibrary(
        meshRelPath: meshRelPath ?? json['mesh'] as String? ?? '',
        poses: [
          for (final p in (json['poses'] as List?) ?? const []) AuthoredPose.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        mirrorOverrides: {
          for (final e in ((json['mirror_overrides'] as Map?) ?? const {}).entries) e.key as String: e.value as String,
        },
      );
}

/// Pose libraries in a project: `contents/animations/<Mesh>/PoseLibrary.lmas`
/// next to the mesh's authored clips, the library as JSON in its payload.
abstract final class AuthoredPoseLibraryStore {
  static const String marker = 'pose_library';

  /// The library's project-relative path for the skeletal mesh at
  /// [meshRelPath].
  static String pathFor(String meshRelPath) {
    final base = meshRelPath.split('/').last.replaceAll(RegExp(r'\.(lmas|glb)$'), '');
    return 'contents/animations/${base.isEmpty ? 'Shared' : base}/PoseLibrary.lmas';
  }

  /// True for a pose library asset.
  static bool isLibrary(LuminaAsset? asset) => asset?.metadata[marker] == 'true';

  /// The mesh's library (empty when it has none yet).
  static AuthoredPoseLibrary load(String projectDir, String meshRelPath) {
    final file = File('$projectDir/${pathFor(meshRelPath)}');
    if (!file.existsSync()) return AuthoredPoseLibrary(meshRelPath: meshRelPath);
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null || payload.isEmpty) return AuthoredPoseLibrary(meshRelPath: meshRelPath);
      return AuthoredPoseLibrary.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map),
          meshRelPath: meshRelPath);
    } catch (_) {
      return AuthoredPoseLibrary(meshRelPath: meshRelPath);
    }
  }

  /// Writes [library]; returns its project-relative path.
  static String save(String projectDir, AuthoredPoseLibrary library) {
    final rel = pathFor(library.meshRelPath);
    final file = File('$projectDir/$rel');
    String? id;
    if (file.existsSync()) {
      try {
        id = LuminaAsset.fromBytes(file.readAsBytesSync()).assetId;
      } catch (_) {}
    }
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(LuminaAsset(
      assetId: id ?? 'pose-library-${DateTime.now().microsecondsSinceEpoch}',
      name: 'PoseLibrary',
      type: AssetType.unknown,
      rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(library.toJson()))),
      metadata: {
        marker: 'true',
        'source_mesh': library.meshRelPath,
        'pose_count': '${library.poses.length}',
      },
    ).toProtoBufferBytes());
    return rel;
  }
}
