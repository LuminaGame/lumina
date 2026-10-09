import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show FilamentMaterialBuilder, FilamatShading;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

import '../helpers/flutter_build_stand_in.dart';

/// Every scenario runs against a
/// real temp project on disk; the cook step spawns a real child process (a
/// tiny Dart script standing in for `flutter`) so the stream plumbing is
/// exercised for real.
void main() {
  late Directory tempDir;
  late Directory projDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_build_pipeline_');
    // The editor's downloaded web module stays out: only what a test sets up counts.
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    projDir = Directory('${tempDir.path}/build_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projDir.path}/contents/materials').createSync(recursive: true);
    Directory('${projDir.path}/contents/meshes').createSync(recursive: true);
    const project = LuminaProject(projectName: 'build_game', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projDir.path}/build_game.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    LuminaDataDir.override = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File writeLmas(String relPath, LuminaAsset asset) {
    final f = File('${projDir.path}/$relPath');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(asset.toProtoBufferBytes(), flush: true);
    return f;
  }

  void writeLevel({List<Map<String, dynamic>> actors = const [], Map<String, dynamic>? navigation}) {
    final level = {
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {
        'actors': actors,
        ...?navigation != null ? {'navigation': navigation} : null,
      },
    };
    File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode(level));
  }

  LuminaProject loadProject() =>
      LuminaProject.fromMap(jsonDecode(File('${projDir.path}/build_game.lmproject').readAsStringSync()) as Map<String, dynamic>);

  Future<List<BuildEvent>> runPlan(BuildPlan plan, {BuildCancellationToken? token, BuildPipelineService? service}) {
    final svc = service ?? BuildPipelineService();
    return svc.run(plan, projectDir: projDir.path, project: loadProject(), token: token).toList();
  }

  group('pipeline ordering', () {
    test('all four steps + cook emit stepStarted in the fixed documented order', () async {
      writeLevel();
      final plan = BuildPlan(steps: [
        CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.shipping, processStarter: _neverStart),
        AssetValidationStep(),
        ThumbnailRegenStep(),
        NavigationBuildStep(),
        MaterialPrecompileStep(compiler: (_) async => const MaterialCompileOutcome.ok()),
      ]);
      final events = await runPlan(plan);
      final started = events.whereType<BuildStepStarted>().map((e) => e.kind).toList();
      expect(started, [
        BuildStepKind.precompileMaterials,
        BuildStepKind.buildNavigation,
        BuildStepKind.regenerateThumbnails,
        BuildStepKind.validateAssets,
        BuildStepKind.cookAndPackage,
      ]);
      expect(events.last, isA<BuildPipelineFinished>());
    });

    test('unchecked steps are absent from the stream (not skipped)', () async {
      writeLevel();
      final plan = BuildPlan(steps: [AssetValidationStep(), ThumbnailRegenStep()]);
      final events = await runPlan(plan);
      final kinds = events.whereType<BuildStepStarted>().map((e) => e.kind).toList();
      expect(kinds, [BuildStepKind.regenerateThumbnails, BuildStepKind.validateAssets]);
      final finished = events.whereType<BuildStepFinished>().map((e) => e.kind).toSet();
      expect(finished.contains(BuildStepKind.precompileMaterials), isFalse);
      expect(finished.contains(BuildStepKind.buildNavigation), isFalse);
      expect(finished.contains(BuildStepKind.cookAndPackage), isFalse);
      expect(events.whereType<BuildStepFinished>().any((e) => e.status == BuildStepStatus.skipped), isFalse);
    });
  });

  group('AssetValidationStep', () {
    test('valid ref, deleted target file and dangling asset_id → exactly 2 issues, step failed', () async {
      writeLevel();
      writeLmas('contents/materials/M_Ok.lmas',
          const LuminaAsset(assetId: 'mat-ok', name: 'M_Ok', type: AssetType.filamat));
      writeLmas('contents/materials/M_Gone.lmas',
          const LuminaAsset(assetId: 'mat-gone', name: 'M_Gone', type: AssetType.filamat));
      writeLmas('contents/meshes/SM_Other.lmas',
          const LuminaAsset(assetId: 'mesh-other', name: 'SM_Other', type: AssetType.filamesh));
      writeLmas(
        'contents/meshes/SM_Crate.lmas',
        const LuminaAsset(assetId: 'mesh-crate', name: 'SM_Crate', type: AssetType.filamesh, references: [
          AssetReference(slotName: 'material_0', assetId: 'mat-ok', assetPath: 'contents/materials/M_Ok.lmas'),
          AssetReference(slotName: 'material_1', assetId: 'mat-gone', assetPath: 'contents/materials/M_Gone.lmas'),
          AssetReference(slotName: 'lod_source', assetId: 'no-such-id', assetPath: 'contents/meshes/SM_Other.lmas'),
        ]),
      );
      // Delete the second target after it was written so the path is truly gone.
      File('${projDir.path}/contents/materials/M_Gone.lmas').deleteSync();

      final events = await runPlan(BuildPlan(steps: [AssetValidationStep()]));
      final issues = events.whereType<BuildValidationIssue>().map((e) => e.issue).toList();
      expect(issues.length, 2, reason: issues.map((i) => i.message).join('\n'));
      expect(issues.every((i) => i.assetPath == 'contents/meshes/SM_Crate.lmas'), isTrue);
      expect(issues.map((i) => i.slotName).toSet(), {'material_1', 'lod_source'});
      final missing = issues.firstWhere((i) => i.slotName == 'material_1');
      expect(missing.targetPath, 'contents/materials/M_Gone.lmas');
      expect(missing.kind, ValidationIssueKind.missingTarget);
      final dangling = issues.firstWhere((i) => i.slotName == 'lod_source');
      expect(dangling.kind, ValidationIssueKind.danglingAssetId);
      expect(dangling.assetId, 'no-such-id');
      expect(dangling.severity, ValidationSeverity.error);
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.kind, BuildStepKind.validateAssets);
      expect(finished.status, BuildStepStatus.failed);
      // Every issue is also a log line.
      final logs = events.whereType<BuildLogEvent>().map((e) => e.message).join('\n');
      expect(logs, contains('material_1'));
      expect(logs, contains('lod_source'));
    });

    test('self-reference is an issue; moved asset (id matches, path stale) is a warning not an error', () async {
      writeLevel();
      writeLmas('contents/materials/M_Moved.lmas',
          const LuminaAsset(assetId: 'mat-moved', name: 'M_Moved', type: AssetType.filamat));
      writeLmas(
        'contents/meshes/SM_Self.lmas',
        const LuminaAsset(assetId: 'mesh-self', name: 'SM_Self', type: AssetType.filamesh, references: [
          AssetReference(slotName: 'self', assetId: 'mesh-self', assetPath: 'contents/meshes/SM_Self.lmas'),
          AssetReference(slotName: 'material_0', assetId: 'mat-moved', assetPath: 'contents/materials/old/M_Moved.lmas'),
        ]),
      );
      final events = await runPlan(BuildPlan(steps: [AssetValidationStep()]));
      final issues = events.whereType<BuildValidationIssue>().map((e) => e.issue).toList();
      expect(issues.map((i) => i.kind).toSet(), {ValidationIssueKind.selfReference, ValidationIssueKind.pathMismatch});
      expect(issues.firstWhere((i) => i.kind == ValidationIssueKind.pathMismatch).severity, ValidationSeverity.warning);
      expect(issues.firstWhere((i) => i.kind == ValidationIssueKind.selfReference).severity, ValidationSeverity.error);
    });
  });

  group('ThumbnailRegenStep', () {
    test('selects exactly the assets with has_thumbnail == false or stale timestamps (3 of 5) and rewrites only those', () async {
      writeLevel();
      final svc = ThumbnailService();
      final png = _tinyPng();
      // 2 fresh: an embedded thumbnail stamped not older than the .lmas.
      final fresh1 = writeLmas('contents/meshes/SM_Fresh1.lmas',
          LuminaAsset(assetId: 'f1', name: 'SM_Fresh1', type: AssetType.filamesh, hasThumbnail: true, thumbnailPng: png));
      final fresh2 = writeLmas('contents/materials/M_Fresh2.lmas',
          LuminaAsset(assetId: 'f2', name: 'M_Fresh2', type: AssetType.filamat, hasThumbnail: true, thumbnailPng: png));
      // 3 stale: no thumbnail; a stamp older than the .lmas; a thumbnail with no stamp at all.
      final noThumb = writeLmas('contents/meshes/SM_NoThumb.lmas',
          const LuminaAsset(assetId: 's1', name: 'SM_NoThumb', type: AssetType.filamesh));
      final staleStamp = writeLmas('contents/meshes/SM_Stale.lmas',
          LuminaAsset(assetId: 's2', name: 'SM_Stale', type: AssetType.filamesh, hasThumbnail: true, thumbnailPng: png));
      final noStamp = writeLmas('contents/materials/M_NoCache.lmas',
          LuminaAsset(assetId: 's3', name: 'M_NoCache', type: AssetType.filamat, hasThumbnail: true, thumbnailPng: png));

      final old = DateTime.now().subtract(const Duration(hours: 2));
      final older = DateTime.now().subtract(const Duration(hours: 3));
      for (final f in [fresh1, fresh2, noThumb, noStamp]) {
        f.setLastModifiedSync(old);
      }
      ThumbnailService.embedThumbnail(fresh1.path, png, source: ThumbnailService.sourceFilament, stamp: old);
      ThumbnailService.embedThumbnail(fresh2.path, png, source: ThumbnailService.sourceFilament, stamp: old);
      ThumbnailService.embedThumbnail(staleStamp.path, png, source: ThumbnailService.sourceFilament, stamp: older);
      staleStamp.setLastModifiedSync(old); // saved after its thumbnail

      final fresh1Mtime = fresh1.lastModifiedSync();
      final fresh2Mtime = fresh2.lastModifiedSync();

      final events = await runPlan(BuildPlan(steps: [ThumbnailRegenStep(thumbnailService: svc)]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      final progress = events.whereType<BuildStepProgress>().toList();
      expect(progress.last.total, 3);
      expect(progress.last.completed, 3);

      expect(fresh1.lastModifiedSync(), fresh1Mtime, reason: 'fresh asset untouched');
      expect(fresh2.lastModifiedSync(), fresh2Mtime, reason: 'fresh asset untouched');
      for (final f in [noThumb, staleStamp, noStamp]) {
        expect(f.lastModifiedSync().isAfter(old), isTrue, reason: '${f.path} rewritten');
        final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
        expect(asset.hasThumbnail, isTrue);
        expect(asset.thumbnailPng, isNotNull);
        expect(asset.thumbnailPng!.length, greaterThan(8));
        // Stamped current, in the .lmas only.
        expect(ThumbnailService.staleFor(f.path, asset.type, asset.metadata[ThumbnailService.sourceKey],
            hasThumbnail: true, assetModified: asset.metadata[ThumbnailService.assetModifiedKey]), isFalse);
      }
      expect(Directory('${projDir.path}/contents/meshes/.thumbnails').existsSync(), isFalse);
      expect(Directory('${projDir.path}/contents/materials/.thumbnails').existsSync(), isFalse);
    });
  });

  group('MaterialPrecompileStep', () {
    test('3 FILAMAT assets where the 2nd fails → 3 per-asset log lines, counter 1/3…3/3, step failed', () async {
      writeLevel();
      for (final n in ['M_A', 'M_B', 'M_C']) {
        writeLmas('contents/materials/$n.lmas',
            LuminaAsset(assetId: 'id-$n', name: n, type: AssetType.filamat, rawPayload: Uint8List.fromList([1, 2, 3])));
      }
      final compiled = <String>[];
      final step = MaterialPrecompileStep(compiler: (input) async {
        compiled.add(input.name);
        expect(input.package, isNotEmpty);
        expect(input.relativePath, 'contents/materials/${input.name}.lmas');
        if (input.name == 'M_B') return const MaterialCompileOutcome.failed('variant 3: shader link error');
        return const MaterialCompileOutcome.ok();
      });
      final events = await runPlan(BuildPlan(steps: [step]));
      expect(compiled, ['M_A', 'M_B', 'M_C'], reason: 'remaining materials still processed after a failure');
      final perAsset = events.whereType<BuildLogEvent>().where((e) => e.message.contains('M_A') || e.message.contains('M_B') || e.message.contains('M_C')).toList();
      expect(perAsset.length, 3);
      expect(perAsset.firstWhere((e) => e.message.contains('M_B')).level, 'error');
      final counters = events.whereType<BuildStepProgress>().where((e) => e.kind == BuildStepKind.precompileMaterials).toList();
      expect(counters.map((c) => '${c.completed}/${c.total}').toList(), ['1/3', '2/3', '3/3']);
      expect(counters.last.failed, 1);
      expect(counters.last.label, 'Materials: 3/3 compiled, 1 failed');
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.failed);
    });

    test('the material a real GLB import writes precompiles through the real filamat compiler', () async {
      final barrel = '${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb';
      if (!File(barrel).existsSync()) return markTestSkipped('needs test-assets/Props/Barrels/empty_barrel.glb');
      writeLevel();
      await AssetRepository().importExternalFile(projectPath: projDir.path, sourceFilePath: barrel);

      final compiler = FilamentMaterialCompiler();
      addTearDown(compiler.dispose);
      final outcomes = <String, MaterialCompileOutcome>{};
      final step = MaterialPrecompileStep(compiler: (input) async {
        final outcome = await compiler(input);
        outcomes[input.name] = outcome;
        return outcome;
      });
      final events = await runPlan(BuildPlan(steps: [step]));
      final logs = events.whereType<BuildLogEvent>().map((e) => e.message).join('\n');

      final imported = outcomes.keys.where((n) => n.startsWith('M_empty_barrel')).toList();
      expect(imported, isNotEmpty, reason: 'the import wrote a FILAMAT asset\n$logs');
      final engineMissing = outcomes.values.any((o) => (o.error ?? '').contains('engine'));
      if (engineMissing) return markTestSkipped('no Filament engine on this host');
      for (final name in imported) {
        expect(outcomes[name]!.ok, isTrue, reason: '$name: ${outcomes[name]!.error}\n$logs');
      }
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok, reason: logs);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('NavigationBuildStep', () {
    test('level without nav volumes → skipped with a log line', () async {
      writeLevel(actors: [
        {'id': 'a1', 'name': 'Crate', 'type': 'StaticMesh', 'location': [0.0, 0.0, 0.0]},
      ]);
      final events = await runPlan(BuildPlan(steps: [NavigationBuildStep()]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.skipped);
      expect(events.whereType<BuildLogEvent>().any((e) => e.message.toLowerCase().contains('no nav')), isTrue);
    });

    test('level with a nav volume runs the real grid bake and reports walkable cells', () async {
      // `extent` is a half size in cm along the stored (Z-up) axes: a
      // 1000 × 1000 cm footprint, 500 cm tall.
      writeLevel(actors: [
        {'id': 'nv', 'name': 'NavMeshBoundsVolume_Main', 'type': 'NavMeshBoundsVolume', 'location': [0.0, 0.0, 0.0], 'extent': [500.0, 500.0, 250.0]},
      ], navigation: {'config': {'cellSize': 50.0}});
      final events = await runPlan(BuildPlan(steps: [NavigationBuildStep()]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      // 1000 × 1000 cm at 50 cm cells, no collision geometry → 400 walkable cells.
      expect(finished.message, contains('400 walkable cells'));
      expect(finished.message, contains('20x20 @ 50 cm'));
      final bake = events.whereType<BuildLogEvent>().singleWhere((e) => e.message.startsWith('Baking navigation grid'));
      expect(bake.message, contains('area 1000 × 1000 cm, 500 cm tall'));
    });

    test('NavMeshBoundsVolume at [0,0,0] with stored scale [20,20,5] bakes a 2000 × 2000 cm area, 500 cm tall', () async {
      // Stored Z up: scale is the size in metres of a 1 m box — 20 × 20 m
      // footprint, 5 m tall. The bake converts through LuminaAxes into the
      // runtime Y-up grid and × unitsPerMetre into cm.
      writeLevel(actors: [
        {
          'id': 'nv',
          'name': 'NavMeshBoundsVolume',
          'type': 'NavMeshBoundsVolume',
          'location': [0.0, 0.0, 0.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [20.0, 20.0, 5.0],
        },
      ], navigation: {
        // What the navigation editor writes: config in cm, volumes mirrored
        // as {id, name} (not a second volume).
        'config': {'cellSize': 50.0, 'agentRadius': 35.0, 'agentHeight': 180.0, 'maxStepHeight': 30.0},
        'volumes': [
          {'id': 'nv', 'name': 'NavMeshBoundsVolume'},
        ],
      });
      final events = await runPlan(BuildPlan(steps: [NavigationBuildStep()]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      final bake = events.whereType<BuildLogEvent>().singleWhere((e) => e.message.startsWith('Baking navigation grid'));
      expect(bake.message, contains('1 volume(s)'), reason: 'the section mirror adds no phantom volume');
      expect(bake.message, contains('area 2000 × 2000 cm, 500 cm tall'));
      expect(bake.message, contains('cell 50 cm, agent r=35 cm'));
      // 2000 / 50 = 40 cells a side, all walkable (no collision geometry).
      expect(finished.message, contains('40x40 @ 50 cm'));
      expect(finished.message, contains('${40 * 40} walkable cells'));
    });

    test('stored Z-up volume axes: a 20 × 10 m footprint along stored X / Y becomes 2000 cm on runtime X and 1000 cm on runtime Z; config falls back to NavGridConfig() cm', () async {
      writeLevel(actors: [
        {'id': 'nv', 'name': 'NavMeshBoundsVolume', 'type': 'NavMeshBoundsVolume', 'location': [500.0, -300.0, 100.0], 'scale': [20.0, 10.0, 2.0]},
      ]);
      final events = await runPlan(BuildPlan(steps: [NavigationBuildStep()]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      final bake = events.whereType<BuildLogEvent>().singleWhere((e) => e.message.startsWith('Baking navigation grid'));
      const d = NavGridConfig();
      expect(bake.message, contains('area 2000 × 1000 cm, 200 cm tall'));
      expect(bake.message, contains('cell ${d.cellSize.toStringAsFixed(0)} cm, agent r=${d.agentRadius.toStringAsFixed(0)} cm'));
      // 2000 / 50 × 1000 / 50 at the engine's default 50 cm cells.
      expect(finished.message, contains('40x20 @ 50 cm'));
      expect(finished.message, contains('800 walkable cells'));
    });
  });

  group('CookAndPackageStep', () {
    late String standIn;
    setUp(() {
      standIn = _writeStandIn(tempDir);
    });

    BuildProcessStarter standInStarter({int exitCode = 0, int lines = 5, int delayMs = 120}) {
      return (String exe, List<String> args, {String? workingDirectory}) {
        // Record the argv the pipeline asked for, then run the stand-in.
        File('${tempDir.path}/argv.json').writeAsStringSync(jsonEncode([exe, ...args]));
        return Process.start(
          _dartExecutable(),
          [standIn, tempDir.path, '$exitCode', '$lines', '$delayMs'],
          workingDirectory: workingDirectory,
        );
      };
    }

    test('5 lines with delays, exit 0 → 5 log events arrive incrementally, step ok, artifact path emitted', () async {
      writeLevel();
      final arrival = <DateTime>[];
      DateTime? finishedAt;
      final svc = BuildPipelineService();
      final step = CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.shipping, processStarter: standInStarter());
      final events = <BuildEvent>[];
      await for (final e in svc.run(BuildPlan(steps: [step]), projectDir: projDir.path, project: loadProject())) {
        events.add(e);
        if (e is BuildLogEvent && e.message.startsWith('stand-in line')) arrival.add(DateTime.now());
        if (e is BuildStepFinished) finishedAt = DateTime.now();
      }
      expect(arrival.length, 5);
      // Incremental: first line arrives clearly before the process ends (~5 * delay).
      expect(finishedAt!.difference(arrival.first).inMilliseconds, greaterThan(300), reason: 'lines must stream as they arrive, not batch at exit');
      expect(arrival.last.difference(arrival.first).inMilliseconds, greaterThan(200));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      final done = events.whereType<BuildPipelineFinished>().single;
      expect(done.artifactPath, '${projDir.path}/build/linux/x64/release/bundle');
    });

    test('exit 7 → step failed with the exit code in the final log line', () async {
      writeLevel();
      final step = CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.debug, processStarter: standInStarter(exitCode: 7, lines: 2, delayMs: 10));
      final events = await runPlan(BuildPlan(steps: [step]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.failed);
      final logs = events.whereType<BuildLogEvent>().toList();
      expect(logs.last.message, contains('7'));
      expect(logs.last.level, 'error');
      expect(events.whereType<BuildPipelineFinished>().single.artifactPath, isNull);
    });

    test('cancel mid-cook kills the child (marker file), closes with cancelled, later steps never start', () async {
      writeLevel();
      final token = BuildCancellationToken();
      final svc = BuildPipelineService();
      final cook = CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.development, processStarter: standInStarter(lines: 50, delayMs: 100));
      final plan = BuildPlan(steps: [cook, AssetValidationStep()]);
      // Put validation AFTER cook on purpose via a custom order so "later steps never start" is observable.
      final events = <BuildEvent>[];
      var seenLines = 0;
      await for (final e in svc.run(plan, projectDir: projDir.path, project: loadProject(), token: token, keepPlanOrder: true)) {
        events.add(e);
        if (e is BuildLogEvent && e.message.startsWith('stand-in line')) {
          seenLines++;
          if (seenLines == 2) token.cancel();
        }
      }
      final marker = File('${tempDir.path}/killed.marker');
      // Windows kills with TerminateProcess, which the child cannot record.
      if (!Platform.isWindows) expect(marker.existsSync(), isTrue, reason: 'stand-in records SIGTERM');
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.cancelled);
      expect(events.whereType<BuildPipelineFinished>().single.status, BuildStepStatus.cancelled);
      expect(events.whereType<BuildStepStarted>().map((e) => e.kind).toList(), [BuildStepKind.cookAndPackage]);
      expect(seenLines, lessThan(50));
    });

    test('code-gen precedes the spawn: dirty temp project gets lib/levels/l_main.dart before the process starts', () async {
      writeLevel(actors: [
        {'id': 'act_1', 'name': 'HeroCrate', 'type': 'StaticMesh', 'location': [1.0, 2.0, 3.0], 'rotation': [0.0, 0.0, 0.0], 'scale': [1.0, 1.0, 1.0]},
      ]);
      final dirty = loadProject().copyWith(isDirty: true);
      File('${projDir.path}/build_game.lmproject').writeAsStringSync(jsonEncode(dirty.toMap()));
      String? levelContentAtSpawn;
      Future<Process> starter(String exe, List<String> args, {String? workingDirectory}) {
        final f = File('${projDir.path}/lib/levels/l_main.dart');
        levelContentAtSpawn = f.existsSync() ? f.readAsStringSync() : null;
        return Process.start(_dartExecutable(), [standIn, tempDir.path, '0', '1', '1'], workingDirectory: workingDirectory);
      }
      final step = CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.shipping, processStarter: starter);
      final events = await runPlan(BuildPlan(steps: [step]));
      expect(levelContentAtSpawn, isNotNull, reason: 'level Dart must exist when flutter build starts');
      expect(levelContentAtSpawn, contains('HeroCrate'));
      expect(File('${projDir.path}/lib/main.dart').existsSync(), isTrue);
      expect(loadProject().isDirty, isFalse, reason: 'codegen pass clears the dirty flag');
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok);
    });

    test('Shipping → --release appears verbatim in the spawned argv; extra flags are shell-split', () async {
      writeLevel();
      final step = CookAndPackageStep(
        target: 'linux',
        configuration: BuildConfiguration.shipping,
        extraFlags: '--dart-define=FOO="a b" -v',
        processStarter: standInStarter(lines: 1, delayMs: 1),
      );
      await runPlan(BuildPlan(steps: [step]));
      final argv = (jsonDecode(File('${tempDir.path}/argv.json').readAsStringSync()) as List).cast<String>();
      expect(argv, ['flutter', 'build', 'linux', '--release', '--dart-define=FOO=a b', '-v']);
      expect(BuildConfiguration.debug.flag, '--debug');
      expect(BuildConfiguration.development.flag, '--profile');
    });

    test('on Windows a project under a folder with a space builds through a space-free alias of it', () async {
      final spaced = Directory('${tempDir.path}/Lumina Projects/space_game')..createSync(recursive: true);
      final aliases = Directory('${tempDir.path}/aliases');
      String? cwd;
      final step = CookAndPackageStep(
        target: 'windows',
        configuration: BuildConfiguration.shipping,
        buildAliasRoot: aliases,
        codeGenerator: (ctx) async => const CookCodeGenOutcome(true, 'no level to generate'),
        processStarter: (exe, args, {workingDirectory}) {
          cwd = workingDirectory;
          return Process.start(_dartExecutable(), [standIn, tempDir.path, '0', '1', '1'], workingDirectory: workingDirectory);
        },
      );
      final events = await BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: spaced.path).toList();
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      expect(events.whereType<BuildPipelineFinished>().single.artifactPath, '${spaced.path}/build/windows/x64/runner/Release',
          reason: 'the artifact stays in the project');
      if (!Platform.isWindows) {
        expect(cwd, spaced.path, reason: 'other hosts build in place');
        return;
      }
      expect(cwd, isNot(contains(' ')), reason: 'cl.exe runs through cmd.exe, which cannot quote a second path with a space');
      expect(cwd!.startsWith(aliases.path), isTrue);
      expect(FileSystemEntity.isLinkSync(cwd!), isTrue);
      File('${spaced.path}/marker.txt').writeAsStringSync('in the project');
      expect(File('$cwd/marker.txt').readAsStringSync(), 'in the project', reason: 'the alias is the project folder');
      expect(events.whereType<BuildLogEvent>().any((l) => l.message.contains('Building through $cwd')), isTrue);
    });

    test('a failed build logs the error of the native-assets hook that failed in it, not older ones', () async {
      writeLevel();
      final hooks = '${projDir.path}/.dart_tool/hooks_runner';
      // A hook that failed in an earlier build: not this build's error.
      final stale = Directory('$hooks/flutter_riglogic/0123456789')..createSync(recursive: true);
      File('${stale.path}/stderr.txt')
        ..writeAsStringSync('Exception: riglogic.lib not found\n')
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
      // A hook that succeeded in this build (empty stderr).
      final ok = Directory('$hooks/flutter_filament/bc4af5bfa5')..createSync(recursive: true);
      File('${ok.path}/stderr.txt').writeAsStringSync('');
      File('${ok.path}/stdout.txt').writeAsStringSync('native cache hit 5acf8243\n');
      final hookStandIn = _writeFailingHookStandIn(tempDir);
      final step = CookAndPackageStep(
        target: 'windows',
        configuration: BuildConfiguration.shipping,
        buildAliasRoot: Directory('${tempDir.path}/aliases'),
        processStarter: (exe, args, {workingDirectory}) =>
            Process.start(_dartExecutable(), [hookStandIn, '$hooks/flutter_assimp/bc4af5bfa5'], workingDirectory: workingDirectory),
      );
      final events = await runPlan(BuildPlan(steps: [step]));
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.failed);
      final errors = events.whereType<BuildLogEvent>().where((l) => l.level == 'error').map((l) => l.message).toList();
      final log = errors.join('\n');
      expect(errors.where((l) => l.startsWith('Native assets hook ')), hasLength(1), reason: log);
      expect(log, contains('Native assets hook flutter_assimp failed'));
      expect(log, contains("Exit code: '1'."), reason: 'the hook exception');
      expect(log, contains("'C:\\Program' is not recognized as an internal or external command,"), reason: "the failing tool's message");
      expect(log, contains('operable program or batch file.'));
      expect(log, isNot(contains('#0      runProcess')), reason: 'stack frames are left out');
      expect(log, isNot(contains('riglogic.lib not found')), reason: "an earlier build's hook error is not this one");
      expect(errors.every((l) => l.length < CookAndPackageStep.hookLineLimit + 80), isTrue, reason: 'command and environment dumps are shortened');
      expect(errors.last, contains('exited with code 1'));
    });
  });

  group('CookAndPackageStep for the web', () {
    FlutterFilamentWebModule? module;
    setUp(() => module = FlutterFilamentWebModule.locate());

    test('web cook: flutter build web --release, artifact build/web, Development → --profile', () async {
      if (module == null) return markTestSkipped('flutter_filament web module not built');
      writeLevel();
      writeFlutterWebPlatform(projDir.path);
      final step = CookAndPackageStep(
        target: 'web',
        configuration: BuildConfiguration.shipping,
        processStarter: flutterBuildStandIn(tempDir),
        webModule: module,
      );
      expect(step.buildArguments(), ['build', 'web', '--release']);
      expect(CookAndPackageStep(target: 'web', configuration: BuildConfiguration.development).buildArguments(),
          ['build', 'web', '--profile']);
      expect(CookAndPackageStep.artifactPathFor(projDir.path, 'web', BuildConfiguration.development), '${projDir.path}/build/web');

      final events = await runPlan(BuildPlan(steps: [step]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: finished.message);
      final argv = (jsonDecode(File('${tempDir.path}/argv.json').readAsStringSync()) as List).cast<String>();
      expect(argv, ['flutter', 'build', 'web', '--release']);
      expect(events.whereType<BuildPipelineFinished>().single.artifactPath, '${projDir.path}/build/web');
    });

    test('bundleWebResources adds --no-web-resources-cdn once, for web only', () {
      expect(
        CookAndPackageStep(target: 'web', configuration: BuildConfiguration.shipping, bundleWebResources: true).buildArguments(),
        ['build', 'web', '--release', '--no-web-resources-cdn'],
      );
      expect(
        CookAndPackageStep(
          target: 'web',
          configuration: BuildConfiguration.development,
          bundleWebResources: true,
          extraFlags: '--no-web-resources-cdn -v',
        ).buildArguments(),
        ['build', 'web', '--profile', '--no-web-resources-cdn', '-v'],
      );
      expect(
        CookAndPackageStep(target: 'linux', configuration: BuildConfiguration.shipping, bundleWebResources: true).buildArguments(),
        ['build', 'linux', '--release'],
      );
      expect(CookAndPackageStep(target: 'web', configuration: BuildConfiguration.shipping).buildArguments(), ['build', 'web', '--release']);
    });

    test('the cook stages flutter_filament.{js,wasm} into build/web with the same bytes and logs their size', () async {
      if (module == null) return markTestSkipped('flutter_filament web module not built');
      writeLevel();
      writeFlutterWebPlatform(projDir.path);
      final events = await runPlan(BuildPlan(steps: [
        CookAndPackageStep(
          target: 'web',
          configuration: BuildConfiguration.shipping,
          processStarter: flutterBuildStandIn(tempDir),
          webModule: module,
        ),
      ]));
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok);
      for (final source in module!.files) {
        final staged = File('${projDir.path}/build/web/${source.uri.pathSegments.last}');
        expect(staged.existsSync(), isTrue, reason: '${staged.path} staged');
        expect(staged.readAsBytesSync(), source.readAsBytesSync());
      }
      expect(Directory('${projDir.path}/web').listSync().map((e) => e.uri.pathSegments.last), ['index.html'],
          reason: 'the module is a build output, not copied into the project sources');
      expect(
        events.whereType<BuildLogEvent>().any((e) => e.message.contains('flutter_filament.wasm') && e.message.contains('MB')),
        isTrue,
      );
    });

    test('without web/index.html the cook refuses to spawn and names the file', () async {
      if (module == null) return markTestSkipped('flutter_filament web module not built');
      writeLevel();
      final events = await runPlan(BuildPlan(steps: [
        CookAndPackageStep(
          target: 'web',
          configuration: BuildConfiguration.shipping,
          processStarter: _neverStart,
          webModule: module,
        ),
      ]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.failed);
      expect(finished.message, contains('${projDir.path}/web/index.html'));
      expect(finished.message, contains('flutter create --platforms=web .'));
      expect(File('${tempDir.path}/argv.json').existsSync(), isFalse, reason: 'flutter build web never started');
    });

    test('without the module the web cook refuses to spawn and says how to build it', () async {
      writeLevel();
      writeFlutterWebPlatform(projDir.path);
      final events = await runPlan(BuildPlan(steps: [
        CookAndPackageStep(target: 'web', configuration: BuildConfiguration.shipping, processStarter: _neverStart),
      ]));
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.failed);
      expect(finished.message, contains('build_module.sh'));
    });
  });

  group('PackageTargetsStep', () {
    List<String> argvLog() => File('${tempDir.path}/argv.log').existsSync()
        ? File('${tempDir.path}/argv.log').readAsLinesSync()
        : const [];

    test('linux, android, web: two real builds, android reported with its reasons and never spawned', () async {
      writeLevel();
      writeFlutterWebPlatform(projDir.path);
      final module = FlutterFilamentWebModule.locate();
      if (module == null) return markTestSkipped('flutter_filament web module not built');
      final host = HostBuildTargets.parseDoctor(_thisHostDoctor, operatingSystem: 'linux');
      var codegens = 0;
      final step = PackageTargetsStep(
        targets: const ['linux', 'android', 'web'],
        reasonsFor: (t) => host.reasonsFor(t, engineReason: (p) => p == 'web' ? null : HostBuildTargets.engineUnsupportedReason(p)),
        packageDirFor: (t) => const ProjectPackagingSettings().packageDirFor(projDir.path, t),
        processStarter: flutterBuildStandIn(tempDir),
        webModule: module,
        codeGenerator: (ctx) async {
          codegens++;
          return CookAndPackageStep.levelFileCodeGenerator(ctx);
        },
      );
      final events = await runPlan(BuildPlan(steps: [step]));
      final order = [
        for (final e in events)
          if (e is BuildTargetStarted) 'started(${e.target})' else if (e is BuildTargetFinished) 'finished(${e.target}, ${e.status.name})',
      ];
      expect(order, [
        'started(linux)', 'finished(linux, ok)',
        'started(android)', 'finished(android, unbuildable)',
        'started(web)', 'finished(web, ok)',
      ], reason: events.whereType<BuildLogEvent>().map((l) => '[${l.source}] ${l.message}').join('\n'));
      expect(codegens, 1, reason: 'the game code is generated once per run');
      expect(argvLog(), ['flutter build linux --release', 'flutter build web --release'], reason: 'android is never spawned');

      final linux = '${projDir.path}/build/package/linux';
      expect(File('$linux/build_game').existsSync(), isTrue, reason: 'the bundle was copied');
      if (!Platform.isWindows) {
        expect(File('$linux/build_game').statSync().modeString(), startsWith('rwx'), reason: 'the executable bit survives the copy');
      }
      expect(File('$linux/data/icudtl.dat').existsSync(), isTrue);
      final web = '${projDir.path}/build/package/web';
      expect(File('$web/index.html').existsSync(), isTrue);
      expect(File('$web/flutter_filament.wasm').lengthSync(), module.files.last.lengthSync(), reason: 'the package carries the staged module');

      final android = events.whereType<BuildTargetFinished>().firstWhere((e) => e.target == 'android');
      expect(android.reasons, hasLength(2));
      expect(android.message, contains('Android license status unknown'));
      final tagged = events.whereType<BuildLogEvent>().where((l) => l.source == 'Cook & Package [android]').map((l) => l.message).toList();
      expect(tagged.first, contains('Android is not buildable'));
      expect(events.whereType<BuildLogEvent>().any((l) => l.source == 'Cook & Package [linux]' && l.message.contains('Built build/linux')), isTrue);
      expect(events.whereType<BuildLogEvent>().any((l) => l.source == 'Cook & Package [web]' && l.message.contains('flutter build web')), isTrue);

      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.failed);
      expect(finished.message, contains('Android not buildable'));
      expect(finished.message, contains('Linux OK'));
    });

    test('cancel during the first of two targets kills it and never spawns the second', () async {
      writeLevel();
      final standIn = _writeStandIn(tempDir);
      final token = BuildCancellationToken();
      var spawned = 0;
      final step = PackageTargetsStep(
        targets: const ['linux', 'web'],
        reasonsFor: (_) => const [],
        packageDirFor: (t) => '${projDir.path}/build/package/$t',
        processStarter: (exe, args, {workingDirectory}) {
          spawned++;
          return Process.start(_dartExecutable(), [standIn, tempDir.path, '0', '50', '100'], workingDirectory: workingDirectory);
        },
      );
      final events = <BuildEvent>[];
      var lines = 0;
      await for (final e in BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: projDir.path, project: loadProject(), token: token)) {
        events.add(e);
        if (e is BuildLogEvent && e.message.startsWith('stand-in line') && ++lines == 2) token.cancel();
      }
      // Windows kills with TerminateProcess, which the child cannot record.
      if (!Platform.isWindows) {
        expect(File('${tempDir.path}/killed.marker').existsSync(), isTrue, reason: 'the running build was killed');
      }
      expect(spawned, 1);
      final finished = {for (final e in events.whereType<BuildTargetFinished>()) e.target: e.status};
      expect(finished, {'linux': PackageTargetStatus.cancelled, 'web': PackageTargetStatus.cancelled});
      expect(events.whereType<BuildTargetStarted>().map((e) => e.target), ['linux']);
      expect(events.whereType<BuildPipelineFinished>().single.status, BuildStepStatus.cancelled);
    });

    test('a package folder overlapping the build output is refused; an APK file is copied into its folder', () {
      final bundle = Directory('${projDir.path}/build/linux/x64/release/bundle')..createSync(recursive: true);
      File('${bundle.path}/game').writeAsStringSync('x');
      expect(() => PackageTargetsStep.copyArtifact(bundle.path, '${bundle.path}/package'), throwsStateError);
      final apk = File('${projDir.path}/build/app/outputs/flutter-apk/app-release.apk')
        ..createSync(recursive: true)
        ..writeAsStringSync('apk');
      final bytes = PackageTargetsStep.copyArtifact(apk.path, '${projDir.path}/build/package/android');
      expect(bytes, 3);
      expect(File('${projDir.path}/build/package/android/app-release.apk').readAsStringSync(), 'apk');
      // A second package replaces the folder: nothing stale survives.
      File('${projDir.path}/build/package/android/stale.txt').writeAsStringSync('old');
      PackageTargetsStep.copyArtifact(apk.path, '${projDir.path}/build/package/android');
      expect(File('${projDir.path}/build/package/android/stale.txt').existsSync(), isFalse);
    });
  });

  group('real host toolchain', () {
    test('CookAndPackageStep drives a real `flutter build linux --release` on a tiny generated project; artifact exists on disk', () async {
      final host = await HostBuildTargets.probe();
      if (!host.targets.contains('linux')) {
        // ignore: avoid_print
        print('SKIP: host has no Linux toolchain (${host.error ?? host.targets})');
        return;
      }
      final dir = Directory('${tempDir.path}/tiny_cook');
      final create = await Process.run('flutter', ['create', '--platforms=linux', '--project-name', 'tiny_cook', dir.path], runInShell: true);
      expect(create.exitCode, 0, reason: '${create.stdout}\n${create.stderr}');
      const project = LuminaProject(projectName: 'tiny_cook', activeLevel: 'contents/levels/L_Main.lmas');
      File('${dir.path}/tiny_cook.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      // The tiny project has no lumina dependency, so the code-gen seam writes a
      // standalone main.dart; the flutter build itself is completely real.
      final step = CookAndPackageStep(
        target: 'linux',
        configuration: BuildConfiguration.shipping,
        codeGenerator: (ctx) async {
          File('${ctx.projectDir}/lib/main.dart').writeAsStringSync(
              "import 'package:flutter/widgets.dart';\nvoid main() => runApp(const Center(child: Text('tiny_cook', textDirection: TextDirection.ltr)));\n");
          return const CookCodeGenOutcome(true, 'wrote standalone lib/main.dart');
        },
      );
      final events = await BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: dir.path, project: project).toList();
      final logs = events.whereType<BuildLogEvent>().toList();
      final finished = events.whereType<BuildStepFinished>().single;
      expect(finished.status, BuildStepStatus.ok, reason: logs.map((l) => l.message).join('\n'));
      expect(logs.any((l) => l.message.contains('Built build/linux/x64/release/bundle')), isTrue, reason: 'real flutter output streamed');
      final artifact = events.whereType<BuildPipelineFinished>().single.artifactPath!;
      expect(artifact, '${dir.path}/build/linux/x64/release/bundle');
      expect(File('$artifact/tiny_cook').existsSync(), isTrue, reason: 'the built executable exists');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('a launcher-created game under "Lumina Projects" (a path with a space) cooks with a real `flutter build windows --release`',
        () async {
      if (!Platform.isWindows) {
        markTestSkipped('Windows only');
        return;
      }
      final host = await HostBuildTargets.probe();
      if (!host.targets.contains('windows')) {
        markTestSkipped('host has no Windows toolchain (${host.error ?? host.targets})');
        return;
      }
      // The launcher's real pipeline: flutter create, the engine dependency,
      // the local engine link (pubspec_overrides.yaml + hook user-defines),
      // pub get, manifest and level.
      final projects = Directory('${tempDir.path}/Lumina Projects')..createSync();
      const name = 'space_cook';
      await ProjectRepository().createProjectStream(projectName: name, projectLocation: projects.path).drain<void>();
      final projectDir = '${projects.path}/$name';
      final project = await ProjectRepository().loadProject('$projectDir/$name.lmproject');
      expect(project, isNotNull);
      final step = PackageTargetsStep(
        targets: const ['windows'],
        reasonsFor: (_) => const [],
        packageDirFor: (t) => '$projectDir/build/package/$t',
        buildAliasRoot: Directory('${tempDir.path}/aliases'),
      );
      final events = await BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: projectDir, project: project).toList();
      final logs = events.whereType<BuildLogEvent>().map((l) => '[${l.level}] ${l.message}').join('\n');
      expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok, reason: logs);
      expect(logs, contains('Building through '), reason: 'the build ran through the space-free alias');
      expect(File('$projectDir/build/windows/x64/runner/Release/$name.exe').existsSync(), isTrue, reason: logs);
      for (final dll in ['flutter_filament.dll', 'flutter_assimp.dll', 'flutter_riglogic.dll']) {
        expect(File('$projectDir/build/package/windows/$dll').existsSync(), isTrue, reason: 'the hooks built $dll\n$logs');
      }
    }, timeout: const Timeout(Duration(minutes: 30)));

    test('FilamentMaterialCompiler compiles a real filamat package on a headless engine and rejects non-packages', () async {
      final compiler = FilamentMaterialCompiler();
      addTearDown(compiler.dispose);
      final junk = await compiler(MaterialCompileInput(name: 'M_Junk', relativePath: 'contents/materials/M_Junk.lmas', package: Uint8List.fromList(List<int>.filled(64, 7)), source: ''));
      expect(junk.ok, isFalse);
      expect(junk.error, contains('no compiled filamat package'));

      Uint8List package;
      try {
        FilamentMaterialBuilder.initEngine();
        final builder = FilamentMaterialBuilder.create();
        builder.setName('BuildManagerProbe');
        builder.setShading(FilamatShading.unlit);
        builder.setCode('void material(inout MaterialInputs material) { prepareMaterial(material); material.baseColor = vec4(1.0, 0.5, 0.0, 1.0); }');
        final built = builder.build();
        if (built == null) {
          // ignore: avoid_print
          print('SKIP: filamat builder produced no package');
          return;
        }
        package = built;
      } catch (e) {
        // ignore: avoid_print
        print('SKIP: filamat builder unavailable ($e)');
        return;
      }
      expect(FilamentMaterialCompiler.isFilamatPackage(package), isTrue);
      final outcome = await compiler(MaterialCompileInput(name: 'M_Probe', relativePath: 'contents/materials/M_Probe.lmas', package: package, source: ''));
      if (!outcome.ok && (outcome.error ?? '').contains('engine')) {
        // ignore: avoid_print
        print('SKIP: ${outcome.error}');
        return;
      }
      expect(outcome.ok, isTrue, reason: outcome.error);
      // Source-only material (what the GLB import pipeline writes) compiles the same way the Material Editor does.
      const source = 'material {\n  name : SourceOnly,\n  shadingModel : unlit\n}\nfragment {\n  void material(inout MaterialInputs material) {\n    prepareMaterial(material);\n    material.baseColor = vec4(0.2, 0.8, 0.3, 1.0);\n  }\n}\n';
      final fromSource = await compiler(MaterialCompileInput(name: 'M_SourceOnly', relativePath: 'contents/materials/M_SourceOnly.lmas', package: Uint8List(0), source: source));
      expect(fromSource.ok, isTrue, reason: fromSource.error);
      expect(fromSource.note, contains('compiled from .mat source'));
      // The GLB import pipeline's template: header parameters must be declared for `materialParams.<name>`.
      const imported = 'material {\n  name : "barrel_blue",\n  shadingModel : lit,\n  parameters : [\n    { type : float4, name : baseColor }\n  ]\n}\nfragment {\n  void material(inout MaterialInputs material) {\n    prepareMaterial(material);\n    material.baseColor = materialParams.baseColor;\n  }\n}\n';
      final importedOutcome = await compiler(MaterialCompileInput(name: 'M_Imported', relativePath: 'contents/materials/M_Imported.lmas', package: Uint8List(0), source: imported));
      expect(importedOutcome.ok, isTrue, reason: importedOutcome.error);
      // The whole definition is compiled: a vertex block after the fragment and header keys beyond shading/blending.
      const vertexBlock = '''material {
  name : Wave,
  shadingModel : unlit,
  blending : fade,
  requires : [ tangents ],
  variables : [ tint ]
}
fragment {
  void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = vec4(variable_tint.rgb, 0.8);
  }
}
vertex {
  void materialVertex(inout MaterialVertexInputs material) {
    material.tint = vec4(material.worldNormal * 0.5 + 0.5, 1.0);
  }
}
''';
      final waveOutcome = await compiler(MaterialCompileInput(name: 'M_Wave', relativePath: 'contents/materials/M_Wave.lmas', package: Uint8List(0), source: vertexBlock));
      expect(waveOutcome.ok, isTrue, reason: waveOutcome.error);
      // A rejected source fails with the compiler's own message and line.
      final brokenOutcome = await compiler(MaterialCompileInput(
          name: 'M_Broken', relativePath: 'contents/materials/M_Broken.lmas', package: Uint8List(0), source: vertexBlock.replaceFirst('variable_tint.rgb', 'nowhereDeclared')));
      expect(brokenOutcome.ok, isFalse);
      expect(brokenOutcome.error, startsWith('matc: '));
      expect(brokenOutcome.error, contains("ERROR: 0:11: 'nowhereDeclared' : undeclared identifier"));
    });
  });

  group('HostBuildTargets', () {
    test('the engine refuses android and ios with a reason; linux, macos and windows build', () {
      expect(HostBuildTargets.engineUnsupportedReason('linux'), isNull);
      expect(HostBuildTargets.engineUnsupportedReason('macos'), isNull);
      expect(HostBuildTargets.engineUnsupportedReason('windows'), isNull, reason: 'hook/build.dart links Filament on Windows');
      expect(HostBuildTargets.engineUnsupportedReason('android'), contains('Android'));
      expect(HostBuildTargets.engineUnsupportedReason('android'), contains('no Android build of the Filament libraries'));
      expect(HostBuildTargets.engineUnsupportedReason('ios'), contains('iOS'));
    });

    test('this host\'s real doctor output gives every platform its reasons', () {
      final host = HostBuildTargets.parseDoctor(_thisHostDoctor, operatingSystem: 'linux');
      expect(host.flutterAvailable, isTrue);
      expect(host.flutterVersion, '3.47.0');
      expect(host.targets, ['linux', 'web'], reason: 'web needs no Chrome to build');
      expect(host.featureFlags, contains('enable-web'));
      expect(host.toolchains['android']!.ready, isFalse);
      expect(host.toolchains['linux']!.ready, isTrue);

      final android = host.reasonsFor('android');
      expect(android, hasLength(2), reason: 'toolchain and engine: accepting the licences alone is not enough');
      expect(android[0], contains('Android license status unknown'));
      expect(android[0], contains('flutter doctor --android-licenses'));
      expect(android[0], isNot(contains('Multiple adb')), reason: 'a ✗ problem is shown instead of the ! warnings');
      expect(android[1], contains('no Android build of the Filament libraries'));
      expect(host.reasonsFor('windows').first, contains('need a Windows host'));
      expect(host.reasonsFor('macos').first, contains('need a Mac with Xcode'));
      expect(host.reasonsFor('ios').first, contains('need a Mac with Xcode'));
      expect(host.reasonsFor('ios'), hasLength(2), reason: 'host, then engine');
      expect(host.reasonsFor('linux'), isEmpty);
      expect(host.reasonsFor('web', engineReason: (_) => null), isEmpty);

      final noWebFlag = HostBuildTargets.parseDoctor(
          _thisHostDoctor.replaceFirst('enable-web, ', ''), operatingSystem: 'linux');
      expect(noWebFlag.targets, isNot(contains('web')));
      expect(noWebFlag.reasonsFor('web', engineReason: (_) => null).single, contains('flutter config --enable-web'));
      final noFlutter = const HostBuildTargets(flutterAvailable: false, error: 'flutter is not available: ProcessException');
      expect(noFlutter.reasonsFor('web', engineReason: (_) => null).single, contains('not available'));
    });

    test('web is buildable exactly when flutter_filament ships its WebAssembly module', () {
      // No package config under the temp dir: no module, and the reason says what to build.
      final absent = HostBuildTargets.engineUnsupportedReason('web', packageRoots: [tempDir.path]);
      expect(absent, contains('flutter_filament.wasm'));
      expect(absent, contains('build_module.sh'));

      final module = FlutterFilamentWebModule.locate();
      if (module == null) {
        markTestSkipped('flutter_filament/web/flutter_filament.wasm is not built (tool/web/build_module.sh)');
        return;
      }
      expect(module.files.map((f) => f.uri.pathSegments.last), ['flutter_filament.js', 'flutter_filament.wasm']);
      expect(module.sizeBytes, greaterThan(1 << 20));
      expect(HostBuildTargets.engineUnsupportedReason('web'), isNull);
    });

    test('parsed doctor output on Linux contains linux and never ios/macos; partial toolchains excluded', () {
      const doctor = '''
[✓] Flutter (Channel stable, 3.47.0, on Ubuntu 26.04.1 LTS, locale en_US.UTF-8)
[!] Android toolchain - develop for Android devices (Android SDK version 37.0.0)
[✓] Chrome - develop for the web
[✓] Linux toolchain - develop for Linux desktop
[✗] Xcode - develop for iOS and macOS
[✓] Connected device (2 available)
''';
      final targets = HostBuildTargets.parseDoctor(doctor, operatingSystem: 'linux');
      expect(targets.flutterAvailable, isTrue);
      expect(targets.flutterVersion, '3.47.0');
      expect(targets.targets, ['linux', 'web']);
      expect(targets.targets, isNot(contains('ios')));
      expect(targets.targets, isNot(contains('macos')));
      expect(targets.targets, isNot(contains('android')), reason: '[!] Android toolchain is not buildable');
    });

    test('real probe on this host reports the host desktop target', () async {
      final targets = await HostBuildTargets.probe();
      expect(targets.flutterAvailable, isTrue);
      expect(targets.targets, contains(Platform.isWindows ? 'windows' : Platform.isMacOS ? 'macos' : 'linux'));
      if (!Platform.isMacOS) expect(targets.targets.any((t) => t == 'ios' || t == 'macos'), isFalse);
    });

    test('missing flutter binary → flutterAvailable false, no targets, no throw', () async {
      final targets = await HostBuildTargets.probe(processStarter: (exe, args, {workingDirectory}) =>
          Process.start('/definitely/not/flutter', args));
      expect(targets.flutterAvailable, isFalse);
      expect(targets.targets, isEmpty);
      expect(targets.error, isNotNull);
    });
  });
}

Future<Process> _neverStart(String exe, List<String> args, {String? workingDirectory}) =>
    throw StateError('cook must not spawn in this test');

String _dartExecutable() {
  // The SDK's own binary: on Windows `bin/dart` is `dart.bat`, which
  // Process.start cannot run without a shell.
  final sdkDart = Platform.isWindows ? 'bin/cache/dart-sdk/bin/dart.exe' : 'bin/dart';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && File('$root/$sdkDart').existsSync()) return '$root/$sdkDart';
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<os>-x64/; walk up to the SDK.
  final idx = exe.indexOf('/bin/cache/');
  if (idx > 0) {
    final candidate = '${exe.substring(0, idx)}/$sdkDart';
    if (File(candidate).existsSync()) return candidate;
  }
  return 'dart';
}

/// A real child process standing in for a `flutter build` whose
/// native-assets hook fails: it writes the hook's `stderr.txt` / `stdout.txt`
/// into the hooks runner folder given as the argument, as the hooks runner
/// does (the text of a flutter_assimp hook that ran cl.exe through cmd.exe
/// under a path with a space), prints flutter's own summary and exits 1.
String _writeFailingHookStandIn(Directory dir) {
  final f = File('${dir.path}/flutter_hook_stand_in.dart');
  f.writeAsStringSync(r'''
import 'dart:io';

void main(List<String> args) {
  final run = Directory(args[0])..createSync(recursive: true);
  final env = List.filled(40, r'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64').join(';');
  File('${run.path}/stderr.txt').writeAsStringSync([
    "ProcessException: Full command string: '(cd C:\\Users\\dev\\Lumina Projects\\game\\.dart_tool\\hooks_runner\\shared\\flutter_assimp\\build\\bc4af5bfa5\\; PATH=$env cl.exe /O2 )'.",
    "Exit code: '1'.",
    'For the output of the process check the logger output.',
    '#0      runProcess (package:native_toolchain_c/src/utils/run_process.dart:85:5)',
    '<asynchronous suspension>',
    '#1      RunCBuilder.runCl (package:native_toolchain_c/src/cbuilder/run_cbuilder.dart:378:20)',
    '<asynchronous suspension>',
    '',
  ].join('\r\n'));
  File('${run.path}/stdout.txt').writeAsStringSync([
    'Using envScript from input: file:///C:/Program%20Files/Microsoft%20Visual%20Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat',
    'Running `(cd C:\\Users\\dev\\Lumina Projects\\game; PATH=$env $env $env cl.exe )`.',
    r"'C:\Program' is not recognized as an internal or external command,",
    'operable program or batch file.',
    '',
  ].join('\r\n'));
  stdout.writeln('Building Windows application...');
  stderr.writeln('Target build_hooks failed: error: Building native assets failed. See the logs for more details.');
  exit(1);
}
''');
  return f.path;
}

/// A real child process standing in for `flutter build`: prints N lines with a
/// delay, records SIGTERM into `killed.marker`, exits with the requested code.
String _writeStandIn(Directory dir) {
  final f = File('${dir.path}/flutter_stand_in.dart');
  f.writeAsStringSync(r'''
import 'dart:io';

Future<void> main(List<String> args) async {
  final outDir = args[0];
  final exitCodeWanted = int.parse(args[1]);
  final lines = int.parse(args[2]);
  final delayMs = int.parse(args[3]);
  // Windows has no catchable SIGTERM (kill is TerminateProcess), so there is
  // no marker there.
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) {
      File('$outDir/killed.marker').writeAsStringSync('SIGTERM', flush: true);
      exit(143);
    });
  }
  for (var i = 1; i <= lines; i++) {
    stdout.writeln('stand-in line $i');
    await stdout.flush();
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }
  if (exitCodeWanted != 0) stderr.writeln('stand-in failing on purpose');
  exit(exitCodeWanted);
}
''');
  return f.path;
}

Uint8List _tinyPng() => Uint8List.fromList(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
      0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);

/// `flutter doctor -v` as this host printed it on 2026-09-24 (Android
/// licences not accepted — the user's decision).
const String _thisHostDoctor = '''
[✓] Flutter (Channel stable, 3.47.0, on Ubuntu 26.04.1 LTS 7.0.0-31-generic, locale en_US.UTF-8) [17ms]
    • Flutter version 3.47.0 on channel stable at /home/dev/snap/flutter/common/flutter
    • Dart version 3.13.0
    • Feature flags: enable-web, enable-linux-desktop, enable-macos-desktop, enable-windows-desktop, enable-android, enable-ios, cli-animations, enable-native-assets

[!] Android toolchain - develop for Android devices (Android SDK version 37.0.0) [284ms]
    • Android SDK at /home/dev/Android/Sdk
    • Emulator version 37.1.11.0 (build_id 15917651) (CL:N/A)
    • Platform android-37.0, build-tools 37.0.0
    • ANDROID_HOME = /home/dev/Android/Sdk
    ! Multiple adb binaries found. This can cause conflicts and device detection issues:
        - /home/dev/Android/Sdk/platform-tools/adb
        - /usr/lib/android-sdk/platform-tools/adb
    • Java binary at: /usr/lib/jvm/java-21-openjdk-amd64/bin/java
      This JDK is specified in your Flutter configuration.
      To change the current JDK, run: `flutter config --jdk-dir="path/to/jdk"`.
    • Java version OpenJDK Runtime Environment (build 21.0.12.1+1-1-26.04.4-Ubuntu)
    ✗ Android license status unknown.
      Run `flutter doctor --android-licenses` to accept the SDK licenses.
      See https://flutter.dev/to/linux-android-setup for more details.

[✓] Chrome - develop for the web [6ms]
    • Chrome at google-chrome

[✓] Linux toolchain - develop for Linux desktop [386ms]
    • Ubuntu clang version 21.1.8 (6ubuntu1)
    • cmake version 4.2.3

[✓] Connected device (2 available) [58ms]
    • Linux (desktop) • linux  • linux-x64      • Ubuntu 26.04.1 LTS 7.0.0-31-generic

[✓] Network resources [493ms]
    • All expected network resources are available.

! Doctor found issues in 1 category.
''';
