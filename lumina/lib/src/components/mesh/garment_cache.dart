import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/assets/glb_loader.dart';
import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';

/// A garment fitted to a body: the skinned GLB, the path it is served
/// under (a key the slot's asset provider answers) and how the fit went.
class LuminaFittedGarment {
  const LuminaFittedGarment(this.path, this.bytes, this.report);

  final String path;
  final Uint8List bytes;
  final LuminaGarmentFitReport report;
}

/// Garments fitted to bodies, each computed once on a worker isolate and
/// kept per (garment document, source mesh, reference body, target body)
/// content. A slot that gets the same garment on the same body again reuses
/// the fit; [capacity] bounds the memory.
class LuminaGarmentCache {
  LuminaGarmentCache({this.capacity = 24});

  /// The cache slots share.
  static final LuminaGarmentCache instance = LuminaGarmentCache();

  final int capacity;
  final Map<String, Future<LuminaFittedGarment>> _fits = {};

  /// How many fits ran (not served from the cache) since start.
  int computed = 0;

  int get length => _fits.length;

  /// The fit of [document] (its [source] mesh authored on [reference]) on
  /// [target], all GLB bytes; [name] names the garment's node.
  Future<LuminaFittedGarment> fit({
    required LuminaGarmentDocument document,
    required Uint8List source,
    required Uint8List reference,
    required Uint8List target,
    String name = 'garment',
  }) {
    final key = [
      LuminaMeshAssetCache.contentDigest(Uint8List.fromList(document.toJson().codeUnits)),
      LuminaMeshAssetCache.contentDigest(source),
      LuminaMeshAssetCache.contentDigest(reference),
      LuminaMeshAssetCache.contentDigest(target),
    ].join('/');
    final existing = _fits.remove(key);
    if (existing != null) {
      _fits[key] = existing; // most recent last
      return existing;
    }
    final json = document.toJson();
    final future = _runFit(json, source, reference, target, name).then((r) {
      computed++;
      return LuminaFittedGarment('garment:$name#${LuminaMeshAssetCache.contentDigest(r.$1)}', r.$1, r.$2);
    });
    _fits[key] = future;
    future.catchError((Object _) {
      _fits.remove(key);
      return LuminaFittedGarment('', _empty, _emptyReport);
    });
    while (_fits.length > capacity) {
      _fits.remove(_fits.keys.first);
    }
    return future;
  }

  void clear() => _fits.clear();

  static final Uint8List _empty = Uint8List(0);
  static const LuminaGarmentFitReport _emptyReport = LuminaGarmentFitReport(
    maxPenetration: 0,
    meanPenetration: 0,
    landmarkError: {},
    denseCorrespondence: false,
    milliseconds: 0,
    pushedVertices: 0,
  );
}

/// The fit on a worker isolate (a top-level function: the isolate gets the
/// bytes and nothing of the cache).
Future<(Uint8List, LuminaGarmentFitReport)> _runFit(String json, Uint8List source, Uint8List reference, Uint8List target, String name) =>
    Isolate.run(() => _fit(json, source, reference, target, name), debugName: 'garment fit');

LuminaSkinnedMeshData _read(Uint8List bytes) {
  try {
    return LuminaSkinnedMeshData.fromGlb(bytes, draco: LuminaGlbLoader.decoders.draco);
  } on UnsupportedError {
    return LuminaSkinnedMeshData.fromGlb(bytes);
  }
}

(Uint8List, LuminaGarmentFitReport) _fit(String json, Uint8List source, Uint8List reference, Uint8List target, String name) {
  final document = LuminaGarmentDocument.fromJson(json);
  // Finer than most garment meshes, so the push-out also holds between
  // the original vertices.
  final src = _read(source).refined(), ref = _read(reference), body = _read(target);
  final fit = LuminaGarmentFitter.fit(source: src, document: document, referenceBody: ref, targetBody: body);
  return (LuminaGarmentGlbWriter.write(fit: fit, source: src, targetBody: body, name: name), fit.report);
}
