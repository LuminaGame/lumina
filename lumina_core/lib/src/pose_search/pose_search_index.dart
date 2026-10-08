import 'dart:convert';
import 'dart:typed_data';

import 'package:lumina_core/src/pose_search/pose_search_document.dart';

/// A group of feature dimensions normalized together (one std for the
/// group) and weighted as one.
class LuminaPoseFeatureGroup {
  final String name;
  final int offset;
  final int length;

  /// `trajectoryPosition`, `trajectoryFacing`, `bonePosition`, `boneVelocity`.
  final String kind;

  /// The schema weight of the group.
  final double weight;

  /// The bone of a bone group, else null.
  final String? bone;

  const LuminaPoseFeatureGroup(this.name, this.offset, this.length, this.kind, this.weight, {this.bone});

  bool get isTrajectory => kind.startsWith('trajectory');
}

/// Where each feature of a schema sits in a row: per trajectory sample a
/// ground position (x, z) then per sample a facing direction (x, z), then
/// per bone its position (x, y, z) and / or velocity (x, y, z).
class LuminaPoseFeatureLayout {
  final LuminaPoseSearchSchema schema;
  final List<LuminaPoseFeatureGroup> groups;
  final int dimensions;

  LuminaPoseFeatureLayout._(this.schema, this.groups, this.dimensions);

  factory LuminaPoseFeatureLayout(LuminaPoseSearchSchema schema) {
    final groups = <LuminaPoseFeatureGroup>[];
    var offset = 0;
    final samples = schema.trajectoryTimes.length;
    if (samples > 0) {
      groups.add(LuminaPoseFeatureGroup('trajectory position', offset, samples * 2, 'trajectoryPosition',
          schema.trajectoryPositionWeight));
      offset += samples * 2;
      groups.add(LuminaPoseFeatureGroup('trajectory facing', offset, samples * 2, 'trajectoryFacing',
          schema.trajectoryFacingWeight));
      offset += samples * 2;
    }
    for (final b in schema.bones) {
      if (b.position > 0) {
        groups.add(LuminaPoseFeatureGroup('${b.name} position', offset, 3, 'bonePosition', b.position, bone: b.name));
        offset += 3;
      }
      if (b.velocity > 0) {
        groups.add(LuminaPoseFeatureGroup('${b.name} velocity', offset, 3, 'boneVelocity', b.velocity, bone: b.name));
        offset += 3;
      }
    }
    return LuminaPoseFeatureLayout._(schema, groups, offset);
  }

  int get trajectorySamples => schema.trajectoryTimes.length;

  /// Offset of trajectory sample [k]'s position (x, z).
  int trajectoryPositionOffset(int k) => k * 2;

  /// Offset of trajectory sample [k]'s facing (x, z).
  int trajectoryFacingOffset(int k) => trajectorySamples * 2 + k * 2;

  /// The dimensions of the trajectory groups (the rest are pose features).
  int get trajectoryDimensions => trajectorySamples * 4;

  LuminaPoseFeatureGroup? group(String kind, String bone) =>
      groups.where((g) => g.kind == kind && g.bone == bone).firstOrNull;
}

/// What a search found: the row and its cost (−1 / infinity when nothing
/// beat the given bound).
typedef LuminaPoseSearchResult = ({int row, double cost});

/// The searchable feature matrix of a pose search database: one row per
/// sampled clip frame (clip, time, mirrored), features normalized per group
/// (`(x − mean) / groupStd`), searched by weighted squared distance with
/// 16-row bounding boxes and per-row early-out.
class LuminaPoseSearchIndex {
  static const int _magic = 0x4C505344; // "LPSD"
  static const int formatVersion = 2;
  static const int blockSize = 16;

  /// Row flag: the row is a mirrored copy of its clip frame.
  static const int flagMirrored = 1;

  /// Row flag: the row may be jumped to.
  static const int flagSearchable = 2;

  final String fingerprint;
  final LuminaPoseFeatureLayout layout;

  /// Database clip names, in document order (rows refer to them by index).
  final List<String> clipNames;

  /// Bit mask of tags per database clip (bit i = [tags] i).
  final Int32List clipTagMasks;
  final List<String> tags;

  /// Cost added to every frame of a database clip (its bias, plus the
  /// looping bias for a loop).
  final Float32List clipCostBias;

  final int rowCount;
  final Float32List features;
  final Float32List mean;

  /// `1 / groupStd` per dimension.
  final Float32List inverseScale;

  /// Schema weight² per dimension.
  final Float32List weights;
  final Int32List rowClip;
  final Float32List rowTime;
  final Uint8List rowFlags;

  late final Int32List _blockStart;
  late final Int32List _blockEnd;
  late final Float32List _blockMin;
  late final Float32List _blockMax;

  LuminaPoseSearchIndex({
    required this.fingerprint,
    required this.layout,
    required this.clipNames,
    required this.clipTagMasks,
    required this.tags,
    required this.clipCostBias,
    required this.rowCount,
    required this.features,
    required this.mean,
    required this.inverseScale,
    required this.weights,
    required this.rowClip,
    required this.rowTime,
    required this.rowFlags,
  }) {
    _buildBlocks();
  }

  int get dimensions => layout.dimensions;

  bool isMirrored(int row) => rowFlags[row] & flagMirrored != 0;

  bool isSearchable(int row) => rowFlags[row] & flagSearchable != 0;

  int get mirroredRowCount {
    var n = 0;
    for (var r = 0; r < rowCount; r++) {
      if (isMirrored(r)) n++;
    }
    return n;
  }

  /// Bytes of the encoded cache.
  int get byteSize => features.lengthInBytes + rowClip.lengthInBytes + rowTime.lengthInBytes + rowFlags.lengthInBytes;

  /// The tag mask of [names] (unknown tags give −1: nothing can match).
  int tagMask(Iterable<String> names) {
    var mask = 0;
    for (final n in names) {
      final i = tags.indexOf(n);
      if (i < 0) return -1;
      mask |= 1 << i;
    }
    return mask;
  }

  /// [raw] (unnormalized features of one row) normalized in place.
  void normalize(Float32List raw) {
    for (var d = 0; d < dimensions; d++) {
      raw[d] = (raw[d] - mean[d]) * inverseScale[d];
    }
  }

  /// Normalized feature [d] of [row].
  double feature(int row, int d) => features[row * dimensions + d];

  /// The unnormalized value of feature [d] of [row].
  double rawFeature(int row, int d) => features[row * dimensions + d] / inverseScale[d] + mean[d];

  /// The row whose clip, mirror flag and time are nearest [time] (−1 when the
  /// clip has no rows).
  int rowAt(int clip, double time, bool mirrored) {
    var best = -1;
    var bestDt = double.infinity;
    for (var r = 0; r < rowCount; r++) {
      if (rowClip[r] != clip || isMirrored(r) != mirrored) continue;
      final dt = (rowTime[r] - time).abs();
      if (dt < bestDt) {
        bestDt = dt;
        best = r;
      } else if (best >= 0 && rowTime[r] > time) {
        break;
      }
    }
    return best;
  }

  /// Weighted squared distance of [query] to [row].
  double cost(Float32List query, int row, [Float32List? weights]) {
    final w = weights ?? this.weights;
    var c = clipCostBias[rowClip[row]].toDouble();
    final o = row * dimensions;
    for (var d = 0; d < dimensions; d++) {
      final diff = query[d] - features[o + d];
      c += w[d] * diff * diff;
    }
    return c;
  }

  /// The searchable row with the least cost below [bound], skipping
  /// [excludeRow] and rows whose clip lacks the [requiredTags] mask; [weights]
  /// (per dimension, squared) default to the schema's. Uses the 16-row
  /// boxes as a lower bound unless [bruteForce].
  LuminaPoseSearchResult search(
    Float32List query, {
    Float32List? weights,
    int requiredTags = 0,
    int excludeRow = -1,
    double bound = double.infinity,
    bool bruteForce = false,
  }) {
    final w = weights ?? this.weights;
    if (requiredTags < 0) return (row: -1, cost: double.infinity);
    var best = bound;
    var bestRow = -1;
    final dims = dimensions;
    for (var b = 0; b < _blockStart.length; b++) {
      final start = _blockStart[b];
      final clip = rowClip[start];
      if (requiredTags != 0 && (clipTagMasks[clip] & requiredTags) != requiredTags) continue;
      final bias = clipCostBias[clip].toDouble();
      if (!bruteForce) {
        var lower = bias;
        final bo = b * dims;
        for (var d = 0; d < dims; d++) {
          final q = query[d];
          final lo = _blockMin[bo + d], hi = _blockMax[bo + d];
          final diff = q < lo ? lo - q : (q > hi ? q - hi : 0.0);
          lower += w[d] * diff * diff;
          if (lower >= best) break;
        }
        if (lower >= best) continue;
      }
      final end = _blockEnd[b];
      for (var r = start; r < end; r++) {
        if (rowFlags[r] & flagSearchable == 0 || r == excludeRow) continue;
        var c = bias;
        final o = r * dims;
        for (var d = 0; d < dims; d++) {
          final diff = query[d] - features[o + d];
          c += w[d] * diff * diff;
          if (c >= best) break;
        }
        if (c < best) {
          best = c;
          bestRow = r;
        }
      }
    }
    return (row: bestRow, cost: bestRow < 0 ? double.infinity : best);
  }

  void _buildBlocks() {
    final starts = <int>[];
    final ends = <int>[];
    var r = 0;
    while (r < rowCount) {
      final start = r;
      final clip = rowClip[r];
      final mirrored = rowFlags[r] & flagMirrored;
      while (r < rowCount && r - start < blockSize && rowClip[r] == clip && (rowFlags[r] & flagMirrored) == mirrored) {
        r++;
      }
      starts.add(start);
      ends.add(r);
    }
    _blockStart = Int32List.fromList(starts);
    _blockEnd = Int32List.fromList(ends);
    final dims = dimensions;
    _blockMin = Float32List(starts.length * dims);
    _blockMax = Float32List(starts.length * dims);
    for (var b = 0; b < starts.length; b++) {
      for (var d = 0; d < dims; d++) {
        var lo = double.infinity, hi = -double.infinity;
        for (var row = starts[b]; row < ends[b]; row++) {
          final v = features[row * dims + d];
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        _blockMin[b * dims + d] = lo;
        _blockMax[b * dims + d] = hi;
      }
    }
  }

  /// The cache file's bytes: a header with the [fingerprint] and the
  /// schema, then the matrices.
  Uint8List encode() {
    final header = utf8.encode(jsonEncode({
      'fingerprint': fingerprint,
      'schema': layout.schema.toJson(),
      'clips': clipNames,
      'tags': tags,
      'rows': rowCount,
      'dimensions': dimensions,
    }));
    final dims = dimensions;
    int pad(int n) => (n + 3) & ~3;
    final headerLen = pad(header.length);
    final size = 12 +
        headerLen +
        clipTagMasks.length * 4 * 2 +
        dims * 4 * 3 +
        rowCount * dims * 4 +
        rowCount * 4 * 2 +
        pad(rowCount);
    final out = Uint8List(size);
    final data = ByteData.sublistView(out);
    data.setUint32(0, _magic, Endian.little);
    data.setUint32(4, formatVersion, Endian.little);
    data.setUint32(8, header.length, Endian.little);
    out.setRange(12, 12 + header.length, header);
    var o = 12 + headerLen;
    void put(TypedData list) {
      final bytes = list.buffer.asUint8List(list.offsetInBytes, list.lengthInBytes);
      out.setRange(o, o + bytes.length, bytes);
      o += pad(bytes.length);
    }

    put(clipTagMasks);
    put(clipCostBias);
    put(mean);
    put(inverseScale);
    put(weights);
    put(features);
    put(rowClip);
    put(rowTime);
    put(rowFlags);
    return out;
  }

  /// The fingerprint stored in cache [bytes], or null when they are not a
  /// cache of this format version.
  static String? fingerprintOf(Uint8List bytes) {
    try {
      final data = ByteData.sublistView(bytes);
      if (bytes.length < 12 || data.getUint32(0, Endian.little) != _magic) return null;
      if (data.getUint32(4, Endian.little) != formatVersion) return null;
      final len = data.getUint32(8, Endian.little);
      final header = jsonDecode(utf8.decode(bytes.sublist(12, 12 + len))) as Map;
      return header['fingerprint'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Reads a cache written by [encode]; throws [FormatException] for anything
  /// else.
  factory LuminaPoseSearchIndex.decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12 || data.getUint32(0, Endian.little) != _magic) {
      throw const FormatException('not a pose search database cache');
    }
    final version = data.getUint32(4, Endian.little);
    if (version != formatVersion) throw FormatException('pose search cache version $version, expected $formatVersion');
    final len = data.getUint32(8, Endian.little);
    final header = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes.sublist(12, 12 + len))) as Map);
    final schema = LuminaPoseSearchSchema.fromJson(Map<String, dynamic>.from(header['schema'] as Map));
    final layout = LuminaPoseFeatureLayout(schema);
    final clips = (header['clips'] as List).cast<String>();
    final rows = header['rows'] as int;
    final dims = layout.dimensions;
    int pad(int n) => (n + 3) & ~3;
    var o = 12 + pad(len);
    Uint8List take(int n) {
      final copy = Uint8List.fromList(bytes.sublist(o, o + n));
      o += pad(n);
      return copy;
    }

    final masks = take(clips.length * 4).buffer.asInt32List();
    final biases = take(clips.length * 4).buffer.asFloat32List();
    final mean = take(dims * 4).buffer.asFloat32List();
    final inverseScale = take(dims * 4).buffer.asFloat32List();
    final weights = take(dims * 4).buffer.asFloat32List();
    final features = take(rows * dims * 4).buffer.asFloat32List();
    final rowClip = take(rows * 4).buffer.asInt32List();
    final rowTime = take(rows * 4).buffer.asFloat32List();
    final rowFlags = take(rows);
    return LuminaPoseSearchIndex(
      fingerprint: header['fingerprint'] as String? ?? '',
      layout: layout,
      clipNames: clips,
      clipTagMasks: masks,
      tags: (header['tags'] as List? ?? const []).cast<String>(),
      clipCostBias: biases,
      rowCount: rows,
      features: features,
      mean: mean,
      inverseScale: inverseScale,
      weights: weights,
      rowClip: rowClip,
      rowTime: rowTime,
      rowFlags: rowFlags,
    );
  }
}
