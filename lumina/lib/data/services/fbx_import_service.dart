import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_assimp/flutter_assimp.dart';

import 'package:lumina/data/services/encoded_image_format.dart';
import 'package:lumina/data/services/fbx_material_mapper.dart';
import 'package:lumina/data/services/fbx_texture_locator.dart';
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/data/services/imported_asset_names.dart';
import 'package:lumina/data/services/tga_decoder_service.dart';

/// Thrown when an FBX file cannot be turned into a GLB.
class FbxImportException implements Exception {
  final String message;
  const FbxImportException(this.message);

  @override
  String toString() => message;
}

/// An FBX file converted for the import pipeline.
class FbxImportResult {
  /// Standard glTF: metres, +Y up, one animation per FBX take (named), node
  /// transforms as TRS, `UCX_`-style collision hulls removed.
  final Uint8List glb;

  /// The bridge report without the hull points and triangles (see
  /// `AssimpImportConversion.report`).
  final Map<String, dynamic> report;

  /// One name per take, in animation order.
  final List<String> clipNames;

  /// The removed collision hulls: name, shape (convex/box/sphere/
  /// capsule), vertex_count, face_count, min/max, points (x, y, z flattened;
  /// metres, Y up, in the asset's space) and triangles (indices into the
  /// points, 3 per face). `MeshCollisionService` turns them into collision.
  final List<Map<String, dynamic>> collisionHulls;

  const FbxImportResult({
    required this.glb,
    required this.report,
    required this.clipNames,
    required this.collisionHulls,
  });

  /// Each texture the FBX referenced but that was found nowhere (see
  /// [FbxImportService.missingTextureDetailsKey]): `material` (the FBX
  /// material name), `slot`, `path` (as the FBX wrote it), `file`.
  List<Map<String, dynamic>> get missingTextureDetails => [
        for (final d in (report[FbxImportService.missingTextureDetailsKey] as List?) ?? const [])
          Map<String, dynamic>.from(d as Map),
      ];

  /// Each texture bound to a material (see
  /// [FbxImportService.materialTexturesKey]).
  List<Map<String, dynamic>> get materialTextures => [
        for (final d in (report[FbxImportService.materialTexturesKey] as List?) ?? const [])
          Map<String, dynamic>.from(d as Map),
      ];

  /// What the import records on the emitted asset: the source format, how it
  /// was normalized, the takes and (when the source had any) the hulls.
  /// [assetBaseName] (the mesh asset's name) turns the FBX material names of
  /// the texture lists into the material assets' names.
  Map<String, String> toAssetMetadata({String? assetBaseName}) {
    String material(Object? raw) => assetBaseName == null ? '$raw' : ImportedAssetNames.material('$raw', assetBaseName);
    final missingDetails = [
      for (final d in missingTextureDetails) {...d, 'material': material(d['material'])},
    ];
    final bound = [
      for (final d in materialTextures) {...d, 'material': material(d['material'])},
    ];
    final source = (report['source_metadata'] as Map?) ?? const {};
    return {
      'source_format': 'FBX',
      if (source['UnitScaleFactor'] != null) 'fbx_unit_scale_factor': '${source['UnitScaleFactor']}',
      if (report['up_axis'] != null) 'fbx_up_axis': '${report['up_axis']}',
      if (report['front_axis'] != null) 'fbx_front_axis': '${report['front_axis']}',
      'import_normalized': '${report['normalized'] == true}',
      'import_unit_scale': '${report['unit_scale'] ?? 1}',
      if (clipNames.isNotEmpty) 'fbx_takes': jsonEncode(report['takes'] ?? const []),
      if (collisionHulls.isNotEmpty) 'collision_hulls': jsonEncode(collisionHulls),
      if ((report[FbxImportService.missingTexturesKey] as List?)?.isNotEmpty ?? false)
        'fbx_missing_textures': jsonEncode(report[FbxImportService.missingTexturesKey]),
      if (missingDetails.isNotEmpty) 'fbx_missing_texture_details': jsonEncode(missingDetails),
      if ((report[FbxImportService.embeddedTexturesKey] as List?)?.isNotEmpty ?? false)
        'fbx_embedded_textures': jsonEncode(report[FbxImportService.embeddedTexturesKey]),
      if (bound.isNotEmpty) 'fbx_material_textures': jsonEncode(bound),
    };
  }
}

/// FBX → GLB for the import pipeline.
///
/// flutter_assimp's bridge does the heavy lifting natively: it bakes the FBX
/// unit scale and axis system into the scene (Unreal exports are centimetres,
/// Z up) and strips `UCX_`/`UBX_`/`USP_`/`UCP_` collision hulls. What remains
/// is fixing what Assimp's glTF exporter writes:
///
/// - one unnamed animation **per channel** (per bone); they are merged back
///   into one animation per FBX take, named after the file (single take) or
///   `<file>_<take>`;
/// - samplers carry their interpolation under `path`; rewritten as
///   `interpolation`;
/// - node transforms as `matrix`; rewritten as TRS, which animated nodes must
///   use (glTF 2.0 §5.25) and the CPU mesh parser reads.
abstract final class FbxImportService {
  static bool isFbx(String path) => path.toLowerCase().endsWith('.fbx');

  /// [convertSync] in a background isolate (Assimp takes seconds on a
  /// skeletal mesh; the editor's UI thread must not wait on it).
  static Future<FbxImportResult> convert(String fbxPath, {List<String> textureSearchDirs = const []}) =>
      Isolate.run(() => convertSync(fbxPath, textureSearchDirs: textureSearchDirs));

  /// [textureSearchDirs] are searched first for the FBX's textures (the
  /// Import dialog's "Textures Folder").
  static FbxImportResult convertSync(String fbxPath, {List<String> textureSearchDirs = const []}) {
    final fileName = File(fbxPath).uri.pathSegments.last;
    final conversion = FlutterAssimp.convertFileForImport(fbxPath);
    if (!conversion.success) {
      throw FbxImportException('FBX conversion of "$fileName" failed: ${conversion.error ?? 'unknown error'}');
    }
    final report = Map<String, dynamic>.from(conversion.report);
    final hulls = [
      for (final h in (report['collision'] as List?) ?? const []) Map<String, dynamic>.from(h as Map),
    ];
    report['collision'] = [
      for (final h in hulls) {...h}
        ..remove('points')
        ..remove('triangles'),
    ];

    final takes = [
      for (final t in (report['takes'] as List?) ?? const [])
        (name: '${(t as Map)['name'] ?? ''}', channels: (t['channels'] as num?)?.toInt() ?? 0),
    ];
    final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    final clipNames = clipNamesFor(baseName, [for (final t in takes) t.name]);
    final processed = postProcess(
      conversion.glb!,
      takes: [for (var i = 0; i < takes.length; i++) (name: clipNames[i], channels: takes[i].channels)],
      generator: 'Lumina FBX import (Assimp ${FlutterAssimp.version})',
    );
    // The FBX's own material values, then its textures.
    final details = [for (final d in (report['material_details'] as List?) ?? const []) d as Map];
    final withMaterials = applyMaterialDetails(processed, details);
    final locator = FbxTextureLocator(fbxFile: File(fbxPath), extraDirs: textureSearchDirs);
    final textures = resolveExternalImages(withMaterials, sourceDir: File(fbxPath).parent, locator: locator);
    final matched = attachMatchedTextures(textures.glb, locator: locator, exclude: textures.boundFiles);
    report[embeddedTexturesKey] = [...textures.embedded, ...matched.embedded];
    report[missingTexturesKey] = textures.missing;
    report[missingTextureDetailsKey] = textures.missingDetails;
    report[materialTexturesKey] = [...textures.bound, ...matched.bound];
    return FbxImportResult(glb: matched.glb, report: report, clipNames: clipNames, collisionHulls: hulls);
  }

  /// [FbxMaterialMapper.applyToGltf] on a GLB.
  static Uint8List applyMaterialDetails(Uint8List glb, List<Map> details) {
    if (details.isEmpty) return glb;
    final doc = GlbDocument.parse(glb, label: 'converted FBX');
    FbxMaterialMapper.applyToGltf(doc.json, details);
    return GlbDocument(doc.json, doc.bin).encode();
  }

  /// Each referenced texture that was found nowhere: `material` (FBX name),
  /// `slot` (`normalMap`, …), `path` (as the FBX wrote it), `file` (its file
  /// name). The import names each in the Output Log.
  static const String missingTextureDetailsKey = 'missing_texture_details';

  /// Each texture bound to a material: `material` (FBX name), `slot`,
  /// `file` (the file found), `texture` (the image's name, which the texture
  /// asset is named after) and `source` (`referenced`, `embedded` or
  /// `matched by name`).
  static const String materialTexturesKey = 'material_textures';

  /// glTF texture slots of a material, as the `.lmas` sampler names.
  static Iterable<(String, Map)> textureSlots(Map material) sync* {
    final pbr = material['pbrMetallicRoughness'] as Map?;
    if (pbr?['baseColorTexture'] is Map) yield ('baseColorMap', pbr!['baseColorTexture'] as Map);
    if (pbr?['metallicRoughnessTexture'] is Map) yield ('metallicRoughnessMap', pbr!['metallicRoughnessTexture'] as Map);
    for (final (key, slot) in const [
      ('normalTexture', 'normalMap'),
      ('occlusionTexture', 'occlusionMap'),
      ('emissiveTexture', 'emissiveMap'),
    ]) {
      if (material[key] is Map) yield (slot, material[key] as Map);
    }
  }

  /// A texture now sampled by [material] in [slot] takes over the colour:
  /// the base colour factor turns white (the FBX diffuse texture replaces
  /// the diffuse colour), a black emissive colour turns white.
  static void _textureTakesOver(Map<String, dynamic> json, Map material, String slot) {
    if (slot == 'baseColorMap') {
      final pbr = material['pbrMetallicRoughness'] as Map;
      final f = (pbr['baseColorFactor'] as List?) ?? const [1, 1, 1, 1];
      pbr['baseColorFactor'] = [1.0, 1.0, 1.0, f.length > 3 ? (f[3] as num).toDouble() : 1.0];
    } else if (slot == 'emissiveMap' && FbxMaterialMapper.emissiveOf(material).every((c) => c <= 0)) {
      FbxMaterialMapper.setEmissive(json, material, const [1.0, 1.0, 1.0]);
    } else if (slot == 'metallicRoughnessMap') {
      final pbr = material['pbrMetallicRoughness'] as Map;
      pbr['metallicFactor'] = 1.0;
      pbr['roughnessFactor'] = 1.0;
    }
  }

  /// Image bytes as embedded in a GLB (TGA re-encoded as PNG), or null when
  /// the file is not an image this importer reads.
  static ({Uint8List bytes, String mime})? _readImage(File file) {
    final raw = file.readAsBytesSync();
    // The bytes decide, not the extension: a texture folder can hold a
    // PNG saved as `.tga`, and the TGA reader takes a PNG's IHDR tag for an
    // 18505x21060 header.
    switch (EncodedImageFormat.sniff(raw)) {
      case EncodedImageFormat.tga:
        final png = TgaDecoderService.tgaToPng(raw);
        return png == null ? null : (bytes: png, mime: 'image/png');
      case EncodedImageFormat.jpeg:
        return (bytes: raw, mime: 'image/jpeg');
      case EncodedImageFormat.png:
        return (bytes: raw, mime: 'image/png');
      default:
        return null;
    }
  }

  /// Gives the materials of [glb] the images of the locator's near folders
  /// that match them by name ([FbxTextureLocator.matchByName]) in the
  /// channels no referenced texture fills: an FBX that names no texture (an
  /// Unreal export of a material with constants and textures carries only
  /// the constants) still gets the textures its author dropped next to it.
  /// Each becomes an embedded image named `T_<material core>_<channel>`.
  static ({Uint8List glb, List<String> embedded, List<Map<String, dynamic>> bound}) attachMatchedTextures(
    Uint8List glb, {
    required FbxTextureLocator locator,
    Set<String> exclude = const {},
  }) {
    final doc = GlbDocument.parse(glb, label: 'converted FBX');
    final json = doc.json;
    final materials = ((json['materials'] as List?) ?? const []).cast<Map>();
    final names = [for (final m in materials) '${m['name'] ?? ''}'];
    final matches = locator.matchByName(names, exclude: exclude);
    if (matches.isEmpty) return (glb: glb, embedded: const [], bound: const []);

    final bin = BytesBuilder(copy: false)..add(doc.bin);
    var binLength = doc.bin.length;
    final bufferViews = ((json['bufferViews'] as List?) ?? const []).toList();
    final images = ((json['images'] as List?) ?? const []).toList();
    final textures = ((json['textures'] as List?) ?? const []).toList();
    final samplers = ((json['samplers'] as List?) ?? const []).toList();
    int? sampler;
    final imageOfFile = <String, int>{};
    final embedded = <String>[];
    final bound = <Map<String, dynamic>>[];
    for (final entry in matches.entries) {
      final material = materials[entry.key] as Map<String, dynamic>;
      final filled = {for (final (slot, _) in textureSlots(material)) slot};
      for (final MapEntry(key: channel, value: file) in entry.value.entries) {
        if (filled.contains(channel.slot)) continue;
        if (channel == FbxTextureChannel.occlusion && filled.contains('metallicRoughnessMap')) continue;
        var image = imageOfFile[file.absolute.path];
        if (image == null) {
          final read = _readImage(file);
          if (read == null) continue;
          final padding = ((binLength + 3) & ~3) - binLength;
          if (padding > 0) bin.add(Uint8List(padding));
          final offset = binLength + padding;
          bin.add(read.bytes);
          binLength = offset + read.bytes.length;
          bufferViews.add(<String, dynamic>{'buffer': 0, 'byteOffset': offset, 'byteLength': read.bytes.length});
          images.add(<String, dynamic>{
            'name': 'T_${FbxTextureLocator.coreName(names[entry.key])}_${channel.suffix}',
            'bufferView': bufferViews.length - 1,
            'mimeType': read.mime,
          });
          image = imageOfFile[file.absolute.path] = images.length - 1;
          embedded.add(file.uri.pathSegments.last);
        }
        sampler ??= () {
          samplers.add(<String, dynamic>{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497});
          return samplers.length - 1;
        }();
        textures.add(<String, dynamic>{'source': image, 'sampler': sampler});
        final ref = <String, dynamic>{'index': textures.length - 1};
        final pbr = (material['pbrMetallicRoughness'] as Map?) ?? (material['pbrMetallicRoughness'] = <String, dynamic>{});
        switch (channel) {
          case FbxTextureChannel.baseColor:
            pbr['baseColorTexture'] = ref;
          case FbxTextureChannel.normal:
            material['normalTexture'] = ref;
          case FbxTextureChannel.emissive:
            material['emissiveTexture'] = ref;
          case FbxTextureChannel.orm:
            pbr['metallicRoughnessTexture'] = ref;
            material['occlusionTexture'] = {'index': textures.length - 1};
          case FbxTextureChannel.occlusion:
            material['occlusionTexture'] = ref;
        }
        _textureTakesOver(json, material, channel.slot);
        filled.add(channel.slot);
        bound.add({
          'material': names[entry.key],
          'slot': channel.slot,
          'file': file.path,
          'texture': (images[image] as Map)['name'],
          'source': 'matched by name',
        });
      }
    }
    if (bound.isEmpty) return (glb: glb, embedded: const [], bound: const []);
    final merged = bin.takeBytes();
    json['images'] = images;
    json['textures'] = textures;
    json['samplers'] = samplers;
    json['bufferViews'] = bufferViews;
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];
    return (glb: GlbDocument(json, merged).encode(), embedded: embedded, bound: bound);
  }

  /// Textures the FBX referenced that were found and embedded (file names).
  static const String embeddedTexturesKey = 'embedded_textures';

  /// Textures the FBX referenced that exist nowhere near it (the exporter's
  /// absolute paths, e.g. `W:/Cafe/.../T_Leather_Normal.png`).
  static const String missingTexturesKey = 'missing_textures';

  /// Clip names for [takeNames]: a single take is named after the file (an
  /// Unreal export calls every take "Unreal Take"); several are
  /// `<file>_<take>`, made unique.
  static List<String> clipNamesFor(String baseName, List<String> takeNames) {
    if (takeNames.isEmpty) return const [];
    if (takeNames.length == 1) return [baseName];
    final used = <String>{};
    final names = <String>[];
    for (var i = 0; i < takeNames.length; i++) {
      var take = takeNames[i].replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      if (take.isEmpty) take = 'Take${i + 1}';
      var name = '${baseName}_$take';
      var n = 2;
      while (!used.add(name)) {
        name = '${baseName}_${take}_${n++}';
      }
      names.add(name);
    }
    return names;
  }

  /// Rewrites the exporter's GLB (see the class doc). [takes] lists each take's
  /// clip name and channel count in export order; when their channel counts do
  /// not add up to the animations present, everything is merged into one clip
  /// named after the first take.
  static Uint8List postProcess(
    Uint8List glb, {
    required List<({String name, int channels})> takes,
    String? generator,
  }) {
    final doc = GlbDocument.parse(glb, label: 'converted FBX');
    final json = doc.json;

    final animations = (json['animations'] as List?) ?? const [];
    if (animations.isNotEmpty) {
      final total = takes.fold<int>(0, (sum, t) => sum + t.channels);
      final groups = total == animations.length && takes.every((t) => t.channels > 0)
          ? takes
          : [(name: takes.isNotEmpty ? takes.first.name : 'Take1', channels: animations.length)];
      final merged = <Map<String, dynamic>>[];
      var next = 0;
      for (final group in groups) {
        final channels = <Map<String, dynamic>>[];
        final samplers = <Map<String, dynamic>>[];
        for (var i = 0; i < group.channels; i++) {
          final anim = animations[next++] as Map;
          final offset = samplers.length;
          for (final s in (anim['samplers'] as List?) ?? const []) {
            final sampler = s as Map;
            final interpolation = sampler['interpolation'] ?? sampler['path'];
            samplers.add({
              'input': sampler['input'],
              'output': sampler['output'],
              'interpolation': const {'LINEAR', 'STEP', 'CUBICSPLINE'}.contains(interpolation) ? interpolation : 'LINEAR',
            });
          }
          for (final c in (anim['channels'] as List?) ?? const []) {
            final channel = c as Map;
            channels.add({
              'sampler': (channel['sampler'] as int) + offset,
              'target': Map<String, dynamic>.from(channel['target'] as Map),
            });
          }
        }
        merged.add({'name': group.name, 'channels': channels, 'samplers': samplers});
      }
      json['animations'] = merged;
    }

    for (final n in (json['nodes'] as List?) ?? const []) {
      final node = n as Map<String, dynamic>;
      final matrix = node.remove('matrix') as List?;
      if (matrix == null || matrix.length != 16) continue;
      final trs = decomposeMatrix([for (final v in matrix) (v as num).toDouble()]);
      if (trs.translation.any((v) => v != 0)) node['translation'] = trs.translation;
      if (!(trs.rotation[0] == 0 && trs.rotation[1] == 0 && trs.rotation[2] == 0)) node['rotation'] = trs.rotation;
      if (trs.scale.any((v) => (v - 1).abs() > 1e-6)) node['scale'] = trs.scale;
    }

    if (generator != null) {
      final asset = (json['asset'] as Map<String, dynamic>?) ?? <String, dynamic>{'version': '2.0'};
      asset['generator'] = generator;
      json['asset'] = asset;
    }
    return GlbDocument(json, doc.bin).encode();
  }

  /// Makes every image of [glb] self-contained. An FBX names its textures by
  /// the path they had on the author's machine; Assimp's exporter keeps that
  /// as the image `uri`. Each one is looked up by [locator] (default: one for
  /// [sourceDir]; see [FbxTextureLocator.locateReference]). Found images are
  /// embedded (TGA re-encoded as PNG) under the name the FBX gave the file;
  /// the rest are removed together with the textures and material slots that
  /// sampled them, so the import never writes a texture asset without an
  /// image, and are listed per material in `missingDetails`.
  static ({
    Uint8List glb,
    List<String> embedded,
    List<String> missing,
    List<Map<String, dynamic>> missingDetails,
    List<Map<String, dynamic>> bound,
    Set<String> boundFiles,
  }) resolveExternalImages(
    Uint8List glb, {
    required Directory sourceDir,
    FbxTextureLocator? locator,
  }) {
    locator ??= FbxTextureLocator(fbxFile: File('${sourceDir.path}/_.fbx'));
    final doc = GlbDocument.parse(glb, label: 'converted FBX');
    final json = doc.json;
    final images = ((json['images'] as List?) ?? const []).cast<Map>().toList();
    final materials = ((json['materials'] as List?) ?? const []).cast<Map>();
    final textures = ((json['textures'] as List?) ?? const []).cast<Map>().toList();

    // Who samples each image, for the missing list and the bound list.
    final users = <int, List<(String, String)>>{}; // image → (material, slot)
    for (final m in materials) {
      for (final (slot, ref) in textureSlots(m)) {
        final t = ref['index'] as int?;
        final source = t != null && t < textures.length ? textures[t]['source'] as int? : null;
        if (source != null) users.putIfAbsent(source, () => []).add(('${m['name'] ?? ''}', slot));
      }
    }

    final bin = BytesBuilder(copy: false)..add(doc.bin);
    var binLength = doc.bin.length;
    final bufferViews = ((json['bufferViews'] as List?) ?? const []).toList();
    final embedded = <String>[];
    final missing = <String>[];
    final missingDetails = <Map<String, dynamic>>[];
    final bound = <Map<String, dynamic>>[];
    final boundFiles = <String>{};
    final keep = <int, int>{}; // old image index → new
    final kept = <Map>[];
    for (var i = 0; i < images.length; i++) {
      final image = Map<String, dynamic>.from(images[i]);
      final uri = image['uri'] as String?;
      if (uri == null || uri.startsWith('data:')) {
        keep[i] = kept.length;
        kept.add(image);
        for (final (material, slot) in users[i] ?? const <(String, String)>[]) {
          bound.add({'material': material, 'slot': slot, 'file': '', 'texture': image['name'] ?? '', 'source': 'embedded'});
        }
        continue;
      }
      String decoded;
      try {
        decoded = Uri.decodeFull(uri);
      } catch (_) {
        decoded = uri;
      }
      final fileName = decoded.replaceAll('\\', '/').split('/').last;
      final file = locator.locateReference(uri);
      final read = file == null ? null : _readImage(file);
      if (read == null) {
        missing.add(uri);
        for (final (material, slot) in users[i] ?? const <(String, String)>[]) {
          missingDetails.add({'material': material, 'slot': slot, 'path': decoded, 'file': fileName});
        }
        continue;
      }
      final padding = ((binLength + 3) & ~3) - binLength;
      if (padding > 0) bin.add(Uint8List(padding));
      final offset = binLength + padding;
      bin.add(read.bytes);
      binLength = offset + read.bytes.length;
      bufferViews.add(<String, dynamic>{'buffer': 0, 'byteOffset': offset, 'byteLength': read.bytes.length});
      image
        ..remove('uri')
        ..['bufferView'] = bufferViews.length - 1
        ..['mimeType'] = read.mime;
      // Named as the FBX named the file (the texture asset's name), not as
      // the copy that was found (`SM_Slot_Machine_T_Tread_Plate_Normal.png`).
      image['name'] ??= fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      embedded.add(file!.uri.pathSegments.last);
      boundFiles.add(file.absolute.path);
      for (final (material, slot) in users[i] ?? const <(String, String)>[]) {
        bound.add({'material': material, 'slot': slot, 'file': file.path, 'texture': image['name'], 'source': 'referenced'});
      }
      keep[i] = kept.length;
      kept.add(image);
    }

    // Textures whose image is gone go too; material slots that sampled them
    // are cleared, the others re-indexed.
    final textureMap = <int, int>{};
    final keptTextures = <Map>[];
    for (var t = 0; t < textures.length; t++) {
      final source = textures[t]['source'] as int?;
      if (source != null && !keep.containsKey(source)) continue;
      textureMap[t] = keptTextures.length;
      keptTextures.add({...textures[t], if (source != null) 'source': keep[source]});
    }
    void fixTextureRefs(Map node) {
      for (final key in node.keys.toList()) {
        final value = node[key];
        if (value is Map) {
          if ('$key'.endsWith('Texture') && value['index'] is int) {
            final mapped = textureMap[value['index'] as int];
            if (mapped == null) {
              node.remove(key);
            } else {
              value['index'] = mapped;
            }
          } else {
            fixTextureRefs(value);
          }
        }
      }
    }

    for (final m in materials) {
      fixTextureRefs(m);
      for (final (slot, _) in textureSlots(m).toList()) {
        _textureTakesOver(json, m, slot);
      }
    }
    if (kept.isEmpty) {
      json.remove('images');
    } else {
      json['images'] = kept;
    }
    if (keptTextures.isEmpty) {
      json.remove('textures');
      json.remove('samplers');
    } else {
      json['textures'] = keptTextures;
    }
    final merged = bin.takeBytes();
    json['bufferViews'] = bufferViews;
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];
    return (
      glb: GlbDocument(json, merged).encode(),
      embedded: embedded,
      missing: missing,
      missingDetails: missingDetails,
      bound: bound,
      boundFiles: boundFiles,
    );
  }

  /// Column-major 4×4 → translation, unit quaternion (x, y, z, w) and scale.
  /// A mirrored basis (negative determinant) is carried by a negative X scale.
  static ({List<double> translation, List<double> rotation, List<double> scale}) decomposeMatrix(List<double> m) {
    var sx = math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]);
    final sy = math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6]);
    final sz = math.sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10]);
    final det = m[0] * (m[5] * m[10] - m[9] * m[6]) - m[4] * (m[1] * m[10] - m[9] * m[2]) + m[8] * (m[1] * m[6] - m[5] * m[2]);
    if (det < 0) sx = -sx;
    double at(int col, int row, double s) => s == 0 ? 0 : m[col * 4 + row] / s;
    // Row-major rotation entries r<row><col>.
    final r00 = at(0, 0, sx), r10 = at(0, 1, sx), r20 = at(0, 2, sx);
    final r01 = at(1, 0, sy), r11 = at(1, 1, sy), r21 = at(1, 2, sy);
    final r02 = at(2, 0, sz), r12 = at(2, 1, sz), r22 = at(2, 2, sz);
    double x, y, z, w;
    final trace = r00 + r11 + r22;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2;
      w = 0.25 * s;
      x = (r21 - r12) / s;
      y = (r02 - r20) / s;
      z = (r10 - r01) / s;
    } else if (r00 > r11 && r00 > r22) {
      final s = math.sqrt(1.0 + r00 - r11 - r22) * 2;
      w = (r21 - r12) / s;
      x = 0.25 * s;
      y = (r01 + r10) / s;
      z = (r02 + r20) / s;
    } else if (r11 > r22) {
      final s = math.sqrt(1.0 + r11 - r00 - r22) * 2;
      w = (r02 - r20) / s;
      x = (r01 + r10) / s;
      y = 0.25 * s;
      z = (r12 + r21) / s;
    } else {
      final s = math.sqrt(1.0 + r22 - r00 - r11) * 2;
      w = (r10 - r01) / s;
      x = (r02 + r20) / s;
      y = (r12 + r21) / s;
      z = 0.25 * s;
    }
    final len = math.sqrt(x * x + y * y + z * z + w * w);
    if (len > 0) {
      x /= len;
      y /= len;
      z /= len;
      w /= len;
    }
    if (w < 0) {
      x = -x;
      y = -y;
      z = -z;
      w = -w;
    }
    // Snap float noise so identity rotations serialize as identity.
    double clean(double v) => v.abs() < 1e-7 ? 0.0 : v;
    return (
      translation: [clean(m[12]), clean(m[13]), clean(m[14])],
      rotation: [clean(x), clean(y), clean(z), w],
      scale: [sx, sy, sz],
    );
  }
}
