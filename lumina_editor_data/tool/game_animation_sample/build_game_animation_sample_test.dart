// Builds the Game Animation Sample example project from a local export of
// the sample's animations. Run from lumina_editor_data:
//
//   LUMINA_GASP_EXPORT=<export folder> \
//   [LUMINA_GASP_MESH=contents/meshes/skeletal/SK_MH_X.lmas] \
//   [LUMINA_GASP_LEVEL=<level export .json>] [LUMINA_GASP_PROPS=<model files, ';'-separated>] \
//   [LUMINA_GASP_PROJECTS=<projects folder>] [LUMINA_GASP_PROJECT=game_animation_sample] \
//   [LUMINA_GASP_CATEGORIES=Walk,Run,...] \
//   flutter test tool/game_animation_sample/build_game_animation_sample_test.dart
//
// Without LUMINA_GASP_MESH it only creates the project (put the character's
// skeletal mesh into it, then run again). LUMINA_GASP_CHARACTER_ONLY=1 with
// LUMINA_GASP_MESH rewrites only the character, its Animation Blueprint, the
// game mode and the input of a built project (no export needed). Skips
// without LUMINA_GASP_EXPORT otherwise.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';

void main() {
  final env = Platform.environment;
  final exportRoot = env['LUMINA_GASP_EXPORT'];
  final characterOnly = env['LUMINA_GASP_CHARACTER_ONLY'] == '1';

  test('build the Game Animation Sample example project', () async {
    final projects = env['LUMINA_GASP_PROJECTS'] ?? '${LuminaWorkspace.home}/Lumina Projects';
    final name = env['LUMINA_GASP_PROJECT'] ?? 'game_animation_sample';
    final projectDir = await GameAnimationSampleBuilder.createProject(projects, name,
        onProgress: (p) => stdout.writeln('[create] ${p.message}'));
    stdout.writeln('Project: $projectDir');
    final mesh = env['LUMINA_GASP_MESH'];
    if (mesh == null || mesh.isEmpty) {
      stdout.writeln('No LUMINA_GASP_MESH: the project is created; add the character mesh and run again.');
      return;
    }
    if (characterOnly) {
      await GameAnimationSampleBuilder(projectDir: projectDir, meshAssetPath: mesh, log: stdout.writeln).updateCharacter();
      return;
    }
    final export = await GaspExport.open(exportRoot!);
    stdout.writeln('Export: ${export.sequences.length} clips, ${export.databases.length} pose search databases');
    final levelFile = env['LUMINA_GASP_LEVEL'];
    final level = levelFile == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(await File(levelFile).readAsString()) as Map);
    final categories = env['LUMINA_GASP_CATEGORIES']?.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toSet();
    final props = env['LUMINA_GASP_PROPS']?.split(';').where((p) => p.isNotEmpty).toList() ?? const <String>[];
    final report = await GameAnimationSampleBuilder(projectDir: projectDir, meshAssetPath: mesh, log: stdout.writeln)
        .build(export: export, categories: categories, levelExport: level, propFiles: props);
    final out = File('$projectDir/Saved/GameAnimationSample/report.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(report.toJson()));
    stdout.writeln('Report: ${out.path}');
    expect(report.import.clips, isNotEmpty);
  }, skip: exportRoot == null && !characterOnly ? 'LUMINA_GASP_EXPORT names no sample export' : false, timeout: Timeout.none);
}
