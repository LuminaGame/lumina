import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_assimp/flutter_assimp.dart';

import 'fbx_import_service.dart';
import 'fbx_texture_locator.dart';
import 'obj_import_service.dart';

/// A model file Assimp could not convert.
class AssimpImportException implements Exception {
  final String message;
  const AssimpImportException(this.message);

  @override
  String toString() => message;
}

/// A Collada, 3DS, PLY, DirectX or STL file converted for the import
/// pipeline.
class AssimpImportResult {
  /// Binary glTF with every texture that was found embedded.
  final Uint8List glb;

  /// Each texture the file references that was found nowhere: `material`,
  /// `slot` (`baseColorMap`, …), `path` (as the file wrote it), `file`.
  final List<Map<String, dynamic>> missingTextures;

  /// Each texture file embedded, by the name it was found under.
  final List<String> embeddedTextures;

  const AssimpImportResult({required this.glb, required this.missingTextures, required this.embeddedTextures});
}

/// Every 3D format Assimp reads besides FBX and OBJ (which have their own
/// services) → GLB for the import pipeline.
///
/// The file is converted where it is, so everything it references relative
/// to itself resolves; the textures are then located like an FBX's
/// ([FbxTextureLocator]: as written, relative to the file, by name in any case
/// in its folder, the chosen texture folders and the usual `Textures/`
/// folders) and embedded. Units and axes are left as Assimp reads them
/// (Collada's `<unit>` and `<up_axis>` are applied by the importer).
abstract final class AssimpImportService {
  /// Whether [path] is imported through this service.
  static bool handles(String path) =>
      !FbxImportService.isFbx(path) && !ObjImportService.isObj(path) && FlutterAssimp.isSupportedFormat(path);

  /// [convertSync] in a background isolate.
  static Future<AssimpImportResult> convert(String path, {List<String> textureSearchDirs = const []}) =>
      Isolate.run(() => convertSync(path, textureSearchDirs: textureSearchDirs));

  /// Throws [AssimpImportException] when Assimp cannot read the file.
  static AssimpImportResult convertSync(String path, {List<String> textureSearchDirs = const []}) {
    final file = File(path);
    final conversion = FlutterAssimp.convertFileForImport(path, options: AssimpConvertOptions.normalize);
    if (!conversion.success) {
      throw AssimpImportException('Could not read "${file.uri.pathSegments.last}": ${conversion.error}');
    }
    final resolved = FbxImportService.resolveExternalImages(
      conversion.glb!,
      sourceDir: file.parent,
      locator: FbxTextureLocator(fbxFile: file, extraDirs: textureSearchDirs),
    );
    return AssimpImportResult(
      glb: resolved.glb,
      missingTextures: resolved.missingDetails,
      embeddedTextures: resolved.embedded,
    );
  }
}
