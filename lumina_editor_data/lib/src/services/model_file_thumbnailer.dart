import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/services/fbx_import_service.dart';
import 'package:lumina_editor_data/src/services/filament_thumbnail_renderer.dart';
import 'package:lumina_editor_data/src/services/glb_parser_service.dart';
import 'package:lumina_editor_data/src/services/obj_import_service.dart';

/// Thumbnails of model files on disk that belong to no project: what a file
/// manager shows for a `.glb`, `.gltf`, `.fbx` or `.obj` once Lumina Studio is
/// installed. The file is turned into the GLB an import would make of it and
/// drawn by [FilamentThumbnailRenderer], so it looks like the Content
/// Browser's thumbnail of the same mesh.
abstract final class ModelFileThumbnailer {
  /// The file types the thumbnailer (and the editor's "Open with") handles.
  static const Set<String> supportedExtensions = {'.glb', '.gltf', '.fbx', '.obj'};

  static String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot).toLowerCase();
  }

  /// Whether [path] has one of the [supportedExtensions] (any case).
  static bool supports(String path) => supportedExtensions.contains(_extension(path));

  /// The GLB the renderer draws for [path], converted as an import converts
  /// it: a `.glb` as it is, a `.gltf` packed with the buffers and images
  /// beside it (a missing image drawn white), FBX and OBJ through Assimp; textures sanitised (TGA → PNG,
  /// texture budget) with the file's folder searched for them. Null when the
  /// file is missing, of another type or cannot be converted.
  static Future<Uint8List?> loadGlb(String path) async {
    if (!supports(path)) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final dir = file.parent.path;
    Uint8List? glb;
    switch (_extension(path)) {
      case '.glb':
        final bytes = await file.readAsBytes();
        // A truncated container never reaches the native loader.
        if (!isCompleteGlb(bytes)) return null;
        glb = bytes;
      case '.gltf':
        // Textures that were not copied along draw white: the preview still
        // shows the geometry.
        glb = await Isolate.run(() => GltfPacker.packFile(path, missingImage: _whitePixelPng()));
      case '.fbx':
        glb = (await FbxImportService.convert(path, textureSearchDirs: [dir])).glb;
      case '.obj':
        glb = (await ObjImportService.convert(path, textureSearchDirs: [dir]))?.glb;
    }
    if (glb == null || !_isGlb(glb)) return null;
    return GlbParserService.convertGlbTgaToPngAsync(glb, searchDirs: [dir]);
  }

  /// [path] rendered by [renderer] as a PNG, or null when the file could not
  /// be loaded or drew nothing. Errors while converting count as "could not
  /// be loaded" (a damaged file must never take the caller down).
  static Future<Uint8List?> render(String path, FilamentThumbnailRenderer renderer) async {
    final Uint8List? glb;
    try {
      glb = await loadGlb(path);
    } catch (_) {
      return null;
    }
    if (glb == null) return null;
    return renderer.renderMesh(glb);
  }

  static Uint8List _whitePixelPng() =>
      img.encodePng(img.Image(width: 1, height: 1)..clear(img.ColorRgb8(255, 255, 255)));

  static bool _isGlb(Uint8List b) =>
      b.length >= 20 && b[0] == 0x67 && b[1] == 0x6C && b[2] == 0x54 && b[3] == 0x46;

  /// Whether [bytes] can be handed to the renderer: a complete binary glTF
  /// container (the length in its header matches, the JSON chunk fits).
  static bool isCompleteGlb(Uint8List bytes) {
    if (!_isGlb(bytes)) return false;
    final data = ByteData.sublistView(bytes);
    final total = data.getUint32(8, Endian.little);
    if (total != bytes.length) return false;
    final jsonLength = data.getUint32(12, Endian.little);
    return 20 + jsonLength <= bytes.length;
  }
}

/// One `--lumina-thumbnail` invocation.
class ModelThumbnailRequest {
  final String input;
  final String output;
  final int size;

  const ModelThumbnailRequest({required this.input, required this.output, this.size = ModelThumbnailCommand.defaultSize});
}

/// `lumina_ui --lumina-thumbnail <input> <output.png> [--size <px>]`: the
/// installed editor run without a window to render one model file's
/// thumbnail, for the file managers (the Windows shell thumbnail provider and
/// the Linux `.thumbnailer` the installers register).
///
/// Exit codes follow `sysexits.h`: [exitOk], [exitUsage] (bad arguments),
/// [exitInput] (missing, unsupported or unreadable file), [exitRender] (the
/// engine could not start or drew nothing), [exitOutput] (the PNG could not
/// be written).
abstract final class ModelThumbnailCommand {
  static const String flag = '--lumina-thumbnail';
  static const int defaultSize = 256;
  static const int minSize = 16;
  static const int maxSize = 1024;

  static const int exitOk = 0;
  static const int exitUsage = 64;
  static const int exitInput = 65;
  static const int exitRender = 70;
  static const int exitOutput = 73;

  static const String usage = 'usage: lumina_ui $flag <input.glb|.gltf|.fbx|.obj> <output.png> [--size <px>]';

  /// The request in [args] (the editor's whole argument list), or an error
  /// message for [exitUsage].
  static ({ModelThumbnailRequest? request, String? error}) parse(List<String> args) {
    final positional = <String>[];
    String? sizeText;
    var seenFlag = false;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == flag) {
        seenFlag = true;
      } else if (a == '--size') {
        sizeText = i + 1 < args.length ? args[++i] : '';
      } else if (a.startsWith('--size=')) {
        sizeText = a.substring('--size='.length);
      } else if (seenFlag && !a.startsWith('--')) {
        positional.add(a);
      }
    }
    if (positional.length < 2) return (request: null, error: usage);
    var size = defaultSize;
    if (sizeText != null) {
      final parsed = int.tryParse(sizeText);
      if (parsed == null || parsed < minSize || parsed > maxSize) {
        return (request: null, error: 'size must be $minSize–$maxSize pixels, not "$sizeText"\n$usage');
      }
      size = parsed;
    }
    return (request: ModelThumbnailRequest(input: positional[0], output: positional[1], size: size), error: null);
  }

  /// Renders [request] and writes the PNG (through `<output>.tmp`, so a
  /// reader never sees half a file). [ibl] lights it like the editor's
  /// thumbnails (the bundled studio cubemap); without it the renderer's
  /// neutral ambient. Returns the exit code.
  static Future<int> run(ModelThumbnailRequest request, {Uint8List? ibl, void Function(String message)? log}) async {
    final say = log ?? (_) {};
    if (!ModelFileThumbnailer.supports(request.input)) {
      say('Not a supported model file: ${request.input}');
      return exitInput;
    }
    final Uint8List? glb;
    try {
      glb = await ModelFileThumbnailer.loadGlb(request.input);
    } catch (e) {
      say('Could not read ${request.input}: $e');
      return exitInput;
    }
    if (glb == null) {
      say('Could not read ${request.input}');
      return exitInput;
    }
    final renderer = FilamentThumbnailRenderer(size: request.size)..environmentIbl = ibl;
    final Uint8List? png;
    try {
      png = await renderer.renderMesh(glb);
    } finally {
      renderer.dispose();
    }
    if (png == null) {
      say('Nothing was rendered for ${request.input}');
      return exitRender;
    }
    final tmp = File('${request.output}.tmp');
    try {
      await tmp.parent.create(recursive: true);
      await tmp.writeAsBytes(png, flush: true);
      final target = File(request.output);
      if (await target.exists()) await target.delete();
      await tmp.rename(request.output);
    } on FileSystemException catch (e) {
      say('Could not write ${request.output}: $e');
      try {
        if (await tmp.exists()) await tmp.delete();
      } on FileSystemException catch (_) {}
      return exitOutput;
    }
    return exitOk;
  }
}
