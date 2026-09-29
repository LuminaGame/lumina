/// What an importable file becomes.
enum ImportFormatKind {
  /// glTF / GLB, OBJ, FBX → a static or skeletal mesh (or an animation).
  mesh,

  /// PNG, JPEG, WebP, TGA → a texture.
  texture,

  /// WAV, OGG, MP3 → a sound.
  audio,

  /// A `.lmas` from another project, copied in as it is.
  asset,
}

/// The file types the import pipeline takes: the one
/// table [AssetRepository.stageImport] classifies by, the Content Browser's
/// file picker offers and the folder importer (`ImportFolderScanner`) walks.
class ImportFormats {
  const ImportFormats._();

  /// Lower-case extension (no dot) → what it imports as.
  static const Map<String, ImportFormatKind> byExtension = {
    'glb': ImportFormatKind.mesh,
    'gltf': ImportFormatKind.mesh,
    'obj': ImportFormatKind.mesh,
    'fbx': ImportFormatKind.mesh,
    'png': ImportFormatKind.texture,
    'jpg': ImportFormatKind.texture,
    'jpeg': ImportFormatKind.texture,
    'webp': ImportFormatKind.texture,
    'tga': ImportFormatKind.texture,
    'wav': ImportFormatKind.audio,
    'ogg': ImportFormatKind.audio,
    'mp3': ImportFormatKind.audio,
    'lmas': ImportFormatKind.asset,
  };

  /// Every importable extension, as a file picker's `allowedExtensions`.
  static List<String> get extensions => byExtension.keys.toList(growable: false);

  /// Files that only travel with a primary file (a `.gltf`'s buffers, an
  /// OBJ's material library) and never import on their own.
  static const Set<String> companionExtensions = {'bin', 'mtl'};

  /// Formats people try that the pipeline has no importer for, and why.
  static const Map<String, String> knownUnsupported = {
    'psd': 'Photoshop documents do not import; export the layers as PNG or TGA',
    'ktx': 'KTX textures have no importer yet; import the source PNG or TGA',
    'ktx2': 'KTX2 textures have no importer yet; import the source PNG or TGA',
    'hdr': 'HDR images have no importer yet (environment maps are set on the Sky actor)',
    'exr': 'OpenEXR images have no importer yet',
    'blend': 'Blender scenes do not import; export glTF or FBX from Blender',
    'max': '3ds Max scenes do not import; export FBX',
    'ma': 'Maya scenes do not import; export FBX',
    'mb': 'Maya scenes do not import; export FBX',
    'dds': 'DDS textures have no importer yet; import PNG or TGA',
    'flac': 'FLAC audio has no importer yet; import WAV or OGG',
  };

  /// The lower-case extension of [path] without the dot, or '' when none.
  static String extensionOf(String path) {
    final name = path.replaceAll(r'\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// What [path] imports as, or null when the pipeline does not take it.
  static ImportFormatKind? kindOf(String path) => byExtension[extensionOf(path)];

  static bool isImportable(String path) => kindOf(path) != null;

  /// Why [path] is not imported, or null when it is.
  static String? unsupportedReason(String path) {
    final ext = extensionOf(path);
    if (byExtension.containsKey(ext)) return null;
    final known = knownUnsupported[ext];
    if (known != null) return known;
    return ext.isEmpty ? 'no file extension' : 'unsupported file type .$ext';
  }

  /// The detected-kind label [AssetRepository.stageImport] reports for a
  /// non-glTF [path] ('texture', 'audio', 'static mesh').
  static String stagedKindOf(String path) => switch (kindOf(path)) {
        ImportFormatKind.texture => 'texture',
        ImportFormatKind.audio => 'audio',
        _ => 'static mesh',
      };
}
