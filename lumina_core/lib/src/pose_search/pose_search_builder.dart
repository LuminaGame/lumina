import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:lumina_core/src/pose_search/glb_animation_sampler.dart';
import 'package:lumina_core/src/pose_search/pose_math.dart';
import 'package:lumina_core/src/pose_search/pose_search_document.dart';
import 'package:lumina_core/src/pose_search/pose_search_index.dart';

/// The character frame of a clip at one time: the root bone projected on
/// the ground (model units) and the yaw of its forward (0 = +Z).
typedef LuminaGroundFrame = ({double x, double z, double yaw});

/// The character frame of the database's mesh: which node is the root, the
/// root's rest-pose forward in its own space, and how to sample its ground
/// frame for a clip at any time (wrapped for a loop, extrapolated for a
/// one-shot clip).
class LuminaPoseSearchRig {
  final LuminaGlbAnimationSampler sampler;
  final LuminaPoseSearchSchema schema;
  final int root;
  final List<int> rootChain;

  /// The root's rest forward in its own (rotation) space.
  final double forwardX, forwardY, forwardZ;

  LuminaPoseSearchRig._(this.sampler, this.schema, this.root, this.rootChain, this.forwardX, this.forwardY, this.forwardZ);

  factory LuminaPoseSearchRig(LuminaGlbAnimationSampler sampler, LuminaPoseSearchSchema schema) {
    var root = schema.rootBone.isEmpty ? -1 : sampler.indexOfNode(schema.rootBone);
    if (root < 0) {
      // The root bone carries the root motion; it may have no skin weights
      // (then it is not a joint), so look above the top joint for it.
      final top = sampler.topJoint ?? 0;
      root = top;
      for (var n = top; n >= 0; n = sampler.parents[n]) {
        if (sampler.nodeNames[n].toLowerCase() == 'root') {
          root = n;
          break;
        }
      }
    }
    final restWorld = sampler.restWorld();
    final q = Float64List(4);
    LuminaPoseMath.affineRotation(restWorld, root * LuminaPoseMath.affineStride, q, 0);
    // The mesh's authored forward: glTF +Z turned back by the yaw offset.
    final o = schema.meshYawOffsetDegrees * math.pi / 180.0;
    final (fx, fz) = LuminaPoseMath.rotateYaw(0, 1, -o);
    final inverse = Float64List.fromList([-q[0], -q[1], -q[2], q[3]]);
    final f = Float64List(3);
    LuminaPoseMath.rotateVector(inverse, 0, fx, 0, fz, f, 0);
    return LuminaPoseSearchRig._(sampler, schema, root, sampler.chainOf(root), f[0], f[1], f[2]);
  }

  final Float64List _affine = Float64List(LuminaPoseMath.affineStride);
  final Float64List _q = Float64List(4);
  final Float64List _v = Float64List(3);

  /// The ground frame of a world affine of the root at [ro].
  LuminaGroundFrame groundOf(Float64List world, int ro) {
    LuminaPoseMath.affineRotation(world, ro, _q, 0);
    LuminaPoseMath.rotateVector(_q, 0, forwardX, forwardY, forwardZ, _v, 0);
    final yaw = (_v[0].abs() < 1e-9 && _v[2].abs() < 1e-9) ? 0.0 : LuminaPoseMath.yawOf(_v[0], _v[2]);
    return (x: world[ro + 9], z: world[ro + 11], yaw: yaw);
  }

  /// The ground frame of [clip] at [time] inside the clip's range.
  LuminaGroundFrame groundAt(int clip, double time) {
    sampler.nodeWorld(clip, rootChain, time, _affine, 0);
    return groundOf(_affine, 0);
  }

  /// The ground frame at any [time]: a loop repeats its displacement per
  /// cycle; a one-shot clip continues at its end (start) velocity and facing.
  LuminaGroundFrame groundExtended(int clip, double time, bool loop) {
    final d = sampler.clips[clip].duration;
    if (d <= 1e-6) return groundAt(clip, 0);
    if (time >= 0 && time <= d) return groundAt(clip, time);
    if (loop) {
      final k = (time / d).floor();
      var g = groundAt(clip, time - k * d);
      final g0 = groundAt(clip, 0), g1 = groundAt(clip, d);
      final dy = g1.yaw - g0.yaw;
      for (var i = 0; i < k.abs(); i++) {
        if (k > 0) {
          final (rx, rz) = LuminaPoseMath.rotateYaw(g.x - g0.x, g.z - g0.z, dy);
          g = (x: g1.x + rx, z: g1.z + rz, yaw: g.yaw + dy);
        } else {
          final (rx, rz) = LuminaPoseMath.rotateYaw(g.x - g1.x, g.z - g1.z, -dy);
          g = (x: g0.x + rx, z: g0.z + rz, yaw: g.yaw - dy);
        }
      }
      return g;
    }
    final h = math.min(1.0 / schema.sampleRate, d);
    if (time < 0) {
      final a = groundAt(clip, 0), b = groundAt(clip, h);
      return (x: a.x + (b.x - a.x) / h * time, z: a.z + (b.z - a.z) / h * time, yaw: a.yaw);
    }
    final a = groundAt(clip, d - h), b = groundAt(clip, d);
    return (x: b.x + (b.x - a.x) / h * (time - d), z: b.z + (b.z - a.z) / h * (time - d), yaw: b.yaw);
  }
}

/// What a build found besides the index.
class LuminaPoseSearchBuildStats {
  final int clips;
  final int rows;
  final int mirroredRows;
  final int dimensions;
  final List<String> missingClips;
  final List<String> staticRootClips;
  final List<String> missingBones;
  final int buildMicroseconds;

  const LuminaPoseSearchBuildStats({
    required this.clips,
    required this.rows,
    required this.mirroredRows,
    required this.dimensions,
    required this.missingClips,
    required this.staticRootClips,
    required this.missingBones,
    required this.buildMicroseconds,
  });

  Map<String, dynamic> toJson() => {
        'clips': clips,
        'rows': rows,
        'mirroredRows': mirroredRows,
        'dimensions': dimensions,
        'missingClips': missingClips,
        'staticRootClips': staticRootClips,
        'missingBones': missingBones,
        'buildMicroseconds': buildMicroseconds,
      };

  factory LuminaPoseSearchBuildStats.fromJson(Map<String, dynamic> j) => LuminaPoseSearchBuildStats(
        clips: j['clips'] as int? ?? 0,
        rows: j['rows'] as int? ?? 0,
        mirroredRows: j['mirroredRows'] as int? ?? 0,
        dimensions: j['dimensions'] as int? ?? 0,
        missingClips: (j['missingClips'] as List? ?? const []).cast<String>(),
        staticRootClips: (j['staticRootClips'] as List? ?? const []).cast<String>(),
        missingBones: (j['missingBones'] as List? ?? const []).cast<String>(),
        buildMicroseconds: j['buildMicroseconds'] as int? ?? 0,
      );
}

/// Builds the feature matrix of a pose search database from its mesh's GLB.
abstract final class LuminaPoseSearchBuilder {
  /// The cache key of [document] over [glb]: changes when either does.
  static String fingerprint(Uint8List glb, LuminaPoseSearchDatabaseDocument document) =>
      fingerprintOfHash(glbHash(glb), document);

  /// The GLB part of [fingerprint] (hashing a large mesh once serves every
  /// database of it).
  static String glbHash(Uint8List glb) => sha1.convert(glb).toString();

  /// [fingerprint] from the mesh's [glbHash].
  static String fingerprintOfHash(String glbHash, LuminaPoseSearchDatabaseDocument document) {
    final docHash = sha1.convert(utf8.encode(jsonEncode(document.toJson())));
    return 'v${LuminaPoseSearchIndex.formatVersion}-$glbHash-$docHash';
  }

  /// [build] on a background isolate (inline where isolates are not
  /// available), returning the encoded cache and the stats.
  static Future<({Uint8List cache, LuminaPoseSearchBuildStats stats})> buildInBackground(
      Uint8List glb, LuminaPoseSearchDatabaseDocument document) async {
    final docJson = jsonEncode(document.toJson());
    ({Uint8List cache, String stats}) work() {
      final doc = LuminaPoseSearchDatabaseDocument.fromJson(jsonDecode(docJson) as Map<String, dynamic>);
      final result = buildWithStats(glb, doc);
      return (cache: result.index.encode(), stats: jsonEncode(result.stats.toJson()));
    }

    ({Uint8List cache, String stats}) r;
    try {
      r = await Isolate.run(work, debugName: 'pose search build');
    } on UnsupportedError {
      r = work();
    }
    return (
      cache: r.cache,
      stats: LuminaPoseSearchBuildStats.fromJson(jsonDecode(r.stats) as Map<String, dynamic>),
    );
  }

  static LuminaPoseSearchIndex build(Uint8List glb, LuminaPoseSearchDatabaseDocument document) =>
      buildWithStats(glb, document).index;

  static ({LuminaPoseSearchIndex index, LuminaPoseSearchBuildStats stats}) buildWithStats(
      Uint8List glb, LuminaPoseSearchDatabaseDocument document,
      {LuminaGlbAnimationSampler? sampler}) {
    final watch = Stopwatch()..start();
    final s = sampler ?? LuminaGlbAnimationSampler.fromGlb(glb);
    final schema = document.schema;
    final layout = LuminaPoseFeatureLayout(schema);
    final rig = LuminaPoseSearchRig(s, schema);
    final dims = layout.dimensions;
    final tags = document.tags;

    final boneNodes = <String, int>{};
    final missingBones = <String>[];
    for (final b in schema.bones) {
      final i = s.indexOfNode(b.name);
      if (i < 0) {
        missingBones.add(b.name);
      } else {
        boneNodes[b.name] = i;
      }
    }

    final rows = <double>[];
    final rowClip = <int>[];
    final rowTime = <double>[];
    final rowFlags = <int>[];
    final missing = <String>[];
    final staticRoot = <String>[];
    var usedClips = 0;
    final local = Float64List(s.nodeCount * LuminaPoseMath.trsStride);
    final world = Float64List(s.nodeCount * LuminaPoseMath.affineStride);
    final rootOffset = rig.root * LuminaPoseMath.affineStride;

    for (var ci = 0; ci < document.clips.length; ci++) {
      final entry = document.clips[ci];
      if (!entry.enabled) continue;
      final clip = s.clipIndex(entry.clip);
      if (clip == null) {
        missing.add(entry.clip);
        continue;
      }
      usedClips++;
      final duration = s.clips[clip].duration;
      final frames = math.max(1, (duration * schema.sampleRate).round());
      final h = duration / frames;
      // Ground frames and bone world positions on the frame grid 0..frames.
      final ground = <LuminaGroundFrame>[];
      final positions = <String, List<List<double>>>{for (final b in boneNodes.keys) b: []};
      for (var i = 0; i <= frames; i++) {
        final t = math.min(i * h, duration);
        s.sampleLocal(clip, t, local);
        s.world(local, world);
        ground.add(rig.groundOf(world, rootOffset));
        for (final e in boneNodes.entries) {
          final o = e.value * LuminaPoseMath.affineStride;
          positions[e.key]!.add([world[o + 9], world[o + 10], world[o + 11]]);
        }
      }
      final moved = math.sqrt(math.pow(ground.last.x - ground.first.x, 2) + math.pow(ground.last.z - ground.first.z, 2));
      if (moved < 1e-4 && (ground.last.yaw - ground.first.yaw).abs() < 1e-4) staticRoot.add(entry.clip);

      // A loop's frame `frames` is its frame 0 one cycle on: carry a
      // position across the seam with the cycle's ground displacement.
      final g0 = ground.first, g1 = ground.last;
      final cycleYaw = g1.yaw - g0.yaw;
      List<double> forward(List<double> p) {
        final (rx, rz) = LuminaPoseMath.rotateYaw(p[0] - g0.x, p[2] - g0.z, cycleYaw);
        return [g1.x + rx, p[1], g1.z + rz];
      }

      List<double> backward(List<double> p) {
        final (rx, rz) = LuminaPoseMath.rotateYaw(p[0] - g1.x, p[2] - g1.z, -cycleYaw);
        return [g0.x + rx, p[1], g0.z + rz];
      }

      List<double> velocity(String bone, int i) {
        final p = positions[bone]!;
        List<double> a, b;
        double span;
        if (entry.loop) {
          a = i == 0 ? backward(p[frames - 1]) : p[i - 1];
          b = i + 1 <= frames ? p[i + 1] : forward(p[1]);
          span = 2 * h;
        } else if (i == 0) {
          a = p[0];
          b = p[math.min(1, frames)];
          span = h;
        } else if (i == frames) {
          a = p[frames - 1];
          b = p[frames];
          span = h;
        } else {
          a = p[i - 1];
          b = p[i + 1];
          span = 2 * h;
        }
        return [(b[0] - a[0]) / span, (b[1] - a[1]) / span, (b[2] - a[2]) / span];
      }

      final last = entry.loop ? frames - 1 : frames;
      final clipStart = rowClip.length;
      for (var i = 0; i <= last; i++) {
        final t = math.min(i * h, duration);
        final g = ground[i];
        final row = List<double>.filled(dims, 0.0);
        for (var k = 0; k < layout.trajectorySamples; k++) {
          final f = rig.groundExtended(clip, t + schema.trajectoryTimes[k], entry.loop);
          final (dx, dz) = LuminaPoseMath.rotateYaw(f.x - g.x, f.z - g.z, -g.yaw);
          final p = layout.trajectoryPositionOffset(k);
          row[p] = dx;
          row[p + 1] = dz;
          final rel = f.yaw - g.yaw;
          final q = layout.trajectoryFacingOffset(k);
          row[q] = math.sin(rel);
          row[q + 1] = math.cos(rel);
        }
        for (final group in layout.groups) {
          final bone = group.bone;
          if (bone == null || !boneNodes.containsKey(bone)) continue;
          final v = group.kind == 'bonePosition'
              ? [positions[bone]![i][0] - g.x, positions[bone]![i][1], positions[bone]![i][2] - g.z]
              : velocity(bone, i);
          final (x, z) = LuminaPoseMath.rotateYaw(v[0], v[2], -g.yaw);
          row[group.offset] = x;
          row[group.offset + 1] = v[1];
          row[group.offset + 2] = z;
        }
        rows.addAll(row);
        rowClip.add(ci);
        rowTime.add(t);
        final inRange = t >= entry.samplingStart - 1e-6 && (entry.samplingEnd <= 0 || t <= entry.samplingEnd + 1e-6);
        final searchable = inRange &&
            (entry.loop || duration <= 2 * document.excludeEndSeconds || t <= duration - document.excludeEndSeconds);
        rowFlags.add(searchable ? LuminaPoseSearchIndex.flagSearchable : 0);
      }
      if (entry.mirror) {
        final clipEnd = rowClip.length;
        for (var r = clipStart; r < clipEnd; r++) {
          rows.addAll(mirrorRow(layout, rows, r * dims, s));
          rowClip.add(ci);
          rowTime.add(rowTime[r]);
          rowFlags.add(rowFlags[r] | LuminaPoseSearchIndex.flagMirrored);
        }
      }
    }

    final count = rowClip.length;
    final raw = Float32List.fromList(rows);
    final mean = Float32List(dims);
    final inverseScale = Float32List(dims);
    final weights = Float32List(dims);
    for (final group in layout.groups) {
      var stdSum = 0.0;
      for (var d = group.offset; d < group.offset + group.length; d++) {
        var m = 0.0;
        for (var r = 0; r < count; r++) {
          m += raw[r * dims + d];
        }
        m = count == 0 ? 0 : m / count;
        var v = 0.0;
        for (var r = 0; r < count; r++) {
          final x = raw[r * dims + d] - m;
          v += x * x;
        }
        mean[d] = m;
        stdSum += count == 0 ? 0 : math.sqrt(v / count);
      }
      final std = stdSum / group.length;
      for (var d = group.offset; d < group.offset + group.length; d++) {
        inverseScale[d] = std > 1e-8 ? 1.0 / std : 1.0;
        weights[d] = group.weight * group.weight;
      }
    }
    for (var r = 0; r < count; r++) {
      for (var d = 0; d < dims; d++) {
        raw[r * dims + d] = (raw[r * dims + d] - mean[d]) * inverseScale[d];
      }
    }
    final masks = Int32List(document.clips.length);
    for (var c = 0; c < document.clips.length; c++) {
      var m = 0;
      for (final t in document.clips[c].tags) {
        m |= 1 << tags.indexOf(t);
      }
      masks[c] = m;
    }
    final index = LuminaPoseSearchIndex(
      fingerprint: fingerprint(glb, document),
      layout: layout,
      clipNames: [for (final c in document.clips) c.clip],
      clipTagMasks: masks,
      tags: tags,
      clipCostBias: Float32List.fromList([
        for (final c in document.clips) c.costBias + (c.loop ? document.loopingCostBias : 0.0),
      ]),
      rowCount: count,
      features: raw,
      mean: mean,
      inverseScale: inverseScale,
      weights: weights,
      rowClip: Int32List.fromList(rowClip),
      rowTime: Float32List.fromList(rowTime),
      rowFlags: Uint8List.fromList(rowFlags),
    );
    watch.stop();
    return (
      index: index,
      stats: LuminaPoseSearchBuildStats(
        clips: usedClips,
        rows: count,
        mirroredRows: index.mirroredRowCount,
        dimensions: dims,
        missingClips: missing,
        staticRootClips: staticRoot,
        missingBones: missingBones,
        buildMicroseconds: watch.elapsedMicroseconds,
      ),
    );
  }

  /// The features of the row at [rows]/[o] seen in a mirror across the
  /// character's sagittal plane: lateral (X) components negated, each bone
  /// group taken from its left/right counterpart's group (itself when the
  /// counterpart is not in the schema).
  static List<double> mirrorRow(LuminaPoseFeatureLayout layout, List<double> rows, int o, LuminaGlbAnimationSampler s) {
    final out = List<double>.filled(layout.dimensions, 0.0);
    for (var k = 0; k < layout.trajectorySamples; k++) {
      final p = layout.trajectoryPositionOffset(k), q = layout.trajectoryFacingOffset(k);
      out[p] = -rows[o + p];
      out[p + 1] = rows[o + p + 1];
      out[q] = -rows[o + q];
      out[q + 1] = rows[o + q + 1];
    }
    for (final group in layout.groups) {
      final bone = group.bone;
      if (bone == null) continue;
      final node = s.indexOfNode(bone);
      final mirrorName = node < 0 ? bone : s.nodeNames[s.mirror[node]];
      final source = layout.group(group.kind, mirrorName) ?? group;
      out[group.offset] = -rows[o + source.offset];
      out[group.offset + 1] = rows[o + source.offset + 1];
      out[group.offset + 2] = rows[o + source.offset + 2];
    }
    return out;
  }
}
