import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/services/fbx_import_service.dart';

/// One FBX clip of the sample to retarget onto the character mesh.
class GaspClipJob {
  final String fbxPath;

  /// The glTF animation name (the FBX base name).
  final String name;

  /// The sample folder it came from (`Walk`, `Jump`, …).
  final String folder;

  /// Into the library asset instead of the character mesh.
  final bool library;

  /// Remove the root bone's height motion: jump and fall clips raise and
  /// drop the root, while in the game the capsule carries the arc.
  final bool removeRootHeight;

  const GaspClipJob({
    required this.fbxPath,
    required this.name,
    required this.folder,
    this.library = false,
    this.removeRootHeight = false,
  });

  Map<String, Object> toMessage() =>
      {'fbx': fbxPath, 'name': name, 'folder': folder, 'library': library, 'height': removeRootHeight};

  factory GaspClipJob.fromMessage(Map<Object?, Object?> m) => GaspClipJob(
        fbxPath: m['fbx']! as String,
        name: m['name']! as String,
        folder: m['folder']! as String,
        library: m['library']! as bool,
        removeRootHeight: m['height']! as bool,
      );
}

/// A clip retargeted onto the character mesh (or its library asset).
class GaspImportedClip {
  final String name;
  final String folder;
  final bool library;

  /// The animation asset metadata (`AnimationImportBinder.clipMetadata`).
  final Map<String, String> metadata;
  final double duration;

  const GaspImportedClip(this.name, this.folder, this.library, this.metadata, this.duration);
}

/// What [GaspAnimationImport.run] produced.
class GaspImportOutcome {
  /// The character mesh GLB with the runtime clips, and the library GLB with
  /// the rest (null when no clip went there).
  final Uint8List meshGlb;
  final Uint8List? libraryGlb;
  final List<GaspImportedClip> clips;

  /// Clip name → why it failed.
  final Map<String, String> failures;

  /// Wall time, and the summed time of the FBX conversions and of the
  /// retargets.
  final Duration elapsed;
  final Duration convertTime;
  final Duration retargetTime;

  const GaspImportOutcome({
    required this.meshGlb,
    required this.libraryGlb,
    required this.clips,
    required this.failures,
    required this.elapsed,
    required this.convertTime,
    required this.retargetTime,
  });
}

/// Progress of a running import: clips done of [total], the last clip.
typedef GaspImportProgress = void Function(int done, int total, String clip);

/// The sample's FBX clips retargeted onto a skeletal mesh, off the UI
/// isolate: a worker isolate converts [converters] FBX files at a time on
/// their own isolates (`FbxImportService.convert`) while it retargets the
/// finished ones in order into two [GlbRetargetBatch]es of the mesh GLB, the
/// character mesh's and the library's, and encodes each once.
abstract final class GaspAnimationImport {
  static Future<GaspImportOutcome> run({
    required Uint8List meshGlb,
    required List<GaspClipJob> jobs,
    required String meshAssetPath,
    required String libraryAssetPath,
    int converters = 6,
    GaspImportProgress? onProgress,
  }) async {
    final port = ReceivePort();
    final done = Completer<GaspImportOutcome>();
    final watch = Stopwatch()..start();
    port.listen((message) {
      final m = message as Map<Object?, Object?>;
      switch (m['kind']) {
        case 'progress':
          onProgress?.call(m['done']! as int, m['total']! as int, m['clip']! as String);
        case 'error':
          port.close();
          done.completeError(StateError('${m['error']}'));
        case 'done':
          port.close();
          final clips = [
            for (final c in (m['clips']! as List).cast<Map<Object?, Object?>>())
              GaspImportedClip(c['name']! as String, c['folder']! as String, c['library']! as bool,
                  Map<String, String>.from(c['metadata']! as Map), (c['duration']! as num).toDouble()),
          ];
          final library = m['library'] as TransferableTypedData?;
          done.complete(GaspImportOutcome(
            meshGlb: (m['mesh']! as TransferableTypedData).materialize().asUint8List(),
            libraryGlb: library?.materialize().asUint8List(),
            clips: clips,
            failures: Map<String, String>.from(m['failures']! as Map),
            elapsed: watch.elapsed,
            convertTime: Duration(microseconds: m['convert']! as int),
            retargetTime: Duration(microseconds: m['retarget']! as int),
          ));
      }
    });
    await Isolate.spawn(_worker, {
      'port': port.sendPort,
      'glb': TransferableTypedData.fromList([meshGlb]),
      'jobs': [for (final j in jobs) j.toMessage()],
      'mesh': meshAssetPath,
      'libraryPath': libraryAssetPath,
      'converters': converters,
    }, onError: port.sendPort, errorsAreFatal: true);
    return done.future;
  }

  static Future<void> _worker(Map<String, Object?> args) async {
    final port = args['port']! as SendPort;
    try {
      final glb = (args['glb']! as TransferableTypedData).materialize().asUint8List();
      final jobs = [for (final j in (args['jobs']! as List).cast<Map<Object?, Object?>>()) GaspClipJob.fromMessage(j)];
      final meshPath = args['mesh']! as String;
      final libraryPath = args['libraryPath']! as String;
      final converters = math.max(1, args['converters']! as int);
      final main = GlbRetargetBatch(glb);
      final library = jobs.any((j) => j.library) ? GlbRetargetBatch(glb) : null;
      final clips = <Map<String, Object>>[];
      final failures = <String, String>{};
      var convertMicros = 0, retargetMicros = 0;

      Future<(FbxImportResult?, int, Object?)> convert(GaspClipJob job) async {
        final w = Stopwatch()..start();
        try {
          final r = await FbxImportService.convert(job.fbxPath);
          return (r, w.elapsedMicroseconds, null);
        } catch (e) {
          return (null, w.elapsedMicroseconds, e);
        }
      }

      final pending = <Future<(FbxImportResult?, int, Object?)>>[];
      for (var i = 0; i < math.min(converters, jobs.length); i++) {
        pending.add(convert(jobs[i]));
      }
      for (var i = 0; i < jobs.length; i++) {
        final job = jobs[i];
        final (result, micros, error) = await pending[i];
        if (i + converters < jobs.length) pending.add(convert(jobs[i + converters]));
        pending[i] = Future.value((null, 0, null)); // release the bytes
        convertMicros += micros;
        if (result == null) {
          failures[job.name] = '$error';
        } else {
          final w = Stopwatch()..start();
          try {
            final clip = job.removeRootHeight ? removeRootHeight(result.glb) : result.glb;
            final batch = job.library ? library! : main;
            final r = batch.add(clip: clip, clipName: job.name);
            clips.add({
              'name': job.name,
              'folder': job.folder,
              'library': job.library,
              'duration': r.duration,
              'metadata': AnimationImportBinder.clipMetadata(job.library ? libraryPath : meshPath, r),
            });
          } catch (e) {
            failures[job.name] = '$e';
          }
          retargetMicros += w.elapsedMicroseconds;
        }
        port.send({'kind': 'progress', 'done': i + 1, 'total': jobs.length, 'clip': job.name});
      }
      final mainGlb = main.finish().glb;
      final libraryGlb = library?.finish().glb;
      port.send({
        'kind': 'done',
        'mesh': TransferableTypedData.fromList([mainGlb]),
        'library': libraryGlb == null ? null : TransferableTypedData.fromList([libraryGlb]),
        'clips': clips,
        'failures': failures,
        'convert': convertMicros,
        'retarget': retargetMicros,
      });
    } catch (e, s) {
      port.send({'kind': 'error', 'error': '$e\n$s'});
    }
  }

  /// [clip] with the root bone's height motion removed: every translation
  /// key of the node named [root] is held at the root's rest height
  /// (measured along world up, glTF +Y, in the root's parent frame), so the
  /// body moves relative to the root as before but no longer rises or falls
  /// with it. The rest height, not the first key's: a landing clip starts
  /// with its root metres up in the air. A clip without such a channel comes
  /// back unchanged.
  static Uint8List removeRootHeight(Uint8List clip, {String root = 'root'}) {
    final doc = GlbDocument.parse(clip, label: 'clip');
    final nodes = ((doc.json['nodes'] as List?) ?? const []).cast<Map>();
    final index = nodes.indexWhere((n) => n['name'] == root);
    if (index < 0) return clip;
    final parent = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final c in (nodes[i]['children'] as List?) ?? const []) {
        if (c is int && c >= 0 && c < nodes.length) parent[c] = i;
      }
    }
    // World up in the root's parent frame: the inverse of the parents'
    // rest rotations applied to +Y.
    var up = [0.0, 1.0, 0.0];
    final chain = <int>[];
    for (var p = parent[index]; p >= 0; p = parent[p]) {
      chain.add(p);
    }
    for (final p in chain.reversed) {
      final r = (nodes[p]['rotation'] as List?)?.map((v) => (v as num).toDouble()).toList();
      if (r != null && r.length == 4) up = _rotate([-r[0], -r[1], -r[2], r[3]], up);
    }
    final accessors = ((doc.json['accessors'] as List?) ?? const []).cast<Map>();
    final views = ((doc.json['bufferViews'] as List?) ?? const []).cast<Map>();
    final data = ByteData.sublistView(doc.bin);
    var changed = false;
    for (final a in ((doc.json['animations'] as List?) ?? const []).cast<Map>()) {
      final samplers = ((a['samplers'] as List?) ?? const []).cast<Map>();
      for (final c in ((a['channels'] as List?) ?? const []).cast<Map>()) {
        final target = c['target'] as Map?;
        if (target?['node'] != index || target?['path'] != 'translation') continue;
        final accessor = accessors[samplers[c['sampler'] as int]['output'] as int];
        final view = views[accessor['bufferView'] as int];
        final stride = (view['byteStride'] as int?) ?? 12;
        final base = ((view['byteOffset'] as int?) ?? 0) + ((accessor['byteOffset'] as int?) ?? 0);
        final count = accessor['count'] as int;
        if (count == 0 || accessor['componentType'] != 5126) continue;
        double height(int k) {
          final o = base + k * stride;
          return data.getFloat32(o, Endian.little) * up[0] +
              data.getFloat32(o + 4, Endian.little) * up[1] +
              data.getFloat32(o + 8, Endian.little) * up[2];
        }

        final rest = ((nodes[index]['translation'] as List?) ?? const [0, 0, 0]).map((v) => (v as num).toDouble()).toList();
        final keep = rest[0] * up[0] + rest[1] * up[1] + rest[2] * up[2];
        for (var k = 0; k < count; k++) {
          final d = height(k) - keep;
          final o = base + k * stride;
          for (var axis = 0; axis < 3; axis++) {
            final v = data.getFloat32(o + axis * 4, Endian.little) - d * up[axis];
            data.setFloat32(o + axis * 4, v, Endian.little);
          }
        }
        accessor.remove('min');
        accessor.remove('max');
        changed = true;
      }
    }
    return changed ? GlbDocument(doc.json, doc.bin).encode() : clip;
  }

  /// [v] rotated by the unit quaternion [q] (x, y, z, w).
  static List<double> _rotate(List<double> q, List<double> v) {
    final (x, y, z, w) = (q[0], q[1], q[2], q[3]);
    final tx = 2 * (y * v[2] - z * v[1]), ty = 2 * (z * v[0] - x * v[2]), tz = 2 * (x * v[1] - y * v[0]);
    return [
      v[0] + w * tx + (y * tz - z * ty),
      v[1] + w * ty + (z * tx - x * tz),
      v[2] + w * tz + (x * ty - y * tx),
    ];
  }
}
