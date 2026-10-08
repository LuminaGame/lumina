import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/repositories/asset_repository.dart';
import 'package:lumina_editor_data/src/repositories/project_repository.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_animation_import.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_character_content.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_databases.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_export.dart';
import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_sandbox_level.dart';
import 'package:lumina_editor_data/src/services/code_generator_service.dart';

/// What [GameAnimationSampleBuilder.build] did, with its numbers.
class GameAnimationSampleReport {
  final String projectDir;
  final GaspImportOutcome import;
  final int runtimeClips;
  final int libraryClips;

  /// Database name → its build stats and `.posedb` size in bytes.
  final Map<String, (LuminaPoseSearchBuildStats, int)> databases;

  /// Database name → wanted clips missing from the mesh.
  final Map<String, List<String>> missingClips;
  final int meshGlbBytes;
  final int libraryGlbBytes;
  final Duration elapsed;

  const GameAnimationSampleReport({
    required this.projectDir,
    required this.import,
    required this.runtimeClips,
    required this.libraryClips,
    required this.databases,
    required this.missingClips,
    required this.meshGlbBytes,
    required this.libraryGlbBytes,
    required this.elapsed,
  });

  Map<String, Object> toJson() => {
        'projectDir': projectDir,
        'runtimeClips': runtimeClips,
        'libraryClips': libraryClips,
        'failures': import.failures,
        'importSeconds': import.elapsed.inMilliseconds / 1000.0,
        'fbxConvertSecondsSummed': import.convertTime.inMilliseconds / 1000.0,
        'retargetSeconds': import.retargetTime.inMilliseconds / 1000.0,
        'meshGlbBytes': meshGlbBytes,
        'libraryGlbBytes': libraryGlbBytes,
        'databases': {
          for (final MapEntry(key: name, value: (stats, bytes)) in databases.entries)
            name: {...stats.toJson(), 'posedbBytes': bytes},
        },
        'missingClips': missingClips,
        'elapsedSeconds': elapsed.inMilliseconds / 1000.0,
      };
}

/// Builds the Game Animation Sample example into a Lumina project: the
/// sample's exported animation set retargeted onto a skeletal mesh already
/// in the project (a MetaHuman), pose search databases, the character, its
/// Animation Blueprint, the game mode, `L_Sandbox` and the project's input
/// and Maps & Modes.
///
/// The sample's files are read from a local export; nothing of it is part
/// of Lumina.
class GameAnimationSampleBuilder {
  final String projectDir;

  /// The character's skeletal mesh asset, project relative.
  final String meshAssetPath;

  final void Function(String message)? log;

  GameAnimationSampleBuilder({required this.projectDir, required this.meshAssetPath, this.log});

  /// The skeletal mesh asset the clips that no database uses go into, so
  /// the game loads only the clips it plays.
  String get libraryAssetPath => meshAssetPath.replaceAll(RegExp(r'\.lmas$'), '_Library.lmas');

  String get _meshName => meshAssetPath.split('/').last.replaceAll('.lmas', '');

  /// The mesh GLB as it was before any clip was added, kept under `Saved/`
  /// so a rebuild starts from it.
  File get _baseGlb => File('$projectDir/Saved/GameAnimationSample/$_meshName.base.glb');

  /// Creates `<projectsDir>/<name>` through Lumina's project pipeline (the
  /// blank template) unless it exists; returns its folder.
  static Future<String> createProject(String projectsDir, String name,
      {void Function(ProjectCreationProgress)? onProgress}) async {
    final dir = Directory('$projectsDir/$name');
    if (await File('${dir.path}/$name.lmproject').exists()) return dir.path;
    await ProjectRepository().createProject(
      projectName: name,
      projectLocation: projectsDir,
      template: kBlank3dTemplateId,
      onProgress: onProgress,
    );
    return dir.path;
  }

  /// Which clips of [export] go where: the ones a database uses into the
  /// character mesh, the rest into the library; the jump clips lose their
  /// root height. [categories] limits the import (null: everything).
  static List<GaspClipJob> jobsFor(GaspExport export, {Set<String>? categories}) {
    final runtime = GaspDatabases.clipsUsed(export);
    return [
      for (final s in export.sequences)
        if (categories == null || categories.contains(s.category))
          GaspClipJob(
            fbxPath: s.fbxPath,
            name: s.name,
            folder: s.folder,
            library: !runtime.contains(s.name),
            removeRootHeight: s.category == 'Jump',
          ),
    ];
  }

  void _log(String m) => log?.call(m);

  Future<GameAnimationSampleReport> build({
    required GaspExport export,
    Set<String>? categories,
    Map<String, dynamic>? levelExport,
    List<String> propFiles = const [],
    int converters = 6,
  }) async {
    final watch = Stopwatch()..start();
    final meshLmas = File('$projectDir/$meshAssetPath');
    if (!await meshLmas.exists()) throw FileSystemException('No skeletal mesh asset', meshLmas.path);
    final meshGlbFile = File('$projectDir/${meshAssetPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
    final Uint8List base;
    if (await _baseGlb.exists()) {
      base = await _baseGlb.readAsBytes();
    } else {
      base = await meshGlbFile.exists()
          ? await meshGlbFile.readAsBytes()
          : (LuminaAsset.fromBytes(await meshLmas.readAsBytes()).rawPayload ?? Uint8List(0));
      if (GlbAnimationMerger.animationNames(base).isNotEmpty) {
        throw StateError('$meshAssetPath already carries animations; start from the mesh as exported');
      }
      await _baseGlb.parent.create(recursive: true);
      await _baseGlb.writeAsBytes(base);
    }

    // 1. Clips.
    final jobs = jobsFor(export, categories: categories);
    _log('Retargeting ${jobs.length} clips onto $_meshName (${jobs.where((j) => !j.library).length} for the game)');
    var lastShown = 0;
    final outcome = await GaspAnimationImport.run(
      meshGlb: base,
      jobs: jobs,
      meshAssetPath: meshAssetPath,
      libraryAssetPath: libraryAssetPath,
      converters: converters,
      onProgress: (done, total, clip) {
        if (done == total || done - lastShown >= 100) {
          lastShown = done;
          _log('  $done / $total ($clip)');
        }
      },
    );
    _log('Retargeted ${outcome.clips.length} clips in ${outcome.elapsed.inSeconds} s '
        '(${outcome.failures.length} failed)');
    await _writeClips(outcome, meshLmas, meshGlbFile);

    // 2. Pose search databases.
    final available = {for (final c in outcome.clips) if (!c.library) c.name};
    final databases = <String, (LuminaPoseSearchBuildStats, int)>{};
    final missing = <String, List<String>>{};
    for (final plan in GaspDatabases.plans) {
      final (doc, lacking) = GaspDatabases.document(plan, export, targetMesh: meshAssetPath, available: available);
      if (lacking.isNotEmpty) missing[plan.name] = lacking;
      final path = GaspCharacterContent.databasePath(meshAssetPath, plan.name);
      await _writeDocument(path, AssetType.poseSearchDatabase, doc.toJson(), meshAssetPath);
      if (doc.clips.isEmpty) continue;
      final built = await LuminaPoseSearchBuilder.buildInBackground(outcome.meshGlb, doc);
      final cache = File('$projectDir/${LuminaPoseSearchDatabaseRuntime.cachePathOf(path)}');
      await cache.writeAsBytes(built.cache);
      databases[plan.name] = (built.stats, built.cache.length);
      _log('${plan.name}: ${built.stats.clips} clips, ${built.stats.rows} rows, '
          '${built.stats.buildMicroseconds ~/ 1000} ms, ${(built.cache.length / 1e6).toStringAsFixed(1)} MB');
    }

    // 3. Character, Animation Blueprint, game mode.
    await _writeCharacter();

    // 4. Level.
    await _writeMaterials();
    final props = await _importProps(propFiles);
    final (blocks, start) =
        levelExport == null ? (GaspSandboxLevel.defaultBlocks(), null) : GaspSandboxLevel.blocksFromExport(levelExport);
    final playerStart = start ?? const [0.0, -400.0, 100.0];
    final actors = GaspSandboxLevel.actors(
      blocks: blocks,
      playerStart: [playerStart[0], playerStart[1], math.max(playerStart[2], 100.0)],
      gameModePath: GaspCharacterContent.gameModePath,
      props: _placeProps(props, blocks, playerStart),
    );
    await File('$projectDir/${GaspSandboxLevel.levelPath}').writeAsString(jsonEncode(GaspSandboxLevel.levelContainer(actors)));
    await _writeProjectAndCode(actors);

    return GameAnimationSampleReport(
      projectDir: projectDir,
      import: outcome,
      runtimeClips: outcome.clips.where((c) => !c.library).length,
      libraryClips: outcome.clips.where((c) => c.library).length,
      databases: databases,
      missingClips: missing,
      meshGlbBytes: outcome.meshGlb.length,
      libraryGlbBytes: outcome.libraryGlb?.length ?? 0,
      elapsed: watch.elapsed,
    );
  }

  Future<void> _writeClips(GaspImportOutcome outcome, File meshLmas, File meshGlbFile) async {
    final mesh = LuminaAsset.fromBytes(await meshLmas.readAsBytes());
    await meshGlbFile.writeAsBytes(outcome.meshGlb);
    LuminaAsset withClips(LuminaAsset a, {required String id, required String name, required List<String> clips}) =>
        LuminaAsset(
          assetId: id,
          name: name,
          type: a.type,
          hasThumbnail: a.hasThumbnail,
          thumbnailPng: a.thumbnailPng,
          // Every reader falls back to the `.entity.glb` companion.
          rawPayload: null,
          rawMatSource: a.rawMatSource,
          references: a.references,
          metadata: {...a.metadata, 'animation_clips': clips.join(',')},
        );
    final runtime = [for (final c in outcome.clips) if (!c.library) c];
    final library = [for (final c in outcome.clips) if (c.library) c];
    await meshLmas.writeAsBytes(
        withClips(mesh, id: mesh.assetId, name: mesh.name, clips: GlbAnimationMerger.animationNames(outcome.meshGlb))
            .toProtoBufferBytes());
    String? libraryId;
    if (outcome.libraryGlb != null) {
      final libraryLmas = File('$projectDir/$libraryAssetPath');
      libraryId = libraryLmas.existsSync() ? LuminaAsset.fromBytes(await libraryLmas.readAsBytes()).assetId : _uuid();
      await File(libraryLmas.path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')).writeAsBytes(outcome.libraryGlb!);
      await libraryLmas.writeAsBytes(withClips(mesh,
              id: libraryId, name: '${mesh.name}_Library', clips: GlbAnimationMerger.animationNames(outcome.libraryGlb!))
          .toProtoBufferBytes());
    }
    final thumbnail = await AssetRepository().generateThumbnailBytes(AssetType.animation);
    for (final (clips, meshPath, meshId) in [
      (runtime, meshAssetPath, mesh.assetId),
      (library, libraryAssetPath, libraryId ?? ''),
    ]) {
      final folder = 'contents/animations/${meshPath.split('/').last.replaceAll('.lmas', '')}';
      for (final c in clips) {
        final rel = '$folder/${c.folder}/${c.name}.lmas';
        final file = File('$projectDir/$rel');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(LuminaAsset(
          assetId: _uuid(),
          name: c.name,
          type: AssetType.animation,
          hasThumbnail: thumbnail != null,
          thumbnailPng: thumbnail,
          references: [AssetReference(slotName: 'skeletal_mesh', assetId: meshId, assetPath: meshPath)],
          metadata: {...c.metadata, 'source': 'game_animation_sample', 'sample_folder': c.folder},
        ).toProtoBufferBytes());
      }
    }
  }

  /// A JSON-payload asset (Blueprint, Animation Blueprint, pose search
  /// database) as the editor writes one; keeps an existing asset's id.
  Future<void> _writeDocument(String rel, AssetType type, Map<String, dynamic> json, String? targetMesh) async {
    final file = File('$projectDir/$rel');
    await file.parent.create(recursive: true);
    String? id;
    if (await file.exists()) {
      try {
        id = LuminaAsset.fromBytes(await file.readAsBytes()).assetId;
      } catch (_) {}
    }
    final text = const JsonEncoder.withIndent('  ').convert(json);
    await file.writeAsBytes(LuminaAsset(
      assetId: id ?? _uuid(),
      name: rel.split('/').last.replaceAll('.lmas', ''),
      type: type,
      rawPayload: Uint8List.fromList(utf8.encode(text)),
      rawMatSource: text,
      references: targetMesh == null ? const [] : [AssetReference(slotName: 'skeletal_mesh', assetId: '', assetPath: targetMesh)],
      metadata: {
        'payload_format': 'json',
        'target_mesh': ?targetMesh,
        'source': 'game_animation_sample',
        'last_modified': DateTime.now().toIso8601String(),
      },
    ).toProtoBufferBytes());
  }

  Future<void> _writeCharacter() async {
    final actions = ProjectInputBinder.bind(GaspCharacterContent.input).actions.values.toList();
    await _writeDocument(GaspCharacterContent.animBlueprintPath(meshAssetPath), AssetType.animBlueprint,
        GaspCharacterContent.animBlueprint(meshAssetPath: meshAssetPath).toJson(), meshAssetPath);
    await _writeDocument(GaspCharacterContent.characterPath, AssetType.actor,
        GaspCharacterContent.characterBlueprint(meshAssetPath: meshAssetPath, inputActions: actions).toJson(), null);
    final gameMode = GaspCharacterContent.gameModeBlueprint.toJson();
    await _writeDocument(GaspCharacterContent.gameModePath, AssetType.actor, gameMode, null);
    final ok = await DartCodeGeneratorService().compileAndWriteActor(projectDir, GaspCharacterContent.gameModeName, gameMode,
        assetPath: GaspCharacterContent.gameModePath, inputActions: actions);
    if (!ok) throw StateError('The sample Blueprints did not compile (${GaspCharacterContent.gameModePath})');
    _log('Compiled ${GaspCharacterContent.gameModeName}, ${GaspCharacterContent.characterName} and '
        '${GaspCharacterContent.animBlueprintName}');
  }

  Future<void> _writeMaterials() async {
    for (final name in GaspSandboxLevel.gridColors.keys) {
      final source = GaspSandboxLevel.gridMaterialSource(name);
      final result = FilamentMatc.compile(source, fileName: '$name.mat', defaultName: name);
      if (!result.ok) throw StateError('$name did not compile: ${result.errorText}');
      final file = File('$projectDir/contents/materials/$name.lmas');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(LuminaAsset(
        assetId: _uuid(),
        name: name,
        type: AssetType.filamat,
        rawPayload: result.package,
        rawMatSource: source,
        metadata: const {'source': 'game_animation_sample', 'shadingModel': 'lit'},
      ).toProtoBufferBytes());
    }
  }

  /// Imports [files] (models) once each; returns their project paths.
  Future<List<String>> _importProps(List<String> files) async {
    final out = <String>[];
    for (final f in files) {
      final name = f.replaceAll(r'\', '/').split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final existing = File('$projectDir/contents/meshes/static/$name.lmas');
      if (await existing.exists()) {
        out.add('contents/meshes/static/$name.lmas');
        continue;
      }
      try {
        final info = await AssetRepository().importExternalFile(projectPath: projectDir, sourceFilePath: f, targetSkeletonPath: '');
        out.add(info.relativePath);
      } catch (e) {
        _log('Prop $name not imported: $e');
      }
    }
    return out;
  }

  /// Props in a ring around the player start, clear of the blocks.
  List<Map<String, dynamic>> _placeProps(List<String> props, List<GaspLevelBlock> blocks, List<double> start) {
    bool clear(double x, double y) => blocks.every((b) {
          final r = math.max(b.size[0], b.size[1]) / 2 + 150;
          return (b.center[0] - x).abs() > r || (b.center[1] - y).abs() > r;
        });
    final out = <Map<String, dynamic>>[];
    var k = 0;
    for (var ring = 0; ring < 6 && out.length < props.length * 2; ring++) {
      for (var i = 0; i < 12 && out.length < props.length * 2; i++) {
        final angle = (i + ring * 0.5) * math.pi / 6;
        final x = start[0] + math.cos(angle) * (700 + ring * 250);
        final y = start[1] + math.sin(angle) * (700 + ring * 250);
        if (!clear(x, y)) continue;
        final mesh = props[k % props.length];
        // Placed meshes resolve their asset by absolute path in Play.
        out.add(GaspSandboxLevel.prop('prop_$k', mesh.split('/').last.replaceAll('.lmas', ''), '$projectDir/$mesh', [x, y, 0.0],
            yaw: (k * 47) % 360.0));
        k++;
      }
    }
    return out;
  }

  Future<void> _writeProjectAndCode(List<Map<String, dynamic>> actors) async {
    final dir = Directory(projectDir);
    final manifest = await dir.list().firstWhere((e) => e is File && e.path.endsWith('.lmproject')) as File;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(await manifest.readAsString()) as Map));
    const mapsAndModes = ProjectMapsAndModes(
      editorStartupMap: GaspSandboxLevel.levelPath,
      gameDefaultMap: GaspSandboxLevel.levelPath,
      defaultGameMode: GaspCharacterContent.gameModePath,
    );
    final now = DateTime.now().toIso8601String();
    final updated = project.copyWith(
      activeLevel: GaspSandboxLevel.levelPath,
      input: GaspCharacterContent.input,
      mapsAndModes: mapsAndModes,
      description: project.description.isEmpty
          ? 'Game Animation Sample on a MetaHuman: motion matching locomotion and a sandbox level'
          : project.description,
      lastModifiedTimestamp: now,
      lastCodeGeneratedTimestamp: now,
    );
    await manifest.writeAsString(jsonEncode(updated.toMap()));

    // The clips, databases and the Animation Blueprint sit in subfolders of
    // contents/, which a game bundles only when its pubspec lists them.
    ProjectRepository.ensurePubspecAssets(projectDir);
    final codegen = DartCodeGeneratorService();
    final levels = Directory('$projectDir/lib/levels');
    await levels.create(recursive: true);
    await File('${levels.path}/${dartFileName(GaspSandboxLevel.levelName)}').writeAsString(codegen.generateLevelDart(
      levelName: GaspSandboxLevel.levelName,
      actors: const [],
      actorMaps: actors,
      projectDir: projectDir,
    ));
    codegen.writeProjectInputDart(projectDir, GaspCharacterContent.input);
    final registry = codegen.writeProjectBlueprintRegistry(projectDir);
    await File('$projectDir/lib/main.dart').writeAsString(codegen.generateMainDart(
      projectName: updated.projectName,
      levelName: GaspSandboxLevel.levelName,
      widgetLibrary: updated.ui.widgetLibrary,
      gravityZ: updated.physics.gravityZ,
      mapsAndModes: mapsAndModes,
      hasBlueprints: true,
      projectInput: true,
      blueprintRegistry: registry,
      levelNames: DartCodeGeneratorService.generatedLevelNames(projectDir),
    ));
  }

  static String _uuid() {
    final random = math.Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
