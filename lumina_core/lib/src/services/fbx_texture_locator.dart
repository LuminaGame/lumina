import 'dart:io';

/// A texture channel an image beside an FBX can be matched to by its name,
/// and the glTF slot it fills.
enum FbxTextureChannel {
  baseColor('BaseColor', 'baseColorMap'),
  normal('Normal', 'normalMap'),
  emissive('Emissive', 'emissiveMap'),
  // Packed occlusion (R) / roughness (G) / metallic (B), glTF's layout.
  orm('ORM', 'metallicRoughnessMap'),
  occlusion('AO', 'occlusionMap');

  const FbxTextureChannel(this.suffix, this.slot);

  /// The suffix of the texture asset the importer names it by (`T_<core>_<suffix>`).
  final String suffix;

  /// The `.lmas` material sampler / glTF slot it fills.
  final String slot;
}

/// Where the textures of an FBX are looked for, in order — the path as
/// written, then relative to the FBX — plus the folders people keep textures in:
///
/// - **near folders** (searched first, and the only ones whose images are
///   matched to materials by name): the folders chosen in the import options,
///   the FBX's folder, and its `Textures/`, `textures/`, `<fbx name>/` and
///   `<fbx name>.fbm/` subfolders (`.fbm` is where the FBX SDK extracts
///   embedded media);
/// - **reference folders** (a referenced file name only): the near folders,
///   then the `Textures`/`textures`/`Texturen`/`Materials` folders of the
///   FBX's folder and its three nearest ancestors, with their direct
///   subfolders.
class FbxTextureLocator {
  FbxTextureLocator({required this.fbxFile, List<String> extraDirs = const []})
      : extraDirs = [for (final d in extraDirs) if (d.trim().isNotEmpty) d];

  final File fbxFile;
  final List<String> extraDirs;

  static const _imageExtensions = {'png', 'jpg', 'jpeg', 'tga'};

  Directory get sourceDir => fbxFile.parent;

  String get _fbxBaseName {
    final name = fbxFile.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  late final List<Directory> nearDirs = _existing([
    for (final d in extraDirs) Directory(d),
    sourceDir,
    for (final name in ['Textures', 'textures', _fbxBaseName, '$_fbxBaseName.fbm']) Directory('${sourceDir.path}/$name'),
  ]);

  late final List<Directory> referenceDirs = () {
    final found = [...nearDirs];
    var d = sourceDir;
    for (var i = 0; i < 4; i++) {
      for (final name in const ['Textures', 'textures', 'Texturen', 'Materials']) {
        final t = Directory('${d.path}/$name');
        if (!t.existsSync()) continue;
        found.add(t);
        try {
          found.addAll(t.listSync().whereType<Directory>());
        } catch (_) {}
      }
      if (d.parent.path == d.path) break;
      d = d.parent;
    }
    return _existing(found);
  }();

  /// Every image file in the [nearDirs], each once.
  late final List<File> nearImages = () {
    final seen = <String>{};
    final images = <File>[];
    for (final dir in nearDirs) {
      for (final f in _files(dir)) {
        final name = f.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        if (dot < 0 || !_imageExtensions.contains(name.substring(dot + 1).toLowerCase())) continue;
        if (seen.add(f.absolute.path)) images.add(f);
      }
    }
    images.sort((a, b) => a.path.compareTo(b.path));
    return images;
  }();

  /// The file an FBX texture reference [uri] names: as written, relative to
  /// the FBX (each with its folders and file matched in any case when that
  /// spelling is not on disk, see [findIgnoringCase]), then by file name
  /// (case-insensitive) in the [referenceDirs], then as an image in the
  /// [nearDirs] whose name ends in `_<file name>` (an exporter that prefixed
  /// the asset's name, e.g. Godot's `SM_Slot_Machine_T_Tread_Plate_Normal.png`).
  File? locateReference(String uri) {
    String decoded;
    try {
      decoded = Uri.decodeFull(uri);
    } catch (_) {
      decoded = uri;
    }
    decoded = decoded.replaceAll('\\', '/');
    for (final candidate in [File(decoded), File('${sourceDir.path}/$decoded')]) {
      if (candidate.existsSync()) return candidate;
    }
    final anyCase = _isAbsolute(decoded) ? findIgnoringCase(decoded) : findIgnoringCase(decoded, base: sourceDir);
    if (anyCase != null) return anyCase;
    final fileName = decoded.split('/').last;
    if (fileName.isEmpty) return null;
    for (final dir in referenceDirs) {
      final found = pickIgnoringCase(_files(dir), fileName);
      if (found != null) return found;
    }
    final base = fileName.toLowerCase();
    for (final f in nearImages) {
      final name = f.uri.pathSegments.last.toLowerCase();
      if (name.endsWith('_$base') || name.endsWith('-$base')) return f;
    }
    return null;
  }

  /// Every channel suffix, as lower-case token sequences at the end of a
  /// file name.
  static const Map<FbxTextureChannel, List<List<String>>> _suffixes = {
    FbxTextureChannel.baseColor: [
      ['base', 'color'], ['basecolor'], ['albedo'], ['diffuse'], ['color'], ['col'], ['bc'], ['d'],
    ],
    FbxTextureChannel.normal: [
      ['normal'], ['normals'], ['normalmap'], ['nrm'], ['norm'], ['n'],
    ],
    FbxTextureChannel.emissive: [
      ['emissive'], ['emission'], ['emit'], ['glow'], ['e'],
    ],
    FbxTextureChannel.orm: [
      ['orm'], ['arm'], ['occlusion', 'roughness', 'metallic'],
    ],
    FbxTextureChannel.occlusion: [
      ['ao'], ['occlusion'], ['ambient', 'occlusion'], ['ambientocclusion'],
    ],
  };

  static List<String> _tokens(String s) =>
      s.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();

  /// The channel a file name (without extension) ends in, and how many of
  /// its tokens the suffix takes.
  static (FbxTextureChannel, int)? channelOf(String stem) {
    final tokens = _tokens(stem);
    (FbxTextureChannel, int)? best;
    for (final entry in _suffixes.entries) {
      for (final suffix in entry.value) {
        if (suffix.length >= tokens.length) continue;
        var match = true;
        for (var i = 0; i < suffix.length; i++) {
          if (tokens[tokens.length - suffix.length + i] != suffix[i]) {
            match = false;
            break;
          }
        }
        if (match && (best == null || suffix.length > best.$2)) best = (entry.key, suffix.length);
      }
    }
    return best;
  }

  /// A material name without its asset-type prefix (`MI_`, `M_`, `Mat_`,
  /// `Material_`).
  static String coreName(String material) =>
      material.replaceFirst(RegExp(r'^(MI|M|Mat|Material)_', caseSensitive: false), '');

  /// The images of the [nearDirs] matched to [materials] by name: a file
  /// matches a material when its name holds the material's name (or its
  /// [coreName]) as whole tokens before a channel suffix — `T_Wood_BaseColor`
  /// for `M_Wood`, `SM_Slot_Machine_MI_Neon_Green_SM_Slot_Machine_Emissive`
  /// for `MI_Neon_Green`. A file goes to the material with the longest
  /// matching name (`MI_Plastic_Black_Matte_1_Normal` belongs to
  /// `MI_Plastic_Black_Matte_1`, not `MI_Plastic_Black`); files in [exclude]
  /// (already bound by reference) are skipped. Result: material index →
  /// channel → file (the first by path when several fit).
  Map<int, Map<FbxTextureChannel, File>> matchByName(List<String> materials, {Set<String> exclude = const {}}) {
    final result = <int, Map<FbxTextureChannel, File>>{};
    final candidates = [
      for (var i = 0; i < materials.length; i++)
        (index: i, names: {_tokens(materials[i]).join(' '), _tokens(coreName(materials[i])).join(' ')}..removeWhere((n) => n.isEmpty)),
    ];
    for (final file in nearImages) {
      if (exclude.contains(file.absolute.path)) continue;
      final name = file.uri.pathSegments.last;
      final stem = name.substring(0, name.lastIndexOf('.'));
      final channel = channelOf(stem);
      if (channel == null) continue;
      final tokens = _tokens(stem);
      final body = ' ${tokens.sublist(0, tokens.length - channel.$2).join(' ')} ';
      int? bestIndex;
      var bestLength = 0;
      for (final c in candidates) {
        for (final n in c.names) {
          if (n.length > bestLength && body.contains(' $n ')) {
            bestLength = n.length;
            bestIndex = c.index;
          }
        }
      }
      if (bestIndex == null) continue;
      result.putIfAbsent(bestIndex, () => {}).putIfAbsent(channel.$1, () => file);
    }
    return result;
  }

  /// The file [path] (`/`- or `\`-separated; relative to [base], or absolute)
  /// names where its folders or file are spelled with other capitals than on
  /// a case-sensitive disk: each segment goes to the entry of that name in any
  /// case ([pickIgnoringCase]). `.` and `..` are followed as written. Null
  /// when a segment has no match. (A case-insensitive file system finds these
  /// by the exact lookup already.)
  static File? findIgnoringCase(String path, {Directory? base}) {
    var segments = path.replaceAll('\\', '/').split('/');
    String dir;
    if (_isAbsolute(path)) {
      // The root ("/" or "C:/") as written.
      dir = segments.first.isEmpty ? '/' : '${segments.first}/';
      segments = segments.skip(1).toList();
    } else if (base != null) {
      dir = base.path;
    } else {
      return null;
    }
    segments = [for (final s in segments) if (s.isNotEmpty && s != '.') s];
    for (var i = 0; i < segments.length; i++) {
      final last = i == segments.length - 1;
      if (segments[i] == '..') {
        if (last) return null;
        dir = Directory(dir).parent.path;
        continue;
      }
      final List<FileSystemEntity> entries;
      try {
        entries = [for (final e in Directory(dir).listSync()) if (last ? e is File : e is Directory) e];
      } catch (_) {
        return null;
      }
      final match = pickIgnoringCase(entries, segments[i]);
      if (match == null) return null;
      if (last) return match as File;
      dir = match.path;
    }
    return null;
  }

  /// The entry of [entries] named [name] in any case: the one spelled
  /// exactly so when there is one, else the first by name (code units), so
  /// the choice never depends on the order the directory was listed in.
  static T? pickIgnoringCase<T extends FileSystemEntity>(Iterable<T> entries, String name) {
    final lower = name.toLowerCase();
    final matches = [for (final e in entries) if (_nameOf(e).toLowerCase() == lower) e];
    if (matches.isEmpty) return null;
    for (final e in matches) {
      if (_nameOf(e) == name) return e;
    }
    matches.sort((a, b) => _nameOf(a).compareTo(_nameOf(b)));
    return matches.first;
  }

  static String _nameOf(FileSystemEntity e) => e.path.replaceAll('\\', '/').split('/').lastWhere((s) => s.isNotEmpty, orElse: () => '');

  static bool _isAbsolute(String path) => path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path);

  static List<Directory> _existing(List<Directory> dirs) {
    final seen = <String>{};
    return [
      for (final d in dirs)
        if (d.existsSync() && seen.add(d.absolute.path)) d,
    ];
  }

  static List<File> _files(Directory dir) {
    try {
      return dir.listSync().whereType<File>().toList();
    } catch (_) {
      return const [];
    }
  }
}
