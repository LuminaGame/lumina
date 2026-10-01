import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/lumina_asset.dart';
import 'animation_import_binder.dart';
import 'authored_animation_clip.dart';
import 'glb_animation_merger.dart';

/// Writes an [AuthoredAnimationClip] into a skinned GLB as a glTF animation,
/// the form every player in the engine reads (gltfio's animator, by clip
/// name, from the skeletal mesh's GLB).
abstract final class GlbAuthoredClipWriter {
  /// Extensions whose references this writer can remap when it drops the
  /// binary data of a replaced animation; any other extension keeps the old
  /// data in place (the file grows, nothing breaks).
  static const Set<String> _compactableExtensions = {
    'KHR_texture_transform',
    'KHR_draco_mesh_compression',
    'KHR_mesh_quantization',
    'KHR_materials_emissive_strength',
    'KHR_materials_unlit',
    'KHR_materials_ior',
    'KHR_materials_specular',
    'KHR_materials_transmission',
    'KHR_materials_volume',
    'KHR_materials_clearcoat',
    'KHR_materials_sheen',
    'KHR_lights_punctual',
    'KHR_texture_basisu',
    'EXT_texture_webp',
  };

  /// Returns [meshGlb] with [clip] as the animation named `clip.name`:
  /// replacing one of that name in place (its old binary data dropped) or
  /// appended. Every skin joint gets a channel — the clip's keys where it has
  /// them, the rest pose (rotation + translation, constant over the clip)
  /// elsewhere — so the clip defines the whole skeleton after any other clip.
  ///
  /// Throws [FormatException] for a non-GLB, a GLB with more than one buffer
  /// or no skin, and a clip naming a bone the mesh does not have.
  static ({Uint8List glb, int clipIndex}) write({required Uint8List meshGlb, required AuthoredAnimationClip clip}) {
    var doc = GlbDocument.parse(meshGlb, label: 'mesh');
    final buffers = (doc.json['buffers'] as List?) ?? const [];
    if (buffers.length > 1) {
      throw FormatException('the mesh uses ${buffers.length} buffers; only single-buffer GLBs can hold an authored clip');
    }
    final skeleton = GlbSkeleton.fromJson(doc.json);
    if (skeleton.joints.isEmpty) throw const FormatException('the mesh has no skin; there is no skeleton to animate');
    final missing = [
      for (final bone in clip.tracks.keys)
        if (skeleton.indexOf(bone) < 0) bone,
    ];
    if (missing.isNotEmpty) {
      throw FormatException('the mesh has no bone named ${missing.join(', ')}');
    }

    for (final entry in clip.tracks.entries) {
      for (final ch in entry.value.values) {
        for (final f in ch.keys.keys) {
          if (f < 0 || f > clip.lengthFrames) {
            throw FormatException('${entry.key} ${ch.path} has a key at frame $f, outside 0–${clip.lengthFrames}');
          }
        }
      }
    }

    final existing = ((doc.json['animations'] as List?) ?? const []).toList();
    var index = existing.indexWhere((a) => (a as Map)['name'] == clip.name);
    if (index >= 0) {
      doc = _removeAnimation(doc, index);
    }

    final json = doc.json;
    final accessors = ((json['accessors'] as List?) ?? const []).toList();
    final bufferViews = ((json['bufferViews'] as List?) ?? const []).toList();
    final bin = BytesBuilder(copy: false)..add(doc.bin);
    var binLength = doc.bin.length;

    int addAccessor(Float32List data, String type, int count, {List<double>? min, List<double>? max}) {
      final pad = (4 - binLength % 4) % 4;
      if (pad > 0) {
        bin.add(Uint8List(pad));
        binLength += pad;
      }
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      bufferViews.add(<String, dynamic>{'buffer': 0, 'byteOffset': binLength, 'byteLength': bytes.length});
      bin.add(Uint8List.fromList(bytes));
      binLength += bytes.length;
      accessors.add(<String, dynamic>{
        'bufferView': bufferViews.length - 1,
        'componentType': 5126,
        'count': count,
        'type': type,
        'min': ?min,
        'max': ?max,
      });
      return accessors.length - 1;
    }

    final duration = clip.duration;
    final constTimes = [0.0, duration];
    final constInput = addAccessor(Float32List.fromList(constTimes), 'SCALAR', 2, min: [0.0], max: [duration]);
    final samplers = <Map<String, dynamic>>[];
    final channels = <Map<String, dynamic>>[];
    void channel(int node, String path, int input, int output, String interpolation) {
      samplers.add({'input': input, 'output': output, 'interpolation': interpolation});
      channels.add({
        'sampler': samplers.length - 1,
        'target': {'node': node, 'path': path},
      });
    }

    void constant(int node, String path, List<double> value) {
      final data = Float32List.fromList([...value, ...value]);
      channel(node, path, constInput, addAccessor(data, path == AuthoredChannel.rotation ? 'VEC4' : 'VEC3', 2), 'LINEAR');
    }

    void authored(int node, AuthoredChannel ch) {
      var frames = ch.keys.keys.toList();
      var values = ch.writtenValues();
      // gltfio skips samplers with fewer than two times: hold the one key.
      if (frames.length == 1) {
        final other = frames.first < clip.lengthFrames ? clip.lengthFrames : 0;
        frames = other > frames.first ? [frames.first, other] : [other, frames.first];
        values = [values.first, values.first];
      }
      final times = [for (final f in frames) f / clip.frameRate];
      final input = addAccessor(Float32List.fromList(times), 'SCALAR', times.length, min: [times.first], max: [times.last]);
      final type = ch.width == 4 ? 'VEC4' : 'VEC3';
      final cubic = ch.interpolation == AuthoredInterpolation.cubic;
      final out = <double>[];
      for (final v in values) {
        if (cubic) out.addAll(List<double>.filled(ch.width, 0.0)); // in-tangent
        out.addAll(v);
        if (cubic) out.addAll(List<double>.filled(ch.width, 0.0)); // out-tangent
      }
      final output = addAccessor(Float32List.fromList(out), type, cubic ? values.length * 3 : values.length);
      channel(node, ch.path, input, output, ch.interpolation.gltfName);
    }

    final animatedNodes = <int>{...skeleton.joints, for (final b in clip.tracks.keys) skeleton.indexOf(b)}.toList()..sort();
    for (final node in animatedNodes) {
      final name = skeleton.names[node];
      final track = name == null ? null : clip.tracks[name];
      final rest = skeleton.rest(node);
      for (final path in AuthoredChannel.paths) {
        final ch = track?[path];
        if (ch != null && ch.keys.isNotEmpty) {
          authored(node, ch);
        } else if (path != AuthoredChannel.scale && skeleton.isJoint(node)) {
          constant(node, path, rest.channel(path));
        }
      }
    }

    final animation = <String, dynamic>{'name': clip.name, 'channels': channels, 'samplers': samplers};
    final animations = ((json['animations'] as List?) ?? const []).toList();
    if (index >= 0 && index <= animations.length) {
      animations.insert(index, animation);
    } else {
      animations.add(animation);
      index = animations.length - 1;
    }
    json['animations'] = animations;
    json['accessors'] = accessors;
    json['bufferViews'] = bufferViews;
    final merged = bin.takeBytes();
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];
    return (glb: GlbDocument(json, merged).encode(), clipIndex: index);
  }

  /// [doc] without animation [index], and — when every extension it uses is
  /// one whose references are known — without the accessors, buffer views
  /// and binary data only that animation used.
  static GlbDocument _removeAnimation(GlbDocument doc, int index) {
    final json = Map<String, dynamic>.from(doc.json);
    final animations = ((json['animations'] as List?) ?? const []).toList();
    final removed = animations.removeAt(index) as Map;
    json['animations'] = animations;

    final used = ((json['extensionsUsed'] as List?) ?? const []).cast<String>();
    if (!used.every(_compactableExtensions.contains)) return GlbDocument(json, doc.bin);

    final accessors = ((json['accessors'] as List?) ?? const []).cast<Map>().toList();
    final bufferViews = ((json['bufferViews'] as List?) ?? const []).cast<Map>().toList();

    // Accessors still referenced by the rest of the document.
    final keepAccessor = <int>{};
    for (final m in (json['meshes'] as List?) ?? const []) {
      for (final p in ((m as Map)['primitives'] as List?) ?? const []) {
        final prim = p as Map;
        for (final a in ((prim['attributes'] as Map?) ?? const {}).values) {
          keepAccessor.add(a as int);
        }
        if (prim['indices'] != null) keepAccessor.add(prim['indices'] as int);
        for (final t in (prim['targets'] as List?) ?? const []) {
          for (final a in (t as Map).values) {
            keepAccessor.add(a as int);
          }
        }
      }
    }
    for (final s in (json['skins'] as List?) ?? const []) {
      final ibm = (s as Map)['inverseBindMatrices'];
      if (ibm != null) keepAccessor.add(ibm as int);
    }
    for (final a in animations) {
      for (final s in ((a as Map)['samplers'] as List?) ?? const []) {
        keepAccessor.add((s as Map)['input'] as int);
        keepAccessor.add(s['output'] as int);
      }
    }
    final dropAccessor = <int>{
      for (final s in (removed['samplers'] as List?) ?? const []) ...[(s as Map)['input'] as int, s['output'] as int],
    }..removeAll(keepAccessor);
    if (dropAccessor.isEmpty) return GlbDocument(json, doc.bin);

    // Buffer views still referenced.
    final keepView = <int>{};
    for (var i = 0; i < accessors.length; i++) {
      if (dropAccessor.contains(i)) continue;
      final a = accessors[i];
      if (a['bufferView'] != null) keepView.add(a['bufferView'] as int);
      final sparse = a['sparse'] as Map?;
      if (sparse != null) {
        keepView.add((sparse['indices'] as Map)['bufferView'] as int);
        keepView.add((sparse['values'] as Map)['bufferView'] as int);
      }
    }
    for (final img in (json['images'] as List?) ?? const []) {
      final v = (img as Map)['bufferView'];
      if (v != null) keepView.add(v as int);
    }
    for (final m in (json['meshes'] as List?) ?? const []) {
      for (final p in ((m as Map)['primitives'] as List?) ?? const []) {
        final draco = ((p as Map)['extensions'] as Map?)?['KHR_draco_mesh_compression'] as Map?;
        if (draco?['bufferView'] != null) keepView.add(draco!['bufferView'] as int);
      }
    }

    // Rebuild the binary chunk from the kept views, in their original order.
    final viewMap = <int, int>{};
    final newViews = <Map>[];
    final out = BytesBuilder(copy: false);
    var length = 0;
    for (var i = 0; i < bufferViews.length; i++) {
      if (!keepView.contains(i)) continue;
      final v = Map<String, dynamic>.from(bufferViews[i]);
      final offset = (v['byteOffset'] as num?)?.toInt() ?? 0;
      final size = (v['byteLength'] as num).toInt();
      final pad = (4 - length % 4) % 4;
      if (pad > 0) {
        out.add(Uint8List(pad));
        length += pad;
      }
      out.add(Uint8List.sublistView(doc.bin, offset, offset + size));
      v['byteOffset'] = length;
      length += size;
      viewMap[i] = newViews.length;
      newViews.add(v);
    }

    final accessorMap = <int, int>{};
    final newAccessors = <Map>[];
    for (var i = 0; i < accessors.length; i++) {
      if (dropAccessor.contains(i)) continue;
      final a = Map<String, dynamic>.from(accessors[i]);
      if (a['bufferView'] != null) a['bufferView'] = viewMap[a['bufferView'] as int];
      final sparse = a['sparse'] as Map?;
      if (sparse != null) {
        final s = Map<String, dynamic>.from(sparse);
        s['indices'] = {...(sparse['indices'] as Map), 'bufferView': viewMap[(sparse['indices'] as Map)['bufferView'] as int]};
        s['values'] = {...(sparse['values'] as Map), 'bufferView': viewMap[(sparse['values'] as Map)['bufferView'] as int]};
        a['sparse'] = s;
      }
      accessorMap[i] = newAccessors.length;
      newAccessors.add(a);
    }

    for (final m in (json['meshes'] as List?) ?? const []) {
      for (final p in ((m as Map)['primitives'] as List?) ?? const []) {
        final prim = p as Map;
        final attrs = prim['attributes'] as Map?;
        if (attrs != null) {
          for (final k in attrs.keys.toList()) {
            attrs[k] = accessorMap[attrs[k] as int];
          }
        }
        if (prim['indices'] != null) prim['indices'] = accessorMap[prim['indices'] as int];
        for (final t in (prim['targets'] as List?) ?? const []) {
          final target = t as Map;
          for (final k in target.keys.toList()) {
            target[k] = accessorMap[target[k] as int];
          }
        }
        final draco = (prim['extensions'] as Map?)?['KHR_draco_mesh_compression'] as Map?;
        if (draco?['bufferView'] != null) draco!['bufferView'] = viewMap[draco['bufferView'] as int];
      }
    }
    for (final s in (json['skins'] as List?) ?? const []) {
      final skin = s as Map;
      if (skin['inverseBindMatrices'] != null) skin['inverseBindMatrices'] = accessorMap[skin['inverseBindMatrices'] as int];
    }
    for (final a in animations) {
      for (final s in ((a as Map)['samplers'] as List?) ?? const []) {
        final sampler = s as Map;
        sampler['input'] = accessorMap[sampler['input'] as int];
        sampler['output'] = accessorMap[sampler['output'] as int];
      }
    }
    for (final img in (json['images'] as List?) ?? const []) {
      final image = img as Map;
      if (image['bufferView'] != null) image['bufferView'] = viewMap[image['bufferView'] as int];
    }

    json['accessors'] = newAccessors;
    json['bufferViews'] = newViews;
    final bin = out.takeBytes();
    final buffers = ((json['buffers'] as List?) ?? const []).toList();
    if (buffers.isNotEmpty) {
      buffers[0] = {...Map<String, dynamic>.from(buffers.first as Map), 'byteLength': bin.length};
      json['buffers'] = buffers;
    }
    return GlbDocument(json, bin);
  }
}

/// Authored animation sequences in a project: the clip in the skeletal
/// mesh's GLB (`.entity.glb` companion, and the mesh `.lmas` payload when it
/// has one), the clip's name in the mesh's `animation_clips`, and an
/// animation `.lmas` that points at it the way a template or bound-import
/// clip does — plus the editor's exact keys as `authored_clip`.
abstract final class AuthoredAnimationStore {
  static const String authoredClipKey = 'authored_clip';
  static const String authoredKey = 'authored';

  /// True when the animation `.lmas` [asset] was authored in the editor.
  static bool isAuthored(LuminaAsset? asset) => (asset?.metadata[authoredClipKey] ?? '').isNotEmpty;

  /// The clip kept in [asset], or null for an imported clip.
  static AuthoredAnimationClip? clipOf(LuminaAsset? asset) {
    final json = asset?.metadata[authoredClipKey];
    if (json == null || json.isEmpty) return null;
    return AuthoredAnimationClip.decode(json);
  }

  static String _baseName(String path) => path.split('/').last.replaceAll(RegExp(r'\.(lmas|glb)$'), '');

  static String _clean(String name) {
    final c = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return c.isEmpty ? 'NewAnimation' : c;
  }

  /// Creates an authored sequence for the skeletal mesh at [meshRelPath]
  /// (project relative) and returns its `.lmas` path: `[lengthFrames]` long at
  /// [frameRate], the skeleton root's rest pose keyed at frame 0. The name is
  /// made unique among the mesh's clips and the files in its animation folder
  /// ([folder], project relative; `contents/animations/<Mesh>` by default).
  static String create({
    required String projectDir,
    required String meshRelPath,
    required String name,
    required int lengthFrames,
    double frameRate = 30.0,
    String? folder,
  }) {
    final meshFile = File('$projectDir/$meshRelPath');
    if (!meshFile.existsSync()) throw FileSystemException('Skeletal mesh asset not found', meshFile.path);
    final glb = AnimationImportBinder.meshGlb(meshFile.path);
    if (glb == null) throw FileSystemException('The skeletal mesh has no GLB to add a clip to', meshFile.path);
    final skeleton = GlbSkeleton.fromGlb(glb);
    final root = skeleton.root;
    if (root == null) throw const FormatException('the mesh has no skin; there is no skeleton to animate');

    folder ??= 'contents/animations/${_baseName(meshRelPath).isEmpty ? 'Shared' : _baseName(meshRelPath)}';
    final taken = GlbAnimationMerger.animationNames(glb).toSet();
    final base = _clean(name);
    var clipName = base;
    var n = 1;
    while (taken.contains(clipName) || File('$projectDir/$folder/$clipName.lmas').existsSync()) {
      clipName = '${base}_${++n}';
    }

    final clip = AuthoredAnimationClip(name: clipName, frameRate: frameRate, lengthFrames: lengthFrames);
    final rest = skeleton.rest(root);
    final rootName = skeleton.names[root]!;
    clip.setKey(rootName, AuthoredChannel.translation, 0, rest.channel(AuthoredChannel.translation));
    clip.setKey(rootName, AuthoredChannel.rotation, 0, rest.channel(AuthoredChannel.rotation));

    final rel = '$folder/$clipName.lmas';
    final meshAsset = LuminaAsset.fromBytes(meshFile.readAsBytesSync());
    final index = _writeIntoMesh(meshFile, meshAsset, glb, clip);
    final asset = LuminaAsset(
      assetId: _uuidV4(),
      name: clipName,
      type: AssetType.animation,
      references: [AssetReference(slotName: 'skeletal_mesh', assetId: meshAsset.assetId, assetPath: meshRelPath)],
      metadata: _clipMetadata(const {}, meshRelPath, clip, index),
    );
    final file = File('$projectDir/$rel');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(asset.toProtoBufferBytes());
    return rel;
  }

  /// Writes [clip] into its mesh's GLB (the animation keeps its index) and
  /// the animation `.lmas` at [animationRelPath]: [metadata] (the editor's
  /// other settings; the asset's own when null) with the clip keys updated.
  /// Returns the asset as written.
  static LuminaAsset save({
    required String projectDir,
    required String animationRelPath,
    required AuthoredAnimationClip clip,
    Map<String, String>? metadata,
    List<AssetReference>? references,
  }) {
    final file = File('$projectDir/$animationRelPath');
    final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
    final meshRelPath = asset.metadata['source_mesh'];
    if (meshRelPath == null || meshRelPath.isEmpty) {
      throw FormatException('$animationRelPath names no source mesh');
    }
    final meshFile = File('$projectDir/$meshRelPath');
    final glb = AnimationImportBinder.meshGlb(meshFile.path);
    if (glb == null) throw FileSystemException('The skeletal mesh has no GLB to add a clip to', meshFile.path);
    final meshAsset = LuminaAsset.fromBytes(meshFile.readAsBytesSync());
    final index = _writeIntoMesh(meshFile, meshAsset, glb, clip);
    final updated = LuminaAsset(
      assetId: asset.assetId,
      name: asset.name,
      type: AssetType.animation,
      hasThumbnail: asset.hasThumbnail,
      thumbnailPng: asset.thumbnailPng,
      rawPayload: null,
      rawMatSource: asset.rawMatSource,
      metadata: _clipMetadata(metadata ?? asset.metadata, meshRelPath, clip, index),
      references: references ?? asset.references,
    );
    file.writeAsBytesSync(updated.toProtoBufferBytes());
    return updated;
  }

  /// The authored clip of the animation `.lmas` at [animationRelPath], or
  /// null when it was imported.
  static AuthoredAnimationClip? load(String projectDir, String animationRelPath) {
    final file = File('$projectDir/$animationRelPath');
    if (!file.existsSync()) return null;
    return clipOf(LuminaAsset.fromBytes(file.readAsBytesSync()));
  }

  static int _writeIntoMesh(File meshFile, LuminaAsset meshAsset, Uint8List glb, AuthoredAnimationClip clip) {
    final result = GlbAuthoredClipWriter.write(meshGlb: glb, clip: clip);
    final companion = File(meshFile.path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    companion.writeAsBytesSync(result.glb);
    final clips = GlbAnimationMerger.animationNames(result.glb);
    final hasPayload = meshAsset.rawPayload != null && meshAsset.rawPayload!.isNotEmpty;
    final updated = LuminaAsset(
      assetId: meshAsset.assetId,
      name: meshAsset.name,
      type: meshAsset.type,
      hasThumbnail: meshAsset.hasThumbnail,
      thumbnailPng: meshAsset.thumbnailPng,
      rawPayload: hasPayload ? result.glb : meshAsset.rawPayload,
      rawMatSource: meshAsset.rawMatSource,
      metadata: Map<String, String>.from(meshAsset.metadata)..['animation_clips'] = clips.join(','),
      references: meshAsset.references,
    );
    meshFile.writeAsBytesSync(updated.toProtoBufferBytes());
    return result.clipIndex;
  }

  static Map<String, String> _clipMetadata(
      Map<String, String> base, String meshRelPath, AuthoredAnimationClip clip, int index) {
    Map<String, dynamic> props = {};
    final existing = base['anim_properties'];
    if (existing != null && existing.isNotEmpty) {
      try {
        props = Map<String, dynamic>.from(jsonDecode(existing) as Map);
      } catch (_) {}
    }
    props
      ..putIfAbsent('rate_scale', () => 1.0)
      ..putIfAbsent('interpolation', () => 'Linear')
      ..putIfAbsent('additive_type', () => 'No Additive')
      ..['frame_rate'] = clip.frameRate
      ..['default_clip'] = index
      ..putIfAbsent('preview_mesh_path', () => meshRelPath);
    return {
      ...base,
      'source_mesh': meshRelPath,
      'clip_name': clip.name,
      'clip_index': '$index',
      'anim_properties': jsonEncode(props),
      'duration_seconds': clip.duration.toStringAsFixed(3),
      'length_frames': '${clip.lengthFrames}',
      authoredKey: 'true',
      authoredClipKey: clip.encode(),
    };
  }

  static String _uuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
