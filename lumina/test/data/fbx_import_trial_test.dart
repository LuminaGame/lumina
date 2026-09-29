// The FBX import trial — every FBX
// under a folder through the real import pipeline (ImportAssetUseCase →
// AssetRepository: stage → convert → resolve → emit) into a real project that
// holds the Third Person mannequin, with a per-file report.
//
// Opt-in (it takes minutes on a large folder):
//   LUMINA_FBX_TRIAL_DIR=/path/to/fbx/files \
//   LUMINA_FBX_TRIAL_OUT=/some/dir \
//   flutter test test/data/fbx_import_trial_test.dart
// Writes <out>/fbx_trial_report.md and .json; the project is created under
// <out>/project and deleted afterwards.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  final trialDir = Platform.environment['LUMINA_FBX_TRIAL_DIR'];
  final outDir = Platform.environment['LUMINA_FBX_TRIAL_OUT'];

  test('FBX import trial through the real pipeline', () async {
    if (trialDir == null || outDir == null || !Directory(trialDir).existsSync()) {
      return markTestSkipped('set LUMINA_FBX_TRIAL_DIR and LUMINA_FBX_TRIAL_OUT to run the FBX import trial');
    }
    final quinn = File(LuminaThirdPersonContent.bundledMeshPath);
    expect(quinn.existsSync(), isTrue, reason: 'build tool/build_third_person_content.dart first');

    final out = Directory(outDir)..createSync(recursive: true);
    final project = Directory('${out.path}/project');
    if (project.existsSync()) project.deleteSync(recursive: true);
    Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
    File('${project.path}/${LuminaThirdPersonContent.projectMeshGlbPath}').writeAsBytesSync(quinn.readAsBytesSync());
    File('${project.path}/${LuminaThirdPersonContent.projectMeshAssetPath}').writeAsBytesSync(LuminaAsset(
      assetId: 'quinn-mesh',
      name: LuminaThirdPersonContent.meshAssetName,
      type: AssetType.filameshSk,
      metadata: {'payload_format': 'glb', 'animation_clips': LuminaThirdPersonContent.clipNames.join(',')},
    ).toProtoBufferBytes());

    final files = Directory(trialDir).listSync(recursive: true).whereType<File>().where((f) => FbxImportService.isFbx(f.path)).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final rows = <Map<String, dynamic>>[];
    final useCase = ImportAssetUseCase();

    try {
      for (final f in files) {
        final rel = f.path.substring(trialDir.length).replaceFirst(RegExp(r'^/'), '');
        final sw = Stopwatch()..start();
        final result = await useCase(projectDir: project.path, sourceFilePath: f.path);
        sw.stop();
        final row = <String, dynamic>{'file': rel, 'ms': sw.elapsedMilliseconds, 'ok': result.isSuccess};
        rows.add(row);
        if (!result.isSuccess) {
          row['error'] = result.error;
          continue;
        }
        final info = result.asset!;
        row['type'] = info.type.name;
        row['path'] = info.relativePath;
        final lmas = LuminaAsset.fromBytes(File('${project.path}/${info.relativePath}').readAsBytesSync());
        row['up_axis'] = lmas.metadata['fbx_up_axis'];
        row['unit_scale'] = lmas.metadata['import_unit_scale'];
        if (info.type == AssetType.filamesh || info.type == AssetType.filameshSk) {
          final mesh = await AssetRepository.loadMeshFromDisk('${project.path}/${info.relativePath}');
          if (mesh == null) {
            row['ok'] = false;
            row['error'] = 'imported, but the mesh loader cannot read it';
            continue;
          }
          // Editor size in cm, Z up (glTF metres, Y up → ×100, y↔z).
          final w = (mesh.maxBounds[0] - mesh.minBounds[0]) * 100;
          final d = (mesh.maxBounds[2] - mesh.minBounds[2]) * 100;
          final h = (mesh.maxBounds[1] - mesh.minBounds[1]) * 100;
          row['size_cm'] = [w, d, h].map((v) => double.parse(v.toStringAsFixed(1))).toList();
          row['min_up_cm'] = double.parse((mesh.minBounds[1] * 100).toStringAsFixed(1));
          // Upright: the FBX up axis became +Y and the prop rests on the
          // ground plane (its lowest point within 2 cm of y = 0).
          row['upright'] = lmas.metadata['fbx_up_axis'] == '+Z' && (mesh.minBounds[1] * 100).abs() <= 2.0;
          final hulls = lmas.metadata['collision_hulls'];
          row['collision_hulls'] = hulls == null ? 0 : (jsonDecode(hulls) as List).length;
          row['materials'] = lmas.references.where((r) => r.slotName.startsWith('material_slot_')).length;
        } else if (info.type == AssetType.animation) {
          row['clip'] = lmas.metadata['clip_name'];
          row['duration_s'] = lmas.metadata['duration_seconds'];
          row['retarget'] = lmas.metadata['retarget_status'];
          row['bound_to'] = lmas.metadata['source_mesh'];
          row['mapped_bones'] = lmas.metadata['retarget_mapped_bones'];
          row['pelvis_scale'] = lmas.metadata['retarget_pelvis_scale'];
          row['clip_index'] = lmas.metadata['clip_index'];
        }
      }

      // The mannequin GLB holds every bound clip, and the loader reads it.
      final meshGlb = File('${project.path}/${LuminaThirdPersonContent.projectMeshGlbPath}').readAsBytesSync();
      final clips = GlbAnimationMerger.animationNames(meshGlb);
      final parsed = await AssetRepository.loadMeshFromDisk('${project.path}/${LuminaThirdPersonContent.projectMeshAssetPath}');

      final report = StringBuffer()
        ..writeln('# FBX import trial — ${files.length} files from $trialDir')
        ..writeln()
        ..writeln('Assimp ${FlutterAssimp.version}; mannequin GLB: ${clips.length} clips, '
            '${(meshGlb.length / 1048576).toStringAsFixed(1)} MB, loader sees ${parsed?.animations.length ?? 0} animations.')
        ..writeln()
        ..writeln('| File | Result | Type | Size W×D×H cm | Upright | Hulls | Clip / retarget | ms |')
        ..writeln('|---|---|---|---|---|---|---|---|');
      for (final r in rows) {
        final size = r['size_cm'] == null ? '' : (r['size_cm'] as List).join(' × ');
        final clip = r['clip'] == null ? '' : '${r['clip']} (${r['duration_s']} s) → ${r['retarget']}; ${r['mapped_bones']} bones, pelvis ×${r['pelvis_scale']}';
        report.writeln('| ${r['file']} | ${r['ok'] == true ? 'OK' : 'FAIL: ${r['error']}'} | ${r['type'] ?? ''} | $size | '
            '${r['upright'] ?? ''} | ${r['collision_hulls'] ?? ''} | $clip | ${r['ms']} |');
      }
      File('${out.path}/fbx_trial_report.md').writeAsStringSync(report.toString());
      File('${out.path}/fbx_trial_report.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'files': rows,
        'mannequin_clips': clips,
        'mannequin_glb_bytes': meshGlb.length,
        'loader_animations': parsed?.animations.length,
      }));

      expect(rows.where((r) => r['ok'] != true).map((r) => '${r['file']}: ${r['error']}'), isEmpty);
    } finally {
      if (project.existsSync()) project.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
