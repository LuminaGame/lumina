import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// One animation to merge into a base GLB: animation [animationIndex] of the
/// GLB [bytes], stored in the result under [name].
class GlbClipSource {
  final String name;
  final Uint8List bytes;
  final int animationIndex;

  /// Drop the clip's `root` translation channel: a root-motion
  /// export moves the whole mesh away from its capsule
  /// and snaps it back when the clip ends; the character's movement provides
  /// the travel instead.
  final bool stripRootMotion;

  /// Rotation-only retarget: drop the clip's translation and
  /// scale channels for every bone except [keepTranslationForBones], keeping
  /// all rotations, so a clip exported from a skeleton with different bone
  /// lengths (the same bone names on other proportions) does not push
  /// the base's bones to the other skeleton's offsets. The kept bones'
  /// translation keys are scaled by the ratio of the base's to the source's
  /// bind length of that bone. `null` (the default) turns it on automatically when the
  /// clip's skeleton differs from the base's — its skin joints and the
  /// base's are not the same set.
  final bool? rotationOnly;
  final Set<String> keepTranslationForBones;

  const GlbClipSource({
    required this.name,
    required this.bytes,
    this.animationIndex = 0,
    this.stripRootMotion = false,
    this.rotationOnly,
    this.keepTranslationForBones = const {'root', 'pelvis'},
  });

  /// A clip exported as a `.gltf` document with its keys in a sibling binary
  /// file (`buffers[].uri`, e.g. `Land.bin`), packed into a GLB in memory.
  ///
  /// Only what the merger reads survives: the buffer is embedded as the GLB
  /// binary chunk and `images` are dropped, so the texture files the export
  /// references need not exist. [name] defaults to the file's stem
  /// (`Land.gltf` → `Land`). Throws [FormatException] for a document
  /// with more than one buffer or a buffer that is neither a sibling file nor
  /// a base64 `data:` URI, and [FileSystemException] when the sibling is
  /// missing.
  factory GlbClipSource.fromGltf(File gltf, {String? name, int animationIndex = 0}) {
    final json = jsonDecode(gltf.readAsStringSync()) as Map<String, dynamic>;
    final buffers = (json['buffers'] as List?) ?? const [];
    if (buffers.length != 1) {
      throw FormatException('${gltf.path} has ${buffers.length} buffers; a clip must use exactly one');
    }
    final uri = (buffers.first as Map)['uri'] as String?;
    final Uint8List bin;
    if (uri == null) {
      throw FormatException('${gltf.path} has a buffer with no uri; a .gltf keeps its keys in a sibling file');
    } else if (uri.startsWith('data:')) {
      final comma = uri.indexOf(',');
      if (comma == -1 || !uri.substring(0, comma).endsWith(';base64')) {
        throw FormatException('${gltf.path} has a data: buffer that is not base64');
      }
      bin = base64Decode(uri.substring(comma + 1));
    } else {
      bin = File('${gltf.parent.path}/${Uri.decodeComponent(uri)}').readAsBytesSync();
    }
    json['buffers'] = [
      <String, dynamic>{'byteLength': bin.length},
    ];
    json.remove('images');
    final stem = gltf.uri.pathSegments.last.replaceFirst(RegExp(r'\.gltf$', caseSensitive: false), '');
    return GlbClipSource(name: name ?? stem, bytes: GlbDocument(json, bin).encode(), animationIndex: animationIndex);
  }
}

/// What merging one clip did to its channels: the bones whose channels were
/// copied and the bones the base skeleton lacked (dropped only with
/// `skipMissingBones`).
class GlbClipMergeReport {
  final String clip;
  final List<String> keptBones;
  final List<String> droppedBones;
  final int keptChannels;
  final int droppedChannels;

  /// Root translation channels left out for a `stripRootMotion` clip.
  final int strippedRootMotionChannels;

  /// Whether the clip was retargeted rotation-only, and what that
  /// left out: translation / scale channels of bones other than the kept
  /// ones, and the factor each kept bone's translation was scaled by.
  final bool rotationOnly;
  final int droppedTranslationChannels;
  final int droppedScaleChannels;
  final Map<String, double> translationScale;

  const GlbClipMergeReport({
    required this.clip,
    required this.keptBones,
    required this.droppedBones,
    required this.keptChannels,
    required this.droppedChannels,
    this.strippedRootMotionChannels = 0,
    this.rotationOnly = false,
    this.droppedTranslationChannels = 0,
    this.droppedScaleChannels = 0,
    this.translationScale = const {},
  });

  bool get droppedAny => droppedBones.isNotEmpty;

  /// Whether every bone of [bones] kept at least one channel.
  bool keeps(Iterable<String> bones) => bones.every(keptBones.contains);

  @override
  String toString() => '$clip: ${keptBones.length} bones kept ($keptChannels channels)'
      '${droppedAny ? ', dropped ${droppedBones.join(', ')} ($droppedChannels channels)' : ''}'
      '${strippedRootMotionChannels > 0 ? ', root motion stripped ($strippedRootMotionChannels channel${strippedRootMotionChannels == 1 ? '' : 's'})' : ''}'
      '${rotationOnly ? ', rotation-only retarget: $droppedTranslationChannels translation + $droppedScaleChannels scale channels dropped'
          '${translationScale.isEmpty ? '' : ', ${translationScale.entries.map((e) => '${e.key} ×${e.value.toStringAsFixed(3)}').join(', ')}'}' : ''}';
}

/// One [GlbClipMergeReport] per merged clip, in merge order.
class GlbMergeReport {
  final List<GlbClipMergeReport> clips;
  const GlbMergeReport(this.clips);

  GlbClipMergeReport? forClip(String name) => clips.where((c) => c.clip == name).firstOrNull;

  @override
  String toString() => clips.join('\n');
}

/// A GLB split into its JSON document and its binary chunk.
class GlbDocument {
  static const int _magic = 0x46546C67; // "glTF"
  static const int _jsonChunk = 0x4E4F534A; // "JSON"
  static const int _binChunk = 0x004E4942; // "BIN\0"

  final Map<String, dynamic> json;
  final Uint8List bin;

  GlbDocument(this.json, this.bin);

  /// Parses [bytes] as a binary glTF 2.0 container. [label] names the input in
  /// the [FormatException] thrown for anything that is not one.
  factory GlbDocument.parse(Uint8List bytes, {String label = 'input'}) {
    if (bytes.length < 20) {
      throw FormatException('$label is not a GLB: ${bytes.length} bytes is shorter than a GLB header');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != _magic) {
      throw FormatException('$label is not a GLB: missing the "glTF" magic');
    }
    final version = data.getUint32(4, Endian.little);
    if (version != 2) {
      throw FormatException('$label is glTF version $version; only 2 is supported');
    }
    final jsonLength = data.getUint32(12, Endian.little);
    if (data.getUint32(16, Endian.little) != _jsonChunk || 20 + jsonLength > bytes.length) {
      throw FormatException('$label has no readable JSON chunk');
    }
    final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;

    var bin = Uint8List(0);
    final binHeader = 20 + jsonLength;
    if (binHeader + 8 <= bytes.length && data.getUint32(binHeader + 4, Endian.little) == _binChunk) {
      final binLength = data.getUint32(binHeader, Endian.little);
      bin = Uint8List.fromList(bytes.sublist(binHeader + 8, binHeader + 8 + binLength));
    }
    return GlbDocument(json, bin);
  }

  /// Serializes the document back into a GLB, padding the JSON chunk with
  /// spaces and the binary chunk with zeros to 4-byte boundaries.
  Uint8List encode() {
    final jsonBytes = utf8.encode(jsonEncode(json));
    final jsonPadded = _align4(jsonBytes.length);
    final binPadded = _align4(bin.length);
    final hasBin = bin.isNotEmpty;
    final total = 12 + 8 + jsonPadded + (hasBin ? 8 + binPadded : 0);

    final out = Uint8List(total);
    final data = ByteData.sublistView(out);
    data.setUint32(0, _magic, Endian.little);
    data.setUint32(4, 2, Endian.little);
    data.setUint32(8, total, Endian.little);
    data.setUint32(12, jsonPadded, Endian.little);
    data.setUint32(16, _jsonChunk, Endian.little);
    out.setRange(20, 20 + jsonBytes.length, jsonBytes);
    out.fillRange(20 + jsonBytes.length, 20 + jsonPadded, 0x20);
    if (hasBin) {
      final binHeader = 20 + jsonPadded;
      data.setUint32(binHeader, binPadded, Endian.little);
      data.setUint32(binHeader + 4, _binChunk, Endian.little);
      out.setRange(binHeader + 8, binHeader + 8 + bin.length, bin);
    }
    return out;
  }

  static int _align4(int n) => (n + 3) & ~3;
}

/// Merges animations from several GLBs into one skinned GLB, so a single
/// gltfio asset — and therefore a single `FilamentAnimator` — can play them all.
///
/// gltfio's animator only plays animations stored in the same asset as the
/// nodes they move. Clip sets exported one animation per file (Unreal's
/// mannequin sequences, Mixamo downloads) are therefore merged ahead of time.
/// Channels are retargeted by **node name**: two exports of the same skeleton
/// do not have to list their bones in the same order, and the Unreal mannequin
/// clips in `test-assets/` indeed permute the finger bones relative to
/// `SKM_Manny_Simple`.
class GlbAnimationMerger {
  const GlbAnimationMerger._();

  /// The names of the animations stored in [glb], in index order.
  static List<String> animationNames(Uint8List glb) {
    final doc = GlbDocument.parse(glb);
    final animations = (doc.json['animations'] as List?) ?? const [];
    return [
      for (var i = 0; i < animations.length; i++)
        ((animations[i] as Map)['name'] as String?) ?? 'Animation$i',
    ];
  }

  /// Whether animation [animationIndex] of [glb] is an additive export: it
  /// has scale channels and every one of their keys is zero. Unreal writes
  /// additive sequences (the turn-in-place set) as deltas — identity
  /// rotations, zero translations and zero scales — which collapse a mesh to
  /// a point when played as absolute keys; their `_Data` companion carries
  /// the absolute poses instead.
  /// Names of the base's skin joints (every skin), or of every named node
  /// when it has no skin.
  static Set<String> _jointNames(Map<String, dynamic> json) {
    final nodes = (json['nodes'] as List?) ?? const [];
    final skins = (json['skins'] as List?) ?? const [];
    final joints = <String>{};
    for (final skin in skins) {
      for (final j in ((skin as Map)['joints'] as List?) ?? const []) {
        final name = (nodes[j as int] as Map)['name'] as String?;
        if (name != null) joints.add(name);
      }
    }
    if (joints.isNotEmpty) return joints;
    return {for (final n in nodes) if ((n as Map)['name'] is String) n['name'] as String};
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  /// |base bind translation| / |source bind translation| of a bone, 1.0 when
  /// either is (near) zero — the root sits at the origin in both.
  static double _bindLengthRatio(Map baseNode, Map srcNode) {
    double length(Map node) {
      final t = (node['translation'] as List?)?.cast<num>();
      if (t == null) return 0.0;
      return math.sqrt(t[0] * t[0] + t[1] * t[1] + t[2] * t[2]);
    }
    final b = length(baseNode), s = length(srcNode);
    if (b < 1e-6 || s < 1e-6) return 1.0;
    return b / s;
  }

  /// Whether every scale channel of animation [animationIndex] keeps every
  /// bone at scale 1 (within [tolerance]); true when it has no scale channel.
  static bool hasUnitScales(Uint8List glb, {int animationIndex = 0, double tolerance = 1e-4}) {
    final doc = GlbDocument.parse(glb);
    final animations = (doc.json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) return false;
    final animation = animations[animationIndex] as Map;
    final samplers = (animation['samplers'] as List?) ?? const [];
    final accessors = (doc.json['accessors'] as List?) ?? const [];
    final bufferViews = (doc.json['bufferViews'] as List?) ?? const [];
    for (final c in (animation['channels'] as List?) ?? const []) {
      if (((c as Map)['target'] as Map)['path'] != 'scale') continue;
      final acc = accessors[(samplers[c['sampler'] as int] as Map)['output'] as int] as Map;
      if (acc['componentType'] != 5126 || acc['bufferView'] == null) return false;
      final bv = bufferViews[acc['bufferView'] as int] as Map;
      final count = acc['count'] as int;
      final stride = (bv['byteStride'] as int?) ?? 12;
      final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
      final data = ByteData.sublistView(doc.bin);
      for (var i = 0; i < count; i++) {
        for (var k = 0; k < 3; k++) {
          if ((data.getFloat32(start + i * stride + k * 4, Endian.little) - 1.0).abs() > tolerance) return false;
        }
      }
    }
    return true;
  }

  static bool hasCollapsedScales(Uint8List glb, {int animationIndex = 0}) {
    final doc = GlbDocument.parse(glb);
    final animations = (doc.json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) return false;
    final animation = animations[animationIndex] as Map;
    final samplers = (animation['samplers'] as List?) ?? const [];
    final accessors = (doc.json['accessors'] as List?) ?? const [];
    final bufferViews = (doc.json['bufferViews'] as List?) ?? const [];
    var scaleChannels = 0;
    for (final c in (animation['channels'] as List?) ?? const []) {
      if (((c as Map)['target'] as Map)['path'] != 'scale') continue;
      scaleChannels++;
      final acc = accessors[(samplers[c['sampler'] as int] as Map)['output'] as int] as Map;
      if (acc['componentType'] != 5126 || acc['bufferView'] == null) return false;
      final bv = bufferViews[acc['bufferView'] as int] as Map;
      final count = acc['count'] as int;
      final stride = (bv['byteStride'] as int?) ?? 12;
      final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
      final data = ByteData.sublistView(doc.bin);
      for (var i = 0; i < count; i++) {
        for (var k = 0; k < 3; k++) {
          if (data.getFloat32(start + i * stride + k * 4, Endian.little).abs() > 1e-6) return false;
        }
      }
    }
    return scaleChannels > 0;
  }

  /// Returns [base] with one animation appended per entry of [clips].
  ///
  /// The base keeps its meshes, skins, images and any animations it already
  /// had. Every accessor a merged sampler reads is copied tightly packed into
  /// the base's binary buffer behind a new buffer view; an accessor shared by
  /// several samplers of one clip (typically the key times) is copied once.
  ///
  /// Throws [FormatException] when an input is not a GLB, the base uses more
  /// than one buffer, a clip uses a sparse accessor, a channel targets an
  /// unnamed node or a bone the base does not have (unless [skipMissingBones]
  /// drops those channels instead), or an animation index is out of range.
  static Uint8List merge({
    required Uint8List base,
    required List<GlbClipSource> clips,
    bool skipMissingBones = false,
  }) =>
      mergeWithReport(base: base, clips: clips, skipMissingBones: skipMissingBones).bytes;

  /// [merge], also reporting per clip which bones' channels were kept and,
  /// with [skipMissingBones], which were dropped because the base skeleton
  /// has no node of that name (an export with extra bones — the Unreal
  /// mannequin's `breast_l/r` — animates the bones both skeletons share and
  /// leaves the rest at the bind pose).
  static ({Uint8List bytes, GlbMergeReport report}) mergeWithReport({
    required Uint8List base,
    required List<GlbClipSource> clips,
    bool skipMissingBones = false,
  }) {
    final reports = <GlbClipMergeReport>[];
    final baseDoc = GlbDocument.parse(base, label: 'base');
    final json = baseDoc.json;

    final buffers = (json['buffers'] as List?) ?? <dynamic>[];
    if (buffers.length > 1) {
      throw FormatException('base uses ${buffers.length} buffers; only single-buffer GLBs can be merged into');
    }
    for (final b in buffers) {
      if ((b as Map)['uri'] != null) {
        throw const FormatException('base buffer points at an external uri; expected the GLB binary chunk');
      }
    }

    final baseNodes = (json['nodes'] as List?) ?? const [];
    final baseIndexByName = <String, int>{};
    for (var i = 0; i < baseNodes.length; i++) {
      final name = (baseNodes[i] as Map)['name'] as String?;
      if (name != null) baseIndexByName.putIfAbsent(name, () => i);
    }
    final baseJoints = _jointNames(json);

    final bin = BytesBuilder(copy: false)..add(baseDoc.bin);
    var binLength = baseDoc.bin.length;
    final bufferViews = (json['bufferViews'] as List?)?.toList() ?? <dynamic>[];
    final accessors = (json['accessors'] as List?)?.toList() ?? <dynamic>[];
    final animations = (json['animations'] as List?)?.toList() ?? <dynamic>[];

    for (final clip in clips) {
      final src = GlbDocument.parse(clip.bytes, label: 'clip "${clip.name}"');
      final srcAnimations = (src.json['animations'] as List?) ?? const [];
      if (clip.animationIndex < 0 || clip.animationIndex >= srcAnimations.length) {
        throw FormatException(
          'clip "${clip.name}" asks for animation ${clip.animationIndex} '
          'but its GLB has ${srcAnimations.length}',
        );
      }
      final srcAnimation = srcAnimations[clip.animationIndex] as Map;
      final srcNodes = (src.json['nodes'] as List?) ?? const [];
      final srcAccessors = (src.json['accessors'] as List?) ?? const [];
      final srcBufferViews = (src.json['bufferViews'] as List?) ?? const [];

      // Resolve every channel target before copying a byte, so a skeleton
      // mismatch reports all missing bones at once.
      final srcChannels = (srcAnimation['channels'] as List?) ?? const [];
      final targets = <int>[];
      final missing = <String>{};
      final kept = <String>{};
      var droppedChannels = 0;
      var strippedRootMotion = 0;
      var droppedTranslation = 0;
      var droppedScale = 0;
      // Rotation-only retarget: on request, or when the clip's
      // skeleton (its skin joints) is not the base's.
      final rotationOnly = clip.rotationOnly ?? (baseJoints.isNotEmpty && !_sameSet(_jointNames(src.json), baseJoints));
      // Kept bones' translation keys are scaled by the bind-length ratio.
      final translationScale = <String, double>{};
      // Accessor scale factors by channel index (1.0 = copied verbatim).
      final channelScale = <int, double>{};
      for (var i = 0; i < srcChannels.length; i++) {
        final c = srcChannels[i];
        final target = (c as Map)['target'] as Map;
        final node = target['node'] as int?;
        if (node == null) {
          throw FormatException('clip "${clip.name}" has a channel with no target node');
        }
        final name = (srcNodes[node] as Map)['name'] as String?;
        if (name == null) {
          throw FormatException('clip "${clip.name}" animates unnamed node $node; channels are matched by name');
        }
        final baseIndex = baseIndexByName[name];
        final path = target['path'];
        if (clip.stripRootMotion && name == 'root' && path == 'translation') {
          strippedRootMotion++;
          targets.add(-1);
        } else if (rotationOnly && baseIndex != null && path == 'scale') {
          droppedScale++;
          targets.add(-1);
        } else if (rotationOnly && baseIndex != null && path == 'translation' && !clip.keepTranslationForBones.contains(name)) {
          droppedTranslation++;
          targets.add(-1);
        } else if (baseIndex == null) {
          missing.add(name);
          droppedChannels++;
          targets.add(-1);
        } else {
          kept.add(name);
          targets.add(baseIndex);
          if (rotationOnly && path == 'translation') {
            final factor = _bindLengthRatio(baseNodes[baseIndex] as Map, srcNodes[node] as Map);
            translationScale[name] = factor;
            if ((factor - 1.0).abs() > 1e-6) channelScale[i] = factor;
          }
        }
      }
      if (missing.isNotEmpty && !skipMissingBones) {
        throw FormatException(
          'clip "${clip.name}" animates bones the base does not have: ${missing.join(', ')}',
        );
      }
      reports.add(GlbClipMergeReport(
        clip: clip.name,
        keptBones: kept.toList(),
        droppedBones: missing.toList(),
        keptChannels: srcChannels.length - droppedChannels - strippedRootMotion - droppedTranslation - droppedScale,
        droppedChannels: droppedChannels,
        strippedRootMotionChannels: strippedRootMotion,
        rotationOnly: rotationOnly,
        droppedTranslationChannels: droppedTranslation,
        droppedScaleChannels: droppedScale,
        translationScale: translationScale,
      ));

      // Copied accessors by source index and scale factor (a scaled copy of
      // a float accessor multiplies every component).
      final copied = <(int, double), int>{};
      int copyAccessor(int srcIndex, [double scale = 1.0]) {
        final existing = copied[(srcIndex, scale)];
        if (existing != null) return existing;

        final acc = srcAccessors[srcIndex] as Map;
        if (acc['sparse'] != null) {
          throw FormatException('clip "${clip.name}" uses sparse accessor $srcIndex, which cannot be merged');
        }
        final count = acc['count'] as int;
        final componentType = acc['componentType'] as int;
        final elementSize = _componentSize(componentType) * _componentCount(acc['type'] as String);
        final packed = Uint8List(count * elementSize);

        final bvIndex = acc['bufferView'] as int?;
        if (bvIndex != null) {
          final bv = srcBufferViews[bvIndex] as Map;
          final stride = (bv['byteStride'] as int?) ?? elementSize;
          final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
          for (var i = 0; i < count; i++) {
            final from = start + i * stride;
            packed.setRange(i * elementSize, (i + 1) * elementSize, src.bin, from);
          }
          if (scale != 1.0) {
            if (componentType != 5126) {
              throw FormatException('clip "${clip.name}" keeps a non-float translation accessor $srcIndex; it cannot be scaled');
            }
            final floats = ByteData.sublistView(packed);
            for (var i = 0; i < packed.length; i += 4) {
              floats.setFloat32(i, floats.getFloat32(i, Endian.little) * scale, Endian.little);
            }
          }
        }

        final padding = GlbDocument._align4(binLength) - binLength;
        if (padding > 0) bin.add(Uint8List(padding));
        final offset = binLength + padding;
        bin.add(packed);
        binLength = offset + packed.length;

        bufferViews.add(<String, dynamic>{
          'buffer': 0,
          'byteOffset': offset,
          'byteLength': packed.length,
        });
        final newAccessor = <String, dynamic>{
          'bufferView': bufferViews.length - 1,
          'componentType': componentType,
          'count': count,
          'type': acc['type'],
          if (acc['normalized'] == true) 'normalized': true,
          if (acc['min'] != null && scale == 1.0) 'min': acc['min'],
          if (acc['max'] != null && scale == 1.0) 'max': acc['max'],
        };
        accessors.add(newAccessor);
        final index = accessors.length - 1;
        copied[(srcIndex, scale)] = index;
        return index;
      }

      // Samplers are copied on demand, so a dropped channel's keys are not
      // carried along; a sampler shared by kept channels is copied once.
      final srcSamplers = (srcAnimation['samplers'] as List?) ?? const [];
      final samplers = <Map<String, dynamic>>[];
      final samplerIndex = <(int, double), int>{};
      int copySampler(int srcIndex, [double scale = 1.0]) => samplerIndex.putIfAbsent((srcIndex, scale), () {
            final sampler = srcSamplers[srcIndex] as Map;
            samplers.add(<String, dynamic>{
              'input': copyAccessor(sampler['input'] as int),
              'output': copyAccessor(sampler['output'] as int, scale),
              if (sampler['interpolation'] != null) 'interpolation': sampler['interpolation'],
            });
            return samplers.length - 1;
          });

      final channels = <Map<String, dynamic>>[];
      for (var i = 0; i < srcChannels.length; i++) {
        if (targets[i] < 0) continue;
        final c = srcChannels[i] as Map;
        channels.add(<String, dynamic>{
          'sampler': copySampler(c['sampler'] as int, channelScale[i] ?? 1.0),
          'target': <String, dynamic>{
            'node': targets[i],
            'path': (c['target'] as Map)['path'],
          },
        });
      }

      animations.add(<String, dynamic>{
        'name': clip.name,
        'channels': channels,
        'samplers': samplers,
      });
    }

    json['bufferViews'] = bufferViews;
    json['accessors'] = accessors;
    json['animations'] = animations;
    final merged = bin.takeBytes();
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];
    return (bytes: GlbDocument(json, merged).encode(), report: GlbMergeReport(reports));
  }

  static int _componentSize(int componentType) {
    switch (componentType) {
      case 5120: // BYTE
      case 5121: // UNSIGNED_BYTE
        return 1;
      case 5122: // SHORT
      case 5123: // UNSIGNED_SHORT
        return 2;
      case 5125: // UNSIGNED_INT
      case 5126: // FLOAT
        return 4;
    }
    throw FormatException('unknown accessor componentType $componentType');
  }

  static int _componentCount(String type) {
    switch (type) {
      case 'SCALAR':
        return 1;
      case 'VEC2':
        return 2;
      case 'VEC3':
        return 3;
      case 'VEC4':
      case 'MAT2':
        return 4;
      case 'MAT3':
        return 9;
      case 'MAT4':
        return 16;
    }
    throw FormatException('unknown accessor type $type');
  }
}
