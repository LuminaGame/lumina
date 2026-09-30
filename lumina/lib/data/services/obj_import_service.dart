import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_assimp/flutter_assimp.dart';
import 'package:image/image.dart' as img;

import 'encoded_image_format.dart';
import 'fbx_import_service.dart';
import 'fbx_texture_locator.dart';
import 'glb_animation_merger.dart';
import 'tga_decoder_service.dart';

/// One `newmtl` block of a Wavefront `.mtl` file: the values the importer
/// maps to glTF. Texture paths are as written (options such as `-bm 1`
/// removed).
class MtlMaterial {
  MtlMaterial(this.name);

  final String name;

  /// `Kd`.
  List<double>? diffuse;

  /// `d` (dissolve), or `1 - Tr` when the file only has `Tr`.
  double? dissolve;
  double? _transparency;

  /// `map_Kd`.
  String? diffuseMap;

  /// `norm`, `map_Bump` / `bump` (exporters write the normal map there).
  String? normalMap;

  /// `map_d`.
  String? alphaMap;

  /// `map_Ks`.
  String? specularMap;

  /// The opacity the file declares: `d`, else `1 - Tr`, else 1.
  double get opacity => dissolve ?? (_transparency == null ? 1.0 : 1.0 - _transparency!);
}

/// An OBJ file converted for the import pipeline.
class ObjImportResult {
  /// Binary glTF: every material's MTL colour, opacity and texture maps,
  /// the textures that were found embedded.
  final Uint8List glb;

  /// The `mtllib` files the OBJ names, as written.
  final List<String> materialLibraries;

  /// The `mtllib` files that were found nowhere.
  final List<String> missingMaterialLibraries;

  /// Each texture the MTL names that was found nowhere: `path` (as the MTL
  /// wrote it), `file`, and `uses` — the (material, slot) pairs that wanted it.
  final List<({String path, String file, List<(String, String)> uses})> missingTextures;

  /// Each texture file embedded, by the name it was found under.
  final List<String> embeddedTextures;

  const ObjImportResult({
    required this.glb,
    required this.materialLibraries,
    required this.missingMaterialLibraries,
    required this.missingTextures,
    required this.embeddedTextures,
  });
}

/// OBJ → GLB for the import pipeline.
///
/// Assimp converts the geometry from the OBJ file itself; its glTF exporter
/// keeps an MTL's `Kd`, `d` and `map_Kd` but drops `Tr`, `map_Bump` /
/// `bump` / `norm`, `map_d` and `map_Ks`. The MTL is therefore read here as
/// well and applied to the glTF materials by name:
///
/// - `Kd` → base colour; `d` (or `1 - Tr`) below 1 → alpha, `BLEND`;
/// - `map_Kd` → base colour texture, `map_Bump` / `bump` / `norm` → normal
///   texture, `map_Ks` → `KHR_materials_specular` texture;
/// - `map_d` → the base colour texture's alpha (the diffuse image with the
///   `map_d` image as alpha, or the diffuse image's own alpha when both name
///   the same file); `MASK` when that alpha is cut-out (only fully opaque
///   or fully clear texels), `BLEND` otherwise.
///
/// Texture paths are resolved like an FBX's ([FbxTextureLocator]): as
/// written, relative to the OBJ, then by file name (any case) in the OBJ's
/// folder, the chosen texture folders and the usual `Textures/` folders.
/// Materials no mesh uses (Assimp's `DefaultMaterial`) are dropped.
abstract final class ObjImportService {
  static bool isObj(String path) => path.toLowerCase().endsWith('.obj');

  /// [convertSync] in a background isolate.
  static Future<ObjImportResult?> convert(String objPath, {List<String> textureSearchDirs = const []}) =>
      Isolate.run(() => convertSync(objPath, textureSearchDirs: textureSearchDirs));

  /// Null when Assimp cannot convert the file (the bridge is not loaded or
  /// the OBJ is unreadable).
  static ObjImportResult? convertSync(String objPath, {List<String> textureSearchDirs = const []}) {
    final objFile = File(objPath);
    final conversion = FlutterAssimp.convertFileForImport(objPath, options: 0);
    if (!conversion.success) return null;

    final libraries = materialLibraries(objFile.readAsStringSync());
    final missingLibraries = <String>[];
    final mtl = <String, MtlMaterial>{};
    for (final name in libraries) {
      final file = locateMaterialLibrary(objFile, name);
      if (file == null) {
        missingLibraries.add(name);
        continue;
      }
      for (final m in parseMtl(file.readAsStringSync())) {
        mtl.putIfAbsent(m.name, () => m);
      }
    }
    // Assimp falls back to `<obj name>.mtl` when no `mtllib` resolves.
    if (libraries.isEmpty || missingLibraries.length == libraries.length) {
      final fallback = locateMaterialLibrary(objFile, '${_stem(objFile.uri.pathSegments.last)}.mtl');
      if (fallback != null) {
        for (final m in parseMtl(fallback.readAsStringSync())) {
          mtl.putIfAbsent(m.name, () => m);
        }
        missingLibraries.clear();
      }
    }

    final locator = FbxTextureLocator(fbxFile: objFile, extraDirs: textureSearchDirs);
    final doc = GlbDocument.parse(conversion.glb!, label: objFile.uri.pathSegments.last);
    final json = doc.json;
    _dropUnusedMaterials(json);

    final scratch = Directory.systemTemp.createTempSync('lumina_obj_');
    try {
      final uses = <String, List<(String, String)>>{}; // MTL path → (material, slot)
      final unreadable = <String>[]; // alpha maps not found (or not images)
      final images = ((json['images'] as List?) ?? const []).cast<Map<String, dynamic>>().toList();
      final textures = ((json['textures'] as List?) ?? const []).cast<Map<String, dynamic>>().toList();
      int addTexture(String uri) {
        images.add(<String, dynamic>{'uri': uri, 'name': _stem(_fileName(uri))});
        textures.add(<String, dynamic>{'source': images.length - 1});
        return textures.length - 1;
      }

      for (final material in ((json['materials'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        final m = mtl['${material['name']}'];
        if (m == null) continue;
        final pbr = (material['pbrMetallicRoughness'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        material['pbrMetallicRoughness'] = pbr;
        final factor = [
          for (final c in (pbr['baseColorFactor'] as List?) ?? const [1, 1, 1, 1]) (c as num).toDouble(),
        ];
        final rgb = m.diffuse ?? factor.take(3).toList();
        var alpha = m.opacity;
        var alphaMode = alpha < 1 ? 'BLEND' : null;

        if (m.diffuseMap != null) {
          uses.putIfAbsent(m.diffuseMap!, () => []).add((m.name, 'baseColorMap'));
          if (pbr['baseColorTexture'] == null) pbr['baseColorTexture'] = {'index': addTexture(m.diffuseMap!)};
        }
        if (m.normalMap != null) {
          uses.putIfAbsent(m.normalMap!, () => []).add((m.name, 'normalMap'));
          material['normalTexture'] ??= {'index': addTexture(m.normalMap!)};
        }
        if (m.specularMap != null) {
          uses.putIfAbsent(m.specularMap!, () => []).add((m.name, 'specularMap'));
          final extensions = (material['extensions'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          material['extensions'] = extensions;
          extensions['KHR_materials_specular'] = {'specularTexture': {'index': addTexture(m.specularMap!)}};
          final used = ((json['extensionsUsed'] as List?) ?? const []).cast<String>().toSet()..add('KHR_materials_specular');
          json['extensionsUsed'] = used.toList();
        }
        if (m.alphaMap != null) {
          uses.putIfAbsent(m.alphaMap!, () => []).add((m.name, 'baseColorMap'));
          final alphaFile = locator.locateReference(m.alphaMap!);
          final alphaImage = alphaFile == null ? null : _decode(alphaFile);
          if (alphaImage == null) {
            unreadable.add(m.alphaMap!);
          } else {
            final diffuseFile = m.diffuseMap == null ? null : locator.locateReference(m.diffuseMap!);
            final sameFile = diffuseFile != null && diffuseFile.absolute.path == alphaFile!.absolute.path;
            final coverage = _alphaOf(alphaImage);
            if (!sameFile || !_hasAlpha(alphaImage)) {
              final base = diffuseFile == null ? null : _decode(diffuseFile);
              final baked = _withAlpha(base, coverage, alphaImage.width, alphaImage.height);
              final name = _stem(_fileName(m.diffuseMap ?? m.alphaMap!));
              final out = File('${scratch.path}/${images.length}_$name.png')..writeAsBytesSync(img.encodePng(baked));
              pbr['baseColorTexture'] = {'index': addTexture(out.path)};
              images.last['name'] = name;
            }
            alphaMode ??= _isCutout(coverage) ? 'MASK' : 'BLEND';
          }
        }

        pbr['baseColorFactor'] = [...rgb, alpha];
        if (alphaMode != null) {
          material['alphaMode'] = alphaMode;
        } else {
          material.remove('alphaMode');
        }
      }
      if (images.isNotEmpty) json['images'] = images;
      if (textures.isNotEmpty) json['textures'] = textures;

      final resolved = FbxImportService.resolveExternalImages(
        GlbDocument(json, doc.bin).encode(),
        sourceDir: objFile.parent,
        locator: locator,
      );
      final missing = <({String path, String file, List<(String, String)> uses})>[];
      final seen = <String>{};
      for (final uri in [...resolved.missing, ...unreadable]) {
        if (!seen.add(uri)) continue;
        missing.add((path: uri, file: _fileName(uri), uses: uses[uri] ?? const []));
      }
      return ObjImportResult(
        glb: resolved.glb,
        materialLibraries: libraries,
        missingMaterialLibraries: missingLibraries,
        missingTextures: missing,
        embeddedTextures: [
          for (final e in resolved.embedded)
            if (!File('${scratch.path}/$e').existsSync()) e,
        ],
      );
    } finally {
      try {
        scratch.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// The `mtllib` names of an OBJ's [source], in order. A name may contain
  /// spaces (the whole rest of the line, as Assimp reads it).
  static List<String> materialLibraries(String source) {
    final names = <String>[];
    for (final line in const LineSplitter().convert(source)) {
      final t = line.trim();
      if (!t.toLowerCase().startsWith('mtllib') || t.length < 7 || !_isSpace(t[6])) continue;
      final name = _stripComment(t.substring(7)).trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    return names;
  }

  /// The file an OBJ's `mtllib` [name] refers to: as written relative to the
  /// OBJ (or absolute), then by file name in any case in the OBJ's folder.
  static File? locateMaterialLibrary(File objFile, String name) {
    final path = name.replaceAll('\\', '/');
    for (final candidate in [File('${objFile.parent.path}/$path'), File(path)]) {
      if (candidate.existsSync()) return candidate;
    }
    final base = path.split('/').last.toLowerCase();
    try {
      for (final f in objFile.parent.listSync().whereType<File>()) {
        if (f.uri.pathSegments.last.toLowerCase() == base) return f;
      }
    } catch (_) {}
    return null;
  }

  /// The materials of an MTL [source].
  static List<MtlMaterial> parseMtl(String source) {
    final materials = <MtlMaterial>[];
    MtlMaterial? current;
    for (final raw in const LineSplitter().convert(source)) {
      final line = _stripComment(raw).trim();
      if (line.isEmpty) continue;
      final space = line.indexOf(RegExp(r'\s'));
      final keyword = (space < 0 ? line : line.substring(0, space)).toLowerCase();
      final rest = space < 0 ? '' : line.substring(space + 1).trim();
      if (keyword == 'newmtl') {
        current = MtlMaterial(rest);
        materials.add(current);
        continue;
      }
      final m = current;
      if (m == null) continue;
      switch (keyword) {
        case 'kd':
          final v = _numbers(rest);
          if (v.length >= 3) m.diffuse = v.take(3).toList();
        case 'd':
          final v = _numbers(rest);
          if (v.isNotEmpty) m.dissolve = v.first.clamp(0.0, 1.0);
        case 'tr':
          final v = _numbers(rest);
          if (v.isNotEmpty) m._transparency = v.first.clamp(0.0, 1.0);
        case 'map_kd':
          m.diffuseMap = _mapFile(rest);
        case 'map_bump' || 'bump' || 'norm' || 'map_norm' || 'map_kn':
          m.normalMap ??= _mapFile(rest);
        case 'map_d':
          m.alphaMap = _mapFile(rest);
        case 'map_ks':
          m.specularMap = _mapFile(rest);
      }
    }
    return materials;
  }

  /// Texture-map options: those taking one argument, and those taking up
  /// to three numbers.
  static const Set<String> _oneArgumentOptions = {
    '-blendu', '-blendv', '-bm', '-boost', '-cc', '-clamp', '-imfchan', '-texres', '-type',
  };
  static const Set<String> _numberOptions = {'-mm', '-o', '-s', '-t'};

  /// The file name of a `map_*` statement: the text after its options
  /// (spaces kept), or null when there is none.
  static String? _mapFile(String rest) {
    final tokens = RegExp(r'\S+').allMatches(rest).toList();
    var i = 0;
    while (i < tokens.length) {
      final option = tokens[i].group(0)!.toLowerCase();
      if (_oneArgumentOptions.contains(option)) {
        i += 2;
      } else if (_numberOptions.contains(option)) {
        i++;
        for (var n = 0; n < 3 && i < tokens.length && double.tryParse(tokens[i].group(0)!) != null; n++) {
          i++;
        }
      } else {
        break;
      }
    }
    if (i >= tokens.length) return null;
    final file = rest.substring(tokens[i].start).trim();
    return file.isEmpty ? null : file;
  }

  static List<double> _numbers(String rest) => [
        for (final t in rest.split(RegExp(r'\s+')))
          if (double.tryParse(t) != null) double.parse(t),
      ];

  static String _stripComment(String line) {
    final hash = line.indexOf('#');
    return hash < 0 ? line : line.substring(0, hash);
  }

  static bool _isSpace(String c) => c == ' ' || c == '\t';

  static String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Removes the materials no primitive uses and re-indexes the rest.
  static void _dropUnusedMaterials(Map<String, dynamic> json) {
    final materials = (json['materials'] as List?) ?? const [];
    final meshes = ((json['meshes'] as List?) ?? const []).cast<Map>();
    final used = <int>{};
    for (final mesh in meshes) {
      for (final p in ((mesh['primitives'] as List?) ?? const []).cast<Map>()) {
        if (p['material'] is int) used.add(p['material'] as int);
      }
    }
    if (used.length == materials.length) return;
    final remap = <int, int>{};
    final kept = [];
    for (var i = 0; i < materials.length; i++) {
      if (!used.contains(i)) continue;
      remap[i] = kept.length;
      kept.add(materials[i]);
    }
    for (final mesh in meshes) {
      for (final p in ((mesh['primitives'] as List?) ?? const []).cast<Map>()) {
        if (p['material'] is int) p['material'] = remap[p['material'] as int];
      }
    }
    json['materials'] = kept;
  }

  static img.Image? _decode(File file) {
    try {
      var raw = file.readAsBytesSync();
      if (EncodedImageFormat.sniff(raw) == EncodedImageFormat.tga) {
        final png = TgaDecoderService.tgaToPng(raw);
        if (png == null) return null;
        raw = png;
      }
      return img.decodeImage(raw);
    } catch (_) {
      return null;
    }
  }

  static bool _hasAlpha(img.Image image) {
    if (!image.hasAlpha) return false;
    for (final p in image) {
      if (p.aNormalized < 1) return true;
    }
    return false;
  }

  /// The coverage an alpha map gives, 0–255 per texel: its alpha channel
  /// when it has one that is not all opaque, else its luminance (the MTL
  /// convention for `map_d`).
  static img.Image _alphaOf(img.Image image) {
    final useAlpha = _hasAlpha(image);
    final out = img.Image(width: image.width, height: image.height, numChannels: 1);
    for (final p in image) {
      final v = useAlpha ? p.aNormalized : p.luminanceNormalized;
      out.setPixelR(p.x, p.y, (v * 255).round().clamp(0, 255));
    }
    return out;
  }

  /// A cut-out alpha: at most 10% of the texels between clear and opaque
  /// (anti-aliased edges).
  static bool _isCutout(img.Image coverage) {
    var partial = 0;
    for (final p in coverage) {
      final v = p.r;
      if (v > 25 && v < 230) partial++;
    }
    return partial <= coverage.width * coverage.height * 0.1;
  }

  /// [base] (white when null) with [coverage] as its alpha.
  static img.Image _withAlpha(img.Image? base, img.Image coverage, int width, int height) {
    final w = base?.width ?? width;
    final h = base?.height ?? height;
    final alpha = coverage.width == w && coverage.height == h ? coverage : img.copyResize(coverage, width: w, height: h);
    final out = img.Image(width: w, height: h, numChannels: 4);
    for (final p in out) {
      final src = base?.getPixel(p.x, p.y);
      p
        ..r = src == null ? 255 : (src.rNormalized * 255).round()
        ..g = src == null ? 255 : (src.gNormalized * 255).round()
        ..b = src == null ? 255 : (src.bNormalized * 255).round()
        ..a = alpha.getPixel(p.x, p.y).r;
    }
    return out;
  }
}
