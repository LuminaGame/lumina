import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_mesh_loader.dart';

/// The workspace's shared models, or null when they are missing.
String? _testAssets() {
  final dir = Platform.environment['LUMINA_TEST_ASSETS'] ?? '../../test-assets';
  return Directory(dir).existsSync() ? Directory(dir).absolute.path : null;
}

/// The longest stretch, in ms, the current isolate's event loop went without
/// running a 1 ms periodic timer while [work] ran.
Future<(T, int)> _longestStall<T>(Future<T> Function() work) async {
  final watch = Stopwatch()..start();
  var last = 0;
  var longest = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = watch.elapsedMilliseconds;
    if (now - last > longest) longest = now - last;
    last = now;
  });
  final result = await work();
  final now = watch.elapsedMilliseconds;
  if (now - last > longest) longest = now - last;
  timer.cancel();
  return (result, longest);
}

void main() {
  final assets = _testAssets();
  final skip = assets == null ? 'test-assets missing (set LUMINA_TEST_ASSETS)' : null;
  late Directory project;
  late Uint8List mannequin;

  setUp(() async {
    Plugin3DViewportMeshLoader.clear();
    Plugin3DViewportMeshLoader.workerThreshold = 8 * 1024 * 1024;
    project = await Directory.systemTemp.createTemp('p3d_');
    if (assets != null) mannequin = await File('$assets/mannequin/SKM_Manny_Simple.glb').readAsBytes();
  });
  tearDown(() async {
    Plugin3DViewportMeshLoader.workerThreshold = 8 * 1024 * 1024;
    await project.delete(recursive: true);
  });

  /// A skeletal mesh asset whose GLB is its `.entity.glb` companion, the way
  /// a MetaHuman mesh is stored; returns its project-relative `.lmas` path.
  Future<String> writeMesh(String name) async {
    const rel = 'contents/meshes/skeletal';
    await Directory('${project.path}/$rel').create(recursive: true);
    await File('${project.path}/$rel/$name.lmas').writeAsBytes(
      LuminaAsset(assetId: name, name: name, type: AssetType.filameshSk).toProtoBufferBytes(),
    );
    await File('${project.path}/$rel/$name.entity.glb').writeAsBytes(mannequin);
    return '$rel/$name.lmas';
  }

  test('a large skeletal mesh is read and parsed on a worker isolate while the UI isolate keeps running', () async {
    final rel = await writeMesh('SK_Large');
    Plugin3DViewportMeshLoader.workerThreshold = 0;
    final workers = Plugin3DViewportMeshLoader.workerCount;

    final (mesh, stall) = await _longestStall(
      () => Plugin3DViewportMeshLoader.load(rel, projectDir: project.path),
    );

    expect(Plugin3DViewportMeshLoader.workerCount, workers + 1);
    expect(mesh, isNotNull);
    expect(mesh!.positions, isNotEmpty);
    expect(mesh.skeletonJointIndices, isNotEmpty, reason: 'a skeletal mesh keeps its joints');
    final inline = await GlbParserService.parseGlb(mannequin);
    expect(mesh.positions.length, inline!.positions.length);
    expect(stall, lessThan(250), reason: 'the UI isolate is never blocked by the read or the parse');
  }, skip: skip);

  test('reopening the same mesh does not read it again; a saved mesh is read again', () async {
    final rel = await writeMesh('SK_Again');
    final first = await Plugin3DViewportMeshLoader.load(rel, projectDir: project.path);
    final parsed = Plugin3DViewportMeshLoader.parsedCount;
    final again = await Plugin3DViewportMeshLoader.load(rel, projectDir: project.path);
    expect(identical(again, first), isTrue);
    expect(Plugin3DViewportMeshLoader.parsedCount, parsed);

    final companion = File('${project.path}/contents/meshes/skeletal/SK_Again.entity.glb');
    await companion.setLastModified(DateTime.now().add(const Duration(seconds: 5)));
    final reread = await Plugin3DViewportMeshLoader.load(rel, projectDir: project.path);
    expect(identical(reread, first), isFalse);
    expect(Plugin3DViewportMeshLoader.parsedCount, parsed + 1);
  }, skip: skip);

  test('an absolute .glb path and a missing mesh', () async {
    final glb = File('${project.path}/m.glb');
    await glb.writeAsBytes(mannequin);
    expect(await Plugin3DViewportMeshLoader.load(glb.path), isNotNull);
    expect(await Plugin3DViewportMeshLoader.load('contents/meshes/none.lmas', projectDir: project.path), isNull);
  }, skip: skip);

  test('the viewport container no longer reads meshes synchronously', () async {
    final source = await File('lib/ui/core/plugin_3d_viewport_container.dart').readAsString();
    expect(source, isNot(contains('Sync(')));
    expect(source, isNot(contains('AnimationImportBinder.meshGlb')));
    expect(source, contains('Plugin3DViewportMeshLoader'));
  });
}
