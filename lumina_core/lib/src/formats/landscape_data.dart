import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3;

/// Placement rules of one foliage layer.
///
/// [density] is instances per 100 m² of painted area, [minSpacing] the
/// rejection radius (metres) between instances of the same layer, and the
/// slope range is measured in degrees off the terrain's up vector — all of
/// them are evaluated against the real heightmap when scattering.
class FoliageRules {
  final double density;
  final double minSpacing;
  final double scaleMin;
  final double scaleMax;
  final bool randomYaw;
  final bool alignToNormal;
  final double slopeMinDegrees;
  final double slopeMaxDegrees;

  const FoliageRules({
    this.density = 50.0,
    this.minSpacing = 1.5,
    this.scaleMin = 0.8,
    this.scaleMax = 1.2,
    this.randomYaw = true,
    this.alignToNormal = false,
    this.slopeMinDegrees = 0.0,
    this.slopeMaxDegrees = 45.0,
  });

  FoliageRules copyWith({
    double? density,
    double? minSpacing,
    double? scaleMin,
    double? scaleMax,
    bool? randomYaw,
    bool? alignToNormal,
    double? slopeMinDegrees,
    double? slopeMaxDegrees,
  }) {
    return FoliageRules(
      density: density ?? this.density,
      minSpacing: minSpacing ?? this.minSpacing,
      scaleMin: scaleMin ?? this.scaleMin,
      scaleMax: scaleMax ?? this.scaleMax,
      randomYaw: randomYaw ?? this.randomYaw,
      alignToNormal: alignToNormal ?? this.alignToNormal,
      slopeMinDegrees: slopeMinDegrees ?? this.slopeMinDegrees,
      slopeMaxDegrees: slopeMaxDegrees ?? this.slopeMaxDegrees,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FoliageRules &&
      other.density == density &&
      other.minSpacing == minSpacing &&
      other.scaleMin == scaleMin &&
      other.scaleMax == scaleMax &&
      other.randomYaw == randomYaw &&
      other.alignToNormal == alignToNormal &&
      other.slopeMinDegrees == slopeMinDegrees &&
      other.slopeMaxDegrees == slopeMaxDegrees;

  @override
  int get hashCode => Object.hash(
        density,
        minSpacing,
        scaleMin,
        scaleMax,
        randomYaw,
        alignToNormal,
        slopeMinDegrees,
        slopeMaxDegrees,
      );
}

/// One placed foliage instance: world position (metres, terrain space), a
/// non-uniform scale, the yaw applied around the alignment axis and the
/// surface normal it was aligned to.
class FoliageInstance {
  final double x;
  final double y;
  final double z;
  final double scaleX;
  final double scaleY;
  final double scaleZ;
  final double yaw;
  final double nx;
  final double ny;
  final double nz;

  const FoliageInstance({
    required this.x,
    required this.y,
    required this.z,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.yaw,
    required this.nx,
    required this.ny,
    required this.nz,
  });

  /// Transform in preview-world units.
  ///
  /// [unitsPerMetre] converts the instance's metre position into the preview
  /// world's units; [meshScale] compensates the mesh asset's own authoring
  /// unit (test-asset GLBs are centimetre-authored, so a metre-scaled preview
  /// needs 0.01).
  Matrix4 toMatrix({double unitsPerMetre = 1.0, double meshScale = 1.0}) {
    final normal = Vector3(nx, ny, nz);
    if (normal.length2 < 1e-12) {
      normal.setValues(0.0, 1.0, 0.0);
    } else {
      normal.normalize();
    }
    final up = Vector3(0.0, 1.0, 0.0);
    Quaternion align;
    final dot = up.dot(normal).clamp(-1.0, 1.0);
    if (dot > 0.999999) {
      align = Quaternion.identity();
    } else if (dot < -0.999999) {
      align = Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), math.pi);
    } else {
      final axis = up.cross(normal)..normalize();
      align = Quaternion.axisAngle(axis, math.acos(dot));
    }
    final rotation = align * Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), yaw);
    return Matrix4.compose(
      Vector3(x * unitsPerMetre, y * unitsPerMetre, z * unitsPerMetre),
      rotation,
      Vector3(scaleX * meshScale, scaleY * meshScale, scaleZ * meshScale),
    );
  }
}

/// A foliage layer: one mesh asset, its placement rules and the packed
/// transforms of every instance painted with it.
///
/// The transforms are a flat `Float32List` of [floatsPerInstance] floats per
/// instance (pos3, scale3, yaw, normal3) — the mirror of the GPU instance
/// batch, kept consistent through the same swap-remove that
/// `LuminaInstancedStaticMeshComponent.removeInstance` performs.
class FoliageLayer {
  static const int floatsPerInstance = 10;

  String meshAssetId;
  String meshAssetPath;
  String name;
  FoliageRules rules;

  Float32List _transforms;
  int _count = 0;

  FoliageLayer({
    required this.meshAssetId,
    required this.meshAssetPath,
    required this.name,
    this.rules = const FoliageRules(),
    Float32List? transforms,
  }) : _transforms = Float32List(math.max(16, (transforms?.length ?? 0))) {
    if (transforms != null && transforms.isNotEmpty) {
      _transforms.setRange(0, transforms.length, transforms);
      _count = transforms.length ~/ floatsPerInstance;
    }
  }

  int get instanceCount => _count;

  /// The live transform floats (a view, length `instanceCount * 10`).
  Float32List get transforms => Float32List.sublistView(_transforms, 0, _count * floatsPerInstance);

  void addInstance(FoliageInstance i) {
    _ensure((_count + 1) * floatsPerInstance);
    final o = _count * floatsPerInstance;
    _transforms[o] = i.x;
    _transforms[o + 1] = i.y;
    _transforms[o + 2] = i.z;
    _transforms[o + 3] = i.scaleX;
    _transforms[o + 4] = i.scaleY;
    _transforms[o + 5] = i.scaleZ;
    _transforms[o + 6] = i.yaw;
    _transforms[o + 7] = i.nx;
    _transforms[o + 8] = i.ny;
    _transforms[o + 9] = i.nz;
    _count++;
  }

  FoliageInstance instanceAt(int index) {
    if (index < 0 || index >= _count) {
      throw RangeError.index(index, this, 'index', 'instance index out of range', _count);
    }
    final o = index * floatsPerInstance;
    return FoliageInstance(
      x: _transforms[o],
      y: _transforms[o + 1],
      z: _transforms[o + 2],
      scaleX: _transforms[o + 3],
      scaleY: _transforms[o + 4],
      scaleZ: _transforms[o + 5],
      yaw: _transforms[o + 6],
      nx: _transforms[o + 7],
      ny: _transforms[o + 8],
      nz: _transforms[o + 9],
    );
  }

  /// Swap-removes [index]; returns the index the last instance moved from
  /// (`-1` when the removed instance was the last one) so callers can keep a
  /// parallel array in step with the GPU batch.
  int removeAt(int index) {
    if (index < 0 || index >= _count) return -1;
    final last = _count - 1;
    if (index != last) {
      final src = last * floatsPerInstance;
      final dst = index * floatsPerInstance;
      for (var f = 0; f < floatsPerInstance; f++) {
        _transforms[dst + f] = _transforms[src + f];
      }
    }
    _count--;
    return index == last ? -1 : last;
  }

  void clearInstances() => _count = 0;

  void _ensure(int floats) {
    if (_transforms.length >= floats) return;
    var next = math.max(_transforms.length * 2, 16);
    while (next < floats) {
      next *= 2;
    }
    final grown = Float32List(next)..setRange(0, _transforms.length, _transforms);
    _transforms = grown;
  }
}

/// A square heightmap terrain plus its foliage layers — the single source of
/// truth of the Landscape editor and of the runtime terrain component.
///
/// Heights are metres in `[0, maxHeight]` on a [gridResolution]² vertex grid
/// covering a [worldSize]×[worldSize] metre square centred on the origin; the
/// mesh sections and instance batches are derived from it and always
/// regenerable.
///
/// ## Storage
///
/// Heights are held as **normalized `uint16`** scaled by [maxHeight] — two
/// bytes per sample, with a quantisation step of `maxHeight / 65535` (exactly
/// the precision a 16-bit PNG import carries anyway). That is what makes the
/// 8129² ceiling reachable: 66 080 641 samples cost ~132 MB instead of the
/// ~264 MB the old `Float32List` needed. Payload **v2** writes those samples
/// directly; **v1** float payloads are still read and quantised on the way in.
///
/// There is no `heights` array to index: reads and writes go through
/// [heightAt]/[setHeight] (or the linear [heightAtIndex]/[setHeightAtIndex]),
/// and [heightsSnapshot] materialises a full `Float32List` only when a caller
/// explicitly asks for one. Nothing in the sculpt or mesh path may do that at
/// scale — at 8129² a single snapshot is 264 MB.
class LandscapeData {
  /// `LSND` — the payload magic inside a `LANDSCAPE` `.lmas`.
  static const List<int> magic = [0x4C, 0x53, 0x4E, 0x44];

  /// Current payload version (uint16 samples).
  static const int formatVersion = 2;

  /// The first payload version: float32 heights, 513² cap. Still readable.
  static const int legacyFloatVersion = 1;

  /// Quads per terrain tile along each axis — the section granularity the
  /// heightmap is tiled with, and therefore the granularity a valid imported
  /// resolution must line up with.
  static const int sectionQuads = 64;

  /// Largest supported grid: 8129² = 66 080 641 samples ≈ 132 MB of uint16.
  ///
  /// Measured on this workspace's machine (NVIDIA RTX PRO 2000, GPU 1): the
  /// allocation is instant, filling every sample takes ~50 ms, streaming the
  /// samples to disk ~85 ms and reading them back ~35 ms. What does *not*
  /// survive at this size is mounting every tile at once (127² = 16 129 tiles,
  /// ~68 M vertices) or any per-stroke pass over the whole grid — hence the
  /// residency budget and the dirty-rect sculpt path.
  static const int maxGridResolution = 8129;

  /// Samples above which the `.lmas` container stops carrying the heights
  /// inline.
  ///
  /// A `.lmas` base64-encodes its payload inside JSON, so an inline 8129²
  /// heightmap would cost ~176 MB of base64 on top of the 132 MB of samples.
  /// Beyond this limit the heights stream into a sidecar `.heights` file next
  /// to the asset and the payload carries only its header — see
  /// [samplesAreExternal].
  static const int maxInlineSamples = 1025 * 1025;

  /// Sidecar magic: `LSHM`.
  static const List<int> sidecarMagic = [0x4C, 0x53, 0x48, 0x4D];

  final int version;
  final int gridResolution;
  final double worldSize;
  final double maxHeight;
  final List<FoliageLayer> layers;

  /// Normalized heights: `sample * maxHeight / 65535` metres.
  final Uint16List samples;

  /// True when this payload was decoded from a header whose samples live in a
  /// sidecar file that has not been attached yet.
  bool samplesAreExternal;

  int _minSample = 0;
  int _maxSample = 0;

  LandscapeData({
    required this.gridResolution,
    required this.worldSize,
    required this.maxHeight,
    Float32List? heights,
    Uint16List? samples,
    List<FoliageLayer>? layers,
    this.version = formatVersion,
    this.samplesAreExternal = false,
  })  : layers = layers ?? <FoliageLayer>[],
        samples = samples ?? Uint16List(gridResolution * gridResolution) {
    if (gridResolution < 2 || gridResolution > maxGridResolution) {
      throw ArgumentError('gridResolution ($gridResolution) must be between 2 and $maxGridResolution');
    }
    if (maxHeight <= 0) {
      throw ArgumentError('maxHeight ($maxHeight) must be positive');
    }
    final expected = gridResolution * gridResolution;
    if (this.samples.length != expected) {
      throw ArgumentError('samples length ${this.samples.length} != gridResolution² ($expected)');
    }
    if (heights != null) {
      if (heights.length != expected) {
        throw ArgumentError('heights length ${heights.length} != gridResolution² ($expected)');
      }
      final scale = 65535.0 / maxHeight;
      for (var i = 0; i < heights.length; i++) {
        final v = heights[i];
        this.samples[i] = v <= 0.0 ? 0 : (v >= maxHeight ? 65535 : (v * scale).round());
      }
    }
    recomputeHeightRange();
  }

  factory LandscapeData.flat({
    int gridResolution = 129,
    double worldSize = 256.0,
    double maxHeight = 100.0,
  }) {
    return LandscapeData(
      gridResolution: gridResolution,
      worldSize: worldSize,
      maxHeight: maxHeight,
    );
  }

  // --- Resolution rules --------------------------------------------------------

  /// A resolution the section map tiles exactly: `n * 64 + 1`, from 65 to
  /// [maxGridResolution].
  static bool isValidResolution(int resolution) =>
      resolution >= sectionQuads + 1 &&
      resolution <= maxGridResolution &&
      (resolution - 1) % sectionQuads == 0;

  /// Every resolution the importer accepts, ascending.
  static List<int> get validResolutions =>
      [for (var n = 1; n * sectionQuads + 1 <= maxGridResolution; n++) n * sectionQuads + 1];

  /// The two valid resolutions bracketing [resolution] (the second is null
  /// when [resolution] is above the cap).
  static (int, int?) nearestValidResolutions(int resolution) {
    if (resolution <= sectionQuads + 1) return (sectionQuads + 1, sectionQuads * 2 + 1);
    if (resolution >= maxGridResolution) return (maxGridResolution, null);
    final n = (resolution - 1) ~/ sectionQuads;
    final lower = n * sectionQuads + 1;
    final upper = (n + 1) * sectionQuads + 1;
    return (lower, upper > maxGridResolution ? maxGridResolution : upper);
  }

  /// Why [resolution] cannot be imported, or null when it can.
  static String? describeInvalidResolution(int resolution) {
    if (isValidResolution(resolution)) return null;
    if (resolution > maxGridResolution) {
      return 'heightmap $resolution² exceeds the $maxGridResolution² limit — '
          'the largest terrain Lumina supports is $maxGridResolution × $maxGridResolution';
    }
    if (resolution < sectionQuads + 1) {
      return 'heightmap $resolution² is smaller than the ${sectionQuads + 1}² minimum '
          '(one $sectionQuads-quad terrain tile)';
    }
    final (lower, upper) = nearestValidResolutions(resolution);
    return 'heightmap $resolution² does not tile into $sectionQuads-quad sections — '
          'a terrain side must be n × $sectionQuads + 1; the nearest valid sizes are '
          '$lower² and ${upper ?? maxGridResolution}²';
  }

  // --- Height access -----------------------------------------------------------

  int get vertexCount => gridResolution * gridResolution;

  /// Bytes the heights occupy in memory.
  int get heightBytes => samples.lengthInBytes;

  /// Metres between two neighbouring height samples.
  double get cellSize => worldSize / (gridResolution - 1);

  /// The smallest height difference this payload can represent.
  double get heightStep => maxHeight / 65535.0;

  /// Lowest height in the terrain, as of the last [recomputeHeightRange].
  double get heightMin => _minSample * heightStep;

  /// Highest height in the terrain, as of the last [recomputeHeightRange].
  double get heightMax => _maxSample * heightStep;

  /// Rescans every sample to refresh [heightMin]/[heightMax].
  ///
  /// O(vertexCount) — call it when a terrain is created, imported or opened,
  /// never per stroke and never per vertex. [setHeight] widens the cached
  /// range as it goes, so the range is only ever too generous, never wrong in
  /// a way that clips the colour ramp.
  void recomputeHeightRange() {
    var lo = 65535;
    var hi = 0;
    for (final s in samples) {
      if (s < lo) lo = s;
      if (s > hi) hi = s;
    }
    _minSample = samples.isEmpty ? 0 : lo;
    _maxSample = samples.isEmpty ? 0 : hi;
  }

  double heightAt(int col, int row) {
    final c = col.clamp(0, gridResolution - 1);
    final r = row.clamp(0, gridResolution - 1);
    return samples[r * gridResolution + c] * heightStep;
  }

  /// Height of the [index]-th sample in row-major order.
  double heightAtIndex(int index) => samples[index] * heightStep;

  void setHeight(int col, int row, double value) {
    if (col < 0 || row < 0 || col >= gridResolution || row >= gridResolution) return;
    setHeightAtIndex(row * gridResolution + col, value);
  }

  void setHeightAtIndex(int index, double value) {
    final s = value <= 0.0
        ? 0
        : (value >= maxHeight ? 65535 : (value * 65535.0 / maxHeight).round());
    samples[index] = s;
    if (s < _minSample) _minSample = s;
    if (s > _maxSample) _maxSample = s;
  }

  /// A full `Float32List` of every height, materialised on demand.
  ///
  /// Two bytes per sample become four: at 8129² this is a 264 MB allocation.
  /// Nothing in the sculpt, mesh or save path calls it — it exists for tests
  /// and for exporting a v1 payload.
  Float32List heightsSnapshot() {
    final out = Float32List(samples.length);
    final step = heightStep;
    for (var i = 0; i < samples.length; i++) {
      out[i] = samples[i] * step;
    }
    return out;
  }

  /// World X (metres) of column [col]; the grid is centred on the origin.
  double worldXOf(int col) => -worldSize / 2 + col * cellSize;
  double worldZOf(int row) => -worldSize / 2 + row * cellSize;

  double columnOf(double worldX) => (worldX + worldSize / 2) / cellSize;
  double rowOf(double worldZ) => (worldZ + worldSize / 2) / cellSize;

  /// Bilinear height sample at a world position (metres).
  double sampleHeight(double worldX, double worldZ) {
    final fc = columnOf(worldX).clamp(0.0, (gridResolution - 1).toDouble());
    final fr = rowOf(worldZ).clamp(0.0, (gridResolution - 1).toDouble());
    final c0 = fc.floor();
    final r0 = fr.floor();
    final c1 = math.min(c0 + 1, gridResolution - 1);
    final r1 = math.min(r0 + 1, gridResolution - 1);
    final tx = fc - c0;
    final tz = fr - r0;
    final h00 = heightAt(c0, r0);
    final h10 = heightAt(c1, r0);
    final h01 = heightAt(c0, r1);
    final h11 = heightAt(c1, r1);
    final a = h00 + (h10 - h00) * tx;
    final b = h01 + (h11 - h01) * tx;
    return a + (b - a) * tz;
  }

  /// Unit surface normal (Y-up) from central differences of the heightmap.
  Vector3 sampleNormal(double worldX, double worldZ) {
    final d = cellSize;
    final hl = sampleHeight(worldX - d, worldZ);
    final hr = sampleHeight(worldX + d, worldZ);
    final hd = sampleHeight(worldX, worldZ - d);
    final hu = sampleHeight(worldX, worldZ + d);
    final n = Vector3(hl - hr, 2 * d, hd - hu);
    if (n.length2 < 1e-12) return Vector3(0.0, 1.0, 0.0);
    return n..normalize();
  }

  /// Slope in degrees off vertical at a world position.
  double sampleSlopeDegrees(double worldX, double worldZ) {
    final n = sampleNormal(worldX, worldZ);
    return math.acos(n.y.clamp(-1.0, 1.0)) * 180.0 / math.pi;
  }

  /// True when [worldX]/[worldZ] lie inside the terrain footprint.
  bool contains(double worldX, double worldZ) {
    final half = worldSize / 2;
    return worldX >= -half && worldX <= half && worldZ >= -half && worldZ <= half;
  }

  LandscapeData copyWithHeights(Float32List newHeights) => LandscapeData(
        gridResolution: gridResolution,
        worldSize: worldSize,
        maxHeight: maxHeight,
        heights: newHeights,
        layers: layers,
      );

  // --- Binary payload ----------------------------------------------------------

  /// Byte length of the header that precedes the samples in a v2 payload.
  static const int _v2HeaderBytes = 4 + 4 + 4 + 4 + 4 + 1;

  /// The payload bytes.
  ///
  /// When [inlineSamples] is false (or the grid is larger than
  /// [maxInlineSamples]) only the header and the foliage layers are written
  /// and the heights are expected in a sidecar — see [writeSidecar].
  Uint8List toBytes({bool? inlineSamples}) {
    final inline = inlineSamples ?? (vertexCount <= maxInlineSamples);
    final tail = _encodeLayers();
    final sampleBytes = inline ? samples.lengthInBytes : 0;
    final out = Uint8List(_v2HeaderBytes + sampleBytes + tail.length);
    final view = ByteData.view(out.buffer);
    out.setRange(0, 4, magic);
    var o = 4;
    view.setUint32(o, formatVersion, Endian.little);
    o += 4;
    view.setUint32(o, gridResolution, Endian.little);
    o += 4;
    view.setFloat32(o, worldSize, Endian.little);
    o += 4;
    view.setFloat32(o, maxHeight, Endian.little);
    o += 4;
    out[o++] = inline ? 0 : 1;
    if (inline) {
      for (var i = 0; i < samples.length; i++) {
        view.setUint16(o, samples[i], Endian.little);
        o += 2;
      }
    }
    out.setRange(o, o + tail.length, tail);
    return out;
  }

  Uint8List _encodeLayers() {
    final strings = <List<int>>[];
    var stringBytes = 0;
    for (final l in layers) {
      for (final s in [l.meshAssetId, l.meshAssetPath, l.name]) {
        final encoded = utf8.encode(s);
        strings.add(encoded);
        stringBytes += 2 + encoded.length;
      }
    }
    var size = 4 + stringBytes;
    for (final l in layers) {
      size += 4 * 6 + 2 + 4;
      size += l.instanceCount * FoliageLayer.floatsPerInstance * 4;
    }
    final out = Uint8List(size);
    final view = ByteData.view(out.buffer);
    var o = 0;
    view.setUint32(o, layers.length, Endian.little);
    o += 4;
    var si = 0;
    for (final l in layers) {
      for (var s = 0; s < 3; s++) {
        final bytes = strings[si++];
        view.setUint16(o, bytes.length, Endian.little);
        o += 2;
        out.setRange(o, o + bytes.length, bytes);
        o += bytes.length;
      }
      final r = l.rules;
      for (final f in [r.density, r.minSpacing, r.scaleMin, r.scaleMax, r.slopeMinDegrees, r.slopeMaxDegrees]) {
        view.setFloat32(o, f, Endian.little);
        o += 4;
      }
      out[o++] = r.randomYaw ? 1 : 0;
      out[o++] = r.alignToNormal ? 1 : 0;
      view.setUint32(o, l.instanceCount, Endian.little);
      o += 4;
      for (final f in l.transforms) {
        view.setFloat32(o, f, Endian.little);
        o += 4;
      }
    }
    return out;
  }

  factory LandscapeData.fromBytes(Uint8List bytes) {
    if (bytes.length < 20 ||
        bytes[0] != magic[0] ||
        bytes[1] != magic[1] ||
        bytes[2] != magic[2] ||
        bytes[3] != magic[3]) {
      throw ArgumentError('not a LANDSCAPE payload (missing LSND magic)');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    var o = 4;
    final version = view.getUint32(o, Endian.little);
    o += 4;
    if (version != formatVersion && version != legacyFloatVersion) {
      throw ArgumentError('unsupported landscape payload version $version');
    }
    final resolution = view.getUint32(o, Endian.little);
    o += 4;
    final worldSize = view.getFloat32(o, Endian.little);
    o += 4;
    final maxHeight = view.getFloat32(o, Endian.little);
    o += 4;

    final count = resolution * resolution;
    final samples = Uint16List(count);
    var external = false;
    if (version == legacyFloatVersion) {
      // v1: float32 metres, quantised into the v2 sample grid.
      final scale = 65535.0 / maxHeight;
      for (var i = 0; i < count; i++) {
        final v = view.getFloat32(o, Endian.little);
        o += 4;
        samples[i] = v <= 0.0 ? 0 : (v >= maxHeight ? 65535 : (v * scale).round());
      }
    } else {
      external = bytes[o++] == 1;
      if (!external) {
        for (var i = 0; i < count; i++) {
          samples[i] = view.getUint16(o, Endian.little);
          o += 2;
        }
      }
    }

    final layerCount = view.getUint32(o, Endian.little);
    o += 4;
    final layers = <FoliageLayer>[];
    for (var l = 0; l < layerCount; l++) {
      final strings = <String>[];
      for (var s = 0; s < 3; s++) {
        final len = view.getUint16(o, Endian.little);
        o += 2;
        strings.add(utf8.decode(bytes.sublist(o, o + len)));
        o += len;
      }
      final floats = <double>[];
      for (var f = 0; f < 6; f++) {
        floats.add(view.getFloat32(o, Endian.little));
        o += 4;
      }
      final randomYaw = bytes[o++] == 1;
      final alignToNormal = bytes[o++] == 1;
      final instanceCount = view.getUint32(o, Endian.little);
      o += 4;
      final transforms = Float32List(instanceCount * FoliageLayer.floatsPerInstance);
      for (var i = 0; i < transforms.length; i++) {
        transforms[i] = view.getFloat32(o, Endian.little);
        o += 4;
      }
      layers.add(FoliageLayer(
        meshAssetId: strings[0],
        meshAssetPath: strings[1],
        name: strings[2],
        rules: FoliageRules(
          density: floats[0],
          minSpacing: floats[1],
          scaleMin: floats[2],
          scaleMax: floats[3],
          slopeMinDegrees: floats[4],
          slopeMaxDegrees: floats[5],
          randomYaw: randomYaw,
          alignToNormal: alignToNormal,
        ),
        transforms: transforms,
      ));
    }
    return LandscapeData(
      gridResolution: resolution,
      worldSize: worldSize,
      maxHeight: maxHeight,
      samples: samples,
      layers: layers,
      version: version,
      samplesAreExternal: external,
    );
  }

  // --- Sidecar (large terrains) ------------------------------------------------

  /// The heights file that belongs to the `.lmas` at [assetPath].
  static String sidecarPathFor(String assetPath) {
    final base = assetPath.toLowerCase().endsWith('.lmas')
        ? assetPath.substring(0, assetPath.length - 5)
        : assetPath;
    return '$base.heights';
  }

  /// Streams the samples into [file] in 4 Mi-sample chunks.
  ///
  /// Nothing here materialises a second copy of the heightmap: at 8129² one
  /// monolithic byte list would be another 132 MB on top of the samples.
  Future<void> writeSidecar(File file) async {
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    final sink = file.openWrite();
    try {
      final header = Uint8List(16);
      final hv = ByteData.view(header.buffer);
      header.setRange(0, 4, sidecarMagic);
      hv.setUint32(4, formatVersion, Endian.little);
      hv.setUint32(8, gridResolution, Endian.little);
      hv.setUint32(12, 0, Endian.little);
      sink.add(header);

      const chunkSamples = 1 << 22;
      for (var off = 0; off < samples.length; off += chunkSamples) {
        final end = math.min(off + chunkSamples, samples.length);
        sink.add(Uint8List.view(samples.buffer, samples.offsetInBytes + off * 2, (end - off) * 2));
        await sink.flush();
      }
    } finally {
      await sink.close();
    }
  }

  /// Reads sidecar bytes into this payload's samples.
  void readSidecarBytes(Uint8List bytes) {
    if (bytes.length < 16 ||
        bytes[0] != sidecarMagic[0] ||
        bytes[1] != sidecarMagic[1] ||
        bytes[2] != sidecarMagic[2] ||
        bytes[3] != sidecarMagic[3]) {
      throw ArgumentError('not a landscape heights sidecar');
    }
    final hv = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final res = hv.getUint32(8, Endian.little);
    if (res != gridResolution) {
      throw ArgumentError('heights sidecar is $res² but the terrain is $gridResolution²');
    }
    final expected = samples.lengthInBytes;
    if (bytes.length - 16 < expected) {
      throw ArgumentError('heights sidecar is truncated (${bytes.length - 16} of $expected bytes)');
    }
    final src = Uint16List.view(bytes.buffer, bytes.offsetInBytes + 16, samples.length);
    samples.setRange(0, samples.length, src);
    samplesAreExternal = false;
    recomputeHeightRange();
  }

  /// Reads a sidecar written by [writeSidecar] into this payload's samples.
  ///
  /// Throws when the sidecar does not describe this terrain, rather than
  /// filling the grid with whatever bytes were there.
  void readSidecar(File file) {
    final bytes = file.readAsBytesSync();
    if (bytes.length < 16 ||
        bytes[0] != sidecarMagic[0] ||
        bytes[1] != sidecarMagic[1] ||
        bytes[2] != sidecarMagic[2] ||
        bytes[3] != sidecarMagic[3]) {
      throw ArgumentError('${file.path} is not a landscape heights sidecar');
    }
    readSidecarBytes(bytes);
  }
}
